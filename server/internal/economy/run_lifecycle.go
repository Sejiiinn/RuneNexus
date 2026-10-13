package economy

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"io"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/Sejiiinn/RuneNexus/server/internal/runstate"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type RunState struct {
	RunID          string `json:"runId"`
	StageNumber    int    `json:"stageNumber"`
	Status         string `json:"status"`
	LegacyImported bool   `json:"legacyImported"`
}

type StartRunRequest struct {
	IdempotencyKey         string
	RawBody                []byte
	WriterGeneration       int64
	SourceSaveRevision     int64
	ExpectedRevision       int64
	ExpectedCatalogVersion int32
	StageNumber            int
}

type CloseRunRequest struct {
	IdempotencyKey         string
	RawBody                []byte
	WriterGeneration       int64
	SourceSaveRevision     int64
	ExpectedRevision       int64
	ExpectedCatalogVersion int32
	RunID                  string
}

// The active run's deck is part of the current read so a restarted client can
// keep presenting candidates locally without ever persisting the deck itself.
func currentRunState(ctx context.Context, q *dbgen.Queries, account pgtype.UUID) (*RunState, *GemDeck, error) {
	row, err := q.GetActiveEconomyRun(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil, nil
	}
	if err != nil {
		return nil, nil, err
	}
	deck, err := parseGemDeck(row.GemDeck)
	if err != nil {
		return nil, nil, err
	}
	return runView(row), deck, nil
}

func runView(row dbgen.EconomyRun) *RunState {
	return &RunState{RunID: formatUUID(row.RunID), StageNumber: int(row.StageNumber), Status: row.Status, LegacyImported: row.LegacyImported}
}

func (service *Service) StartRun(ctx context.Context, account, session string, request StartRunRequest) (CommandResult, error) {
	if request.StageNumber < 1 || request.StageNumber > gamesave.CurrentStageCount {
		return CommandResult{}, ErrInvalidCommand
	}
	return service.runLifecycle(ctx, account, session, request, "run_start", "")
}

func (service *Service) CloseRun(ctx context.Context, account, session string, request CloseRunRequest) (CommandResult, error) {
	common := StartRunRequest{IdempotencyKey: request.IdempotencyKey, RawBody: request.RawBody, WriterGeneration: request.WriterGeneration, SourceSaveRevision: request.SourceSaveRevision, ExpectedRevision: request.ExpectedRevision, ExpectedCatalogVersion: request.ExpectedCatalogVersion}
	if _, err := parseUUID(request.RunID); err != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	return service.runLifecycle(ctx, account, session, common, "run_close", request.RunID)
}

