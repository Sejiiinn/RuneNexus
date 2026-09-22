extends RefCounted
## Pure actual-content v2 checkpoint preparation. Never mutates a live session.
const Codec = preload("res://app/save_codec.gd")
const CombatProjection = preload("res://app/run_save_adapter.gd")
const Commands = preload("res://app/run_commands.gd")
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
	var source: Dictionary = catalog.stage(stage)
	var run := state.duplicate(true)
	run.stageNumber = source.id
	run.mapSignature = CombatProjection.map_signature(source.map, source.map.path)
	var progression: Dictionary = state.get("progression", {}).duplicate(true)
	var inventory: Dictionary = progression.get("turretModules", {}).duplicate(true)
	progression.erase("turretModules")
	if not _finite_tree(run) or not _finite_tree(progression): return _reject("Non-finite domain value")
	var envelope: Dictionary = Codec.decode({"version":2,"savedAtMillis":saved_at,"preferences":preferences,"progression":progression,"turretModules":inventory,"activeRun":run})
	if not _compatible(run, envelope.activeRun) or not _compatible(progression,envelope.progression) or not _compatible(inventory,envelope.turretModules): return _reject("Domain state cannot roundtrip v2")
	if not snapshot.has_all(["session","defense","wave","enemies","turrets"]) or not _finite_tree(snapshot): return _reject("Invalid combat snapshot")
	if snapshot.turrets.size() != state.get("turrets",[]).size(): return _reject("Turret checkpoint mismatch")
	var templates := {}
	for t in state.get("turrets", []): templates[str(t.id)] = t
	var projected: Variant = CombatProjection.capture(envelope, snapshot, templates, saved_at)
	if projected == null: return _reject("Incomplete combat checkpoint")
	# v2 distance is in Dart logical pixels; native content boards use tile units.
	var scale := float(state.get("tileSize", 1.0)) / float(catalog.data.units.tileSize)
	if not is_finite(scale) or scale <= 0: return _reject("Invalid tile size")
	for enemy in projected.activeRun.enemies: enemy.distanceTravelled /= scale
	# The application owns reward/return phases; native combat may still be paused.
	projected.activeRun.phase = "failure" if state.phase == "coreDestruction" else state.phase
	if not run.has("runCoreCombatSkill"):
		projected.activeRun.runCoreCombatSkill = snapshot.get("core", {}).get("skill", progression.get("coreCombatSkill", "guardianBeam"))
	if prepare(projected, {"tileSize":float(state.get("tileSize",1.0))}).is_empty(): return {}
	return projected

