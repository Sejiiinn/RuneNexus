package economy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"sort"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

const (
	maxBootstrapDiamonds int64 = 1_000_000
	maxBootstrapTickets  int64 = 1_000_000
	maxBootstrapModules        = 10_000
)

type legacyProgression struct {
	FreeDiamonds            int64 `json:"freeDiamonds"`
	PaidDiamonds            int64 `json:"paidDiamonds"`
	ResearchSlotTwoUnlocked bool  `json:"researchSlotTwoUnlocked"`
	ClearedStageNumbers     []int `json:"clearedStageNumbers"`
}

type legacyModuleInventory struct {
	FreeDiamonds            int64          `json:"-"`
	ResearchSlotTwoUnlocked bool           `json:"-"`
	ClearedStageNumbers     []int          `json:"-"`
	Tickets                 int64          `json:"tickets"`
	DrawCount               int64          `json:"drawCount"`
	TicketPurchaseCount     int64          `json:"ticketPurchaseCount"`
	ItemSequence            int64          `json:"itemSequence"`
	Items                   []legacyModule `json:"items"`
}

type legacyModule struct {
	ID            string         `json:"id"`
	TurretType    string         `json:"turretType"`
	Part          string         `json:"part"`
	Family        string         `json:"family"`
	Grade         string         `json:"grade"`
	Options       []moduleOption `json:"options"`
	AcquiredOrder int64          `json:"acquiredOrder"`
	Equipped      bool           `json:"equipped"`
}

