extends Node3D
class_name SniperEnergyBlast

## 폭발 젬 저격의 청록 에너지 폭발. 외부 전투 시계의 진행도로만 재생한다(자체 _process 없음).
## 섬광·후광·범위 직전까지 부푸는 에너지 껍질, 몸체 높이에서 뻗는 임팩트 갈래,
## 튀어 떨어지며 식는 불티, 실제 스플래시 반경에서 끝나는 끊긴 지면 충격파로 구성한다.
## 노드를 반경 배율로 키우므로 자식 좌표는 반경 1 기준이다. 모두 입체 메시이며
## 카메라를 향하는 평면은 쓰지 않는다. 운동은 셰이더가 u_age로 계산한다.
const DURATION: float = 0.6
const SPIKE_COUNT: int = 12
const SPARK_COUNT: int = 24
## 적 몸체 중심 높이(타일). 섬광·갈래·불티는 맞은 높이에서 터진다.
const HIT_HEIGHT: float = 0.42
## 지면 충격파 높이(타일).
const GROUND_HEIGHT: float = 0.035
const FLASH_SHADER: Shader = preload("res://effects/sniper_energy_blast_flash.gdshader")
const SHELL_SHADER: Shader = preload("res://effects/sniper_energy_blast_shell.gdshader")
const SPIKE_SHADER: Shader = preload("res://effects/sniper_energy_blast_spike.gdshader")
const SPARK_SHADER: Shader = preload("res://effects/sniper_energy_blast_spark.gdshader")
const RING_SHADER: Shader = preload("res://effects/sniper_energy_blast_ring.gdshader")
## 지면 충격파 평면의 반경(스플래시 반경 1 기준). 셰이더 EXTENT와 같다.
const RING_EXTENT: float = 1.05

static var _spike_mesh: ArrayMesh
static var _spark_mesh: ArrayMesh

var _flash: MeshInstance3D
var _halo: MeshInstance3D
var _shell: MeshInstance3D
var _ring: MeshInstance3D
var _spikes: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D
var _materials: Array[ShaderMaterial] = []
var _scattered_id: int = -1


func _init() -> void:
	name = "SniperEnergyBlast"
	if _spike_mesh == null: _spike_mesh = _build_spike_mesh()
	if _spark_mesh == null: _spark_mesh = _build_spark_mesh()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_flash = _mesh_child("Flash", sphere, FLASH_SHADER, {"tint": Vector3(2.4, 2.7, 2.8), "softness": 1.8,
		"scale_range": Vector2(0.125, 0.225), "grow_time": 0.05, "grow_power": 2.0, "fade_range": Vector2(0.03, 0.12), "peak": 1.0})
	_halo = _mesh_child("Halo", sphere, FLASH_SHADER, {"tint": Vector3(0.10, 0.75, 1.0), "softness": 2.6,
		"scale_range": Vector2(0.4, 0.65), "grow_time": 0.18, "grow_power": 1.0, "fade_range": Vector2(0.02, 0.26), "peak": 0.8})
	_shell = _mesh_child("Shell", sphere, SHELL_SHADER, {})
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * RING_EXTENT * 2.0
	_ring = _mesh_child("Shockwave", plane, RING_SHADER, {})
	_spikes = _multimesh_child("Spikes", _spike_mesh, SPIKE_COUNT, SPIKE_SHADER)
	_sparks = _multimesh_child("Sparks", _spark_mesh, SPARK_COUNT, SPARK_SHADER)
	visible = false


func update_impact(progress: float, radius: float, impact_id: int, _camera: Camera3D) -> void:
	progress = clampf(progress, 0.0, 1.0)
	visible = progress < 1.0
	if not visible:
		return
	radius = maxf(radius, 0.001)
	if impact_id != _scattered_id:
		_scatter(impact_id)
	scale = Vector3.ONE * radius
	# 높이는 반경과 무관한 실제 타일 높이로 둔다.
	for child: Node3D in [_flash, _halo, _spikes, _sparks]:
		child.position.y = HIT_HEIGHT / radius
	_ring.position.y = GROUND_HEIGHT / radius
	var age := progress * DURATION
	for material in _materials:
		material.set_shader_parameter("u_age", age)
	_sparks.material_override.set_shader_parameter("u_radius", radius)


## 착탄 공용 계약. 셰이더가 렌더 시점의 VIEW만 쓰므로 시점 전환에 갱신할 값이 없다.
func update_camera(_camera: Camera3D) -> void:
	pass


