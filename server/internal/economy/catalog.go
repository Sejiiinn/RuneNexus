package economy

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"

	"github.com/Sejiiinn/RuneNexus/server/internal/contentregistry"
)

const (
	CatalogVersion              int32 = 2
	AuthorityVersion            int32 = 1
	RNGAlgorithmVersion         int32 = 1
	ModuleTicketDiamondCost     int64 = 40
	ResearchSlotTwoUnlockCost   int64 = 600
	ResearchDiamondMillis       int64 = 60_000
	StageElevenModuleTicketGift int64 = 5
)

var (
	turretTypes        = contentregistry.TurretTypes()
	parts              = contentregistry.ModuleParts()
	grades             = contentregistry.ModuleGrades()
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

// moduleRange returns the zero range for an option the catalog does not define.
func moduleRange(optionType, part, grade string) optionRange {
	limits, _ := contentregistry.ModuleRange(optionType, part, grade)
	return optionRange{limits.Min, limits.Max}
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
		rangeForOption := moduleRange(optionType, part, grade)
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
	return contentregistry.ModulePool(turretType, part)
}

func familyFor(turretType string, part string) string {
	return contentregistry.ModuleFamily(turretType, part)
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
		rangeForOption := moduleRange(option.Type, module.Part, module.Grade)
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
