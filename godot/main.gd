extends Node3D

const Impact = preload("res://effects/godot_impact.gd")
const FieldCache = preload("res://effects/field_cache.gd")
const WeaponAtlas = preload("res://effects/weapon_atlas.gd")
const MachineGunMuzzle = preload("res://effects/machinegun_muzzle.gd")
const BallisticProjectile = preload("res://effects/ballistic_projectile.gd")
const Terrain = preload("res://assets/environment/terrain.glb")
const Dressing = preload("res://assets/environment/dressing.glb")
const FoliageWind = preload("res://environment/foliage_wind.gdshader")
const TURRET_MODELS := {
	"arrow": preload("res://assets/turrets/arrow.glb"),
	"cannon": preload("res://assets/turrets/cannon.glb"),
	"magic": preload("res://assets/turrets/magic.glb"),
	"frost": preload("res://assets/turrets/frost.glb"),
	"sniper": preload("res://assets/turrets/sniper.glb"),
	"lightning": preload("res://assets/turrets/lightning.glb"),
}
const ENEMY_MODELS := {
	"normal": preload("res://assets/enemies/normal.glb"),
	"armored": preload("res://assets/enemies/armored.glb"),
	"shielded": preload("res://assets/enemies/shielded.glb"),
	"fast": preload("res://assets/enemies/fast.glb"),
	"tank": preload("res://assets/enemies/tank.glb"),
	"boss": preload("res://assets/enemies/boss.glb"),
}
const PROJECTILE_COLORS := {
	"arrow": Color("ffe3a3"), "cannon": Color("ffb261"), "magic": Color("d59bff"),
	"frost": Color("94e6ff"), "sniper": Color("ffeec4"), "lightning": Color("c7d8ff"),
}
const CAMERA_TRANSITION_SECONDS := 0.7

var bridge: Object
var camera := Camera3D.new()
var camera_mode := ""
var camera_transition: Tween
var sun := DirectionalLight3D.new()
var world := Node3D.new()
var terrain := Node3D.new()
var turrets := {}
var enemies := {}
var projectiles := {}
var impacts := {}
var impact_pool: Array[Node3D] = []
var impact_lights: Array[OmniLight3D] = []
var field: Dictionary
var last_frame := {}
var columns := 8
var rows := 10
var options := {"camera": "angled", "zoom": 1.0, "shadows": true, "volume": true, "empty": false}
var metrics_elapsed := 0.0
var frame_count := 0
var frame_time_total := 0.0
var frame_time_max := 0.0
var last_sequence := -1
var received_frames := 0
var standalone_time := 0.0
var standalone_playing := false
var _terrain_library: Node3D
var _dressing_library: Node3D
var _foliage_material: ShaderMaterial
var _build_tile_slots := PackedInt32Array()
var _occupied_build_tiles := Vector2i.ZERO
var _terrain_manifest := {}
var _current_map := {}
var _using_authored := false
var _portals: Array[Node3D] = []
var _cores: Array[Node3D] = []
var _build_preview := {}
var _projectile_meshes := {}
var _ballistic_pool := {"arrow": [], "cannon": []}


