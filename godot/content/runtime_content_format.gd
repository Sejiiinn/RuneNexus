extends RefCounted
## The sole runtime wire boundary. Shared schedules stay compact until requested.
const TypedJson = preload("res://app/save_json.gd")
const Teleports = preload("res://combat/teleport_pairs.gd")
const SPAWN_COLUMNS = ["enemyType", "delay"]
const ROUTE_SPAWN_COLUMNS = ["enemyType", "delay", "routeId"]
const DURABILITY_COLUMNS = ["maxHp", "maxShield", "maxArmor"]
const ROOT_FIELDS = ["schemaVersion", "units", "defaults", "randomization", "defenseConfig", "enemyDefinitions", "enemies", "turrets", "stages", "runtimeFormat", "spawnSchedules"]
const STAGE_FIELDS = ["id", "name", "firstClearCorePointReward", "firstClearTurretModuleTicketReward", "map", "waves"]
const WAVE_FIELDS = ["round", "previewText", "clearRewardGold", "groups", "spawnSchedule", "enemyDurability"]
const SCHEDULING_POLICY = {"version": 1, "scope": "global", "minimumInterval": 0.18, "tieBreak": "source-group-member-order", "dispatchTimeBasis": "spawn-queue-seconds"}
const DISPATCH_FIELDS = ["groupId", "groupIndex", "enemyType", "count", "routeId", "spawnPortalId", "requestedDispatch", "firstDispatch", "lastDispatch", "spawnIndices"]

static func validate(candidate: Variant) -> String:
	if not TypedJson.is_json_value(candidate): return "Invalid content JSON value"
	if not candidate is Dictionary or not candidate.get("schemaVersion") is int or candidate.schemaVersion != 2:
		return "Unsupported content schema"
	# Legacy fixture documents remain readable. New generated catalogs opt into
	# the complete metadata contract through their root schedulingPolicy.
	var annotated: bool = candidate.has("schedulingPolicy")
	if not _fields(candidate, ROOT_FIELDS + (["schedulingPolicy"] if annotated else [])): return "Invalid runtime root fields"
	if annotated:
		var policy: Variant = candidate.schedulingPolicy
		if not policy is Dictionary or not _fields(policy, SCHEDULING_POLICY.keys()) or not policy.version is int or not _float(policy.minimumInterval) or policy != SCHEDULING_POLICY: return "Unsupported scheduling policy"
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
			if not row is Array or row.size() not in [2, 3] or not row[0] is String or not candidate.enemies.has(row[0]) or not _float(row[1]) or row[1] < 0.0 or (previous != -INF and row[1] - previous < 0.18 - 0.00000001): return "Invalid spawn order/type/reference"
			if row.size() == 3 and not _route_id(row[2]): return "Invalid spawn routeId"
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
		var map_error := _validate_map(map)
		if not map_error.is_empty(): return map_error
		var routes := {}
		for route in map.get("routes", []): routes[route.id] = true
		var rounds := {}
		var expected_round := 1
		for wave in source.waves:
			if not wave is Dictionary or not _fields(wave, WAVE_FIELDS + (["groupDispatch"] if annotated else [])) or not wave.get("round") is int or wave.round != expected_round or rounds.has(wave.round): return "Invalid/duplicate wave ID"
			rounds[wave.round] = true
			expected_round += 1
			if not wave.previewText is String or not wave.clearRewardGold is int or wave.clearRewardGold < 0: return "Invalid wave metadata"
			if wave.has("spawnQueue") or not wave.get("spawnSchedule") is String or not candidate.spawnSchedules.has(wave.spawnSchedule): return "Invalid spawn schedule reference"
			used[wave.spawnSchedule] = true
			for row in candidate.spawnSchedules[wave.spawnSchedule]:
				if not routes.is_empty() and (row.size() != 3 or not routes.has(row[2])): return "Missing/unknown spawn routeId"
				if routes.is_empty() and row.size() == 3: return "routeId requires map routes"
			if not wave.get("groups") is Array or wave.groups.is_empty(): return "Invalid wave groups"
			var group_ids := {}
			for group_index in range(wave.groups.size()):
				var group: Variant = wave.groups[group_index]
				if not group is Dictionary or not group.get("enemyType") is String or not candidate.enemies.has(group.enemyType): return "Invalid wave group reference"
				for field in group:
					if not field in ["id", "enemyType", "count", "interval", "startDelay", "startAfterPrevious", "followDelay", "routeId"]: return "Invalid wave group fields"
				var group_id: Variant = group.get("id", "g%02d" % (group_index + 1))
				if not _route_id(group_id) or group_ids.has(group_id): return "Invalid/duplicate wave group id"
				group_ids[group_id] = true
				if group.has("routeId") and (not _route_id(group.routeId) or not routes.has(group.routeId)): return "Invalid wave group routeId"
				if not routes.is_empty() and not group.has("routeId"): return "Missing wave group routeId"
				if not group.get("count") is int or group.count <= 0 or not _float(group.get("interval")) or group.interval <= 0.0 or not _float(group.get("startDelay")) or group.startDelay < 0.0: return "Invalid wave group numeric types"
				if group.has("startAfterPrevious") and not group.startAfterPrevious is bool: return "Invalid wave group relative flag"
				if group.get("startAfterPrevious", false) and (not _float(group.get("followDelay")) or group.followDelay < 0.0): return "Invalid wave group follow delay"
			if annotated:
				var dispatch_error := _validate_group_dispatch(wave, map, candidate.spawnSchedules[wave.spawnSchedule])
				if not dispatch_error.is_empty(): return dispatch_error
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

