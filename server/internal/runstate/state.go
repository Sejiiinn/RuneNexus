package runstate

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math"
	"slices"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

type State struct {
	RunID            pgtype.UUID
	StageNumber      int32
	Status           string
	OwnedGems        map[string]int64
	TotalUsed        int32
	PurchasedOffer   json.RawMessage
	PurchaseSequence int64
	LegacyImported   bool
}

// RequiresCurrentClient also covers pinned pre-economy saves: no old write may
// advance the immutable migration source before adoption.
func RequiresCurrentClient(ctx context.Context, q *dbgen.Queries, account pgtype.UUID) (bool, error) {
	state, err := q.GetAccountRunAuthority(ctx, account)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return state.Adopted || state.LegacySourceRevision.Valid, nil
}

func FromRow(row dbgen.EconomyRun) (State, error) {
	state := State{RunID: row.RunID, StageNumber: row.StageNumber, Status: row.Status, TotalUsed: row.TotalUsed, PurchasedOffer: row.PurchasedOffer, PurchaseSequence: row.PurchaseSequence, LegacyImported: row.LegacyImported}
	if json.Unmarshal(row.OwnedGems, &state.OwnedGems) != nil || state.OwnedGems == nil {
		return State{}, ErrConflict
	}
	for gem, count := range state.OwnedGems {
		if !ValidGem(gem) || count < 0 {
			return State{}, ErrConflict
		}
	}
	return state, nil
}

// Caller holds the writer, save header and wallet locks, in that order.
func RequireActive(ctx context.Context, q *dbgen.Queries, account, runID pgtype.UUID) (State, error) {
	row, err := q.GetEconomyRunForUpdate(ctx, dbgen.GetEconomyRunForUpdateParams{AccountID: account, RunID: runID})
	if errors.Is(err, pgx.ErrNoRows) {
		return State{}, ErrConflict
	}
	if err != nil {
		return State{}, err
	}
	if row.Status != "active" {
		return State{}, ErrConflict
	}
	return FromRow(row)
}

func Save(ctx context.Context, q *dbgen.Queries, account pgtype.UUID, state State) error {
	if state.Status != "active" || state.TotalUsed < 0 || state.TotalUsed > 3 || state.PurchaseSequence < 0 {
		return ErrConflict
	}
	if state.OwnedGems == nil {
		state.OwnedGems = map[string]int64{}
	}
	for gem, count := range state.OwnedGems {
		if !ValidGem(gem) || count < 0 {
			return ErrConflict
		}
	}
	owned, err := json.Marshal(state.OwnedGems)
	if err != nil {
		return err
	}
	changed, err := q.UpdateEconomyRun(ctx, dbgen.UpdateEconomyRunParams{AccountID: account, RunID: state.RunID, OwnedGems: owned, TotalUsed: state.TotalUsed, PurchasedOffer: state.PurchasedOffer, PurchaseSequence: state.PurchaseSequence})
	if err != nil {
		return err
	}
	if changed != 1 {
		return ErrConflict
	}
	return nil
}

func Grant(state *State, gem string, quantity int64) error {
	if state == nil || state.Status != "active" || !ValidGem(gem) || quantity <= 0 || state.OwnedGems[gem] > math.MaxInt64-quantity {
		return ErrConflict
	}
	if state.OwnedGems == nil {
		state.OwnedGems = map[string]int64{}
	}
	state.OwnedGems[gem] += quantity
	return nil
}

