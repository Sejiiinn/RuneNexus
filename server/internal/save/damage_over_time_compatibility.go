package save

import (
	"encoding/json"
	"math"
)

// DPS remains baked into legacy fields; optional coefficients retain the
// original additive layer so live training can join it after a checkpoint.
func validateDamageOverTimeMetadata(raw []byte, clientVersion int) error {
	var run struct {
		Enemies []json.RawMessage `json:"enemies"`
	}
	if len(raw) == 0 || string(raw) == "null" {
		return nil
	}
	if json.Unmarshal(raw, &run) != nil {
		return nil
	}
	validate := func(value json.RawMessage) error {
		if len(value) == 0 {
			return nil
		}
		var multiplier *float64
		if json.Unmarshal(value, &multiplier) != nil || multiplier == nil || math.IsNaN(*multiplier) || math.IsInf(*multiplier, 0) || *multiplier < 1 || *multiplier > 4 {
			return ErrClientUpdateRequired
		}
		if clientVersion < DamageTrainingClientCompatibilityVersion {
			return ErrClientUpdateRequired
		}
		return nil
	}
	for _, rawEnemy := range run.Enemies {
		var enemy map[string]json.RawMessage
		if json.Unmarshal(rawEnemy, &enemy) != nil {
			continue
		}
		if err := validate(enemy["poisonDamageOverTimeIncreaseMultiplier"]); err != nil {
			return err
		}
		var burns []json.RawMessage
		if json.Unmarshal(enemy["burnInstances"], &burns) != nil {
			continue
		}
		for _, rawBurn := range burns {
			var burn map[string]json.RawMessage
			if json.Unmarshal(rawBurn, &burn) != nil {
				continue
			}
			if err := validate(burn["damageOverTimeIncreaseMultiplier"]); err != nil {
				return err
			}
		}
	}
	return nil
}
