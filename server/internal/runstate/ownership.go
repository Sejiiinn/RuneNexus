// Package runstate owns server-issued run identity and exact gem totals. Combat
// checkpoints only allocate those gems between loose inventory and turret slots.
package runstate

import (
	"bytes"
	"encoding/json"
	"errors"
	"math"
)

var ErrConflict = errors.New("server-owned run must be restored")

// ReadOwnedGems is the isolated checkpoint adapter. It counts the containers the
// save codec preserves, once. equippedGems is only the legacy fallback when the
// authoritative equippedGemSlots key is absent, never a second ownership source.
func ReadOwnedGems(raw []byte) (map[string]int64, error) {
	var run map[string]json.RawMessage
	if json.Unmarshal(raw, &run) != nil || run == nil {
		return nil, ErrConflict
	}
	owned := map[string]int64{}
	if inventory, exists := run["gemInventory"]; exists {
		var quantities map[string]json.RawMessage
		if json.Unmarshal(inventory, &quantities) != nil || quantities == nil {
			return nil, ErrConflict
		}
		for gem, value := range quantities {
			quantity, err := nonnegativeInteger(value)
			if err != nil || !ValidGem(gem) {
				return nil, ErrConflict
			}
			if quantity > 0 {
				owned[gem] = quantity
			}
		}
	}
	if turretsRaw, exists := run["turrets"]; exists {
		var turrets []json.RawMessage
		if json.Unmarshal(turretsRaw, &turrets) != nil || turrets == nil {
			return nil, ErrConflict
		}
		for _, turretRaw := range turrets {
			var turret map[string]json.RawMessage
			if json.Unmarshal(turretRaw, &turret) != nil || turret == nil {
				return nil, ErrConflict
			}
			slotsRaw, exists := turret["equippedGemSlots"]
			if !exists {
				slotsRaw, exists = turret["equippedGems"]
			}
			if !exists {
				continue
			}
			var kind string
			if json.Unmarshal(turret["type"], &kind) != nil || !validTurret(kind) {
				return nil, ErrConflict
			}
			limit := int64(1)
			if value, exists := turret["slotLimit"]; exists {
				var err error
				limit, err = nonnegativeInteger(value)
				if err != nil || limit < 1 || limit > 5 {
					return nil, ErrConflict
				}
			}
			var slots []json.RawMessage
			if json.Unmarshal(slotsRaw, &slots) != nil || slots == nil || int64(len(slots)) > limit {
				return nil, ErrConflict
			}
			seen := map[string]bool{}
			for _, slot := range slots {
				if bytes.Equal(bytes.TrimSpace(slot), []byte("null")) {
					continue
				}
				var gem string
				if json.Unmarshal(slot, &gem) != nil || !ValidGem(gem) || seen[gem] || owned[gem] == math.MaxInt64 {
					return nil, ErrConflict
				}
				seen[gem] = true
				owned[gem]++
			}
		}
	}
	return owned, nil
}

func ValidateOwnership(raw []byte, expected map[string]int64) error {
	actual, err := ReadOwnedGems(raw)
	if err != nil {
		return err
	}
	for gem, count := range expected {
		if !ValidGem(gem) || count < 0 || actual[gem] != count {
			return ErrConflict
		}
	}
	for gem, count := range actual {
		if expected[gem] != count {
			return ErrConflict
		}
	}
	return nil
}

func nonnegativeInteger(raw []byte) (int64, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] < '0' || raw[0] > '9' {
		return 0, ErrConflict
	}
	var value int64
	if json.Unmarshal(raw, &value) != nil || value < 0 {
		return 0, ErrConflict
	}
	return value, nil
}

func ValidGem(gem string) bool {
	switch gem {
	case "attackSpeed", "range", "physicalDamage", "elementalDamage", "lightWeapon", "heavyWeapon", "damageOverTime", "explosion", "chain", "criticalChance", "aimSpeed", "damageAmplifier", "armorPiercing", "multipleProjectiles":
		return true
	default:
		return false
	}
}

func validTurret(kind string) bool {
	switch kind {
	case "arrow", "cannon", "magic", "frost", "sniper", "lightning":
		return true
	default:
		return false
	}
}

// ValidatePristine permits a full client-generated initial checkpoint before
// StartRun binds it to a fresh server identity. It cannot carry reward progress.
func ValidatePristine(raw []byte, stage int32) error {
	var fields map[string]json.RawMessage
	if json.Unmarshal(raw, &fields) != nil || fields == nil {
		return ErrConflict
	}
	for _, key := range []string{"stageNumber", "completedRounds", "roundIndex", "gemRerollsUsed", "gemShards", "gemOfferRevision", "gemOfferEquipRevision", "gemEconomyRevision"} {
		if value, present := fields[key]; present {
			if _, err := nonnegativeInteger(value); err != nil {
				return ErrConflict
			}
		}
	}
	var run struct {
		RunID           string            `json:"economyRunId"`
		Stage           int32             `json:"stageNumber"`
		Phase           string            `json:"phase"`
		Completed       int64             `json:"completedRounds"`
		Round           int64             `json:"roundIndex"`
		Used            int64             `json:"gemRerollsUsed"`
		Options         []string          `json:"rewardOptions"`
		Purchased       bool              `json:"isPurchasedGemReward"`
		LegacyPaid      bool              `json:"paidGemRoll"`
		OfferID         string            `json:"gemOfferId"`
		OfferRevision   int64             `json:"gemOfferRevision"`
		OfferStatus     string            `json:"gemOfferStatus"`
		EconomyRevision int64             `json:"gemEconomyRevision"`
		EquipRevision   int64             `json:"gemOfferEquipRevision"`
		Shards          int64             `json:"gemShards"`
		ReturnPhase     *string           `json:"rewardReturnPhase"`
		Enemies         []json.RawMessage `json:"enemies"`
		SpawnQueue      []json.RawMessage `json:"spawnQueue"`
	}
	if json.Unmarshal(raw, &run) != nil || run.RunID != "" || stage <= 0 || run.Stage != stage || run.Phase != "preparation" || run.Completed != 0 || run.Round != 0 || run.Used != 0 || len(run.Options) != 0 || run.Purchased || run.LegacyPaid || run.OfferID != "" || run.OfferRevision != 0 || run.OfferStatus != "" {
		return ErrConflict
	}
	if run.Shards < 0 || run.EconomyRevision != 0 || run.EquipRevision != 0 || (run.ReturnPhase != nil && *run.ReturnPhase != "") || len(run.Enemies) != 0 || len(run.SpawnQueue) != 0 {
		return ErrConflict
	}
	return ValidateOwnership(raw, nil)
}
