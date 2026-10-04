extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Codec = preload("res://app/save_codec.gd")
class CountingCatalog extends Catalog:
	var materialization_calls := {"bootstrap":0,"enemy":0,"random":0,"turret":0}
	var validation_calls := {"live":0,"pending":0}
	var pending_validation := false
	func validate_enemy(stage_index: int, round_index: int, type: String, inputs: Dictionary = {}) -> bool:
		if not pending_validation: validation_calls.live += 1
		return super.validate_enemy(stage_index,round_index,type,inputs)
	func validate_randomized_enemy(stage_index: int, round_index: int, type: String, inputs: Dictionary = {}) -> bool:
		validation_calls.pending += 1
		pending_validation = true
		var result := super.validate_randomized_enemy(stage_index,round_index,type,inputs)
		pending_validation = false
		return result
	func reset_calls() -> void:
		for key in materialization_calls: materialization_calls[key] = 0
	func bootstrap(stage_index: int, inputs: Dictionary = {}) -> Dictionary:
		materialization_calls.bootstrap += 1
		return super.bootstrap(stage_index,inputs)
	func enemy(stage_index: int, round_index: int, type: String, id: int = 100000, inputs: Dictionary = {}) -> Dictionary:
		materialization_calls.enemy += 1
		return super.enemy(stage_index,round_index,type,id,inputs)
	func random_spawn_values(stage_index: int, round_index: int, rng: RandomNumberGenerator) -> Array:
		materialization_calls.random += 1
		return super.random_spawn_values(stage_index,round_index,rng)
	func turret(type: String = "arrow", inputs: Dictionary = {}) -> Dictionary:
		materialization_calls.turret += 1
		return super.turret(type,inputs)

