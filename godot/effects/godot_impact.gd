extends Node3D
class_name GodotImpact

## 외부 전투 시계로 재생하는 1.1초 입체 착탄. 자체 _process나 카메라 평면 없음.
const DURATION: float = 1.1
const SPARK_COUNT: int = 56
const FRAGMENT_COUNT: int = 34
const HALF_EXTENT := Vector3(2.35, 1.45, 2.35)
const VOLUME_SHADER: Shader = preload("res://effects/cannon_impact.gdshader")

static var _spark_mesh: ArrayMesh
static var _fragment_mesh: ArrayMesh

var _volume: MeshInstance3D
var _volume_material: ShaderMaterial
var _sparks: MultiMeshInstance3D
var _fragments: MultiMeshInstance3D
var _times := PackedFloat64Array()
var _grid: int = 48
var _bricks := Vector3i(4, 4, 2)
var _particles: Array[Dictionary] = []
var _configured: bool = false
var _last_radius: float = -1.0


func configure(field_texture: Texture3D, manifest: Dictionary) -> void:
	if _configured:
		push_error("착탄 효과의 공유 캐시는 한 번만 설정합니다.")
		return
	if field_texture == null or manifest.is_empty():
		push_error("착탄 효과에 유효한 공유 캐시가 필요합니다.")
		return
	_grid = int(manifest["gridSize"])
	var brick_values: Array = manifest["atlasBricks"]
	_bricks = Vector3i(int(brick_values[0]), int(brick_values[1]), int(brick_values[2]))
	for value in manifest["times"]:
		_times.append(float(value))
	_volume_material = ShaderMaterial.new()
	_volume_material.shader = VOLUME_SHADER
	_volume_material.set_shader_parameter("u_field", field_texture)
	_volume_material.set_shader_parameter("u_field_uv_scale", Vector3(
		float(_grid - 1) / float(_grid * _bricks.x),
		float(_grid - 1) / float(_grid * _bricks.y),
		float(_grid - 1) / float(_grid * _bricks.z)
	))
	_volume_material.set_shader_parameter("u_density_scale", float(manifest["densityScale"]))
	_volume_material.set_shader_parameter("u_emission_scale", float(manifest["emissionScale"]))
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	_volume = MeshInstance3D.new()
	_volume.name = "CannonImpactVolume"
	_volume.mesh = box
	_volume.material_override = _volume_material
	_volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_volume)
	if _spark_mesh == null:
		_spark_mesh = _build_spark_mesh()
	if _fragment_mesh == null:
		_fragment_mesh = _build_fragment_mesh()
	_sparks = MultiMeshInstance3D.new()
	_sparks.name = "CannonImpactSparks"
	_fragments = MultiMeshInstance3D.new()
	_fragments.name = "CannonImpactFragments"
	for group in [_sparks, _fragments]:
		var spark: bool = group == _sparks
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = _spark_mesh if spark else _fragment_mesh
		instances.instance_count = SPARK_COUNT if spark else FRAGMENT_COUNT
		group.multimesh = instances
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(group)
	var random := RandomNumberGenerator.new()
	random.seed = 1404
	for index in range(SPARK_COUNT + FRAGMENT_COUNT):
		var spark: bool = index < SPARK_COUNT
		var large: bool = not spark and index % 5 == 0
		_particles.append({
			"angle": random.randf() * TAU,
			"speed": 1.8 + random.randf() * 3.8 if spark else 1.4 + random.randf() * 3.1,
			"rise": 1.2 + random.randf() * 3.6 if spark else 1.3 + random.randf() * 3.1,
			"death": 0.19 + random.randf() * 0.39 if spark else 0.65 + random.randf() * 0.43,
			"delay": random.randf() * 0.018,
			"width": (0.0025 + random.randf() * 0.0035) if spark else (
				(0.12 + random.randf() * 0.06) if large else (0.032 + random.randf() * 0.052)
			),
			"length": 0.045 + random.randf() * 0.085,
			"stretch": 0.55 + random.randf() * 1.1,
			"spin": 3.0 + random.randf() * 8.0,
		})
	_configured = true
	visible = false


