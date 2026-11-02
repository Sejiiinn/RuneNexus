//go:build integration

package dbtest_test

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

// Stage 11 is 3-1 (odd, diamonds); 12 is 3-2 (even, tickets); 15 is 3-5.
const challengeProgression = `{"clearedStageNumbers":[1,2,11,12,15],"challengeStageNumbers":[11],"hardChallengeStageNumbers":[12,15]}`

func openChallengeClaim(t *testing.T, progression string) (context.Context, *claimedSaveService, string, *economy.Service) {
	t.Helper()
	ctx, fixture, accountID := openSaveService(t)
	modules := json.RawMessage(`{"tickets":0,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`)
	seedPreAuthoritySave(t, fixture, accountID, gamesave.Data{Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: json.RawMessage(`{"freeDiamonds":0,"paidDiamonds":0}`), TurretModules: modules})
	service := economy.NewService(fixture.pool)
	if _, err := service.Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90c01", RawBody: []byte(`{"bootstrap":true,"clientCompatibilityVersion":16}`),
		WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1,
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey: secondSaveKey, ExpectedRevision: 1,
		ClientCompatibilityVersion: gamesave.CurrentClientCompatibilityVersion,
		RawBody:                    []byte(`{"expectedRevision":1,"clientCompatibilityVersion":16}`),
		Data: gamesave.Data{
			Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`),
			Progression: json.RawMessage(progression), TurretModules: modules,
		},
	}); err != nil {
		t.Fatal(err)
	}
	return ctx, fixture, accountID, service
}

// challengeRequest expects the account's current economy revision.
func challengeRequest(t *testing.T, ctx context.Context, service *economy.Service, accountID string, fixture *claimedSaveService, key string, stage int, difficulty string) economy.StageChallengeClaimRequest {
	t.Helper()
	snapshot, err := service.Get(ctx, accountID)
	if err != nil {
		t.Fatal(err)
	}
	return economy.StageChallengeClaimRequest{
		IdempotencyKey: key, RawBody: []byte(`{"expectedEconomyRevision":` + itoa(int(snapshot.EconomyRevision)) + `,"clientCompatibilityVersion":16,"stageNumber":` + itoa(stage) + `,"difficulty":"` + difficulty + `"}`),
		ExpectedRevision: snapshot.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
		StageNumber: stage, Difficulty: difficulty, WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 2,
	}
}

func itoa(value int) string {
	encoded, _ := json.Marshal(value)
	return string(encoded)
}

func TestStageChallengeClaimGrantsOnce(t *testing.T) {
	ctx, fixture, accountID, service := openChallengeClaim(t, challengeProgression)
	normal := challengeRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90c02", 11, "normal")
	result, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, normal)
	if err != nil || result.GrantedDiamonds != 300 || result.GrantedModuleTickets != 0 || result.RewardKey != "stage:11:challenge:normal" {
		t.Fatalf("normal claim: %+v %v", result, err)
	}
	if replayed, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, normal); err != nil || replayed.GrantedDiamonds != 300 {
		t.Fatalf("replay changed the receipt: %+v %v", replayed, err)
	}
	again := challengeRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90c03", 11, "normal")
	if _, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, again); !errors.Is(err, economy.ErrInvalidCommand) {
		t.Fatalf("second claim of one key: %v", err)
	}
	// Hard 3-2 is a ticket reward, and the hard achievement also credits normal.
	hard, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, challengeRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90c04", 12, "hard"))
	if err != nil || hard.GrantedModuleTickets != 7 {
		t.Fatalf("hard ticket claim: %+v %v", hard, err)
	}
	credited, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, challengeRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90c05", 12, "normal"))
	if err != nil || credited.GrantedModuleTickets != 6 {
		t.Fatalf("normal credited by hard: %+v %v", credited, err)
	}
	var diamonds, tickets, claims int64
	if err := fixture.pool.QueryRow(ctx, `SELECT free_diamonds,module_tickets,
 (SELECT count(*) FROM economy_reward_claims WHERE account_id=$1 AND reward_key LIKE 'stage:%:challenge:%')
 FROM player_economies WHERE account_id=$1`, fixture.accountUUID).Scan(&diamonds, &tickets, &claims); err != nil {
		t.Fatal(err)
	}
	if diamonds != 300 || tickets != 13 || claims != 3 {
		t.Fatalf("challenge claim state diamonds=%d tickets=%d claims=%d", diamonds, tickets, claims)
	}
	keys := credited.Snapshot.ClaimedRewardKeys
	if len(keys) != 3 {
		t.Fatalf("snapshot claim keys: %v", keys)
	}
}

func TestStageChallengeClaimRejectsUnearned(t *testing.T) {
	ctx, fixture, accountID, service := openChallengeClaim(t, challengeProgression)
	for _, tc := range []struct {
		name       string
		stage      int
		difficulty string
	}{
		{"hard not achieved", 11, "hard"},
		{"not achieved", 2, "normal"},
		{"core point reward stays client side", 15, "hard"},
		{"unknown difficulty", 11, "easy"},
	} {
		request := challengeRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90c10", tc.stage, tc.difficulty)
		if _, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, request); !errors.Is(err, economy.ErrInvalidCommand) {
			t.Fatalf("%s: %v", tc.name, err)
		}
	}
	stale := challengeRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90c12", 11, "normal")
	stale.ExpectedRevision--
	if _, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, stale); !errors.As(err, new(*economy.ConflictError)) {
		t.Fatalf("stale economy revision: %v", err)
	}
	old := challengeRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90c11", 11, "normal")
	old.RawBody = []byte(`{"clientCompatibilityVersion":15,"stageNumber":11,"difficulty":"normal"}`)
	if _, err := service.ClaimStageChallenge(ctx, accountID, fixture.sessionID, old); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old client claim: %v", err)
	}
}
