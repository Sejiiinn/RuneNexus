//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/Sejiiinn/RuneNexus/server/internal/weeklyreward"
	"testing"
)

func TestGrowthMigrationRejectsOldWritersAndEconomyWithoutGlobalLockout(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	original := gamesave.UpdateRequest{IdempotencyKey: firstSaveKey, ClientCompatibilityVersion: 2,
		RawBody: []byte(`{"clientCompatibilityVersion":2}`), Data: gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`),
			Progression: json.RawMessage(`{"runes":150,"freeDiamonds":100,"paidDiamonds":0}`), TurretModules: json.RawMessage(`{"tickets":2,"items":[]}`)}}
	if _, err := fixture.Update(ctx, accountID, original); err != nil {
		t.Fatal(err)
	}
	svc := economy.NewService(fixture.pool)
	bootstrap := economy.BootstrapRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bea", RawBody: []byte(`{"clientCompatibilityVersion":2}`), WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1}
	if _, err := svc.Bootstrap(ctx, accountID, fixture.sessionID, bootstrap); err != nil {
		t.Fatal(err)
	}
	// Generation 2 remains allowed even after economy bootstrap, until growth migrates.
	legacy := original
	legacy.IdempotencyKey = secondSaveKey
	legacy.ExpectedRevision = 1
	legacy.RawBody = []byte(`{"clientCompatibilityVersion":2,"expectedRevision":1}`)
	if _, err := fixture.Update(ctx, accountID, legacy); err != nil {
		t.Fatalf("legacy before migration: %v", err)
	}
	migrated := original
	migrated.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90beb"
	migrated.ExpectedRevision = 2
	migrated.ClientCompatibilityVersion = 3
	migrated.RawBody = []byte(`{"clientCompatibilityVersion":3,"expectedRevision":2}`)
	migrated.Data.Progression = json.RawMessage(`{"growthVersion":1,"runes":150,"freeDiamonds":100,"paidDiamonds":0,"bossBountyUpgradeLevel":10}`)
	if _, err := fixture.Update(ctx, accountID, migrated); err != nil {
		t.Fatal(err)
	}
	// Exact receipts are read-only and remain recoverable after migration.
	if _, err := fixture.Update(ctx, accountID, legacy); err != nil {
		t.Fatalf("legacy receipt: %v", err)
	}
	if _, err := svc.Bootstrap(ctx, accountID, fixture.sessionID, bootstrap); err != nil {
		t.Fatalf("bootstrap receipt: %v", err)
	}
	stale := legacy
	stale.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bec"
	stale.ExpectedRevision = 3
	if _, err := fixture.Update(ctx, accountID, stale); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old update err=%v", err)
	}
	stale.ClientCompatibilityVersion = 3
	if _, err := fixture.Update(ctx, accountID, stale); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("current stale growth err=%v", err)
	}
	if _, err := fixture.service.ClaimWriter(ctx, accountID, fixture.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: secondClaimKey, ClientInstanceID: clientInstanceID, ClientCompatibilityVersion: 2, RawBody: []byte(`{"clientCompatibilityVersion":2}`)}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old writer err=%v", err)
	}
	requestBody := []byte(`{"clientCompatibilityVersion":2}`)
	_, err := svc.UnlockResearchSlotTwo(ctx, accountID, fixture.sessionID, economy.ResearchSlotUnlockRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bed", RawBody: requestBody, WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 3, ExpectedRevision: 1, ExpectedCatalogVersion: economy.CatalogVersion})
	if !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old writer-bound economy err=%v", err)
	}
	_, err = svc.DisassembleModules(ctx, accountID, economy.DisassembleRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bee", RawBody: requestBody, ExpectedRevision: 1, ExpectedCatalogVersion: economy.CatalogVersion, ModuleIDs: []string{"0198b955-3656-7c40-b3cb-87f427b90bff"}})
	if !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old economy-only err=%v", err)
	}
	_, err = weeklyreward.NewService(fixture.pool).Claim(ctx, accountID, fixture.sessionID, weeklyreward.ClaimRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bef", RawBody: requestBody, Period: "daily", RewardType: "attendance"})
	if !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old daily reward err=%v", err)
	}
	snapshot, err := fixture.Get(ctx, accountID)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Revision != 3 || gamesave.GrowthVersion(snapshot.Data.Progression) != 1 {
		t.Fatalf("save changed: %+v", snapshot)
	}
	wallet, err := svc.Get(ctx, accountID)
	if err != nil {
		t.Fatal(err)
	}
	if wallet.EconomyRevision != 1 || wallet.Wallet.FreeDiamonds != 100 {
		t.Fatalf("wallet changed: %+v", wallet)
	}
}
