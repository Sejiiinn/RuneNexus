package economy

import (
	"math"

	"github.com/Sejiiinn/RuneNexus/server/internal/progression"
)

// Hard clear rewards (docs/stage_difficulty_design.md). The client shows the
// same chances from godot/content/stage_difficulty.gd; keep both in step.
const (
	HardFirstClearModuleTickets int64 = 2
	hardLootMaxModules                = 3
	// Chances rise linearly with the progression ordinal: 1-1 is ordinal 1 and
	// 3-10 ordinal 30. Later chapters keep the same slope.
	hardTicketChanceStart    = 0.05
	hardTicketChanceAt30     = 0.10
	hardLootFirstChanceStart = 0.25
	hardLootFirstChanceAt30  = 0.40
	hardLootExtraChanceStart = 0.20
	hardLootExtraChanceAt30  = 0.30
	chanceResolution         = 1_000_000
)

type hardClearRewards struct {
	ModuleTickets int64
	Modules       []generatedModule
}

func progressionOrdinal(stageNumber int) int {
	for index, id := range progression.OrderedIDs() {
		if int(id) == stageNumber {
			return index + 1
		}
	}
	return 0
}

func ordinalChance(ordinal int, start float64, at30 float64) float64 {
	if ordinal < 1 {
		return 0
	}
	return math.Min(1, start+float64(ordinal-1)*(at30-start)/29)
}

func hardTicketChance(ordinal int) float64 {
	return ordinalChance(ordinal, hardTicketChanceStart, hardTicketChanceAt30)
}

func hardLootChances(ordinal int) (float64, float64) {
	return ordinalChance(ordinal, hardLootFirstChanceStart, hardLootFirstChanceAt30),
		ordinalChance(ordinal, hardLootExtraChanceStart, hardLootExtraChanceAt30)
}

func secureChance(chance float64) (bool, error) {
	if chance <= 0 {
		return false, nil
	}
	value, err := secureInt(0, chanceResolution-1)
	if err != nil {
		return false, err
	}
	return float64(value) < chance*chanceResolution, nil
}

// rollHardClearRewards draws the repeat ticket and loot modules of one hard
// clear. Loot uses the account's current build level without counting as a
// draw, on a random turret the account has unlocked.
func rollHardClearRewards(stageNumber int, drawCount int64, unlocked []string) (hardClearRewards, error) {
	ordinal := progressionOrdinal(stageNumber)
	var rewards hardClearRewards
	ticket, err := secureChance(hardTicketChance(ordinal))
	if err != nil {
		return rewards, err
	}
	if ticket {
		rewards.ModuleTickets = 1
	}
	if len(unlocked) == 0 {
		return rewards, nil
	}
	first, extra := hardLootChances(ordinal)
	chance := first
	for len(rewards.Modules) < hardLootMaxModules {
		won, err := secureChance(chance)
		if err != nil || !won {
			return rewards, err
		}
		turret, err := randomChoice(unlocked)
		if err != nil {
			return rewards, err
		}
		module, err := generateModule(turret, drawCount)
		if err != nil {
			return rewards, err
		}
		rewards.Modules = append(rewards.Modules, module)
		chance = extra
	}
	return rewards, nil
}

func unlockedTurretTypes(progressionJSON []byte) []string {
	unlocked := make([]string, 0, len(turretTypes))
	for _, turret := range turretTypes {
		if turretUnlocked(turret, progressionJSON) {
			unlocked = append(unlocked, turret)
		}
	}
	return unlocked
}