func _ready() -> void:
	if Engine.has_singleton("RuneNexusPreview"):
		bridge = Engine.get_singleton("RuneNexusPreview")
	elif OS.get_name() == "Android":
		_fail("Flutter 전투 브리지가 등록되지 않았습니다.")
		return
	add_child(world)
	world.add_child(terrain)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 100.0
	camera.current = true
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b20")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.86, 1.0)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	sun.rotation_degrees = Vector3(-62, -32, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40, 135, 0)
	fill.light_color = Color(0.65, 0.8, 1.0)
	fill.light_energy = 0.35
	add_child(fill)
	for index in range(4):
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.42, 0.08)
		light.light_energy = 0.0
		world.add_child(light)
		impact_lights.append(light)
	field = FieldCache.load_shared()
	if field.is_empty():
		_fail("폭발 필드 캐시를 불러오지 못했습니다.")
		return
	_terrain_library = Terrain.instantiate()
	_prepare_vertex_colors(_terrain_library)
	_dressing_library = Dressing.instantiate()
	_prepare_vertex_colors(_dressing_library)
	var foliage := _dressing_library.find_child("stage1_dressing_foliage", true, false) as MeshInstance3D
	if not foliage:
		_fail("스테이지 1 환경 GLB의 풀 메시를 찾지 못했습니다.")
		return
	# 전장 전체의 바람에 하나의 재질·GPU 시계 공유.
	_foliage_material = ShaderMaterial.new()
	_foliage_material.shader = FoliageWind
	foliage.material_override = _foliage_material
	foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foliage.extra_cull_margin = 0.03
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain_manifest.json"))
	if not (manifest is Dictionary):
		_fail("지형 원본의 맵 정보를 읽지 못했습니다.")
		return
	_terrain_manifest = manifest
	get_viewport().size_changed.connect(_update_camera)
	# Tween은 _process 뒤에 진행되므로 실제 렌더 직전의 카메라로 투영을 보고.
	RenderingServer.frame_pre_draw.connect(_report_presentation)
	_update_camera()
	if bridge:
		bridge.report_ready()
	else:
		# 네이티브 데스크톱 검수 입력. Android에서는 실제 Flutter 전투만 사용.
		var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://assets/preview_frame.json"))
		if fixture is Dictionary:
			_apply_frame(fixture)
		print("RuneNexus Godot scene ready; Space: impacts, C: camera, S: shadows, V: volume")


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_report_presentation):
		RenderingServer.frame_pre_draw.disconnect(_report_presentation)
	if is_instance_valid(_terrain_library):
		_terrain_library.free()
	if is_instance_valid(_dressing_library):
		_dressing_library.free()


func _fail(message: String) -> void:
	push_error(message)
	if bridge:
		bridge.report_error(message)


func _process(delta: float) -> void:
	if bridge:
		var option_text: String = bridge.take_options()
		if not option_text.is_empty():
			var incoming = JSON.parse_string(option_text)
			if incoming is Dictionary:
				options.merge(incoming, true)
				_apply_options()
		var frame_text: String = bridge.take_frame()
		if not frame_text.is_empty():
			var incoming = JSON.parse_string(frame_text)
			if incoming is Dictionary:
				_apply_frame(incoming)
	elif standalone_playing and not last_frame.is_empty():
		standalone_time += delta
		var frame: Dictionary = last_frame.duplicate(true)
		frame["time"] = standalone_time
		frame["impacts"] = []
		for index in range(mini(3, frame.get("enemies", []).size())):
			var progress := fposmod(standalone_time + index * 0.37, 1.4) / 1.1
			if progress < 1.0:
				var target: Array = frame["enemies"][index]
				frame["impacts"].append([100 + index, target[1], target[2], 1.2, progress])
		_apply_frame(frame)
	metrics_elapsed += delta
	frame_count += 1
	frame_time_total += delta
	frame_time_max = maxf(frame_time_max, delta)
	if metrics_elapsed >= 1.0:
		var viewport := get_viewport().get_visible_rect().size
		var metrics := {
			"fps": frame_count / frame_time_total,
			"frame_ms": frame_time_total * 1000.0 / frame_count,
			"max_frame_ms": frame_time_max * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"received_frames": received_frames, "sequence": last_sequence,
			"viewport": [viewport.x, viewport.y], "authored_terrain": _using_authored,
			"renderer": RenderingServer.get_current_rendering_method(),
		}
		if bridge:
			bridge.report_metrics(JSON.stringify(metrics))
		metrics_elapsed = 0.0
		frame_count = 0
		frame_time_total = 0.0
		frame_time_max = 0.0


func _apply_options() -> void:
	world.visible = not bool(options["empty"])
	sun.shadow_enabled = bool(options["shadows"])
	_update_camera()
	if not last_frame.is_empty():
		_update_impacts(last_frame.get("impacts", []))


func _update_camera() -> void:
	var requested_mode: String = options["camera"]
	if requested_mode != "drone":
		requested_mode = "angled"
	if requested_mode != camera_mode:
		var drone := requested_mode == "drone"
		var target_position := Vector3(0, 30, 0.001) if drone else Vector3(5, 27, 13)
		var target_basis := Basis.looking_at(-target_position, Vector3.FORWARD if drone else Vector3.UP)
		if camera_mode.is_empty():
			camera.transform = Transform3D(target_basis, target_position)
		else:
			if camera_transition:
				camera_transition.kill()
			# 재입력 시 현재 궤도에서 이어지는 0.7초 cubic 감속.
			var start_rotation := camera.quaternion
			var target_rotation := target_basis.get_rotation_quaternion()
			var start_distance := camera.position.length()
			var target_distance := target_position.length()
			camera_transition = create_tween().set_ignore_time_scale(true)
			camera_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			camera_transition.tween_method(func(weight: float) -> void:
				var pose := Basis(start_rotation.slerp(target_rotation, weight))
				camera.transform = Transform3D(pose, pose.z * lerpf(start_distance, target_distance, weight))
				_fit_camera_to_frame()
				_update_camera_visuals()
			, 0.0, 1.0, CAMERA_TRANSITION_SECONDS)
		camera_mode = requested_mode
	_fit_camera_to_frame()
	_update_camera_visuals()


