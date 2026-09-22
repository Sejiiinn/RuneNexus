extends SceneTree
## Shared orchestration must run without development UI or a fixture payload.
var failures: Array = []
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
	scene._standalone_session = controller
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
	check(scene._native_combat.turrets.size() == 1, "shared selected tile builds through domain")
	controller.start_wave()
	scene._native_combat.advance_session(0.1)
	controller._process(0.1)
	check(controller.run_domain.event_ack == scene._native_combat.event_id, "process collects and acknowledges without diagnostic label")
	controller.toggle_pause()
	var clock_before: float = scene._native_combat.clock
	scene._native_combat.advance_session(1.0)
	check(scene._native_combat.clock == clock_before, "shared pause preserves clock")
	check(controller.checkpoint.save_session(controller) == OK, "common session saves without fixture fields")
	var epoch_before: int = controller.epoch
	check(controller.checkpoint.load_session(controller) == OK and controller.epoch > epoch_before, "common checkpoint restores content session")
	check(scene._native_combat.session.paused and scene._native_combat.turrets.size() == 1, "restore retains towers and waits for resume")
	controller.checkpoint.store.clear()
	scene.queue_free()
	for i in range(3): await process_frame
	if failures.is_empty(): print("PASS shared session controller: UI-free command/ACK, pause, content checkpoint and sibling entry points")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