static func _route_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value == value.strip_edges()

static func _validate_map(map: Dictionary) -> String:
	if not map.get("columns") is int or not map.get("rows") is int or map.columns <= 0 or map.rows <= 0 or not map.get("tiles") is Array or map.tiles.size() != map.columns * map.rows or not map.get("path") is Array or map.path.size() < 2: return "Invalid map dimensions/path"
	for tile in map.tiles:
		if not tile in ["blocked", "build", "path", "spawn", "core"]: return "Invalid map tile"
	for point in map.path:
		if not point is Array or point.size() != 2 or not point[0] is int or not point[1] is int or point[0] < 0 or point[1] < 0 or point[0] >= map.columns or point[1] >= map.rows: return "Invalid path tile coordinates"
	var teleport_error := Teleports.validate_map(map)
	if not teleport_error.is_empty(): return teleport_error
	if not map.has("routes"): return _validate_spawn_portals(map)
	if not map.routes is Array or map.routes.size() < 2: return "routes must contain at least two routes"
	var ids := {}
	for route in map.routes:
		if not route is Dictionary or not route.has_all(["id", "label", "path"]) or not _route_id(route.id) or ids.has(route.id) or not route.label is String or route.label.strip_edges().is_empty(): return "Invalid/duplicate map route"
		for field in route:
			if field not in ["id", "label", "path", "teleportPairs", "spawnPortalId"]: return "Invalid map route fields"
		ids[route.id] = true
		var child := map.duplicate(false)
		child.erase("routes")
		child.erase("spawnPortals")
		child.path = route.path
		child.teleportPairs = route.get("teleportPairs", [])
		var route_error := _validate_map(child)
		if not route_error.is_empty(): return route_error
		var first: Array = route.path[0]
		var last: Array = route.path[-1]
		if map.tiles[first[1] * map.columns + first[0]] != "spawn" or last != map.path[-1] or map.tiles[last[1] * map.columns + last[0]] != "core": return "Route must connect spawn to common core"
		var occupied := {}
		for index in range(route.path.size()):
			var point: Array = route.path[index]
			var tile_index: int = point[1] * map.columns + point[0]
			if occupied.has(tile_index): return "Repeated route path tile"
			occupied[tile_index] = true
			if index > 0 and index < route.path.size() - 1 and map.tiles[tile_index] != "path": return "Route must follow traversable path tiles"
	if map.routes[0].path != map.path: return "Default map path must match first route"
	return _validate_spawn_portals(map)