func _fit_camera_to_frame() -> void:
	var visible_size := get_viewport().get_visible_rect().size
	var logical_viewport: Array = last_frame.get("viewport", [])
	var screen_center: Array = last_frame.get("screenCenter", [])
	if logical_viewport.size() != 2 or screen_center.size() != 2 or not last_frame.has("pixelsPerTile"):
		# HUD 없는 검수 화면은 기울어진 지형의 투영 폭·높이까지 포함.
		var aspect := visible_size.x / maxf(1.0, visible_size.y)
		var basis := camera.global_basis
		var width := absf(basis.x.x) * columns + absf(basis.x.z) * rows
		var height := absf(basis.y.x) * columns + absf(basis.y.z) * rows
		camera.size = maxf(height + 1.2, (width + 1.2) / aspect) / maxf(0.01, float(options["zoom"]))
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	var viewport := Vector2(maxf(1.0, float(logical_viewport[0])), maxf(1.0, float(logical_viewport[1])))
	var inverse := camera.global_transform.affine_inverse()
	var bounds_min := Vector2(INF, INF)
	var bounds_max := Vector2(-INF, -INF)
	var min_column := columns
	var max_column := 0
	var min_row := rows
	var max_row := 0
	var tiles: Array = _current_map.get("tiles", [])
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		var x := index % columns
		var z := floori(float(index) / float(columns))
		min_column = mini(min_column, x)
		max_column = maxi(max_column, x + 1)
		min_row = mini(min_row, z)
		max_row = maxi(max_row, z + 1)
		for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
			var point: Vector3 = inverse * Vector3(float(x) + corner.x - columns / 2.0, 0.0, float(z) + corner.y - rows / 2.0)
			bounds_min = bounds_min.min(Vector2(point.x, point.y))
			bounds_max = bounds_max.max(Vector2(point.x, point.y))
	if not bounds_min.is_finite():
		bounds_min = Vector2(-0.5, -0.5)
		bounds_max = Vector2(0.5, 0.5)
		min_column = 0
		max_column = 1
		min_row = 0
		max_row = 1
	var span := bounds_max - bounds_min
	var fit := clampf(minf(float(max_column - min_column) / maxf(span.x, 0.001), float(max_row - min_row) / maxf(span.y, 0.001)), 0.1, 1.0)
	var ppu := maxf(1.0, float(last_frame["pixelsPerTile"]) * float(last_frame.get("zoom", 1.0)) * fit)
	var center := (bounds_min + bounds_max) / 2.0
	camera.size = viewport.y / ppu
	# 비대칭 직교 투영을 카메라 수평·수직 오프셋으로 표현.
	camera.h_offset = center.x + (viewport.x / 2.0 - float(screen_center[0])) / ppu
	camera.v_offset = center.y + (float(screen_center[1]) - viewport.y / 2.0) / ppu


func _update_camera_visuals() -> void:
	for effect: Node3D in impacts.values():
		if effect.visible:
			effect.update_camera(camera)
	for entry: Dictionary in turrets.values():
		_update_weapon_camera(entry)


func presentation() -> Dictionary:
	if last_frame.is_empty():
		return {}
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return {}
	var origin := camera.unproject_position(Vector3(-columns / 2.0, 0.0, -rows / 2.0))
	var x_axis := camera.unproject_position(Vector3(1.0 - columns / 2.0, 0.0, -rows / 2.0)) - origin
	var y_axis := camera.unproject_position(Vector3(-columns / 2.0, 0.0, 1.0 - rows / 2.0)) - origin
	var height_axis := camera.unproject_position(Vector3(-columns / 2.0, 1.0, -rows / 2.0)) - origin
	return {
		"projection": {
			"origin": [origin.x / size.x, origin.y / size.y],
			"xAxis": [x_axis.x / size.x, x_axis.y / size.y],
			"yAxis": [y_axis.x / size.x, y_axis.y / size.y],
			"heightAxis": [height_axis.x / size.x, height_axis.y / size.y],
		},
		"sequence": last_sequence, "camera": camera_mode,
		"transitioning": is_instance_valid(camera_transition) and camera_transition.is_running(),
	}


