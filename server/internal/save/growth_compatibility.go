package save

import (
	"encoding/json"

	"github.com/Sejiiinn/RuneNexus/server/internal/progression"
)

// Growth progression is stored in schema v2. Version 1 requires generation 3
// clients; generation 2 remains usable until this account first migrates.
const (
	EconomyClientCompatibilityVersion            = 2
	GrowthClientCompatibilityVersion             = 3
	CurrentGrowthVersion                         = 1
	ProgressionClientCompatibilityVersion        = 4
	RoutedContentClientCompatibilityVersion      = 5
	FifthLinkClientCompatibilityVersion          = 6
	GemRerollClientCompatibilityVersion          = 7
	GemOfferClientCompatibilityVersion           = 8
	BossDamageTrainingClientCompatibilityVersion = 11
	DamageTrainingClientCompatibilityVersion     = 12
	CurrentProgressionVersion                    = progression.Version
	CurrentStageCount                            = progression.StageCount
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
	for _, key := range damageTrainingFields {
		level, valid := optionalTrainingLevel(progression, key, 80)
		if !valid || (level > 0 && clientVersion < DamageTrainingClientCompatibilityVersion) {
			return ErrClientUpdateRequired
		}
	}
	level, valid := bossDamageTrainingLevel(progression)
	if !valid || (level > 0 && clientVersion < BossDamageTrainingClientCompatibilityVersion) {
		return ErrClientUpdateRequired
	}
	level, valid = poisonDamageTrainingLevel(progression)
	if !valid || (level > 0 && clientVersion < PoisonTurretClientCompatibilityVersion) {
		return ErrClientUpdateRequired
	}
	if hasFifthLinkResearch(progression) && clientVersion < FifthLinkClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}
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
	// Permanent upgrades have no reset command. Neither an old exact payload nor
	// a newly wrapped stale outbox may erase already purchased training.
	for _, key := range damageTrainingFields {
		before, _ := optionalTrainingLevel(current, key, 80)
		after, _ := optionalTrainingLevel(incoming, key, 80)
		if after < before {
			return ErrClientUpdateRequired
		}
	}
	beforeTraining, _ := bossDamageTrainingLevel(current)
	afterTraining, _ := bossDamageTrainingLevel(incoming)
	if afterTraining < beforeTraining {
		return ErrClientUpdateRequired
	}
	beforePoison, _ := poisonDamageTrainingLevel(current)
	afterPoison, _ := poisonDamageTrainingLevel(incoming)
	if afterPoison < beforePoison {
		return ErrClientUpdateRequired
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

// Absence is level zero and remains absent on the wire. A RawMessage rejects
// null/fractional/string values instead of silently treating them as zero.
var damageTrainingFields = [...]string{
	"directDamageTrainingUpgradeLevel",
	"splashDamageTrainingUpgradeLevel",
	"damageOverTimeTrainingUpgradeLevel",
}

func bossDamageTrainingLevel(raw []byte) (int, bool) {
	return optionalTrainingLevel(raw, "bossDamageTrainingUpgradeLevel", 40)
}

// Poison family training opens with the poison turret and shares its generation.
func poisonDamageTrainingLevel(raw []byte) (int, bool) {
	return optionalTrainingLevel(raw, "poisonDamageTrainingUpgradeLevel", 50)
}

func optionalTrainingLevel(raw []byte, key string, maximum int) (int, bool) {
	if len(raw) == 0 {
		return 0, true
	}
	var fields map[string]json.RawMessage
	if json.Unmarshal(raw, &fields) != nil {
		return 0, false
	}
	value, present := fields[key]
	if !present {
		return 0, true
	}
	var level *int
	if json.Unmarshal(value, &level) != nil || level == nil || *level < 0 || *level > maximum {
		return 0, false
	}
	return *level, true
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
	if err := validateDamageOverTimeMetadata(activeRun, clientVersion); err != nil {
		return err
	}
	if err := ValidateGemContentClient(activeRun, clientVersion); err != nil {
		return err
	}
	if err := validatePoisonTurretClient(activeRun, clientVersion); err != nil {
		return err
	}
	if err := validateSupportCoreClient(activeRun, clientVersion); err != nil {
		return err
	}
	if err := ValidateCoreTreeClient(progression, activeRun, clientVersion); err != nil {
		return err
	}
	var offer struct {
		ID       string `json:"gemOfferId"`
		Revision int64  `json:"gemOfferRevision"`
	}
	if json.Unmarshal(activeRun, &offer) == nil && (offer.ID != "" || offer.Revision > 0) && clientVersion < GemOfferClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}
	var reroll struct {
		Used int `json:"gemRerollsUsed"`
	}
	if json.Unmarshal(activeRun, &reroll) == nil && reroll.Used > 0 && clientVersion < GemRerollClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}
	if err := ValidateGrowthClient(progression, clientVersion); err != nil {
		return err
	}
	var run struct {
		StageNumber int `json:"stageNumber"`
		Turrets     []struct {
			SlotLimit int `json:"slotLimit"`
		} `json:"turrets"`
		Enemies    []map[string]json.RawMessage `json:"enemies"`
		SpawnQueue []map[string]json.RawMessage `json:"spawnQueue"`
	}
	validRun := json.Unmarshal(activeRun, &run) == nil
	if validRun && clientVersion < FifthLinkClientCompatibilityVersion {
		for _, turret := range run.Turrets {
			if turret.SlotLimit >= 5 {
				return ErrClientUpdateRequired
			}
		}
	}
	if validRun && clientVersion < RoutedContentClientCompatibilityVersion {
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

// Generation five codecs discard the new research ID. Protect only accounts
// which have begun using it, leaving existing three/four-slot saves compatible.
func hasFifthLinkResearch(raw []byte) bool {
	var p struct {
		Levels  map[string]int   `json:"researchLevels"`
		Elapsed map[string]int64 `json:"researchElapsedMillis"`
		Active  []struct {
			Type string `json:"type"`
		} `json:"activeResearches"`
	}
	if json.Unmarshal(raw, &p) != nil {
		return false
	}
	if p.Levels["linkExpansionTwo"] > 0 || p.Elapsed["linkExpansionTwo"] > 0 {
		return true
	}
	for _, active := range p.Active {
		if active.Type == "linkExpansionTwo" {
			return true
		}
	}
	return false
}
