package economy

import (
	"encoding/json"
	"errors"
	"testing"
	"time"
)

func TestResearchCompletionCostAfterRestart(t *testing.T) {
	const start = int64(5000000)
	progression, _ := json.Marshal(researchProgression{ActiveResearches: []activeResearch{{Type: "gemAttunement", TargetLevel: 1, StartedAtMillis: start, DurationMillis: 45 * 60000, InitialElapsedMillis: 15 * 60000}}})
	for _, tc := range []struct {
		minutes int64
		want    int64
		reject  bool
	}{{0, 45, false}, {30, 15, false}, {44, 1, false}, {45, 0, true}} {
		_, cost, err := researchCompletionCost(progression, "gemAttunement", time.UnixMilli(start+tc.minutes*60000))
		if cost != tc.want || errors.Is(err, ErrInvalidCommand) != tc.reject {
			t.Fatalf("minute %d cost=%d err=%v", tc.minutes, cost, err)
		}
	}
}

func TestResearchCompletionVersionedBounds(t *testing.T) {
	for _, tc := range []struct {
		kind          string
		growth, level int
		reject        bool
	}{
		{"criticalChance", 1, 10, false}, {"criticalChance", 1, 11, true}, {"criticalChance", 0, 1, true},
		{"emergencySale", 1, 5, false}, {"emergencySale", 1, 6, true},
		{"bossBounty", 0, 20, false}, {"bossBounty", 1, 1, true}, {"unknown", 1, 1, true},
	} {
		raw, _ := json.Marshal(researchProgression{GrowthVersion: tc.growth, ActiveResearches: []activeResearch{{Type: tc.kind, TargetLevel: tc.level, StartedAtMillis: 1000, DurationMillis: 60000}}})
		_, _, err := researchCompletionCost(raw, tc.kind, time.UnixMilli(1000))
		if errors.Is(err, ErrInvalidCommand) != tc.reject {
			t.Fatalf("%+v err=%v", tc, err)
		}
	}
}

func TestResearchEffectAcknowledgementAfterGrowthMigration(t *testing.T) {
	effect := []byte(`{"researchType":"bossBounty","targetLevel":10}`)
	for _, tc := range []struct {
		progression string
		want        bool
	}{
		{`{"growthVersion":1,"bossBountyUpgradeLevel":10}`, true},
		{`{"growthVersion":1,"bossBountyUpgradeLevel":9}`, false},
		{`{"researchLevels":{"bossBounty":10}}`, true},
		{`{"growthVersion":1,"bossBountyUpgradeLevel":10,"activeResearches":[{"type":"bossBounty","targetLevel":10}]}`, false},
	} {
		if got := effectAppliedToProgression(effect, []byte(tc.progression)); got != tc.want {
			t.Fatalf("%s got=%v", tc.progression, got)
		}
	}
	for _, effect := range []string{`{"researchType":"unknown","targetLevel":1}`, `{"researchType":"criticalChance","targetLevel":11}`, `{"researchType":"emergencySale","targetLevel":6}`, `{"researchType":"bossBounty","targetLevel":21}`} {
		if effectAppliedToProgression([]byte(effect), []byte(`{"growthVersion":1,"bossBountyUpgradeLevel":40,"researchLevels":{"unknown":1,"criticalChance":11,"emergencySale":6}}`)) {
			t.Fatalf("accepted %s", effect)
		}
	}
}