func _report_presentation() -> void:
	# Android Java 싱글턴은 동적 호출이므로 Object.has_method 검사 생략.
	if bridge and not last_frame.is_empty():
		bridge.report_presentation(JSON.stringify(presentation()))


func _apply_frame(frame: Dictionary) -> void:
	if bool(frame.get("reset", false)):
		_clear_scene()
		return
	var map: Dictionary = frame.get("map", {})
	if map.is_empty():
		return
	if map != _current_map and not _build_terrain(map):
		return
	last_frame = frame
	last_sequence = int(frame.get("seq", -1))
	received_frames += 1
	_update_camera()
	_sync_turrets(frame.get("turrets", []))
	_sync_enemies(frame.get("enemies", []))
	_sync_projectiles(frame.get("projectiles", []))
	_sync_build_preview(frame.get("buildPreview"))
	_update_impacts(frame.get("impacts", []))
	var time := float(frame.get("time", 0.0))
	for portal in _portals:
		var pulse := 1.0 + sin(time * 3.0) * (0.012 + float(frame.get("portalAlert", 0.0)) * 0.018)
		portal.scale = Vector3(pulse, 1.0, pulse)
	for core in _cores:
		core.scale = Vector3(1.0, 1.0 + sin(time * 2.5) * 0.012 + float(frame.get("nexusHit", 0.0)) * 0.025, 1.0)


func _clear_scene() -> void:
	if camera_transition:
		camera_transition.kill()
	camera_mode = ""
	for collection: Dictionary in [turrets, enemies, projectiles]:
		for entry: Dictionary in collection.values():
			entry["root"].free()
		collection.clear()
	for pool: Array in _ballistic_pool.values():
		for projectile: Node3D in pool:
			projectile.free()
		pool.clear()
	if not _build_preview.is_empty():
		_build_preview["root"].free()
		_build_preview.clear()
	for effect: Node3D in impacts.values():
		effect.free()
	impacts.clear()
	for effect in impact_pool:
		effect.free()
	impact_pool.clear()
	for child in terrain.get_children():
		child.free()
	for light in impact_lights:
		light.light_energy = 0.0
	_portals.clear()
	_cores.clear()
	_current_map = {}
	last_frame = {}
	last_sequence = -1
	received_frames = 0
	standalone_playing = false
	standalone_time = 0.0
	_using_authored = false
	_build_tile_slots.clear()
	if _occupied_build_tiles != Vector2i.ZERO:
		_occupied_build_tiles = Vector2i.ZERO
		_foliage_material.set_shader_parameter("occupied_build_tiles", _occupied_build_tiles)


