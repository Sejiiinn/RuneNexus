extends RefCounted
## The whole stage, not just the first wave. Tower rights come from the same
## derived configuration as the build/reward UI, including restored equipment.
const Units = preload("res://presentation/battlefield_units.gd")

static func for_stage(catalog, index: int, derived: Dictionary, restored_state: Dictionary = {}) -> Dictionary:
	var enemies: Array = []
	for wave in range(catalog.wave_count(index)):
		for kind in catalog.wave_summary(index, wave).get("enemyCounts", {}):
			if kind not in enemies: enemies.append(kind)
	var towers: Array = derived.get("availableTurretTypes", ["arrow", "cannon", "magic", "frost"]).duplicate()
	for turret: Dictionary in restored_state.get("turrets", []):
		var kind := str(turret.get("type", ""))
		if Units.TURRET_MODELS.has(kind) and kind not in towers: towers.append(kind)
	enemies.sort()
	towers.sort()
	var paths: Array = []
	for kind: String in towers:
		if Units.TURRET_MODELS.has(kind): _add(paths, Units.TURRET_MODELS[kind])
	for kind: String in enemies:
		if Units.ENEMY_MODELS.has(kind): _add(paths, Units.ENEMY_MODELS[kind])
		if kind in ["normal", "fast", "tank"]: _add(paths, "res://assets/enemies/%s_death.glb" % kind)
	_add(paths, "res://assets/backgrounds/combat_space_nebula.png")
	_add(paths, "res://assets/ui/turret_levels.png")
	_add(paths, "res://assets/ui/death_silhouettes.png")
	return {"stage_id":catalog.stage_id(index),"enemy_types":enemies,"tower_types":towers,
		"map":catalog.stage_map(index),"paths":paths}

static func _add(paths: Array, path: String) -> void:
	if path not in paths: paths.append(path)