var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var catalog = CountingCatalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(),"catalogs")
	var service = Commands.new(catalog,growth)
	var adapter = Adapter.new(catalog,growth)
	var state: Dictionary = service.initial_state({"growthVersion":1,"runes":1234,"startingGoldUpgradeLevel":2,"fireTrainingUpgradeLevel":3,"coreCombatSkill":null,"turretModules":{"tickets":17,"items":[]}},0)
	var source: Dictionary = catalog.stage(0)
	var cell: int = source.map.tiles.find("build")
	var built: Dictionary = service.apply(state,{"kind":"build","type":"arrow","x":cell % int(source.map.columns),"y":cell / int(source.map.columns)})
	check(built.ok,"build")
	state = built.state
	state.turrets[0].slotLimit = 2
	state.turrets[0].equippedGemSlots = [null,"attackSpeed"]
	state.turrets[0].equippedGems = ["attackSpeed"]
	state.turrets[0].investedGold = 999
	state.pendingEconomyDiamonds = 7
	state.economyRunId = "actual-local-run"
	state.killGoldFractionWallet = 0.75
	state.runUpgradeLevels = {"towerDamage":2}
	state.runCoreCombatSkill = null
	var inputs: Dictionary = {"defenseConfig":service.derived(state).defenseConfig,"coreConfig":growth.core_config(state,0,0,catalog)}
	var bootstrap: Dictionary = catalog.bootstrap(0,inputs)
	bootstrap.turrets = []
	for command in service.runtime_commands(state): bootstrap.turrets.append(command.turret)
	bootstrap.wave = catalog.wave(0,0)
	var enemy: Dictionary = catalog.enemy(0,0,"normal",99999)
	enemy.distanceTravelled = 0.75
	for key in ["x","y","position","targetIndex","facingAngle"]: enemy.erase(key)
	enemy.burnInstances = [{"remaining":2.0,"damagePerSecond":0.5,"damageMultiplier":1.0,"sourceX":state.turrets[0].x,"sourceY":state.turrets[0].y,"ignoreArmorReduction":false}]
	bootstrap.enemies = [enemy]
	var runtime = Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","paused":true},"bootstrap":bootstrap})
	state.phase = "reward"
	state.isPurchasedGemReward = true
	state.rewardReturnPhase = "wave"
	state.rewardOptions = ["attackSpeed","range"]
	check(adapter.capture(state,runtime.snapshot(),1).is_empty(),"unacknowledged events rejected")
	runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
	catalog.reset_calls()
	var source_state := state.duplicate(true)
	var source_snapshot: Dictionary = runtime.snapshot()
	var source_snapshot_before := source_snapshot.duplicate(true)
	var source_preferences := {"selectedStageNumber":1,"autoStartMode":"fullAuto"}
	var saved: Dictionary = adapter.capture(state,source_snapshot,123,source_preferences)
	check(not saved.is_empty(),"capture: " + adapter.error)
	check(state == source_state and source_snapshot == source_snapshot_before and source_preferences == {"selectedStageNumber":1,"autoStartMode":"fullAuto"},"capture leaves all source trees unchanged")
	check(catalog.materialization_calls == {"bootstrap":0,"enemy":0,"random":0,"turret":0},"capture validates without restore payload materialization")
	if saved.is_empty(): quit(1); return
	var captured_before := saved.duplicate(true)
	saved.progression.runes = 1
	saved.turretModules.tickets = 1
	saved.activeRun.enemies[0].hp = 1.0
	saved.activeRun.turrets[0].equippedGemSlots[1] = null
	check(state == source_state and source_snapshot == source_snapshot_before,"captured nested trees own their mutations")
	saved = captured_before
	check(Codec.is_normalized_v2(saved),"normalized v2")
	_capture_normalized_handoff_cases(adapter,state,source_snapshot,saved)
	check(saved.activeRun.enemies[0].distanceTravelled == 36.0,"wire distance uses 48px units")
	var prepared: Dictionary = adapter.prepare(saved)
	check(not prepared.is_empty(),"prepare: " + adapter.error)
	check(catalog.materialization_calls.bootstrap == 1 and catalog.materialization_calls.turret == 1 and catalog.materialization_calls.random == 1 and catalog.materialization_calls.enemy > 0,"prepare alone materializes restore payload")
	if prepared.is_empty(): quit(1); return
	check(prepared.session.paused and prepared.state.phase == "reward" and prepared.state.rewardReturnPhase == "wave","paused purchased reward resumes")
	check(prepared.nextRound == 1 and prepared.state.pendingEconomyDiamonds == 7 and prepared.state.economyRunId == "actual-local-run","round and pending economy")
	check(prepared.state.turrets[0].investedGold == 999 and prepared.state.turrets[0].equippedGemSlots == [null,"attackSpeed"],"investment and empty gem slot")
	check(prepared.state.progression.turretModules.tickets == 17 and prepared.bootstrap.coreConfig.runSkill == null,"inventory and null core skill")
	var restored = Runtime.new()
	restored.process_command({"epoch":2,"sequence":0,"session":prepared.session,"bootstrap":prepared.bootstrap})
	check(is_equal_approx(restored.enemies["100000"].distanceTravelled,0.75),"restored distance")
	check(is_equal_approx(restored.enemies["100000"].x,runtime.enemies["99999"].x) and is_equal_approx(restored.enemies["100000"].y,runtime.enemies["99999"].y),"position reconstructed from distance")
	check(restored.turrets["1000"].stats.damage == runtime.turrets["1000"].stats.damage,"growth and gems rebuilt combat stats")
	check(restored.wave.queue[0].delay == runtime.wave.snapshot().spawnQueue[0].delay,"remaining spawn delay no added gap")
	_light_weapon_legacy_cases(adapter,service,saved)
	_gem_slot_restore_cases(adapter,saved)
	var before := saved.duplicate(true)
	var bad := saved.duplicate(true)
	bad.activeRun.mapSignature = "different-map"
	check(adapter.prepare(bad).is_empty(),"wrong map rejected")
	bad = saved.duplicate(true)
	bad.activeRun.roundIndex = 999
	check(adapter.prepare(bad).is_empty(),"unknown round rejected")
	bad = saved.duplicate(true)
	bad.activeRun.turrets[0].equippedGemSlots = ["notAGem"]
	check(adapter.prepare(bad).is_empty(),"unsupported gem rejected without codec loss")
	bad = saved.duplicate(true)
	bad.activeRun.runUpgradeLevels.towerDamage = 999
	check(adapter.prepare(bad).is_empty(),"unsupported growth rejected")
	check(saved == before,"preparation leaves source unchanged")
	check(adapter.prepare(saved,{"origin":[1.0,0.0]}).is_empty(),"unsupported layout rejected")
	for phase in ["preparation","reward","success","failure"]:
		var phase_save := saved.duplicate(true)
		phase_save.activeRun.phase = phase
		phase_save.activeRun.isPurchasedGemReward = false
		phase_save.activeRun.rewardReturnPhase = null
		phase_save.activeRun.spawnQueue = []
		if phase != "failure": phase_save.activeRun.enemies = []
		if phase != "reward": phase_save.activeRun.rewardOptions = []
		if phase == "failure": phase_save.activeRun.nexusHp = 0.0
		var phase_result: Dictionary = adapter.prepare(phase_save)
		check(not phase_result.is_empty(),"phase prepares: " + phase + " " + adapter.error)
		if not phase_result.is_empty():
			check(phase_result.state.phase == phase and phase_result.session.paused,"phase retained paused: " + phase)
	var randomized := saved.duplicate(true)
	randomized.activeRun.roundIndex = 9
	randomized.activeRun.enemies[0].diamondReward = 3
	randomized.activeRun.enemies[0].laneOffsetRatio = 0.04
	randomized.activeRun.spawnQueue = source.waves[9].spawnQueue.slice(1).duplicate(true)
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 6
	var expected_values: Array = catalog.random_spawn_values(0,9,expected_rng)
	var restore_rng := RandomNumberGenerator.new()
	restore_rng.seed = 6
	var randomized_result: Dictionary = adapter.prepare(randomized,{},restore_rng)
	check(not randomized_result.is_empty(),"pending spawn reroll preparation: " + adapter.error)
	if not randomized_result.is_empty():
		var carrier_found := false
		var boss_found := false
		for index in range(randomized_result.bootstrap.wave.spawnQueue.size()):
			var pending: Dictionary = randomized_result.bootstrap.wave.spawnQueue[index].enemy
			var expected: Dictionary = expected_values[index+1]
			check(pending.diamondReward == expected.diamondReward and pending.laneOffsetRatio == expected.laneOffsetRatio and pending.visualPhase == expected.visualPhase,"pending suffix uses real per-type seeded rules")
			carrier_found = carrier_found or pending.diamondReward > 0
			if pending.type in catalog.randomization().bossTypes:
				boss_found = true
				check(pending.diamondReward == 0,"boss cannot carry diamonds")
		check(carrier_found and boss_found,"real seeded sample includes carrier and boss")
		check(randomized_result.bootstrap.enemies[0].diamondReward == 3 and randomized_result.bootstrap.enemies[0].laneOffsetRatio == 0.04,"live enemy saved random values remain unchanged")
	var failure_queue := saved.duplicate(true)
	failure_queue.activeRun.phase = "failure"
	failure_queue.activeRun.nexusHp = 0.0
	check(adapter.prepare(failure_queue).is_empty(),"terminal queue rejected rather than silently dropped")
	var wrong_queue := saved.duplicate(true)
	wrong_queue.activeRun.spawnQueue[0].enemyType = "forgeBoss"
	check(adapter.prepare(wrong_queue).is_empty(),"pending queue must match actual wave suffix")
	var fractional := state.duplicate(true)
	fractional.gold = 1.5
	check(adapter.capture(fractional,runtime.snapshot(),124).is_empty(),"fractional gold rejected")
	fractional.gold = 1.0
	check(adapter.capture(fractional,runtime.snapshot(),124).is_empty(),"float-typed integer gold rejected")
	var invalid := saved.duplicate(true)
	invalid.activeRun.nexusHp = NAN
	check(adapter.prepare(invalid).is_empty(),"nonfinite state rejected")
	var scaled: Dictionary = adapter.prepare(saved,{"tileSize":2.0})
	check(not scaled.is_empty() and scaled.bootstrap.enemies[0].distanceTravelled == 1.5,"alternate tile size distance scaled")
	_validation_reuse_cases(adapter,catalog,saved)
	state.pendingEconomyDiamonds = 1000001
	check(adapter.capture(state,runtime.snapshot(),124).is_empty(),"capped economy rejected before mutation")
	_ordinal_durability_save_cases(catalog,growth)
	print("CONTENT_RUN_SAVE failures=",failures)
	quit(0 if failures == 0 else 1)

