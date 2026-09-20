extends SceneTree
var failures: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = load("res://session/standalone.gd").new()
	app.content_enabled = false # Explicit legacy save regression, never the default content path.
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	var runtime = scene._native_combat
	check(scene._session_frame_delta(300.0,true,1)==0.0,"first activation discards suspended delta")
	check(scene._session_frame_delta(0.016,true,1)==0.016,"active frame uses unmodified delta")
	check(scene._session_frame_delta(600.0,true,2)==0.0,"resume generation discards delta even without inactive tick")
	check(runtime.native_session() and scene._scene_epoch == app.epoch,"standalone entry owns session")
	for stage in [0,5,10,14,0]:
		app.enter_stage(stage)
		check(not scene._current_map.is_empty(),"stage %d terrain" % (stage+1))
		var map: Dictionary = app.fixture.stages[stage].map
		var index: int = map.tiles.find("build")
		var tile := Vector2i(index % int(map.columns),floori(float(index)/int(map.columns)))
		var point: Vector2 = scene.camera.unproject_position(scene.world.to_global(Vector3(tile.x+0.5-scene.columns/2.0,0,tile.y+0.5-scene.rows/2.0)))
		check(scene._session_input.board_position(point)==tile,"native camera ray stage %d" % (stage+1))
		scene._session_input.tap(point)
		app.build_selected()
		check(scene._native_combat.turrets.size()==1,"native tile selection and construction")
	# Real touch must be emitted once even with OS-emulated mouse delivery.
	var input = scene._session_input
	var point: Vector2 = scene.camera.unproject_position(scene.world.to_global(Vector3(-1.5,0,-4.5)))
	var before_id: int = scene._native_combat.event_id
	scene._native_combat_base_frame.rewardViewport = null
	for pressed in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = pressed
		input.handle(touch)
		var mouse := InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.pressed = pressed
		input.handle(mouse)
	check(scene._native_combat.event_id == before_id+1,"touch plus emulated mouse emits one tap; null reward viewport allowed")
	before_id = scene._native_combat.event_id
	for index in [0,1]:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.position = point+Vector2(index*30,0)
		touch.pressed = true
		input.handle(touch)
	for index in [1,0]:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.position = point+Vector2(index*30,0)
		touch.pressed = false
		input.handle(touch)
	check(scene._native_combat.event_id == before_id,"two-finger release cannot turn into board tap")
	app.start_wave()
	runtime = scene._native_combat
	for i in range(180):
		runtime.advance_session(1.0/60.0)
		scene._apply_frame(scene._native_combat_base_frame)
	check(runtime.clock > 2.9 and not runtime.enemies.is_empty(),"combat without Flutter dt")
	check(runtime.turrets.values()[0].shotSequence>0,"standalone placed turret attacks")
	var before: float = runtime.clock
	app.toggle_pause()
	runtime.advance_session(1.0)
	check(runtime.clock == before,"standalone pause")
	app.toggle_pause()
	app.toggle_speed()
	runtime.advance_session(0.25)
	check(is_equal_approx(runtime.clock,before+1.0),"standalone resume/speed")
	var saved_directory: String = OS.get_environment("TMPDIR").path_join("rune-session-restart-" + str(OS.get_process_id()))
	check(saved_directory.is_absolute_path(), "isolated checkpoint directory")
	app.checkpoint = load("res://session/session_checkpoint.gd").new(saved_directory)
	check(app.checkpoint.save_session(app) == OK, "native session writes compatible v2 checkpoint")
	var checkpoint: Dictionary = app.checkpoint.store.load_save()
	var old_epoch: int = app.epoch
	app.exit_stage()
	app.queue_free()
	await process_frame
	app = load("res://session/standalone.gd").new()
	app.content_enabled = false # Explicit legacy save regression, never the default content path.
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	app.epoch = old_epoch + 2
	app.checkpoint = load("res://session/session_checkpoint.gd").new(saved_directory)
	check(app.checkpoint.load_session(app) == OK, "fresh application restores checkpoint")
	runtime = scene._native_combat
	check(runtime.enemies.size() == checkpoint.activeRun.enemies.size(), "restored active enemies")
	check(runtime.wave.snapshot().spawnQueue == checkpoint.activeRun.spawnQueue, "remaining spawn delays not replayed")
	check(runtime.turrets.size() == checkpoint.activeRun.turrets.size(), "restored tower layout")
	check(is_equal_approx(runtime.turrets.values()[0].cooldown, checkpoint.activeRun.turrets[0].cooldown), "restored tower cooldown")
	check(is_equal_approx(runtime.defense.hp, checkpoint.activeRun.nexusHp), "restored core durability")
	check(runtime.session.paused and runtime.clock == 0 and runtime.epoch == app.epoch and runtime.events.all(func(event): return event.kind == "waveStarted"), "restore waits for explicit resume with fresh event epoch")
	app.toggle_pause()
	runtime.advance_session(0.1)
	check(runtime.clock > 0, "restored session continues without Flutter")
	var before_rejected_epoch: int = app.epoch
	checkpoint.activeRun.turrets[0].type = "cannon"
	app.checkpoint.store.save_save(checkpoint)
	check(app.checkpoint.load_session(app) == ERR_UNAVAILABLE and app.epoch == before_rejected_epoch, "unsupported fixture save never replaces active scene")
	app.checkpoint.store.clear()
	DirAccess.remove_absolute(saved_directory.path_join("saves/guest"))
	DirAccess.remove_absolute(saved_directory.path_join("saves"))
	DirAccess.remove_absolute(saved_directory)
	scene._apply_frame(scene._native_combat_base_frame)
	app._process(0)
	if DisplayServer.get_name() != "headless":
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../captures/standalone-session.png"))
	app.exit_stage()
	check(not scene._native_combat.active and scene._native_combat.events.is_empty(),"exit drops active clock and events")
	app.enter_stage(0)
	check(scene._native_combat.clock == 0 and scene._native_combat.events.is_empty(),"reentry fresh state")
	scene.queue_free()
	for i in range(3): await process_frame
	if failures.is_empty(): print("PASS standalone stages 1/6/11/15, ray projection, selection/build, combat, pause/resume/4x, exit/reentry, v2 checkpoint/restart")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
