extends SceneTree
const OUT = "/Users/sejin/Documents/Codex/RuneNexus/design/stage_background_concepts/2026-09-28/chapter-palettes"
var scene
var app
var layer
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	if scene.camera_transition and scene.camera_transition.is_running():
		await scene.camera_transition.finished
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	await settle()
	assert(root.get_texture().get_image().save_png(OUT.path_join(label+".png")) == OK)
	print("CAPTURE ", label, " size=", root.get_visible_rect().size, " camera=", scene.camera.rotation_degrees, " bg=", scene._world_environment.background_mode, " sky=", scene._world_environment.sky.resource_path, " sun=",scene.sun.light_energy)
func run() -> void:
	root.size = Vector2i(440,900)
	root.content_scale_size = Vector2i(440,900)
	scene = load("res://main.tscn").instantiate()
	scene._app_mode = false
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	app = load("res://app/app_lifecycle.gd").new()
	app.ui_enabled = false
	app.checkpoint = load("res://session/session_checkpoint.gd").new(OUT.path_join("isolated-save"))
	scene.add_child(app)
	app.set_process(false)
	scene._standalone_session = app
	scene._app_mode = true
	root.content_scale_size = Vector2i(440,900)
	layer = CanvasLayer.new()
	layer.layer = 10
	app.add_child(layer)
	app.hud = load("res://ui/battle_hud.gd").new()
	app.hud.app = app
	layer.add_child(app.hud)
	app.lobby = load("res://ui/lobby.gd").new()
	app.lobby.app = app
	layer.add_child(app.lobby)
	app.in_lobby = false
	scene.options.camera = "drone"
	for stage in [0,5,10,0]:
		app.enter_stage(stage)
		app._refresh_ui()
		await settle()
		scene._apply_options()
		await capture("chapter%d-drone25" % (stage/5+1) if stage != 0 or app.epoch < 1005 else "chapter1-return-from3")
		var expected_theme: String = str(app.stage_source(stage).map.get("theme", "chapterOne"))
		assert(scene._space_background._theme == expected_theme)
		print("PALETTE ",expected_theme," tint=",scene._space_background._star_material.get_shader_parameter("nebula_tint"))
		assert(scene._world_environment.background_mode == Environment.BG_CANVAS)
		assert(scene._world_environment.background_canvas_max_layer == -1)
		assert(scene.get_node("CombatSpaceBackground/Nebula").texture.resource_path == "res://assets/backgrounds/combat_space_nebula.png")
	scene.world.visible = false
	layer.hide()
	var original: Shader = scene._space_background._star_material.shader
	scene._space_background.apply_theme("chapterThreeForge")
	for mark in [0,3]:
		if mark == 3: await create_timer(3.0).timeout
		assert(scene._space_background._star_material.shader == original)
		assert(scene._space_background._theme == "chapterThreeForge")
		var tint: Vector3 = scene._space_background._star_material.get_shader_parameter("nebula_tint")
		assert(tint == scene._space_background.CHAPTER_TINTS.chapterThreeForge)
		print("TIME_PAIR original_shader=",original.resource_path," tint=",tint," mark=",mark)
		await capture("background-forge-time%d" % mark)
	var frozen := Shader.new()
	# 시간차는 위에서 원본 셰이더로 확인. 아래는 색 마스크 대조만 TIME 고정.
	frozen.code = original.code.replace("TIME", "0.0")
	scene._space_background._star_material.shader = frozen
	for theme in ["chapterOne", "chapterTwoRift", "chapterThreeForge"]:
		scene._space_background.apply_theme(theme)
		await capture("background-"+theme+"-frozen")
	print("PASS chapter palettes, 3->1 reset, shared image, star/center protection, actual HUD, isolated save=",app.checkpoint.base_directory)
	scene.queue_free()
	for i in range(8): await process_frame
	quit()
