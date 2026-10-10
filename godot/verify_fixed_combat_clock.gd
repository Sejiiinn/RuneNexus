extends SceneTree
## The same game-timestamped replay must be independent of render cadence/speed.
## Optional FIXED_CLOCK_REPORT writes local evidence; FIXED_CLOCK_BASELINE=1
## records the pre-clock implementation without asserting cadence equivalence.
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Catalog = preload("res://content/content_catalog.gd")
const RunSession = preload("res://session/run_session.gd")
const SaveAdapter = preload("res://app/run_save_adapter.gd")
const SaveCodec = preload("res://app/save_codec.gd")
class ClockScene extends Node3D:
	var _native_combat = Runtime.new()
	var _native_combat_base_frame: Dictionary = {}
	func _apply_frame(frame: Dictionary) -> void:
		if frame.get("reset", false): _native_combat = Runtime.new()

class ClockApp extends "res://app/app_lifecycle.gd":
	var checkpoint_writes := 0
	func persist_progression() -> bool:
		checkpoint_writes += 1
		return true
	func refresh_selection() -> void:
		pass

const STEP := 1.0 / 60.0
const TYPES := ["arrow", "cannon", "magic", "frost", "sniper", "lightning"]
const PATTERNS := {
	"120Hz": [1.0 / 120.0], "60Hz": [STEP], "30Hz": [1.0 / 30.0],
	"20Hz": [1.0 / 20.0], "hitches": [1.0 / 240.0, STEP, 0.117, 0.002, 0.20, 1.0 / 30.0, 0.05, 0.007],
}
var checks := 0
var failures: Array = []
var fixtures: Array = []
var catalog = Catalog.new()
var baseline := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func close(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.0000001, label + ": " + str(actual) + " != " + str(expected))

