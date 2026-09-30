extends Node3D
## Isolated design-map preview. Reads the design source; never writes game content or saves.
const BattlefieldEnvironment = preload("res://environment/battlefield_environment.gd")
const BattlefieldUnits = preload("res://presentation/battlefield_units.gd")
const NativeRuntime = preload("res://combat/native_combat_runtime.gd")
const Teleports = preload("res://combat/teleport_pairs.gd")
const SpaceBackground = preload("res://environment/combat_space_background.gd")

var terrain := Node3D.new()
var actors := Node3D.new()
var environment := Environment.new()
var sun := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()
var battlefield := BattlefieldEnvironment.new(terrain, environment, sun, fill)
var camera := Camera3D.new()
var units := BattlefieldUnits.new(actors, camera)
var runtime := NativeRuntime.new()
var stage := "1-7"
var map := {}
var design_root := ""
var ready_for_capture := false
var capture_mode := false
var sequence := 0
var report := {}
var trace: Array = []
var event_seen := 0
var heading := Label.new()
var status := Label.new()
var paused := true
var speed := 1.0

func _ready() -> void:
	get_window().size = Vector2i(900, 990)
	name = "ChapterOneExpansionPreview"
	add_child(SpaceBackground.new())
	terrain.name = "Terrain"
	actors.name = "Actors"
	add_child(terrain)
	add_child(actors)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.8
	camera.position = Vector3(0, cos(deg_to_rad(25.0)) * 20.0, sin(deg_to_rad(25.0)) * 20.0)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	battlefield.attach_lighting(self)
	battlefield.failed.connect(func(message: String): push_error(message))
	units.failure.connect(func(message: String): push_error(message))
	if not battlefield.initialize(): return
	design_root = OS.get_environment("RUNE_EXPANSION_DESIGN_ROOT")
	if design_root.is_empty():
		var candidate := ProjectSettings.globalize_path("res://")
		for _i in range(5):
			var directory := candidate.path_join("design/chapter1_map_expansion")
			if FileAccess.file_exists(directory.path_join("maps.json")):
				design_root = directory
				break
			candidate = candidate.get_base_dir()
	assert(not design_root.is_empty(), "Set RUNE_EXPANSION_DESIGN_ROOT to the design folder")
	if not OS.get_environment("RUNE_EXPANSION_STAGE").is_empty(): stage = OS.get_environment("RUNE_EXPANSION_STAGE")
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	heading.position.y = 20
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	canvas.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -72
	status.offset_bottom = -16
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 17)
	capture_mode = "--capture" in OS.get_cmdline_user_args() or "--still" in OS.get_cmdline_user_args()
	_load_map()
	if capture_mode: _capture.call_deferred()

func _load_map() -> void:
	ready_for_capture = false
	units.clear()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(design_root.path_join("maps.json")))
	map = {}
	for item: Dictionary in source.maps:
		if item.chapterStage == stage: map = item.duplicate(true)
	assert(not map.is_empty())
	map.columns = int(map.columns)
	map.rows = int(map.rows)
	map.theme = map.tileTheme
	for i in range(map.path.size()): map.path[i] = [int(map.path[i][0]), int(map.path[i][1])]
	for pair: Dictionary in map.teleportPairs:
		for role in ["entrance", "exit"]: pair[role] = [int(pair[role][0]), int(pair[role][1])]
	assert(Teleports.validate_map(map).is_empty())
	assert(battlefield.build_terrain(map))
	_load_dressing()
	var base_nodes := terrain.get_child_count()
	var logical: Array = []
	for point: Array in map.path: logical.append({"x": (float(point[0]) + 0.5) * 48.0, "y": (float(point[1]) + 0.5) * 48.0})
	runtime = NativeRuntime.new()
	sequence = 0
	event_seen = 0
	trace.clear()
	var response: Dictionary = runtime.process_command({"epoch": 1, "sequence": sequence,
		"bootstrap": {"path": logical, "teleportPairs": Teleports.compile_map(map), "tileSize": 48.0,
			"boardDistanceScale": 1.0, "enemies": [{"id": 1, "type": "normal", "maxHp": 100.0,
				"speed": 72.0, "presentationScale": 0.55, "visualPhase": 0.7, "laneOffsetRatio": 0.0}]},
		"session": {"clock": "godot", "phase": "wave", "paused": true, "speed": 1.0}})
	assert(response.accepted)
	paused = true
	speed = 1.0
	report = {"stage": stage, "path_tiles": map.path.size(), "walking_edges": int(map.walkingEdges),
		"teleport_pairs": map.teleportPairs, "terrain_nodes": base_nodes, "host_cut": battlefield._teleport_cut_report,
		"forbidden_cells": _gap_cells(), "teleports": [], "blocked_cell_violations": [], "render_root_mismatches": []}
	heading.text = "기획 " + stage + "  " + str(map.name)
	ready_for_capture = true
	_present()
	print("EXPANSION_PREVIEW_READY ", JSON.stringify(report))

