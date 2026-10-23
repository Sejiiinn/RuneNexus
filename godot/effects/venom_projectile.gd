extends Node3D

## 독 포탑의 포물선 독액. 전투는 평면에서 대상을 따라가며, 화면은 포구에서
## 착탄 지점까지 높이만 더한다. 착탄 지점은 프레임의 end 필드로 받는다.
## 무거운 독액 덩어리가 진행 방향으로 늘어지고, 뒤로 끈적한 꼬리와 떨어지는 방울을 남긴다.
## 멀리서도 궤적이 읽히도록 지나온 포물선을 따라 가늘어지며 옅어지는 독기 꼬리를 그린다.
const FrameRows = preload("res://presentation/frame_rows.gd")
const Goo = preload("res://effects/venom_goo.gd")
const TAIL_COUNT := 5
const DRIP_COUNT := 3
const LAND_HEIGHT := 0.32
const GLOB_RADIUS := 0.12
## 비행 진행률을 대략의 초로 바꾸는 값(타일/초). 떨어지는 방울의 낙하에만 쓴다.
const FLIGHT_TILES_PER_SECOND := 7.2
const GRAVITY := 9.0
## 꼬리가 덮는 비행 진행률 길이, 궤적 표본 수, 단면 변 수, 머리 쪽 반지름.
const STREAK_SPAN := 0.4
const STREAK_SAMPLES := 14
const STREAK_SIDES := 6
const STREAK_RADIUS := 0.08
static var _streak_material: StandardMaterial3D

## 덩어리·꼬리·방울 크기 배율. 독액 웅덩이 특성처럼 한 발이 무거운 공격을 더 크게 보인다.
const VENOM_POOL_SCALE := 1.3
var size_scale := 1.0

var glob := MeshInstance3D.new()
var tail: MultiMeshInstance3D
var streak := MeshInstance3D.new()
var _streak_mesh := ImmediateMesh.new()
var launch_position := Vector3.ZERO
var initialized := false


func _init() -> void:
	name = "Projectile_poison"
	glob.mesh = Goo.drop_mesh()
	glob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glob)
	tail = Goo.drops(TAIL_COUNT + DRIP_COUNT, 12.0)
	add_child(tail)
	if _streak_material == null:
		_streak_material = StandardMaterial3D.new()
		_streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_streak_material.vertex_color_use_as_albedo = true
		_streak_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_streak_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	streak.mesh = _streak_mesh
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(streak)
	reset()


func reset() -> void:
	initialized = false
	visible = false
	size_scale = 1.0
	_streak_mesh.clear_surfaces()


func update_flight(row: FrameRows.Projectile, map_offset: Vector3, muzzle_pose = null) -> void:
	var ground := Vector3(row.x, 0.0, row.y) + map_offset
	if not initialized:
		launch_position = Vector3(row.start_x, 0.5, row.start_y) + map_offset
		if muzzle_pose is Transform3D: launch_position = muzzle_pose.origin
		initialized = true
	var landing := Vector3(row.end_x, 0.0, row.end_y) + map_offset if row.has_end else ground
	var start := Vector3(launch_position.x, 0.0, launch_position.z)
	var travelled := start.distance_to(ground)
	var remaining := ground.distance_to(landing)
	var total := maxf(0.001, travelled + remaining)
	var height := 0.35 + 0.3 * total
	var progress := travelled / total
	visible = true
	global_transform = Transform3D.IDENTITY
	var point := _arc_point(start, ground, 1.0, progress, height)
	var ahead := _arc_point(start, ground, 1.0 + 0.02 / maxf(0.001, progress), progress + 0.02, height)
	var velocity := ahead - point
	# 덩어리가 출렁이며 진행 방향으로 늘어진다.
	var wobble := 1.0 + 0.1 * sin(progress * 38.0)
	var glob_radius := GLOB_RADIUS * size_scale
	glob.transform = Goo.stretched(point, velocity, glob_radius, 1.35 * wobble)
	_draw_streak(start, ground, progress, height)
	var instances := tail.multimesh
	for index in range(TAIL_COUNT):
		var lag := progress - 0.016 * (index + 1)
		if lag <= 0.0:
			instances.set_instance_transform(index, Goo.stretched(point, velocity, 0.0, 1.0))
			continue
		var along := lag / maxf(0.001, progress)
		var at := _arc_point(start, ground, along, lag, height)
		var lead := _arc_point(start, ground, along + 0.02, lag + 0.02, height)
		instances.set_instance_transform(index, Goo.stretched(at, lead - at, glob_radius * (0.78 - 0.13 * index), 1.9))
	for index in range(DRIP_COUNT):
		# 비행 중간중간 덩어리에서 떨어져 나와 아래로 떨어지는 방울.
		var released := 0.18 + 0.22 * index
		var slot := TAIL_COUNT + index
		var seconds := (progress - released) * total / FLIGHT_TILES_PER_SECOND
		if seconds <= 0.0 or seconds > 0.35:
			instances.set_instance_transform(slot, Goo.stretched(point, velocity, 0.0, 1.0))
			continue
		var origin := _arc_point(start, ground, released / maxf(0.001, progress), released, height)
		var fall := Vector3(0.0, -GRAVITY * seconds, 0.0)
		var at := origin + velocity.normalized() * seconds * 0.6 + Vector3(0.0, -0.5 * GRAVITY * seconds * seconds, 0.0)
		instances.set_instance_transform(slot, Goo.stretched(at, fall + velocity.normalized(), glob_radius * 0.32 * (1.0 - seconds / 0.35), 1.8))


