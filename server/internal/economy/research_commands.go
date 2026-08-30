package economy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
)

type researchProgression struct {
	ClearedStageNumbers []int            `json:"clearedStageNumbers"`
	ResearchLevels      map[string]int   `json:"researchLevels"`
	ActiveResearches    []activeResearch `json:"activeResearches"`
}

type activeResearch struct {
	Type                 string `json:"type"`
	TargetLevel          int    `json:"targetLevel"`
	StartedAtMillis      int64  `json:"startedAtMillis"`
	DurationMillis       int64  `json:"durationMillis"`
	InitialElapsedMillis int64  `json:"initialElapsedMillis"`
}

func (service *Service) CompleteResearch(
	ctx context.Context,
	accountID string,
	sessionID string,
	request ResearchCompleteRequest,
) (CommandResult, error) {
	accountUUID, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse research account ID: %w", err)
	}
	sessionUUID, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse research session ID: %w", err)
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
		return CommandResult{}, fmt.Errorf("get research command receipt: %w", err)
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin research completion: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	_, saveSnapshot, err := lockWriterAndSave(ctx, txQueries, accountUUID, sessionUUID, request.WriterGeneration, request.SourceSaveRevision)
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
		return CommandResult{}, fmt.Errorf("recheck research command receipt: %w", err)
	}
	if err := validateExpectedEconomy(economy, request.ExpectedRevision, request.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	pendingEffects, err := txQueries.ListPendingEconomyProgressionEffects(ctx, accountUUID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("list pending research effects: %w", err)
	}
	for _, effect := range pendingEffects {
		if effect.EffectType != "complete_research" {
			continue
		}
		var payload struct {
			ResearchType string `json:"researchType"`
		}
		if json.Unmarshal(effect.Payload, &payload) == nil && payload.ResearchType == request.ResearchType {
			return CommandResult{}, ErrProgressionEffect
		}
	}
	active, cost, err := researchCompletionCost(saveSnapshot.Progression, request.ResearchType, service.now().UTC())
	if err != nil {
		return CommandResult{}, err
	}
	freeAfter, paidAfter, freeSpent, paidSpent, err := spendDiamonds(economy.FreeDiamonds, economy.PaidDiamonds, cost)
	if err != nil {
		return CommandResult{}, err
	}
	resultingRevision := economy.Revision + 1
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("get research authority epoch: %w", err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: accountUUID, IdempotencyKey: key, CommandType: "research_complete",
		RequestHash: requestHash, ExpectedRevision: int8(economy.Revision),
		ResultingRevision: resultingRevision, AuthorityEpoch: system.AuthorityEpoch,
		CatalogVersion: int4(CatalogVersion), ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create research completion command: %w", err)
	}
	effectPayload, _ := json.Marshal(map[string]any{"researchType": active.Type, "targetLevel": active.TargetLevel})
	effect, err := txQueries.CreateEconomyProgressionEffect(ctx, dbgen.CreateEconomyProgressionEffectParams{
		AccountID: accountUUID, CommandID: command.ID, EffectType: "complete_research", Payload: effectPayload,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create research progression effect: %w", err)
	}
	updated, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: accountUUID, Revision: resultingRevision,
		FreeDiamonds: freeAfter, PaidDiamonds: paidAfter, ModuleTickets: economy.ModuleTickets,
		ModuleDrawCount: economy.ModuleDrawCount, ModuleTicketPurchaseCount: economy.ModuleTicketPurchaseCount,
		ModuleItemSequence:      economy.ModuleItemSequence,
		ResearchSlotTwoUnlocked: economy.ResearchSlotTwoUnlocked, Revision_2: economy.Revision,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("update economy after research completion: %w", err)
	}
	entryOrder := int16(0)
	if freeSpent > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "free_diamond", -freeSpent, freeAfter, "research_complete"); err != nil {
			return CommandResult{}, err
		}
	}
	if paidSpent > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "paid_diamond", -paidSpent, paidAfter, "research_complete"); err != nil {
			return CommandResult{}, err
		}
	}
	snapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return CommandResult{}, err
	}
	progressionEffect := ProgressionEffect{
		ID: formatUUID(effect.ID), EffectType: effect.EffectType,
		Payload: map[string]any{"researchType": active.Type, "targetLevel": active.TargetLevel},
	}
	result := CommandResult{Snapshot: snapshot, ProgressionEffect: &progressionEffect}
	if err := storeCommandResult(ctx, txQueries, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CommandResult{}, fmt.Errorf("commit research completion: %w", err)
	}
	return result, nil
}