func update_impact(progress: float, radius: float, impact_id: int, camera: Camera3D) -> void:
	if not _configured or camera == null:
		visible = false
		return
	progress = clampf(progress, 0.0, 1.0)
	radius = maxf(radius, 0.001)
	var age: float = progress * DURATION
	var angle: float = float(posmod(impact_id, 23)) * 0.317
	visible = progress < 1.0
	if not visible:
		return
	_volume.position = Vector3(0.0, HALF_EXTENT.y * radius, 0.0)
	_volume.scale = HALF_EXTENT * radius
	_sparks.visible = age < 0.6
	if radius != _last_radius:
		# 전체 탄도 포함 경계. 카메라 밖 조각의 재등장 시 잘림 방지.
		var bounds := AABB(Vector3(-5.0, -0.25, -5.0) * radius, Vector3(10.0, 4.0, 10.0) * radius)
		_sparks.multimesh.custom_aabb = bounds
		_fragments.multimesh.custom_aabb = bounds
		_last_radius = radius
	var frame: int = 0
	while frame < _times.size() - 2 and _times[frame + 1] < age:
		frame += 1
	var blend: float = clampf((age - _times[frame]) / (_times[frame + 1] - _times[frame]), 0.0, 1.0)
	_volume_material.set_shader_parameter("u_age", age)
	_volume_material.set_shader_parameter("u_progress", progress)
	_volume_material.set_shader_parameter("u_angle", angle)
	_volume_material.set_shader_parameter("u_field_mix", blend)
	_volume_material.set_shader_parameter("u_field_frame_0", _frame_offset(frame))
	_volume_material.set_shader_parameter("u_field_frame_1", _frame_offset(frame + 1))
	update_camera(camera)
	for index in range(_particles.size()):
		var particle: Dictionary = _particles[index]
		var spark: bool = index < SPARK_COUNT
		var instances: MultiMesh = _sparks.multimesh if spark else _fragments.multimesh
		var slot: int = index if spark else index - SPARK_COUNT
		var time: float = maxf(0.0, age - float(particle["delay"]))
		var drag: float = 1.8 if spark else 0.75
		var travel: float = (1.0 - exp(-drag * time)) / drag
		var gravity: float = 4.8 if spark else 5.4
		var rise: float = float(particle["rise"])
		var height: float = 0.055 + rise * time - gravity * time * time
		var heading: float = float(particle["angle"]) + angle
		var velocity_x: float = cos(heading) * float(particle["speed"])
		var velocity_z: float = sin(heading) * float(particle["speed"])
		var origin := Vector3(velocity_x * travel, height, velocity_z * travel) * radius
		var rotation_basis := Basis.IDENTITY
		var particle_scale := Vector3.ZERO
		var death: float = float(particle["death"])
		if age >= float(particle["delay"]) and time <= death and height >= 0.014:
			var width: float = float(particle["width"])
			if spark:
				var direction := Vector3(
					velocity_x * exp(-drag * time), rise - 2.0 * gravity * time,
					velocity_z * exp(-drag * time)
				).normalized()
				rotation_basis = Basis(Quaternion(Vector3.BACK, direction))
				particle_scale = Vector3(width, width, float(particle["length"]) * (1.0 - time / death)) * radius
			else:
				var spin: float = float(particle["spin"])
				rotation_basis = Basis.from_euler(Vector3(
					time * spin + float(index), time * spin * 0.73, time * spin * 1.31
				), EULER_ORDER_XYZ)
				var fade: float = clampf((death - time) / 0.11, 0.0, 1.0)
				particle_scale = Vector3(width, width * float(particle["stretch"]), width) * radius * fade
		instances.set_instance_transform(slot, Transform3D(rotation_basis * Basis.from_scale(particle_scale), origin))