func _initialize() -> void:
	baseline = OS.get_environment("FIXED_CLOCK_BASELINE") == "1"
	fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	check(catalog.load_catalog(), "content loads")
	var report := {}
	var legacy: Dictionary = {}
	if not baseline:
		legacy = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/fixed_combat_clock_60hz.json")).scenarios
	for scenario in TYPES + ["mixed", "burst"]:
		var reference := replay(scenario, [STEP], 1.0)
		report[scenario] = {"60Hz@1x": reference.metrics}
		if legacy.has(scenario):
			check(metrics_equal(reference.metrics, legacy[scenario]), scenario + ": original 60 Hz 1x balance preserved")
		check(reference.metrics.shots > 0, scenario + ": actually fires")
		check(reference.metrics.damage > 0, scenario + ": actually damages moving enemies")
		for cadence in PATTERNS:
			for speed in [1.0, 2.0, 4.0]:
				var label: String = cadence + "@" + str(int(speed)) + "x"
				if label == "60Hz@1x": continue
				var result := replay(scenario, PATTERNS[cadence], speed)
				report[scenario][label] = result.metrics
				if not baseline:
					check(result.state == reference.state, scenario + " " + label + ": exact combat, RNG, event and reward equality; " + difference(reference.metrics, result.metrics))
	if not baseline:
		lifecycle_checks()
		ordering_checks()
		controller_checks()
		debt_checks()
		var callback_run := replay("mixed", PATTERNS.hitches, 4.0, true)
		check(callback_run.state == replay("mixed", [STEP], 1.0).state, "commands injected at post-step game timestamps remain frame independent")
	var output := OS.get_environment("FIXED_CLOCK_REPORT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		check(file != null, "open requested evidence file")
		if file != null: file.store_string(JSON.stringify(report, "  "))
	print("FIXED_COMBAT_CLOCK checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func metrics_equal(actual: Variant, expected: Variant) -> bool:
	if expected is float or expected is int:
		return (actual is float or actual is int) and absf(float(actual) - float(expected)) < 0.0000001
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not metrics_equal(actual[key], expected[key]): return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size(): return false
		for i in range(expected.size()):
			if not metrics_equal(actual[i], expected[i]): return false
		return true
	return actual == expected

func difference(a: Dictionary, b: Dictionary) -> String:
	var changed: Array = []
	for key in a:
		if a[key] != b[key]: changed.append(key + " " + str(a[key]) + " -> " + str(b[key]))
	return "; ".join(changed)

func input_for(type: String, burst: bool = false) -> Dictionary:
	for fixture in fixtures:
		var source: Dictionary = fixture.input
		if source.definition.type == type and int(source.level) == 1 and source.gems.is_empty():
			var input := source.duplicate(true)
			input.definition.criticalChance = 0.35
			if burst:
				input.level = 10
				input.moduleEffect.attackRateIncreaseRate = 5.0
				input.gems = ["chain"]
			return input
	return {}

func tower(type: String, id: int, burst: bool = false) -> Dictionary:
	return {"id":id,"position":[0.0,float(id - 1) * 2.0],"statInput":input_for(type, burst),"state":{"x":id,"y":0}}

func moving_enemy(id: int, hp: float = 100.0) -> Dictionary:
	return {"id":id,"type":"normal","hp":hp,"maxHp":hp,"maxArmor":8.0,"armor":8.0,"maxShield":4.0,"shield":4.0,"speed":13.0 + float(id % 4) * 3.0,"collisionRadius":3.0,"coreDamage":2.0,"diamondReward":id % 2,"path":[[-85.0,-15.0],[-30.0,-15.0],[10.0,15.0],[85.0,15.0]]}

func setup(scenario: String, speed: float = 1.0):
	var towers: Array = []
	if scenario == "mixed":
		for i in range(TYPES.size()): towers.append(tower(TYPES[i], i + 1))
	else:
		towers.append(tower("arrow" if scenario == "burst" else scenario, 1, scenario == "burst"))
	var queue: Array = []
	for i in range(9):
		queue.append({"enemyType":"normal","delay":0.05 + i * 0.31,"enemy":moving_enemy(i + 1, [18.0,75.0,10000.0][i % 3])})
	var r = Runtime.new()
	r.process_command({"epoch":7,"sequence":0,"session":{"clock":"godot","phase":"wave","speed":speed},"bootstrap":{"seed":71423,"tileSize":48.0,"boardDistanceScale":1.0,"turrets":towers,"wave":{"id":1,"active":true,"spawnQueue":queue},"defense":{"config":{"maxHp":1000.0},"state":{"hp":1000.0}}}})
	return r

func timed_command(r, second: int) -> void:
	var commands: Array = []
	match second:
		3:
			var updated: Dictionary = r.turrets["1"].duplicate(true)
			updated.statInput.level = mini(10, int(updated.statInput.level) + 1)
			commands.append({"kind":"turret","turret":updated})
		5: commands.append({"kind":"riftMark","enemyId":3,"damageAmplification":0.25,"duration":1.25})
		7: commands.append({"kind":"spawn","enemy":moving_enemy(20, 80.0)})
		9: commands.append({"kind":"coreDamage","enemyId":3,"damage":35.0})
	if not commands.is_empty():
		var reply: Dictionary = r.process_command({"epoch":7,"sequence":r.sequence + 1,"commands":commands}, false)
		check(reply.accepted, "timestamped command accepted")

func replay(scenario: String, pattern: Array, speed: float, tick_commands: bool = false) -> Dictionary:
	var r = setup(scenario, speed)
	var tick_callback := func():
		if r.simulation_tick in [180, 300, 420, 540]: timed_command(r, r.simulation_tick / 60)
	if tick_commands: r.step_completed.connect(tick_callback)
	var supplied := 0.0
	var frame := 0
	# Split only at command timestamps. Every rate sees exactly the same commands
	# after ticks 180/300/420/540, before any later simulated combat.
	for boundary in ([12.0] if tick_commands else [3.0, 5.0, 7.0, 9.0, 12.0]):
		while supplied < boundary - 0.0000000001:
			var dt := minf(float(pattern[frame % pattern.size()]) * speed, boundary - supplied)
			r.advance_session(dt / speed)
			supplied += dt
			frame += 1
		if r.has_signal("step_completed"):
			while r.simulation_debt + 0.0000000001 >= STEP: r.advance_session(0.0)
		if not tick_commands: timed_command(r, int(boundary))
	if tick_commands: r.step_completed.disconnect(tick_callback)
	var domain = RunSession.new()
	domain.now_millis = func(): return 1720000000000
	check(domain.initialize(catalog, {}, 0, 7), "reward domain initializes")
	domain.state.economyRunId = "fixed-clock-fixture"
	domain.state.phase = "wave"
	check(domain.collect(r).ok, "native replay rewards settle")
	var rewards := {}
	for key in ["gold", "gemShards", "pendingEconomyDiamonds", "killGoldFractionWallet", "completedRounds"]: rewards[key] = domain.state.get(key)
	var before := rewards.duplicate(true)
	check(domain.collect(r).ok, "repeat reward collection accepted")
	for key in before: check(domain.state.get(key) == before[key], "repeat rewards not paid: " + key)
	var snapshot: Dictionary = r.snapshot()
	for key in ["session", "stateRevision", "ackSequence"]: snapshot.erase(key)
	snapshot.rng = str(r.rng.state)
	snapshot.rewards = rewards
	snapshot.projectiles = var_to_str(r.projectiles)
	snapshot.delayed = var_to_str(r.delayed)
	var shots := 0
	var damage := 0.0
	for t in r.turrets.values():
		shots += int(t.shotSequence)
		for key in ["directDamageDealt", "splashDamageDealt", "chainDamageDealt", "burnDamageDealt"]: damage += float(t[key])
	var hp := 0.0
	for e in r.enemies.values(): hp += float(e.hp) + float(e.armor) + float(e.shield)
	var kills: Array = []
	var arrivals: Array = []
	for e in r.events:
		if e.kind == "kill": kills.append(e.enemyId)
		if e.kind == "arrival": arrivals.append(e.enemyId)
	return {"state":JSON.stringify(snapshot),"metrics":{"shots":shots,"damage":damage,"durability":hp,"kills":kills,"arrivals":arrivals,"rewards":rewards,"rng":str(r.rng.state),"clock":r.clock}}

func empty_runtime(speed: float = 1.0):
	var r = Runtime.new()
	r.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","speed":speed},"bootstrap":{"enemies":[{"id":1,"type":"normal","hp":100.0,"maxHp":100.0,"speed":1.0,"path":[[0,0],[100,0]]}]}})
	return r

func patch_session(r, patch: Dictionary) -> void:
	r.process_command({"epoch":r.epoch,"sequence":r.sequence + 1,"session":patch}, false)

func lifecycle_checks() -> void:
	for barrier in ["paused", "loading", "backgrounded"]:
		var r = empty_runtime()
		r.advance_session(STEP * 0.5)
		close(r.clock, 0.0, barrier + ": fractional frame waits")
		patch_session(r, {barrier:true})
		r.advance_session(100.0)
		close(r.clock, 0.0, barrier + ": blocked time never accrues")
		patch_session(r, {barrier:false})
		r.advance_session(STEP * 0.5)
		close(r.clock, STEP, barrier + ": earned fractional debt retained")
	var r = empty_runtime()
	r.advance_session(STEP * 0.5)
	r.advance_session(100.0, false)
	r.advance_session(STEP * 0.5)
	close(r.clock, STEP, "host inactive does not accrue time")
	r = empty_runtime()
	r.advance_session(STEP * 0.5)
	patch_session(r, {"speed":4.0})
	r.advance_session(STEP / 8.0)
	close(r.clock, STEP, "speed change does not rescale already-earned debt")
	r.advance_session(STEP / 8.0)
	r.process_command({"epoch":2,"sequence":0,"session":{"clock":"godot","phase":"preparation"},"bootstrap":{}}, false)
	close(r.simulation_debt, 0.0, "new epoch clears fractional debt")
	check(r.simulation_tick == 0, "new epoch clears tick counter")
	r.advance_session(STEP * 0.5)
	close(r.clock, 0.0, "new stage never inherits old fractional tick")
	for phase in ["reward", "ended", "failure", "success", "restored"]:
		r = empty_runtime()
		r.advance_session(STEP * 0.5)
		patch_session(r, {"phase":phase})
		r.advance_session(100.0)
		close(r.clock, 0.0, phase + ": no combat time advances")
	# A snapshot/read is not a hidden simulation step or a new save field.
	r = empty_runtime()
	r.advance_session(STEP * 0.5)
	var saved: Dictionary = r.snapshot()
	close(r.simulation_debt, STEP * 0.5, "snapshot preserves live accumulator")
	var envelope: Dictionary = SaveCodec.decode({"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":{"phase":"wave","gold":321}})
	var checkpoint: Dictionary = SaveAdapter.capture(envelope, saved, {}, 1720000000000)
	check(not JSON.stringify(checkpoint).contains("simulationDebt") and not JSON.stringify(checkpoint).contains("simulationTick"), "runtime scheduler diagnostics do not enter v2 save")
	check(checkpoint.activeRun.enemies.size() == 1, "checkpoint preserves live enemy")
	if not checkpoint.activeRun.enemies.is_empty():
		close(checkpoint.activeRun.enemies[0].distanceTravelled, r.enemies["1"].distanceTravelled, "checkpoint captures last simulated position without spending debt")
	var restored = Runtime.new()
	var restored_enemies: Array = checkpoint.activeRun.enemies.duplicate(true)
	for i in range(restored_enemies.size()):
		restored_enemies[i].id = i + 1
		restored_enemies[i].path = saved.enemies[i].path.duplicate(true)
	restored.process_command({"epoch":2,"sequence":0,"session":{"clock":"godot","phase":"restored","paused":true},"bootstrap":{"enemies":restored_enemies}}, false)
	close(restored.simulation_debt, 0.0, "checkpoint bootstrap starts with no old debt")
	restored.advance_session(10.0)
	check(restored.simulation_tick == 0, "checkpoint stays paused until explicit resume")
	patch_session(restored, {"phase":"wave","paused":false})
	restored.advance_session(STEP * 0.5)
	check(restored.simulation_tick == 0, "checkpoint resume cannot replay pre-save fractional debt")

func ordering_checks() -> void:
	var r = empty_runtime()
	var e: Dictionary = r.enemies["1"]
	e.hp = 1.0
	e.speed = 60.0
	Enemy.update_path(e, [[0,0],[1,0]])
	Enemy.add_burn(e, {"damagePerSecond":60.0,"duration":1.0})
	r.advance_session(STEP)
	check(r.events.filter(func(v): return v.kind == "kill").size() == 1, "same-tick death before arrival emits one kill")
	check(r.events.filter(func(v): return v.kind == "arrival").is_empty(), "same-tick death suppresses arrival")
	r = Runtime.new()
	r.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave"},"bootstrap":{"defense":{"config":{"maxHp":3.0},"state":{"hp":3.0}},"enemies":[{"id":1,"hp":10.0,"maxHp":10.0,"speed":60.0,"coreDamage":5.0,"path":[[0,0],[1,0]]},{"id":2,"hp":1.0,"maxHp":1.0,"burnRemaining":1.0,"burnDamagePerSecond":60.0}]}})
	r.advance_session(STEP * 8.0)
	check(r.events.map(func(v): return v.kind) == ["arrival", "coreDefeated"], "lethal first arrival stops later enemy death in same tick")
	check(r.enemies["2"].hp == 1.0 and r.simulation_tick == 1, "terminal tick stops remaining combat and stale debt")
	var terminal_debt: float = r.simulation_debt
	r.advance_session(0.0)
	r.advance_session(1.0)
	check(r.simulation_tick == 1, "terminal retained debt never runs combat during collapse")
	close(r.simulation_debt, terminal_debt, "terminal retained debt is inert")
	r.process_command({"epoch":2,"sequence":0,"session":{"clock":"godot","phase":"wave"},"bootstrap":{}}, false)
	close(r.simulation_debt, 0.0, "terminal debt disappears with replacement epoch")

func debt_checks() -> void:
	var r = empty_runtime(4.0)
	r.advance_session(1.0)
	check(r.simulation_tick == Runtime.MAX_STEPS_PER_FRAME, "long hitch obeys work cap")
	check(r.simulation_debt >= STEP, "long hitch retains unprocessed game seconds")
	var wall: float = r.wall_elapsed
	while r.simulation_debt + 0.0000000001 >= STEP: r.advance_session(0.0)
	check(r.simulation_tick == 240, "draining hitch eventually simulates all earned steps")
	close(r.clock, 4.0, "long hitch has no discarded game time")
	close(r.wall_elapsed, wall, "zero-delta drain does not invent wall time")
	var before: Dictionary = r.snapshot()
	for invalid in [-1.0, INF, NAN]: r.advance_session(invalid)
	check(r.snapshot() == before, "negative and nonfinite frame deltas rejected")

func make_controller(speed: float):
	var app = ClockApp.new()
	app.scene = ClockScene.new()
	app.ui_enabled = false
	app.startup_blocked = false
	app.in_lobby = false
	app.auto_start_mode = "fullAuto"
	app.catalog = catalog
	app.spawn_rng.seed = 71423
	app.run_domain.now_millis = func(): return 1720000000000
	app.enter_stage(0, {}, {"speed":speed})
	return app

func controller_replay(pattern: Array, speed: float) -> Dictionary:
	var app = make_controller(speed)
	app.start_wave()
	var r = app.scene._native_combat
	check(r.step_completed.get_connections().size() == 1, "controller connects once to active runtime")
	# Resolve a real kill and final-enemy wave completion in the same fixed step.
	# All event collection, rewards, ACK and next-wave start use production code.
	r.wave.queue.clear()
	r.wave.next_index = 0
	r._spawn({"id":999,"type":"normal","hp":1.0,"maxHp":1.0,"burnRemaining":1.0,"burnDamagePerSecond":60.0,"diamondReward":1})
	var supplied := 0.0
	var frame := 0
	while supplied < 0.3 - 0.0000000001:
		var dt := minf(float(pattern[frame % pattern.size()]) * speed, 0.3 - supplied)
		r.advance_session(dt / speed)
		supplied += dt
		frame += 1
	check(app.next_round == 2 and r.wave.id == 2, "automatic next wave starts inside post-step callback")
	check(app.run_domain.state.completedRounds == 1 and app.run_domain.state.pendingEconomyDiamonds == 1, "same-step kill and wave rewards settled once")
	check(r.events.is_empty() and not r.enemies.has("999"), "same-step terminal enemy ACK retires after reward")
	check(app.run_domain.event_ack == r.event_id, "callback drains all generated wave and kill events")
	var deaths: Array = r.take_death_presentations()
	check(deaths.size() == 1 and int(deaths[0].enemyId) == 999, "ACK retains the final enemy death across every cadence/speed and automatic wave entry")
	check(not r.snapshot().has("_presentation_deaths"), "death display queue is runtime-only, never checkpoint state")
	if deaths.size() == 1:
		check(deaths[0].enemyPresentation.type == "normal" and deaths[0].has("visualOffset"), "death owns immutable presentation inputs after gameplay removal")
	app.command()
	check(r.take_death_presentations().is_empty(), "presentation consumption and repeated reward ACK cannot replay death")
	var result := {"wave":r.wave.snapshot(),"core":r.core.snapshot(),"clock":r.clock,"ticks":r.simulation_tick,"rng":str(r.rng.state),"spawnRng":str(app.spawn_rng.state),"gold":app.run_domain.state.gold,"diamonds":app.run_domain.state.pendingEconomyDiamonds,"completed":app.run_domain.state.completedRounds,"saves":app.checkpoint_writes}
	app.scene.free()
	app.free()
	return result

func controller_checks() -> void:
	var reference: Dictionary = controller_replay([STEP], 1.0)
	for cadence in PATTERNS:
		for speed in [1.0, 2.0, 4.0]:
			check(controller_replay(PATTERNS[cadence], speed) == reference, "actual controller auto-start/ACK/rewards: " + cadence + " " + str(speed) + "x")
	var initial_delay := -1.0
	for speed in [1.0, 2.0, 4.0]:
		var app = make_controller(speed)
		app.start_wave()
		var r = app.scene._native_combat
		var delay: float = r.wave.queue[0].delay
		if initial_delay < 0: initial_delay = delay
		close(delay, initial_delay, "first-wave delay is game time at " + str(speed) + "x")
		var old_runtime = r
		app.enter_stage(0)
		check(app.scene._native_combat != old_runtime and app.scene._native_combat.step_completed.get_connections().size() == 1, "replacement stage gets exactly one new callback")
		check(app.scene._native_combat.simulation_tick == 0 and app.scene._native_combat.simulation_debt == 0, "controller stage replacement resets scheduler")
		app.scene.free()
		app.free()
