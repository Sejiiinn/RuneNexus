extends SceneTree
## Real main scene and app HUD in an isolated offline guest run (no network or
## production saves): build a support core through the HUD, then capture the
## build step, the placed core with its connections and a strengthened turret.
## Godot --path build/godot/project -s <this file> -- <absolute output dir>
class OfflineApp extends "res://app/app_lifecycle.gd":
	func _detached_debug_lifecycle() -> bool: return true
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Progression = preload("res://content/stage_progression.gd")
const SupportCore = preload("res://app/support_core_rules.gd")
const STAGE_ID := 13
var scene
var app
var directory := ""

func _initialize() -> void: run.call_deferred()

func capture(label: String) -> void:
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("SUPPORT_CORE_CAPTURE ", label)

func present() -> void:
	app.refresh_selection()
	scene.apply_frame(scene.combat_base_frame)
	app.hud.refresh()

func tap(tile: Vector2i) -> void:
	app.board_tap(tile)
	present()

func build_tile(map: Dictionary, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < int(map.columns) and y < int(map.rows) and map.tiles[y * int(map.columns) + x] == "build"

func run() -> void:
	var args := OS.get_cmdline_user_args()
	directory = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../support-core-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(440, 900)
	scene = load("res://main.gd").new()
	scene.app_mode = true
	root.add_child(scene)
	var original = scene.session_controller
	if original.services != null: original.services.free()
	original.services = null
	original.free()
	app = OfflineApp.new()
	scene.session_controller = app
	scene.add_child(app)
	var services = app.services
	app.services = null
	if services != null: services.free()
	app.checkpoint = Checkpoint.new(directory.path_join("isolated-save"))
	app.checkpoint.allow_progression_only = true
	if not app.retry_load(): push_error("offline startup"); quit(1); return
	print("SUPPORT_CORE_PROGRESS loaded")
	var order: Array = Progression.ordered_ids()
	app.progression_inputs = {"growthVersion":1, "progressionVersion":Progression.VERSION, "clearedStageNumbers":order.slice(0, order.find(STAGE_ID)), "coreCombatSkill":null, "turretModules":{"tickets":0, "items":[]}}
	var index: int = app.catalog.stage_index(STAGE_ID)
	print("SUPPORT_CORE_PROGRESS starting ", index)
	if not await app.start_stage(index): push_error("start stage: " + app.checkpoint.message); quit(1); return
	var map: Dictionary = app.catalog.stage_map(index)
	var core := Vector2i(-1, -1)
	for y in range(int(map.rows)):
		for x in range(int(map.columns)):
			if core.x < 0 and build_tile(map, x, y) and build_tile(map, x + 1, y) and build_tile(map, x, y + 1):
				core = Vector2i(x, y)
	if core.x < 0: push_error("no core tile"); quit(1); return
	app.run_domain.state.gold = 3000 # Test budget; every build still pays its actual cost.
	app.run_domain.state.gemInventory = {"range":1, "chain":2, "attackSpeed":1}
	for spec in [[core + Vector2i(1, 0), "arrow"], [core + Vector2i(0, 1), "cannon"], [core + Vector2i(-1, 0), "magic"], [core + Vector2i(0, -1), "frost"]]:
		if not build_tile(map, spec[0].x, spec[0].y): continue
		app.turret_type = spec[1]
		tap(spec[0])
		app.build_selected()
	print("SUPPORT_CORE_SETUP stage=", STAGE_ID, " core=", core, " turrets=", app.run_domain.state.turrets.size())
	# Build step: empty tile and support core picked; the default gem (most copies: chain) is preselected.
	app.hud.main_tab = "turrets"
	app.turret_type = "supportCore"
	tap(core)
	present()
	await capture("1-build-gem-choice")
	print("SUPPORT_CORE_DEFAULT_GEM ", app.hud.support_core_panel.chosen(app.run_domain.state))
	# A second tap on the picker builds, like a turret.
	var picker: Button = app.hud.find_child("Picker_supportCore", true, false)
	picker.pressed.emit()
	present()
	var built := not SupportCore.at(app.run_domain.state, core.x, core.y).is_empty()
	print("SUPPORT_CORE_BUILT ", built, " gold=", app.run_domain.state.gold, " gems=", app.run_domain.state.gemInventory, " links=", SupportCore.connections(app.run_domain.state).size())
	# Placed core selected: effect, connections, demolition.
	tap(core)
	await capture("2-core-detail")
	# Strengthened turret selected: its connection chip.
	tap(core + Vector2i(1, 0))
	await capture("3-turret-detail")
	# Field only, drone camera.
	app.hud.main_tab = "closed"
	tap(Vector2i(-1, -1))
	scene.options["camera"] = "drone"
	scene._battlefield_camera.stop_transition(); scene.camera_mode = ""
	present()
	await capture("4-field-drone")
	scene.options["camera"] = "angled"
	scene._battlefield_camera.stop_transition(); scene.camera_mode = ""
	present()
	await capture("5-field-angled")
	# Close views with the game's own lighting, materials and effects.
	app.hud.hide()
	var target: Vector3 = scene._support_cores.cores[core].root.global_position + Vector3(0.5, 0.0, 0.5)
	var close := Camera3D.new(); scene.world.add_child(close)
	close.fov = 20
	for view in [["6-close-angled", Vector3(2.6, 3.4, 3.6)], ["7-close-high", Vector3(0.8, 6.0, 2.2)]]:
		close.position = target + view[1]; close.look_at(target + Vector3(0, 0.15, 0)); close.make_current()
		for frame in range(60): await process_frame
		await capture(view[0])
	if "--gif" in args:
		await gif_frames(close, target)
		quit(0 if built else 1)
		return
	# Pulse phases at a fixed clock: launch (arms flash), travel, arrival ripple.
	# The scene stops applying frames so each still shows exactly one phase.
	scene.set_process(false)
	var period: float = scene._support_cores.LINK_PERIOD
	var phases := [0.02, 0.3, 0.55, 0.7, 0.85]
	for view in [["8-pulse-close", Vector3(0.8, 6.0, 2.2), 1.0], ["9-pulse-game", Vector3(0.4, 11.0, 3.6), 0.5]]:
		close.position = target + view[1]; close.look_at(target + Vector3(0, 0.15, 0)); close.make_current()
		var strip: Image
		for i in phases.size():
			scene._support_cores.sync(app.run_domain.state, null, Vector2i(scene.columns, scene.rows), 30.0 * period + phases[i] * period)
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image = image.get_region(Rect2i(0, int(image.get_height() * 0.1), image.get_width(), int(image.get_height() * 0.5)))
			if view[2] < 1.0: image.resize(int(image.get_width() * view[2]), int(image.get_height() * view[2]))
			if strip == null: strip = Image.create(image.get_width() * phases.size(), image.get_height(), false, image.get_format())
			strip.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(i * image.get_width(), 0))
		strip.save_png(directory.path_join(view[0] + ".png"))
		print("SUPPORT_CORE_CAPTURE ", view[0])
	quit(0 if built else 1)