static func _validate_spawn_portals(map: Dictionary) -> String:
	var routes: Array = map.get("routes", [])
	if not map.has("spawnPortals"):
		for route in routes:
			if route.has("spawnPortalId"): return "Route spawnPortalId requires map spawnPortals"
		return ""
	if not map.spawnPortals is Array or map.spawnPortals.is_empty(): return "Invalid map spawnPortals"
	var portals := {}
	var cells := {}
	for portal in map.spawnPortals:
		if not portal is Dictionary or not _fields(portal, ["id", "label", "cell"]) or not _route_id(portal.id) or portals.has(portal.id) or not portal.label is String or portal.label.strip_edges().is_empty(): return "Invalid/duplicate spawn portal"
		var cell: Variant = portal.cell
		if not cell is Array or cell.size() != 2 or not cell[0] is int or not cell[1] is int or cell[0] < 0 or cell[1] < 0 or cell[0] >= map.columns or cell[1] >= map.rows: return "Invalid spawn portal cell"
		var tile_index: int = cell[1] * map.columns + cell[0]
		if map.tiles[tile_index] != "spawn" or cells.has(tile_index): return "Invalid/duplicate spawn portal cell"
		cells[tile_index] = true
		portals[portal.id] = cell
	var used := {}
	if routes.is_empty():
		if portals.size() != 1 or map.spawnPortals[0].cell != map.path[0]: return "Single-path map requires one matching spawn portal"
		used[map.spawnPortals[0].id] = true
	else:
		for route in routes:
			var portal_id: Variant = route.get("spawnPortalId")
			if not _route_id(portal_id) or not portals.has(portal_id) or portals[portal_id] != route.path[0]: return "Route spawnPortalId must match its starting cell"
			used[portal_id] = true
	if used.size() != portals.size(): return "Unreferenced spawn portal"
	for index in range(map.tiles.size()):
		if map.tiles[index] == "spawn" and not cells.has(index): return "Spawn portal registry must cover every spawn tile"
	return ""

static func _spawn_portal_id(map: Dictionary, route_id: String) -> String:
	if not map.has("spawnPortals"): return "default"
	if route_id.is_empty(): return map.spawnPortals[0].id
	for route in map.routes:
		if route.id == route_id: return route.spawnPortalId
	return ""