# 머리에서 꼬리로 갈수록 가늘고 옅어지는 관. 머리는 밝은 독초록, 꼬리는 짙은 녹색.
func _draw_streak(start: Vector3, ground: Vector3, progress: float, height: float) -> void:
	_streak_mesh.clear_surfaces()
	var span := minf(STREAK_SPAN, progress)
	if span < 0.02:
		return
	var points: Array[Vector3] = []
	for index in range(STREAK_SAMPLES):
		var lag := progress - span * float(index) / float(STREAK_SAMPLES - 1)
		points.append(_arc_point(start, ground, lag / maxf(0.001, progress), lag, height))
	var rings: Array = []
	for index in range(STREAK_SAMPLES):
		var forward := (points[maxi(index - 1, 0)] - points[mini(index + 1, STREAK_SAMPLES - 1)]).normalized()
		var side := forward.cross(Vector3.UP)
		if side.length_squared() < 0.0001: side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(forward).normalized()
		var fade := 1.0 - float(index) / float(STREAK_SAMPLES - 1)
		var radius := STREAK_RADIUS * size_scale * (0.25 + 0.75 * fade) * fade
		var ring: Array[Vector3] = []
		for corner in range(STREAK_SIDES):
			var angle := TAU * float(corner) / float(STREAK_SIDES)
			ring.append(points[index] + (side * cos(angle) + up * sin(angle)) * radius)
		rings.append([ring, Color(0.2, 0.72, 0.26).lerp(Color(0.05, 0.32, 0.09), 1.0 - fade), 0.6 * pow(fade, 1.4)])
	_streak_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _streak_material)
	for index in range(STREAK_SAMPLES - 1):
		var a: Array = rings[index]
		var b: Array = rings[index + 1]
		var color_a := Color(a[1], a[2])
		var color_b := Color(b[1], b[2])
		for corner in range(STREAK_SIDES):
			var next := (corner + 1) % STREAK_SIDES
			for vertex: Array in [[a, corner, color_a], [b, corner, color_b], [b, next, color_b], [a, corner, color_a], [b, next, color_b], [a, next, color_a]]:
				_streak_mesh.surface_set_color(vertex[2])
				_streak_mesh.surface_add_vertex(vertex[0][0][vertex[1]])
	_streak_mesh.surface_end()


# along: 발사점→현재 지면 위치 보간, progress: 전체 비행 진행률.
func _arc_point(start: Vector3, ground: Vector3, along: float, progress: float, height: float) -> Vector3:
	var point := start.lerp(ground, clampf(along, 0.0, 1.2))
	point.y = lerpf(launch_position.y, LAND_HEIGHT, progress) + height * 4.0 * progress * (1.0 - progress)
	return point
