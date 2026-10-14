extends RefCounted
## Named rows of the battlefield presentation frame.
## Stored fixtures and older producers serialize rows as positional arrays; this
## file is the only place that knows those positions. Coordinates stay 64-bit
## floats (not Vector2) so derived transforms are bit-identical to the arrays.

class Enemy extends RefCounted:
	var id := 0
	var x := 0.0
	var y := 0.0
	var facing := 0.0
	var phase := 0.0
	var scale := 1.0
	var has_scale := false
	var hit_flash := 0.0
	var type := "tank"
	var burning := false
	var slowed := false
	var poisoned := false
	var diamond := false
	## Path position without the visual lane offset; absent in old fixtures.
	var has_logical := false
	var logical_x := 0.0
	var logical_y := 0.0
	## Increments on every teleport jump; -1 when the map has no teleports.
	var teleport_serial := -1
	## Optional visual shield state; older fixtures omit it and remain unshielded.
	var has_shield := false
	var shield := 0.0
	var max_shield := 0.0

	static func from_array(d: Array) -> Enemy:
		var row := Enemy.new()
		row.id = int(d[0]); row.x = float(d[1]); row.y = float(d[2])
		if d.size() > 3: row.facing = float(d[3])
		if d.size() > 4: row.phase = float(d[4])
		if d.size() > 5:
			row.scale = float(d[5]); row.has_scale = true
		if d.size() > 6: row.hit_flash = float(d[6])
		if d.size() > 7: row.type = str(d[7])
		row.burning = d.size() > 8 and bool(d[8])
		row.slowed = d.size() > 9 and bool(d[9])
		row.poisoned = d.size() > 10 and bool(d[10])
		row.diamond = d.size() > 11 and bool(d[11])
		if d.size() > 13 and d[12] != null and d[13] != null:
			row.has_logical = true
			row.logical_x = float(d[12]); row.logical_y = float(d[13])
		if d.size() > 14 and d[14] is Dictionary:
			if d[14].has("teleportSerial"): row.teleport_serial = int(d[14]["teleportSerial"])
			if d[14].has("shield"):
				row.has_shield = true
				row.shield = float(d[14].shield)
				row.max_shield = float(d[14].get("maxShield", 0.0))
		return row

	func to_array() -> Array:
		var d := [id, x, y, facing, phase, scale, hit_flash, type, burning, slowed, poisoned, diamond]
		if has_logical or teleport_serial >= 0 or has_shield: d.append_array([logical_x, logical_y] if has_logical else [null, null])
		var extra := {}
		if teleport_serial >= 0: extra.teleportSerial = teleport_serial
		if has_shield:
			extra.shield = shield
			extra.maxShield = max_shield
		if not extra.is_empty(): d.append(extra)
		return d

class Turret extends RefCounted:
	var id := 0
	var x := 0.0
	var y := 0.0
	var aim_angle := 0.0
	var shot_sequence := 0
	var fire_feedback := 0.0
	var type := "cannon"
	var level := 1
	## Presentation projection of turret state (sniper aim, frost, stockpile).
	## The authoritative saved state lives in combat checkpoints.
	var extension: Dictionary = {}

	static func from_array(d: Array) -> Turret:
		var row := Turret.new()
		row.id = int(d[0]); row.x = float(d[1]); row.y = float(d[2])
		row.aim_angle = float(d[3])
		if d.size() > 4: row.shot_sequence = int(d[4])
		if d.size() > 5: row.fire_feedback = float(d[5])
		if d.size() > 6: row.type = str(d[6])
		if d.size() > 7: row.level = int(d[7])
		if d.size() > 8 and d[8] is Dictionary: row.extension = d[8]
		return row

	func stockpile_enabled() -> bool: return bool(extension.get("stockpileEnabled",false))
	func stockpile_charges() -> int: return clampi(int(extension.get("stockpileCharges",0)),0,2)

	func to_array() -> Array:
		var d := [id, x, y, aim_angle, shot_sequence, fire_feedback, type, level]
		if not extension.is_empty(): d.append(extension)
		return d

