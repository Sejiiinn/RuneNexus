package economy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type progressionUnlocks struct {
	ClearedStageNumbers []int `json:"clearedStageNumbers"`
}

func (service *Service) DrawModules(
	ctx context.Context,
	accountID string,
	sessionID string,
	request DrawRequest,
) (CommandResult, error) {
	accountUUID, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse draw account ID: %w", err)
	}
	sessionUUID, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse draw session ID: %w", err)
	}
	key, requestHash, err := requestIdentity(request.IdempotencyKey, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	if (request.Count != 1 && request.Count != 5) || !contains(turretTypes, request.TurretType) {
		return CommandResult{}, ErrInvalidCommand
	}
	queries := dbgen.New(service.database)
	stored, err := queries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{AccountID: accountUUID, IdempotencyKey: key})
	if err == nil {
		return existingCommandResult[CommandResult](stored, requestHash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("get module draw receipt: %w", err)
	}

	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin module draw: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	_, saveSnapshot, err := lockWriterAndSave(
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
		return CommandResult{}, fmt.Errorf("recheck module draw receipt: %w", err)
	}
	if err := validateExpectedEconomy(economy, request.ExpectedRevision, request.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	if !turretUnlocked(request.TurretType, saveSnapshot.Progression) {
		return CommandResult{}, ErrInvalidCommand
	}

	count := int64(request.Count)
	missingTickets := count - economy.ModuleTickets
	if missingTickets < 0 {
		missingTickets = 0
	}
	if missingTickets > 0 && !request.BuyMissingTicketsWithDiamonds {
		return CommandResult{}, ErrInsufficientTickets
	}
	diamondCost := missingTickets * ModuleTicketDiamondCost
	freeAfter, paidAfter, freeSpent, paidSpent, err := spendDiamonds(
		economy.FreeDiamonds, economy.PaidDiamonds, diamondCost,
	)
	if err != nil {
		return CommandResult{}, err
	}
	resultingRevision := economy.Revision + 1
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("get draw authority epoch: %w", err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: accountUUID, IdempotencyKey: key, CommandType: "turret_module_draw",
		RequestHash: requestHash, ExpectedRevision: int8(economy.Revision),
		ResultingRevision: resultingRevision, AuthorityEpoch: system.AuthorityEpoch,
		CatalogVersion: int4(CatalogVersion), RngAlgorithmVersion: int4(RNGAlgorithmVersion),
		ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create module draw command: %w", err)
	}
	drawn := make([]Module, 0, request.Count)
	sequence := economy.ModuleItemSequence
	for index := 0; index < request.Count; index++ {
		generated, err := generateModule(request.TurretType, economy.ModuleDrawCount+int64(index))
		if err != nil {
			return CommandResult{}, err
		}
		options, _ := json.Marshal(generated.Options)
		sequence++
		row, err := txQueries.CreatePlayerModule(ctx, dbgen.CreatePlayerModuleParams{
			AccountID: accountUUID, TurretType: generated.TurretType, Part: generated.Part,
			Family: generated.Family, Grade: generated.Grade, Options: options,
			AcquiredOrder: sequence, AcquiredRevision: resultingRevision,
			CreatedByCommandID: command.ID,
		})
		if err != nil {
			return CommandResult{}, fmt.Errorf("create drawn module: %w", err)
		}
		module, err := moduleFromRow(row)
		if err != nil {
			return CommandResult{}, err
		}
		drawn = append(drawn, module)
	}
	ticketsAfter := economy.ModuleTickets + missingTickets - count
	updated, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: accountUUID, Revision: resultingRevision,
		FreeDiamonds: freeAfter, PaidDiamonds: paidAfter, ModuleTickets: ticketsAfter,
		ModuleDrawCount:           economy.ModuleDrawCount + count,
		ModuleTicketPurchaseCount: economy.ModuleTicketPurchaseCount + missingTickets,
		ModuleItemSequence:        sequence,
		ResearchSlotTwoUnlocked:   economy.ResearchSlotTwoUnlocked,
		Revision_2:                economy.Revision,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("update economy after draw: %w", err)
	}
	entryOrder := int16(0)
	if freeSpent > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "free_diamond", -freeSpent, freeAfter, "module_ticket_purchase"); err != nil {
			return CommandResult{}, err
		}
	}
	if paidSpent > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "paid_diamond", -paidSpent, paidAfter, "module_ticket_purchase"); err != nil {
			return CommandResult{}, err
		}
	}
	if missingTickets > 0 {
		if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "module_ticket", missingTickets, economy.ModuleTickets+missingTickets, "module_ticket_purchase"); err != nil {
			return CommandResult{}, err
		}
	}
	if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "module_ticket", -count, ticketsAfter, "turret_module_draw"); err != nil {
		return CommandResult{}, err
	}
	snapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{Snapshot: snapshot, DrawnModules: drawn}
	if err := storeCommandResult(ctx, txQueries, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CommandResult{}, fmt.Errorf("commit module draw: %w", err)
	}
	return result, nil
}