func _capture_normalized_handoff_cases(adapter, state: Dictionary, snapshot: Dictionary, saved: Dictionary) -> void:
	check(not saved.activeRun.has("stage") and not saved.activeRun.has("nextTurretId") and not saved.activeRun.turrets[0].has("id") and not saved.progression.has("turretModules"),"capture validation scratch fields do not leak into save")
	var legacy := state.duplicate(true)
	legacy.turrets[0].type = "cannon"
	legacy.turrets[0].slotLimit = 3
	legacy.turrets[0].equippedGemSlots = [null,"lightWeapon"]
	legacy.turrets[0].equippedGems = ["lightWeapon"]
	legacy.gemInventory = {"lightWeapon":2}
	var legacy_before := legacy.duplicate(true)
	var legacy_saved: Dictionary = adapter.capture(legacy,snapshot,125)
	check(not legacy_saved.is_empty(),"capture validates legacy gem migration on separate scratch: "+adapter.error)
	if not legacy_saved.is_empty():
		check(legacy_saved.activeRun.turrets[0].equippedGemSlots == [null,"lightWeapon"] and legacy_saved.activeRun.turrets[0].equippedGems == ["lightWeapon"] and legacy_saved.activeRun.gemInventory == {"lightWeapon":2},"capture preserves saved slots/inventory before restore migration")
	check(legacy == legacy_before,"capture legacy validation cannot change domain source")
	var absent_skill := state.duplicate(true)
	absent_skill.erase("runCoreCombatSkill")
	for skill in [null,"guardianBeam","riftMark"]:
		var skill_snapshot := snapshot.duplicate(true)
		skill_snapshot.core.skill = skill
		var skill_saved: Dictionary = adapter.capture(absent_skill,skill_snapshot,126)
		check(not skill_saved.is_empty(),"capture accepts absent frozen skill snapshot fallback: "+str(skill)+" "+adapter.error)
		if not skill_saved.is_empty(): check(skill_saved.activeRun.runCoreCombatSkill == skill and Codec.is_normalized_v2(skill_saved),"snapshot fallback is normalized and frozen: "+str(skill))
	var invalid_skill := snapshot.duplicate(true)
	invalid_skill.core.skill = "unknownSkill"
	check(adapter.capture(absent_skill,invalid_skill,126).is_empty() and adapter.error == "Unsupported save values","capture rejects unsupported post-projection skill fallback")
	var scaled := state.duplicate(true)
	scaled.tileSize = 2.0
	var scaled_snapshot := snapshot.duplicate(true)
	scaled_snapshot.enemies[0].distanceTravelled = 1.25
	var scaled_saved: Dictionary = adapter.capture(scaled,scaled_snapshot,127)
	check(not scaled_saved.is_empty(),"capture scaled handoff: "+adapter.error)
	if not scaled_saved.is_empty(): check(scaled_saved.activeRun.enemies[0].distanceTravelled == 30.0 and Codec.is_normalized_v2(scaled_saved),"capture scales distance without losing float wire type")
	scaled.tileSize = 1e-300
	scaled_snapshot.enemies[0].distanceTravelled = 1e300
	check(adapter.capture(scaled,scaled_snapshot,127).is_empty() and adapter.error == "Unsupported save values","capture rejects overflow created by distance scaling")
	var missing_return := state.duplicate(true)
	missing_return.rewardReturnPhase = null
	check(adapter.capture(missing_return,snapshot,128).is_empty() and adapter.error == "Unsupported save values","domain reward phase cannot silently normalize a null return phase")
	var reward_snapshot := snapshot.duplicate(true)
	reward_snapshot.session.phase = "reward"
	var reward_saved: Dictionary = adapter.capture(missing_return,reward_snapshot,128)
	check(not reward_saved.is_empty() and reward_saved.activeRun.rewardReturnPhase == "wave","projection retains existing purchased reward fallback")
	for phase in ["preparation","restored","reward","success","coreDestruction","failure"]:
		var phase_state := state.duplicate(true)
		phase_state.phase = phase
		phase_state.isPurchasedGemReward = false
		phase_state.rewardReturnPhase = null
		var phase_snapshot := snapshot.duplicate(true)
		phase_snapshot.enemies = []
		phase_snapshot.wave.spawnQueue = []
		var phase_saved: Dictionary = adapter.capture(phase_state,phase_snapshot,129)
		check(not phase_saved.is_empty(),"capture domain phase survives normalized handoff: "+phase+" "+adapter.error)
		if not phase_saved.is_empty(): check(phase_saved.activeRun.phase == ("failure" if phase == "coreDestruction" else phase) and Codec.is_normalized_v2(phase_saved),"domain phase wire value preserved: "+phase)
	var permissive_state := state.duplicate(true)
	permissive_state.gemInventory.unknownGem = 2
	var permissive_snapshot := snapshot.duplicate(true)
	permissive_snapshot.enemies.append({"type":"unknownEnemy"})
	permissive_snapshot.core.activationCount = 1.5
	var permissive_saved: Dictionary = adapter.capture(permissive_state,permissive_snapshot,130)
	check(not permissive_saved.is_empty(),"capture keeps existing codec permissive projection behavior: "+adapter.error)
	if not permissive_saved.is_empty(): check(not permissive_saved.activeRun.gemInventory.has("unknownGem") and permissive_saved.activeRun.enemies.size() == snapshot.enemies.size() and permissive_saved.activeRun.runCoreCombatSkillStats.activationCount == 1,"existing unknown key/enemy filtering and activation truncation unchanged")

