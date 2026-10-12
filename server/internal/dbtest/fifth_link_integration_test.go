//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"testing"
	"time"
)

func TestFifthLinkResearchSaveCompletionAndOldWriterProtection(t *testing.T) {
	ctx, fixture, accountID := openSaveService(t)
	p := map[string]any{"growthVersion": 1, "progressionVersion": 1, "clearedStageNumbers": []int{20, 30}, "researchLevels": map[string]int{"linkExpansionOne": 1}, "runes": 55000, "freeDiamonds": 1000, "paidDiamonds": 0, "activeResearches": []map[string]any{{"type": "linkExpansionTwo", "targetLevel": 1, "startedAtMillis": time.Now().UnixMilli(), "durationMillis": int64(28800000)}}}
	save := func(key string, revision int64, client int, run json.RawMessage) error {
		raw, err := json.Marshal(p)
		if err != nil {
			t.Fatal(err)
		}
		_, err = fixture.Update(ctx, accountID, gamesave.UpdateRequest{IdempotencyKey: key, ExpectedRevision: revision, ClientCompatibilityVersion: client, RawBody: []byte(`{"clientCompatibilityVersion":9}`), Data: gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`), Progression: raw, TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: run}})
		return err
	}
	initialProgression, _ := json.Marshal(p)
	seedPreAuthoritySave(t, fixture, accountID, gamesave.Data{Version: 2, Preferences: json.RawMessage(`{}`), Progression: initialProgression, TurretModules: json.RawMessage(`{"tickets":0,"items":[]}`), ActiveRun: json.RawMessage(`{"economyRunId":"0198b955-3656-7c40-b3cb-87f427b90d00","stageNumber":1,"phase":"preparation","completedRounds":0,"gemRerollsUsed":0,"gemInventory":{"attackSpeed":1,"range":1,"physicalDamage":1,"criticalChance":1,"multipleProjectiles":1},"turrets":[]}`)})
	svc := economy.NewService(fixture.pool)
	boot, err := svc.Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{IdempotencyKey: secondSaveKey, RawBody: []byte(`{"clientCompatibilityVersion":9}`), WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1})
	if err != nil {
		t.Fatal(err)
	}
	if _, err = fixture.service.ClaimWriter(ctx, accountID, fixture.sessionID, gamesave.ClaimWriterRequest{IdempotencyKey: secondClaimKey, ClientInstanceID: secondClientID, ClientCompatibilityVersion: 5, RawBody: []byte(`{"clientCompatibilityVersion":5}`)}); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old writer claim: %v", err)
	}
	if err = save("0198b955-3656-7c40-b3cb-87f427b90c01", 1, 5, nil); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old update: %v", err)
	}
	request := economy.ResearchCompleteRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c02", RawBody: []byte(`{"clientCompatibilityVersion":9,"researchType":"linkExpansionTwo"}`), ExpectedRevision: boot.Snapshot.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion, WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 1, ResearchType: "linkExpansionTwo"}
	result, err := svc.CompleteResearch(ctx, accountID, fixture.sessionID, request)
	if err != nil || result.ProgressionEffect == nil || result.ProgressionEffect.Payload["researchType"] != "linkExpansionTwo" {
		t.Fatalf("II complete: %+v %v", result, err)
	}
	replay, err := svc.CompleteResearch(ctx, accountID, fixture.sessionID, request)
	if err != nil || replay.Snapshot.EconomyRevision != result.Snapshot.EconomyRevision {
		t.Fatalf("idempotent complete: %v", err)
	}
	p["researchLevels"] = map[string]int{"linkExpansionOne": 1, "linkExpansionTwo": 1}
	p["activeResearches"] = []any{}
	run := json.RawMessage(`{"economyRunId":"0198b955-3656-7c40-b3cb-87f427b90d00","stageNumber":1,"phase":"preparation","completedRounds":0,"gemRerollsUsed":0,"gemInventory":{},"gold":1000,"turrets":[{"type":"arrow","level":5,"slotLimit":5,"equippedGemSlots":["attackSpeed","range","physicalDamage","criticalChance","multipleProjectiles"]}]}`)
	if err = save("0198b955-3656-7c40-b3cb-87f427b90c03", 1, gamesave.CurrentClientCompatibilityVersion, run); err != nil {
		t.Fatalf("save five: %v", err)
	}
	ack, err := svc.AcknowledgeProgressionEffect(ctx, accountID, fixture.sessionID, economy.EffectAckRequest{IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c04", RawBody: []byte(`{"clientCompatibilityVersion":9}`), EffectID: result.ProgressionEffect.ID, WriterGeneration: fixture.writerGeneration, AppliedSaveRevision: 2})
	if err != nil || len(ack.Snapshot.PendingProgressionEffects) != 0 {
		t.Fatalf("II ack: %+v %v", ack, err)
	}
	snapshot, err := fixture.Get(ctx, accountID)
	if err != nil || string(snapshot.Data.ActiveRun) != string(run) { // JSONB object order is immaterial.
		var got, want any
		if err != nil || json.Unmarshal(snapshot.Data.ActiveRun, &got) != nil || json.Unmarshal(run, &want) != nil {
			t.Fatalf("read five: %v", err)
		}
		gotJSON, _ := json.Marshal(got)
		wantJSON, _ := json.Marshal(want)
		if string(gotJSON) != string(wantJSON) {
			t.Fatalf("five-slot run changed: %s", snapshot.Data.ActiveRun)
		}
	}
	var saved map[string]any
	if json.Unmarshal(snapshot.Data.Progression, &saved) != nil || saved["researchLevels"].(map[string]any)["linkExpansionTwo"] != float64(1) {
		t.Fatal("II progression lost")
	}
	if err = save("0198b955-3656-7c40-b3cb-87f427b90c05", 2, 5, nil); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old writer erased five: %v", err)
	}
}
