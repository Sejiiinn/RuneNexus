package economy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5"
)

// Stage challenge rewards (docs/stage_difficulty_design.md#도전과제). The client
// shows the same table from godot/content/stage_challenges.gd; keep both in step.
// Achievements are client-trusted progression like the rest of a run; the
// server only grants each reward key once.

// Per chapter: normal diamonds, hard diamonds, normal tickets, hard tickets.
// Chapter 3 is the cap for later chapters.
var challengeRewardTable = map[int][4]int64{1: {100, 200, 4, 5}, 2: {200, 300, 5, 6}, 3: {300, 400, 6, 7}}

type challengeReward struct {
	Diamonds      int64
	ModuleTickets int64
}

// challengeStagePosition returns the 1-based chapter and position of a stage:
// each chapter is ten consecutive entries of the progression order.
func challengeStagePosition(stageNumber int) (int, int) {
	ordinal := progressionOrdinal(stageNumber)
	if ordinal < 1 {
		return 0, 0
	}
	return (ordinal-1)/10 + 1, (ordinal-1)%10 + 1
}

// stageChallengeReward is false for hard 5th/10th stages, whose core point
// reward stays in client progression.
func stageChallengeReward(stageNumber int, hard bool) (challengeReward, bool) {
	chapter, position := challengeStagePosition(stageNumber)
	if chapter == 0 || (hard && position%5 == 0) {
		return challengeReward{}, false
	}
	row := challengeRewardTable[min(chapter, 3)]
	index := 0
	if hard {
		index = 1
	}
	if position%2 == 1 {
		return challengeReward{Diamonds: row[index]}, true
	}
	return challengeReward{ModuleTickets: row[2+index]}, true
}

func stageChallengeRewardKey(stageNumber int, hard bool) string {
	difficulty := "normal"
	if hard {
		difficulty = "hard"
	}
	return fmt.Sprintf("stage:%d:challenge:%s", stageNumber, difficulty)
}

type challengeProgression struct {
	Cleared []int `json:"clearedStageNumbers"`
	Normal  []int `json:"challengeStageNumbers"`
	Hard    []int `json:"hardChallengeStageNumbers"`
}

// Normal is also achieved by a hard achievement.
func stageChallengeAchieved(raw []byte, stageNumber int, hard bool) bool {
	var progression challengeProgression
	if json.Unmarshal(raw, &progression) != nil || !intContains(progression.Cleared, stageNumber) {
		return false
	}
	return intContains(progression.Hard, stageNumber) || (!hard && intContains(progression.Normal, stageNumber))
}

func (service *Service) ClaimStageChallenge(
	ctx context.Context,
	accountID string,
	sessionID string,
	request StageChallengeClaimRequest,
) (CommandResult, error) {
	if request.StageNumber < 1 || request.StageNumber > gamesave.CurrentStageCount || (request.Difficulty != "normal" && request.Difficulty != "hard") {
		return CommandResult{}, ErrInvalidCommand
	}
	hard := request.Difficulty == "hard"
	reward, granted := stageChallengeReward(request.StageNumber, hard)
	if !granted {
		return CommandResult{}, ErrInvalidCommand
	}
	return service.claimProgressionReward(ctx, accountID, sessionID, progressionRewardClaim{
		IdempotencyKey: request.IdempotencyKey, RawBody: request.RawBody,
		ExpectedRevision: request.ExpectedRevision, ExpectedCatalogVersion: request.ExpectedCatalogVersion,
		WriterGeneration: request.WriterGeneration, SourceSaveRevision: request.SourceSaveRevision,
		RewardKey: stageChallengeRewardKey(request.StageNumber, hard), Reward: reward, Reason: "stage_challenge",
		Evidence: map[string]any{"stageNumber": request.StageNumber, "difficulty": request.Difficulty},
		Earned: func(progression []byte, _ dbgen.PlayerEconomy) bool {
			return stageChallengeAchieved(progression, request.StageNumber, hard)
		},
	})
}

// progressionRewardClaim grants one reward earned in client-trusted progression
// (or the economy) once under its reward key.
type progressionRewardClaim struct {
	IdempotencyKey         string
	RawBody                []byte
	ExpectedRevision       int64
	ExpectedCatalogVersion int32
	WriterGeneration       int64
	SourceSaveRevision     int64
	RewardKey              string
	Reward                 challengeReward
	Reason                 string
	Evidence               map[string]any
	// Earned checks the locked save's progression and economy.
	Earned func(progression []byte, economy dbgen.PlayerEconomy) bool
}

