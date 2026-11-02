//go:build integration

package dbtest_test

import (
	"context"
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

const achievementProgression = `{"clearedStageNumbers":[1],"achievementCounters":{"attendance":30,"killBosses":29}}`

func achievementRequest(t *testing.T, ctx context.Context, service *economy.Service, accountID string, fixture *claimedSaveService, key string, id string, tier int) economy.CumulativeAchievementClaimRequest {
	t.Helper()
	snapshot, err := service.Get(ctx, accountID)
	if err != nil {
		t.Fatal(err)
	}
	return economy.CumulativeAchievementClaimRequest{
		IdempotencyKey: key, RawBody: []byte(`{"expectedEconomyRevision":` + itoa(int(snapshot.EconomyRevision)) + `,"clientCompatibilityVersion":16,"achievementId":"` + id + `","tier":` + itoa(tier) + `}`),
		ExpectedRevision: snapshot.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
		AchievementID: id, Tier: tier, WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 2,
	}
}

func TestCumulativeAchievementClaimGrantsEachTierOnce(t *testing.T) {
	ctx, fixture, accountID, service := openChallengeClaim(t, achievementProgression)
	first := achievementRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90d02", "attendance", 1)
	result, err := service.ClaimCumulativeAchievement(ctx, accountID, fixture.sessionID, first)
	if err != nil || result.GrantedDiamonds != 300 || result.RewardKey != "achievement:attendance:1" {
		t.Fatalf("tier 1 claim: %+v %v", result, err)
	}
	if replayed, err := service.ClaimCumulativeAchievement(ctx, accountID, fixture.sessionID, first); err != nil || replayed.GrantedDiamonds != 300 {
		t.Fatalf("replay changed the receipt: %+v %v", replayed, err)
	}
	again := achievementRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90d03", "attendance", 1)
	if _, err := service.ClaimCumulativeAchievement(ctx, accountID, fixture.sessionID, again); !errors.Is(err, economy.ErrInvalidCommand) {
		t.Fatalf("second claim of one tier: %v", err)
	}
	second, err := service.ClaimCumulativeAchievement(ctx, accountID, fixture.sessionID, achievementRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90d04", "attendance", 2))
	if err != nil || second.GrantedDiamonds != 500 {
		t.Fatalf("tier 2 claim: %+v %v", second, err)
	}
	var diamonds, claims int64
	if err := fixture.pool.QueryRow(ctx, `SELECT free_diamonds,
 (SELECT count(*) FROM economy_reward_claims WHERE account_id=$1 AND reward_key LIKE 'achievement:%')
 FROM player_economies WHERE account_id=$1`, fixture.accountUUID).Scan(&diamonds, &claims); err != nil {
		t.Fatal(err)
	}
	if diamonds != 800 || claims != 2 {
		t.Fatalf("achievement claim state diamonds=%d claims=%d", diamonds, claims)
	}
}

func TestCumulativeAchievementClaimRejectsUnearned(t *testing.T) {
	ctx, fixture, accountID, service := openChallengeClaim(t, achievementProgression)
	for _, tc := range []struct {
		name string
		id   string
		tier int
	}{
		{"below threshold", "attendance", 3},
		{"one short", "killBosses", 1},
		{"draws read the economy count", "moduleDraws", 1},
		{"tier 5 is a client medal", "attendance", 5},
		{"unknown achievement", "playTime", 1},
	} {
		request := achievementRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90d10", tc.id, tc.tier)
		if _, err := service.ClaimCumulativeAchievement(ctx, accountID, fixture.sessionID, request); !errors.Is(err, economy.ErrInvalidCommand) {
			t.Fatalf("%s: %v", tc.name, err)
		}
	}
	old := achievementRequest(t, ctx, service, accountID, fixture, "0198b955-3656-7c40-b3cb-87f427b90d11", "attendance", 1)
	old.RawBody = []byte(`{"clientCompatibilityVersion":15,"achievementId":"attendance","tier":1}`)
	if _, err := service.ClaimCumulativeAchievement(ctx, accountID, fixture.sessionID, old); !errors.Is(err, gamesave.ErrClientUpdateRequired) {
		t.Fatalf("old client claim: %v", err)
	}
}