func (service *Service) Bootstrap(
	ctx context.Context,
	accountID string,
	sessionID string,
	request BootstrapRequest,
) (BootstrapResult, error) {
	databaseAccountID, err := parseUUID(accountID)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("parse bootstrap account ID: %w", err)
	}
	databaseSessionID, err := parseUUID(sessionID)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("parse bootstrap session ID: %w", err)
	}
	key, requestHash, err := requestIdentity(request.IdempotencyKey, request.RawBody)
	if err != nil {
		return BootstrapResult{}, err
	}
	queries := dbgen.New(service.database)
	stored, err := queries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{
		AccountID: databaseAccountID, IdempotencyKey: key,
	})
	if err == nil {
		return existingCommandResult[BootstrapResult](stored, requestHash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return BootstrapResult{}, fmt.Errorf("get bootstrap receipt: %w", err)
	}

	tx, err := service.database.Begin(ctx)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("begin economy bootstrap: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := dbgen.New(tx)
	writer, snapshot, err := lockWriterAndSave(
		ctx, txQueries, databaseAccountID, databaseSessionID,
		request.WriterGeneration, request.ExpectedSaveRevision,
	)
	if err != nil {
		return BootstrapResult{}, err
	}
	if err := txQueries.EnsurePlayerEconomy(ctx, databaseAccountID); err != nil {
		return BootstrapResult{}, fmt.Errorf("ensure player economy: %w", err)
	}
	economy, err := txQueries.GetPlayerEconomyForUpdate(ctx, databaseAccountID)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("lock player economy: %w", err)
	}
	stored, err = txQueries.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{
		AccountID: databaseAccountID, IdempotencyKey: key,
	})
	if err == nil {
		return existingCommandResult[BootstrapResult](stored, requestHash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return BootstrapResult{}, fmt.Errorf("recheck bootstrap receipt: %w", err)
	}
	if economy.AuthorityState == "server_authoritative" {
		return BootstrapResult{}, ErrAlreadyBootstrapped
	}

	legacyEconomy, accepted, rejected, cleared, err := decodeLegacyEconomy(
		snapshot.Progression, snapshot.TurretModules,
	)
	if err != nil {
		return BootstrapResult{}, err
	}
	system, err := txQueries.GetEconomySystemState(ctx)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("get economy authority epoch: %w", err)
	}
	command, err := txQueries.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: databaseAccountID, IdempotencyKey: key, CommandType: "legacy_bootstrap",
		RequestHash: requestHash, ResultingRevision: 1, AuthorityEpoch: system.AuthorityEpoch,
		CatalogVersion: int4(CatalogVersion), ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("create bootstrap command: %w", err)
	}
	if intContains(legacyEconomy.ClearedStageNumbers, 11) {
		evidence, _ := json.Marshal(map[string]any{
			"source": "legacy_bootstrap", "stageNumber": 11,
		})
		if err := txQueries.CreateEconomyRewardClaim(ctx, dbgen.CreateEconomyRewardClaimParams{
			AccountID: databaseAccountID, RewardKey: "stage:11:first_clear",
			CommandID: command.ID, WriterGeneration: int8(writer.Generation),
			OriginSaveRevision: int8(snapshot.Revision), Evidence: evidence,
		}); err != nil {
			return BootstrapResult{}, fmt.Errorf("preserve legacy stage reward claim: %w", err)
		}
	}

	legacyIDMap := make(map[string]string, len(accepted))
	maxSequence := legacyEconomy.ItemSequence
	for _, module := range accepted {
		options, marshalErr := json.Marshal(module.Options)
		if marshalErr != nil {
			return BootstrapResult{}, fmt.Errorf("encode legacy module options: %w", marshalErr)
		}
		created, createErr := txQueries.CreatePlayerModule(ctx, dbgen.CreatePlayerModuleParams{
			AccountID: databaseAccountID, LegacyItemID: textValue(module.ID),
			TurretType: module.TurretType, Part: module.Part, Family: module.Family,
			Grade: module.Grade, Options: options, AcquiredOrder: module.AcquiredOrder,
			AcquiredRevision: 1, CreatedByCommandID: command.ID,
		})
		if createErr != nil {
			return BootstrapResult{}, fmt.Errorf("import legacy module: %w", createErr)
		}
		legacyIDMap[module.ID] = formatUUID(created.ID)
		if module.AcquiredOrder > maxSequence {
			maxSequence = module.AcquiredOrder
		}
	}
	if _, err := txQueries.CompleteEconomyBootstrap(ctx, dbgen.CompleteEconomyBootstrapParams{
		AccountID: databaseAccountID, Revision: 1,
		FreeDiamonds:              legacyEconomy.FreeDiamonds,
		ModuleTickets:             legacyEconomy.Tickets,
		ModuleDrawCount:           legacyEconomy.DrawCount,
		ModuleTicketPurchaseCount: legacyEconomy.TicketPurchaseCount,
		ModuleItemSequence:        maxSequence,
		ResearchSlotTwoUnlocked:   legacyEconomy.ResearchSlotTwoUnlocked,
		AuthorityVersion:          AuthorityVersion,
		BootstrapSaveRevision:     int8(snapshot.Revision),
	}); err != nil {
		return BootstrapResult{}, fmt.Errorf("complete economy bootstrap: %w", err)
	}
	entryOrder := int16(0)
	if legacyEconomy.FreeDiamonds > 0 {
		if err := txQueries.CreateEconomyLedgerEntry(ctx, dbgen.CreateEconomyLedgerEntryParams{
			CommandID: command.ID, EntryOrder: entryOrder, AssetType: "free_diamond",
			Delta: legacyEconomy.FreeDiamonds, BalanceAfter: legacyEconomy.FreeDiamonds,
			Reason: "legacy_bootstrap",
		}); err != nil {
			return BootstrapResult{}, fmt.Errorf("create bootstrap diamond ledger: %w", err)
		}
		entryOrder++
	}
	if legacyEconomy.Tickets > 0 {
		if err := txQueries.CreateEconomyLedgerEntry(ctx, dbgen.CreateEconomyLedgerEntryParams{
			CommandID: command.ID, EntryOrder: entryOrder, AssetType: "module_ticket",
			Delta: legacyEconomy.Tickets, BalanceAfter: legacyEconomy.Tickets,
			Reason: "legacy_bootstrap",
		}); err != nil {
			return BootstrapResult{}, fmt.Errorf("create bootstrap ticket ledger: %w", err)
		}
	}
	diagnostics, _ := json.Marshal(map[string]any{
		"rejectedModules": rejected, "clearedEquippedIds": cleared,
		"writerGeneration": writer.Generation,
	})
	if err := txQueries.CreateEconomyBootstrapBackup(ctx, dbgen.CreateEconomyBootstrapBackupParams{
		AccountID: databaseAccountID, CommandID: command.ID,
		SourceSaveRevision: snapshot.Revision, Progression: snapshot.Progression,
		TurretModules: snapshot.TurretModules, Diagnostics: diagnostics,
	}); err != nil {
		return BootstrapResult{}, fmt.Errorf("create economy bootstrap backup: %w", err)
	}
	updated, err := txQueries.GetPlayerEconomy(ctx, databaseAccountID)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("get bootstrapped economy: %w", err)
	}
	economySnapshot, err := service.snapshot(ctx, txQueries, updated)
	if err != nil {
		return BootstrapResult{}, err
	}
	result := BootstrapResult{
		Snapshot: economySnapshot, ImportedLegacyIDMap: legacyIDMap,
		RejectedModules: rejected, ClearedEquippedIDs: cleared,
		BootstrapSaveRevision: snapshot.Revision,
	}
	response, err := json.Marshal(result)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("encode bootstrap result: %w", err)
	}
	if _, err := txQueries.UpdateEconomyCommandResponse(ctx, dbgen.UpdateEconomyCommandResponseParams{
		ID: command.ID, ResponsePayload: response,
	}); err != nil {
		return BootstrapResult{}, fmt.Errorf("store bootstrap result: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return BootstrapResult{}, fmt.Errorf("commit economy bootstrap: %w", err)
	}
	return result, nil
}

