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
	check(scene._session_frame_delta(300.0,true,1,1000000)==0.0,"first activation discards suspended delta")
	check(scene._session_frame_delta(0.016,true,1,1016000)==0.016,"active frame uses monotonic elapsed time")
	check(scene._session_frame_delta(600.0,true,2,9016000)==0.0,"resume generation discards delta even without inactive tick")
	# Use the production default Time.get_ticks_usec path, not a synthetic clock.
	# Even a deliberately capped engine delta must retain the full active stall.
	scene._session_frame_clock.reset()
	check(scene._session_frame_delta(0.1,true,3) == 0.0,"real monotonic sampler starts without catch-up")
	OS.delay_msec(300)
	check(scene._session_frame_delta(0.1,true,3) >= 0.29,"real 300ms stall survives fake capped engine delta")
	var host_revision: int = scene._session_host_revision
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not scene._session_has_focus,"focus loss closes actual host gate")
	check(scene._session_frame_delta(600.0,scene._session_has_focus,scene._session_host_revision) == 0.0,"focus loss contributes no elapsed time")
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(scene._session_suspended,"application pause closes suspension gate")
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(scene._session_has_focus and not scene._session_suspended and scene._session_host_revision > host_revision,"resume restores host gate and changes generation")
	check(scene._session_frame_delta(600.0,true,scene._session_host_revision) == 0.0,"actual resumed generation rejects offline delta")
	_verify_control_boundaries(scene)
	_verify_host_boundaries(scene)
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

func _verify_control_boundaries(scene) -> void:
	var runtime = scene._native_combat
	var real_clock: Callable = scene._session_now_usec
	var time := {"usec":1000000}
	scene._session_now_usec = func(): return time.usec
	scene._session_frame_clock.reset()
	scene.set_process(true)
	scene._session_frame_delta(0.0,true,scene._session_host_revision)
	time.usec = 1050000
	var speed_packet := {"epoch":runtime.epoch,"sequence":runtime.sequence+1,"session":{"speed":4.0}}
	runtime.process_command(speed_packet, false)
	check(is_equal_approx(runtime.simulation_debt,0.05) and runtime.simulation_tick == 0,"speed command accrues preceding half-interval at old 1x without stepping")
	check(runtime.sequence == int(speed_packet.sequence),"accrual-only boundary cannot recursively consume command sequence")
	time.usec = 1100000
	var elapsed: float = scene._session_frame_delta(0.1,true,scene._session_host_revision)
	runtime.advance_session(elapsed)
	check(runtime.simulation_tick == 15 and is_equal_approx(runtime.clock,0.25) and is_equal_approx(runtime.wall_elapsed,0.1),"half interval 1x plus half interval 4x produces exactly 0.25 game seconds")
	var sampled: int = scene._session_frame_clock.sampled_usec
	time.usec = 1125000
	runtime.process_command(speed_packet, false)
	check(scene._session_frame_clock.sampled_usec == sampled and runtime.simulation_tick == 15 and is_equal_approx(runtime.wall_elapsed,0.1),"duplicate ACK does not sample, accrue, step or rebase host time")
	time.usec = 1150000
	runtime.process_command({"epoch":runtime.epoch,"sequence":runtime.sequence+1,"session":{"paused":true}},false)
	check(is_equal_approx(runtime.simulation_debt,0.2) and runtime.simulation_tick == 15,"pause retains active interval at old speed without advancing combat")
	time.usec = 901150000
	runtime.process_command({"epoch":runtime.epoch,"sequence":runtime.sequence+1,"session":{"paused":false}},false)
	time.usec += 50000
	elapsed = scene._session_frame_delta(900.0,true,scene._session_host_revision)
	runtime.advance_session(elapsed)
	check(is_equal_approx(elapsed,0.05) and runtime.simulation_tick == 39 and is_equal_approx(runtime.wall_elapsed,0.2),"pause/resume between renders excludes 900 offline seconds and retains active time")
	var next_tick: int = runtime.simulation_tick + 1
	var boundary := func():
		if runtime.simulation_tick != next_tick: return
		time.usec += 1000000
		runtime.process_command({"epoch":runtime.epoch,"sequence":runtime.sequence+1,"session":{"speed":1.0}},false)
	runtime.step_completed.connect(boundary)
	sampled = scene._session_frame_clock.sampled_usec
	var wall: float = runtime.wall_elapsed
	runtime.advance_session(1.0/60.0)
	runtime.step_completed.disconnect(boundary)
	check(runtime.simulation_tick == 43 and scene._session_frame_clock.sampled_usec == sampled and is_equal_approx(runtime.wall_elapsed,wall+1.0/60.0),"game-timestamped callback skips physical sampling and rebase inside accepted frame")
	# A retained old runtime cannot charge time into its scene replacement.
	var replacement = scene._new_native_combat()
	scene._native_combat = replacement
	sampled = scene._session_frame_clock.sampled_usec
	time.usec += 1000000
	runtime.process_command({"epoch":runtime.epoch,"sequence":runtime.sequence+1,"session":{"speed":2.0}},false)
	check(replacement.simulation_debt == 0.0 and replacement.wall_elapsed == 0.0 and scene._session_frame_clock.sampled_usec == sampled,"retired runtime control signals cannot accrue or rebase replacement clock")
	scene._native_combat = runtime
	scene.set_process(false)
	scene._session_now_usec = real_clock
	scene._session_frame_clock.reset()