func reset() -> void:
	visible = false
	_scattered_id = -1


## 같은 ID는 같은 모양. 새 착탄에서 한 번만 자세를 기록한다.
func _scatter(impact_id: int) -> void:
	_scattered_id = impact_id
	var random := RandomNumberGenerator.new()
	random.seed = hash(impact_id)
	var seed_value := random.randf() * 97.0
	_shell.material_override.set_shader_parameter("u_seed", seed_value)
	_ring.material_override.set_shader_parameter("u_seed", seed_value)
	var offset := random.randf() * TAU
	for index in range(SPIKE_COUNT):
		var azimuth := offset + index * TAU / SPIKE_COUNT + random.randf_range(-0.22, 0.22)
		# 첫 갈래는 거의 수직으로 가장 길게, 나머지는 바깥·위로 뻗는다.
		var elevation := deg_to_rad(80.0) if index == 0 else random.randf_range(deg_to_rad(-8.0), deg_to_rad(48.0))
		var length := random.randf_range(0.6, 1.0) * (1.15 if index == 0 else 1.0)
		var width := random.randf_range(0.06, 0.095)
		_spikes.multimesh.set_instance_transform(index, _along(_direction(azimuth, elevation), length, width))
		_spikes.multimesh.set_instance_custom_data(index, Color(random.randf_range(0.0, 0.025), 0, 0, 0))
	for index in range(SPARK_COUNT):
		var azimuth := random.randf() * TAU
		var elevation := random.randf_range(deg_to_rad(10.0), deg_to_rad(65.0))
		var velocity := _direction(azimuth, elevation) * random.randf_range(1.6, 2.6)
		# xyz 초속(반경 기준), w 수명. 지연은 셰이더가 순번으로 정한다. 변환은 단위 행렬이어야
		# 셰이더가 계산한 위치가 그대로 쓰인다(MultiMesh 변환 버퍼의 초기값은 0이다).
		_sparks.multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		_sparks.multimesh.set_instance_custom_data(index, Color(velocity.x, velocity.y, velocity.z, random.randf_range(0.28, 0.5)))


static func _direction(azimuth: float, elevation: float) -> Vector3:
	return Vector3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation))


static func _along(direction: Vector3, length: float, width: float) -> Transform3D:
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001: side = Vector3.RIGHT
	side = side.normalized()
	var depth := side.cross(direction).normalized()
	return Transform3D(Basis(side * width, direction * length, depth * width), Vector3.ZERO)


func _mesh_child(child_name: String, mesh: Mesh, shader: Shader, parameters: Dictionary) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = child_name
	instance.mesh = mesh
	instance.material_override = _material(shader, parameters)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _multimesh_child(child_name: String, mesh: Mesh, count: int, shader: Shader) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = count
	var group := MultiMeshInstance3D.new()
	group.name = child_name
	group.multimesh = instances
	group.material_override = _material(shader, {})
	group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 최대 신장 기준 경계. 갈래·불티가 반경 1.5 안에 머문다.
	instances.custom_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3.0, 3.0, 3.0))
	add_child(group)
	return group


func _material(shader: Shader, parameters: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	for key: String in parameters:
		material.set_shader_parameter(key, parameters[key])
	_materials.append(material)
	return material


## 끝이 뾰족해지는 4면 갈래. y 0→0.35→1에서 단면 반폭 1→0.7→0(인스턴스 폭 배율로 줄임).
static func _build_spike_mesh() -> ArrayMesh:
	var corners: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var tip := Vector3(0, 1, 0)
	for index in range(4):
		var a := corners[index]
		var b := corners[(index + 1) % 4]
		var a0 := a
		var b0 := b
		var a1 := a * 0.7 + Vector3(0, 0.35, 0)
		var b1 := b * 0.7 + Vector3(0, 0.35, 0)
		for vertex in [a0, b0, b1, a0, b1, a1, a1, b1, tip]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()


## 불티: y 0(꼬리)→1(머리)의 4면 막대. 셰이더가 위치·방향·굵기를 정한다.
static func _build_spark_mesh() -> ArrayMesh:
	var corners: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var lift := Vector3(0, 1, 0)
	for index in range(4):
		var a := corners[index]
		var b := corners[(index + 1) % 4]
		for vertex in [a, b, b + lift, a, b + lift, a + lift]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()
