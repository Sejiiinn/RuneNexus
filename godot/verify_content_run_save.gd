extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Codec = preload("res://app/save_codec.gd")
class CountingCatalog extends Catalog:
	var materialization_calls := {"bootstrap":0,"enemy":0,"random":0,"turret":0}
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
	var saved: Dictionary = adapter.capture(state,runtime.snapshot(),123,{"selectedStageNumber":1,"autoStartMode":"fullAuto"})
	check(not saved.is_empty(),"capture: " + adapter.error)
	check(catalog.materialization_calls == {"bootstrap":0,"enemy":0,"random":0,"turret":0},"capture validates without restore payload materialization")
	if saved.is_empty(): quit(1); return
	check(Codec.is_normalized_v2(saved),"normalized v2")
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
			if pending.type in catalog.data.randomization.bossTypes:
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
	state.pendingEconomyDiamonds = 1000001
	check(adapter.capture(state,runtime.snapshot(),124).is_empty(),"capped economy rejected before mutation")
	print("CONTENT_RUN_SAVE failures=",failures)
	quit(0 if failures == 0 else 1)

func _light_weapon_legacy_cases(adapter, service, saved: Dictionary) -> void:
	for type in service.catalog.data.turrets:
		var allowed: bool = "light" in service.catalog.data.turrets[type].configuration.statInput.definition.attackTags
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
