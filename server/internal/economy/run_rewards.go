package economy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/runstate"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type runSettlementProgression struct {
	BestRoundsByStage     map[string]int `json:"bestRoundsByStage"`
	HardBestRoundsByStage map[string]int `json:"hardBestRoundsByStage"`
	ClearedStageNumbers   []int          `json:"clearedStageNumbers"`
}

func (service *Service) SettleRun(
	ctx context.Context,
	accountID string,
	sessionID string,
	request RunSettlementRequest,
) (CommandResult, error) {
	accountUUID, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse run settlement account ID: %w", err)
	}
	sessionUUID, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse run settlement session ID: %w", err)
	}
	runUUID, err := parseUUID(request.RunID)
	if err != nil || request.StageNumber < 1 ||
		request.StageNumber > gamesave.CurrentStageCount || request.CompletedRounds < 0 || request.CompletedRounds > 40 ||
		request.PendingDiamonds < 0 || request.PendingDiamonds > int64(request.CompletedRounds+1)*300 ||
		request.FirstClearModuleTickets < 0 ||
		(request.FirstClearModuleTickets > 0 && (!request.Success ||
			(request.FirstClearModuleTickets != HardFirstClearModuleTickets &&
				(request.StageNumber != 11 || request.FirstClearModuleTickets != StageElevenModuleTicketGift)))) {
		return CommandResult{}, ErrInvalidCommand
	}
	// UUID의 표기 대소문자는 보상 동일성에 영향을 주지 않는다.
	// RawBody는 기존 exact 재전송 영수증의 해시 계약을 그대로 보존한다.
	request.RunID = formatUUID(runUUID)
	identity, err := newCommandIdentity(request.IdempotencyKey, "run_settlement", "", request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	queries := dbgen.New(service.database)
	if result, found, err := storedCommandResult[CommandResult](ctx, queries, accountUUID, identity); found || err != nil {
		return result, err
	}
	rewardKey := "run:" + request.RunID + ":settlement"
	receipt, err := runSettlementReceipt(ctx, queries, accountUUID, rewardKey)
	if err == nil {
		var result CommandResult
		if decodeErr := json.Unmarshal(receipt, &result); decodeErr != nil {
			return CommandResult{}, fmt.Errorf("decode run settlement receipt: %w", decodeErr)
		}
		return result, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("get run reward claim: %w", err)
	}
	if gamesave.ClientCompatibilityFromBody(request.RawBody) < gamesave.RunAuthorityClientCompatibilityVersion {
		return CommandResult{}, gamesave.ErrClientUpdateRequired
	}

	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin run settlement: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	writer, saveSnapshot, err := lockWriterAndSave(
		ctx, txQueries, accountUUID, sessionUUID,
		request.WriterGeneration, request.SourceSaveRevision, request.RawBody,
	)
	if err != nil {
		return CommandResult{}, err
	}
	economy, err := lockAuthoritativeEconomy(ctx, txQueries, accountUUID, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	if result, found, err := storedCommandResult[CommandResult](ctx, txQueries, accountUUID, identity); found || err != nil {
		return result, err
	}
	if err := gamesave.ValidateClientGenerationFloor(writer, gamesave.ClientCompatibilityFromBody(request.RawBody)); err != nil {
		return CommandResult{}, err
	}
	receipt, err = runSettlementReceipt(ctx, txQueries, accountUUID, rewardKey)
	if err == nil {
		var result CommandResult
		if decodeErr := json.Unmarshal(receipt, &result); decodeErr != nil {
			return CommandResult{}, fmt.Errorf("decode locked run receipt: %w", decodeErr)
		}
		return result, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("recheck run reward claim: %w", err)
	}
	var closingRun *RunState
	var closingDeck []byte
	hard := false
	if economy.RunAuthorityEnabled || gamesave.ClientCompatibilityFromBody(request.RawBody) >= gamesave.RunAuthorityClientCompatibilityVersion {
		if !economy.RunAuthorityEnabled {
			if err := runstate.AdoptCanonical(ctx, txQueries, accountUUID, saveSnapshot.ActiveRun); err != nil {
				return CommandResult{}, runLifecycleError(err)
			}
			economy.RunAuthorityEnabled = true
		}
		run, err := runstate.RequireActive(ctx, txQueries, accountUUID, runUUID)
		if err != nil {
			return CommandResult{}, runLifecycleError(err)
		}
		var checkpoint struct {
			ID        string `json:"economyRunId"`
			Stage     int    `json:"stageNumber"`
			Completed int    `json:"completedRounds"`
			Phase     string `json:"phase"`
			// Client-trusted like the rest of the run; only rolls are server-side.
			Difficulty string `json:"difficulty"`
		}
		if json.Unmarshal(saveSnapshot.ActiveRun, &checkpoint) != nil || checkpoint.ID != request.RunID || checkpoint.Stage != request.StageNumber || checkpoint.Completed != request.CompletedRounds || (checkpoint.Phase != "success" && checkpoint.Phase != "failure") || (checkpoint.Phase == "success") != request.Success || run.StageNumber != int32(request.StageNumber) {
			return CommandResult{}, ErrInvalidCommand
		}
		hard = checkpoint.Difficulty == "hard"
		closingRun = &RunState{RunID: request.RunID, StageNumber: request.StageNumber, Status: "closed", LegacyImported: run.LegacyImported}
		closingDeck = run.GemDeck
	}
	var progression runSettlementProgression
	stageKey := fmt.Sprintf("%d", request.StageNumber)
	// A hard run records its rounds separately; either record covers the run.
	if json.Unmarshal(saveSnapshot.Progression, &progression) != nil ||
		max(progression.BestRoundsByStage[stageKey], progression.HardBestRoundsByStage[stageKey]) < request.CompletedRounds ||
		(request.Success && !intContains(progression.ClearedStageNumbers, request.StageNumber)) ||
		// Hard first clears carry their own ticket gift; normal never does.
		(request.FirstClearModuleTickets == HardFirstClearModuleTickets) != (hard && request.FirstClearModuleTickets > 0) {
		return CommandResult{}, ErrInvalidCommand
	}
	stageRewardKey := fmt.Sprintf("stage:%d:first_clear", request.StageNumber)
	if hard {
		stageRewardKey = fmt.Sprintf("stage:%d:hard_first_clear", request.StageNumber)
	}
	stageTickets := int64(0)
	if request.Success && request.FirstClearModuleTickets > 0 {
		if _, claimErr := txQueries.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{
			AccountID: accountUUID, RewardKey: stageRewardKey,
		}); errors.Is(claimErr, pgx.ErrNoRows) {
			stageTickets = request.FirstClearModuleTickets
		} else if claimErr != nil {
			return CommandResult{}, fmt.Errorf("check stage reward claim: %w", claimErr)
		}
	}
	resultingRevision := economy.Revision + 1
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("get run authority epoch: %w", err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: accountUUID, IdempotencyKey: identity.key, CommandType: identity.commandType,
		RequestHash: identity.requestHash, ResultingRevision: resultingRevision,
		AuthorityEpoch: system.AuthorityEpoch, CatalogVersion: int4(CatalogVersion),
		ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create run settlement command: %w", err)
	}
	evidence, _ := json.Marshal(map[string]any{
		"runId": request.RunID, "stageNumber": request.StageNumber,
		"completedRounds": request.CompletedRounds, "success": request.Success,
		"pendingDiamonds":         request.PendingDiamonds,
		"firstClearModuleTickets": request.FirstClearModuleTickets,
		"hard":                    hard,
	})
	if err := txQueries.CreateEconomyRewardClaim(ctx, dbgen.CreateEconomyRewardClaimParams{
		AccountID: accountUUID, RewardKey: rewardKey, CommandID: command.ID,
		WriterGeneration: int8(writer.Generation), OriginSaveRevision: int8(saveSnapshot.Revision),
		Evidence: evidence,
	}); err != nil {
		return CommandResult{}, fmt.Errorf("create run reward claim: %w", err)
	}
	if stageTickets > 0 {
		if err := txQueries.CreateEconomyRewardClaim(ctx, dbgen.CreateEconomyRewardClaimParams{
			AccountID: accountUUID, RewardKey: stageRewardKey, CommandID: command.ID,
			WriterGeneration: int8(writer.Generation), OriginSaveRevision: int8(saveSnapshot.Revision),
			Evidence: evidence,
		}); err != nil {
			return CommandResult{}, fmt.Errorf("create stage reward claim: %w", err)
		}
	}
	entryOrder := int16(0)
	if err := chargeDeckRerolls(ctx, txQueries, accountUUID, closingDeck, saveSnapshot.ActiveRun, economy.GemResetTickets, command.ID, &entryOrder); err != nil {
		return CommandResult{}, err
	}
	// Repeat hard rewards are rolled only on a hard clear, never per wave.
	var drops hardClearRewards
	if hard && request.Success {
		drops, err = rollHardClearRewards(request.StageNumber, economy.ModuleDrawCount, unlockedTurretTypes(saveSnapshot.Progression))
		if err != nil {
			return CommandResult{}, err
		}
	}
	sequence := economy.ModuleItemSequence
	// Nil when nothing dropped, so stored receipts replay identically.
	var loot []Module
	for _, generated := range drops.Modules {
		options, _ := json.Marshal(generated.Options)
		sequence++
		row, err := txQueries.CreatePlayerModule(ctx, dbgen.CreatePlayerModuleParams{
			AccountID: accountUUID, TurretType: generated.TurretType, Part: generated.Part,
			Family: generated.Family, Grade: generated.Grade, Options: options,
			AcquiredOrder: sequence, AcquiredRevision: resultingRevision,
			CreatedByCommandID: command.ID,
		})
		if err != nil {
			return CommandResult{}, fmt.Errorf("create hard loot module: %w", err)
		}
		module, err := moduleFromRow(row)
		if err != nil {
			return CommandResult{}, err
		}
		loot = append(loot, module)
	}
	walletUpdate := NextWalletUpdate(economy)
	walletUpdate.FreeDiamonds = economy.FreeDiamonds + request.PendingDiamonds
	walletUpdate.ModuleTickets = economy.ModuleTickets + stageTickets + drops.ModuleTickets
	walletUpdate.ModuleItemSequence = sequence
	updated, err := txQueries.UpdatePlayerEconomy(ctx, walletUpdate)
	if err != nil {
		return CommandResult{}, fmt.Errorf("update economy after run: %w", err)
	}
	if request.PendingDiamonds > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "free_diamond", request.PendingDiamonds, updated.FreeDiamonds, "run_settlement"); err != nil {
			return CommandResult{}, err
		}
	}
	if stageTickets > 0 {
		reason := "stage_first_clear"
		if hard {
			reason = "hard_first_clear"
		}
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "module_ticket", stageTickets, updated.ModuleTickets-drops.ModuleTickets, reason); err != nil {
			return CommandResult{}, err
		}
	}
	if drops.ModuleTickets > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "module_ticket", drops.ModuleTickets, updated.ModuleTickets, "hard_clear_drop"); err != nil {
			return CommandResult{}, err
		}
	}
	if closingRun != nil {
		changed, err := txQueries.CloseEconomyRun(ctx, dbgen.CloseEconomyRunParams{AccountID: accountUUID, RunID: runUUID})
		if err != nil {
			return CommandResult{}, err
		}
		if changed != 1 {
			return CommandResult{}, ErrGemOfferConflict
		}
	}
	snapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{
		Snapshot: snapshot, RewardKey: rewardKey,
		GrantedDiamonds: request.PendingDiamonds, GrantedModuleTickets: stageTickets + drops.ModuleTickets,
		HardDropModuleTickets: drops.ModuleTickets, HardLootModules: loot,
		Run: closingRun,
	}
	if err := storeCommandResult(ctx, txQueries, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	// 정산과 최고 기록의 원자적 반영. 동일·하위 기록은 최초 확정 시각 보존.
	if request.CompletedRounds > 0 {
		if err := txQueries.UpsertProgressionLeaderboardRecord(ctx, dbgen.UpsertProgressionLeaderboardRecordParams{
			AccountID: accountUUID, StageNumber: int32(request.StageNumber),
			CompletedRounds: int32(request.CompletedRounds), SourceCommandID: command.ID,
		}); err != nil {
			return CommandResult{}, fmt.Errorf("update progression leaderboard: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return CommandResult{}, fmt.Errorf("commit run settlement: %w", err)
	}
	return result, nil
}

func runSettlementReceipt(ctx context.Context, queries *dbgen.Queries, accountID pgtype.UUID, rewardKey string) ([]byte, error) {
	claim, err := queries.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{
		AccountID: accountID, RewardKey: rewardKey,
	})
	if !errors.Is(err, pgx.ErrNoRows) {
		return claim.ResponsePayload, err
	}
	// 기존 서버가 원문 UUID로 저장한 영수증도 계정 내 같은 UUID의 정산이다.
	// 영속 key/hash/응답은 바꾸지 않고 기존 응답을 그대로 복구한다.
	return queries.GetLegacyRunSettlementReceipt(ctx, dbgen.GetLegacyRunSettlementReceiptParams{
		AccountID: accountID, RewardKey: rewardKey,
	})
}

func intContains(values []int, target int) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
