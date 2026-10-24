package save

import "encoding/json"

// Older codecs drop unknown turret types, poison modules and per-stack poison
// timers, so a run that already holds any of them must not be resumed or
// overwritten by them.
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
		Modules []turretModuleType `json:"runTurretModules"`
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
	return requirePoisonModuleClient(run.Modules)
}

type turretModuleType struct {
	TurretType string `json:"turretType"`
}

func requirePoisonModuleClient(modules []turretModuleType) error {
	for _, module := range modules {
		if module.TurretType == "poison" {
			return ErrClientUpdateRequired
		}
	}
	return nil
}

// ValidateModuleContentClient keeps an older codec, which silently drops poison
// modules, from rewriting the saved module mirror and losing their equip state.
func ValidateModuleContentClient(turretModules []byte, clientVersion int) error {
	if clientVersion >= PoisonTurretClientCompatibilityVersion || len(turretModules) == 0 || string(turretModules) == "null" {
		return nil
	}
	var inventory struct {
		Items []turretModuleType `json:"items"`
	}
	if json.Unmarshal(turretModules, &inventory) != nil {
		return nil
	}
	return requirePoisonModuleClient(inventory.Items)
}
