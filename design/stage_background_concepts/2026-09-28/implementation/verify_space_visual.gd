extends SceneTree
const OUT = "/Users/sejin/Documents/Codex/RuneNexus/design/stage_background_concepts/2026-09-28/implementation"
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
	for stage in [0,5,10]:
		app.enter_stage(stage)
		app._refresh_ui()
		await settle()
		scene._apply_options()
		await capture("chapter%d-drone25" % (stage/5+1))
		assert(scene._world_environment.background_mode == Environment.BG_CANVAS)
		assert(scene._world_environment.background_canvas_max_layer == -1)
		assert(scene.get_node("CombatSpaceBackground/Nebula").texture.resource_path == "res://assets/backgrounds/combat_space_nebula.png")
	app.enter_stage(0)
	app._refresh_ui()
	scene.options.camera = "angled"
	scene._apply_options()
	await capture("chapter1-fixed")
	scene.options.camera = "drone"
	scene._apply_options()
	await capture("chapter1-drone25-return")
	app.in_lobby = true
	app._refresh_ui()
	await capture("lobby-preserved")
	scene.world.visible = false
	layer.hide()
	await capture("background-time0")
	await create_timer(3.0).timeout
	await capture("background-time3")
	print("PASS common background, actual HUD, cameras, chapters 1/2/3, isolated save=",app.checkpoint.base_directory)
	scene.queue_free()
	for i in range(8): await process_frame
	quit()
