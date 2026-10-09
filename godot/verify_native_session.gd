extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
	_verify_blast_timing()
	_verify_control_signals()
	_verify_frame_clock()
	_verify_fixed_clock_contract()
	_verify_boundary_commands()
	_verify_boundary_transitions()
	var runtime = Runtime.new()
	var setup := {"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","speed":1.0},"bootstrap":{"enemies":[{"id":1,"hp":100,"maxHp":100,"speed":1,"path":[[0,0],[100,0]]}]}}
	runtime.process_command(setup)
	var revision: int = runtime.state_revision
	runtime.advance_session(0.25)
	check(is_equal_approx(runtime.clock,0.25) and runtime.state_revision > revision, "native frame advances without host command")
	check(runtime.sequence == 0, "revision advances independently of command ACK")
	runtime.process_command({"epoch":1,"sequence":1,"dt":20.0,"steps":[{"dt":20.0}]})
	check(is_equal_approx(runtime.clock,0.25), "external dt cannot double advance session")
	runtime.process_command({"epoch":1,"sequence":2,"session":{"paused":true}})
	runtime.advance_session(1.0)
	check(is_equal_approx(runtime.clock,0.25), "pause")
	runtime.process_command({"epoch":1,"sequence":3,"session":{"paused":false,"speed":4.0}})
	runtime.advance_session(0.25, false)
	check(is_equal_approx(runtime.clock,0.25), "platform background")
	runtime.advance_session(0.25)
	check(is_equal_approx(runtime.clock,1.25) and is_equal_approx(runtime.wall_elapsed,0.5), "resume has no catch up; 4x only combat clock")
	runtime.submit_input({"kind":"boardTap","column":2,"row":3})
	var event_id: int = runtime.event_id
	runtime.advance_session(0.1)
	check(runtime.snapshot().events[-1].id == event_id, "input event survives replaced snapshot")
	runtime.process_command({"epoch":1,"sequence":4,"ackEvent":event_id})
	check(runtime.events.is_empty(), "explicit cumulative ACK retires event")
	runtime.process_command({"epoch":1,"sequence":5,"session":{"loading":true}})
	var clock: float = runtime.clock
	runtime.advance_session(0.5)
	check(runtime.clock == clock, "loading blocks time")
	runtime.process_command({"epoch":1,"sequence":6,"session":{"loading":false,"phase":"coreDestruction"}})
	runtime.advance_session(1.0)
	check(runtime.destruction_elapsed == 1.0 and is_equal_approx(runtime.clock,clock+0.25), "collapse slow motion")
	runtime.advance_session(2.2)
	check(runtime.session.phase == "failure" and is_equal_approx(runtime.destruction_elapsed,3.2), "collapse completes autonomously")
	runtime.process_command({"epoch":2,"sequence":0,"bootstrap":{},"session":{"clock":"godot","phase":"preparation"}})
	check(runtime.events.is_empty() and runtime.clock == 0 and runtime.wall_elapsed == 0, "new epoch resets clock/events")
	check(not runtime.process_command(setup).accepted and runtime.epoch == 2, "old bootstrap cannot reenter previous scene")
	if failures.is_empty(): print("PASS native session: autonomous time, one clock, pause/resume, speed, lifecycle, loading, events/ACK, destruction, epoch isolation")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _verify_blast_timing() -> void:
	for speed in [1.0, 4.0]:
		var runtime = Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","speed":speed},"bootstrap":{}})
		var turret := {"statInput":{"definition":{"type":"cannon"}}}
		runtime._visual("blast", Vector2.ZERO, turret, {"radius":1.0})
		runtime._visual("impact", Vector2.ZERO, turret)
		check(is_equal_approx(runtime.visual_effects[0].duration, 1.1), "cannon uses authored 1.1-second lifetime")
		check(is_equal_approx(runtime.visual_effects[1].duration, 0.28), "ordinary impact lifetime unchanged")
		runtime.advance_session(0.55 / speed)
		var frame: Dictionary = runtime.decorate_frame({})
		check(frame.impacts.size() == 1 and is_equal_approx(frame.impacts[0][4], 0.5), "blast reaches halfway after 0.55 combat seconds at " + str(speed) + "x")
		runtime.session.paused = true
		runtime.advance_session(1.0)
		check(runtime.decorate_frame({}).impacts == frame.impacts, "pause freezes explosion")
		runtime.session.paused = false
		runtime.advance_session(0.56 / speed)
		check(runtime.decorate_frame({}).impacts.is_empty(), "blast expires after 1.1 combat seconds")

func _new_runtime(speed: float = 1.0):
	var runtime = Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","speed":speed},"bootstrap":{}})
	return runtime