func (service *Service) UnlockResearchSlotTwo(
	ctx context.Context,
	accountID string,
	sessionID string,
	request ResearchSlotUnlockRequest,
) (CommandResult, error) {
	accountUUID, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse research slot account ID: %w", err)
	}
	sessionUUID, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse research slot session ID: %w", err)
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
		return CommandResult{}, fmt.Errorf("get research slot receipt: %w", err)
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin research slot unlock: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	_, saveSnapshot, err := lockWriterAndSave(ctx, txQueries, accountUUID, sessionUUID, request.WriterGeneration, request.SourceSaveRevision)
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
		return CommandResult{}, fmt.Errorf("recheck research slot receipt: %w", err)
	}
	if err := validateExpectedEconomy(economy, request.ExpectedRevision, request.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	if economy.ResearchSlotTwoUnlocked || !stageCleared(saveSnapshot.Progression, 10) {
		return CommandResult{}, ErrInvalidCommand
	}
	freeAfter, paidAfter, freeSpent, paidSpent, err := spendDiamonds(economy.FreeDiamonds, economy.PaidDiamonds, ResearchSlotTwoUnlockCost)
	if err != nil {
		return CommandResult{}, err
	}
	resultingRevision := economy.Revision + 1
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("get research slot authority epoch: %w", err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: accountUUID, IdempotencyKey: key, CommandType: "research_slot_two_unlock",
		RequestHash: requestHash, ExpectedRevision: int8(economy.Revision),
		ResultingRevision: resultingRevision, AuthorityEpoch: system.AuthorityEpoch,
		CatalogVersion: int4(CatalogVersion), ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create research slot command: %w", err)
	}
	updated, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: accountUUID, Revision: resultingRevision,
		FreeDiamonds: freeAfter, PaidDiamonds: paidAfter, ModuleTickets: economy.ModuleTickets,
		ModuleDrawCount: economy.ModuleDrawCount, ModuleTicketPurchaseCount: economy.ModuleTicketPurchaseCount,
		ModuleItemSequence: economy.ModuleItemSequence, ResearchSlotTwoUnlocked: true,
		Revision_2: economy.Revision,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("update economy after research slot unlock: %w", err)
	}
	entryOrder := int16(0)
	if freeSpent > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "free_diamond", -freeSpent, freeAfter, "research_slot_two_unlock"); err != nil {
			return CommandResult{}, err
		}
	}
	if paidSpent > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "paid_diamond", -paidSpent, paidAfter, "research_slot_two_unlock"); err != nil {
			return CommandResult{}, err
		}
	}
	snapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{Snapshot: snapshot}
	if err := storeCommandResult(ctx, txQueries, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CommandResult{}, fmt.Errorf("commit research slot unlock: %w", err)
	}
	return result, nil
}

