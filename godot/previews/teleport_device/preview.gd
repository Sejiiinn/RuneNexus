extends Node3D
## Isolated rendering fixture; never modifies shipped map content or saves.
const BattlefieldEnvironment = preload("res://environment/battlefield_environment.gd")
const TeleportDevice = preload("res://environment/teleport_device.gd")

var terrain := Node3D.new()
var environment := Environment.new()
var sun := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()
var battlefield := BattlefieldEnvironment.new(terrain, environment, sun, fill)
var camera := Camera3D.new()
var battle_time := 16.0 / 24.0
var paused := true
var speed := 1.0
var theme := "chapterOne"
var ready_for_capture := false
var report := {}
var stage_id := 0


func _ready() -> void:
	name = "TeleportPreview"
	get_window().size = Vector2i(1280, 900)
	add_child(terrain)
	terrain.name = "Terrain"
	battlefield.failed.connect(func(message: String): push_error(message))
	battlefield.attach_lighting(self)
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.002, 0.004, 0.008)
	if not battlefield.initialize(): return
	if not OS.get_environment("RUNE_TELEPORT_THEME").is_empty(): theme = OS.get_environment("RUNE_TELEPORT_THEME")
	stage_id = int(OS.get_environment("RUNE_TELEPORT_STAGE"))
	var baseline := stage_fixture(stage_id, false) if stage_id > 0 else fixture(theme, false)
	theme = str(baseline.theme)
	if not battlefield.build_terrain(baseline): return
	var baseline_count := terrain.get_child_count()
	var original_meshes := mesh_snapshot()
	assert(battlefield._teleport_devices.is_empty())
	baseline.teleportPairs = []
	if not battlefield.build_terrain(baseline): return
	assert(baseline_count == terrain.get_child_count())
	assert(battlefield._teleport_devices.is_empty())
	if not battlefield.build_terrain(stage_fixture(stage_id, true) if stage_id > 0 else fixture(theme, true)): return
	for item: Array in original_meshes:
		assert(mesh_fingerprint(item[0]) == item[1])
	assert(battlefield._teleport_devices.size() == 4)
	report = {"theme": theme, "baseline_nodes": baseline_count, "devices": 4, "cut": battlefield._teleport_cut_report,
		"bounds": measure_bounds(), "clock": verify_clock(), "source_meshes_unchanged": original_meshes.size(),
		"stage": stage_id, "authored": battlefield._using_authored, "chapter_environment": battlefield._using_chapter_environment}
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.6
	add_child(camera)
	camera.position = Vector3(-0.5, 11.0, 6.3)
	camera.look_at(Vector3(-0.5, 0.0, -0.5))
	camera.current = true
	if stage_id > 0:
		camera.size = 13.0
		camera.position = Vector3(0, 15, 10)
		camera.look_at(Vector3.ZERO)
	for row in ([] if stage_id > 0 else [0, 2]):
		for column in [0, 3]:
			var caption := Label3D.new()
			caption.text = ("BLUE" if row == 0 else "ORANGE") + (" IN" if column == 0 else " OUT")
			caption.font_size = 48
			caption.pixel_size = 0.0023
			caption.outline_size = 0
			caption.modulate = Color(0.58, 0.79, 1.0) if row == 0 else Color(1.0, 0.72, 0.36)
			caption.position = Vector3(float(column) - 2.0, 0.02, float(row) - 2.2)
			caption.rotation_degrees.x = -90
			add_child(caption)
	battlefield.update_frame({"time": battle_time})
	ready_for_capture = true
	print("TELEPORT_RENDER_READY ", JSON.stringify(report))
	var output := OS.get_environment("RUNE_TELEPORT_REPORT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
	if "--capture" in OS.get_cmdline_user_args(): _capture_sequence.call_deferred()


static func stage_fixture(stage: int, with_portals: bool) -> Dictionary:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/game_content.json"))
	var map: Dictionary = content.stages[stage - 1].map.duplicate(true)
	map.theme = map.tileTheme
	map.columns = int(map.columns)
	map.rows = int(map.rows)
	for i in range(map.path.size()):
		map.path[i] = [int(map.path[i][0]), int(map.path[i][1])]
	if with_portals:
		map.teleportPairs = [{"color": "blue", "entrance": map.path[3], "exit": map.path[6]},
			{"color": "orange", "entrance": map.path[10], "exit": map.path[14]}]
	return map


func mesh_snapshot() -> Array:
	var result: Array = []
	for instance: MeshInstance3D in terrain.find_children("*", "MeshInstance3D", true, false):
		result.append([instance.mesh, mesh_fingerprint(instance.mesh)])
	for instance: MultiMeshInstance3D in terrain.find_children("*", "MultiMeshInstance3D", true, false):
		result.append([instance.multimesh.mesh, mesh_fingerprint(instance.multimesh.mesh)])
	return result


static func mesh_fingerprint(mesh: Mesh) -> int:
	var fingerprint := mesh.get_surface_count()
	for surface in range(mesh.get_surface_count()):
		fingerprint = hash([fingerprint, mesh.surface_get_arrays(surface)])
	return fingerprint


static func fixture(theme_name: String, with_portals: bool) -> Dictionary:
	var tiles: Array = []
	for i in range(24): tiles.append("blocked")
	# Adjacent walking context joins the two independent portal pairs.
	var path := [[1,0],[0,0],[3,0],[4,0],[4,1],[3,1],[2,1],[1,1],[0,1],[0,2],[3,2],[4,2]]
	for cell in path: tiles[cell[1] * 6 + cell[0]] = "path"
	var map := {"columns": 6, "rows": 4, "theme": theme_name, "tiles": tiles}
	if with_portals:
		map.path = path
		map.teleportPairs = [{"color": "blue", "entrance": [0,0], "exit": [3,0]},
			{"color": "orange", "entrance": [0,2], "exit": [3,2]}]
	return map


func measure_bounds() -> Dictionary:
	var result := {}
	for device: Node3D in battlefield._teleport_devices:
		var bounds := AABB()
		var initial := true
		for mesh: MeshInstance3D in device.find_children("*", "MeshInstance3D", true, false):
			var local := device.global_transform.affine_inverse() * mesh.global_transform
			var current := local * mesh.get_aabb()
			bounds = current if initial else bounds.merge(current)
			initial = false
		for frame in range(97):
			for arm in range(3):
				for packet in range(5):
					var point := TeleportDevice.radial_light_position(float(frame) / 24.0, device.outflow, arm, packet)
					bounds = bounds.merge(AABB(point - Vector3.ONE * 0.004, Vector3.ONE * 0.008))
		assert(bounds.position.x >= -0.500001 and bounds.end.x <= 0.500001)
		assert(bounds.position.z >= -0.500001 and bounds.end.z <= 0.500001)
		result[device.name] = {"min": [bounds.position.x, bounds.position.y, bounds.position.z], "max": [bounds.end.x, bounds.end.y, bounds.end.z]}
	return result


func verify_clock() -> Dictionary:
	for device in battlefield._teleport_devices:
		device.update_time(0.5)
		var parameter: float = device._surface_material.get_shader_parameter("battle_time")
		device.update_time(0.5)
		assert(parameter == float(device._surface_material.get_shader_parameter("battle_time")))
		device.update_time(1.5)
		assert(float(device._surface_material.get_shader_parameter("battle_time")) == 1.5)
		for arm in range(3):
			for packet in range(5):
				assert(TeleportDevice.radial_light_position(0, device.outflow, arm, packet).is_equal_approx(TeleportDevice.radial_light_position(4, device.outflow, arm, packet)))
	return {"paused_uniform_unchanged": true, "authoritative_clock": true, "four_second_loop": true}


func _process(delta: float) -> void:
	if not ready_for_capture: return
	if not paused: battle_time += delta * speed
	battlefield.update_frame({"time": battle_time})


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_SPACE: paused = not paused
	elif event.keycode == KEY_1: speed = 1.0
	elif event.keycode == KEY_4: speed = 4.0
	elif event.keycode == KEY_R:
		battle_time = 16.0 / 24.0
		paused = true
	print("TELEPORT_CLOCK ", battle_time, " paused=", paused, " speed=", speed)


func _capture_sequence() -> void:
	var destination := OS.get_environment("RUNE_TELEPORT_CAPTURE")
	if destination.is_empty(): return
	DirAccess.make_dir_recursive_absolute(destination)
	for frame in ([17] if stage_id > 0 else [1, 9, 17, 25, 49, 73, 96]):
		battle_time = float(frame - 1) / 24.0
		battlefield.update_frame({"time": battle_time})
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(destination.path_join("frame-%04d.png" % frame))
	print("TELEPORT_CAPTURE_DONE")
	get_tree().quit()


func _exit_tree() -> void:
	if is_instance_valid(terrain): battlefield.dispose()
