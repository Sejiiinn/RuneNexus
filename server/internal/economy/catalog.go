package economy

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
)

const (
	CatalogVersion              int32 = 1
	AuthorityVersion            int32 = 1
	RNGAlgorithmVersion         int32 = 1
	ModuleTicketDiamondCost     int64 = 40
	ResearchSlotTwoUnlockCost   int64 = 600
	ResearchDiamondMillis       int64 = 60_000
	StageElevenModuleTicketGift int64 = 5
)

var (
	turretTypes        = []string{"arrow", "cannon", "magic", "frost", "sniper", "lightning"}
	parts              = []string{"core", "barrel", "frame"}
	grades             = []string{"normal", "magic", "rare", "unique"}
	gradeRefund        = map[string]int64{"normal": 2, "magic": 5, "rare": 20, "unique": 50}
	gradeOptionWeights = map[string][]int{
		"normal": {85, 15, 0},
		"magic":  {40, 60, 0},
		"rare":   {10, 55, 35},
		"unique": {0, 40, 60},
	}
)

type moduleOption struct {
	Type  string `json:"type"`
	Value int    `json:"value"`
}

type generatedModule struct {
	TurretType string         `json:"turretType"`
	Part       string         `json:"part"`
	Family     string         `json:"family"`
	Grade      string         `json:"grade"`
	Options    []moduleOption `json:"options"`
}

type optionRange struct {
	min int
	max int
}

var optionRanges = map[string]map[string]optionRange{
	"damageIncrease": {
		"normal": {4, 7}, "magic": {8, 13}, "rare": {14, 21}, "unique": {22, 30},
	},
	"attackRateIncrease": {
		"normal": {1, 3}, "magic": {4, 6}, "rare": {7, 10}, "unique": {11, 14},
	},
	"criticalChanceBonus": {
		"normal": {2, 4}, "magic": {5, 7}, "rare": {8, 11}, "unique": {12, 16},
	},
	"criticalDamageBonus": {
		"normal": {8, 14}, "magic": {15, 24}, "rare": {25, 38}, "unique": {39, 55},
	},
	"rangeIncrease": {
		"normal": {2, 4}, "magic": {5, 7}, "rare": {8, 11}, "unique": {12, 15},
	},
	"levelUpCostDiscount": {
		"normal": {2, 4}, "magic": {5, 7}, "rare": {8, 11}, "unique": {12, 16},
	},
	"linkUpgradeCostDiscount": {
		"normal": {3, 6}, "magic": {7, 10}, "rare": {11, 16}, "unique": {17, 24},
	},
	"buildCostDiscount": {
		"normal": {2, 4}, "magic": {6, 8}, "rare": {10, 12}, "unique": {14, 16},
	},
	"highLevelUpgradeCostDiscount": {
		"normal": {3, 5}, "magic": {6, 9}, "rare": {10, 15}, "unique": {16, 22},
	},
	"gemEffectIncrease": {
		"normal": {2, 3}, "magic": {4, 5}, "rare": {6, 8}, "unique": {9, 12},
	},
	"splashRadiusIncrease": {
		"normal": {3, 5}, "magic": {6, 9}, "rare": {10, 14}, "unique": {15, 22},
	},
	"damageOverTimeIncrease": {
		"normal": {5, 8}, "magic": {9, 15}, "rare": {16, 24}, "unique": {25, 36},
	},
	"burnDurationIncrease": {
		"normal": {4, 8}, "magic": {9, 14}, "rare": {15, 22}, "unique": {23, 34},
	},
	"slowDurationIncrease": {
		"normal": {4, 8}, "magic": {9, 14}, "rare": {15, 22}, "unique": {23, 34},
	},
	"slowStrengthBonus": {
		"normal": {2, 4}, "magic": {5, 7}, "rare": {8, 10}, "unique": {11, 14},
	},
	"lightningChainDamageIncrease": {
		"normal": {5, 8}, "magic": {9, 15}, "rare": {16, 24}, "unique": {25, 36},
	},
	"projectileSpeedIncrease": {
		"normal": {2, 4}, "magic": {5, 7}, "rare": {8, 11}, "unique": {12, 16},
	},
	"splashSecondaryDamageBonus": {
		"normal": {3, 5}, "magic": {6, 9}, "rare": {10, 14}, "unique": {15, 20},
	},
	"lightningChainRangeIncrease": {
		"normal": {3, 5}, "magic": {6, 9}, "rare": {10, 14}, "unique": {15, 22},
	},
	"aimSpeedIncrease": {
		"normal": {2, 4}, "magic": {5, 7}, "rare": {8, 11}, "unique": {12, 16},
	},
}

func generateModule(turretType string, drawCount int64) (generatedModule, error) {
	if !contains(turretTypes, turretType) {
		return generatedModule{}, errors.New("unsupported turret type")
	}
	part, err := randomChoice(parts)
	if err != nil {
		return generatedModule{}, err
	}
	grade, err := rollGrade(drawCount)
	if err != nil {
		return generatedModule{}, err
	}
	pool := optionPool(turretType, part)
	count, err := rollOptionCount(grade)
	if err != nil {
		return generatedModule{}, err
	}
	selected, err := randomDistinct(pool, count)
	if err != nil {
		return generatedModule{}, err
	}
	options := make([]moduleOption, 0, len(selected))
	for _, optionType := range selected {
		rangeForOption := optionRanges[optionType][grade]
		if part == "core" && optionType == "damageIncrease" {
			rangeForOption = map[string]optionRange{
				"normal": {5, 8}, "magic": {9, 15}, "rare": {16, 24}, "unique": {25, 36},
			}[grade]
		}
		value, err := secureInt(rangeForOption.min, rangeForOption.max)
		if err != nil {
			return generatedModule{}, err
		}
		options = append(options, moduleOption{Type: optionType, Value: value})
	}
	return generatedModule{
		TurretType: turretType,
		Part:       part,
		Family:     familyFor(turretType, part),
		Grade:      grade,
		Options:    options,
	}, nil
}