// AdoptCanonical is called once, while the wallet lock is held and its adoption
// flag is false. raw MUST be the pre-existing server save, never an incoming body.
// Even an account without a run adopts now, so future client IDs cannot import.
func AdoptCanonical(ctx context.Context, q *dbgen.Queries, account pgtype.UUID, raw []byte) error {
	if err := q.EnsureAccountRunAuthority(ctx, account); err != nil {
		return err
	}
	authority, err := q.GetAccountRunAuthority(ctx, account)
	if err != nil {
		return err
	}
	if authority.Adopted {
		return q.EnableRunAuthority(ctx, account)
	}
	source, sourceErr := q.GetSaveSnapshot(ctx, account)
	if sourceErr != nil && !errors.Is(sourceErr, pgx.ErrNoRows) {
		return sourceErr
	}
	if !bytes.Equal(bytes.TrimSpace(raw), bytes.TrimSpace(source.ActiveRun)) {
		return ErrConflict
	}
	if authority.LegacySourceRevision.Valid && (sourceErr != nil || source.Revision != authority.LegacySourceRevision.Int64) {
		return ErrConflict
	}
	var run struct {
		RunID       string            `json:"economyRunId"`
		Stage       int32             `json:"stageNumber"`
		Used        int32             `json:"gemRerollsUsed"`
		Phase       string            `json:"phase"`
		Purchased   bool              `json:"isPurchasedGemReward"`
		LegacyPaid  bool              `json:"paidGemRoll"`
		Wave        int32             `json:"completedRounds"`
		Options     []string          `json:"rewardOptions"`
		Inventory   map[string]int64  `json:"gemInventory"`
		Shards      int64             `json:"gemShards"`
		ReturnPhase string            `json:"rewardReturnPhase"`
		Enemies     []json.RawMessage `json:"enemies"`
		SpawnQueue  []json.RawMessage `json:"spawnQueue"`
	}
	if len(raw) > 0 && string(raw) != "null" {
		if json.Unmarshal(raw, &run) != nil {
			return ErrConflict
		}
		if run.RunID == "" {
			if ValidatePristine(raw, run.Stage) != nil {
				return ErrConflict
			}
		} else {
			if !authority.LegacySourceRevision.Valid {
				return ErrConflict
			}
			id, err := ParseUUID(run.RunID)
			if err != nil || run.Stage <= 0 || run.Used < 0 || run.Used > 3 {
				return ErrConflict
			}
			owned, err := ReadOwnedGems(raw)
			if err != nil {
				return err
			}
			budget, budgetErr := q.GetGemReroll(ctx, dbgen.GetGemRerollParams{AccountID: account, RunID: id})
			if budgetErr == nil {
				run.Used = max(run.Used, budget.TotalUsed)
			} else if !errors.Is(budgetErr, pgx.ErrNoRows) {
				return budgetErr
			}
			// Import is not an upsert: an existing tombstone can never become active.
			if _, err = q.GetEconomyRunForUpdate(ctx, dbgen.GetEconomyRunForUpdateParams{AccountID: account, RunID: id}); err == nil {
				return ErrConflict
			} else if !errors.Is(err, pgx.ErrNoRows) {
				return err
			}
			encoded, _ := json.Marshal(owned)
			if _, err = q.CreateEconomyRun(ctx, dbgen.CreateEconomyRunParams{AccountID: account, RunID: id, StageNumber: run.Stage, OwnedGems: encoded, TotalUsed: run.Used, LegacyImported: true}); err != nil {
				return err
			}
			if run.Phase == "reward" && (run.Purchased || run.LegacyPaid) {
				if len(run.Options) != 3 || run.Wave < 0 || run.Wave > 40 || run.Shards < 0 {
					return ErrConflict
				}
				for i, gem := range run.Options {
					if !ValidGem(gem) || slices.Contains(run.Options[:i], gem) {
						return ErrConflict
					}
				}
				if run.ReturnPhase == "" {
					run.ReturnPhase = "preparation"
					if len(run.Enemies) > 0 || len(run.SpawnQueue) > 0 {
						run.ReturnPhase = "wave"
					}
				}
				if run.ReturnPhase != "preparation" && run.ReturnPhase != "wave" {
					return ErrConflict
				}
				offerID := pgtype.UUID{Valid: true}
				if _, err = rand.Read(offerID.Bytes[:]); err != nil {
					return err
				}
				offerID.Bytes[6] = (offerID.Bytes[6] & 0x0f) | 0x40
				offerID.Bytes[8] = (offerID.Bytes[8] & 0x3f) | 0x80
				if run.Inventory == nil {
					run.Inventory = map[string]int64{}
				}
				purchase, _ := json.Marshal(map[string]any{"kind": "purchase", "offerId": FormatUUID(offerID), "runId": FormatUUID(id), "rewardWave": run.Wave, "revision": 1, "totalUsed": run.Used, "gemOptions": run.Options, "status": "pending", "choice": "", "grantedGem": "", "grantedShards": 0, "gemInventory": run.Inventory, "gemShards": run.Shards, "returnPhase": run.ReturnPhase, "purchaseSequence": 1, "legacyImported": true})
				if err = Save(ctx, q, account, State{RunID: id, StageNumber: run.Stage, Status: "active", OwnedGems: owned, TotalUsed: run.Used, PurchasedOffer: purchase, PurchaseSequence: 1, LegacyImported: true}); err != nil {
					return err
				}
			}
			// Already settled legacy runs enter as closed tombstones. Their terminal
			// checkpoint can remain visible, but cannot earn another offer or reward.
			_, settledErr := q.GetLegacyRunSettlementReceipt(ctx, dbgen.GetLegacyRunSettlementReceiptParams{AccountID: account, RewardKey: "run:" + FormatUUID(id) + ":settlement"})
			if settledErr == nil {
				if _, err = q.CloseEconomyRun(ctx, dbgen.CloseEconomyRunParams{AccountID: account, RunID: id}); err != nil {
					return err
				}
			} else if !errors.Is(settledErr, pgx.ErrNoRows) {
				return settledErr
			}
		}
	}
	if err := q.MarkAccountRunAdopted(ctx, account); err != nil {
		return err
	}
	return q.EnableRunAuthority(ctx, account)
}

func ParseUUID(value string) (pgtype.UUID, error) {
	if len(value) != 36 || value[8] != '-' || value[13] != '-' || value[18] != '-' || value[23] != '-' {
		return pgtype.UUID{}, ErrConflict
	}
	decoded, err := hex.DecodeString(value[:8] + value[9:13] + value[14:18] + value[19:23] + value[24:])
	if err != nil {
		return pgtype.UUID{}, ErrConflict
	}
	result := pgtype.UUID{Valid: true}
	copy(result.Bytes[:], decoded)
	return result, nil
}

func FormatUUID(value pgtype.UUID) string {
	if !value.Valid {
		return ""
	}
	v := hex.EncodeToString(value.Bytes[:])
	return v[:8] + "-" + v[8:12] + "-" + v[12:16] + "-" + v[16:20] + "-" + v[20:]
}
