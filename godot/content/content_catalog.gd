extends RefCounted
## Compiled content is read once; authoring and generation stay outside runtime.
## Growth/equipment are already resolved numeric inputs, never purchased here.
const TypedJson = preload("res://app/save_json.gd")
const Teleports = preload("res://combat/teleport_pairs.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const RuntimeFormat = preload("res://content/runtime_content_format.gd")
var _data: Dictionary = {}
var _revision := 0
var error: String = ""

func _begin_load() -> void:
	_data = {}
	error = ""
	_revision += 1

func load_catalog(path: String = "res://content/game_content.json") -> bool:
	_begin_load()
	var parsed: Dictionary = TypedJson.parse_record(FileAccess.get_file_as_string(path))
	if not parsed.ok:
		error = "Invalid content JSON: " + str(parsed.error)
		return false
	if not parsed.value is Dictionary or not parsed.value.has("schedulingPolicy"):
		error = "Shipped content requires compiled scheduling metadata"
		return false
	return _accept_content(parsed.value)

func _accept_content(candidate: Variant) -> bool:
	error = RuntimeFormat.validate(candidate)
	if not error.is_empty(): return false
	_data = candidate
	return true

func load_fixture_content(domain: Dictionary) -> bool:
	_begin_load()
	return _accept_content(RuntimeFormat.compact_fixture(domain))

func domain_snapshot() -> Dictionary:
	return RuntimeFormat.expand_content(_data) if is_loaded() else {}

func is_loaded() -> bool:
	return not _data.is_empty()

func content_revision() -> int:
	return _revision

func tile_size() -> float:
	return float(_data.units.tileSize) if is_loaded() else 0.0

func initial_delay() -> float:
	return float(_data.defaults.initialDelay) if is_loaded() else 0.0

func randomization() -> Dictionary:
	return _data.randomization.duplicate(true) if is_loaded() else {}

func enemy_types() -> Array:
	return _data.get("enemies", {}).keys()

func turret_types() -> Array:
	return _data.get("turrets", {}).keys()

func enemy_definition(type: String) -> Dictionary:
	return _data.get("enemyDefinitions", {}).get(type, {}).duplicate(true)

func enemy_template(type: String) -> Dictionary:
	return _data.get("enemies", {}).get(type, {}).duplicate(true)

func turret_definition(type: String) -> Dictionary:
	if not _data.get("turrets", {}).has(type): return {}
	return _data.turrets[type].configuration.statInput.definition.duplicate(true)

func stage_map(index: int) -> Dictionary:
	if not _valid_stage(index): return {}
	var result: Dictionary = _data.stages[index].map.duplicate(true)
	result.theme = result.tileTheme
	return result

func wave_definition(stage_index: int, round_index: int) -> Dictionary:
	if not _valid_wave(stage_index, round_index): return {}
	return RuntimeFormat.expand_wave(_data, _data.stages[stage_index].waves[round_index])

func wave_durability(stage_index: int, round_index: int, type: String) -> Dictionary:
	if not _valid_wave(stage_index, round_index): return {}
	if not _data.enemies.has(type):
		error = "Unknown enemy type"
		return {}
	return RuntimeFormat.durability(_data.stages[stage_index].waves[round_index], type)

func _schedule(stage_index: int, round_index: int) -> Array:
	return _data.spawnSchedules[_data.stages[stage_index].waves[round_index].spawnSchedule]

func wave_summary(stage_index: int, round_index: int) -> Dictionary:
	if not _valid_wave(stage_index, round_index): return {}
	var source: Dictionary = _data.stages[stage_index].waves[round_index]
	var counts := {}
	for row in _schedule(stage_index, round_index):
		counts[row[0]] = int(counts.get(row[0], 0)) + 1
	# Compiler owns group membership, timeline and chronological order. Summaries
	# only add presentation labels; they never reconstruct dispatch scheduling.
	var route_groups: Array = source.get("groupDispatch", []).duplicate(true)
	for group in route_groups:
		var route := route_map(stage_index,group.routeId)
		var portal := spawn_portal(stage_index,group.routeId)
		group.routeLabel = route.get("label", "")
		group.spawnPortalLabel = portal.get("label", "")
		group.spawnDelay = group.firstDispatch
	return {"routeGroups":route_groups,"round": source.round, "previewText": source.get("previewText", ""),
		"clearRewardGold": source.get("clearRewardGold", 0), "spawnCount": _schedule(stage_index, round_index).size(),
		"boss": wave_has_boss(stage_index, round_index), "enemyCounts": counts}

func stage_count() -> int:
	return _data.get("stages", []).size()

func stage_id(index: int) -> int:
	return int(_data.stages[index].id) if _valid_stage(index) else 0

func stage_index(id: int) -> int:
	for index in range(stage_count()):
		if _data.stages[index].id == id: return index
	error = "Unknown stage ID"
	return -1

func wave_count(index: int) -> int:
	return _data.stages[index].waves.size() if _valid_stage(index) else 0

func wave_has_boss(stage_index: int, round_index: int) -> bool:
	if not _valid_wave(stage_index, round_index): return false
	for group in _data.stages[stage_index].waves[round_index].groups:
		if str(group.enemyType).to_lower().contains("boss"): return true
	return false

func stage_summary(index: int) -> Dictionary:
	# UI and settlement need scalar metadata, not a copy of all compiled waves.
	if not _valid_stage(index): return {}
	var source: Dictionary = _data.stages[index]
	return {"id":source.id, "name":source.get("name", ""), "waveCount":source.waves.size(),
		"firstClearCorePointReward":source.get("firstClearCorePointReward", 0),
		"firstClearTurretModuleTicketReward":source.get("firstClearTurretModuleTicketReward", 0)}

func stage(index: int) -> Dictionary:
	if index < 0 or index >= stage_count():
		error = "Unknown stage index"
		return {}
	var result: Dictionary = _data.stages[index].duplicate(true)
	for wi in range(result.waves.size()): result.waves[wi] = wave_definition(index, wi)
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
	if round_index < 0 or round_index >= _data.stages[stage_index].waves.size():
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
	if _data.is_empty():
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
	return {"tileSize": float(tile), "boardDistanceScale": float(tile) / float(_data.units.tileSize), "origin": [float(origin[0]), float(origin[1])]}

# Empty route IDs retain the legacy primary path; explicit IDs never silently fall back.
func route_map(stage_index: int, route_id: String = "") -> Dictionary:
	if not _valid_stage(stage_index): return {}
	var map: Dictionary = _data.stages[stage_index].map
	if route_id.is_empty(): return map
	for route in map.get("routes", []):
		if route.id == route_id: return route
	error = "Unknown route: " + route_id
	return {}

# Portal identity is derived from authored metadata, never separately persisted.
# Static helpers let map-only presentation share the exact same fallback rule.
static func map_spawn_portals(map: Dictionary) -> Array:
	if map.has("spawnPortals"): return map.spawnPortals.duplicate(true)
	if map.get("path", []).is_empty(): return []
	return [{"id":"default","label":"","cell":map.path[0].duplicate()}]

static func map_route_portal(map: Dictionary, route_id: String = "") -> Dictionary:
	var portals := map_spawn_portals(map)
	if portals.is_empty(): return {}
	var selected: Dictionary = map
	if not map.get("routes", []).is_empty():
		selected = map.routes[0] if route_id.is_empty() else {}
		for route in map.routes:
			if route.id == route_id: selected = route; break
	elif not route_id.is_empty(): return {}
	if selected.is_empty(): return {}
	var portal_id: String = selected.get("spawnPortalId",portals[0].id)
	for portal in portals:
		if portal.id == portal_id: return portal
	return {}

func spawn_portals(stage_index: int) -> Array:
	return map_spawn_portals(_data.stages[stage_index].map) if _valid_stage(stage_index) else []

func spawn_portal(stage_index: int, route_id: String = "") -> Dictionary:
	if not _valid_stage(stage_index): return {}
	var result := map_route_portal(_data.stages[stage_index].map,route_id)
	if result.is_empty(): error = "Unknown route or spawn portal: " + route_id
	return result

func route_portal(stage_index: int, route_id: String = "") -> Dictionary:
	return spawn_portal(stage_index,route_id)

func world_path(stage_index: int, inputs: Dictionary = {}) -> Array:
	if not _valid_stage(stage_index): return []
	var layout := _layout(inputs)
	if layout.is_empty(): return []
	var result: Array = []
	var selected := route_map(stage_index, str(inputs.get("routeId", "")))
	if selected.is_empty(): return []
	for point in selected.path:
		result.append({"x": layout.origin[0] + (float(point[0]) + 0.5) * layout.tileSize, "y": layout.origin[1] + (float(point[1]) + 0.5) * layout.tileSize})
	return result

# Validation-only entry points share every rejection with materialization. They
# deliberately avoid world paths, enemy dictionaries and randomized spawn rows.
func _bootstrap_layout(stage_index: int, inputs: Dictionary) -> Dictionary:
	if not _valid_stage(stage_index): return {}
	for key in ["defenseConfig", "coreConfig"]:
		if inputs.has(key) and not inputs[key] is Dictionary:
			error = "Configuration must be a dictionary: " + key
			return {}
	var teleport_error := Teleports.validate_map(_data.stages[stage_index].map)
	if not teleport_error.is_empty():
		error = teleport_error
		return {}
	var layout := _layout(inputs)
	if layout.is_empty() or _data.stages[stage_index].map.path.is_empty(): return {}
	return layout

func validate_bootstrap(stage_index: int, inputs: Dictionary = {}) -> bool:
	return not _bootstrap_layout(stage_index,inputs).is_empty()

func bootstrap(stage_index: int, inputs: Dictionary = {}) -> Dictionary:
	var result := _bootstrap_layout(stage_index,inputs)
	if result.is_empty(): return {}
	result.path = world_path(stage_index, inputs)
	if result.path.is_empty(): return {}
	var pairs := Teleports.compile_map(_data.stages[stage_index].map)
	if not pairs.is_empty(): result.teleportPairs = pairs
	if _data.stages[stage_index].map.has("spawnPortals"): result.spawnPortalId = spawn_portal(stage_index).id
	if _data.stages[stage_index].map.has("routes"):
		result.routes = []
		for route in _data.stages[stage_index].map.routes:
			var route_inputs := inputs.duplicate()
			route_inputs.routeId = route.id
			var compiled := {"id":route.id,"path":world_path(stage_index,route_inputs),"teleportPairs":Teleports.compile_map(route)}
			if route.has("spawnPortalId"): compiled.spawnPortalId = route.spawnPortalId
			result.routes.append(compiled)
	result.defense = {"config": _data.defenseConfig.duplicate(true)}
	if inputs.has("defenseConfig"): result.defense.config.merge(inputs.defenseConfig, true)
	if inputs.has("coreConfig"): result.coreConfig = inputs.coreConfig.duplicate(true)
	return result

func _enemy_layout(stage_index: int, round_index: int, type: String, inputs: Dictionary) -> Dictionary:
	if not _valid_wave(stage_index, round_index): return {}
	if not _data.enemies.has(type):
		error = "Unknown enemy type"
		return {}
	if not _valid_enemy_values(inputs.get("enemyValues", {})): return {}
	if route_map(stage_index,str(inputs.get("routeId", ""))).is_empty(): return {}
	var layout := _layout(inputs)
	if layout.is_empty() or _data.stages[stage_index].map.path.is_empty(): return {}
	return layout

func validate_enemy(stage_index: int, round_index: int, type: String, inputs: Dictionary = {}) -> bool:
	return not _enemy_layout(stage_index,round_index,type,inputs).is_empty()

func validate_randomized_enemy(stage_index: int, round_index: int, type: String, inputs: Dictionary = {}) -> bool:
	# Pending overrides replace caller enemyValues. RNG produces finite phase and
	# integer rewards; its lane offset is finite exactly when the amplitude is.
	if not _valid_wave(stage_index, round_index): return false
	var pending := inputs.duplicate()
	pending.enemyValues = {"laneOffsetRatio":float(_data.randomization.laneOffsetAmplitudes.get(type,0.0)),"visualPhase":0.0,"diamondReward":0}
	return validate_enemy(stage_index,round_index,type,pending)

func enemy(stage_index: int, round_index: int, type: String, id: int = 100000, inputs: Dictionary = {}) -> Dictionary:
	var layout := _enemy_layout(stage_index,round_index,type,inputs)
	if layout.is_empty(): return {}
	var result: Dictionary = _data.enemies[type].duplicate(true)
	var durability: Dictionary = RuntimeFormat.durability(_data.stages[stage_index].waves[round_index], type)
	for key in ["Hp", "Shield", "Armor"]:
		result["max" + key] = durability["max" + key]
		result[key.to_lower()] = durability["max" + key]
	result.id = id
	for key in ["laneOffsetRatio", "visualPhase", "diamondReward"]:
		if inputs.get("enemyValues", {}).has(key): result[key] = inputs.enemyValues[key]
	result.path = world_path(stage_index, inputs)
	if result.path.is_empty(): return {}
	var route_id := str(inputs.get("routeId", ""))
	if route_id.is_empty() and not _data.stages[stage_index].map.get("routes", []).is_empty(): route_id = _data.stages[stage_index].map.routes[0].id
	if not route_id.is_empty(): result.routeId = route_id
	if _data.stages[stage_index].map.has("spawnPortals"): result.spawnPortalId = spawn_portal(stage_index,route_id).id
	var pairs := Teleports.compile_map(route_map(stage_index,str(inputs.get("routeId", ""))))
	if not pairs.is_empty(): result.teleportPairs = pairs
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
	var delay: Variant = inputs.get("initialDelay", _data.defaults.initialDelay)
	if not _finite_number(delay) or delay < 0.0:
		error = "Initial delay must be finite and nonnegative"
		return {}
	var source: Dictionary = _data.stages[stage_index].waves[round_index]
	var schedule: Array = _schedule(stage_index, round_index)
	if inputs.has("spawnValues"):
		if not inputs.spawnValues is Array or inputs.spawnValues.size() != schedule.size():
			error = "Spawn input count differs from schedule"
			return {}
		for values in inputs.spawnValues:
			if not _valid_enemy_values(values): return {}
	var queue: Array = []
	for index in range(schedule.size()):
		var entry: Array = schedule[index]
		var spawn_inputs := inputs.duplicate()
		if entry.size() > 2: spawn_inputs.routeId = entry[2]
		var prepared := enemy(stage_index, round_index, entry[0], first_enemy_id + index, spawn_inputs)
		if prepared.is_empty(): return {}
		if inputs.has("spawnValues"):
			prepared.merge(inputs.spawnValues[index], true)
		queue.append({"enemyType": entry[0], "delay": entry[1] + float(delay), "enemy": prepared})
		if prepared.has("routeId"): queue[-1].routeId = prepared.routeId
	return {"id": source.round, "active": true, "spawnQueue": queue}

func turret(type: String = "arrow", inputs: Dictionary = {}) -> Dictionary:
	if not _data.get("turrets", {}).has(type):
		error = "Unknown turret type"
		return {}
	if not inputs.get("statInput", {}) is Dictionary:
		error = "Stat input must be a dictionary"
		return {}
	var result: Dictionary = _data.turrets[type].configuration.statInput.duplicate(true)
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
	return {} if input.is_empty() else Stats.shared_stats_at(input, int(input.level))

func random_spawn_values(stage_index: int, round_index: int, rng: RandomNumberGenerator) -> Array:
	if not _valid_wave(stage_index, round_index): return []
	if rng == null:
		error = "Missing random number generator"
		return []
	var values: Array = []
	var rules: Dictionary = _data.randomization
	for spawn in _schedule(stage_index, round_index):
		var type: String = spawn[0]
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
