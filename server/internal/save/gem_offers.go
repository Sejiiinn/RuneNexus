package save

import (
	"context"
	"encoding/json"
	"errors"
	"slices"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

var ErrGemOfferConflict = errors.New("server-owned gem offer must be restored")

type gemOfferSaveRun struct {
	RunID           string           `json:"economyRunId"`
	Wave            int              `json:"completedRounds"`
	Phase           string           `json:"phase"`
	Purchased       bool             `json:"isPurchasedGemReward"`
	LegacyPaid      bool             `json:"paidGemRoll"`
	Used            int              `json:"gemRerollsUsed"`
	Options         []string         `json:"rewardOptions"`
	OfferID         string           `json:"gemOfferId"`
	Revision        int64            `json:"gemOfferRevision"`
	Status          string           `json:"gemOfferStatus"`
	Inventory       map[string]int64 `json:"gemInventory"`
	Shards          int64            `json:"gemShards"`
	ReturnPhase     string           `json:"rewardReturnPhase"`
	EconomyRevision int64            `json:"gemEconomyRevision"`
}

type gemOfferSaveProjection struct {
	OfferID         string           `json:"offerId"`
	Revision        int64            `json:"revision"`
	Status          string           `json:"status"`
	Used            int              `json:"totalUsed"`
	Options         []string         `json:"gemOptions"`
	Inventory       map[string]int64 `json:"gemInventory"`
	Shards          int64            `json:"gemShards"`
	Kind            string           `json:"kind"`
	ReturnPhase     string           `json:"returnPhase"`
	Wave            int32            `json:"rewardWave"`
	EconomyRevision int64            `json:"economyRevision"`
	LegacyImported  bool             `json:"legacyImported"`
}

// This adapter protects reward presentation and consumption markers. The run
// aggregate independently protects identity and exact gem totals. Combat and
// shard earnings remain client reports; neither wave nor purchased grants do.
func validateGemOfferSave(ctx context.Context, q *dbgen.Queries, account pgtype.UUID, raw []byte, client int) error {
	if len(raw) == 0 || string(raw) == "null" {
		return nil
	}
	var run gemOfferSaveRun
	if json.Unmarshal(raw, &run) != nil {
		return ErrGemOfferConflict
	}
	id, err := parseUUID(run.RunID)
	if err != nil {
		if run.OfferID != "" || run.Revision != 0 || run.Status != "" {
			return ErrGemOfferConflict
		}
		return nil
	}
	if deckRun, err := q.GetEconomyRun(ctx, dbgen.GetEconomyRunParams{AccountID: account, RunID: id}); err == nil && len(deckRun.GemDeck) > 0 {
		return nil
	} else if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	if client < RunAuthorityClientCompatibilityVersion {
		// Pre-adoption compatibility only. Adopted accounts use the exact run
		// aggregate validator before entering this presentation-state adapter.
		grants, err := q.ListRunGemGrants(ctx, dbgen.ListRunGemGrantsParams{AccountID: account, RunID: id})
		if err != nil {
			return err
		}
		minimum := make(map[string]int64, len(grants))
		for _, grant := range grants {
			minimum[grant.Gem] = grant.Quantity
		}
		if err = validateGemOwnershipFloor(raw, minimum); err != nil {
			return err
		}
	}
	row, err := q.GetLatestGemOffer(ctx, dbgen.GetLatestGemOfferParams{AccountID: account, RunID: id})
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	if client >= RunAuthorityClientCompatibilityVersion {
		aggregate, runErr := q.GetEconomyRun(ctx, dbgen.GetEconomyRunParams{AccountID: account, RunID: id})
		if runErr != nil && !errors.Is(runErr, pgx.ErrNoRows) {
			return runErr
		}
		if runErr == nil && len(aggregate.PurchasedOffer) > 0 {
			var purchase, wave gemOfferSaveProjection
			if json.Unmarshal(aggregate.PurchasedOffer, &purchase) != nil {
				return ErrGemOfferConflict
			}
			if err == nil && json.Unmarshal(row.Payload, &wave) != nil {
				return ErrGemOfferConflict
			}
			if errors.Is(err, pgx.ErrNoRows) || purchase.Status == "pending" || purchase.EconomyRevision > wave.EconomyRevision {
				if purchase.LegacyImported && purchase.Status == "pending" && purchase.EconomyRevision == 0 && run.OfferID != purchase.OfferID {
					// Only the pre-existing canonical paid choice can bridge the
					// one-time import; its server offer is exposed by GET economy.
					source, e := q.GetSaveSnapshot(ctx, account)
					if e != nil {
						return e
					}
					var previous gemOfferSaveRun
					if json.Unmarshal(source.ActiveRun, &previous) != nil || previous.RunID != run.RunID || previous.OfferID != run.OfferID || previous.Revision != run.Revision || previous.Status != run.Status || previous.EconomyRevision != run.EconomyRevision {
						return ErrGemOfferConflict
					}
					run.OfferID = purchase.OfferID
					run.Revision = purchase.Revision
					run.Status = purchase.Status
					if run.ReturnPhase == "" && previous.ReturnPhase == "" {
						run.ReturnPhase = purchase.ReturnPhase
					}
					if run.LegacyPaid && previous.LegacyPaid {
						run.LegacyPaid = false
						run.Purchased = true
					}
				}
				return validateGemOfferProjection(run, purchase.Wave, aggregate.PurchasedOffer)
			}
		}
	}
	if errors.Is(err, pgx.ErrNoRows) {
		if run.OfferID != "" || run.Revision != 0 || run.Status != "" {
			return ErrGemOfferConflict
		}
		if client >= RunAuthorityClientCompatibilityVersion && (run.Purchased || run.LegacyPaid || len(run.Options) != 0 || run.EconomyRevision != 0) {
			return ErrGemOfferConflict
		}
		if client >= GemOfferClientCompatibilityVersion && run.Phase == "reward" && !run.Purchased && !run.LegacyPaid && len(run.Options) != 0 {
			return ErrGemOfferConflict
		}
		return nil
	}
	if err != nil {
		return err
	}
	if client < GemOfferClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}

	return validateGemOfferProjection(run, row.RewardWave, row.Payload)
}

func validateGemOfferProjection(run gemOfferSaveRun, wave int32, payload []byte) error {
	var offer gemOfferSaveProjection
	if err := json.Unmarshal(payload, &offer); err != nil {
		return err
	}

	if run.Wave < int(wave) || run.OfferID != offer.OfferID || run.Revision != offer.Revision || run.Status != offer.Status || run.Used != offer.Used || run.EconomyRevision != offer.EconomyRevision {
		return ErrGemOfferConflict
	}
	if offer.Status == "pending" {
		purchased := offer.Kind == "purchase"
		if run.Wave != int(wave) || (run.Phase != "reward" && run.Phase != "failure") || run.Purchased != purchased || run.LegacyPaid || (purchased && run.ReturnPhase != offer.ReturnPhase) || !slices.Equal(run.Options, offer.Options) || run.Shards != offer.Shards {
			return ErrGemOfferConflict
		}
	} else if offer.Status == "chosen" {
		if run.Purchased || run.LegacyPaid {
			return ErrGemOfferConflict
		}
		if offer.Kind != "purchase" && run.Wave == int(wave) && run.Phase == "reward" {
			return ErrGemOfferConflict
		}
		if len(run.Options) != 0 {
			return ErrGemOfferConflict
		}
	} else {
		return ErrGemOfferConflict
	}
	return nil
}