func prepare(envelope: Dictionary, battle_inputs: Dictionary = {}, spawn_rng: RandomNumberGenerator = null) -> Dictionary:
	error = ""
	var decoded: Variant = Codec.decode(envelope)
	if decoded == null or not decoded.activeRun is Dictionary: return _reject("No active run")
	if not _finite_tree(envelope) or not _compatible(envelope,decoded): return _reject("Unsupported save values")
	var run: Dictionary = decoded.activeRun
	var stage := -1
	for index in range(catalog.stage_count()):
		if int(catalog.data.stages[index].id) == int(run.stageNumber): stage = index
	if stage < 0: return _reject("Unknown stage")
	var source: Dictionary = catalog.stage(stage)
	if run.mapSignature != CombatProjection.map_signature(source.map, source.map.path): return _reject("Map signature mismatch")
	var phase: String = run.phase
	if phase == "restored": phase = "preparation"
	if phase == "coreDestruction": phase = "failure"
	if phase not in ["preparation","wave","reward","success","failure"]: return _reject("Unsupported run phase")
	var round_index := int(run.roundIndex)
	if round_index < 0 or round_index > source.waves.size() or int(run.completedRounds) < 0 or int(run.completedRounds) > source.waves.size(): return _reject("Invalid round")
	var live: bool = phase == "wave" or (phase == "reward" and run.isPurchasedGemReward and run.rewardReturnPhase == "wave")
	if (live or not run.enemies.is_empty() or not run.spawnQueue.is_empty()) and round_index >= source.waves.size(): return _reject("No active wave")
	if not live and phase != "failure" and (not run.enemies.is_empty() or not run.spawnQueue.is_empty()): return _reject("Combat outside active wave")
	if phase == "failure" and not run.spawnQueue.is_empty(): return _reject("Failed run cannot retain a spawn queue")
	if phase == "reward" and (run.rewardOptions.is_empty() or (run.isPurchasedGemReward and run.rewardReturnPhase not in ["preparation","wave"])): return _reject("Invalid reward phase")
	var state := run.duplicate(true)
	state.phase = phase
	state.stage = stage
	state.tileSize = float(battle_inputs.get("tileSize",1.0))
	if not is_finite(state.tileSize) or state.tileSize <= 0: return _reject("Invalid tile size")
	# Commands currently place towers at tile centres with zero board origin.
	if battle_inputs.get("origin",[0.0,0.0]) != [0.0,0.0]: return _reject("Unsupported board origin")
	state.progression = decoded.progression.duplicate(true)
	state.progression.turretModules = decoded.turretModules.duplicate(true)
	state.nextTurretId = 1000
	var occupied := {}
	for t in state.turrets:
		var rule: Dictionary = growth.data.turretRules.get(t.type,{})
		if rule.is_empty() or t.x < 0 or t.y < 0 or t.x >= source.map.columns or t.y >= source.map.rows: return _reject("Invalid turret tile/type")
		var cell := int(t.y) * int(source.map.columns) + int(t.x)
		if occupied.has(cell) or source.map.tiles[cell] != "build": return _reject("Occupied or unbuildable turret tile")
		occupied[cell] = true
		if t.level < 1 or t.level > int(rule.maxLevel) or t.slotLimit < 1 or t.slotLimit > 4 or t.equippedGemSlots.size() > t.slotLimit: return _reject("Invalid turret level/slots")
		for key in ["primaryTrait","secondaryTrait"]:
			if t[key] != null and t[key] not in rule.get(key+"s",[]): return _reject("Invalid turret trait")
		var seen := {}
		for gem in t.equippedGemSlots:
			if gem == null: continue
			if seen.has(gem) or gem not in rule.compatibleGems: return _reject("Invalid turret gems")
			seen[gem] = true
		while t.equippedGemSlots.size() < t.slotLimit: t.equippedGemSlots.append(null)
		t.equippedGems = t.equippedGemSlots.filter(func(g): return g != null)
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
	var core_state := state.duplicate(true)
	core_state.progression.coreCombatSkill = run.runCoreCombatSkill
	inputs.coreConfig = growth.core_config(core_state,stage,mini(round_index,source.waves.size()-1),catalog)
	# A saved run skill is frozen independently of the current account selection.
	inputs.coreConfig.runSkill = run.runCoreCombatSkill
	var bootstrap: Dictionary = catalog.bootstrap(stage,inputs)
	if bootstrap.is_empty(): return _reject(catalog.error)
	bootstrap.defense.state = {"hp":run.nexusHp,"roundHpLost":run.roundNexusHpLost,"emergencyChargeUsedThisRound":run.emergencyChargeUsedThisRound,"finalDefenseUsedThisRound":run.finalDefenseUsedThisRound}
	bootstrap.core = run.runCoreCombatSkillStats.duplicate(true)
	bootstrap.turrets = []
	for command in service.runtime_commands(state): bootstrap.turrets.append(command.turret)
	bootstrap.enemies = []
	var next_enemy_id := 100000
	for saved in run.enemies:
		var enemy: Dictionary = catalog.enemy(stage,round_index,saved.type,next_enemy_id,inputs)
		if enemy.is_empty(): return _reject(catalog.error)
		enemy.merge(saved,true)
		enemy.distanceTravelled *= bootstrap.boardDistanceScale
		# Let NativeEnemyState reconstruct position/heading from saved distance.
		for key in ["x","y","position","targetIndex","facingAngle"]: enemy.erase(key)
		bootstrap.enemies.append(enemy)
		next_enemy_id += 1
	if live or not run.spawnQueue.is_empty():
		var queue := []
		var schedule: Array = source.waves[round_index].spawnQueue
		var offset: int = schedule.size() - run.spawnQueue.size()
		if offset < 0: return _reject("Spawn queue exceeds wave schedule")
		for index in range(run.spawnQueue.size()):
			if run.spawnQueue[index].enemyType != schedule[offset+index].enemyType: return _reject("Spawn queue does not match remaining wave schedule")
		# v2 stores only pending types/delays. Re-roll their spawn randomness using
		# the same real-content rules; existing live enemies keep saved values.
		var rng := spawn_rng if spawn_rng != null else RandomNumberGenerator.new()
		var spawn_values: Array = catalog.random_spawn_values(stage,round_index,rng)
		var pending_index := 0
		for saved in run.spawnQueue:
			if saved.delay < 0 or not is_finite(saved.delay): return _reject("Invalid spawn delay")
			var spawn_inputs := inputs.duplicate(true)
			spawn_inputs.enemyValues = spawn_values[offset+pending_index]
			var enemy: Dictionary = catalog.enemy(stage,round_index,saved.enemyType,next_enemy_id,spawn_inputs)
			pending_index += 1
			if enemy.is_empty(): return _reject(catalog.error)
			queue.append({"enemyType":saved.enemyType,"delay":saved.delay,"enemy":enemy})
			next_enemy_id += 1
		bootstrap.wave = {"id":source.waves[round_index].round,"active":live,"spawnQueue":queue}
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
