extends SceneTree
## Lifecycle coverage, not balance/winability: retain shipped schedules, enemy
## stats and geometry; enlarge only test core HP and use one-second logic steps.
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Domain = preload("res://session/run_session.gd")
var checks := 0
var failures: Array = []
var completed_waves := 0
var arrivals := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var catalog = Catalog.new()
	check(catalog.load_catalog(),"content loads")
	for stage_id in range(26,31): _stage(catalog,stage_id)
	check(completed_waves == 200,"all 200 waves completed naturally")
	print(JSON.stringify({"checks":checks,"failures":failures,"completedWaves":completed_waves,"arrivals":arrivals,"elapsedMillis":Time.get_ticks_msec()-started}))
	quit(0 if failures.is_empty() else 1)
func _stage(catalog, stage_id: int) -> void:
	var stage: int = catalog.stage_index(stage_id)
	var domain = Domain.new()
	domain.now_millis = func(): return 1791560000000
	check(domain.initialize(catalog,{"growthVersion":1,"coreCombatSkill":null},stage,stage_id),"domain initializes " + str(stage_id))
	var bootstrap: Dictionary = catalog.bootstrap(stage,{"defenseConfig":{"maxHp":1.0e12}})
	var runtime = Runtime.new()
	var sequence := 0
	check(runtime.process_command({"epoch":stage_id,"sequence":sequence,"bootstrap":bootstrap,"session":{"clock":"godot","phase":"preparation","paused":false}},false).accepted,"bootstrap " + str(stage_id))
	var seen_ids := {}
	var map: Dictionary = catalog.stage_map(stage)
	var route_ids := {}
	var expected_paths := {"":catalog.world_path(stage)}
	for route in map.get("routes",[]):
		route_ids[route.id] = true
		expected_paths[route.id] = catalog.world_path(stage,{"routeId":route.id})
	for round_index in range(40):
		var label := "%d/%d" % [stage_id,round_index+1]
		check(domain.state.phase == "preparation" and domain.state.roundIndex == round_index,"pre-wave domain " + label)
		var wave: Dictionary = catalog.wave(stage,round_index,100000+round_index*10000)
		var expected: int = wave.spawnQueue.size()
		var wave_arrivals := 0
		var completion_events := 0
		var gold_before: int = domain.state.gold
		domain.state.phase = "wave"
		sequence += 1
		check(runtime.process_command({"epoch":stage_id,"sequence":sequence,"session":{"phase":"wave","paused":false},"running":true,"commands":[{"kind":"waveStart","wave":wave}]},false).accepted,"start wave " + label)
		# Even the slowest shipped enemy can walk every waypoint inside this
		# generous guard after the real schedule's final spawn. No artificial kill.
		var limit: int = ceili(float(wave.spawnQueue[-1].delay)) + map.path.size()*10 + 300
		for tick in range(limit):
			runtime._step(1.0)
			for enemy in runtime.enemies.values():
				if seen_ids.has(enemy.id): continue
				seen_ids[enemy.id] = true
				if not route_ids.is_empty():
					check(route_ids.has(enemy.get("routeId","")),"spawn route identity " + label)
					check(enemy.path == expected_paths[enemy.routeId],"spawn follows own route " + label)
			for event in runtime.events:
				if event.id <= domain.event_ack: continue
				if event.kind == "arrival":
					wave_arrivals += 1
					var enemy: Dictionary = runtime.enemies[str(event.enemyId)]
					var expected_path: Array = expected_paths[enemy.get("routeId", "")]
					check(enemy.path == expected_path and is_equal_approx(enemy.x,expected_path[-1].x) and is_equal_approx(enemy.y,expected_path[-1].y),"natural arrival keeps route through core " + label)
				if event.kind == "waveCompleted": completion_events += 1
				check(event.kind != "kill" and event.kind != "coreDefeated","natural arrivals without kill/defeat " + label)
			var collected: Dictionary = domain.collect(runtime)
			check(collected.ok,"domain event collection " + label + ": " + domain.error)
			if not collected.ok: return
			sequence += 1
			runtime.process_command({"epoch":stage_id,"sequence":sequence,"ackEvent":domain.event_ack,"commands":collected.commands},false)
			if runtime.wave.completed: break
		check(runtime.wave.completed and completion_events == 1,"exactly one native completion " + label)
		check(wave_arrivals == expected and runtime.enemies.is_empty(),"every scheduled enemy arrives " + label)
		check(domain.state.completedRounds == round_index+1,"domain advances round " + label)
		check(domain.state.gold >= gold_before,"clear reward applied " + label)
		check(not domain.service.complete_wave(domain.state,round_index+1).ok,"duplicate domain completion rejected " + label)
		if not runtime.wave.completed: return
		completed_waves += 1
		arrivals += wave_arrivals
		var after_completion: Dictionary = domain.state.duplicate(true)
		runtime._step(1.0)
		check(runtime.events.is_empty(),"native completion never repeats " + label)
		check(domain.collect(runtime).ok and domain.state == after_completion,"repeated collection cannot repeat reward " + label)
		if domain.state.phase == "reward":
			check(domain.apply({"kind":"chooseRewardShards"}).ok,"real reward selection returns to preparation " + label)
	check(domain.state.phase == "success" and domain.state.completedRounds == 40 and domain.is_finished(),"final result settled " + str(stage_id))
	check(stage_id in domain.state.progression.clearedStageNumbers,"final clear retained " + str(stage_id))
	check(domain.state.progression.lastRunRuneReward > 0,"final rune reward " + str(stage_id))
	var finished: Dictionary = domain.state.duplicate(true)
	domain.finish(true)
	check(domain.state == finished,"final result and all rewards exactly once " + str(stage_id))
