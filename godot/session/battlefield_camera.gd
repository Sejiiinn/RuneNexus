extends Node
## Camera pose, projection and camera-lifetime caches. Scene wiring and presentation
## consumers stay in main; no scene/owner reference crosses this boundary.
signal pose_changed

const CAMERA_TRANSITION_SECONDS := 0.7
const CAMERA_DEPTH_MARGIN := 0.5

var camera: Camera3D
var camera_mode := ""
var camera_transition: Tween
var _camera_terrain_id := 0
var _camera_map_bounds := AABB()
var _camera_actor_bounds := AABB()
var _camera_envelope := AABB()
var _camera_enemy_scale := 1.0
var _camera_impact_radius := 0.0
var _camera_layout_revision := 0
var _camera_layout_key: Array = []
var _camera_layout_pose := Vector3.ZERO
var _collapse_camera_start: Dictionary = {}
var columns := 8
var rows := 10
var _tiles: Array = []
var _using_chapter_environment := false
var _using_forge := false
var _environment_bounds := AABB()
var _environment_points: Array = []


func _init(target: Camera3D) -> void:
	camera = target


func configure_geometry(map_size: Vector2i, tiles: Array, chapter_environment: bool,
		forge: bool, environment_bounds: AABB, environment_points: Array) -> void:
	columns = map_size.x
	rows = map_size.y
	_tiles = tiles
	_using_chapter_environment = chapter_environment
	_using_forge = forge
	_environment_bounds = environment_bounds
	_environment_points = environment_points


func invalidate_layout() -> void:
	_camera_layout_revision += 1
	_camera_layout_key.clear()


func reset() -> void:
	stop_transition()
	camera_mode = ""
	_collapse_camera_start.clear()
	invalidate_layout()


func stop_transition() -> void:
	if camera_transition:
		camera_transition.kill()


func _exit_tree() -> void:
	stop_transition()


func update_mode(requested_mode: String, forge: bool) -> void:
	if requested_mode != "drone":
		requested_mode = "angled"
	if requested_mode != camera_mode:
		var drone := requested_mode == "drone"
		var angled_position := Vector3(5, 20, 13) if forge else Vector3(5, 27, 13)
		var target_position := Vector3(0, 30, 0.001) if drone else angled_position
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
				pose_changed.emit()
			, 0.0, 1.0, CAMERA_TRANSITION_SECONDS)
		camera_mode = requested_mode


func fit_frame(visible_size: Vector2, last_frame: Dictionary, zoom: float,
		battle_rect: Rect2, native_session: bool) -> void:
	_fit_camera_depth()
	# 깊이는 움직이는 actor/impact를 따라 매번 갱신하고 평면 fit만 캐시한다.
	# global_transform은 tween 자세·거리도 포함. world shake는 평면 fit 입력이 아니다.
	var key: Array = [
		_camera_layout_revision, camera.global_transform, visible_size,
		last_frame.get("viewport", []), last_frame.get("screenCenter", []),
		last_frame.has("pixelsPerTile"), last_frame.get("pixelsPerTile", 0.0),
		last_frame.get("zoom", 1.0), zoom, columns, rows,
		battle_rect,
	]
	if key == _camera_layout_key:
		if native_session:
			camera.size = _camera_layout_pose.x
			camera.h_offset = _camera_layout_pose.y
			camera.v_offset = _camera_layout_pose.z
		return
	_camera_layout_key = key
	_fit_camera_layout(visible_size, last_frame, zoom, battle_rect)
	_camera_layout_pose = Vector3(camera.size,camera.h_offset,camera.v_offset)


