extends SceneTree
var failures: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2 or not arguments[0] in ["write", "read"] or not arguments[1].is_absolute_path():
		push_error("Expected write/read and an isolated absolute save directory")
		quit(1)
		return
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = load("res://session/standalone.gd").new()
	app.content_enabled = false # Explicit legacy save regression, never the default content path.
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	app.checkpoint = load("res://session/session_checkpoint.gd").new(arguments[1])
	if arguments[0] == "write":
		var map: Dictionary = app.fixture.stages[0].map
		var index: int = map.tiles.find("build")
		app.board_tap(Vector2i(index % int(map.columns), floori(float(index)/int(map.columns))))
		app.build_selected()
		app.start_wave()
		for i in range(180): scene._native_combat.advance_session(1.0/60.0)
		check(app.checkpoint.save_session(app) == OK, "write v2 checkpoint before process exit")
	else:
		var saved = app.checkpoint.store.load_save()
		check(saved != null, "previous process save exists")
		if saved != null:
			check(app.checkpoint.load_session(app) == OK, "new process loads v2 checkpoint")
			var runtime = scene._native_combat
			check(runtime.session.paused and runtime.clock == 0, "restored process waits for resume")
			check(runtime.enemies.size() == saved.activeRun.enemies.size(), "enemy count")
			check(runtime.wave.snapshot().spawnQueue == saved.activeRun.spawnQueue, "remaining spawn schedule")
			for i in range(runtime.enemies.size()):
				var enemy: Dictionary = runtime.enemies.values()[i]
				check(is_equal_approx(enemy.distanceTravelled, saved.activeRun.enemies[i].distanceTravelled) and is_equal_approx(enemy.hp, saved.activeRun.enemies[i].hp), "enemy progress and HP")
			check(runtime.turrets.size() == saved.activeRun.turrets.size(), "turret layout")
			check(is_equal_approx(runtime.turrets.values()[0].cooldown, saved.activeRun.turrets[0].cooldown), "turret cooldown")
			app.toggle_pause()
			runtime.advance_session(0.1)
			check(runtime.clock > 0, "restored process advances without Flutter")
			scene._apply_frame(scene._native_combat_base_frame)
			app._process(0)
			if DisplayServer.get_name() != "headless":
				for i in range(8): await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../captures/save-restart.png"))
	scene.queue_free()
	for i in range(3): await process_frame
	print("SESSION_PROCESS_RESTART mode=", arguments[0], " failures=", failures)
	quit(0 if failures.is_empty() else 1)
