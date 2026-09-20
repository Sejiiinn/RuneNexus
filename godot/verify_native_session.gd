extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
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
