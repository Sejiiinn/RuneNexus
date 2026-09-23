extends SceneTree

# Isolated desktop capture of the real frost turret combat path.
const OUTPUT := "/Users/sejin/Documents/Codex/RuneNexus/design/frost_tower_concepts/2026-09-23/production/fire-motion-review/close"
const PRE_FRAMES := 8
const POST_FRAMES := 24
var recent: Array = []
var captured: Array = []

func _initialize() -> void:
	call_deferred("run")

func snapshot(scene: Node3D, entry: Dictionary, tick: int, sequence: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var flash: MeshInstance3D = entry["flashes"][int(entry["active_port"])]
	var smoke: MeshInstance3D = entry["smokes"][int(entry["active_port"])]
	var projectiles: Array = []
	for projectile in scene.projectiles.values():
		if projectile["type"] == "frost":
			projectiles.append([projectile["root"].global_position.x, projectile["root"].global_position.y, projectile["root"].global_position.z])
	return {
		"tick": tick,
		"time": float(scene.last_frame.get("time", 0.0)),
		"shot_sequence": sequence,
		"head_y_radians": entry["head"].rotation.y,
		"barrel_z": entry["barrel"].position.z,
		"muzzle_world": [entry["muzzle"].global_position.x, entry["muzzle"].global_position.y, entry["muzzle"].global_position.z],
		"flash_visible": flash.visible,
		"smoke_visible": smoke.visible,
		"frost_projectiles": projectiles,
		"png": image.save_png_to_buffer(),
	}

func save_frames(frames: Array) -> Array:
	var rows: Array = []
	for i in range(frames.size()):
		var frame: Dictionary = frames[i]
		var filename := "frame_%03d.png" % i
		var file := FileAccess.open(OUTPUT.path_join(filename), FileAccess.WRITE)
		file.store_buffer(frame["png"])
		frame.erase("png")
		frame["file"] = filename
		rows.append(frame)
	return rows

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	if not OS.get_user_data_dir().contains("RuneNexus-Frost-Review"):
		push_error("Expected isolated frost review user directory")
		quit(1)
		return
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var app = scene._standalone_session
	if app == null or app.startup_blocked:
		push_error("Formal app failed to start")
		quit(1)
		return
	scene.set_process(false)
	app.set_process(false)
	app.progression_inputs["clearedStageNumbers"] = range(1, 16)
	app.progression_inputs["unlockedStageCount"] = 15
	if not app.start_stage(0):
		push_error("Stage did not start")
		quit(1)
		return
	app.run_domain.state.gold = 100000
	var source: Dictionary = app.stage_source(0)
	var tile := Vector2i(-1, -1)
	for index in range(source.map.tiles.size()):
		if source.map.tiles[index] == "build":
			tile = Vector2i(index % int(source.map.columns), floori(float(index) / int(source.map.columns)))
			break
	app.turret_type = "frost"
	app.board_tap(tile)
	app.build_selected()
	app.command()
	scene._apply_frame(scene._native_combat_base_frame)
	app._process(0.0)
	var frost_id := -1
	for id in scene.turrets:
		if scene.turrets[id]["type"] == "frost":
			frost_id = int(id)
			break
	if frost_id < 0:
		push_error("Frost model not constructed")
		quit(1)
		return
	var entry: Dictionary = scene.turrets[frost_id]
	app.board_tap(Vector2i(-1, -1))
	app.hud.hide()
	scene.camera.h_offset = 0
	scene.camera.v_offset = 0
	scene.camera.size = 2.7
	scene.camera.near = 0.05
	scene.camera.far = 100.0
	var center: Vector3 = entry["root"].global_position + Vector3(0, 0.32, 0)
	scene.camera.position = center + Vector3(1.8, 2.3, 3.0)
	scene.camera.look_at(center)
	app.start_wave()
	var fire_tick := -1
	var last_sequence := 0
	for tick in range(900):
		scene._native_combat.advance_session(1.0 / 60.0)
		app.command()
		scene._apply_frame(scene._native_combat_base_frame)
		app._process(0.0)
		# The app's frame application fits the battlefield camera each tick.
		# Override it only in this review script for a readable close inspection.
		scene.camera.h_offset = 0
		scene.camera.v_offset = 0
		scene.camera.size = 2.7
		scene.camera.position = center + Vector3(1.8, 2.3, 3.0)
		scene.camera.look_at(center)
		var sequence := 0
		for turret in scene._native_combat.turrets.values():
			if turret.statInput.definition.type == "frost":
				sequence = int(turret.shotSequence)
		var data: Dictionary = await snapshot(scene, entry, tick, sequence)
		if fire_tick < 0:
			recent.append(data)
			if recent.size() > PRE_FRAMES + 1:
				recent.pop_front()
			if sequence > last_sequence:
				fire_tick = tick
				captured.append_array(recent)
		else:
			captured.append(data)
			if tick >= fire_tick + POST_FRAMES:
				break
		last_sequence = sequence
	if fire_tick < 0:
		push_error("Frost turret did not fire in 900 ticks")
		quit(1)
		return
	var rows := save_frames(captured)
	var report := {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"user_directory": OS.get_user_data_dir(),
		"asset_sha256": FileAccess.get_sha256("res://assets/turrets/frost.glb"),
		"frost_id": frost_id,
		"fire_tick": fire_tick,
		"frame_count": rows.size(),
		"frames": rows,
	}
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("FIRE_MOTION_CAPTURE fire_tick=", fire_tick, " frames=", rows.size(), " output=", OUTPUT)
	scene.queue_free()
	for i in range(4): await process_frame
	quit(0)