func _light_weapon_legacy_cases(adapter, service, saved: Dictionary) -> void:
	for type in service.catalog.turret_types():
		var allowed: bool = "light" in service.catalog.turret_definition(type).attackTags
		var legacy := saved.duplicate(true)
		legacy.activeRun.turrets[0].type = type
		legacy.activeRun.turrets[0].slotLimit = 3
		legacy.activeRun.turrets[0].equippedGemSlots = [null,"lightWeapon","attackSpeed"]
		legacy.activeRun.turrets[0].equippedGems = ["lightWeapon","attackSpeed"]
		legacy.activeRun.gemInventory = {"lightWeapon":2,"range":3}
		var original := legacy.duplicate(true)
		var result: Dictionary = adapter.prepare(legacy)
		check(not result.is_empty(),type+": old lightWeapon save remains loadable: "+adapter.error)
		if result.is_empty(): continue
		check(result.envelope == Codec.decode(legacy),type+": restored migrations leave returned envelope unchanged")
		var expected_slots: Array = [null,"lightWeapon" if allowed else null,"attackSpeed"]
		var expected_inventory := {"lightWeapon":2 if allowed else 3,"range":3}
		check(result.state.turrets[0].equippedGemSlots == expected_slots,type+": only obsolete slot cleared")
		check(result.state.turrets[0].equippedGems == expected_slots.filter(func(g): return g != null),type+": equipped list follows slots")
		check(result.state.gemInventory == expected_inventory,type+": obsolete gem returned once")
		check(("lightWeapon" in result.bootstrap.turrets[0].statInput.gems) == allowed,type+": restored combat respects eligibility")
		check(legacy == original,type+": loading does not change source save")
		var again: Dictionary = adapter.prepare(legacy)
		check(not again.is_empty() and again.state.gemInventory == expected_inventory,type+": repeat source load does not accumulate refund")
		var runtime = Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"session":result.session,"bootstrap":result.bootstrap})
		runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
		var resaved: Dictionary = adapter.capture(result.state,runtime.snapshot(),456)
		check(not resaved.is_empty(),type+": migrated state saves: "+adapter.error)
		if not resaved.is_empty():
			var reloaded: Dictionary = adapter.prepare(resaved)
			check(not reloaded.is_empty() and reloaded.state.gemInventory == expected_inventory and reloaded.state.turrets[0].equippedGemSlots == expected_slots,type+": save and reload does not refund twice")
		# Saves without explicit slots use the legacy equipped list once.
		legacy.activeRun.turrets[0].erase("equippedGemSlots")
		var old_format: Dictionary = adapter.prepare(legacy)
		check(not old_format.is_empty() and old_format.state.gemInventory == expected_inventory,type+": legacy equipped list refunds once")
	var invalid := saved.duplicate(true)
	invalid.activeRun.turrets[0].type = "cannon"
	invalid.activeRun.turrets[0].equippedGemSlots = ["lightWeapon","lightWeapon"]
	invalid.activeRun.turrets[0].equippedGems = ["lightWeapon","lightWeapon"]
	check(adapter.prepare(invalid).is_empty(),"duplicate obsolete gems still rejected")
	invalid.activeRun.turrets[0].equippedGemSlots = ["lightWeapon","aimSpeed"]
	invalid.activeRun.turrets[0].equippedGems = ["lightWeapon","aimSpeed"]
	check(adapter.prepare(invalid).is_empty(),"other incompatible gems still rejected")