## Pulse cycles from a fixed clock, as raw RGB frames for make_gif.py: two cycles at 20 fps,
## or with --video three cycles at 30 fps in a 2x window (encoded with ffmpeg, see README).
func gif_frames(close: Camera3D, target: Vector3) -> void:
	scene.set_process(false)
	var period: float = scene._support_cores.LINK_PERIOD
	var video := "--video" in OS.get_cmdline_user_args()
	var fps := 30 if video else 20
	var frames_dir := directory.path_join("gif-frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	close.position = target + Vector3(0.5, 8.0, 3.0); close.look_at(target + Vector3(0, 0.15, 0)); close.make_current()
	# --video renders the same world and framing off screen at twice the window size (a window that
	# tall is clamped to the display). The 2D level badges follow the main camera, so they stay out; the
	# space backdrop is screen-space, so each frame lays the 3D render over the upscaled window.
	var view: Viewport = root
	if video:
		var offscreen := SubViewport.new()
		offscreen.size = root.size * 2
		offscreen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		offscreen.msaa_3d = root.msaa_3d
		offscreen.screen_space_aa = root.screen_space_aa
		offscreen.use_taa = root.use_taa
		offscreen.transparent_bg = true
		root.add_child(offscreen)
		var camera := Camera3D.new()
		offscreen.add_child(camera)
		camera.fov = close.fov
		camera.global_transform = close.global_transform
		camera.make_current()
		view = offscreen
		for frame in range(10): await process_frame
	var count := int(round(period * fps)) * (3 if video else 2)
	var size := Vector2i.ZERO
	for i in count:
		scene._support_cores.sync(app.run_domain.state, null, Vector2i(scene.columns, scene.rows), 30.0 * period + float(i) / fps)
		for frame in range(2): await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		if video:
			var backdrop := root.get_texture().get_image()
			backdrop.convert(Image.FORMAT_RGBA8); image.convert(Image.FORMAT_RGBA8)
			backdrop.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_BILINEAR)
			backdrop.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
			image = backdrop
		image = image.get_region(Rect2i(0, int(image.get_height() * 0.16), image.get_width(), int(image.get_height() * 0.42)))
		image.convert(Image.FORMAT_RGB8)
		size = image.get_size()
		var file := FileAccess.open(frames_dir.path_join("%03d.rgb" % i), FileAccess.WRITE)
		file.store_buffer(image.get_data())
		file.close()
	var info := FileAccess.open(frames_dir.path_join("frames.json"), FileAccess.WRITE)
	info.store_string(JSON.stringify({"width":size.x, "height":size.y, "count":count, "fps":fps}))
	info.close()
	print("SUPPORT_CORE_GIF_FRAMES ", count, " ", size)