func _build_terrain(map: Dictionary) -> bool:
	var next_columns := int(map.get("columns", 0))
	var next_rows := int(map.get("rows", 0))
	var tiles: Array = map.get("tiles", [])
	if next_columns <= 0 or next_rows <= 0 or tiles.size() != next_columns * next_rows:
		_fail("3D 전장의 맵 크기와 타일 수가 맞지 않습니다.")
		return false
	columns = next_columns
	rows = next_rows
	for child in terrain.get_children():
		child.free()
	_portals.clear()
	_cores.clear()
	var authored := _terrain_library.find_child("stage1_environment", true, false)
	_using_authored = authored != null and int(_terrain_manifest.get("columns", 0)) == columns \
		and int(_terrain_manifest.get("rows", 0)) == rows and _terrain_manifest.get("tileTypes", []) == tiles
	_build_tile_slots.clear()
	if _using_authored:
		terrain.add_child(authored.duplicate())
		# 동일한 맵 원본에 배치된 환경 장식만 지형 수명에 연결.
		terrain.add_child(_dressing_library.duplicate())
		_build_tile_slots.resize(tiles.size())
		_build_tile_slots.fill(-1)
	var names := {"path": "path_tile", "build": "build_tile", "spawn": "portal", "core": "core"}
	var build_slot := 0
	for index in range(tiles.size()):
		var tile: String = tiles[index]
		if _using_authored and tile == "build":
			# Blender UV2와 같은 맵 순회의 건설칸 슬롯.
			_build_tile_slots[index] = build_slot
			build_slot += 1
		if tile == "blocked" or (_using_authored and tile != "spawn" and tile != "core"):
			continue
		if not names.has(tile):
			_fail("지원하지 않는 맵 타일: %s" % tile)
			return false
		var point := Vector3(float(index % columns) + 0.5 - columns / 2.0, 0.0, floor(float(index) / float(columns)) + 0.5 - rows / 2.0)
		if not _using_authored and (tile == "spawn" or tile == "core"):
			var foundation: Node3D = _terrain_library.find_child("path_tile", true, false).duplicate()
			foundation.position = point
			terrain.add_child(foundation)
		var model := _terrain_library.find_child(names[tile], true, false)
		if not model:
			_fail("지형 GLB 노드를 찾지 못했습니다: %s" % names[tile])
			return false
		var instance: Node3D = model.duplicate()
		instance.position = point
		terrain.add_child(instance)
		if tile == "spawn":
			_portals.append(instance)
		elif tile == "core":
			_cores.append(instance)
	# JSON 숫자형까지 보존해 같은 맵을 매 프레임 재생성하지 않음.
	_current_map = map.duplicate(true)
	return true


func _prepare_vertex_colors(model: Node) -> void:
	# GLB COLOR_0 보존: 일부 다중 primitive 재질의 누락된 사용 플래그 보정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material := mesh.get_active_material(surface)
			if colors != null and not colors.is_empty() and material is StandardMaterial3D:
				material.vertex_color_use_as_albedo = true


func _new_turret(type: String) -> Dictionary:
	var root: Node3D = TURRET_MODELS[type].instantiate()
	_prepare_vertex_colors(root)
	world.add_child(root)
	var barrel: Node3D = root.find_child("turret_barrel", true, false)
	var muzzle: Node3D = root.find_child("muzzle", true, false)
	var entry := {
		"root": root, "type": type, "head": root.find_child("turret_head", true, false),
		"barrel": barrel, "muzzle": muzzle, "barrel_rest_z": barrel.position.z,
		"flashes": [], "smokes": [], "smoke_starts": [-INF, -INF],
		"last_shot": -1, "last_time": -INF, "fire_start": -INF, "active_port": 0,
	}
	if type == "arrow":
		var effect := MachineGunMuzzle.new()
		root.add_child(effect)
		entry["muzzle_effect"] = effect
		return entry
	for index in range(2):
		var flash := WeaponAtlas.new()
		flash.configure(true)
		flash.position.x = (-0.062 if index == 0 else 0.062) if type == "arrow" else 0.0
		flash.position.z = 0.018
		muzzle.add_child(flash)
		entry["flashes"].append(flash)
		var smoke := WeaponAtlas.new()
		smoke.configure(false, Color("697586") if type == "arrow" else Color.WHITE)
		smoke.position.x = flash.position.x
		muzzle.add_child(smoke)
		entry["smokes"].append(smoke)
	return entry


func _sync_turrets(units: Array) -> void:
	var alive := {}
	var occupied := Vector2i.ZERO
	for data: Array in units:
		var id := int(data[0])
		# 구 검수 배열에만 cannon 기본값 사용. 명시된 다른 유형은 대체하지 않음.
		var type := str(data[6]) if data.size() > 6 else "cannon"
		if not TURRET_MODELS.has(type):
			_fail("스테이지 1에서 지원하지 않는 포탑: %s" % type)
			continue
		alive[id] = true
		if _using_authored:
			var x := floori(float(data[1]))
			var z := floori(float(data[2]))
			if x >= 0 and x < columns and z >= 0 and z < rows:
				var slot := _build_tile_slots[z * columns + x]
				if slot >= 0 and slot < 16:
					occupied.x |= 1 << slot
				elif slot >= 16 and slot < 32:
					occupied.y |= 1 << (slot - 16)
		if turrets.has(id) and turrets[id]["type"] != type:
			turrets[id]["root"].free()
			turrets.erase(id)
		if not turrets.has(id):
			turrets[id] = _new_turret(type)
		var entry: Dictionary = turrets[id]
		entry["root"].position = Vector3(float(data[1]) - columns / 2.0, 0.0, float(data[2]) - rows / 2.0)
		entry["head"].rotation.y = PI / 2.0 - float(data[3])
		_update_fire(entry, int(data[4]), float(data[5]))
	for id in turrets.keys():
		if not alive.has(id):
			turrets[id]["root"].free()
			turrets.erase(id)
	# 확정 포탑의 점유가 바뀔 때만 전장 전체의 중앙 풀 가림을 갱신.
	if occupied != _occupied_build_tiles:
		_occupied_build_tiles = occupied
		_foliage_material.set_shader_parameter("occupied_build_tiles", occupied)


