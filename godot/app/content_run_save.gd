extends RefCounted
## Pure actual-content v2 checkpoint preparation. Never mutates a live session.
const Codec = preload("res://app/save_codec.gd")
const CombatProjection = preload("res://app/run_save_adapter.gd")
const Commands = preload("res://app/run_commands.gd")
const GemSlots = preload("res://app/gem_slot_rules.gd")
var catalog
var growth
var error := ""

func _init(content = null, growth_rules = null) -> void:
	catalog = content
	growth = growth_rules

func _reject(reason: String) -> Dictionary:
	error = reason
	return {}

func capture(state: Dictionary, snapshot: Dictionary, saved_at: int, preferences: Dictionary = {}) -> Dictionary:
	error = ""
	var stage := int(state.get("stage", -1))
	if stage < 0 or stage >= catalog.stage_count(): return _reject("Unknown stage")
	if not snapshot.get("events", []).is_empty(): return _reject("Unsettled combat events")
	var map: Dictionary = catalog.stage_map(stage)
	# Only these top-level fields change before decode creates the owned save tree.
	var run := state.duplicate()
	run.stageNumber = catalog.stage_id(stage)
	run.mapSignature = CombatProjection.map_signature(map, map.path)
	var progression: Dictionary = state.get("progression", {}).duplicate()
	var inventory: Dictionary = progression.get("turretModules", {})
	progression.erase("turretModules")
	# run still contains the entire source progression, including module inventory.
	if not _finite_tree(run): return _reject("Non-finite domain value")
	var envelope: Dictionary = Codec.decode({"version":2,"savedAtMillis":saved_at,"preferences":preferences,"progression":progression,"turretModules":inventory,"activeRun":run})
	if not _compatible(run, envelope.activeRun) or not _compatible(progression,envelope.progression) or not _compatible(inventory,envelope.turretModules): return _reject("Domain state cannot roundtrip v2")
	if not snapshot.has_all(["session","defense","wave","enemies","turrets"]) or not _finite_tree(snapshot): return _reject("Invalid combat snapshot")
	if snapshot.turrets.size() != state.get("turrets",[]).size(): return _reject("Turret checkpoint mismatch")
	var templates := {}
	for t in state.get("turrets", []): templates[str(t.id)] = t
	var projected: Variant = CombatProjection._capture_owned_normalized(envelope, snapshot, templates, saved_at)
	if projected == null: return _reject("Incomplete combat checkpoint")
	# v2 distance is in Dart logical pixels; native content boards use tile units.
	var scale: float = float(state.get("tileSize", 1.0)) / catalog.tile_size()
	if not is_finite(scale) or scale <= 0: return _reject("Invalid tile size")
	for enemy in projected.activeRun.enemies: enemy.distanceTravelled /= scale
	# The application owns reward/return phases; native combat may still be paused.
	projected.activeRun.phase = "failure" if state.phase == "coreDestruction" else state.phase
	if not run.has("runCoreCombatSkill"):
		projected.activeRun.runCoreCombatSkill = snapshot.get("core", {}).get("skill", progression.get("coreCombatSkill", "guardianBeam"))
	# Projection's decode already owns and normalizes every field. Only distance,
	# domain phase and the absent frozen skill can change after that handoff.
	# Phase also controls the codec's legacy purchased-reward return fallback.
	if not _finite_tree(projected) or not _projection_overrides_compatible(projected): return _reject("Unsupported save values")
	if _validate_normalized_checkpoint(projected, {"tileSize":float(state.get("tileSize",1.0))}, false).is_empty(): return {}
	return projected

func _projection_overrides_compatible(envelope: Dictionary) -> bool:
	var run: Dictionary = envelope.activeRun
	if not _compatible(run.phase, Codec._enum("GamePhase", run.phase, "preparation")): return false
	var return_fallback: Variant = "wave" if run.phase == "reward" and run.isPurchasedGemReward and (not run.enemies.is_empty() or not run.spawnQueue.is_empty()) else null
	if not _compatible(run.rewardReturnPhase, Codec._enum("GamePhase", run.rewardReturnPhase, return_fallback)): return false
	return _compatible(run.runCoreCombatSkill, Codec._skill(run, "runCoreCombatSkill", envelope.progression.coreCombatSkill))