class Projectile extends RefCounted:
	var id := 0
	var x := 0.0
	var y := 0.0
	var direction_x := 0.0
	var direction_y := 0.0
	var type := "cannon"
	## Launch data; absent in old fixtures.
	var has_launch := false
	var start_x := 0.0
	var start_y := 0.0
	var has_owner := false
	var owner_id := -1
	var shot := 0
	var chained := false
	## Combat time the flight ended, or -1 while it is in flight.
	var finished_at := -1.0
	var has_end := false
	var end_x := 0.0
	var end_y := 0.0

	static func from_array(d: Array) -> Projectile:
		var row := Projectile.new()
		row.id = int(d[0]); row.x = float(d[1]); row.y = float(d[2])
		row.direction_x = float(d[3]); row.direction_y = float(d[4])
		if d.size() > 5: row.type = str(d[5])
		if d.size() >= 12:
			row.has_launch = true
			row.start_x = float(d[6]); row.start_y = float(d[7])
			row.has_owner = d[8] != null
			row.owner_id = int(d[8]) if d[8] != null else -1
			row.shot = int(d[9]); row.chained = bool(d[10]); row.finished_at = float(d[11])
		if d.size() >= 14 and d[12] != null and d[13] != null:
			row.has_end = true
			row.end_x = float(d[12]); row.end_y = float(d[13])
		return row

	func to_array() -> Array:
		var d := [id, x, y, direction_x, direction_y, type]
		# In-flight rows serialize the integer sentinel -1, as the runtime always has.
		if has_launch: d.append_array([start_x, start_y, owner_id if has_owner else null, shot, chained, finished_at if finished_at >= 0.0 else -1])
		if has_launch: d.append_array([end_x, end_y] if has_end else [null, null])
		return d

class Impact extends RefCounted:
	var id := 0
	var x := 0.0
	var y := 0.0
	## Blast radius in tiles.
	var radius := 0.0
	## Normalized lifetime 0..1.
	var progress := 0.0

	static func from_array(d: Array) -> Impact:
		var row := Impact.new()
		row.id = int(d[0]); row.x = float(d[1]); row.y = float(d[2])
		row.radius = float(d[3]); row.progress = float(d[4])
		return row

	func to_array() -> Array:
		return [id, x, y, radius, progress]

class BuildPreview extends RefCounted:
	var x := 0.0
	var y := 0.0
	var aim_angle := 0.0
	var type := "cannon"

	static func from_array(d: Array) -> BuildPreview:
		var row := BuildPreview.new()
		row.x = float(d[1]); row.y = float(d[2]); row.aim_angle = float(d[3])
		if d.size() > 6: row.type = str(d[6])
		return row

## Shared read-only value for turrets without type-specific state.
const NO_EXTENSION := {}
const ROW_TYPES := {"enemies": Enemy, "turrets": Turret, "projectiles": Projectile, "impacts": Impact}

## Rows of one kind as named objects; already-named rows pass through.
static func rows(kind: String, list: Array) -> Array:
	if list.is_empty() or not list[0] is Array: return list
	var decoder = ROW_TYPES[kind]
	var result := []
	result.resize(list.size())
	for index in list.size(): result[index] = decoder.from_array(list[index])
	return result

## Build preview as a named object, or null when absent/incomplete.
static func build_preview(data) -> BuildPreview:
	if data is BuildPreview: return data
	if not data is Array or data.size() < 6: return null
	return BuildPreview.from_array(data)

## Shallow copy of a frame whose rows are named objects. The caller's frame and
## arrays are not modified.
static func decoded(frame: Dictionary) -> Dictionary:
	var result := frame
	for kind in ROW_TYPES:
		var list: Variant = frame.get(kind)
		if list is Array and not list.is_empty() and list[0] is Array:
			if result == frame: result = frame.duplicate()
			result[kind] = rows(kind, list)
	return result

## Shallow copy of a frame with rows in the positional serialized form, for
## digests, fixtures and comparisons.
static func serialized(frame: Dictionary) -> Dictionary:
	var result := frame.duplicate()
	for kind in ROW_TYPES:
		if frame.get(kind) is Array:
			result[kind] = frame[kind].map(func(row): return row if row is Array else row.to_array())
	return result
