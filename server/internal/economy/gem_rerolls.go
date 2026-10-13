package economy

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"math/big"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	stageprogression "github.com/Sejiiinn/RuneNexus/server/internal/progression"
	"github.com/Sejiiinn/RuneNexus/server/internal/runstate"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

var gemTypes = []string{"attackSpeed", "range", "physicalDamage", "elementalDamage", "lightWeapon", "heavyWeapon", "damageOverTime", "explosion", "chain", "criticalChance", "aimSpeed", "damageAmplifier", "armorPiercing", "multipleProjectiles"}

type gemRewardRun struct {
	RunID           string           `json:"economyRunId"`
	Phase           string           `json:"phase"`
	CompletedRounds int              `json:"completedRounds"`
	Purchased       bool             `json:"isPurchasedGemReward"`
	LegacyPaid      bool             `json:"paidGemRoll"`
	Used            int              `json:"gemRerollsUsed"`
	Options         []string         `json:"rewardOptions"`
	Inventory       map[string]int64 `json:"gemInventory"`
	Shards          int64            `json:"gemShards"`
	OfferID         string           `json:"gemOfferId"`
	ReturnPhase     string           `json:"rewardReturnPhase"`
}

func availableGems(raw []byte) ([]string, error) {
	var progression progressionUnlocks
	if json.Unmarshal(raw, &progression) != nil {
		return nil, ErrInvalidCommand
	}
	result := make([]string, 0, len(gemTypes))
	for _, gem := range gemTypes {
		if !stageprogression.HasRequirement("gem", gem, false) ||
			contains(progression.GrandfatherUnlocks, "gem:"+gem) ||
			intContains(progression.ClearedStageNumbers, stageprogression.Requirement("gem", gem, false)) ||
			(progression.ProgressionVersion < stageprogression.Version && intContains(progression.ClearedStageNumbers, stageprogression.Requirement("gem", gem, true))) {
			result = append(result, gem)
		}
	}
	return result, nil
}

// Uniform sampling without replacement, using only server crypto entropy.
// The immediate prior three are excluded; older offers are eligible again.
func sampleGems(random io.Reader, available, previous []string) ([]string, error) {
	if len(previous) != 0 && len(previous) != 3 {
		return nil, ErrInvalidCommand
	}
	excluded := map[string]bool{}
	for _, gem := range previous {
		if excluded[gem] || !contains(available, gem) {
			return nil, ErrInvalidCommand
		}
		excluded[gem] = true
	}
	candidates := make([]string, 0, len(available))
	seen := map[string]bool{}
	for _, gem := range available {
		if seen[gem] || !contains(gemTypes, gem) {
			return nil, ErrInvalidCommand
		}
		seen[gem] = true
		if !excluded[gem] {
			candidates = append(candidates, gem)
		}
	}
	if len(candidates) < 3 {
		return nil, ErrInvalidCommand
	}
	for i := 0; i < 3; i++ {
		n, err := rand.Int(random, big.NewInt(int64(len(candidates)-i)))
		if err != nil {
			return nil, fmt.Errorf("sample gem entropy: %w", err)
		}
		j := i + int(n.Int64())
		candidates[i], candidates[j] = candidates[j], candidates[i]
	}
	return candidates[:3], nil
}

func gemRerollFromRow(row dbgen.EconomyGemReroll) *GemRerollState {
	return &GemRerollState{RunID: formatUUID(row.RunID), RewardWave: int(row.RewardWave), TotalUsed: int(row.TotalUsed), GemOptions: row.GemOptions}
}