func prepare(envelope: Dictionary, battle_inputs: Dictionary = {}, spawn_rng: RandomNumberGenerator = null) -> Dictionary:
	var validated := _validate_checkpoint(envelope,battle_inputs)
	if validated.is_empty(): return {}
	return _materialize_checkpoint(validated,spawn_rng)

func _validate_checkpoint(envelope: Dictionary, battle_inputs: Dictionary = {}, for_restore: bool = true) -> Dictionary:
	error = ""
	var decoded: Variant = Codec.decode(envelope)
	if decoded == null or not decoded.activeRun is Dictionary: return _reject("No active run")
	if not _finite_tree(envelope) or not _compatible(envelope,decoded): return _reject("Unsupported save values")
	return _validate_normalized_checkpoint(decoded,battle_inputs,for_restore)

# Private handoff accepts only the owned codec result (with checked projection
# overrides for capture). Public preparation retains its full input validation.
func _validate_normalized_checkpoint(decoded: Dictionary, battle_inputs: Dictionary, for_restore: bool) -> Dictionary:
	var run: Dictionary = decoded.activeRun
	var stage: int = catalog.stage_index(int(run.stageNumber))
	if stage < 0: return _reject("Unknown stage")
	var map: Dictionary = catalog.stage_map(stage)
	var count: int = catalog.wave_count(stage)
	if run.mapSignature != CombatProjection.map_signature(map, map.path): return _reject("Map signature mismatch")
	var phase: String = run.phase
	if phase == "restored": phase = "preparation"
	if phase == "coreDestruction": phase = "failure"
	if phase not in ["preparation","wave","reward","success","failure"]: return _reject("Unsupported run phase")
	var round_index := int(run.roundIndex)
	if round_index < 0 or round_index > count or int(run.completedRounds) < 0 or int(run.completedRounds) > count: return _reject("Invalid round")
	var live: bool = phase == "wave" or (phase == "reward" and run.isPurchasedGemReward and run.rewardReturnPhase == "wave")
	if (live or not run.enemies.is_empty() or not run.spawnQueue.is_empty()) and round_index >= count: return _reject("No active wave")
	if not live and phase != "failure" and (not run.enemies.is_empty() or not run.spawnQueue.is_empty()): return _reject("Combat outside active wave")
	if phase == "failure" and not run.spawnQueue.is_empty(): return _reject("Failed run cannot retain a spawn queue")
	if phase == "reward" and (run.rewardOptions.is_empty() or (run.isPurchasedGemReward and run.rewardReturnPhase not in ["preparation","wave"])): return _reject("Invalid reward phase")
	# Save-only validation shares read-only fields, but separates every branch
	# mutated by ID assignment and legacy gem migration from the returned save.
	# Restoration retains a full separate state for subsequent runtime commands.
	var state: Dictionary = run.duplicate(true) if for_restore else run.duplicate()
	if not for_restore:
		state.turrets = run.turrets.duplicate(true)
		state.gemInventory = run.gemInventory.duplicate()
	state.phase = phase
	state.stage = stage
	state.tileSize = float(battle_inputs.get("tileSize",1.0))
	if not is_finite(state.tileSize) or state.tileSize <= 0: return _reject("Invalid tile size")
	# Commands currently place towers at tile centres with zero board origin.
	if battle_inputs.get("origin",[0.0,0.0]) != [0.0,0.0]: return _reject("Unsupported board origin")
	state.progression = decoded.progression.duplicate(true) if for_restore else decoded.progression.duplicate()
	state.progression.turretModules = decoded.turretModules.duplicate(true) if for_restore else decoded.turretModules
	state.nextTurretId = 1000
	var occupied := {}
	for t in state.turrets:
		var rule: Dictionary = growth.data.turretRules.get(t.type,{})
		if rule.is_empty() or t.x < 0 or t.y < 0 or t.x >= map.columns or t.y >= map.rows: return _reject("Invalid turret tile/type")
		var cell := int(t.y) * int(map.columns) + int(t.x)
		if occupied.has(cell) or map.tiles[cell] != "build": return _reject("Occupied or unbuildable turret tile")
		occupied[cell] = true
		if t.level < 1 or t.level > int(rule.maxLevel) or t.slotLimit < 1 or t.slotLimit > 4 or t.equippedGemSlots.size() > t.slotLimit: return _reject("Invalid turret level/slots")
		for key in ["primaryTrait","secondaryTrait"]:
			if t[key] != null and t[key] not in rule.get(key+"s",[]): return _reject("Invalid turret trait")
		if GemSlots.has_duplicates(t.equippedGemSlots): return _reject("Invalid turret gems")
		for slot in range(t.equippedGemSlots.size()):
			var gem = t.equippedGemSlots[slot]
			if gem == null: continue
			if not GemSlots.is_compatible(gem, rule.compatibleGems):
				# Older content allowed lightWeapon on every turret. Return that
				# obsolete equipment once, using slots as the inventory authority.
				# Only the copied runtime state changes; the source save stays intact.
				if gem != "lightWeapon": return _reject("Invalid turret gems")
				GemSlots.replace_owned(t, slot, null, state.gemInventory)
		while t.equippedGemSlots.size() < t.slotLimit: t.equippedGemSlots.append(null)
		GemSlots.sync_equipped(t)
		t.id = state.nextTurretId
		state.nextTurretId += 1
	for type in state.runUpgradeLevels:
		var rule: Dictionary = growth.data.runUpgrades.get(type,{})
		if rule.is_empty() or int(state.runUpgradeLevels[type]) < 0: return _reject("Invalid run upgrade")
	var service = Commands.new(catalog,growth)
	var derived: Dictionary = service.derived(state)
	for type in state.runUpgradeLevels:
		if int(state.runUpgradeLevels[type]) > int(growth.data.runUpgrades[type].maxLevel) + int(derived.runUpgradeMaxLevelBonuses.get(type,0)): return _reject("Invalid run upgrade level")
	if run.nexusHp < 0 or run.nexusHp > derived.maxNexusHp: return _reject("Invalid nexus HP")
	var inputs := battle_inputs.duplicate(true)
	inputs.defenseConfig = derived.defenseConfig
	# Only the frozen skill changes; growth reads the other nested fields.
	var core_state := state.duplicate()
	core_state.progression = state.progression.duplicate()
	core_state.progression.coreCombatSkill = run.runCoreCombatSkill
	inputs.coreConfig = growth.core_config(core_state,stage,mini(round_index,count-1),catalog)
	# A saved run skill is frozen independently of the current account selection.
	inputs.coreConfig.runSkill = run.runCoreCombatSkill
	if not catalog.validate_bootstrap(stage,inputs): return _reject(catalog.error)
	# Same stage/round/inputs for every live enemy. Cache success only within this
	# invocation, independently of pending enemies whose enemyValues are replaced.
	var live_types := {}
	for saved in run.enemies:
		if not map.get("routes", []).is_empty() and str(saved.get("routeId", "")).is_empty(): return _reject("Missing saved route")
		if catalog.route_map(stage,str(saved.get("routeId", ""))).is_empty(): return _reject("Unknown saved route")
		if live_types.has(saved.type): continue
		if not catalog.validate_enemy(stage,round_index,saved.type,inputs): return _reject(catalog.error)
		live_types[saved.type] = true
	var definition: Dictionary = catalog.wave_definition(stage,round_index) if live or not run.spawnQueue.is_empty() else {}
	if live or not run.spawnQueue.is_empty():
		var schedule: Array = definition.spawnQueue
		var offset: int = schedule.size() - run.spawnQueue.size()
		if offset < 0: return _reject("Spawn queue exceeds wave schedule")
		for index in range(run.spawnQueue.size()):
			if run.spawnQueue[index].enemyType != schedule[offset+index].enemyType or run.spawnQueue[index].get("routeId", "") != schedule[offset+index].get("routeId", ""): return _reject("Spawn queue does not match remaining wave schedule")
		var pending_types := {}
		for saved in run.spawnQueue:
			if saved.delay < 0 or not is_finite(saved.delay): return _reject("Invalid spawn delay")
			if pending_types.has(saved.enemyType): continue
			if not catalog.validate_randomized_enemy(stage,round_index,saved.enemyType,inputs): return _reject(catalog.error)
			pending_types[saved.enemyType] = true
	return {"decoded":decoded,"run":run,"state":state,"wave":definition,"stage":stage,"roundIndex":round_index,"phase":phase,"live":live,"inputs":inputs,"service":service}