func update_camera(camera: Camera3D) -> void:
	# 시점 전환에서는 입자·수명 갱신 없이 광선만 동기화.
	var inverse: Transform3D = _volume.global_transform.affine_inverse()
	# 본게임 HUD 맞춤 오프셋을 포함한 실제 렌더 카메라.
	var camera_pose: Transform3D = camera.get_camera_transform()
	var camera_local: Vector3 = inverse * camera_pose.origin
	_volume_material.set_shader_parameter("u_camera_local", camera_local)
	_volume_material.set_shader_parameter("u_camera_inside",
		absf(camera_local.x) < 1.0 and absf(camera_local.y) < 1.0 and absf(camera_local.z) < 1.0)
	_volume_material.set_shader_parameter("u_orthographic", camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	# Godot 카메라의 전방은 -Z. 비균일 박스 배율까지 역변환한 로컬 광선.
	_volume_material.set_shader_parameter("u_ray_direction", (inverse.basis * -camera_pose.basis.z).normalized())


func _frame_offset(index: int) -> Vector3:
	# 복셀 중심 안의 좌표만 사용해 다른 시간 brick으로 선형 보간되지 않도록 제한.
	return Vector3(
		(float(index % _bricks.x) + 0.5 / float(_grid)) / float(_bricks.x),
		(float(floori(float(index) / float(_bricks.x)) % _bricks.y) + 0.5 / float(_grid)) / float(_bricks.y),
		(float(floori(float(index) / float(_bricks.x * _bricks.y))) + 0.5 / float(_grid)) / float(_bricks.z)
	)


static func _build_spark_mesh() -> ArrayMesh:
	var points: Array[Vector3] = [
		Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, -1, 0),
		Vector3(0, 1, 0), Vector3(0, 0, -0.5), Vector3(0, 0, 0.5)
	]
	var indices: Array[int] = [0, 3, 5, 3, 1, 5, 1, 2, 5, 2, 0, 5, 3, 0, 4, 1, 3, 4, 2, 1, 4, 0, 2, 4]
	var vertices := PackedVector3Array()
	for index in indices:
		vertices.append(points[index])
	var mesh: ArrayMesh = _triangle_mesh(vertices)
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = vec3(6.0, 1.45, 0.14); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	return mesh


static func _build_fragment_mesh() -> ArrayMesh:
	var rim: Array[Vector2] = [
		Vector2(-0.95, -0.50), Vector2(-0.20, -0.90), Vector2(0.78, -0.64),
		Vector2(0.53, -0.08), Vector2(1.0, 0.61), Vector2(0.19, 0.38),
		Vector2(-0.35, 0.91), Vector2(-0.70, 0.19)
	]
	var vertices := PackedVector3Array()
	for index in range(rim.size()):
		var a: Vector2 = rim[index]
		var b: Vector2 = rim[(index + 1) % rim.size()]
		var front_a := Vector3(a.x, a.y, 0.12 + float(index % 3) * 0.045)
		var front_b := Vector3(b.x, b.y, 0.12 + float((index + 1) % 3) * 0.045)
		var back_a := Vector3(a.x * 0.87, a.y * 0.94, -0.17)
		var back_b := Vector3(b.x * 0.87, b.y * 0.94, -0.17)
		vertices.append_array(PackedVector3Array([
			Vector3(0.04, -0.03, 0.36), front_a, front_b,
			Vector3(-0.07, 0.04, -0.21), back_b, back_a,
			front_a, back_a, back_b, front_a, back_b, front_b
		]))
	var mesh: ArrayMesh = _triangle_mesh(vertices)
	var material := StandardMaterial3D.new()
	# StandardMaterial 색 입력은 sRGB, 기존 three의 RGB는 선형값.
	material.albedo_color = Color(0.019, 0.020, 0.021).linear_to_srgb()
	material.metallic = 0.48
	material.roughness = 0.72
	mesh.surface_set_material(0, material)
	return mesh


static func _triangle_mesh(source: PackedVector3Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in range(0, source.size(), 3):
		var a: Vector3 = source[index]
		var b: Vector3 = source[index + 1]
		var c: Vector3 = source[index + 2]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		# Godot의 시계 방향 앞면 규약. 원본 파단면 법선은 유지.
		vertices.append_array(PackedVector3Array([a, c, b]))
		normals.append_array(PackedVector3Array([normal, normal, normal]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
