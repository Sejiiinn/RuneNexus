extends SceneTree
## Actual content, paid turret commands and native combat; isolated review saves.
const OUT := "/Users/sejin/Documents/Codex/RuneNexus/design/enemy_concepts/2026-09-27/fast-rune-hound/death/game-review/captures/"
var scene: Node3D
var app
var mode := "angled"
var survey := false
var speed := 1.0
var capture_start := 8.5
var capture_end := 20.0
var status_case := false
var burn_case := false
var turns: Array = []
var events: Array = []
var known := {}
var shots := 0
var max_dead := 0
var death_samples: Array = []
var max_burning := 0
var max_frozen := 0
var effect_counts := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): mode = arg.trim_prefix("--view=")
		if arg == "--survey": survey = true
		if arg == "--status": status_case = true
		if arg == "--burn":
			status_case = true
			burn_case = true
		if arg == "--speed=4":
			speed = 4.0
			capture_start = 2.125
			capture_end = 5.0
	if status_case: capture_end = 20.0 if speed == 1.0 else 5.0
	call_deferred("run")

func run() -> void:
	seed(20260927)
	root.size = Vector2i(440,900)
	root.content_scale_size = Vector2i(440,760)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	scene = load("res://main.tscn").instantiate()
	scene._app_mode = false
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	# Bootstrap manually to avoid service/login UI, then use the real app's
	# canonical Canvas presentation conversion for HUD bars and effect sizes.
	scene._app_mode = true
	app = load("res://app/app_lifecycle.gd").new()
	app.ui_enabled = false
	app.checkpoint = load("res://session/session_checkpoint.gd").new(OUT.path_join("isolated-save-" + str(OS.get_process_id())))
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	app.spawn_rng.seed = 20260927
	assert(app.start_stage(0), app.checkpoint.message)
	app.run_domain.state.gold = 1000 # Explicit review fixture budget, actual build prices/stats.
	var towers := [["frost",Vector2i(2,1)],["magic",Vector2i(3,3)]] if status_case else [["cannon",Vector2i(5,5)],["arrow",Vector2i(5,7)]]
	if burn_case: towers = [["magic",Vector2i(2,1)],["magic",Vector2i(3,3)]]
	for tower in towers:
		app.turret_type = tower[0]
		app.board_tap(tower[1])
		app.build_selected()
	assert(scene._native_combat.turrets.size() == 2)
	app.selected = Vector2i(-1,-1)
	app.refresh_selection()
	var layer := CanvasLayer.new()
	layer.layer = 10
	app.add_child(layer)
	app.hud = load("res://ui/battle_hud.gd").new()
	app.hud.app = app
	layer.add_child(app.hud)
	app._refresh_ui()
	scene.options.camera = mode
	scene._apply_options()
	scene._battlefield_camera.stop_transition()
	scene.camera_mode = ""
	scene._update_camera()
	app.next_round = 3 # Authored stage 1 wave 4: normal and fast groups.
	app.run_domain.state.completedRounds = 3
	app.start_wave()
	if speed != 1.0: app.command([], {"speed":speed})
	for i in range(12): await process_frame
	var label := mode + ("-4x" if speed == 4.0 else "") + ("-status" if status_case else "")
	if burn_case: label += "-burn"
	var folder := OUT.path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in range(int(capture_end * 30.0) + 30):
		var t := float(frame)/30.0
		scene._process(1.0/30.0)
		var runtime = scene._native_combat
		if runtime.enemies.has("100000") and scene._units.enemies.has(100000):
			var first: Dictionary = runtime.enemies["100000"]
			turns.append({"wall":t,"clock":runtime.clock,"target":PI/2.0-float(first.facingAngle),"shown":scene._units.enemies[100000].root.rotation.y})
		for event: Dictionary in runtime.events:
			if not known.has(event.id):
				known[event.id] = true
				events.append({"wall":t,"combat":runtime.clock,"event":event.duplicate(true)})
				if event.get("kind") in ["kill","arrival"]: print("REVIEW_EVENT ",t," ",JSON.stringify(event))
		app._process(1.0/30.0)
		if app.hud != null: app.hud.refresh()
		if scene._units._guardian_preview != null:
			max_dead = maxi(max_dead,scene._units._guardian_preview.deaths.size())
			for id in scene._units._guardian_preview.deaths:
				var corpse: Dictionary = scene._units._guardian_preview.deaths[id]
				if corpse.type == "fast":
					death_samples.append({"id":id,"wall":t,"age":runtime.clock-float(corpse.born),"fade":1.0 - float(corpse.death_bodies[0].get_instance_shader_parameter("death_opacity")),"frame":shots})
		var burning := 0
		var frozen := 0
		for entry: Dictionary in scene._units.enemies.values():
			if entry.has("burn") and entry.burn.visible: burning += 1
			if entry.has("frost") and entry.frost.visible: frozen += 1
			for effect in ["burn", "frost"]:
				if entry.has(effect) and entry[effect].visible:
					var key: String = entry.type + "_" + effect
					if not effect_counts.has(key): print("FIRST_EFFECT ", key, " wall=", t)
					effect_counts[key] = int(effect_counts.get(key, 0)) + 1
		max_burning = maxi(max_burning, burning)
		max_frozen = maxi(max_frozen, frozen)
		if not survey:
			await process_frame
			await RenderingServer.frame_post_draw
			if t >= capture_start and t < capture_end:
				root.get_texture().get_image().save_png(folder.path_join("%05d.png" % shots))
				shots += 1
		elif frame % 60 == 0: await process_frame
		if frame % 120 == 0: print("CAPTURE_PROGRESS ",mode," t=",t," enemies=",scene.enemies.size()," corpses_max=",max_dead)
	var report := {"mode":mode,"speed":speed,"source":"actual stage1 wave4; actual paid towers relocated to expose corners; fixture build budget1000", "status_case":status_case,"turns":turns, "events":events,"frames":shots,"fps":30,"capture_start":capture_start,"capture_end":capture_end,"max_simultaneous_deaths":max_dead,"max_burning":max_burning,"max_frozen":max_frozen,"effect_frames_by_kind":effect_counts,"fast_deaths":death_samples,"window_size":str(root.size),"renderer":RenderingServer.get_current_rendering_method(),"mobile_performance":"unmeasured; desktop deterministic capture is not an FPS benchmark"}
	var file := FileAccess.open(OUT.path_join(label + ("-survey" if survey else "") + ".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("HOUND_CAPTURE_DONE ",mode," frames=",shots," deaths_max=",max_dead)
	scene.queue_free()
	for i in range(3): await process_frame
	quit()
