extends RefCounted
## Projects native combat onto the existing save envelope. App-owned progression,
## economy and turret configuration must be supplied by the domain owner.
const Codec = preload("res://app/save_codec.gd")
const DAMAGE_FIELDS = ["directDamageDealt", "splashDamageDealt", "chainDamageDealt", "burnDamageDealt"]

static func map_signature(map: Dictionary, path: Array) -> String:
	var columns := int(map.columns)
	var value := "%dx%d|" % [columns, int(map.rows)]
	for row in range(int(map.rows)):
		for column in range(columns):
			value += str(map.tiles[row * columns + column]) + ","
		value += "/"
	value += "|"
	for point in path:
		# Presentation fixture paths use tile centres; persisted map paths are grid points.
		value += "%d,%d;" % [floori(float(point[0])), floori(float(point[1]))]
	for route in map.get("routes", []):
		value += "|route:" + str(route.id) + ":"
		for point in route.path: value += "%d,%d;" % [int(point[0]),int(point[1])]
		value += JSON.stringify(route.get("teleportPairs", []))
	return value

## Content may later open blocked tiles for building. A saved run stays valid
## when its signature differs only by such openings: same size, path and routes,
## and every other tile unchanged, so each saved placement remains legal.
static func map_signature_accepts(saved: String, map: Dictionary, path: Array) -> bool:
	var current := map_signature(map, path)
	if saved == current: return true
	var before := saved.split("|", true, 2)
	var after := current.split("|", true, 2)
	if before.size() != 3 or after.size() != 3 or before[0] != after[0] or before[2] != after[2]: return false
	var before_rows := before[1].split("/")
	var after_rows := after[1].split("/")
	if before_rows.size() != after_rows.size(): return false
	for row in before_rows.size():
		var before_tiles := before_rows[row].split(",")
		var after_tiles := after_rows[row].split(",")
		if before_tiles.size() != after_tiles.size(): return false
		for column in before_tiles.size():
			if before_tiles[column] != after_tiles[column] and not (before_tiles[column] == "blocked" and after_tiles[column] == "build"): return false
	return true

static func capture(envelope: Dictionary, snapshot: Dictionary, turret_templates: Dictionary, saved_at: int) -> Variant:
	if not snapshot.get("events", []).is_empty(): return null
	return _capture_owned_normalized(Codec.decode(envelope), snapshot, turret_templates, saved_at)

# Internal handoff from ContentRunSave: decode already created this owned tree.
# The public entry point still normalizes arbitrary input without mutating it.
# Projection is normalized again below after replacing combat-owned fields.
static func _capture_owned_normalized(result: Variant, snapshot: Dictionary, turret_templates: Dictionary, saved_at: int) -> Variant:
	# The app must settle and acknowledge events before committing its economy
	# together with this combat checkpoint. Never persist half-applied events.
	if not snapshot.get("events", []).is_empty(): return null
	if result == null or not result.activeRun is Dictionary:
		return null
	var run: Dictionary = result.activeRun
	var phase: String = snapshot.session.get("phase", run.phase)
	if phase == "restored": phase = "preparation" if run.phase == "restored" else run.phase
	if phase == "coreDestruction": phase = "failure"
	run.phase = phase
	run.nexusHp = snapshot.defense.hp
	run.roundNexusHpLost = snapshot.defense.roundHpLost
	run.emergencyChargeUsedThisRound = snapshot.defense.emergencyChargeUsedThisRound
	run.finalDefenseUsedThisRound = snapshot.defense.finalDefenseUsedThisRound
	# Stage-limited passives are checkpoint state, not recreated by a new epoch.
	# Keep v4 payload shape intact for exact legacy receipt/hash recovery.
	if int(run.get("runCorePassiveTreeRevision", result.progression.get("corePassiveTreeRevision", 4))) >= 5:
		run.nexusAdditionalHp = float(snapshot.defense.get("additionalHp", 0.0))
		run.nexusAdditionalHpGranted = bool(snapshot.defense.get("additionalHpGranted", true))
		run.indomitableUsedThisStage = bool(snapshot.defense.get("indomitableUsedThisStage", false))
		run.nexusInvulnerableRemaining = float(snapshot.defense.get("invulnerableRemaining", 0.0))
	# These temporary references are read synchronously by decode below, which
	# creates the owned enemy/status and queue trees returned to the caller.
	run.enemies = snapshot.enemies
	if int(run.get("runCorePassiveTreeRevision", result.progression.get("corePassiveTreeRevision", 4))) < 5:
		run.enemies = []
		for enemy in snapshot.enemies:
			var legacy_enemy: Dictionary = enemy.duplicate()
			for field in ["firstControlApplied", "stunRemaining", "freezeRemaining"]: legacy_enemy.erase(field)
			run.enemies.append(legacy_enemy)
	run.spawnQueue = snapshot.wave.spawnQueue
	run.turrets = []
	for state in snapshot.turrets:
		var key := str(state.id)
		if not turret_templates.has(key): return null
		# Only scalar runtime stats change here; decode owns the nested gem lists.
		var turret: Dictionary = turret_templates[key].duplicate()
		turret.cooldown = state.cooldown
		if int(run.get("runCorePassiveTreeRevision", result.progression.get("corePassiveTreeRevision", 4))) >= 5:
			turret.stockpileCharges = int(state.get("stockpileCharges", 0))
		turret.damageDealt = 0.0
		for field in DAMAGE_FIELDS:
			turret[field] = state[field]
			turret.damageDealt += float(state[field])
		run.turrets.append(turret)
	# Core-cycle clocks/projectiles remain runtime-only, matching the Dart save contract.
	if snapshot.get("core") is Dictionary:
		var core: Dictionary = snapshot.core
		run.runCoreCombatSkillStats = {
			"directDamageDealt": core.get("directDamageDealt", 0.0),
			"bonusDamageDealt": core.get("bonusDamageDealt", 0.0),
			"activationCount": core.get("activationCount", 0),
		}
	result.savedAtMillis = saved_at
	return Codec.decode(result)