// Only the canonical active run is sent, keeping snapshots bounded while old
// per-run budgets remain durable even after that run disappears from the save.
func currentGemReroll(ctx context.Context, queries *dbgen.Queries, account pgtype.UUID) (*GemRerollState, error) {
	source, err := queries.GetSaveSnapshot(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var run gemRewardRun
	if json.Unmarshal(source.ActiveRun, &run) != nil {
		return nil, nil
	}
	id, err := parseUUID(run.RunID)
	if err != nil {
		return nil, nil
	}
	aggregate, runErr := queries.GetEconomyRun(ctx, dbgen.GetEconomyRunParams{AccountID: account, RunID: id})
	if runErr == nil && aggregate.Status == "closed" {
		return nil, nil
	}
	if runErr != nil && !errors.Is(runErr, pgx.ErrNoRows) {
		return nil, runErr
	}
	row, err := queries.GetGemReroll(ctx, dbgen.GetGemRerollParams{AccountID: account, RunID: id})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if row.TotalUsed == 0 {
		return nil, nil
	}
	return gemRerollFromRow(row), nil
}

func gemOfferFromRow(row dbgen.EconomyGemOffer) (*GemOfferState, error) {
	var state GemOfferState
	if err := json.Unmarshal(row.Payload, &state); err != nil {
		return nil, err
	}
	if state.OfferID != formatUUID(row.OfferID) || state.RunID != formatUUID(row.RunID) || state.RewardWave != int(row.RewardWave) || state.Revision != row.Revision {
		return nil, ErrGemOfferConflict
	}
	return &state, nil
}

func currentGemOffer(ctx context.Context, q *dbgen.Queries, account pgtype.UUID) (*GemOfferState, error) {
	source, err := q.GetSaveSnapshot(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var run gemRewardRun
	if json.Unmarshal(source.ActiveRun, &run) != nil {
		return nil, nil
	}
	id, err := parseUUID(run.RunID)
	if err != nil {
		return nil, nil
	}
	authority, runErr := q.GetEconomyRun(ctx, dbgen.GetEconomyRunParams{AccountID: account, RunID: id})
	if runErr == nil && authority.Status == "closed" {
		return nil, nil
	}
	if runErr == nil && len(authority.PurchasedOffer) > 0 {
		var purchase GemOfferState
		if json.Unmarshal(authority.PurchasedOffer, &purchase) != nil {
			return nil, ErrGemOfferConflict
		}
		if purchase.Status == "pending" || purchase.OfferID == run.OfferID {
			return &purchase, nil
		}
	} else if runErr != nil && !errors.Is(runErr, pgx.ErrNoRows) {
		return nil, runErr
	}
	row, err := q.GetLatestGemOffer(ctx, dbgen.GetLatestGemOfferParams{AccountID: account, RunID: id})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return gemOfferFromRow(row)
}

func (service *Service) OfferGems(ctx context.Context, account, session string, request GemOfferRequest) (CommandResult, error) {
	return service.gemCommand(ctx, account, session, request, "gem_offer", "", 0, 0, "")
}

func (service *Service) ChooseGem(ctx context.Context, account, session string, request GemChooseRequest) (CommandResult, error) {
	return service.gemCommand(ctx, account, session, request.GemOfferRequest, "gem_choose", request.OfferID, request.ExpectedOfferRevision, 0, request.Choice)
}

func (service *Service) RerollGems(ctx context.Context, account, session string, request GemRerollRequest) (CommandResult, error) {
	common := GemOfferRequest{IdempotencyKey: request.IdempotencyKey, RawBody: request.RawBody, ExpectedRevision: request.ExpectedRevision, ExpectedCatalogVersion: request.ExpectedCatalogVersion, SourceSaveRevision: request.SourceSaveRevision, WriterGeneration: request.WriterGeneration, RunID: request.RunID, CompletedRounds: request.CompletedRounds}
	return service.gemCommand(ctx, account, session, common, "gem_reroll", request.OfferID, request.ExpectedOfferRevision, request.ExpectedRerollCount, "")
}

func (service *Service) PurchaseGems(ctx context.Context, account, session string, request GemOfferRequest) (CommandResult, error) {
	return service.gemCommand(ctx, account, session, request, "gem_purchase", "", 0, 0, "")
}

func (service *Service) gemCommand(ctx context.Context, accountID, sessionID string, request GemOfferRequest, kind, offerID string, offerRevision int64, expectedUsed int, choice string) (CommandResult, error) {
	account, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	session, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	identity, err := newCommandIdentity(request.IdempotencyKey, kind, kind, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	q := dbgen.New(service.database)
	// Receipts are immutable, including generation 7/8 bodies. Lookup precedes all
	// compatibility, writer, active-run and progression checks.
	if result, found, err := storedCommandResult[CommandResult](ctx, q, account, identity); found || err != nil {
		return result, err
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q = dbgen.New(tx)
	// All writers use writer -> save header -> wallet -> active run lock order.
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
	wallet, err := q.GetPlayerEconomyForUpdate(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, ErrNotBootstrapped
	}
	if err != nil {
		return CommandResult{}, err
	}
	if result, found, err := storedCommandResult[CommandResult](ctx, q, account, identity); found || err != nil {
		return result, err
	}
	if gamesave.ClientCompatibilityFromBody(request.RawBody) < gamesave.RunAuthorityClientCompatibilityVersion {
		return CommandResult{}, gamesave.ErrClientUpdateRequired
	}
	if wallet.AuthorityState != "server_authoritative" {
		return CommandResult{}, ErrNotBootstrapped
	}
	if writer.Generation == 0 || request.WriterGeneration <= 0 {
		return CommandResult{}, ErrWriterRequired
	}
	if writer.Generation != request.WriterGeneration || writer.SessionID != session {
		return CommandResult{}, ErrWriterReplaced
	}
	runID, err := parseUUID(request.RunID)
	if err != nil || request.RunID != formatUUID(runID) || request.CompletedRounds < 0 || request.CompletedRounds >= 40 {
		return CommandResult{}, ErrInvalidCommand
	}
	source, err := q.GetSaveSnapshot(ctx, account)
	if err != nil {
		return CommandResult{}, err
	}
	adoptedInTransaction := false
	if !wallet.RunAuthorityEnabled {
		if err = runstate.AdoptCanonical(ctx, q, account, source.ActiveRun); err != nil {
			return CommandResult{}, runLifecycleError(err)
		}
		adoptedInTransaction = true
	}
	authority, err := runstate.RequireActive(ctx, q, account, runID)
	if err != nil {
		return CommandResult{}, ErrGemOfferConflict
	}
	if len(authority.GemDeck) > 0 {
		// Deck runs present candidates locally and are reconciled at close.
		if gamesave.ClientCompatibilityFromBody(request.RawBody) < GemDeckClientCompatibilityVersion {
			return CommandResult{}, gamesave.ErrClientUpdateRequired
		}
		return CommandResult{}, ErrGemOfferConflict
	}
	var run gemRewardRun
	if json.Unmarshal(source.ActiveRun, &run) != nil || run.RunID != request.RunID || run.CompletedRounds != request.CompletedRounds {
		return CommandResult{}, ErrInvalidCommand
	}
	if err = runstate.ValidateOwnership(source.ActiveRun, authority.OwnedGems); err != nil {
		return CommandResult{}, ErrGemOfferConflict
	}
	var purchased *GemOfferState
	if len(authority.PurchasedOffer) > 0 && string(authority.PurchasedOffer) != "null" {
		if json.Unmarshal(authority.PurchasedOffer, &purchased) != nil {
			return CommandResult{}, ErrGemOfferConflict
		}
	}
	var offer *GemOfferState
	isPurchase := kind == "gem_purchase" || (purchased != nil && purchased.OfferID == offerID && kind == "gem_choose")
	if isPurchase {
		if purchased != nil && purchased.Status == "pending" {
			offer = purchased
		}
	} else if request.CompletedRounds > 0 && request.CompletedRounds%5 == 0 {
		row, rowErr := q.GetGemOffer(ctx, dbgen.GetGemOfferParams{AccountID: account, RunID: runID, RewardWave: int32(request.CompletedRounds)})
		if rowErr == nil {
			offer, err = gemOfferFromRow(row)
			if err != nil {
				return CommandResult{}, err
			}
		} else if !errors.Is(rowErr, pgx.ErrNoRows) {
			return CommandResult{}, rowErr
		}
	} else {
		return CommandResult{}, ErrInvalidCommand
	}
	recovering := (kind == "gem_offer" || kind == "gem_purchase") && offer != nil
	system, err := q.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	if recovering {
		// Semantic recovery is a read. A new key cannot produce receipts, revisions,
		// debit, fresh entropy or unbounded database rows. Exact mutation keys above
		// still return their original immutable outcome.
		// The one-time legacy migration can have created a purchased offer in this
		// transaction, however. Persist that adoption before exposing its UUID;
		// clients with an existing writer need not have made a new writer claim.
		if adoptedInTransaction {
			if err = tx.Commit(ctx); err != nil {
				return CommandResult{}, err
			}
		}
		return CommandResult{GemReceipt: newGemReceipt(wallet, system), GemOffer: offer, SaveRevision: source.Revision, ServerSavedAt: source.UpdatedAt.Time.UTC()}, nil
	}
	if kind == "gem_choose" || kind == "gem_reroll" {
		if offer == nil || offer.Status != "pending" || offer.OfferID != offerID || offer.Revision != offerRevision {
			return CommandResult{}, ErrGemOfferConflict
		}
	}
	if header.Revision != request.SourceSaveRevision {
		return CommandResult{}, ErrSaveRevisionConflict
	}
	if err = validateExpectedEconomy(wallet, request.ExpectedRevision, request.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	if err = gamesave.ValidateContentClient(source.Progression, source.ActiveRun, gamesave.ClientCompatibilityFromBody(request.RawBody)); err != nil {
		return CommandResult{}, err
	}
	if run.Shards < 0 {
		return CommandResult{}, ErrInvalidCommand
	}
	if kind == "gem_purchase" {
		if run.Phase != "preparation" && run.Phase != "wave" {
			return CommandResult{}, ErrInvalidCommand
		}
		if run.Shards < 20 {
			return CommandResult{}, ErrInsufficientGemShards
		}
		if authority.PurchaseSequence == math.MaxInt64 {
			return CommandResult{}, ErrInvalidCommand
		}
	} else {
		if run.Phase != "reward" || run.Used < 0 || run.Used > 3 {
			return CommandResult{}, ErrInvalidCommand
		}
		if isPurchase {
			if !run.Purchased || run.OfferID != offerID {
				return CommandResult{}, ErrGemOfferConflict
			}
		} else if run.Purchased || run.LegacyPaid {
			return CommandResult{}, ErrInvalidCommand
		}
	}
	cost := int64(0)
	switch kind {
	case "gem_offer", "gem_purchase":
		if purchased != nil && purchased.Status == "pending" {
			return CommandResult{}, ErrGemOfferConflict
		}
		latest, latestErr := q.GetLatestGemOffer(ctx, dbgen.GetLatestGemOfferParams{AccountID: account, RunID: runID})
		if latestErr == nil {
			previous, e := gemOfferFromRow(latest)
			if e != nil {
				return CommandResult{}, e
			}
			if previous.Status != "chosen" || (!isPurchase && previous.RewardWave >= request.CompletedRounds) {
				return CommandResult{}, ErrGemOfferConflict
			}
		} else if !errors.Is(latestErr, pgx.ErrNoRows) {
			return CommandResult{}, latestErr
		}
		available, e := availableGems(source.Progression)
		if e != nil {
			return CommandResult{}, e
		}
		options, e := sampleGems(rand.Reader, available, nil)
		if e != nil {
			return CommandResult{}, e
		}
		id, e := newGemUUID()
		if e != nil {
			return CommandResult{}, e
		}
		inventory := run.Inventory
		if inventory == nil {
			inventory = map[string]int64{}
		}
		offer = &GemOfferState{Kind: "wave", OfferID: formatUUID(id), RunID: request.RunID, RewardWave: request.CompletedRounds, Revision: 1, TotalUsed: int(authority.TotalUsed), GemOptions: options, Status: "pending", GemInventory: inventory, GemShards: run.Shards}
		if isPurchase {
			authority.PurchaseSequence++
			offer.Kind = "purchase"
			offer.PurchaseSequence = authority.PurchaseSequence
			offer.ReturnPhase = run.Phase
			offer.GemShards -= 20
		}
	case "gem_reroll", "gem_choose":
		// Saves may rearrange gems into equipment while the choice is open.
		// Project current loose allocation, never an earlier offer checkpoint.
		if offer != nil {
			offer.GemInventory = run.Inventory
			if offer.GemInventory == nil {
				offer.GemInventory = map[string]int64{}
			}
		}
		if offer == nil || offer.Status != "pending" || offer.OfferID != offerID || offer.Revision != offerRevision || run.OfferID != offerID {
			return CommandResult{}, ErrGemOfferConflict
		}
		if offer.TotalUsed != int(authority.TotalUsed) {
			return CommandResult{}, ErrGemRerollConflict
		}
		if kind == "gem_reroll" {
			if isPurchase || offer.Kind == "purchase" {
				return CommandResult{}, ErrInvalidCommand
			}
			if expectedUsed != offer.TotalUsed {
				return CommandResult{}, ErrGemRerollConflict
			}
			if offer.TotalUsed >= 3 {
				return CommandResult{}, ErrGemRerollLimit
			}
			if offer.TotalUsed > 0 {
				cost = 1
			}
			if wallet.GemResetTickets < cost {
				return CommandResult{}, ErrInsufficientGemResetTickets
			}
			available, e := availableGems(source.Progression)
			if e != nil {
				return CommandResult{}, e
			}
			offer.GemOptions, e = sampleGems(rand.Reader, available, offer.GemOptions)
			if e != nil {
				return CommandResult{}, e
			}
			offer.TotalUsed++
			authority.TotalUsed++
		} else {
			if choice == "shards" {
				if isPurchase || offer.GemShards > math.MaxInt64-10 {
					return CommandResult{}, ErrInvalidCommand
				}
				offer.GrantedShards = 10
				offer.GemShards += 10
			} else if contains(offer.GemOptions, choice) {
				if offer.GemInventory[choice] == math.MaxInt64 {
					return CommandResult{}, ErrInvalidCommand
				}
				if err = runstate.Grant(&authority, choice, 1); err != nil {
					return CommandResult{}, ErrInvalidCommand
				}
				offer.GrantedGem = choice
				offer.GemInventory[choice]++
			} else {
				return CommandResult{}, ErrInvalidCommand
			}
			offer.Status = "chosen"
			offer.Choice = choice
		}
		offer.Revision++
	default:
		return CommandResult{}, ErrInvalidCommand
	}
	resultingRevision := wallet.Revision + 1
	offer.EconomyRevision = resultingRevision
	command, err := q.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{AccountID: account, IdempotencyKey: identity.key, CommandType: kind, RequestHash: identity.requestHash, ExpectedRevision: int8(wallet.Revision), ResultingRevision: resultingRevision, AuthorityEpoch: system.AuthorityEpoch, CatalogVersion: int4(CatalogVersion), RngAlgorithmVersion: int4(2), ResponsePayload: []byte(`{}`)})
	if err != nil {
		return CommandResult{}, err
	}
	payload, err := json.Marshal(offer)
	if err != nil {
		return CommandResult{}, err
	}
	if isPurchase {
		authority.PurchasedOffer = payload
	} else {
		if kind == "gem_offer" {
			id, _ := parseUUID(offer.OfferID)
			err = q.CreateGemOffer(ctx, dbgen.CreateGemOfferParams{AccountID: account, RunID: runID, RewardWave: int32(offer.RewardWave), OfferID: id, Revision: offer.Revision, Payload: payload, CommandID: command.ID})
		} else {
			var changed int64
			changed, err = q.UpdateGemOffer(ctx, dbgen.UpdateGemOfferParams{AccountID: account, RunID: runID, RewardWave: int32(offer.RewardWave), Revision: offer.Revision, Payload: payload, CommandID: command.ID})
			if err == nil && changed != 1 {
				return CommandResult{}, ErrGemOfferConflict
			}
		}
		if err != nil {
			return CommandResult{}, err
		}
		if err = q.UpsertGemReroll(ctx, dbgen.UpsertGemRerollParams{AccountID: account, RunID: runID, RewardWave: int32(offer.RewardWave), TotalUsed: int32(offer.TotalUsed), GemOptions: offer.GemOptions, CommandID: command.ID}); err != nil {
			return CommandResult{}, err
		}
	}
	if err = runstate.Save(ctx, q, account, authority); err != nil {
		return CommandResult{}, err
	}
	if err = q.EnableGemOffers(ctx, account); err != nil {
		return CommandResult{}, err
	}
	if err = q.SetGemResetTickets(ctx, dbgen.SetGemResetTicketsParams{AccountID: account, GemResetTickets: wallet.GemResetTickets - cost}); err != nil {
		return CommandResult{}, err
	}
	wallet, err = q.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{AccountID: account, Revision: resultingRevision, FreeDiamonds: wallet.FreeDiamonds, PaidDiamonds: wallet.PaidDiamonds, ModuleTickets: wallet.ModuleTickets, ModuleDrawCount: wallet.ModuleDrawCount, ModuleTicketPurchaseCount: wallet.ModuleTicketPurchaseCount, ModuleItemSequence: wallet.ModuleItemSequence, ResearchSlotTwoUnlocked: wallet.ResearchSlotTwoUnlocked, Revision_2: wallet.Revision})
	if err != nil {
		return CommandResult{}, err
	}
	if cost > 0 {
		order := int16(0)
		if err = createLedger(ctx, q, command.ID, &order, "gem_reset_ticket", -cost, wallet.GemResetTickets, "gem_reroll"); err != nil {
			return CommandResult{}, err
		}
	}
	activeRun, err := projectGemOffer(source.ActiveRun, offer)
	if err != nil {
		return CommandResult{}, err
	}
	if err = runstate.ValidateOwnership(activeRun, authority.OwnedGems); err != nil {
		return CommandResult{}, ErrGemOfferConflict
	}
	if err = q.UpsertSaveActiveRun(ctx, dbgen.UpsertSaveActiveRunParams{AccountID: account, Payload: activeRun}); err != nil {
		return CommandResult{}, err
	}
	advanced, err := q.AdvanceSaveHeader(ctx, dbgen.AdvanceSaveHeaderParams{AccountID: account, SchemaVersion: source.SchemaVersion, ClientSavedAtMillis: source.ClientSavedAtMillis, Revision: source.Revision})
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{GemReceipt: newGemReceipt(wallet, system), GemOffer: offer, SaveRevision: advanced.Revision, ServerSavedAt: advanced.UpdatedAt.Time.UTC()}
	if err = storeCommandResult(ctx, q, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return CommandResult{}, err
	}
	return result, nil
}

func newGemUUID() (pgtype.UUID, error) {
	return gemUUIDFrom(rand.Reader)
}

func projectGemOffer(raw []byte, offer *GemOfferState) ([]byte, error) {
	var run map[string]json.RawMessage
	if json.Unmarshal(raw, &run) != nil || run == nil {
		return nil, ErrInvalidCommand
	}
	fields := map[string]any{"paidGemRoll": false, "gemEconomyRevision": offer.EconomyRevision, "gemOfferId": offer.OfferID, "gemOfferRevision": offer.Revision, "gemOfferStatus": offer.Status, "gemRerollsUsed": offer.TotalUsed, "gemInventory": offer.GemInventory, "gemShards": offer.GemShards, "rewardOptions": offer.GemOptions}
	var previousID string
	_ = json.Unmarshal(run["gemOfferId"], &previousID)
	if previousID != offer.OfferID {
		fields["gemOfferEquipRevision"] = 0
	}

	if offer.Kind == "purchase" {
		fields["phase"] = "reward"
		fields["isPurchasedGemReward"] = true
		fields["rewardReturnPhase"] = offer.ReturnPhase
	}
	if offer.Status == "chosen" {
		fields["phase"] = "preparation"
		if offer.Kind == "purchase" {
			fields["phase"] = offer.ReturnPhase
		}
		fields["rewardOptions"] = []string{}
		fields["isPurchasedGemReward"] = false
		fields["rewardReturnPhase"] = nil
	}
	for key, value := range fields {
		encoded, err := json.Marshal(value)
		if err != nil {
			return nil, err
		}
		run[key] = encoded
	}
	return json.Marshal(run)
}