func _validation_reuse_cases(adapter, catalog, saved: Dictionary) -> void:
	var repeated := saved.duplicate(true)
	for index in range(16): repeated.activeRun.enemies.append(saved.activeRun.enemies[0].duplicate(true))
	var original := repeated.duplicate(true)
	var live_types := {}
	var pending_types := {}
	for enemy in repeated.activeRun.enemies: live_types[enemy.type] = true
	for spawn in repeated.activeRun.spawnQueue: pending_types[spawn.enemyType] = true
	for for_restore in [true,false]:
		catalog.validation_calls = {"live":0,"pending":0}
		var result: Dictionary = adapter._validate_checkpoint(repeated,{},for_restore)
		check(not result.is_empty(),"both validation modes accept repeated enemy fixture")
		check(catalog.validation_calls == {"live":live_types.size(),"pending":pending_types.size()},"each mode validates each live/pending type once independently")
		check(repeated == original,"both validation modes preserve source envelope")
	# Different inputs on the next call must be checked even for a prior success.
	var invalid_inputs := {"enemyValues":{"diamondReward":"invalid"}}
	for for_restore in [true,false]:
		catalog.validation_calls = {"live":0,"pending":0}
		check(adapter._validate_checkpoint(repeated,invalid_inputs,for_restore).is_empty(),"successful type validation cannot leak to a later call's inputs")
		check(catalog.validation_calls == {"live":1,"pending":0},"invalid live values fail before pending validation")
	# Pending generation replaces enemyValues and remains a distinct validation.
	var pending_only := repeated.duplicate(true)
	pending_only.activeRun.enemies = []
	for for_restore in [true,false]:
		catalog.validation_calls = {"live":0,"pending":0}
		check(not adapter._validate_checkpoint(pending_only,invalid_inputs,for_restore).is_empty(),"pending overrides remain valid independently of caller live values")
		check(catalog.validation_calls == {"live":0,"pending":pending_types.size()},"pending-only validation retains its own type successes")
	var invalid_delay := repeated.duplicate(true)
	invalid_delay.activeRun.spawnQueue[-1].delay = -0.1
	for for_restore in [true,false]:
		check(adapter._validate_checkpoint(invalid_delay,{},for_restore).is_empty() and adapter.error == "Invalid spawn delay","every pending delay is checked after a repeated successful type")
	var result: Dictionary = adapter.prepare(repeated)
	check(not result.is_empty(),"repeated fixture prepares")
	if not result.is_empty():
		var envelope_before: Dictionary = result.envelope.duplicate(true)
		result.state.turrets[0].equippedGemSlots[0] = "range"
		result.state.gemInventory.range = 17
		result.state.progression.turretModules.tickets = 1
		check(result.envelope == envelope_before,"restore state mutations do not change returned envelope")