func _update_fire(entry: Dictionary, shot_sequence: int, feedback: float) -> void:
	var time := float(last_frame.get("time", 0.0))
	if time < float(entry["last_time"]):
		entry["fire_start"] = -INF
		entry["smoke_starts"] = [-INF, -INF]
		if entry.has("muzzle_effect"):
			entry["muzzle_effect"].reset()
	var previous := int(entry["last_shot"])
	var fired := (previous >= 0 and previous != shot_sequence) or (previous < 0 and shot_sequence > 0 and feedback > 0.0)
	if fired:
		entry["fire_start"] = time
		entry["active_port"] = posmod(shot_sequence, 2)
		entry["smoke_starts"][entry["active_port"]] = time
	entry["last_shot"] = shot_sequence
	entry["last_time"] = time
	var age := maxf(0.0, time - float(entry["fire_start"]))
	var heavy: bool = entry["type"] == "cannon"
	var machine_gun: bool = entry["type"] == "arrow"
	var duration := 0.11 if heavy else (0.12 if machine_gun else 0.085)
	var recovery := 0.34 if heavy else (0.075 if machine_gun else 0.14)
	var kick := age / 0.018 if age < 0.018 else pow(clampf(1.0 - (age - 0.018) / recovery, 0.0, 1.0), 2.0)
	entry["barrel"].position.z = float(entry["barrel_rest_z"]) - kick * (0.12 if heavy else (0.025 if machine_gun else 0.045))
	if fired and (heavy or machine_gun):
		var muzzle: Node3D = entry["muzzle"]
		var pose := muzzle.global_transform.orthonormalized()
		pose.origin = muzzle.to_global(Vector3((0.062 if int(entry["active_port"]) == 1 else -0.062) if machine_gun else 0.0, 0.0, 0.018))
		entry["shot_pose"] = pose
	if machine_gun:
		# 최신 조준·반동 위치에서 이번 한 발만 기록. 건너뛴 순번은 재연하지 않음.
		if fired:
			entry["muzzle_effect"].fire(entry["muzzle"], time, shot_sequence)
		entry["muzzle_effect"].update_effect(entry["muzzle"], time, camera)
		return
	for index in range(2):
		var flash: MeshInstance3D = entry["flashes"][index]
		flash.visible = index == int(entry["active_port"]) and age < duration
		if flash.visible:
			var progress := age / duration
			flash.set_frame(floori(progress * 8.0), (1.0 - progress * 0.65) * (0.95 if heavy else 0.8))
			var growth := 0.8 + sin(progress * PI) * 0.35
			flash.display_size = Vector2(0.60 if heavy else (0.90 if machine_gun else 0.26), 0.29 if heavy else (0.70 if machine_gun else 0.18)) * growth
		var smoke: MeshInstance3D = entry["smokes"][index]
		var smoke_age := time - float(entry["smoke_starts"][index])
		var smoke_duration := 0.60 if heavy else (0.65 if machine_gun else 0.36)
		smoke.visible = smoke_age >= 0.0 and smoke_age < smoke_duration
		if smoke.visible:
			var progress := smoke_age / smoke_duration
			var opacity := 0.85 * (1.0 - progress * 0.35) if machine_gun else (0.35 if heavy else 0.17) * (1.0 - progress)
			smoke.set_frame(floori(progress * 8.0), opacity)
			smoke.display_angle = 0.18 * sin(float(index) + progress)
			smoke.position.y = 0.02 + progress * (0.17 if heavy else 0.09)
			smoke.position.z = 0.06 + progress * (0.14 if heavy else 0.07)
			var size := (0.25 if heavy else (0.80 if machine_gun else 0.11)) * (1.0 + progress * 1.4)
			smoke.display_size = Vector2(size, size)
	_update_weapon_camera(entry)