func rollGrade(drawCount int64) (string, error) {
	rates := [4]int{64, 26, 7, 3}
	switch {
	case drawCount >= 800:
		rates = [4]int{45, 35, 15, 5}
	case drawCount >= 500:
		rates = [4]int{51, 33, 12, 4}
	case drawCount >= 250:
		rates = [4]int{56, 30, 10, 4}
	case drawCount >= 100:
		rates = [4]int{60, 28, 9, 3}
	}
	roll, err := secureInt(0, 99)
	if err != nil {
		return "", err
	}
	cursor := 0
	for index, rate := range rates {
		cursor += rate
		if roll < cursor {
			return grades[index], nil
		}
	}
	return "normal", nil
}

func rollOptionCount(grade string) (int, error) {
	roll, err := secureInt(0, 99)
	if err != nil {
		return 0, err
	}
	cursor := 0
	for index, weight := range gradeOptionWeights[grade] {
		cursor += weight
		if roll < cursor {
			return index + 1, nil
		}
	}
	return 3, nil
}

func optionPool(turretType string, part string) []string {
	if part == "barrel" {
		return []string{"damageIncrease", "attackRateIncrease", "criticalChanceBonus", "criticalDamageBonus", "rangeIncrease"}
	}
	if part == "frame" {
		return []string{"levelUpCostDiscount", "linkUpgradeCostDiscount", "buildCostDiscount", "highLevelUpgradeCostDiscount", "gemEffectIncrease"}
	}
	switch turretType {
	case "arrow":
		return []string{"damageIncrease", "attackRateIncrease", "criticalChanceBonus", "projectileSpeedIncrease"}
	case "cannon":
		return []string{"damageIncrease", "splashRadiusIncrease", "splashSecondaryDamageBonus", "attackRateIncrease"}
	case "magic":
		return []string{"damageIncrease", "damageOverTimeIncrease", "burnDurationIncrease", "attackRateIncrease"}
	case "frost":
		return []string{"damageIncrease", "slowDurationIncrease", "slowStrengthBonus", "rangeIncrease"}
	case "sniper":
		return []string{"damageIncrease", "criticalChanceBonus", "criticalDamageBonus", "aimSpeedIncrease"}
	default:
		return []string{"damageIncrease", "lightningChainDamageIncrease", "lightningChainRangeIncrease", "attackRateIncrease"}
	}
}

func familyFor(turretType string, part string) string {
	families := map[string][3]string{
		"arrow":     {"rapidCore", "balancedBarrel", "stableFrame"},
		"cannon":    {"blastCore", "heavyBarrel", "reinforcedFrame"},
		"magic":     {"ignitionCore", "emberBarrel", "heatSinkFrame"},
		"frost":     {"frostCore", "coldBarrel", "coolingFrame"},
		"sniper":    {"scopeCore", "precisionBarrel", "anchorFrame"},
		"lightning": {"currentCore", "coilBarrel", "insulatedFrame"},
	}
	index := 0
	if part == "barrel" {
		index = 1
	} else if part == "frame" {
		index = 2
	}
	return families[turretType][index]
}

func validateModule(module generatedModule) error {
	if !contains(turretTypes, module.TurretType) || !contains(parts, module.Part) ||
		!contains(grades, module.Grade) || module.Family != familyFor(module.TurretType, module.Part) ||
		len(module.Options) == 0 || len(module.Options) > 3 {
		return errors.New("invalid module definition")
	}
	pool := optionPool(module.TurretType, module.Part)
	seen := make(map[string]struct{}, len(module.Options))
	for _, option := range module.Options {
		if !contains(pool, option.Type) {
			return errors.New("invalid module option")
		}
		if _, exists := seen[option.Type]; exists {
			return errors.New("duplicate module option")
		}
		seen[option.Type] = struct{}{}
		rangeForOption := optionRanges[option.Type][module.Grade]
		if module.Part == "core" && option.Type == "damageIncrease" {
			rangeForOption = map[string]optionRange{
				"normal": {5, 8}, "magic": {9, 15}, "rare": {16, 24}, "unique": {25, 36},
			}[module.Grade]
		}
		if option.Value < rangeForOption.min || option.Value > rangeForOption.max {
			return errors.New("module option value is outside catalog")
		}
	}
	return nil
}

func randomChoice(values []string) (string, error) {
	index, err := secureInt(0, len(values)-1)
	if err != nil {
		return "", err
	}
	return values[index], nil
}

func randomDistinct(values []string, count int) ([]string, error) {
	if count > len(values) {
		count = len(values)
	}
	remaining := append([]string(nil), values...)
	result := make([]string, 0, count)
	for len(result) < count {
		index, err := secureInt(0, len(remaining)-1)
		if err != nil {
			return nil, err
		}
		result = append(result, remaining[index])
		remaining = append(remaining[:index], remaining[index+1:]...)
	}
	return result, nil
}

func secureInt(minimum int, maximum int) (int, error) {
	if maximum < minimum {
		return 0, fmt.Errorf("invalid secure random range %d..%d", minimum, maximum)
	}
	value, err := rand.Int(rand.Reader, big.NewInt(int64(maximum-minimum+1)))
	if err != nil {
		return 0, fmt.Errorf("read secure random: %w", err)
	}
	return minimum + int(value.Int64()), nil
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
