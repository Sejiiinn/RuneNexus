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
	return value

static func capture(envelope: Dictionary, snapshot: Dictionary, turret_templates: Dictionary, saved_at: int) -> Variant:
	# The app must settle and acknowledge events before committing its economy
	# together with this combat checkpoint. Never persist half-applied events.
	if not snapshot.get("events", []).is_empty(): return null
	var result = Codec.decode(envelope)
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
	run.enemies = snapshot.enemies.duplicate(true)
	run.spawnQueue = snapshot.wave.spawnQueue.duplicate(true)
	run.turrets = []
	for state in snapshot.turrets:
		var key := str(state.id)
		if not turret_templates.has(key): return null
		var turret: Dictionary = turret_templates[key].duplicate(true)
		turret.cooldown = state.cooldown
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