func lockWriterAndSave(
	ctx context.Context,
	queries *dbgen.Queries,
	accountID pgtype.UUID,
	sessionID pgtype.UUID,
	writerGeneration int64,
	saveRevision int64,
) (dbgen.SaveWriterState, dbgen.GetSaveSnapshotRow, error) {
	writer, err := queries.GetSaveWriterStateForUpdate(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) || writerGeneration <= 0 {
		return dbgen.SaveWriterState{}, dbgen.GetSaveSnapshotRow{}, ErrWriterRequired
	}
	if err != nil {
		return dbgen.SaveWriterState{}, dbgen.GetSaveSnapshotRow{}, fmt.Errorf("lock economy save writer: %w", err)
	}
	if writer.Generation != writerGeneration || !writer.SessionID.Valid || writer.SessionID.Bytes != sessionID.Bytes {
		return dbgen.SaveWriterState{}, dbgen.GetSaveSnapshotRow{}, ErrWriterReplaced
	}
	header, err := queries.GetSaveHeaderForUpdate(ctx, accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return dbgen.SaveWriterState{}, dbgen.GetSaveSnapshotRow{}, ErrSaveRevisionConflict
	}
	if err != nil {
		return dbgen.SaveWriterState{}, dbgen.GetSaveSnapshotRow{}, fmt.Errorf("lock economy source save: %w", err)
	}
	if header.Revision != saveRevision {
		return dbgen.SaveWriterState{}, dbgen.GetSaveSnapshotRow{}, ErrSaveRevisionConflict
	}
	snapshot, err := queries.GetSaveSnapshot(ctx, accountID)
	if err != nil {
		return dbgen.SaveWriterState{}, dbgen.GetSaveSnapshotRow{}, fmt.Errorf("read economy source save: %w", err)
	}
	return writer, snapshot, nil
}

func decodeLegacyEconomy(
	progressionJSON []byte,
	modulesJSON []byte,
) (legacyModuleInventory, []legacyModule, []RejectedModule, []string, error) {
	var progression legacyProgression
	if err := json.Unmarshal(progressionJSON, &progression); err != nil {
		return legacyModuleInventory{}, nil, nil, nil, fmt.Errorf("decode legacy progression: %w", err)
	}
	if progression.FreeDiamonds < 0 || progression.PaidDiamonds < 0 ||
		progression.FreeDiamonds > maxBootstrapDiamonds ||
		progression.PaidDiamonds > maxBootstrapDiamonds ||
		progression.FreeDiamonds > math.MaxInt64-progression.PaidDiamonds ||
		progression.FreeDiamonds+progression.PaidDiamonds > maxBootstrapDiamonds {
		return legacyModuleInventory{}, nil, nil, nil, ErrInvalidCommand
	}
	var inventory legacyModuleInventory
	if err := json.Unmarshal(modulesJSON, &inventory); err != nil {
		return legacyModuleInventory{}, nil, nil, nil, fmt.Errorf("decode legacy module inventory: %w", err)
	}
	if inventory.Tickets < 0 || inventory.Tickets > maxBootstrapTickets ||
		inventory.DrawCount < 0 || inventory.TicketPurchaseCount < 0 ||
		inventory.ItemSequence < 0 || len(inventory.Items) > maxBootstrapModules {
		return legacyModuleInventory{}, nil, nil, nil, ErrInvalidCommand
	}
	inventory.FreeDiamonds = progression.FreeDiamonds + progression.PaidDiamonds
	inventory.ResearchSlotTwoUnlocked = progression.ResearchSlotTwoUnlocked
	inventory.ClearedStageNumbers = progression.ClearedStageNumbers
	accepted := make([]legacyModule, 0, len(inventory.Items))
	rejected := make([]RejectedModule, 0)
	cleared := make([]string, 0)
	seenIDs := make(map[string]struct{}, len(inventory.Items))
	seenOrders := make(map[int64]struct{}, len(inventory.Items))
	for _, module := range inventory.Items {
		reason := ""
		generated := generatedModule{
			TurretType: module.TurretType, Part: module.Part, Family: module.Family,
			Grade: module.Grade, Options: module.Options,
		}
		switch {
		case module.ID == "":
			reason = "missing_id"
		case module.AcquiredOrder <= 0:
			reason = "invalid_acquired_order"
		case validateModule(generated) != nil:
			reason = "catalog_mismatch"
		default:
			if _, exists := seenIDs[module.ID]; exists {
				reason = "duplicate_id"
			} else if _, exists := seenOrders[module.AcquiredOrder]; exists {
				reason = "duplicate_acquired_order"
			}
		}
		if reason != "" {
			rejected = append(rejected, RejectedModule{LegacyItemID: module.ID, Reason: reason})
			if module.Equipped && module.ID != "" {
				cleared = append(cleared, module.ID)
			}
			continue
		}
		seenIDs[module.ID] = struct{}{}
		seenOrders[module.AcquiredOrder] = struct{}{}
		accepted = append(accepted, module)
	}
	sort.Slice(accepted, func(i, j int) bool { return accepted[i].AcquiredOrder < accepted[j].AcquiredOrder })
	return inventory, accepted, rejected, cleared, nil
}