func _update_weapon_camera(entry: Dictionary) -> void:
	if entry.has("muzzle_effect"):
		entry["muzzle_effect"].update_camera(camera)
		return
	var muzzle: Node3D = entry["muzzle"]
	var source := camera.unproject_position(muzzle.global_position)
	var target := camera.unproject_position(muzzle.to_global(Vector3.BACK))
	var direction := target - source
	for flash: MeshInstance3D in entry["flashes"]:
		flash.display_angle = atan2(-direction.y, direction.x)
		flash.update_camera(camera)
	for smoke: MeshInstance3D in entry["smokes"]:
		smoke.update_camera(camera)


func _sync_enemies(units: Array) -> void:
	var alive := {}
	for data: Array in units:
		var id := int(data[0])
		var type := str(data[7]) if data.size() > 7 else "tank"
		if not ENEMY_MODELS.has(type):
			_fail("스테이지 1에서 지원하지 않는 적: %s" % type)
			continue
		alive[id] = true
		if enemies.has(id) and enemies[id]["type"] != type:
			enemies[id]["root"].free()
			enemies.erase(id)
		if not enemies.has(id):
			var model: Node3D = ENEMY_MODELS[type].instantiate()
			_prepare_vertex_colors(model)
			world.add_child(model)
			enemies[id] = {"root": model, "type": type}
		var root: Node3D = enemies[id]["root"]
		var hover := 0.025 if type in ["normal", "fast", "shielded"] else 0.008
		root.position = Vector3(float(data[1]) - columns / 2.0, sin(float(data[4])) * hover, float(data[2]) - rows / 2.0)
		root.rotation.y = PI / 2.0 - float(data[3])
		root.scale = Vector3.ONE * float(data[5])
	for id in enemies.keys():
		if not alive.has(id):
			enemies[id]["root"].free()
			enemies.erase(id)