func (service *Service) claimProgressionReward(ctx context.Context, accountID string, sessionID string, claim progressionRewardClaim) (CommandResult, error) {
	accountUUID, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse %s claim account ID: %w", claim.Reason, err)
	}
	sessionUUID, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse %s claim session ID: %w", claim.Reason, err)
	}
	identity, err := newCommandIdentity(claim.IdempotencyKey, "reward_claim", claim.RewardKey, claim.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	queries := dbgen.New(service.database)
	if result, found, err := storedCommandResult[CommandResult](ctx, queries, accountUUID, identity); found || err != nil {
		return result, err
	}
	if gamesave.ClientCompatibilityFromBody(claim.RawBody) < gamesave.StageChallengeClientCompatibilityVersion {
		return CommandResult{}, gamesave.ErrClientUpdateRequired
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin %s claim: %w", claim.Reason, err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	writer, saveSnapshot, err := lockWriterAndSave(ctx, txQueries, accountUUID, sessionUUID, claim.WriterGeneration, claim.SourceSaveRevision, claim.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	economy, err := lockAuthoritativeEconomy(ctx, txQueries, accountUUID, claim.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	if result, found, err := storedCommandResult[CommandResult](ctx, txQueries, accountUUID, identity); found || err != nil {
		return result, err
	}
	if err := gamesave.ValidateClientGenerationFloor(writer, gamesave.ClientCompatibilityFromBody(claim.RawBody)); err != nil {
		return CommandResult{}, err
	}
	if err := validateExpectedEconomy(economy, claim.ExpectedRevision, claim.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	if !claim.Earned(saveSnapshot.Progression, economy) {
		return CommandResult{}, ErrInvalidCommand
	}
	// An already claimed key is rejected; the snapshot's claim keys show it.
	if _, claimErr := txQueries.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{
		AccountID: accountUUID, RewardKey: claim.RewardKey,
	}); claimErr == nil {
		return CommandResult{}, ErrInvalidCommand
	} else if !errors.Is(claimErr, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("check %s reward claim: %w", claim.Reason, claimErr)
	}
	resultingRevision := economy.Revision + 1
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("get %s claim authority epoch: %w", claim.Reason, err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: accountUUID, IdempotencyKey: identity.key, CommandType: identity.commandType,
		RequestHash: identity.requestHash, ResultingRevision: resultingRevision,
		AuthorityEpoch: system.AuthorityEpoch, CatalogVersion: int4(CatalogVersion),
		ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create %s claim command: %w", claim.Reason, err)
	}
	evidence, _ := json.Marshal(claim.Evidence)
	if err := txQueries.CreateEconomyRewardClaim(ctx, dbgen.CreateEconomyRewardClaimParams{
		AccountID: accountUUID, RewardKey: claim.RewardKey, CommandID: command.ID,
		WriterGeneration: int8(writer.Generation), OriginSaveRevision: int8(saveSnapshot.Revision),
		Evidence: evidence,
	}); err != nil {
		return CommandResult{}, fmt.Errorf("create %s reward claim: %w", claim.Reason, err)
	}
	reward := claim.Reward
	updated, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: accountUUID, Revision: resultingRevision,
		FreeDiamonds:              economy.FreeDiamonds + reward.Diamonds,
		PaidDiamonds:              economy.PaidDiamonds,
		ModuleTickets:             economy.ModuleTickets + reward.ModuleTickets,
		ModuleDrawCount:           economy.ModuleDrawCount,
		ModuleTicketPurchaseCount: economy.ModuleTicketPurchaseCount,
		ModuleItemSequence:        economy.ModuleItemSequence,
		ResearchSlotTwoUnlocked:   economy.ResearchSlotTwoUnlocked,
		Revision_2:                economy.Revision,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("update economy after %s claim: %w", claim.Reason, err)
	}
	entryOrder := int16(0)
	if reward.Diamonds > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "free_diamond", reward.Diamonds, updated.FreeDiamonds, claim.Reason); err != nil {
			return CommandResult{}, err
		}
	}
	if reward.ModuleTickets > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "module_ticket", reward.ModuleTickets, updated.ModuleTickets, claim.Reason); err != nil {
			return CommandResult{}, err
		}
	}
	snapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{
		Snapshot: snapshot, RewardKey: claim.RewardKey,
		GrantedDiamonds: reward.Diamonds, GrantedModuleTickets: reward.ModuleTickets,
	}
	if err := storeCommandResult(ctx, txQueries, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CommandResult{}, fmt.Errorf("commit %s claim: %w", claim.Reason, err)
	}
	return result, nil
}