func _verify_fixed_clock_contract() -> void:
	var runtime = _new_runtime(4.0)
	runtime.advance_session(Runtime.FIXED_STEP / 8.0)
	check(runtime.simulation_tick == 0 and runtime.clock == 0, "sub-step debt never advances a partial integrator")
	runtime.advance_session(Runtime.FIXED_STEP / 8.0)
	check(runtime.simulation_tick == 1 and is_equal_approx(runtime.clock, Runtime.FIXED_STEP), "sub-step remainders combine into one game-time step")
	runtime = _new_runtime(4.0)
	runtime.advance_session(5.0)
	check(runtime.simulation_tick == Runtime.MAX_STEPS_PER_FRAME, "hitch work is bounded per render")
	check(is_equal_approx(runtime.clock + runtime.simulation_debt, 20.0), "hitch retains all earned game time")
	var debt: float = runtime.simulation_debt
	var wall: float = runtime.wall_elapsed
	for flag in ["paused", "loading", "backgrounded"]:
		runtime.session[flag] = true
		check(not runtime.advance_session(600.0) and not runtime.advance_session(0.0), flag + " blocks accrual and draining")
		check(runtime.simulation_debt == debt and runtime.wall_elapsed == wall, flag + " retains pre-earned debt without offline time")
		runtime.session[flag] = false
	check(not runtime.advance_session(600.0, false) and runtime.simulation_debt == debt, "inactive host contributes no offline time")
	runtime.process_command({"epoch":1,"sequence":1,"session":{"speed":1.0}})
	check(runtime.simulation_debt == debt, "speed change never rescales old game-time debt")
	var before: int = runtime.simulation_tick
	check(runtime.advance_session(0.0) and runtime.simulation_tick == before + Runtime.MAX_STEPS_PER_FRAME, "zero-delta frame drains retained debt within cap")
	check(runtime.wall_elapsed == wall, "debt drain never double-counts wall time")
	while runtime.simulation_debt + Runtime.STEP_EPSILON >= Runtime.FIXED_STEP:
		runtime.advance_session(0.0)
	check(runtime.simulation_tick == 1200 and is_equal_approx(runtime.clock, 20.0), "all hitch debt eventually simulates once")
	check(not runtime.advance_session(0.0), "empty zero-delta frame does no work")
	check(not runtime.advance_session(-1.0) and not runtime.advance_session(INF) and not runtime.advance_session(NAN), "invalid deltas cannot poison clock")
	runtime.advance_session(3.0)
	check(runtime.simulation_debt > 1.0, "new epoch reset tested with outstanding overload debt")
	runtime.process_command({"epoch":2,"sequence":0,"bootstrap":{},"session":{"clock":"godot","phase":"preparation","paused":true}})
	check(runtime.simulation_tick == 0 and runtime.simulation_debt == 0 and runtime.clock == 0, "checkpoint/new epoch starts fresh rather than replaying old debt")
	check(not runtime.advance_session(600.0), "restored paused clock waits for explicit resume")

func _command_replay(chunk_ticks: int):
	var runtime = _new_runtime()
	var boundary := func():
		var commands: Array = []
		match runtime.simulation_tick:
			3: commands = [{"kind":"spawn","enemy":{"id":7,"hp":100,"maxHp":100,"speed":6,"path":[[0,0],[100,0]]}}]
			8: commands = [{"kind":"coreDamage","enemyId":7,"damage":7.0}]
			13: commands = [{"kind":"riftMark","enemyId":7,"damageAmplification":0.25,"duration":0.2}]
		if commands.is_empty(): return
		var packet := {"epoch":1,"sequence":runtime.sequence+1,"ackEvent":runtime.event_id,"commands":commands}
		runtime.process_command(packet, false)
		runtime.process_command(packet, false)
		check(not runtime.advance_session(1.0), "boundary callback cannot recursively advance")
	runtime.step_completed.connect(boundary)
	for frame in range(24 / chunk_ticks): runtime.advance_session(Runtime.FIXED_STEP * chunk_ticks)
	runtime.step_completed.disconnect(boundary)
	return runtime

func _verify_boundary_commands() -> void:
	var fine = _command_replay(1)
	var coarse = _command_replay(8)
	check(fine.simulation_tick == 24 and coarse.simulation_tick == 24, "timestamped commands execute on identical ticks")
	check(fine.enemies == coarse.enemies and fine.events == coarse.events, "same boundary commands are independent of render grouping")
	check(fine.enemies["7"].hp == 93.0 and fine.sequence == 3 and fine.event_id == coarse.event_id, "duplicate command ACK does not repeat boundary damage")