func (service *Service) DisassembleModules(
	ctx context.Context,
	accountID string,
	request DisassembleRequest,
) (CommandResult, error) {
	accountUUID, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, fmt.Errorf("parse disassemble account ID: %w", err)
	}
	key, requestHash, err := requestIdentity(request.IdempotencyKey, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	moduleIDs := append([]string(nil), request.ModuleIDs...)
	sort.Strings(moduleIDs)
	if len(moduleIDs) == 0 || len(moduleIDs) > 500 {
		return CommandResult{}, ErrInvalidCommand
	}
	for index, value := range moduleIDs {
		if index > 0 && value == moduleIDs[index-1] {
			return CommandResult{}, ErrInvalidCommand
		}
	}
	queries := dbgen.New(service.database)
	stored, err := queries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{AccountID: accountUUID, IdempotencyKey: key})
	if err == nil {
		return existingCommandResult[CommandResult](stored, requestHash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("get disassemble receipt: %w", err)
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("begin module disassemble: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	economy, err := lockAuthoritativeEconomy(ctx, txQueries, accountUUID)
	if err != nil {
		return CommandResult{}, err
	}
	stored, err = txQueries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{AccountID: accountUUID, IdempotencyKey: key})
	if err == nil {
		return existingCommandResult[CommandResult](stored, requestHash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, fmt.Errorf("recheck disassemble receipt: %w", err)
	}
	if err := validateExpectedEconomy(economy, request.ExpectedRevision, request.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	rows := make([]dbgen.PlayerModule, 0, len(moduleIDs))
	refund := int64(0)
	for _, moduleID := range moduleIDs {
		parsed, err := parseUUID(moduleID)
		if err != nil {
			return CommandResult{}, ErrModuleNotOwned
		}
		row, err := txQueries.GetActivePlayerModuleForUpdate(ctx, dbgen.GetActivePlayerModuleForUpdateParams{AccountID: accountUUID, ID: parsed})
		if errors.Is(err, pgx.ErrNoRows) {
			return CommandResult{}, ErrModuleNotOwned
		}
		if err != nil {
			return CommandResult{}, fmt.Errorf("lock module for disassembly: %w", err)
		}
		if row.Grade == "unique" {
			return CommandResult{}, ErrModuleNotAllowed
		}
		rows = append(rows, row)
		refund += gradeRefund[row.Grade]
	}
	resultingRevision := economy.Revision + 1
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, fmt.Errorf("get disassemble authority epoch: %w", err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: accountUUID, IdempotencyKey: key, CommandType: "turret_module_disassemble",
		RequestHash: requestHash, ExpectedRevision: int8(economy.Revision),
		ResultingRevision: resultingRevision, AuthorityEpoch: system.AuthorityEpoch,
		CatalogVersion: int4(CatalogVersion), ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("create disassemble command: %w", err)
	}
	for _, row := range rows {
		if _, err := txQueries.DisassemblePlayerModule(ctx, dbgen.DisassemblePlayerModuleParams{
			AccountID: accountUUID, ID: row.ID, DisassembledByCommandID: command.ID,
		}); err != nil {
			return CommandResult{}, fmt.Errorf("disassemble player module: %w", err)
		}
	}
	updated, err := txQueries.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: accountUUID, Revision: resultingRevision,
		FreeDiamonds: economy.FreeDiamonds + refund, PaidDiamonds: economy.PaidDiamonds,
		ModuleTickets: economy.ModuleTickets, ModuleDrawCount: economy.ModuleDrawCount,
		ModuleTicketPurchaseCount: economy.ModuleTicketPurchaseCount,
		ModuleItemSequence:        economy.ModuleItemSequence,
		ResearchSlotTwoUnlocked:   economy.ResearchSlotTwoUnlocked,
		Revision_2:                economy.Revision,
	})
	if err != nil {
		return CommandResult{}, fmt.Errorf("update economy after disassembly: %w", err)
	}
	entryOrder := int16(0)
	if err := createLedger(ctx, txQueries, command.ID, &entryOrder, "free_diamond", refund, updated.FreeDiamonds, "turret_module_disassemble"); err != nil {
		return CommandResult{}, err
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
		return CommandResult{}, fmt.Errorf("commit module disassembly: %w", err)
	}
	return result, nil
}

func lockAuthoritativeEconomy(ctx context.Context, queries *dbgen.Queries, accountID pgtype.UUID) (dbgen.PlayerEconomy, error) {
	economy, err := queries.GetPlayerEconomyForUpdate(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && economy.AuthorityState != "server_authoritative") {
		return dbgen.PlayerEconomy{}, ErrNotBootstrapped
	}
	if err != nil {
		return dbgen.PlayerEconomy{}, fmt.Errorf("lock player economy: %w", err)
	}
	return economy, nil
}

func validateExpectedEconomy(economy dbgen.PlayerEconomy, revision int64, catalogVersion int32) error {
	if catalogVersion != CatalogVersion {
		return ErrCatalogChanged
	}
	if economy.Revision != revision {
		return &ConflictError{CurrentRevision: economy.Revision}
	}
	return nil
}

func spendDiamonds(free int64, paid int64, cost int64) (int64, int64, int64, int64, error) {
	if cost < 0 || free+paid < cost {
		return free, paid, 0, 0, ErrInsufficientDiamonds
	}
	freeSpent := cost
	if freeSpent > free {
		freeSpent = free
	}
	paidSpent := cost - freeSpent
	return free - freeSpent, paid - paidSpent, freeSpent, paidSpent, nil
}

func createLedger(ctx context.Context, queries *dbgen.Queries, commandID pgtype.UUID, order *int16, asset string, delta int64, balance int64, reason string) error {
	if delta == 0 {
		return nil
	}
	if err := queries.CreateEconomyLedgerEntry(ctx, dbgen.CreateEconomyLedgerEntryParams{
		CommandID: commandID, EntryOrder: *order, AssetType: asset,
		Delta: delta, BalanceAfter: balance, Reason: reason,
	}); err != nil {
		return fmt.Errorf("create economy ledger entry: %w", err)
	}
	*order++
	return nil
}

func storeCommandResult(ctx context.Context, queries *dbgen.Queries, commandID pgtype.UUID, result any) error {
	payload, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("encode economy command result: %w", err)
	}
	if _, err := queries.UpdateEconomyCommandResponse(ctx, dbgen.UpdateEconomyCommandResponseParams{ID: commandID, ResponsePayload: payload}); err != nil {
		return fmt.Errorf("store economy command result: %w", err)
	}
	return nil
}

func turretUnlocked(turretType string, progressionJSON []byte) bool {
	if turretType != "sniper" && turretType != "lightning" {
		return true
	}
	var progression progressionUnlocks
	if json.Unmarshal(progressionJSON, &progression) != nil {
		return false
	}
	requiredStage := 3
	if turretType == "lightning" {
		requiredStage = 6
	}
	for _, stage := range progression.ClearedStageNumbers {
		if stage == requiredStage {
			return true
		}
	}
	return false
}
