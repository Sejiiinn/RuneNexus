package economy

import (
	"math"
	"testing"
)

func TestHardRewardChancesFollowProgression(t *testing.T) {
	for _, tc := range []struct {
		stage                int
		ticket, first, extra float64
	}{
		{1, 0.05, 0.25, 0.20},  // 1-1
		{30, 0.10, 0.40, 0.30}, // 3-10
		{15, 0.05 + 24*0.05/29, 0.25 + 24*0.15/29, 0.20 + 24*0.10/29},
	} {
		ordinal := progressionOrdinal(tc.stage)
		first, extra := hardLootChances(ordinal)
		if math.Abs(hardTicketChance(ordinal)-tc.ticket) > 1e-9 || math.Abs(first-tc.first) > 1e-9 || math.Abs(extra-tc.extra) > 1e-9 {
			t.Fatalf("stage %d: ticket=%v first=%v extra=%v", tc.stage, hardTicketChance(ordinal), first, extra)
		}
	}
	// Later chapters keep the slope without a cap, but never exceed certainty.
	if hardTicketChance(60) <= hardTicketChance(30) || ordinalChance(1000, 0.25, 0.40) != 1 {
		t.Fatal("chances keep rising and clamp at one")
	}
	if hardTicketChance(progressionOrdinal(999)) != 0 {
		t.Fatal("unknown stage never rolls")
	}
}

func TestHardClearRewardsRollLootOnUnlockedTurrets(t *testing.T) {
	const runs = 6000
	counts := [hardLootMaxModules + 1]int{}
	tickets := 0
	for i := 0; i < runs; i++ {
		rewards, err := rollHardClearRewards(30, 0, []string{"machinegun", "cannon"})
		if err != nil {
			t.Fatal(err)
		}
		counts[len(rewards.Modules)]++
		tickets += int(rewards.ModuleTickets)
		for _, module := range rewards.Modules {
			if module.TurretType != "machinegun" && module.TurretType != "cannon" {
				t.Fatalf("loot outside unlocked turrets: %s", module.TurretType)
			}
			if err := validateModule(module); err != nil {
				t.Fatal(err)
			}
		}
	}
	// 3-10: one or more 40%, two or more 40%*30%, three 40%*30%*30%.
	expected := []float64{0.60, 0.40 * 0.70, 0.40 * 0.30 * 0.70, 0.40 * 0.30 * 0.30}
	for count, want := range expected {
		got := float64(counts[count]) / runs
		if math.Abs(got-want) > 0.025 {
			t.Fatalf("%d modules: got %.3f want %.3f", count, got, want)
		}
	}
	if rate := float64(tickets) / runs; math.Abs(rate-0.10) > 0.015 {
		t.Fatalf("ticket rate %.3f", rate)
	}
	if rewards, err := rollHardClearRewards(30, 0, nil); err != nil || len(rewards.Modules) != 0 {
		t.Fatal("no unlocked turret means no loot")
	}
}
