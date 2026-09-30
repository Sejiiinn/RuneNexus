package save

import (
	"encoding/json"

	"github.com/Sejiiinn/RuneNexus/server/internal/progression"
)

// Growth progression is stored in schema v2. Version 1 requires generation 3
// clients; generation 2 remains usable until this account first migrates.
const (
	EconomyClientCompatibilityVersion     = 2
	GrowthClientCompatibilityVersion      = 3
	CurrentGrowthVersion                  = 1
	ProgressionClientCompatibilityVersion = 4
	CurrentProgressionVersion             = progression.Version
	CurrentStageCount                     = progression.StageCount
)

func GrowthVersion(progression []byte) int {
	var value struct {
		GrowthVersion int `json:"growthVersion"`
	}
	if json.Unmarshal(progression, &value) != nil {
		return 0
	}
	return value.GrowthVersion
}

func ClientCompatibilityFromBody(raw []byte) int {
	var value struct {
		Version int `json:"clientCompatibilityVersion"`
	}
	if json.Unmarshal(raw, &value) != nil {
		return 0
	}
	return value.Version
}

func ValidateGrowthClient(progression []byte, clientVersion int) error {
	if ProgressionVersion(progression) >= CurrentProgressionVersion && clientVersion < ProgressionClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}
	if GrowthVersion(progression) >= CurrentGrowthVersion && clientVersion < GrowthClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}
	return nil
}

// Even a current client must not overwrite an upgraded save with an old outbox.
func ValidateGrowthUpdate(current, incoming []byte, clientVersion int) error {
	if err := ValidateGrowthClient(current, clientVersion); err != nil {
		return err
	}
	if err := ValidateGrowthClient(incoming, clientVersion); err != nil {
		return err
	}
	if GrowthVersion(incoming) < GrowthVersion(current) || GrowthVersion(incoming) > CurrentGrowthVersion {
		return ErrClientUpdateRequired
	}
	if ProgressionVersion(incoming) < ProgressionVersion(current) || ProgressionVersion(incoming) > CurrentProgressionVersion {
		return ErrClientUpdateRequired
	}
	if ProgressionVersion(current) > 0 {
		var before, after progressionRights
		if json.Unmarshal(current, &before) != nil || json.Unmarshal(incoming, &after) != nil {
			return ErrClientUpdateRequired
		}
		for _, stage := range before.UnlockedStageIDs {
			if !containsValue(after.UnlockedStageIDs, stage) {
				return ErrClientUpdateRequired
			}
		}
		for _, right := range before.GrandfatherUnlocks {
			if !containsValue(after.GrandfatherUnlocks, right) {
				return ErrClientUpdateRequired
			}
		}
	}
	return nil
}

type progressionRights struct {
	Version            int      `json:"progressionVersion"`
	UnlockedStageIDs   []int    `json:"unlockedStageIds"`
	GrandfatherUnlocks []string `json:"grandfatherUnlocks"`
}

func ProgressionVersion(progression []byte) int {
	var value progressionRights
	if json.Unmarshal(progression, &value) != nil {
		return 0
	}
	return value.Version
}

func containsValue[T comparable](values []T, expected T) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}