func _fit_camera_layout(visible_size: Vector2, last_frame: Dictionary, zoom: float, battle_rect: Rect2) -> void:
	var formal := battle_rect.size.x > 0 and battle_rect.size.y > 0
	var logical_viewport: Array = last_frame.get("viewport", [])
	var screen_center: Array = last_frame.get("screenCenter", [])
	if formal:
		logical_viewport = [visible_size.x, visible_size.y]
		screen_center = [battle_rect.get_center().x, battle_rect.get_center().y]
	if not formal and (logical_viewport.size() != 2 or screen_center.size() != 2 or not last_frame.has("pixelsPerTile")):
		# HUD 없는 검수 화면은 기울어진 지형의 투영 폭·높이까지 포함.
		var aspect := visible_size.x / maxf(1.0, visible_size.y)
		if _using_chapter_environment:
			var rectangle := _environment_camera_rect()
			camera.size = maxf(rectangle.size.y + 0.16, (rectangle.size.x + 0.16) / aspect) / maxf(0.01, zoom)
			camera.h_offset = rectangle.get_center().x
			camera.v_offset = rectangle.get_center().y
			return
		var basis := camera.global_basis
		var width := absf(basis.x.x) * columns + absf(basis.x.z) * rows
		var height := absf(basis.y.x) * columns + absf(basis.y.z) * rows
		camera.size = maxf(height + 1.2, (width + 1.2) / aspect) / maxf(0.01, zoom)
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
	var tiles: Array = _tiles
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
	if _using_chapter_environment:
		# 절벽의 깊이·외곽과 배치 장식까지 같은 HUD 전장 영역 안에 수용한다.
		var rectangle := _environment_camera_rect().grow(0.08)
		bounds_min = bounds_min.min(rectangle.position)
		bounds_max = bounds_max.max(rectangle.end)
	if not bounds_min.is_finite():
		bounds_min = Vector2(-0.5, -0.5)
		bounds_max = Vector2(0.5, 0.5)
		min_column = 0
		max_column = 1
		min_row = 0
		max_row = 1
	var span := bounds_max - bounds_min
	var fit := clampf(minf(float(max_column - min_column) / maxf(span.x, 0.001), float(max_row - min_row) / maxf(span.y, 0.001)), 0.1, 1.0)
	var ppu := maxf(1.0, float(last_frame.get("pixelsPerTile", 1.0)) * float(last_frame.get("zoom", 1.0)) * fit)
	if formal:
		ppu = maxf(1.0, minf(battle_rect.size.x / maxf(span.x + 0.7, 1.0), battle_rect.size.y / maxf(span.y + 1.0, 1.0)) * zoom)
	var center := (bounds_min + bounds_max) / 2.0
	var target_center := Vector2(float(screen_center[0]), float(screen_center[1]))
	if _using_forge and not formal:
		# 화면 좌표는 전체 격자 중심이므로 비대칭 빈 테두리의 오프셋을 되돌린다.
		# 투영 경계는 이미 활성 타일 중심이며, 사용자 팬·줌은 그대로 유지한다.
		var grid_offset := Vector2(min_column + max_column - columns, min_row + max_row - rows) * 0.5
		target_center += grid_offset * float(last_frame["pixelsPerTile"]) * float(last_frame.get("zoom", 1.0))
	camera.size = viewport.y / ppu
	# 비대칭 직교 투영을 카메라 수평·수직 오프셋으로 표현.
	camera.h_offset = center.x + (viewport.x / 2.0 - target_center.x) / ppu
	camera.v_offset = center.y + (target_center.y - viewport.y / 2.0) / ppu


func _environment_camera_rect() -> Rect2:
	var inverse := camera.global_transform.affine_inverse()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	# 원본에서 준비한 실제 지형·소품의 지지점만 투영한다. 전체 AABB의 빈 모서리는 제외.
	var points: Array = _environment_points
	if not points.is_empty():
		for coordinate: Array in points:
			var point: Vector3 = inverse * Vector3(float(coordinate[0]), float(coordinate[1]), float(coordinate[2]))
			low = low.min(Vector2(point.x, point.y))
			high = high.max(Vector2(point.x, point.y))
		return Rect2(low, high - low)
	for index in range(8):
		var point: Vector3 = inverse * _environment_bounds.get_endpoint(index)
		low = low.min(Vector2(point.x, point.y))
		high = high.max(Vector2(point.x, point.y))
	return Rect2(low, high - low)


static func mesh_bounds(node: Node3D, parent_pose := Transform3D.IDENTITY) -> AABB:
	# 맵 생성·모델 캐시 준비 때만 순회. 매 프레임 메시를 조사하지 않는다.
	var pose: Transform3D = parent_pose * node.transform
	var bounds := AABB(pose.origin, Vector3.ZERO)
	if node is MeshInstance3D:
		bounds = pose * node.get_aabb()
	elif node is MultiMeshInstance3D and node.multimesh != null:
		bounds = pose * node.multimesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			bounds = bounds.merge(mesh_bounds(child, pose))
	return bounds