func _materialize_checkpoint(validated: Dictionary, spawn_rng: RandomNumberGenerator) -> Dictionary:
	var decoded: Dictionary = validated.decoded
	var run: Dictionary = validated.run
	var state: Dictionary = validated.state
	var definition: Dictionary = validated.wave
	var stage: int = validated.stage
	var round_index: int = validated.roundIndex
	var phase: String = validated.phase
	var live: bool = validated.live
	var inputs: Dictionary = validated.inputs
	var service = validated.service
	var bootstrap: Dictionary = catalog.bootstrap(stage,inputs)
	if bootstrap.is_empty(): return _reject(catalog.error)
	bootstrap.defense.state = {"hp":run.nexusHp,"roundHpLost":run.roundNexusHpLost,"emergencyChargeUsedThisRound":run.emergencyChargeUsedThisRound,"finalDefenseUsedThisRound":run.finalDefenseUsedThisRound}
	bootstrap.core = run.runCoreCombatSkillStats.duplicate(true)
	bootstrap.turrets = []
	for command in service.runtime_commands(state): bootstrap.turrets.append(command.turret)
	bootstrap.enemies = []
	var next_enemy_id := 100000
	for saved in run.enemies:
		var enemy_inputs := inputs.duplicate()
		enemy_inputs.routeId = saved.get("routeId", "")
		var enemy: Dictionary = catalog.enemy(stage,round_index,saved.type,next_enemy_id,enemy_inputs)
		if enemy.is_empty(): return _reject(catalog.error)
		enemy.merge(saved,true)
		enemy.distanceTravelled *= bootstrap.boardDistanceScale
		# Let NativeEnemyState reconstruct position/heading from saved distance.
		for key in ["x","y","position","targetIndex","facingAngle"]: enemy.erase(key)
		bootstrap.enemies.append(enemy)
		next_enemy_id += 1
	if live or not run.spawnQueue.is_empty():
		var queue := []
		var schedule: Array = definition.spawnQueue
		var offset: int = schedule.size() - run.spawnQueue.size()
		# v2 stores only pending types/delays. Re-roll their spawn randomness using
		# the same real-content rules; existing live enemies keep saved values.
		var rng := spawn_rng if spawn_rng != null else RandomNumberGenerator.new()
		var spawn_values: Array = catalog.random_spawn_values(stage,round_index,rng)
		var pending_index := 0
		for saved in run.spawnQueue:
			var spawn_inputs := inputs.duplicate(true)
			spawn_inputs.enemyValues = spawn_values[offset+pending_index]
			spawn_inputs.routeId = saved.get("routeId", "")
			var enemy: Dictionary = catalog.enemy(stage,round_index,saved.enemyType,next_enemy_id,spawn_inputs)
			pending_index += 1
			if enemy.is_empty(): return _reject(catalog.error)
			queue.append({"enemyType":saved.enemyType,"delay":saved.delay,"enemy":enemy})
			if saved.has("routeId"): queue[-1].routeId = saved.routeId
			next_enemy_id += 1
		bootstrap.wave = {"id":definition.round,"active":live,"spawnQueue":queue}
	return {"state":state,"bootstrap":bootstrap,"session":{"clock":"godot","phase":phase,"paused":true,"speed":1.0},"stage":stage,"nextRound":round_index + (1 if live else 0),"nextEnemyId":next_enemy_id,"envelope":decoded}

# Unknown runtime-only keys may be dropped; known v2 values must not normalize
# silently (invalid enums, discarded objects, capped currency or non-finite data).
func _compatible(raw: Variant, normalized: Variant) -> bool:
	if raw is Dictionary and normalized is Dictionary:
		for key in raw:
			if normalized.has(key) and not _compatible(raw[key],normalized[key]): return false
		return true
	if raw is Array and normalized is Array:
		if raw.size() != normalized.size(): return false
		for index in range(raw.size()):
			if not _compatible(raw[index],normalized[index]): return false
		return true
	if normalized is int and not raw is int: return false
	return raw == normalized

func _finite_tree(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Dictionary:
		for child in value.values():
			if not _finite_tree(child): return false
	elif value is Array:
		for child in value:
			if not _finite_tree(child): return false
	return true
