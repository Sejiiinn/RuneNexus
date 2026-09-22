extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Codec = preload("res://app/save_codec.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var catalog = Catalog.new()
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
	var saved: Dictionary = adapter.capture(state,runtime.snapshot(),123,{"selectedStageNumber":1,"autoStartMode":"fullAuto"})
	check(not saved.is_empty(),"capture: " + adapter.error)
	if saved.is_empty(): quit(1); return
	check(Codec.is_normalized_v2(saved),"normalized v2")
	check(saved.activeRun.enemies[0].distanceTravelled == 36.0,"wire distance uses 48px units")
	var prepared: Dictionary = adapter.prepare(saved)
	check(not prepared.is_empty(),"prepare: " + adapter.error)
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