func _verify_boundary_transitions() -> void:
	var runtime = _new_runtime()
	runtime.process_command({"epoch":1,"sequence":1,"commands":[{"kind":"waveStart","wave":{"id":1,"active":true,"spawnQueue":[]}}]})
	var reward_boundary := func():
		if runtime.wave.completed and runtime.session.phase == "wave":
			runtime.process_command({"epoch":1,"sequence":2,"ackEvent":runtime.event_id,"session":{"phase":"reward"}}, false)
	runtime.step_completed.connect(reward_boundary)
	runtime.advance_session(Runtime.FIXED_STEP * 15.0)
	check(runtime.simulation_tick == 1 and runtime.session.phase == "reward", "wave reward transition stops at completion boundary")
	check(runtime.sequence == 2 and runtime.events.is_empty(), "completion ACK settled before another fixed step")
	var debt: float = runtime.simulation_debt
	runtime.advance_session(600.0)
	check(runtime.simulation_tick == 1 and runtime.simulation_debt == debt, "reward wait freezes earned remainder and adds no game time")
	runtime.process_command({"epoch":1,"sequence":3,"session":{"phase":"preparation"}}, false)
	runtime.advance_session(0.0)
	check(runtime.simulation_tick == 15 and runtime.simulation_debt < Runtime.STEP_EPSILON, "reward choice resumes only pre-earned debt")
	runtime.step_completed.disconnect(reward_boundary)
	var replaced = _new_runtime()
	var epoch_boundary := func():
		if replaced.epoch == 1 and replaced.simulation_tick == 3:
			replaced.process_command({"epoch":2,"sequence":0,"bootstrap":{},"session":{"clock":"godot","phase":"preparation"}})
	replaced.step_completed.connect(epoch_boundary)
	replaced.advance_session(0.5)
	check(replaced.epoch == 2 and replaced.simulation_tick == 0 and replaced.clock == 0 and replaced.simulation_debt == 0, "new epoch during boundary callback stops old batch")
	replaced.advance_session(Runtime.FIXED_STEP)
	check(replaced.simulation_tick == 1, "replacement epoch accepts its own subsequent frame")
	replaced.step_completed.disconnect(epoch_boundary)

func _verify_frame_clock() -> void:
	var sampler = preload("res://session/combat_frame_clock.gd").new()
	check(sampler.sample(1000000, true, 1) == 0.0, "initial monotonic sample contributes no elapsed time")
	check(is_equal_approx(sampler.sample(1450000, true, 1), 0.45), "450ms active hitch is measured without engine-delta cap")
	check(sampler.sample(900000000, false, 1) == 0.0, "inactive host discards suspension time")
	check(sampler.sample(1900000000, true, 2) == 0.0, "resume starts a new monotonic sample")
	check(is_equal_approx(sampler.sample(1900016667, true, 2), 0.016667), "next active sample advances normally")
	check(sampler.sample(2900000000, true, 3) == 0.0, "resume generation drops unseen background interval")
	check(sampler.sample(3900000000, true, 3, 2) == 0.0, "control revision rejects pause-resume without inactive render")
	check(sampler.sample(3900450000, true, 3, 2) == 0.45, "real time after control resume is retained")
	sampler.reset()
	check(sampler.sample(4900000000, true, 3, 2) == 0.0, "scene/visibility reset prevents hidden time catch-up")
	var runtime = _new_runtime()
	var revision: int = runtime.clock_control_revision
	runtime.process_command({"epoch":1,"sequence":1,"session":{"paused":true}})
	runtime.process_command({"epoch":1,"sequence":2,"session":{"paused":false}})
	check(runtime.clock_control_revision == revision + 2, "pause-resume command pair changes sampling gate without a render")
	runtime.process_command({"epoch":1,"sequence":3,"session":{"speed":4.0}})
	check(runtime.clock_control_revision == revision + 2, "speed/ACK changes do not discard active sampling interval")

func _verify_control_signals() -> void:
	var runtime = Runtime.new()
	var notices: Array = []
	var before := func(): notices.append("before")
	var after := func(): notices.append("after")
	runtime.clock_control_changing.connect(before)
	runtime.clock_control_changed.connect(after)
	runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","speed":1.0},"bootstrap":{}})
	check(notices.is_empty(),"bootstrap never accrues old epoch host time")
	var packet := {"epoch":1,"sequence":1,"session":{"speed":4.0}}
	runtime.process_command(packet, false)
	check(notices == ["before","after"],"accepted control emits one ordered signal pair")
	runtime.process_command(packet, false)
	runtime.process_command({"epoch":0,"sequence":2,"session":{"speed":1.0}},false)
	runtime.process_command({"epoch":1,"sequence":3,"session":{"speed":1.0}},false)
	check(notices.size() == 2,"duplicate, stale and sequence-gap commands never mutate host timing")
	runtime.clock_control_changing.disconnect(before)
	runtime.clock_control_changed.disconnect(after)
