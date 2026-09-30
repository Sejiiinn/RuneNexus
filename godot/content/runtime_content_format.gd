extends RefCounted
## The sole runtime wire boundary. Shared schedules stay compact until requested.
const TypedJson = preload("res://app/save_json.gd")
const Teleports = preload("res://combat/teleport_pairs.gd")
const SPAWN_COLUMNS = ["enemyType", "delay"]
const DURABILITY_COLUMNS = ["maxHp", "maxShield", "maxArmor"]
const ROOT_FIELDS = ["schemaVersion", "units", "defaults", "randomization", "defenseConfig", "enemyDefinitions", "enemies", "turrets", "stages", "runtimeFormat", "spawnSchedules"]
const STAGE_FIELDS = ["id", "name", "firstClearCorePointReward", "firstClearTurretModuleTicketReward", "map", "waves"]
const WAVE_FIELDS = ["round", "previewText", "clearRewardGold", "groups", "spawnSchedule", "enemyDurability"]

static func validate(candidate: Variant) -> String:
	if not TypedJson.is_json_value(candidate): return "Invalid content JSON value"
	if not candidate is Dictionary or not candidate.get("schemaVersion") is int or candidate.schemaVersion != 2:
		return "Unsupported content schema"
	if not _fields(candidate, ROOT_FIELDS): return "Invalid runtime root fields"
	if not candidate.get("runtimeFormat") is Dictionary or candidate.runtimeFormat.size() != 2 or candidate.runtimeFormat.get("spawnColumns") != SPAWN_COLUMNS or candidate.runtimeFormat.get("durabilityColumns") != DURABILITY_COLUMNS:
		return "Unsupported runtime content columns"
	for key in ["units", "defenseConfig", "defaults", "randomization", "enemies", "enemyDefinitions", "turrets", "spawnSchedules"]:
		if not candidate.get(key) is Dictionary or candidate[key].is_empty(): return "Missing content section: " + key
	if not candidate.get("stages") is Array or candidate.stages.is_empty(): return "Missing content stages"
	if not _float(candidate.units.get("tileSize")) or candidate.units.tileSize != 48.0 or candidate.units.get("time") != "seconds" or not _float(candidate.defaults.get("initialDelay")) or candidate.defaults.initialDelay < 0.0 or not _float(candidate.defenseConfig.get("maxHp")):
		return "Unsupported units/defaults"
	for type in candidate.enemies:
		var template: Variant = candidate.enemies[type]
		if not type is String or not template is Dictionary or template.get("type") != type or not template.has_all(["presentationSize", "visualOffset", "collisionRadius", "targetingRadius", "maxHp", "speed", "coreDamage"]): return "Invalid enemy template: " + str(type)
		if not candidate.enemyDefinitions.get(type) is Dictionary: return "Missing enemy definition: " + str(type)
		for field in ["presentationSize", "visualOffset"]:
			if not template[field] is Array or template[field].size() != 2: return "Invalid enemy dimensions: " + str(type)
			for value in template[field]:
				if not _float(value): return "Invalid enemy numeric type: " + str(type)
		for field in ["collisionRadius", "targetingRadius", "maxHp", "speed"]:
			if not _float(template[field]): return "Invalid enemy numeric type: " + str(type)
	if candidate.enemyDefinitions.size() != candidate.enemies.size(): return "Enemy definition inventory differs"
	for type in candidate.turrets:
		var template: Variant = candidate.turrets[type]
		if not type is String or not template is Dictionary or not template.get("configuration") is Dictionary or not template.configuration.get("statInput") is Dictionary or not template.configuration.statInput.get("definition") is Dictionary: return "Invalid turret template: " + str(type)
	var rules: Dictionary = candidate.randomization
	if not rules.get("laneOffsetAmplitudes") is Dictionary or not rules.get("bossTypes") is Array: return "Invalid randomization rules"
	for type in candidate.enemies:
		if not _float(rules.laneOffsetAmplitudes.get(type)): return "Invalid randomization amplitude"
	for type in rules.bossTypes:
		if not type is String or not candidate.enemies.has(type): return "Invalid randomization boss type"
	for field in ["carrierChance", "oneDiamondChanceGivenCarrier", "twoDiamondChanceGivenCarrier", "threeDiamondChanceGivenCarrier"]:
		if not _float(rules.get(field)): return "Invalid randomization probability"
	var schedule_id := RegEx.create_from_string("^schedule_[0-9a-f]{64}$")
	for id in candidate.spawnSchedules:
		if not id is String or schedule_id.search(id) == null: return "Invalid spawn schedule ID"
		var queue: Variant = candidate.spawnSchedules[id]
		if not queue is Array or queue.is_empty(): return "Invalid spawn schedule rows"
		var previous := -INF
		for row in queue:
			if not row is Array or row.size() != 2 or not row[0] is String or not candidate.enemies.has(row[0]) or not _float(row[1]) or row[1] < 0.0 or (previous != -INF and row[1] - previous < 0.18 - 0.00000001): return "Invalid spawn order/type/reference"
			previous = row[1]
		# Compiler/Python verify the source binary64 digest. Godot's decimal JSON
		# parser may differ by one ULP, so runtime IDs are opaque checked references.
	var used := {}
	var previous_stage := 0
	var seen := {}
	for source in candidate.stages:
		if not source is Dictionary or not _fields(source, STAGE_FIELDS) or not source.id is int or source.id <= previous_stage or seen.has(source.id): return "Missing/duplicate stage ID"
		seen[source.id] = true
		previous_stage = source.id
		if not source.name is String: return "Invalid stage name"
		for field in ["firstClearCorePointReward", "firstClearTurretModuleTicketReward"]:
			if not source[field] is int or source[field] < 0: return "Invalid stage reward"
		if not source.waves is Array or source.waves.is_empty() or not source.map is Dictionary: return "Invalid stage type"
		var map: Dictionary = source.map
		if not map.get("columns") is int or not map.get("rows") is int or map.columns <= 0 or map.rows <= 0 or not map.get("tiles") is Array or map.tiles.size() != map.columns * map.rows or not map.get("path") is Array or map.path.size() < 2: return "Invalid map dimensions/path"
		for tile in map.tiles:
			if not tile in ["blocked", "build", "path", "spawn", "core"]: return "Invalid map tile"
		for point in map.path:
			if not point is Array or point.size() != 2 or not point[0] is int or not point[1] is int or point[0] < 0 or point[1] < 0 or point[0] >= map.columns or point[1] >= map.rows: return "Invalid path tile coordinates"
		var teleport_error := Teleports.validate_map(map)
		if not teleport_error.is_empty(): return teleport_error
		var rounds := {}
		var expected_round := 1
		for wave in source.waves:
			if not wave is Dictionary or not _fields(wave, WAVE_FIELDS) or not wave.get("round") is int or wave.round != expected_round or rounds.has(wave.round): return "Invalid/duplicate wave ID"
			rounds[wave.round] = true
			expected_round += 1
			if not wave.previewText is String or not wave.clearRewardGold is int or wave.clearRewardGold < 0: return "Invalid wave metadata"
			if wave.has("spawnQueue") or not wave.get("spawnSchedule") is String or not candidate.spawnSchedules.has(wave.spawnSchedule): return "Invalid spawn schedule reference"
			used[wave.spawnSchedule] = true
			if not wave.get("groups") is Array or wave.groups.is_empty(): return "Invalid wave groups"
			for group in wave.groups:
				if not group is Dictionary or not group.get("enemyType") is String or not candidate.enemies.has(group.enemyType): return "Invalid wave group reference"
				for field in group:
					if not field in ["enemyType", "count", "interval", "startDelay", "startAfterPrevious", "followDelay"]: return "Invalid wave group fields"
				if not group.get("count") is int or group.count <= 0 or not _float(group.get("interval")) or group.interval <= 0.0 or not _float(group.get("startDelay")) or group.startDelay < 0.0: return "Invalid wave group numeric types"
				if group.has("startAfterPrevious") and not group.startAfterPrevious is bool: return "Invalid wave group relative flag"
				if group.get("startAfterPrevious", false) and (not _float(group.get("followDelay")) or group.followDelay < 0.0): return "Invalid wave group follow delay"
			if not wave.get("enemyDurability") is Dictionary or wave.enemyDurability.size() != candidate.enemies.size(): return "Invalid durability enemy columns"
			for type in candidate.enemies:
				var values: Variant = wave.enemyDurability.get(type)
				if not values is Array or values.size() != 3: return "Invalid durability row: " + str(type)
				for value in values:
					if not _float(value) or value < 0.0: return "Invalid durability numeric type: " + str(type)
	if used.size() != candidate.spawnSchedules.size(): return "Unreferenced spawn schedule"
	return ""

