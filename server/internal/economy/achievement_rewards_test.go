package economy

import (
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
)

func TestCumulativeAchievementCountSources(t *testing.T) {
	raw := []byte(`{"achievementCounters":{"attendance":7,"killBosses":31},"turretModules":{"drawCount":99}}`)
	economy := dbgen.PlayerEconomy{ModuleDrawCount: 21}
	for _, tc := range []struct {
		id   string
		want int64
	}{
		{"attendance", 7},
		{"killBosses", 31},
		{"clearWaves", 0},
		// Draws read the economy's own count, never the save.
		{"moduleDraws", 21},
	} {
		if got := cumulativeAchievementCount(raw, economy, tc.id); got != tc.want {
			t.Fatalf("%s = %d, want %d", tc.id, got, tc.want)
		}
	}
	if got := cumulativeAchievementCount([]byte(`not json`), economy, "attendance"); got != 0 {
		t.Fatalf("invalid progression counted %d", got)
	}
	if key := cumulativeAchievementRewardKey("killEnemies", 4); key != "achievement:killEnemies:4" {
		t.Fatalf("key %q", key)
	}
}
