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

func TestWeeklyRewardDefinitionsDoNotAcceptClientAmounts(t *testing.T) {
	quest, err := rewardDefinitionForRequest(
		ClaimRequest{RewardType: RewardTypeQuest, QuestType: "clearWaves"},
		"2026-W24",
	)
	if err != nil {
		t.Fatalf("quest definition: %v", err)
	}
	if quest.rewardKey != "weekly:2026-W24:quest:clearWaves" ||
		quest.diamonds != 20 || quest.moduleTickets != 0 {
		t.Fatalf("quest definition = %#v", quest)
	}
	all, err := rewardDefinitionForRequest(
		ClaimRequest{RewardType: RewardTypeAllComplete},
		"2026-W24",
	)
	if err != nil {
		t.Fatalf("all-complete definition: %v", err)
	}
	if all.diamonds != 60 || all.moduleTickets != 1 {
		t.Fatalf("all-complete definition = %#v", all)
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
