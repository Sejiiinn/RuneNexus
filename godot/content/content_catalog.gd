extends RefCounted
## Generated Dart definitions are read once; runtime needs no Dart process.
## Growth/equipment are already resolved numeric inputs, never purchased here.
const TypedJson = preload("res://app/save_json.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
var data: Dictionary = {}
var error: String = ""

func load_catalog(path: String = "res://content/game_content.json") -> bool:
	data = {}
	error = ""
	var parsed: Dictionary = TypedJson.parse_record(FileAccess.get_file_as_string(path))
	if not parsed.ok or not parsed.value is Dictionary:
		error = "Invalid content JSON: " + str(parsed.error)
		return false
	var candidate: Dictionary = parsed.value
	if candidate.get("schemaVersion") != 1 or not candidate.get("stages") is Array or not candidate.get("enemies") is Dictionary or not candidate.get("turrets") is Dictionary:
		error = "Unsupported content schema"
		return false
	for key in ["units", "defenseConfig", "defaults", "randomization"]:
		if not candidate.get(key) is Dictionary:
			error = "Missing content section: " + key
			return false
	if candidate.units.get("tileSize") != 48.0 or candidate.units.get("time") != "seconds" or not candidate.defaults.get("initialDelay") is float or not candidate.defenseConfig.get("maxHp") is float:
		error = "Unsupported units/defaults"
		return false
	for type in candidate.enemies:
		var template: Variant = candidate.enemies[type]
		if not template is Dictionary or template.get("type") != type or not template.has_all(["presentationSize", "visualOffset", "collisionRadius", "targetingRadius", "maxHp", "speed", "coreDamage"]):
			error = "Invalid enemy template: " + str(type)
			return false
	for type in candidate.turrets:
		var template: Variant = candidate.turrets[type]
		if not template is Dictionary or not template.get("configuration") is Dictionary or not template.configuration.get("statInput") is Dictionary:
			error = "Invalid turret template: " + str(type)
			return false
	var seen := {}
	for source in candidate.stages:
		if not source is Dictionary or not source.has_all(["id", "waves", "map"]) or seen.has(source.get("id")):
			error = "Missing/duplicate stage ID"
			return false
		seen[source.id] = true
		if not source.id is int or not source.get("waves") is Array or not source.get("map") is Dictionary:
			error = "Invalid stage type"
			return false
		var map: Dictionary = source.map
		if not map.get("columns") is int or not map.get("rows") is int or not map.get("tiles") is Array or map.tiles.size() != map.columns * map.rows or not map.get("path") is Array or map.path.size() < 2:
			error = "Invalid map dimensions/path"
			return false
		for point in map.path:
			if not point is Array or point.size() != 2 or not point[0] is int or not point[1] is int:
				error = "Invalid path tile coordinates"
				return false
		var round_ids := {}
		for definition in source.waves:
			if not definition is Dictionary or not definition.has_all(["round", "spawnQueue", "enemyDurability"]) or not definition.spawnQueue is Array or not definition.enemyDurability is Dictionary or not definition.get("round") is int or round_ids.has(definition.round):
				error = "Invalid/duplicate wave ID"
				return false
			round_ids[definition.round] = true
			for type in candidate.enemies:
				var durability: Variant = definition.enemyDurability.get(type)
				if not durability is Dictionary or not durability.get("maxHp") is float or not durability.get("maxShield") is float or not durability.get("maxArmor") is float:
					error = "Invalid durability numeric type: " + str(type)
					return false
			var previous := -INF
			for entry in definition.spawnQueue:
				if not entry is Dictionary or not entry.has_all(["delay", "enemyType"]) or not entry.delay is float or entry.delay < 0.0 or entry.delay < previous or not candidate.enemies.has(entry.enemyType) or not definition.enemyDurability.has(entry.enemyType):
					error = "Invalid spawn order/type/reference"
					return false
				previous = entry.delay
	data = candidate
	return true

func stage_count() -> int:
	return data.get("stages", []).size()

func stage(index: int) -> Dictionary:
	if index < 0 or index >= stage_count():
		error = "Unknown stage index"
		return {}
	var result: Dictionary = data.stages[index].duplicate(true)
	result.map.theme = result.map.tileTheme
	result.path = world_path(index)
	return result

func _valid_stage(stage_index: int) -> bool:
	if stage_index < 0 or stage_index >= stage_count():
		error = "Unknown stage index"
		return false
	return true

func _valid_wave(stage_index: int, round_index: int) -> bool:
	if not _valid_stage(stage_index): return false
	if round_index < 0 or round_index >= data.stages[stage_index].waves.size():
		error = "Unknown wave index"
		return false
	return true

func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _valid_enemy_values(value: Variant) -> bool:
	if not value is Dictionary:
		error = "Enemy values must be a dictionary"
		return false
	for key in value:
		if key in ["laneOffsetRatio", "visualPhase"]:
			if not value[key] is float or not is_finite(value[key]):
				error = "Enemy visual values must be finite floats"
				return false
		elif key == "diamondReward":
			if not value[key] is int or value[key] < 0:
				error = "Diamond reward must be a nonnegative integer"
				return false
		else:
			error = "Unknown enemy value: " + str(key)
			return false
	return true

func _layout(inputs: Dictionary) -> Dictionary:
	if data.is_empty():
		error = "Content catalog is not loaded"
		return {}
	var tile: Variant = inputs.get("tileSize", 1.0)
	var origin: Variant = inputs.get("origin", [0.0, 0.0])
	if not _finite_number(tile) or tile <= 0.0 or not origin is Array or origin.size() != 2:
		error = "Invalid layout"
		return {}
	if not _finite_number(origin[0]) or not _finite_number(origin[1]):
		error = "Origin must contain finite numbers"
		return {}
	return {"tileSize": float(tile), "boardDistanceScale": float(tile) / float(data.units.tileSize), "origin": [float(origin[0]), float(origin[1])]}

func world_path(stage_index: int, inputs: Dictionary = {}) -> Array:
	if not _valid_stage(stage_index): return []
	var layout := _layout(inputs)
	if layout.is_empty(): return []
	var result: Array = []
	for point in data.stages[stage_index].map.path:
		result.append({"x": layout.origin[0] + (float(point[0]) + 0.5) * layout.tileSize, "y": layout.origin[1] + (float(point[1]) + 0.5) * layout.tileSize})
	return result

func bootstrap(stage_index: int, inputs: Dictionary = {}) -> Dictionary:
	if not _valid_stage(stage_index): return {}
	for key in ["defenseConfig", "coreConfig"]:
		if inputs.has(key) and not inputs[key] is Dictionary:
			error = "Configuration must be a dictionary: " + key
			return {}
	var result := _layout(inputs)
	if result.is_empty(): return {}
	result.path = world_path(stage_index, inputs)
	if result.path.is_empty(): return {}
	result.defense = {"config": data.defenseConfig.duplicate(true)}
	if inputs.has("defenseConfig"): result.defense.config.merge(inputs.defenseConfig, true)
	if inputs.has("coreConfig"): result.coreConfig = inputs.coreConfig.duplicate(true)
	return result

func enemy(stage_index: int, round_index: int, type: String, id: int = 100000, inputs: Dictionary = {}) -> Dictionary:
	if not _valid_wave(stage_index, round_index): return {}
	if not data.enemies.has(type):
		error = "Unknown enemy type"
		return {}
	if not _valid_enemy_values(inputs.get("enemyValues", {})): return {}
	var layout := _layout(inputs)
	if layout.is_empty(): return {}
	var result: Dictionary = data.enemies[type].duplicate(true)
	var durability: Dictionary = data.stages[stage_index].waves[round_index].enemyDurability[type]
	for key in ["Hp", "Shield", "Armor"]:
		result["max" + key] = durability["max" + key]
		result[key.to_lower()] = durability["max" + key]
	result.id = id
	for key in ["laneOffsetRatio", "visualPhase", "diamondReward"]:
		if inputs.get("enemyValues", {}).has(key): result[key] = inputs.enemyValues[key]
	result.path = world_path(stage_index, inputs)
	if result.path.is_empty(): return {}
	result.x = result.path[0].x
	result.y = result.path[0].y
	result.position = {"x": result.x, "y": result.y}
	result.boardDistanceScale = layout.boardDistanceScale
	for key in ["presentationSize", "visualOffset"]:
		for index in range(result[key].size()): result[key][index] *= layout.boardDistanceScale
	for key in ["collisionRadius", "targetingRadius"]: result[key] *= layout.boardDistanceScale
	for index in range(1, result.path.size()):
		var dx: float = result.path[index].x - result.path[index - 1].x
		var dy: float = result.path[index].y - result.path[index - 1].y
		if dx != 0.0 or dy != 0.0:
			result.targetIndex = index
			result.facingAngle = atan2(dy, dx)
			break
	return result

func wave(stage_index: int, round_index: int, first_enemy_id: int = 100000, inputs: Dictionary = {}) -> Dictionary:
	if not _valid_wave(stage_index, round_index) or _layout(inputs).is_empty(): return {}
	var delay: Variant = inputs.get("initialDelay", data.defaults.initialDelay)
	if not _finite_number(delay) or delay < 0.0:
		error = "Initial delay must be finite and nonnegative"
		return {}
	var source: Dictionary = data.stages[stage_index].waves[round_index]
	if inputs.has("spawnValues"):
		if not inputs.spawnValues is Array or inputs.spawnValues.size() != source.spawnQueue.size():
			error = "Spawn input count differs from schedule"
			return {}
		for values in inputs.spawnValues:
			if not _valid_enemy_values(values): return {}
	var queue: Array = []
	for index in range(source.spawnQueue.size()):
		var entry: Dictionary = source.spawnQueue[index]
		var prepared := enemy(stage_index, round_index, entry.enemyType, first_enemy_id + index, inputs)
		if prepared.is_empty(): return {}
		if inputs.has("spawnValues"):
			prepared.merge(inputs.spawnValues[index], true)
		queue.append({"enemyType": entry.enemyType, "delay": entry.delay + float(delay), "enemy": prepared})
	return {"id": source.round, "active": true, "spawnQueue": queue}

func turret(type: String = "arrow", inputs: Dictionary = {}) -> Dictionary:
	if not data.get("turrets", {}).has(type):
		error = "Unknown turret type"
		return {}
	if not inputs.get("statInput", {}) is Dictionary:
		error = "Stat input must be a dictionary"
		return {}
	var result: Dictionary = data.turrets[type].configuration.statInput.duplicate(true)
	var layout := _layout(inputs)
	if layout.is_empty(): return {}
	result.boardDistanceScale = layout.boardDistanceScale
	result.lightningChainJumpRange *= layout.boardDistanceScale
	# Only known, explicitly supplied stat inputs cross the app/runtime boundary.
	for key in inputs.get("statInput", {}):
		if key in ["definition", "boardDistanceScale"] or not result.has(key):
			error = "Unsupported turret input: " + str(key)
			return {}
		result[key] = inputs.statInput[key]
	return result

func turret_stats(type: String = "arrow", inputs: Dictionary = {}) -> Dictionary:
	var input := turret(type, inputs)
	return {} if input.is_empty() else Stats.stats_at(input, int(input.level))

func random_spawn_values(stage_index: int, round_index: int, rng: RandomNumberGenerator) -> Array:
	if not _valid_wave(stage_index, round_index): return []
	if rng == null:
		error = "Missing random number generator"
		return []
	var values: Array = []
	var rules: Dictionary = data.randomization
	for spawn in data.stages[stage_index].waves[round_index].spawnQueue:
		var type: String = spawn.enemyType
		var lane: float = (rng.randf() * 2.0 - 1.0) * rules.laneOffsetAmplitudes[type]
		var phase := rng.randf()
		var reward := 0
		if not type in rules.bossTypes:
			var roll := rng.randf()
			var boundary: float = rules.carrierChance * rules.oneDiamondChanceGivenCarrier
			if roll < boundary: reward = 1
			elif roll < boundary + rules.carrierChance * rules.twoDiamondChanceGivenCarrier: reward = 2
			elif roll < boundary + rules.carrierChance * (rules.twoDiamondChanceGivenCarrier + rules.threeDiamondChanceGivenCarrier): reward = 3
		values.append({"laneOffsetRatio": lane, "visualPhase": phase, "diamondReward": reward})
	return values
