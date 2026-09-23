extends SceneTree

## 실제 앱 경로의 격리된 시각 검수. frost-review 프로젝트에서만 실행한다.
var output := "/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/charge-mist-concept/integration"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func capture(name: String) -> void:
	if "--detail-only" in OS.get_cmdline_user_args() and not name.begins_with("detail") and name != "app-4x": return
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	check(OS.get_user_data_dir().contains("RuneNexus-Frost-Charge-Integration"), "isolated user directory")
	if not failures.is_empty():
		quit(1)
		return
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var app = scene._standalone_session
	check(app != null and not app.startup_blocked, "formal app started")
	if app == null or app.startup_blocked:
		quit(1)
		return
	scene.set_process(false)
	app.set_process(false)
	app.progression_inputs["clearedStageNumbers"] = range(1, 16)
	app.progression_inputs["unlockedStageCount"] = 15
	check(app.start_stage(0), "stage started")
	app.run_domain.state.gold = 100000
	var source: Dictionary = app.stage_source(0)
	var tiles: Array[Vector2i] = []
	for index in range(source.map.tiles.size()):
		if source.map.tiles[index] == "build":
			tiles.append(Vector2i(index % int(source.map.columns), floori(float(index) / int(source.map.columns))))
	var types := ["frost", "cannon", "frost", "arrow"]
	for index in range(types.size()):
		app.turret_type = types[index]
		app.board_tap(tiles[index])
		app.build_selected()
	app.command()
	scene._apply_frame(scene._native_combat_base_frame)
	app._process(0.0)
	check(scene.turrets.size() == 4, "four actual constructed models")
	var frost: Dictionary = {}
	for entry: Dictionary in scene.turrets.values():
		if entry.type == "frost":
			frost = entry
			break
	check(not frost.is_empty(), "frost model instantiated")
	if frost.is_empty():
		quit(1)
		return
	check(frost.head != null and frost.barrel != null and frost.muzzle != null, "rig markers preserved")
	app.board_tap(tiles[0])
	app._process(0.0)
	scene.options.camera = "angled"
	scene._apply_options()
	if scene.camera_transition and scene.camera_transition.is_running(): await scene.camera_transition.finished
	await capture("app-angled-selected")
	app.board_tap(Vector2i(-1, -1))
	scene.options.camera = "drone"
	scene._apply_options()
	if scene.camera_transition and scene.camera_transition.is_running(): await scene.camera_transition.finished
	await capture("app-drone")
	# 같은 본게임 조명·실제 에셋을 근접 촬영해 세부를 비교한다.
	app.hud.hide()
	var center: Vector3 = frost.root.global_position + Vector3(0, 0.32, 0)
	scene.camera.h_offset = 0
	scene.camera.v_offset = 0
	scene.camera.size = 2.4
	scene.camera.near = 0.05
	scene.camera.far = 100.0
	scene.camera.position = center + Vector3(1.8, 2.3, 3.0)
	scene.camera.look_at(center)
	await capture("model-hero")
	scene.camera.position = center + Vector3(0, 4, 0.001)
	scene.camera.look_at(center)
	await capture("model-top")
	# Actual application and native combat, with deterministic manual frame stepping.
	app.hud.show()
	scene.options.camera = "angled"
	scene._apply_options()
	if scene.camera_transition and scene.camera_transition.is_running(): await scene.camera_transition.finished
	await capture("ready-waiting")
	app.start_wave()
	var runtime = scene._native_combat
	var fired := false
	var slowed := false
	var first_shot := -1
	var video_frame := 0
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	for tick in range(900):
		runtime.advance_session(1.0 / 24.0)
		app.command()
		scene._apply_frame(scene._native_combat_base_frame)
		app._process(0.0)
		for turret in runtime.turrets.values():
			if turret.statInput.definition.type == "frost" and turret.shotSequence > 0:
				fired = true
				if first_shot < 0: first_shot = tick
		for enemy in runtime.enemies.values():
			if not enemy.get("slowInstances", []).is_empty(): slowed = true
		if fired:
			await process_frame
			await RenderingServer.frame_post_draw
			if "--detail-only" not in OS.get_cmdline_user_args(): root.get_texture().get_image().save_png(output.path_join("frames/%04d.png" % video_frame))
			video_frame += 1
			var elapsed := tick - first_shot
			if elapsed == 10:
				await capture("app-release-slowed")
				var time_before: float = runtime.clock
				app.command([], {"paused":true})
				for i in 30: runtime.advance_session(1.0/24.0)
				scene._apply_frame(scene._native_combat_base_frame)
				check(runtime.clock == time_before, "pause freezes combat and effect clock")
				await capture("app-paused-release")
				app.command([], {"paused":false})
			if elapsed == 38: await capture("app-charging")
			if elapsed >= (12 if "--detail-only" in OS.get_cmdline_user_args() else 143): break
	check(fired, "frost actually fired")
	check(slowed, "actual enemies slowed")
	# Close-up uses the same game lights and current native state; no conceptual tint.
	app.hud.hide()
	center = frost.root.global_position + Vector3(0, .20, 0)
	scene.camera.h_offset = 0
	scene.camera.v_offset = 0
	scene.camera.size = 4.2
	scene.camera.position = center + Vector3(1.8, 2.8, 3.8)
	scene.camera.look_at(center)
	var captured_release := false
	var captured_charge := false
	for tick in 500:
		runtime.advance_session(1.0/60.0)
		app.command()
		scene._apply_frame(scene._native_combat_base_frame)
		var effect = frost.frost_effect
		if not captured_release and effect.mist.visible and float(effect.mist_material.get_shader_parameter("age")) > .3:
			closeup(scene, frost)
			await capture("detail-release")
			captured_release = true
		if not captured_charge and effect.charge > .5 and effect.charge < .65:
			closeup(scene, frost)
			await capture("detail-charging")
			captured_charge = true
		if captured_release and captured_charge: break
	check(captured_release and captured_charge, "detail charge and release states observed")
	var before: float = runtime.clock
	app.command([], {"speed":4.0})
	runtime.advance_session(.05)
	app.command()
	scene._apply_frame(scene._native_combat_base_frame)
	check(is_equal_approx(runtime.clock-before,.2), "4x combat-clock advance")
	closeup(scene, frost)
	await capture("detail-4x")
	app.hud.show()
	scene._apply_options()
	if scene.camera_transition and scene.camera_transition.is_running(): await scene.camera_transition.finished
	app._process(0.0)
	await capture("app-4x")
	app.command([], {"paused":true})
	var report := {"engine":Engine.get_version_info(), "renderer":RenderingServer.get_current_rendering_method(), "user_directory":OS.get_user_data_dir(), "asset_sha256":FileAccess.get_sha256("res://assets/turrets/frost.glb"), "fired":fired,"slowed_observed":slowed,"video_frames":video_frame,"failures":failures}
	var file := FileAccess.open(output.path_join("detail-report.json" if "--detail-only" in OS.get_cmdline_user_args() else "report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("FROST_INTEGRATION ", JSON.stringify(report))
	scene.queue_free()
	for i in 4: await process_frame
	quit(0 if failures.is_empty() else 1)

func closeup(scene, frost: Dictionary) -> void:
	if scene.camera_transition and scene.camera_transition.is_running(): scene.camera_transition.kill()
	var center: Vector3 = frost.root.global_position + Vector3(0, .18, 0)
	scene.camera.h_offset = 0
	scene.camera.v_offset = 0
	scene.camera.size = 2.8
	scene.camera.near = .05
	scene.camera.far = 100
	scene.camera.position = center + Vector3(1.8, 2.3, 3.0)
	scene.camera.look_at(center)