static func _validate_group_dispatch(wave: Dictionary, map: Dictionary, queue: Array) -> String:
	# Validate ownership against the one compiled queue. Never re-expand groups,
	# replay scheduling, or sort the supplied dispatch rows at the consumer boundary.
	var dispatch: Variant = wave.get("groupDispatch")
	if not dispatch is Array or dispatch.size() != wave.groups.size(): return "Invalid groupDispatch coverage"
	var used := {}
	var seen := {}
	var ids := {}
	var previous_time := -INF
	var previous_group := -1
	var requested_starts := []
	var previous_end := 0.0
	for group in wave.groups:
		var start: float = previous_end + group.followDelay if group.get("startAfterPrevious", false) else group.startDelay
		requested_starts.append(start)
		previous_end = start + (group.count - 1) * group.interval
	var requested_order := []
	requested_order.resize(queue.size())
	for row in dispatch:
		if not row is Dictionary or not _fields(row, DISPATCH_FIELDS): return "Invalid groupDispatch fields"
		var index: Variant = row.groupIndex
		if not index is int or index < 0 or index >= wave.groups.size() or seen.has(index): return "Invalid/duplicate groupDispatch groupIndex"
		seen[index] = true
		var group: Dictionary = wave.groups[index]
		if not _route_id(row.groupId) or row.groupId != group.get("id", "g%02d" % (index + 1)) or ids.has(row.groupId) or not row.enemyType is String or row.enemyType != group.enemyType or not row.count is int or row.count != group.count or not row.routeId is String or row.routeId != group.get("routeId", "") or not row.spawnPortalId is String or row.spawnPortalId != _spawn_portal_id(map, row.routeId): return "groupDispatch identity differs from group/route/portal"
		ids[row.groupId] = true
		var indices: Variant = row.spawnIndices
		if not indices is Array or indices.size() != group.count: return "Invalid groupDispatch spawn ownership"
		var previous_index := -1
		for member in range(indices.size()):
			var spawn_index: Variant = indices[member]
			if not spawn_index is int or spawn_index < 0 or spawn_index >= queue.size() or spawn_index <= previous_index or used.has(spawn_index): return "Invalid groupDispatch spawn ownership"
			previous_index = spawn_index
			used[spawn_index] = true
			requested_order[spawn_index] = [requested_starts[index] + member * group.interval, index, member]
			var spawn: Array = queue[spawn_index]
			if spawn[0] != row.enemyType or (spawn[2] if spawn.size() == 3 else "") != row.routeId: return "groupDispatch spawn identity differs"
		for key in ["requestedDispatch", "firstDispatch", "lastDispatch"]:
			if not _float(row[key]) or row[key] < 0.0: return "Invalid groupDispatch dispatch time"
		# Source arithmetic can differ by a few ULPs from Python's decimal parser;
		# actual queue endpoint values below must still match the stored rows exactly.
		if abs(row.requestedDispatch - requested_starts[index]) > max(0.000000000001, abs(requested_starts[index]) * 0.00000000000001): return "groupDispatch requested time differs from source group"
		if row.firstDispatch != queue[indices[0]][1] or row.lastDispatch != queue[indices[-1]][1] or row.firstDispatch + 0.00000001 < row.requestedDispatch: return "groupDispatch time differs from actual queue"
		if row.firstDispatch < previous_time or (row.firstDispatch == previous_time and index <= previous_group): return "groupDispatch must be in chronological order"
		previous_time = row.firstDispatch
		previous_group = index
	if used.size() != queue.size(): return "groupDispatch must cover the complete queue"
	for index in range(queue.size()):
		var requested: Array = requested_order[index]
		if queue[index][1] + 0.00000001 < requested[0]: return "groupDispatch precedes its requested time"
		if index == 0: continue
		var before: Array = requested_order[index - 1]
		# Python verifies exact source/group/member tie order. Decimal parsing can
		# collapse/reorder neighboring source ULPs here, so only reject requests
		# separated beyond that numeric uncertainty rather than reschedule ties.
		var uncertainty: float = max(0.000000000001, max(abs(before[0]), abs(requested[0])) * 0.00000000000001)
		if before[0] > requested[0] + uncertainty: return "groupDispatch ownership violates source request order"
	return ""

static func durability(wave: Dictionary, type: String) -> Dictionary:
	var row: Array = wave.enemyDurability[type]
	return {"maxHp": row[0], "maxShield": row[1], "maxArmor": row[2]}

static func expand_wave(content: Dictionary, wave: Dictionary) -> Dictionary:
	var result := wave.duplicate(true)
	result.erase("spawnSchedule")
	result.spawnQueue = []
	for row in content.spawnSchedules[wave.spawnSchedule]:
		var entry := {"enemyType": row[0], "delay": row[1]}
		if row.size() == 3: entry.routeId = row[2]
		result.spawnQueue.append(entry)
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
				if not entry is Dictionary or not _fields(entry, ROUTE_SPAWN_COLUMNS if entry.has("routeId") else SPAWN_COLUMNS) or not entry.enemyType is String or not _float(entry.delay): return {}
				var row := [entry.enemyType, entry.delay]
				if entry.has("routeId"):
					if not _route_id(entry.routeId): return {}
					row.append(entry.routeId)
				rows.append(row)
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
	# Legacy bytes are unchanged; routed queues append each route's UTF-8 bytes.
	var routed := false
	for row in rows:
		if row.size() == 3: routed = true
	var payload := ("rune-spawn-routes-v1" if routed else "rune-spawn-v1").to_utf8_buffer()
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
		if routed:
			var route: PackedByteArray = (str(row[2]) if row.size() == 3 else "").to_utf8_buffer()
			length.encode_u32(0, route.size())
			payload.append_array(length)
			payload.append_array(route)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish().hex_encode()