func _verify_host_boundaries(scene) -> void:
	var original_runtime = scene._native_combat
	var real_clock: Callable = scene._session_now_usec
	var time := {"usec":1000000}
	scene._session_now_usec = func(): return time.usec
	scene.set_process(true)
	var focus_out := MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT
	var focus_in := MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN
	var paused := MainLoop.NOTIFICATION_APPLICATION_PAUSED
	var resumed := MainLoop.NOTIFICATION_APPLICATION_RESUMED
	for outgoing in [[focus_out], [paused], [focus_out, paused], [paused, focus_out]]:
		for incoming in [[focus_in, resumed], [resumed, focus_in]]:
			for child_pause in [false, true]:
				for speed in [1.0, 4.0]:
					var runtime = scene._new_native_combat()
					scene._native_combat = runtime
					scene._session_has_focus = true
					scene._session_suspended = false
					scene._session_frame_clock.reset()
					time.usec = 1000000
					runtime.process_command({"epoch":1,"sequence":0,"session":{"clock":"godot","phase":"wave","speed":speed},"bootstrap":{}}, false)
					scene._session_frame_delta(0.0,true,scene._session_host_revision)
					time.usec = 1500000
					for notification in outgoing:
						scene._notification(notification)
						if child_pause:
							runtime.process_command({"epoch":1,"sequence":runtime.sequence+1,"session":{"paused":true}},false)
						# Repeated and second-gate notifications at later physical
						# timestamps must not spend debt or accept background time.
						time.usec += 100000
						scene._notification(notification)
					check(is_equal_approx(runtime.simulation_debt,0.5*speed) and is_equal_approx(runtime.wall_elapsed,0.5),"host close preserves exactly the pre-suspend interval")
					check(runtime.simulation_tick == 0 and runtime.event_id == 0 and runtime.sequence == (outgoing.size() if child_pause else 0),"host notifications accrue only, without combat/events/nested ACKs")
					time.usec = 901500000
					for notification in incoming: scene._notification(notification)
					if child_pause:
						runtime.process_command({"epoch":1,"sequence":runtime.sequence+1,"session":{"paused":false}},false)
					time.usec += 25000
					for notification in incoming: scene._notification(notification)
					time.usec += 25000
					var elapsed: float = scene._session_frame_delta(900.0,true,scene._session_host_revision)
					runtime.advance_session(elapsed)
					while runtime.simulation_debt + 0.0000000001 >= 1.0/60.0: runtime.advance_session(0.0)
					check(is_equal_approx(elapsed,0.05) and is_equal_approx(runtime.clock,0.55*speed) and is_equal_approx(runtime.wall_elapsed,0.55),"both host notification orders exclude 900 seconds and preserve active prefix/suffix at 1x/4x")
	scene._native_combat = original_runtime
	scene._session_now_usec = real_clock
	scene._session_frame_clock.reset()
	scene.set_process(false)
