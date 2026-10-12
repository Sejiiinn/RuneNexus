//go:build integration

package dbtest_test

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

// A receipt replays only for the same command type, URL target and body.
func TestEconomyReceiptReplayRequiresSameCommandAndTarget(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	progression := map[string]any{"growthVersion": 1, "progressionVersion": 1, "clearedStageNumbers": []int{20, 30}, "researchLevels": map[string]int{"linkExpansionOne": 1}, "runes": 55000, "freeDiamonds": 1000, "paidDiamonds": 0, "activeResearches": []map[string]any{{"type": "linkExpansionTwo", "targetLevel": 1, "startedAtMillis": time.Now().UnixMilli(), "durationMillis": int64(28800000)}}}
	raw, err := json.Marshal(progression)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{IdempotencyKey: firstSaveKey, ExpectedRevision: 0, ClientCompatibilityVersion: 9, RawBody: []byte(`{"clientCompatibilityVersion":9}`), Data: gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`), Progression: raw, TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`)}}); err != nil {
		t.Fatal(err)
	}
	svc := economy.NewService(fixture.pool)
	boot, err := svc.Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{IdempotencyKey: secondSaveKey, RawBody: []byte(`{"clientCompatibilityVersion":9}`), WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1})
	if err != nil {
		t.Fatal(err)
	}
	body := []byte(`{"clientCompatibilityVersion":9}`)
	request := economy.ResearchCompleteRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90d01", RawBody: body, ExpectedRevision: boot.Snapshot.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion, WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 1, ResearchType: "linkExpansionTwo"}
	result, err := svc.CompleteResearch(ctx, accountID, fixture.sessionID, request)
	if err != nil || result.ProgressionEffect == nil {
		t.Fatalf("complete research: %+v %v", result, err)
	}
	replay, err := svc.CompleteResearch(ctx, accountID, fixture.sessionID, request)
	if err != nil || replay.Snapshot.EconomyRevision != result.Snapshot.EconomyRevision {
		t.Fatalf("exact replay: %+v %v", replay, err)
	}

	otherTarget := request
	otherTarget.ResearchType = "linkExpansionOne"
	if _, err := svc.CompleteResearch(ctx, accountID, fixture.sessionID, otherTarget); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("same key and body for another research = %v", err)
	}
	if _, err := svc.UnlockResearchSlotTwo(ctx, accountID, fixture.sessionID, economy.ResearchSlotUnlockRequest{IdempotencyKey: request.IdempotencyKey, RawBody: body, WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 1, ExpectedRevision: result.Snapshot.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion}); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("same key and body for another command = %v", err)
	}

	// Receipts stored before the target was bound hashed the body alone; an
	// in-flight retry of such a receipt still replays after the upgrade.
	legacy := sha256.Sum256(body)
	tag, err := fixture.pool.Exec(ctx, `UPDATE economy_commands SET request_hash = $1 WHERE idempotency_key = $2`, legacy[:], request.IdempotencyKey)
	if err != nil || tag.RowsAffected() != 1 {
		t.Fatalf("store legacy receipt hash: %v", err)
	}
	legacyReplay, err := svc.CompleteResearch(ctx, accountID, fixture.sessionID, request)
	if err != nil || legacyReplay.Snapshot.EconomyRevision != result.Snapshot.EconomyRevision {
		t.Fatalf("legacy receipt replay: %+v %v", legacyReplay, err)
	}
	if _, err := svc.UnlockResearchSlotTwo(ctx, accountID, fixture.sessionID, economy.ResearchSlotUnlockRequest{IdempotencyKey: request.IdempotencyKey, RawBody: body, WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 1, ExpectedRevision: result.Snapshot.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion}); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("legacy receipt for another command = %v", err)
	}
}