func _gem_slot_restore_cases(adapter, saved: Dictionary) -> void:
	var short_slots := saved.duplicate(true)
	short_slots.activeRun.turrets[0].slotLimit = 3
	short_slots.activeRun.turrets[0].equippedGemSlots = [null]
	# Explicit slots remain authoritative over the legacy derived list.
	short_slots.activeRun.turrets[0].equippedGems = ["attackSpeed"]
	var original := short_slots.duplicate(true)
	var result: Dictionary = adapter.prepare(short_slots)
	check(not result.is_empty(),"short slot array remains loadable: "+adapter.error)
	if not result.is_empty():
		check(result.state.turrets[0].equippedGemSlots == [null,null,null] and result.state.turrets[0].equippedGems.is_empty(),"restore pads empty slots and derives equipped list from slots")
		check(result.state.gemInventory == original.activeRun.gemInventory,"stale derived list does not refund inventory")
	check(short_slots == original,"slot padding and list derivation preserve source save")
	for gems in [["attackSpeed","attackSpeed"],["lightWeapon","lightWeapon"],["lightWeapon","aimSpeed"]]:
		var invalid := saved.duplicate(true)
		invalid.activeRun.turrets[0].type = "cannon"
		invalid.activeRun.turrets[0].equippedGemSlots = gems.duplicate()
		invalid.activeRun.turrets[0].equippedGems = gems.duplicate()
		original = invalid.duplicate(true)
		check(adapter.prepare(invalid).is_empty() and adapter.error == "Invalid turret gems","duplicate or incompatible restore retains exact gem error: "+str(gems))
		check(invalid == original,"rejected restore does not refund or clear source slots: "+str(gems))

