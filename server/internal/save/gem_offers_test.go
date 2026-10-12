package save

import (
	"encoding/json"
	"errors"
	"testing"
)

func TestGemOfferSaveProjectionGuardsOwnershipAndConsumption(t *testing.T) {
	pending := gemOfferSaveProjection{OfferID: "server-offer", Revision: 2, Status: "pending", Used: 1, Options: []string{"range", "chain", "explosion"}, Inventory: map[string]int64{"range": 2}, Shards: 7}
	raw, _ := json.Marshal(pending)
	base := gemOfferSaveRun{RunID: "run", Wave: 5, Phase: "reward", Used: 1, Options: pending.Options, OfferID: pending.OfferID, Revision: 2, Status: "pending", Inventory: pending.Inventory, Shards: 7}
	if err := validateGemOfferProjection(base, 5, raw); err != nil {
		t.Fatal(err)
	}
	abandoned := base
	abandoned.Phase = "failure"
	if err := validateGemOfferProjection(abandoned, 5, raw); err != nil {
		t.Fatalf("terminal abandon lost pending offer metadata: %v", err)
	}
	for _, test := range []struct {
		name   string
		change func(*gemOfferSaveRun)
	}{
		{"remove identity", func(r *gemOfferSaveRun) { r.OfferID = "" }},
		{"rollback revision", func(r *gemOfferSaveRun) { r.Revision = 1 }},
		{"fabricate completion", func(r *gemOfferSaveRun) { r.Status = "chosen" }},
		{"rollback budget", func(r *gemOfferSaveRun) { r.Used = 0 }},
		{"change options", func(r *gemOfferSaveRun) { r.Options = []string{"attackSpeed", "chain", "explosion"} }},
		{"rollback economy marker", func(r *gemOfferSaveRun) { r.EconomyRevision = 1 }},
		{"grant shards", func(r *gemOfferSaveRun) { r.Shards = 17 }},
		{"skip reward", func(r *gemOfferSaveRun) { r.Phase = "preparation" }},
		{"advance unresolved", func(r *gemOfferSaveRun) { r.Wave = 10 }},
		{"disguise purchased", func(r *gemOfferSaveRun) { r.Purchased = true }},
	} {
		t.Run(test.name, func(t *testing.T) {
			changed := base
			test.change(&changed)
			if err := validateGemOfferProjection(changed, 5, raw); !errors.Is(err, ErrGemOfferConflict) {
				t.Fatalf("accepted mutation: %+v %v", changed, err)
			}
		})
	}
	chosen := pending
	chosen.Revision = 3
	chosen.Status = "chosen"
	chosen.Shards = 17
	raw, _ = json.Marshal(chosen)
	done := base
	done.Revision = 3
	done.Status = "chosen"
	done.Phase = "preparation"
	done.Options = nil
	done.Shards = 17
	if err := validateGemOfferProjection(done, 5, raw); err != nil {
		t.Fatal(err)
	}
	reopened := done
	reopened.Phase = "reward"
	if err := validateGemOfferProjection(reopened, 5, raw); !errors.Is(err, ErrGemOfferConflict) {
		t.Fatal("reopened completed wave")
	}
	newer := done
	newer.Wave = 10
	newer.Phase = "reward"
	if err := validateGemOfferProjection(newer, 5, raw); err != nil {
		t.Fatalf("next wave pending issuance rejected: %v", err)
	}
	// A client cannot manufacture a purchased choice by toggling reward flags.
	purchased := done
	purchased.Phase = "reward"
	purchased.Purchased = true
	purchased.Options = []string{"attackSpeed", "range", "chain"}
	if err := validateGemOfferProjection(purchased, 5, raw); !errors.Is(err, ErrGemOfferConflict) {
		t.Fatalf("unissued purchased path accepted: %v", err)
	}
}

func TestPendingPurchaseBindsReturnPhaseAndAllowsOwnershipAllocation(t *testing.T) {
	offer := gemOfferSaveProjection{Kind: "purchase", OfferID: "purchase", Revision: 1, Status: "pending", Used: 2, Options: []string{"range", "chain", "explosion"}, Shards: 5, ReturnPhase: "wave", EconomyRevision: 8}
	raw, _ := json.Marshal(offer)
	run := gemOfferSaveRun{RunID: "run", Wave: 8, Phase: "reward", Purchased: true, Used: 2, Options: offer.Options, OfferID: offer.OfferID, Revision: 1, Status: "pending", Shards: 5, ReturnPhase: "wave", EconomyRevision: 8, Inventory: map[string]int64{}}
	if err := validateGemOfferProjection(run, 8, raw); err != nil {
		t.Fatal(err)
	}
	run.ReturnPhase = "preparation"
	if err := validateGemOfferProjection(run, 8, raw); !errors.Is(err, ErrGemOfferConflict) {
		t.Fatal("purchase return phase changed")
	}
}

func TestGemOfferCompatibilityRequiresGenerationEight(t *testing.T) {
	active := []byte(`{"gemOfferId":"offer","gemOfferRevision":1}`)
	if err := ValidateContentClient(nil, active, 7); !errors.Is(err, ErrClientUpdateRequired) {
		t.Fatalf("old codec accepted: %v", err)
	}
	if err := ValidateContentClient(nil, active, 8); err != nil {
		t.Fatal(err)
	}
}