func (service *Service) runLifecycle(ctx context.Context, accountText, sessionText string, request StartRunRequest, kind, runText string) (CommandResult, error) {
	account, err := parseUUID(accountText)
	if err != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	session, err := parseUUID(sessionText)
	if err != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	identity, err := newCommandIdentity(request.IdempotencyKey, kind, kind, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	q := dbgen.New(service.database)
	if result, found, err := storedCommandResult[CommandResult](ctx, q, account, identity); found || err != nil {
		return result, err
	}
	if gamesave.ClientCompatibilityFromBody(request.RawBody) < gamesave.RunAuthorityClientCompatibilityVersion {
		return CommandResult{}, gamesave.ErrClientUpdateRequired
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q = dbgen.New(tx)
	// Check receipts again immediately after the serialization locks, before
	// revision validation, so concurrent exact retries recover their first result.
	writer, err := q.GetSaveWriterStateForUpdate(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, ErrWriterRequired
	}
	if err != nil {
		return CommandResult{}, err
	}
	header, err := q.GetSaveHeaderForUpdate(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, ErrSaveRevisionConflict
	}
	if err != nil {
		return CommandResult{}, err
	}
	wallet, err := lockAuthoritativeEconomy(ctx, q, account, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	if result, found, err := storedCommandResult[CommandResult](ctx, q, account, identity); found || err != nil {
		return result, err
	}
	if writer.Generation <= 0 || request.WriterGeneration <= 0 {
		return CommandResult{}, ErrWriterRequired
	}
	if writer.Generation != request.WriterGeneration || writer.SessionID != session {
		return CommandResult{}, ErrWriterReplaced
	}
	if header.Revision != request.SourceSaveRevision {
		return CommandResult{}, ErrSaveRevisionConflict
	}
	if err = validateExpectedEconomy(wallet, request.ExpectedRevision, request.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	source, err := q.GetSaveSnapshot(ctx, account)
	if err != nil {
		return CommandResult{}, err
	}
	if !wallet.RunAuthorityEnabled {
		if err = runstate.AdoptCanonical(ctx, q, account, source.ActiveRun); err != nil {
			return CommandResult{}, runLifecycleError(err)
		}
		wallet.RunAuthorityEnabled = true
	}
	var row dbgen.EconomyRun
	var activeRun map[string]json.RawMessage
	var deck *GemDeck
	var closingDeck []byte
	if kind == "run_start" {
		if err := gamesave.ValidateCoreTreeRunStart(source.Progression, source.ActiveRun, gamesave.ClientCompatibilityFromBody(request.RawBody)); err != nil {
			return CommandResult{}, err
		}
		if _, activeErr := q.GetActiveEconomyRunForUpdate(ctx, account); activeErr == nil {
			return CommandResult{}, ErrGemOfferConflict
		} else if !errors.Is(activeErr, pgx.ErrNoRows) {
			return CommandResult{}, activeErr
		}
		if runstate.ValidatePristine(source.ActiveRun, int32(request.StageNumber)) != nil {
			return CommandResult{}, ErrGemOfferConflict
		}
		id := pgtype.UUID{Valid: true}
		if _, err = io.ReadFull(rand.Reader, id.Bytes[:]); err != nil {
			return CommandResult{}, err
		}
		id.Bytes[6] = (id.Bytes[6] & 0x0f) | 0x40
		id.Bytes[8] = (id.Bytes[8] & 0x3f) | 0x80
		row, err = q.CreateEconomyRun(ctx, dbgen.CreateEconomyRunParams{AccountID: account, RunID: id, StageNumber: int32(request.StageNumber), OwnedGems: []byte(`{}`)})
		if err != nil {
			return CommandResult{}, err
		}
		if gamesave.ClientCompatibilityFromBody(request.RawBody) >= GemDeckClientCompatibilityVersion {
			if deck, err = issueGemDeck(ctx, q, account, id, source.Progression); err != nil {
				return CommandResult{}, err
			}
		}
		if json.Unmarshal(source.ActiveRun, &activeRun) != nil || activeRun == nil {
			return CommandResult{}, ErrInvalidCommand
		}
		activeRun["economyRunId"], _ = json.Marshal(formatUUID(id))
		payload, e := json.Marshal(activeRun)
		if e != nil {
			return CommandResult{}, e
		}
		if err = q.UpsertSaveActiveRun(ctx, dbgen.UpsertSaveActiveRunParams{AccountID: account, Payload: payload}); err != nil {
			return CommandResult{}, err
		}
	} else {
		id, _ := parseUUID(runText)
		row, err = q.GetEconomyRunForUpdate(ctx, dbgen.GetEconomyRunForUpdateParams{AccountID: account, RunID: id})
		if errors.Is(err, pgx.ErrNoRows) {
			return CommandResult{}, ErrGemOfferConflict
		}
		if err != nil {
			return CommandResult{}, err
		}
		var checkpoint struct {
			ID string `json:"economyRunId"`
		}
		if len(source.ActiveRun) > 0 && string(source.ActiveRun) != "null" {
			if json.Unmarshal(source.ActiveRun, &checkpoint) != nil || checkpoint.ID != formatUUID(id) {
				return CommandResult{}, ErrGemOfferConflict
			}
		} else if row.Status == "active" {
			return CommandResult{}, ErrGemOfferConflict
		} else {
			// Recovery after an already-cleared close is read-only. A fresh key
			// cannot manufacture an unbounded history of no-op commands.
			system, e := q.GetEconomySystemState(ctx)
			if e != nil {
				return CommandResult{}, e
			}
			return CommandResult{Run: runView(row), GemReceipt: newGemReceipt(wallet, system), SaveRevision: source.Revision, ServerSavedAt: source.UpdatedAt.Time.UTC()}, nil
		}
		if row.Status == "active" {
			closingDeck = row.GemDeck
			changed, e := q.CloseEconomyRun(ctx, dbgen.CloseEconomyRunParams{AccountID: account, RunID: id})
			if e != nil {
				return CommandResult{}, e
			}
			if changed != 1 {
				return CommandResult{}, ErrGemOfferConflict
			}
			row.Status = "closed"
		}
		if err = q.DeleteSaveActiveRun(ctx, account); err != nil {
			return CommandResult{}, err
		}
	}
	advanced, err := q.AdvanceSaveHeader(ctx, dbgen.AdvanceSaveHeaderParams{AccountID: account, SchemaVersion: source.SchemaVersion, ClientSavedAtMillis: source.ClientSavedAtMillis, Revision: source.Revision})
	if err != nil {
		return CommandResult{}, err
	}
	system, err := q.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	command, err := q.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{AccountID: account, IdempotencyKey: identity.key, CommandType: kind, RequestHash: identity.requestHash, ExpectedRevision: int8(wallet.Revision), ResultingRevision: wallet.Revision + 1, AuthorityEpoch: system.AuthorityEpoch, CatalogVersion: int4(CatalogVersion), ResponsePayload: []byte(`{}`)})
	if err != nil {
		return CommandResult{}, err
	}
	order := int16(0)
	if err = chargeDeckRerolls(ctx, q, account, closingDeck, source.ActiveRun, wallet.GemResetTickets, command.ID, &order); err != nil {
		return CommandResult{}, err
	}
	wallet, err = q.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{AccountID: account, Revision: wallet.Revision + 1, FreeDiamonds: wallet.FreeDiamonds, PaidDiamonds: wallet.PaidDiamonds, ModuleTickets: wallet.ModuleTickets, ModuleDrawCount: wallet.ModuleDrawCount, ModuleTicketPurchaseCount: wallet.ModuleTicketPurchaseCount, ModuleItemSequence: wallet.ModuleItemSequence, ResearchSlotTwoUnlocked: wallet.ResearchSlotTwoUnlocked, Revision_2: wallet.Revision})
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{Run: runView(row), GemReceipt: newGemReceipt(wallet, system), SaveRevision: advanced.Revision, ServerSavedAt: advanced.UpdatedAt.Time.UTC(), GemDeck: deck}
	if err = storeCommandResult(ctx, q, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return CommandResult{}, err
	}
	return result, nil
}

// Decks are drawn from the unlocks of the checkpoint the run starts from. Clear
// progression only changes after settlement, so they stay valid for the run.
func issueGemDeck(ctx context.Context, q *dbgen.Queries, account, runID pgtype.UUID, progression []byte) (*GemDeck, error) {
	available, err := availableGems(progression)
	if err != nil {
		return nil, err
	}
	deck, err := generateGemDeck(rand.Reader, formatUUID(runID), available)
	if err != nil || deck == nil {
		return nil, err
	}
	raw, err := json.Marshal(deck)
	if err != nil {
		return nil, err
	}
	changed, err := q.SetEconomyRunGemDeck(ctx, dbgen.SetEconomyRunGemDeckParams{AccountID: account, RunID: runID, GemDeck: raw})
	if err != nil {
		return nil, err
	}
	if changed != 1 {
		return nil, ErrGemOfferConflict
	}
	return deck, nil
}

func runLifecycleError(err error) error {
	if errors.Is(err, runstate.ErrConflict) {
		return ErrGemOfferConflict
	}
	return err
}