func update_envelope(terrain: Node3D, last_frame: Dictionary, map_size: Vector2i,
		model_libraries: Array) -> void:
	var columns := map_size.x
	var rows := map_size.y
	if terrain.get_child_count() == 0:
		return
	if _camera_actor_bounds.size == Vector3.ZERO:
		var models := AABB()
		for library: Dictionary in model_libraries:
			for packed: PackedScene in library.values():
				var model: Node3D = packed.instantiate()
				models = models.merge(mesh_bounds(model))
				model.free()
		# 공통 서리 결정의 최대 부착 길이도 포함한다.
		models = models.grow(0.2)
		# 적·포탑이 모든 방향으로 회전해도 담는 수평 반경.
		var radius := 0.0
		for index in range(8):
			var corner := models.get_endpoint(index)
			radius = maxf(radius, Vector2(corner.x, corner.z).length())
		_camera_actor_bounds = AABB(Vector3(-radius, models.position.y, -radius),
			Vector3(radius * 2.0, models.size.y, radius * 2.0))
	var terrain_id := terrain.get_child(0).get_instance_id()
	if terrain_id != _camera_terrain_id:
		_camera_terrain_id = terrain_id
		_camera_enemy_scale = 1.0
		_camera_impact_radius = 0.0
		_camera_map_bounds = AABB(Vector3(-columns / 2.0, 0.0, -rows / 2.0), Vector3(columns, 0.0, rows))
		_camera_map_bounds = _camera_map_bounds.merge(mesh_bounds(terrain).grow(0.05))
	# 브리지의 실제 크기를 수용하고 효과가 끝나도 맵 수명 동안 범위를 유지한다.
	# 발사·소멸마다 shadow map 범위가 왕복하는 것을 피한다.
	for data: Array in last_frame.get("enemies", []):
		_camera_enemy_scale = maxf(_camera_enemy_scale, absf(float(data[5])))
	for data: Array in last_frame.get("impacts", []):
		_camera_impact_radius = maxf(_camera_impact_radius, float(data[3]))
	for key in ["turrets", "enemies", "projectiles", "impacts"]:
		for data: Array in last_frame.get(key, []):
			_camera_map_bounds = _camera_map_bounds.expand(Vector3(float(data[1]) - columns / 2.0, 0.0, float(data[2]) - rows / 2.0))
			if key == "projectiles" and data.size() >= 12:
				_camera_map_bounds = _camera_map_bounds.expand(Vector3(float(data[6]) - columns / 2.0, 0.0, float(data[7]) - rows / 2.0))
				if data.size() >= 14 and data[12] != null and data[13] != null:
					_camera_map_bounds = _camera_map_bounds.expand(Vector3(float(data[12]) - columns / 2.0, 0.0, float(data[13]) - rows / 2.0))
	# 포구 연기는 총구에서 최대 0.37 전진 + 반길이 0.35, 위로 0.17 + 반폭 0.22.
	# 1타일 여유는 포구 화염·반동·건설 미리보기의 0.12 부유도 포함한다.
	var actor := AABB(_camera_actor_bounds.position * _camera_enemy_scale, _camera_actor_bounds.size * _camera_enemy_scale).grow(1.0)
	# 1.35타일 예광과 포탄 코끝을 포함. 폭발은 godot_impact.gd의 전체 입자 AABB.
	var horizontal := maxf(1.35, maxf(actor.end.x, 5.0 * _camera_impact_radius))
	var low := minf(_camera_map_bounds.position.y, minf(actor.position.y, -0.25 * _camera_impact_radius))
	var high := maxf(_camera_map_bounds.end.y, maxf(actor.end.y, 3.75 * _camera_impact_radius))
	_camera_envelope = AABB(Vector3(_camera_map_bounds.position.x - horizontal, low, _camera_map_bounds.position.z - horizontal),
		Vector3(_camera_map_bounds.size.x + 2.0 * horizontal, high - low, _camera_map_bounds.size.z + 2.0 * horizontal))


func _fit_camera_depth() -> void:
	if _camera_envelope.size == Vector3.ZERO:
		return
	# 직교 카메라는 sun.max_distance를 사용하지 않으므로 실제 수신 깊이를 제한.
	# h/v_offset는 시선에 수직인 이동이어서 깊이에 영향을 주지 않는다.
	var inverse := camera.global_transform.affine_inverse()
	var nearest := INF
	var farthest := -INF
	for index in range(8):
		var depth := -(inverse * _camera_envelope.get_endpoint(index)).z
		nearest = minf(nearest, depth)
		farthest = maxf(farthest, depth)
	camera.near = maxf(0.05, nearest - CAMERA_DEPTH_MARGIN)
	camera.far = maxf(camera.near + 1.0, farthest + CAMERA_DEPTH_MARGIN)


func world_shake_offset(effects: Dictionary, viewport: Array, actual_size: Vector2) -> Vector3:
	var shake: Array = effects.get("shake", [])
	if shake.size() != 2 or viewport.size() != 2:
		return Vector3.ZERO
	# 기존 Canvas의 logical pixel 이동을 현재 카메라의 화면 평면으로 옮긴다.
	var units_per_pixel := camera.size / maxf(float(viewport[1]), 1.0)
	var units_per_x_pixel := camera.size * actual_size.x / maxf(actual_size.y, 1.0) / maxf(float(viewport[0]), 1.0)
	return camera.global_basis.x * float(shake[0]) * units_per_x_pixel - camera.global_basis.y * float(shake[1]) * units_per_pixel


func apply_session_offsets(pan: Vector2, zoom: float, logical_size: Vector2,
		apply_pan: bool, collapsing: bool, core: Vector3, destruction_elapsed: float,
		actual_size: Vector2) -> bool:
	var camera_adjusted := false
	if apply_pan:
		camera_adjusted = true
		camera.h_offset -= pan.x * camera.size * logical_size.x / logical_size.y
		camera.v_offset += pan.y * camera.size
	if collapsing:
		if _collapse_camera_start.is_empty():
			_collapse_camera_start = {"size":camera.size,"h":camera.h_offset,"v":camera.v_offset,"zoom":zoom}
		var weight := 1.0 - pow(1.0-clampf(destruction_elapsed/1.15,0,1),3)
		camera.size = lerpf(_collapse_camera_start.size,_collapse_camera_start.size*_collapse_camera_start.zoom/1.75,weight)
		camera.h_offset = _collapse_camera_start.h
		camera.v_offset = _collapse_camera_start.v
		var screen := camera.unproject_position(core)
		var offset := screen-actual_size*Vector2(0.5,0.56)
		camera.h_offset += offset.x/actual_size.y*camera.size*weight
		camera.v_offset -= offset.y/actual_size.y*camera.size*weight
		camera_adjusted = true
	return camera_adjusted