func (service *Service) AcknowledgeProgressionEffect(
	ctx context.Context,
	accountID string,
	sessionID string,
	request EffectAckRequest,
) (CommandResult, error) {
	accountUUID, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse effect account ID: %w", err)
	}
	sessionUUID, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse effect session ID: %w", err)
	}
	effectUUID, err := parseUUID(request.EffectID)
	if err != nil {
		return CommandResult{}, ErrProgressionEffect
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
		return CommandResult{}, fmt.Errorf("get effect ack receipt: %w", err)
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin effect ack: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	_, saveSnapshot, err := lockWriterAndSave(ctx, txQueries, accountUUID, sessionUUID, request.WriterGeneration, request.AppliedSaveRevision)
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
		return CommandResult{}, fmt.Errorf("recheck effect ack receipt: %w", err)
	}
	effect, err := txQueries.GetEconomyProgressionEffectForUpdate(ctx, dbgen.GetEconomyProgressionEffectForUpdateParams{AccountID: accountUUID, ID: effectUUID})
	if errors.Is(err, pgx.ErrNoRows) || effect.Status != "pending" {
		return CommandResult{}, ErrProgressionEffect
	}
	if err != nil {
		return CommandResult{}, fmt.Errorf("lock progression effect: %w", err)
	}
	if !effectAppliedToProgression(effect.Payload, saveSnapshot.Progression) {
		return CommandResult{}, ErrProgressionEffect
	}
	resultingRevision := economy.Revision + 1
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("get effect authority epoch: %w", err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: accountUUID, IdempotencyKey: key, CommandType: "progression_effect_ack",
		RequestHash: requestHash, ResultingRevision: resultingRevision,
		AuthorityEpoch: system.AuthorityEpoch, ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create effect ack command: %w", err)
	}
	if _, err := txQueries.ApplyEconomyProgressionEffect(ctx, dbgen.ApplyEconomyProgressionEffectParams{
		AccountID: accountUUID, ID: effectUUID,
		AppliedSaveRevision: int8(request.AppliedSaveRevision), AppliedByCommandID: command.ID,
	}); err != nil {
		return CommandResult{}, fmt.Errorf("apply progression effect ack: %w", err)
	}
	updated, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: accountUUID, Revision: resultingRevision,
		FreeDiamonds: economy.FreeDiamonds, PaidDiamonds: economy.PaidDiamonds,
		ModuleTickets: economy.ModuleTickets, ModuleDrawCount: economy.ModuleDrawCount,
		ModuleTicketPurchaseCount: economy.ModuleTicketPurchaseCount,
		ModuleItemSequence:        economy.ModuleItemSequence,
		ResearchSlotTwoUnlocked:   economy.ResearchSlotTwoUnlocked, Revision_2: economy.Revision,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("advance economy after effect ack: %w", err)
	}
	snapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{Snapshot: snapshot}
	if err := storeCommandResult(ctx, txQueries, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CommandResult{}, fmt.Errorf("commit effect ack: %w", err)
	}
	return result, nil
}

func researchCompletionCost(progressionJSON []byte, researchType string, now time.Time) (activeResearch, int64, error) {
	var progression researchProgression
	if err := json.Unmarshal(progressionJSON, &progression); err != nil {
		return activeResearch{}, 0, ErrInvalidCommand
	}
	for _, active := range progression.ActiveResearches {
		if active.Type != researchType || active.TargetLevel <= 0 || active.DurationMillis <= 0 {
			continue
		}
		elapsed := active.InitialElapsedMillis
		if active.StartedAtMillis > 0 {
			realtime := now.UnixMilli() - active.StartedAtMillis
			if realtime > 0 {
				elapsed += realtime
			}
		}
		remaining := active.DurationMillis - elapsed
		if remaining <= 0 {
			return activeResearch{}, 0, ErrInvalidCommand
		}
		cost := (remaining + ResearchDiamondMillis - 1) / ResearchDiamondMillis
		return active, cost, nil
	}
	return activeResearch{}, 0, ErrInvalidCommand
}

func stageCleared(progressionJSON []byte, stage int) bool {
	var progression progressionUnlocks
	if json.Unmarshal(progressionJSON, &progression) != nil {
		return false
	}
	for _, value := range progression.ClearedStageNumbers {
		if value == stage {
			return true
		}
	}
	return false
}

func effectAppliedToProgression(effectJSON []byte, progressionJSON []byte) bool {
	var effect struct {
		ResearchType string `json:"researchType"`
		TargetLevel  int    `json:"targetLevel"`
	}
	var progression researchProgression
	if json.Unmarshal(effectJSON, &effect) != nil || json.Unmarshal(progressionJSON, &progression) != nil {
		return false
	}
	if progression.ResearchLevels[effect.ResearchType] < effect.TargetLevel {
		return false
	}
	for _, active := range progression.ActiveResearches {
		if active.Type == effect.ResearchType && active.TargetLevel <= effect.TargetLevel {
			return false
		}
	}
	return true
}
