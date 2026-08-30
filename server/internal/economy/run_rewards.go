package economy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
)

type runSettlementProgression struct {
	BestRoundsByStage   map[string]int `json:"bestRoundsByStage"`
	ClearedStageNumbers []int          `json:"clearedStageNumbers"`
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
	if _, err := parseUUID(request.RunID); err != nil || request.StageNumber < 1 ||
		request.StageNumber > 15 || request.CompletedRounds < 0 || request.CompletedRounds > 40 ||
		request.PendingDiamonds < 0 || request.PendingDiamonds > int64(request.CompletedRounds+1)*300 ||
		request.FirstClearModuleTickets < 0 ||
		request.FirstClearModuleTickets > StageElevenModuleTicketGift ||
		(request.FirstClearModuleTickets > 0 &&
			(!request.Success || request.StageNumber != 11 ||
				request.FirstClearModuleTickets != StageElevenModuleTicketGift)) {
		return CommandResult{}, ErrInvalidCommand
	}
	key, requestHash, err := requestIdentity(request.IdempotencyKey, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	queries := dbgen.New(service.database)
	stored, err := queries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{AccountID: accountUUID, IdempotencyKey: key})
	if err == nil {
		return existingCommandResult[CommandResult](stored, requestHash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("get run settlement receipt: %w", err)
	}
	rewardKey := "run:" + request.RunID + ":settlement"
	claimed, err := queries.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{AccountID: accountUUID, RewardKey: rewardKey})
	if err == nil {
		var result CommandResult
		if decodeErr := json.Unmarshal(claimed.ResponsePayload, &result); decodeErr != nil {
			return CommandResult{}, fmt.Errorf("decode run settlement receipt: %w", decodeErr)
		}
		return result, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("get run reward claim: %w", err)
	}

	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin run settlement: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	writer, saveSnapshot, err := lockWriterAndSave(
		ctx, txQueries, accountUUID, sessionUUID,
		request.WriterGeneration, request.SourceSaveRevision,
	)
	if err != nil {
		return CommandResult{}, err
	}
	economy, err := lockAuthoritativeEconomy(ctx, txQueries, accountUUID)
	if err != nil {
		return CommandResult{}, err
	}
	stored, err = txQueries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{AccountID: accountUUID, IdempotencyKey: key})
	if err == nil {
		return existingCommandResult[CommandResult](stored, requestHash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("recheck run settlement receipt: %w", err)
	}
	claimed, err = txQueries.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{AccountID: accountUUID, RewardKey: rewardKey})
	if err == nil {
		var result CommandResult
		if decodeErr := json.Unmarshal(claimed.ResponsePayload, &result); decodeErr != nil {
			return CommandResult{}, fmt.Errorf("decode locked run receipt: %w", decodeErr)
		}
		return result, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("recheck run reward claim: %w", err)
	}
	var progression runSettlementProgression
	if json.Unmarshal(saveSnapshot.Progression, &progression) != nil ||
		progression.BestRoundsByStage[fmt.Sprintf("%d", request.StageNumber)] < request.CompletedRounds ||
		(request.Success && !intContains(progression.ClearedStageNumbers, request.StageNumber)) {
		return CommandResult{}, ErrInvalidCommand
	}
	stageRewardKey := fmt.Sprintf("stage:%d:first_clear", request.StageNumber)
	stageTickets := int64(0)
	if request.Success && request.StageNumber == 11 &&
		request.FirstClearModuleTickets == StageElevenModuleTicketGift {
		if _, claimErr := txQueries.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{
			AccountID: accountUUID, RewardKey: stageRewardKey,
		}); errors.Is(claimErr, pgx.ErrNoRows) {
			stageTickets = StageElevenModuleTicketGift
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
		AccountID: accountUUID, IdempotencyKey: key, CommandType: "run_settlement",
		RequestHash: requestHash, ResultingRevision: resultingRevision,
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
	updated, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: accountUUID, Revision: resultingRevision,
		FreeDiamonds:              economy.FreeDiamonds + request.PendingDiamonds,
		PaidDiamonds:              economy.PaidDiamonds,
		ModuleTickets:             economy.ModuleTickets + stageTickets,
		ModuleDrawCount:           economy.ModuleDrawCount,
		ModuleTicketPurchaseCount: economy.ModuleTicketPurchaseCount,
		ModuleItemSequence:        economy.ModuleItemSequence,
		ResearchSlotTwoUnlocked:   economy.ResearchSlotTwoUnlocked,
		Revision_2:                economy.Revision,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("update economy after run: %w", err)
	}
	entryOrder := int16(0)
	if request.PendingDiamonds > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "free_diamond", request.PendingDiamonds, updated.FreeDiamonds, "run_settlement"); err != nil {
			return CommandResult{}, err
		}
	}
	if stageTickets > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "module_ticket", stageTickets, updated.ModuleTickets, "stage_first_clear"); err != nil {
			return CommandResult{}, err
		}
	}
	snapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{
		Snapshot: snapshot, RewardKey: rewardKey,
		GrantedDiamonds: request.PendingDiamonds, GrantedModuleTickets: stageTickets,
	}
	if err := storeCommandResult(ctx, txQueries, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CommandResult{}, fmt.Errorf("commit run settlement: %w", err)
	}
	return result, nil
}

func intContains(values []int, target int) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
