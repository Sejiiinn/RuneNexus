package save

import "encoding/json"

// Older codecs drop unknown turret types and per-stack poison timers, so a run
// that already holds either must not be resumed or overwritten by them.
const PoisonTurretClientCompatibilityVersion = 13

func validatePoisonTurretClient(activeRun []byte, clientVersion int) error {
	if clientVersion >= PoisonTurretClientCompatibilityVersion || len(activeRun) == 0 || string(activeRun) == "null" {
		return nil
	}
	var run struct {
		Turrets []struct {
			Type string `json:"type"`
		} `json:"turrets"`
		Enemies []struct {
			PoisonInstances []json.RawMessage `json:"poisonInstances"`
		} `json:"enemies"`
	}
	if json.Unmarshal(activeRun, &run) != nil {
		return nil
	}
	for _, turret := range run.Turrets {
		if turret.Type == "poison" {
			return ErrClientUpdateRequired
		}
	}
	for _, enemy := range run.Enemies {
		if len(enemy.PoisonInstances) > 0 {
			return ErrClientUpdateRequired
		}
	}
	return nil
}
