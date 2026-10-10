package save

import (
	"encoding/json"

	"github.com/Sejiiinn/RuneNexus/server/internal/progression"
)

// Growth progression is stored in schema v2. Version 1 requires generation 3
// clients; generation 2 remains usable until this account first migrates.
const (
	EconomyClientCompatibilityVersion       = 2
	GrowthClientCompatibilityVersion        = 3
	CurrentGrowthVersion                    = 1
	ProgressionClientCompatibilityVersion   = 4
	RoutedContentClientCompatibilityVersion = 5
	CurrentProgressionVersion               = progression.Version
	CurrentStageCount                       = progression.StageCount
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
	if hasExpandedChapterThreeProgress(progression) && clientVersion < RoutedContentClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}
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

// Old codecs do not preserve route IDs. Gate only saves which use the new content,
// keeping generation four clients compatible with their existing 25-stage saves.
func ValidateContentClient(progression, activeRun []byte, clientVersion int) error {
	if err := ValidateGrowthClient(progression, clientVersion); err != nil {
		return err
	}
	var run struct {
		StageNumber int                          `json:"stageNumber"`
		Enemies     []map[string]json.RawMessage `json:"enemies"`
		SpawnQueue  []map[string]json.RawMessage `json:"spawnQueue"`
	}
	if json.Unmarshal(activeRun, &run) == nil && clientVersion < RoutedContentClientCompatibilityVersion {
		if run.StageNumber > 25 {
			return ErrClientUpdateRequired
		}
		for _, rows := range [][]map[string]json.RawMessage{run.Enemies, run.SpawnQueue} {
			for _, row := range rows {
				if _, present := row["routeId"]; present {
					return ErrClientUpdateRequired
				}
			}
		}
	}
	return nil
}

func hasExpandedChapterThreeProgress(raw []byte) bool {
	var p struct {
		Unlocked []int `json:"unlockedStageIds"`
		Cleared  []int `json:"clearedStageNumbers"`
		Claimed  []int `json:"claimedCorePointStageRewards"`
	}
	if json.Unmarshal(raw, &p) != nil {
		return false
	}
	for _, ids := range [][]int{p.Unlocked, p.Cleared, p.Claimed} {
		for _, id := range ids {
			if id > 25 {
				return true
			}
		}
	}
	return false
}
