package economy

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
)

// Cumulative achievements (docs/stage_difficulty_design.md#누적-업적). The client
// shows the same table from godot/content/cumulative_achievements.gd; keep both
// in step. Tiers 1-4 grant diamonds here; tier 5 is a medal kept in client
// progression. Counters are client-trusted progression like stage challenges,
// except module draws, which read the economy's own draw count.

var cumulativeAchievementTiers = map[string][4]int64{
	"attendance":  {7, 30, 60, 120},
	"clearWaves":  {300, 1500, 4000, 8000},
	"killBosses":  {30, 150, 400, 800},
	"killEnemies": {3000, 20000, 60000, 120000},
	"moduleDraws": {20, 60, 150, 250},
}

var cumulativeAchievementDiamonds = [4]int64{300, 500, 700, 1000}

func cumulativeAchievementRewardKey(id string, tier int) string {
	return fmt.Sprintf("achievement:%s:%d", id, tier)
}

type achievementProgression struct {
	Counters map[string]int64 `json:"achievementCounters"`
}

// cumulativeAchievementCount reads one lifetime counter.
func cumulativeAchievementCount(progression []byte, economy dbgen.PlayerEconomy, id string) int64 {
	if id == "moduleDraws" {
		return economy.ModuleDrawCount
	}
	var saved achievementProgression
	if json.Unmarshal(progression, &saved) != nil {
		return 0
	}
	return saved.Counters[id]
}

func (service *Service) ClaimCumulativeAchievement(
	ctx context.Context,
	accountID string,
	sessionID string,
	request CumulativeAchievementClaimRequest,
) (CommandResult, error) {
	thresholds, known := cumulativeAchievementTiers[request.AchievementID]
	if !known || request.Tier < 1 || request.Tier > len(thresholds) {
		return CommandResult{}, ErrInvalidCommand
	}
	threshold := thresholds[request.Tier-1]
	return service.claimProgressionReward(ctx, accountID, sessionID, progressionRewardClaim{
		IdempotencyKey: request.IdempotencyKey, RawBody: request.RawBody,
		ExpectedRevision: request.ExpectedRevision, ExpectedCatalogVersion: request.ExpectedCatalogVersion,
		WriterGeneration: request.WriterGeneration, SourceSaveRevision: request.SourceSaveRevision,
		RewardKey: cumulativeAchievementRewardKey(request.AchievementID, request.Tier),
		Reward:    challengeReward{Diamonds: cumulativeAchievementDiamonds[request.Tier-1]},
		Reason:    "cumulative_achievement",
		Evidence:  map[string]any{"achievementId": request.AchievementID, "tier": request.Tier},
		Earned: func(progression []byte, economy dbgen.PlayerEconomy) bool {
			return cumulativeAchievementCount(progression, economy, request.AchievementID) >= threshold
		},
	})
}