func _sync_build_preview(data) -> void:
	var type := str(data[6]) if data is Array and data.size() > 6 else "cannon"
	if not _build_preview.is_empty() and (data == null or _build_preview["type"] != type):
		_build_preview["root"].free()
		_build_preview.clear()
	if not (data is Array) or data.size() < 6:
		return
	if not TURRET_MODELS.has(type):
		_fail("지원하지 않는 건설 미리보기 포탑: %s" % type)
		return
	if _build_preview.is_empty():
		_build_preview = _new_turret(type)
		for mesh: GeometryInstance3D in _build_preview["root"].find_children("*", "GeometryInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_preview["root"].position = Vector3(float(data[1]) - columns / 2.0, 0.10 + sin(float(last_frame.get("time", 0.0)) * 3.0) * 0.02, float(data[2]) - rows / 2.0)
	_build_preview["head"].rotation.y = PI / 2.0 - float(data[3])
	_build_preview["barrel"].position.z = _build_preview["barrel_rest_z"]


func _new_projectile(type: String) -> Node3D:
	if _ballistic_pool.has(type):
		var pool: Array = _ballistic_pool[type]
		if not pool.is_empty():
			return pool.pop_back()
		return BallisticProjectile.new(type)
	if not _projectile_meshes.has(type):
		var heavy := type == "cannon"
		var ballistic := type in ["cannon", "arrow", "sniper"]
		var radius := 0.028 if heavy else (0.011 if type == "sniper" else 0.009)
		var length := 0.13 if heavy else 0.075
		var material := StandardMaterial3D.new()
		if ballistic:
			material.albedo_color = Color("45494d") if heavy else Color("c8a269")
			material.metallic = 0.5 if heavy else 0.72
			material.roughness = 0.65 if heavy else 0.42
		else:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = PROJECTILE_COLORS[type]
		var body := CylinderMesh.new()
		body.top_radius = radius
		body.bottom_radius = radius
		body.height = length
		body.radial_segments = 8
		body.material = material
		var nose := CylinderMesh.new()
		nose.top_radius = 0.0
		nose.bottom_radius = radius
		nose.height = length * 0.32
		nose.radial_segments = 8
		nose.material = material
		var tracer_length := 0.10 if heavy else 0.13
		var tracer := CylinderMesh.new()
		tracer.top_radius = 0.007 if heavy else 0.0035
		tracer.bottom_radius = 0.002 if heavy else 0.0015
		tracer.height = tracer_length
		tracer.radial_segments = 5
		var tracer_material := StandardMaterial3D.new()
		tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color: Color = PROJECTILE_COLORS[type]
		color.a = 0.32 if heavy else 0.55
		tracer_material.albedo_color = color
		tracer.material = tracer_material
		_projectile_meshes[type] = {"meshes": [body, nose, tracer], "z": [0.0, length * 0.66, -(length + tracer_length) / 2.0]}
	var root := Node3D.new()
	root.name = "Projectile_" + type
	var template: Dictionary = _projectile_meshes[type]
	for index in range(3):
		var mesh := MeshInstance3D.new()
		mesh.mesh = template["meshes"][index]
		mesh.rotation.x = PI / 2.0
		mesh.position.z = float(template["z"][index])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	return root


func _sync_projectiles(units: Array) -> void:
	var alive := {}
	for data: Array in units:
		var id := int(data[0])
		var type := str(data[5]) if data.size() > 5 else "cannon"
		if not TURRET_MODELS.has(type):
			_fail("지원하지 않는 탄환: %s" % type)
			continue
		alive[id] = true
		if projectiles.has(id) and projectiles[id]["type"] != type:
			projectiles[id]["root"].free()
			projectiles.erase(id)
		if not projectiles.has(id):
			var model := _new_projectile(type)
			if not model.is_inside_tree():
				world.add_child(model)
			projectiles[id] = {"root": model, "type": type}
		var root: Node3D = projectiles[id]["root"]
		if root is BallisticProjectile:
			var pose = null
			if data.size() >= 12 and data[8] != null and not bool(data[10]):
				var owner: Dictionary = turrets.get(int(data[8]), {})
				if int(owner.get("last_shot", -1)) == int(data[9]):
					pose = owner.get("shot_pose")
			root.update_flight(data, float(last_frame.get("time", 0.0)), Vector3(-columns / 2.0, 0.0, -rows / 2.0), pose)
			continue
		root.position = Vector3(float(data[1]) - columns / 2.0, 0.56 if type == "cannon" else 0.45, float(data[2]) - rows / 2.0)
		root.rotation.y = PI / 2.0 - atan2(float(data[4]), float(data[3]))
	for id in projectiles.keys():
		if not alive.has(id):
			var projectile: Node3D = projectiles[id]["root"]
			var type: String = projectiles[id]["type"]
			if projectile is BallisticProjectile and _ballistic_pool[type].size() < 64:
				projectile.reset()
				_ballistic_pool[type].append(projectile)
			else:
				projectile.free()
			projectiles.erase(id)


func _update_impacts(units: Array) -> void:
	var alive := {}
	for light in impact_lights:
		light.light_energy = 0.0
	var light_index := 0
	for data: Array in units:
		var id := int(data[0])
		alive[id] = true
		if not impacts.has(id):
			var effect: Node3D
			if impact_pool.is_empty():
				effect = Impact.new()
				world.add_child(effect)
				effect.configure(field["texture"], field["manifest"])
			else:
				effect = impact_pool.pop_back()
			impacts[id] = effect
		var effect: Node3D = impacts[id]
		effect.visible = bool(options["volume"])
		effect.position = Vector3(float(data[1]) - columns / 2.0, 0, float(data[2]) - rows / 2.0)
		if effect.visible:
			effect.update_impact(float(data[4]), float(data[3]), id, camera)
			if float(data[4]) < 0.68 and light_index < impact_lights.size():
				var light := impact_lights[light_index]
				light.position = effect.position + Vector3(0, 0.3 + float(data[3]) * 0.12, 0)
				light.omni_range = float(data[3]) * 3.2
				light.light_energy = 1.6 * pow(1.0 - float(data[4]) / 0.68, 2)
				light_index += 1
	for id in impacts.keys():
		if not alive.has(id):
			var effect: Node3D = impacts[id]
			effect.visible = false
			impact_pool.append(effect)
			impacts.erase(id)


func _unhandled_key_input(event: InputEvent) -> void:
	if bridge or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: standalone_playing = not standalone_playing
		KEY_C: options["camera"] = "drone" if options["camera"] == "angled" else "angled"
		KEY_S: options["shadows"] = not options["shadows"]
		KEY_V: options["volume"] = not options["volume"]
	_apply_options()
