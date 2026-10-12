extends SceneTree
## Shared orchestration must run without development UI or a fixture payload.
var failures: Array = []
## Native runtime that can refuse a start or any non-empty command batch.
class RejectingRuntime extends "res://combat/native_combat_runtime.gd":
	var reject_start := false
	var reject_commands := false
	func start(new_epoch: int, bootstrap: Dictionary, session_state: Dictionary) -> String:
		return "testRejected" if reject_start else super.start(new_epoch, bootstrap, session_state)
	func apply_batch(batch_epoch: int, commands: Array, session_patch: Dictionary, ack_event: int) -> String:
		if reject_commands and not commands.is_empty(): return "testRejected"
		return super.apply_batch(batch_epoch, commands, session_patch, ack_event)
## Battlefield whose per-stage runtimes are RejectingRuntime.
## A stage entry resets the scene, which creates the runtime that starts it.
class RejectingMain extends "res://main.gd":
	var reject_start := false
	func _new_native_combat() -> NativeCombatRuntime:
		var runtime := RejectingRuntime.new()
		# main's member initializer creates the first runtime before this field.
		runtime.reject_start = reject_start == true
		return runtime
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	var controller_script = load("res://session/session_controller.gd")
	for path in ["res://app/app_lifecycle.gd", "res://session/standalone.gd"]:
		check(load(path).get_base_script() == controller_script, path + " directly shares session orchestration")
	var controller = controller_script.new()
	var names: Array = controller.get_property_list().map(func(property): return property.name)
	for property in ["fixture", "status", "panel", "turret_button", "wave_button", "content_enabled", "next_id"]:
		check(not names.has(property), "shared controller excludes development state: " + property)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	controller.scene = scene
	scene.session_controller = controller
	scene.add_child(controller)
	controller.set_process(false)
	var directory := OS.get_environment("TMPDIR").path_join("rune-controller-" + str(Time.get_ticks_usec()))
	check(directory.is_absolute_path(), "isolated checkpoint directory")
	controller.checkpoint = load("res://session/session_checkpoint.gd").new(directory)
	check(controller.catalog.load_catalog(), "content catalog loads")
	controller.enter_stage(0)
	var map: Dictionary = controller.stage_source(0).map
	var index: int = map.tiles.find("build")
	controller.board_tap(Vector2i(index % int(map.columns), index / int(map.columns)))
	controller.build_selected()
	check(scene.combat_runtime.turrets.size() == 1, "shared selected tile builds through domain")
	controller.start_wave()
	scene.combat_runtime.advance_session(0.1)
	controller._process(0.1)
	check(controller.run_domain.event_ack == scene.combat_runtime.event_id, "process collects and acknowledges without diagnostic label")
	controller.toggle_pause()
	var clock_before: float = scene.combat_runtime.clock
	scene.combat_runtime.advance_session(1.0)
	check(scene.combat_runtime.clock == clock_before, "shared pause preserves clock")
	check(controller.checkpoint.save_session(controller) == OK, "common session saves without fixture fields")
	var epoch_before: int = controller.epoch
	check(controller.checkpoint.load_session(controller) == OK and controller.epoch > epoch_before, "common checkpoint restores content session")
	check(scene.combat_runtime.session.paused and scene.combat_runtime.turrets.size() == 1, "restore retains towers and waits for resume")
	controller.checkpoint.store.clear()
	scene.queue_free()
	for i in range(3): await process_frame
	await _rejection_checks(controller_script, directory + "-rejection")
	if failures.is_empty(): print("PASS shared session controller: UI-free command/ACK, pause, content checkpoint, runtime rejection and sibling entry points")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

## Runtime rejections surface; the run never runs ahead of combat.
func _rejection_checks(controller_script, directory: String) -> void:
	var scene := RejectingMain.new()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var controller = controller_script.new()
	controller.scene = scene
	scene.session_controller = controller
	scene.add_child(controller)
	controller.set_process(false)
	controller.checkpoint = load("res://session/session_checkpoint.gd").new(directory)
	check(controller.catalog.load_catalog() and controller.enter_stage(0), "stage starts on an accepting runtime")
	var map: Dictionary = controller.stage_source(0).map
	var index: int = map.tiles.find("build")
	controller.board_tap(Vector2i(index % int(map.columns), index / int(map.columns)))
	var runtime = scene.combat_runtime
	var run_before: Dictionary = controller.run_domain.state.duplicate(true)
	runtime.reject_commands = true
	check(not controller.apply_run_command({"kind":"build","x":controller.selected.x,"y":controller.selected.y,"type":controller.turret_type}), "rejected build reports failure")
	check(controller.run_domain.state == run_before and runtime.turrets.is_empty(), "rejected build keeps run state (gold, turrets) with combat")
	check(controller.checkpoint.message.contains("testRejected"), "rejected build explains the runtime reason")
	runtime.reject_commands = false
	check(controller.apply_run_command({"kind":"build","x":controller.selected.x,"y":controller.selected.y,"type":controller.turret_type}) and runtime.turrets.size() == 1, "accepted build after a rejection")
	scene.reject_start = true
	check(not controller.enter_stage(0) and controller.checkpoint.message.contains("testRejected"), "rejected start fails stage entry with reason")
	controller.checkpoint.store.clear()
	scene.queue_free()
	for i in range(3): await process_frame
