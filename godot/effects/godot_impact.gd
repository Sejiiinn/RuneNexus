extends Node3D
class_name GodotImpact

## 외부 전투 시계로 재생하는 1.1초 입체 착탄. 자체 _process나 카메라 평면 없음.
const DURATION: float = 1.1
const SPARK_COUNT: int = 56
const FRAGMENT_COUNT: int = 34
const HALF_EXTENT := Vector3(2.35, 1.45, 2.35)
const VOLUME_SHADER: Shader = preload("res://effects/cannon_impact.gdshader")
const SPARK_SHADER: Shader = preload("res://effects/cannon_impact_sparks.gdshader")
const FRAGMENT_SHADER: Shader = preload("res://effects/cannon_impact_fragments.gdshader")

static var _spark_mesh: ArrayMesh
static var _fragment_mesh: ArrayMesh
static var _particle_texture: ImageTexture

var _volume: MeshInstance3D
var _volume_material: ShaderMaterial
var _sparks: MultiMeshInstance3D
var _fragments: MultiMeshInstance3D
var _spark_material: ShaderMaterial
var _fragment_material: ShaderMaterial
var _times := PackedFloat64Array()
var _grid: int = 48
var _bricks := Vector3i(4, 4, 2)
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
		# 인스턴스는 정적 단위행렬. 운동은 절대 age에서 GPU가 재구성한다.
		for slot in range(instances.instance_count):
			instances.set_instance_transform(slot, Transform3D.IDENTITY)
		group.multimesh = instances
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(group)
	if _particle_texture == null:
		_initialize_particle_data()
	_spark_material = _particle_material(SPARK_SHADER)
	_fragment_material = _particle_material(FRAGMENT_SHADER)
	_sparks.material_override = _spark_material
	_fragments.material_override = _fragment_material
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
	# TIME/누적 delta를 쓰지 않아 정지·배속·되감기·풀 재사용이 같은 결과를 낸다.
	for material in [_spark_material, _fragment_material]:
		material.set_shader_parameter("u_age", age)
		material.set_shader_parameter("u_radius", radius)
		material.set_shader_parameter("u_angle", angle)


func update_camera(camera: Camera3D) -> void:
	# 시점 전환에서는 입자·수명 갱신 없이 광선만 동기화.
	var inverse: Transform3D = _volume.global_transform.affine_inverse()
	# 본게임 HUD 맞춤 오프셋을 포함한 실제 렌더 카메라.
	var camera_pose: Transform3D = camera.get_camera_transform()
	var camera_local: Vector3 = inverse * camera_pose.origin
	_volume_material.set_shader_parameter("u_view_to_local", inverse * camera_pose)
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


static func _initialize_particle_data() -> void:
	# seed와 난수 호출 순서는 기존 CPU 탄도의 초기조건과 동일하다.
	var particles: Array[Dictionary] = []
	var random := RandomNumberGenerator.new()
	random.seed = 1404
	for index in range(SPARK_COUNT + FRAGMENT_COUNT):
		var spark: bool = index < SPARK_COUNT
		var large: bool = not spark and index % 5 == 0
		particles.append({
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
	# 정밀도 손실이 큰 8-bit 색/half 대신 선형 RGBA32F 데이터 텍스처를 공유한다.
	# 열 0: angle/speed/rise/death, 1: delay/width/length/stretch, 2: spin.
	var image := Image.create(3, SPARK_COUNT + FRAGMENT_COUNT, false, Image.FORMAT_RGBAF)
	for index in range(particles.size()):
		var particle: Dictionary = particles[index]
		image.set_pixel(0, index, Color(
			particle["angle"], particle["speed"], particle["rise"], particle["death"]
		))
		image.set_pixel(1, index, Color(
			particle["delay"], particle["width"], particle["length"], particle["stretch"]
		))
		image.set_pixel(2, index, Color(particle["spin"], 0.0, 0.0, 0.0))
	_particle_texture = ImageTexture.create_from_image(image)


func _particle_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("u_particle_data", _particle_texture)
	return material


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
