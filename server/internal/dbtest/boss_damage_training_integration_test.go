//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"testing"

	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestBossDamageTrainingProtectsWriterAndPreservesHistoricalReceipts(t *testing.T) {
	ctx, f, account := openSaveService(t)
	legacy := gamesave.UpdateRequest{
		IdempotencyKey: firstSaveKey, ClientCompatibilityVersion: 10,
		WriterGeneration: f.writerGeneration,
		RawBody:          []byte(`{"clientCompatibilityVersion":10,"training":"unbought"}`),
		Data: gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`),
			TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`),
			Progression:   json.RawMessage(`{"runes":1000,"clearedStageNumbers":[24]}`)},
	}
	first, err := f.Update(ctx, account, legacy)
	if err != nil {
		t.Fatalf("unbought generation-ten save: %v", err)
	}
	claim, err := f.service.ClaimWriter(ctx, account, f.sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey: secondClaimKey, ClientInstanceID: secondClientID,
		ClientCompatibilityVersion: 10, RawBody: []byte(`{"clientCompatibilityVersion":10,"training":"unbought"}`),
	})
	if err != nil {
		t.Fatalf("unbought generation-ten writer: %v", err)
	}
	f.writerGeneration = claim.WriterGeneration
	purchased := legacy
	purchased.IdempotencyKey = secondSaveKey
	purchased.ExpectedRevision = first.Revision
	purchased.ClientCompatibilityVersion = gamesave.BossDamageTrainingClientCompatibilityVersion
	purchased.RawBody = []byte(`{"clientCompatibilityVersion":11,"training":"purchased"}`)
	purchased.Data.Progression = json.RawMessage(`{"runes":800,"clearedStageNumbers":[24],"bossDamageTrainingUpgradeLevel":1}`)
	second, err := f.Update(ctx, account, purchased)
	if err != nil {
		t.Fatalf("first training purchase: %v", err)
	}
	// Existing exact receipts must resolve before newly introduced content gates.
	replayed, err := f.service.Update(ctx, account, f.sessionID, legacy)
	if err != nil || replayed.Revision != first.Revision {
		t.Fatalf("legacy exact save receipt: %+v %v", replayed, err)
	}
	for index, tc := range []struct {
		name, progression string
		client            int
	}{
		{"old client", `{"runes":800,"clearedStageNumbers":[24]}`, 10},
		{"current stale missing field", `{"runes":800,"clearedStageNumbers":[24]}`, 11},
		{"current stale zero", `{"runes":800,"clearedStageNumbers":[24],"bossDamageTrainingUpgradeLevel":0}`, 11},
	} {
		stale := purchased
		stale.IdempotencyKey = []string{"0198b955-3656-7c40-b3cb-87f427b90bf1", "0198b955-3656-7c40-b3cb-87f427b90bf2", "0198b955-3656-7c40-b3cb-87f427b90bf3"}[index]
		stale.ExpectedRevision = second.Revision
		stale.ClientCompatibilityVersion = tc.client
		stale.RawBody = []byte(`{"case":"` + tc.name + `"}`)
		stale.Data.Progression = json.RawMessage(tc.progression)
		if _, err := f.Update(ctx, account, stale); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
			t.Fatalf("%s: %v", tc.name, err)
		}
	}
	if _, err := f.service.ClaimWriter(ctx, account, f.sessionID, gamesave.ClaimWriterRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bf4", ClientInstanceID: clientInstanceID,
		ClientCompatibilityVersion: 10, RawBody: []byte(`{"clientCompatibilityVersion":10,"training":"stale"}`),
	}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old generation writer after purchase: %v", err)
	}
	snapshot, err := f.Get(ctx, account)
	if err != nil || snapshot.Revision != second.Revision {
		t.Fatalf("failed writes changed revision: %+v %v", snapshot, err)
	}
	assertGemOfferJSONEqual(t, snapshot.Data.Progression, purchased.Data.Progression)
}