func _load_dressing() -> void:
	var file := design_root.path_join("concepts/chapter-" + stage + "-dressing.glb")
	if not FileAccess.file_exists(file): return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(file, state) == OK)
	var dressing := document.generate_scene(state)
	dressing.name = "PreservedConceptDressing"
	BattlefieldEnvironment.prepare_vertex_colors(dressing)
	terrain.add_child(dressing)

func _gap_cells() -> Array:
	var result: Array = []
	for pair: Dictionary in map.teleportPairs:
		var from := Vector2i(pair.entrance[0], pair.entrance[1])
		var to := Vector2i(pair.exit[0], pair.exit[1])
		var direction := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
		var cell := from + direction
		while cell != to:
			assert(map.tiles[cell.y * map.columns + cell.x] == "blocked")
			assert(not map.path.has([cell.x, cell.y]))
			result.append([cell.x, cell.y])
			cell += direction
	return result

func _process(delta: float) -> void:
	if not ready_for_capture or capture_mode: return
	runtime.advance_session(delta)
	_present()

func _present() -> void:
	var frame: Dictionary = runtime.decorate_frame({"time": 0.0, "enemies": [], "turrets": []})
	battlefield.update_frame(frame)
	units.configure(float(frame.time), Vector2i(map.columns, map.rows), {"volume": true})
	units.sync_guardian_events(runtime)
	units._sync_enemies(frame.enemies)
	for event: Dictionary in runtime.events:
		if int(event.id) <= event_seen: continue
		event_seen = int(event.id)
		if event.kind == "teleport":
			report.teleports.append(event.duplicate(true))
			print("EXPANSION_TELEPORT ", JSON.stringify(event))
	if not frame.enemies.is_empty():
		var row: Array = frame.enemies[0]
		var cell := [floori(float(row[12])), floori(float(row[13]))]
		if map.tiles[cell[1] * map.columns + cell[0]] == "blocked": report.blocked_cell_violations.append(cell)
		var rendered: Vector3 = units.enemies[1].root.position
		var expected := Vector3(float(row[1]) - map.columns / 2.0, 0.0, float(row[2]) - map.rows / 2.0)
		if not rendered.is_equal_approx(expected): report.render_root_mismatches.append([rendered.x, rendered.z])
		if capture_mode: trace.append({"time": frame.time, "x": row[12], "y": row[13], "serial": row[14].teleportSerial,
			"render_x": rendered.x, "render_z": rendered.z})
	status.text = "보행 %d칸 · 순간이동 %d/%d회 · 건설 %d칸\nSpace 정지/재생 · 1/4 배속 · 7/0 맵 전환 · R 다시 보기" % [map.walkingEdges, report.teleports.size(), map.teleportPairs.size(), map.buildCells.size()]

func _session(values: Dictionary) -> void:
	sequence += 1
	assert(runtime.process_command({"epoch": 1, "sequence": sequence, "session": values}).accepted)

func _unhandled_key_input(event: InputEvent) -> void:
	if not ready_for_capture or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE:
			paused = not paused
			_session({"paused": paused})
		KEY_1, KEY_4:
			speed = 1.0 if event.keycode == KEY_1 else 4.0
			_session({"speed": speed})
		KEY_7, KEY_0:
			stage = "1-7" if event.keycode == KEY_7 else "1-10"
			_load_map()
		KEY_R: _load_map()

func _capture() -> void:
	var directory := OS.get_environment("RUNE_EXPANSION_CAPTURE")
	assert(not directory.is_empty())
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("overview.png"))
	if "--still" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	_session({"paused": false})
	var frame_index := 0
	var previous_events := 0
	while frame_index < 420 and not bool(runtime.enemies["1"].arrived):
		runtime.advance_session(1.0 / 24.0)
		_present()
		await RenderingServer.frame_post_draw
		var pixels := get_viewport().get_texture().get_image()
		pixels.save_png(directory.path_join("frame-%04d.png" % frame_index))
		if report.teleports.size() > previous_events:
			pixels.save_png(directory.path_join("teleport-%d-exit.png" % report.teleports.size()))
			previous_events = report.teleports.size()
		frame_index += 1
	report.frames = frame_index
	report.arrived = runtime.enemies["1"].arrived
	report.trace = trace
	assert(report.teleports.size() == map.teleportPairs.size())
	assert(report.blocked_cell_violations.is_empty())
	assert(report.render_root_mismatches.is_empty())
	assert(report.arrived)
	var file := FileAccess.open(directory.path_join("runtime-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("EXPANSION_CAPTURE_COMPLETE ", stage, " ", frame_index)
	get_tree().quit()

func _exit_tree() -> void:
	units.clear()
	if is_instance_valid(terrain): battlefield.dispose()