func _ordinal_durability_save_cases(current, growth) -> void:
	# Reconstruct historical fixed-ID scaling solely for pre-alignment v2 input.
	# These save fields keep their original values; no save schema is changed.
	var old = Catalog.new()
	check(old.load_catalog(),"legacy content input loads")
	var fixture: Dictionary = current.domain_snapshot()
	for stage in fixture.stages:
		if stage.id > 15: continue
		for wave in stage.waves:
			var factor := pow(2.0,(wave.round-1)/10.0) * pow(1.15,stage.id-1)
			for kind in fixture.enemyDefinitions:
				for field in ["maxHp","maxShield","maxArmor"]:
					wave.enemyDurability[kind][field] = fixture.enemyDefinitions[kind][field] * factor
	check(old.load_fixture_content(fixture),"historical durability fixture loads")
	for stage_id in [6,11]:
		var stage: int = stage_id-1
		var round_index := 9
		var commands = Commands.new(old,growth)
		var old_adapter = Adapter.new(old,growth)
		var new_adapter = Adapter.new(current,growth)
		var state: Dictionary = commands.initial_state({"growthVersion":1,"runes":345,"coreCombatSkill":null,"turretModules":{"tickets":8,"items":[]}},stage)
		state.phase = "wave"
		state.roundIndex = round_index
		state.completedRounds = round_index
		state.tileSize = 48.0
		state.runCoreCombatSkill = null
		state.economyRunId = "ordinal-old-run-"+str(stage_id)
		state.pendingEconomyDiamonds = 7
		var input := {"tileSize":48.0,"defenseConfig":commands.derived(state).defenseConfig}
		var bootstrap: Dictionary = old.bootstrap(stage,input)
		bootstrap.wave = old.wave(stage,round_index,100000,input)
		bootstrap.enemies = []
		var kinds := ["normal","shielded","shieldBoss"] if stage_id == 6 else ["armored","shielded","forgeBoss"]
		for index in range(kinds.size()):
			var enemy: Dictionary = old.enemy(stage,round_index,kinds[index],90000+index,input)
			enemy.hp *= 0.45
			enemy.shield *= 0.25
			enemy.armor *= 0.6
			enemy.distanceTravelled = 48.0 * (2.25+index)
			enemy.slowInstances = [{"multiplier":0.8,"remaining":2.0}]
			for field in ["x","y","position","targetIndex","facingAngle"]: enemy.erase(field)
			bootstrap.enemies.append(enemy)
		var runtime = Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","paused":true},"bootstrap":bootstrap})
		runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
		var saved: Dictionary = old_adapter.capture(state,runtime.snapshot(),123,{"selectedStageNumber":stage_id})
		check(not saved.is_empty(),"old capture "+str(stage_id)+": "+old_adapter.error)
		if saved.is_empty(): continue
		var untouched := saved.duplicate(true)
		var prepared: Dictionary = new_adapter.prepare(saved,{"tileSize":48.0})
		check(not prepared.is_empty(),"new prepare "+str(stage_id)+": "+new_adapter.error)
		if prepared.is_empty(): continue
		check(saved == untouched,"source save immutable")
		check(prepared.envelope == saved,"old v2 fields retained")
		check(prepared.state.stage == stage and prepared.nextRound == round_index+1 and prepared.session.paused,"same stage,next round,paused")
		check(prepared.state.economyRunId == state.economyRunId and prepared.state.pendingEconomyDiamonds == 7 and prepared.state.progression.runes == 345,"economy records retained")
		var restored = Runtime.new()
		restored.process_command({"epoch":2,"sequence":0,"session":prepared.session,"bootstrap":prepared.bootstrap})
		for index in range(saved.activeRun.enemies.size()):
			var before: Dictionary = saved.activeRun.enemies[index]
			var live: Dictionary = restored.enemies[str(100000+index)]
			for field in ["maxHp","hp","shield","armor","distanceTravelled","slowInstances"]:
				check(live[field] == before[field],"old live retained "+field)
			var definition: Dictionary = current.wave_durability(stage,round_index,before.type)
			for field in ["maxShield","maxArmor"]:
				check(not before.has(field) and live[field] == definition[field],"v2 omitted derived maximum "+field)
		for index in range(prepared.bootstrap.wave.spawnQueue.size()):
			var pending: Dictionary = prepared.bootstrap.wave.spawnQueue[index]
			check(pending.delay == saved.activeRun.spawnQueue[index].delay and pending.enemyType == saved.activeRun.spawnQueue[index].enemyType,"pending type/delay retained")
			var expected: Dictionary = current.wave_durability(stage,round_index,pending.enemyType)
			for field in ["maxHp","maxShield","maxArmor"]: check(pending.enemy[field] == expected[field],"pending latest "+field)
		var next_wave: Dictionary = current.wave(stage,prepared.nextRound,200000,{"tileSize":48.0})
		check(next_wave.id == round_index+2,"next wave identity")
		for pending in next_wave.spawnQueue:
			var expected: Dictionary = current.wave_durability(stage,round_index+1,pending.enemyType)
			for field in ["maxHp","maxShield","maxArmor"]: check(pending.enemy[field] == expected[field],"next latest "+field)
		var core: Dictionary = growth.core_config(prepared.state,stage,round_index,current)
		check(core.normalMaxHp == current.wave_durability(stage,round_index,"normal").maxHp,"core current normal reference")
