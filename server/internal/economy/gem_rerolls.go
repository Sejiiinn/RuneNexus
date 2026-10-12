package economy

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"sort"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	stageprogression "github.com/Sejiiinn/RuneNexus/server/internal/progression"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

var gemTypes = []string{"attackSpeed", "range", "physicalDamage", "elementalDamage", "lightWeapon", "heavyWeapon", "damageOverTime", "explosion", "chain", "criticalChance", "aimSpeed", "damageAmplifier", "armorPiercing", "multipleProjectiles"}

type gemRewardRun struct {
	RunID           string   `json:"economyRunId"`
	Phase           string   `json:"phase"`
	CompletedRounds int      `json:"completedRounds"`
	Purchased       bool     `json:"isPurchasedGemReward"`
	LegacyPaid      bool     `json:"paidGemRoll"`
	Used            int      `json:"gemRerollsUsed"`
	Options         []string `json:"rewardOptions"`
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

// This RNG is isolated from combat, ordinary reward and module RNG streams.
// Stable SHA256 ranking makes exact same run/reward/sequence deterministic.
func rerolledGems(runID string, wave, sequence int, available, previous []string) ([]string, error) {
	if len(previous) != 3 || len(available) > 14 {
		return nil, ErrInvalidCommand
	}
	excluded := map[string]bool{}
	for _, gem := range previous {
		if excluded[gem] || !contains(available, gem) {
			return nil, ErrInvalidCommand
		}
		excluded[gem] = true
	}
	type ranked struct {
		gem  string
		hash [32]byte
	}
	ranks := make([]ranked, 0, len(available))
	for _, gem := range available {
		if !excluded[gem] {
			ranks = append(ranks, ranked{gem, sha256.Sum256([]byte(fmt.Sprintf("rune-nexus:gem-reroll:v1:%s:%d:%d:%s", runID, wave, sequence, gem)))})
		}
	}
	if len(ranks) < 3 {
		return nil, ErrInvalidCommand
	}
	sort.Slice(ranks, func(i, j int) bool {
		cmp := bytes.Compare(ranks[i].hash[:], ranks[j].hash[:])
		if cmp == 0 {
			return ranks[i].gem < ranks[j].gem
		}
		return cmp < 0
	})
	return []string{ranks[0].gem, ranks[1].gem, ranks[2].gem}, nil
}

func validateGemRerollRun(run gemRewardRun, request GemRerollRequest, latest *GemRerollState) (int, error) {
	if run.RunID != request.RunID || run.Phase != "reward" || run.Purchased || run.LegacyPaid ||
		run.CompletedRounds != request.CompletedRounds || run.CompletedRounds <= 0 || run.CompletedRounds >= 40 || run.CompletedRounds%5 != 0 ||
		len(run.Options) != 3 || run.Used < 0 || run.Used > 3 {
		return 0, ErrInvalidCommand
	}
	// A linked guest run may already have used its one local free reroll.
	// Importing this counter can only reduce its initial server budget.
	used := run.Used
	if latest != nil {
		used = latest.TotalUsed
		if run.CompletedRounds < latest.RewardWave || (run.CompletedRounds == latest.RewardWave && !slices.Equal(run.Options, latest.GemOptions)) {
			return 0, ErrGemRerollConflict
		}
	}
	if used != request.ExpectedRerollCount || run.Used != used {
		return 0, ErrGemRerollConflict
	}
	if used >= 3 {
		return 0, ErrGemRerollLimit
	}
	return used, nil
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
	row, err := queries.GetGemReroll(ctx, dbgen.GetGemRerollParams{AccountID: account, RunID: id})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return gemRerollFromRow(row), nil
}

func (service *Service) RerollGems(ctx context.Context, accountID, sessionID string, request GemRerollRequest) (CommandResult, error) {
	account, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	session, err := parseUUID(sessionID)
	if err != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	runID, err := parseUUID(request.RunID)
	if err != nil || request.RunID != formatUUID(runID) {
		return CommandResult{}, ErrInvalidCommand
	}
	// Domain-separate the hash so this key cannot replay another command's body.
	key, hash, err := requestIdentity(request.IdempotencyKey, append([]byte("gem_reroll\n"), request.RawBody...))
	if err != nil {
		return CommandResult{}, err
	}
	queries := dbgen.New(service.database)
	receiptParams := dbgen.GetEconomyCommandParams{AccountID: account, IdempotencyKey: key}
	stored, err := queries.GetEconomyCommand(ctx, receiptParams)
	if err == nil {
		return existingCommandResult[CommandResult](stored, hash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, err
	}
	// Exact receipts precede all compatibility and current-writer checks.
	if gamesave.ClientCompatibilityFromBody(request.RawBody) < gamesave.GemRerollClientCompatibilityVersion {
		return CommandResult{}, gamesave.ErrClientUpdateRequired
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := dbgen.New(tx)
	// Acquire locks in the shared writer -> save -> economy order. Recheck the
	// receipt before validating any current state, including a replaced writer.
	if _, err = q.GetSaveWriterStateForUpdate(ctx, account); errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, ErrWriterRequired
	} else if err != nil {
		return CommandResult{}, fmt.Errorf("lock gem reroll writer: %w", err)
	}
	if _, err = q.GetSaveHeaderForUpdate(ctx, account); errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, ErrSaveRevisionConflict
	} else if err != nil {
		return CommandResult{}, fmt.Errorf("lock gem reroll save: %w", err)
	}
	wallet, err := q.GetPlayerEconomyForUpdate(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, ErrNotBootstrapped
	}
	if err != nil {
		return CommandResult{}, err
	}
	stored, err = q.GetEconomyCommand(ctx, receiptParams)
	if err == nil {
		return existingCommandResult[CommandResult](stored, hash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, err
	}
	if wallet.AuthorityState != "server_authoritative" {
		return CommandResult{}, ErrNotBootstrapped
	}
	_, source, err := lockWriterAndSave(ctx, q, account, session, request.WriterGeneration, request.SourceSaveRevision, request.RawBody)
	if err != nil {
		return CommandResult{}, err
	}
	if err = validateExpectedEconomy(wallet, request.ExpectedRevision, request.ExpectedCatalogVersion); err != nil {
		return CommandResult{}, err
	}
	var run gemRewardRun
	if json.Unmarshal(source.ActiveRun, &run) != nil {
		return CommandResult{}, ErrInvalidCommand
	}
	var latest *GemRerollState
	row, err := q.GetGemReroll(ctx, dbgen.GetGemRerollParams{AccountID: account, RunID: runID})
	if err == nil {
		latest = gemRerollFromRow(row)
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, err
	}
	used, err := validateGemRerollRun(run, request, latest)
	if err != nil {
		return CommandResult{}, err
	}
	cost := int64(0)
	if used > 0 {
		cost = 1
	}
	if wallet.GemResetTickets < cost {
		return CommandResult{}, ErrInsufficientGemResetTickets
	}
	available, err := availableGems(source.Progression)
	if err != nil {
		return CommandResult{}, err
	}
	options, err := rerolledGems(request.RunID, request.CompletedRounds, used+1, available, run.Options)
	if err != nil {
		return CommandResult{}, err
	}
	system, err := q.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	command, err := q.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{
		AccountID: account, IdempotencyKey: key, CommandType: "gem_reroll", RequestHash: hash,
		ExpectedRevision: int8(wallet.Revision), ResultingRevision: wallet.Revision + 1,
		AuthorityEpoch: system.AuthorityEpoch, CatalogVersion: int4(CatalogVersion),
		RngAlgorithmVersion: int4(1), ResponsePayload: []byte(`{}`),
	})
	if err != nil {
		return CommandResult{}, err
	}
	if err = q.SetGemResetTickets(ctx, dbgen.SetGemResetTicketsParams{AccountID: account, GemResetTickets: wallet.GemResetTickets - cost}); err != nil {
		return CommandResult{}, err
	}
	if err = q.UpsertGemReroll(ctx, dbgen.UpsertGemRerollParams{AccountID: account, RunID: runID, RewardWave: int32(request.CompletedRounds), TotalUsed: int32(used + 1), GemOptions: options, CommandID: command.ID}); err != nil {
		return CommandResult{}, err
	}
	updated, err := q.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{
		AccountID: account, Revision: wallet.Revision + 1, FreeDiamonds: wallet.FreeDiamonds, PaidDiamonds: wallet.PaidDiamonds,
		ModuleTickets: wallet.ModuleTickets, ModuleDrawCount: wallet.ModuleDrawCount, ModuleTicketPurchaseCount: wallet.ModuleTicketPurchaseCount,
		ModuleItemSequence: wallet.ModuleItemSequence, ResearchSlotTwoUnlocked: wallet.ResearchSlotTwoUnlocked, Revision_2: wallet.Revision,
	})
	if err != nil {
		return CommandResult{}, err
	}
	order := int16(0)
	if err = createLedger(ctx, q, command.ID, &order, "gem_reset_ticket", -cost, updated.GemResetTickets, "gem_reroll"); err != nil {
		return CommandResult{}, err
	}
	snapshot, err := service.snapshot(ctx, q, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{Snapshot: snapshot, GemReroll: snapshot.GemReroll}
	if err = storeCommandResult(ctx, q, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return CommandResult{}, err
	}
	return result, nil
}
