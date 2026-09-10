package weeklyreward

import (
	"errors"
	"testing"
	"time"
)

func TestWeeklyPeriodResetsAtMondayFiveKST(t *testing.T) {
	before := time.Date(2026, 6, 7, 19, 59, 59, 0, time.UTC)
	after := time.Date(2026, 6, 7, 20, 0, 0, 0, time.UTC)

	beforePeriod, beforeWeek := weeklyPeriod(before)
	afterPeriod, afterWeek := weeklyPeriod(after)

	if beforePeriod != "2026-W23" || afterPeriod != "2026-W24" {
		t.Fatalf("periods = %q, %q", beforePeriod, afterPeriod)
	}
	if afterWeek != beforeWeek+1 {
		t.Fatalf("week keys = %d, %d", beforeWeek, afterWeek)
	}
}

func TestRewardDefinitionsUseServerAmounts(t *testing.T) {
	tests := []struct {
		name          string
		period        string
		rewardType    string
		questType     string
		rewardKey     string
		diamonds      int32
		moduleTickets int32
	}{
		{"daily quest", "daily", RewardTypeQuest, "clearWaves", "daily:period:quest:clearWaves", 20, 0},
		{"daily all complete", "daily", RewardTypeAllComplete, "", "daily:period:all_complete", 40, 1},
		{"daily attendance", "daily", RewardTypeAttendance, "", "daily:period:attendance", 20, 0},
		{"weekly quest", "weekly", RewardTypeQuest, "clearWaves", "weekly:period:quest:clearWaves", 40, 0},
		{"weekly all complete", "weekly", RewardTypeAllComplete, "", "weekly:period:all_complete", 100, 4},
		{"weekly attendance", "weekly", RewardTypeAttendance, "", "weekly:period:attendance", 40, 0},
		{"legacy weekly quest", "", RewardTypeQuest, "clearWaves", "weekly:period:quest:clearWaves", 40, 0},
		{"legacy weekly all complete", "", RewardTypeAllComplete, "", "weekly:period:all_complete", 100, 4},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			reward, err := rewardDefinitionForRequest(ClaimRequest{
				Period: test.period, RewardType: test.rewardType, QuestType: test.questType,
			}, "period")
			if err != nil {
				t.Fatalf("reward definition: %v", err)
			}
			if reward.rewardKey != test.rewardKey || reward.diamonds != test.diamonds || reward.moduleTickets != test.moduleTickets {
				t.Fatalf("reward definition = %#v", reward)
			}
		})
	}
	if _, err := rewardDefinitionForRequest(
		ClaimRequest{RewardType: RewardTypeQuest, QuestType: "unknown"},
		"2026-W24",
	); !errors.Is(err, ErrInvalidReward) {
		t.Fatalf("unknown quest error = %v", err)
	}
}

func TestWeeklyRewardEligibilityUsesSavedProgressionEvidence(t *testing.T) {
	weekKey := int64(2945)
	complete := progressionEvidence{
		WeeklyQuestProgress: map[string]int64{
			"clearWaves":     150,
			"killBosses":     15,
			"killEnemies":    500,
			"buyRunUpgrades": 25,
		},
		WeeklyAttendanceDayKeys: []int64{
			weekKey*7 - 3,
			weekKey*7 - 2,
			weekKey*7 - 1,
			weekKey * 7,
			weekKey*7 + 1,
			weekKey*7 + 1,
		},
	}

	requests := []ClaimRequest{
		{RewardType: RewardTypeQuest, QuestType: "killEnemies"},
		{RewardType: RewardTypeAllComplete},
		{RewardType: RewardTypeAttendance},
	}
	for _, request := range requests {
		if err := validateEligibility(request, weekKey, complete); err != nil {
			t.Fatalf("eligible request %#v: %v", request, err)
		}
	}

	incomplete := complete
	incomplete.WeeklyQuestProgress = map[string]int64{"clearWaves": 149}
	if err := validateEligibility(
		ClaimRequest{RewardType: RewardTypeAllComplete},
		weekKey,
		incomplete,
	); !errors.Is(err, ErrNotEligible) {
		t.Fatalf("incomplete all reward error = %v", err)
	}
	claimed := complete
	claimed.ClaimedWeeklyQuestRewards = []string{"killEnemies"}
	if err := validateEligibility(
		ClaimRequest{RewardType: RewardTypeQuest, QuestType: "killEnemies"},
		weekKey,
		claimed,
	); !errors.Is(err, ErrNotEligible) {
		t.Fatalf("claimed quest error = %v", err)
	}
	rolledBack := complete
	rolledBack.DailyQuestClockRollbackDetected = true
	if err := validateEligibility(
		ClaimRequest{RewardType: RewardTypeAttendance},
		weekKey,
		rolledBack,
	); !errors.Is(err, ErrNotEligible) {
		t.Fatalf("clock rollback error = %v", err)
	}
}