static func _fields(value: Dictionary, fields: Array) -> bool:
	return value.size() == fields.size() and value.has_all(fields)

static func _float(value: Variant) -> bool:
	return value is float and is_finite(value)

static func durability(wave: Dictionary, type: String) -> Dictionary:
	var row: Array = wave.enemyDurability[type]
	return {"maxHp": row[0], "maxShield": row[1], "maxArmor": row[2]}

static func expand_wave(content: Dictionary, wave: Dictionary) -> Dictionary:
	var result := wave.duplicate(true)
	result.erase("spawnSchedule")
	result.spawnQueue = []
	for row in content.spawnSchedules[wave.spawnSchedule]:
		result.spawnQueue.append({"enemyType": row[0], "delay": row[1]})
	result.enemyDurability = {}
	for type in wave.enemyDurability: result.enemyDurability[type] = durability(wave, type)
	return result

static func expand_content(content: Dictionary) -> Dictionary:
	var result := content.duplicate(true)
	result.schemaVersion = 1
	result.erase("runtimeFormat")
	result.erase("spawnSchedules")
	for si in range(content.stages.size()):
		for wi in range(content.stages[si].waves.size()):
			result.stages[si].waves[wi] = expand_wave(content, content.stages[si].waves[wi])
	return result

static func compact_fixture(domain: Dictionary) -> Dictionary:
	# Explicit test/tooling entry point; shipped content must already be schema 2.
	if not TypedJson.is_json_value(domain) or not domain.get("schemaVersion") is int or domain.schemaVersion != 1 or not domain.get("stages") is Array: return {}
	var result := domain.duplicate(true)
	result.schemaVersion = 2
	result.runtimeFormat = {"spawnColumns": SPAWN_COLUMNS.duplicate(), "durabilityColumns": DURABILITY_COLUMNS.duplicate()}
	result.spawnSchedules = {}
	for stage in result.stages:
		if not stage is Dictionary or not stage.get("waves") is Array: return {}
		for wave in stage.waves:
			if not wave is Dictionary or not wave.get("spawnQueue") is Array or not wave.get("enemyDurability") is Dictionary: return {}
			var rows := []
			for entry in wave.spawnQueue:
				if not entry is Dictionary or not _fields(entry, SPAWN_COLUMNS) or not entry.enemyType is String or not _float(entry.delay): return {}
				rows.append([entry.enemyType, entry.delay])
			var id := "schedule_" + schedule_digest(rows)
			result.spawnSchedules[id] = rows
			wave.erase("spawnQueue")
			wave.spawnSchedule = id
			for type in wave.enemyDurability:
				var values: Variant = wave.enemyDurability[type]
				if not values is Dictionary or not _fields(values, DURABILITY_COLUMNS): return {}
				wave.enemyDurability[type] = [values.maxHp, values.maxShield, values.maxArmor]
	return result

static func schedule_digest(rows: Array) -> String:
	# Same binary contract as Python: tag, UTF-8 byte count/name, binary64 delay.
	var payload := "rune-spawn-v1".to_utf8_buffer()
	payload.append(0)
	for row in rows:
		var name: PackedByteArray = str(row[0]).to_utf8_buffer()
		var length := PackedByteArray()
		length.resize(4)
		length.encode_u32(0, name.size())
		payload.append_array(length)
		payload.append_array(name)
		var delay := PackedByteArray()
		delay.resize(8)
		delay.encode_double(0, float(row[1]))
		payload.append_array(delay)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()
