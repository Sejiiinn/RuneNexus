extends Node3D
const EffectFormat = preload("res://combat/effect_presentation.gd")

## 기관총 명중의 입체 도탄 불티. 명중마다 고정 슬롯에 시작 시각·자세를 한 번
## 기록하고, 불티 운동과 소멸은 공유 전투 시계로 GPU가 재구성한다.
## 표시 전용이며 전투 판정·피해·저장에 관여하지 않는다.
const SPARK_SHADER = preload("res://effects/machinegun_ricochet.gdshader")
const FLARE_SHADER = preload("res://effects/machinegun_ricochet_flare.gdshader")
const SLOTS := 32
const SPARKS_PER_HIT := 7
const SPARK_LIFE := 0.17
const GLOW_LIFE := 0.08
const MAX_LIGHTS := 2
## 기관총 탄체·예광의 비행 높이와 같다.
const HEIGHT := 0.45
const INACTIVE := -100000.0
static var _spark_mesh: ArrayMesh
static var _flare_mesh: ArrayMesh

var sparks := MultiMeshInstance3D.new()
var flares := MultiMeshInstance3D.new()
var spark_material := ShaderMaterial.new()
var flare_material := ShaderMaterial.new()
var lights: Array[OmniLight3D] = []
## 표시 이벤트 ID → 슬롯. 늦게 도착해 이미 끝난 명중은 -1로 기록해 재생하지 않는다.
var active := {}
var slot_starts := PackedFloat64Array()
var slot_points: Array[Vector3] = []
var next_slot := 0
var _base_time := 0.0
var _last_time := -INF


func _init() -> void:
	name = "MachinegunRicochet"
	if _spark_mesh == null:
		_spark_mesh = _build_spark_mesh()
		_flare_mesh = _build_flare_mesh()
	spark_material.shader = SPARK_SHADER
	flare_material.shader = FLARE_SHADER
	for pair in [[sparks, _spark_mesh, spark_material, SLOTS * SPARKS_PER_HIT], [flares, _flare_mesh, flare_material, SLOTS]]:
		var group: MultiMeshInstance3D = pair[0]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		instances.mesh = pair[1]
		instances.instance_count = pair[3]
		group.multimesh = instances
		group.material_override = pair[2]
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 인스턴스 자세는 맵 어디든 놓이고 GPU가 불티를 최대 약 0.8타일 움직인다.
		group.custom_aabb = AABB(Vector3(-24, -2, -24), Vector3(48, 8, 48))
		group.set_meta("exclude_selection_mask", true)
		add_child(group)
	sparks.name = "RicochetSparks"
	flares.name = "RicochetFlares"
	slot_starts.resize(SLOTS)
	slot_points.resize(SLOTS)
	for index in range(MAX_LIGHTS):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.62, 0.24)
		lamp.light_energy = 0.0
		# 촘촘한 행렬에서 이웃 몸체까지 번지지 않는 반경.
		lamp.omni_range = 0.28
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		lights.append(lamp)
	reset()


static func handles(effect: Dictionary) -> bool:
	return EffectFormat.is_spatial_ricochet(effect)


func reset() -> void:
	active.clear()
	next_slot = 0
	_last_time = -INF
	_clear_slots()
	for lamp in lights:
		lamp.visible = false
		lamp.light_energy = 0.0


func _clear_slots() -> void:
	# GPU는 기준 시각 대비 상대 시작 시각만 안다. 기준을 바꾸기 전 모든 슬롯을 비워
	# 이전 기준의 불티가 새 기준에서 다시 재생되지 않게 한다.
	slot_starts.fill(INACTIVE)
	sparks.visible = false
	flares.visible = false
	for index in range(SLOTS * SPARKS_PER_HIT):
		sparks.multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		sparks.multimesh.set_instance_custom_data(index, Color(INACTIVE, 0, 0, 0))
	for index in range(SLOTS):
		flares.multimesh.set_instance_transform(index, Transform3D.IDENTITY)
		flares.multimesh.set_instance_custom_data(index, Color(INACTIVE, 0, 0, 0))


## items: 효과 표시 노드의 현재 항목. enemy_rows: 전투 프레임의 적 행.
## time: 효과 항목의 age와 같은 증분으로 진행하는 프레임 시계.
func present(items: Array, enemy_rows: Array, map_size: Vector2, time: float, enabled: bool) -> void:
	visible = enabled
	if not enabled:
		if not active.is_empty() or _last_time > -INF: reset()
		return
	if time + 0.000001 < _last_time:
		# 새 전투·되감기에서는 이전 시계의 불티를 이어 그리지 않는다.
		reset()
	if _last_time == -INF:
		_base_time = time
	elif time - _base_time > 600.0 and not _any_alive(time):
		_clear_slots()
		_base_time = time
	_last_time = time
	var seen := {}
	var offsets := {}
	var offsets_loaded := false
	for item: Dictionary in items:
		if not handles(item): continue
		var id := int(item.get("id", -1))
		if id < 0: continue
		seen[id] = true
		if active.has(id): continue
		var age := float(item.get("age", 0.0))
		if age < 0.0 or age >= SPARK_LIFE:
			active[id] = -1
			continue
		if not offsets_loaded:
			# 명중점은 논리 좌표다. 맞은 몸체의 차선 표시 오프셋만 더한다.
			for row: Array in enemy_rows:
				if row.size() >= 14:
					offsets[int(row[0])] = Vector2(float(row[1]) - float(row[12]), float(row[2]) - float(row[13]))
			offsets_loaded = true
		var point := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
		point += offsets.get(int(item.get("targetId", -1)), Vector2.ZERO)
		var direction: Array = item.get("direction", [])
		_spawn(id, Vector3(point.x - map_size.x / 2.0, HEIGHT, point.y - map_size.y / 2.0),
			Vector3(float(direction[0]), 0.0, float(direction[1])), time - age)
	for id in active.keys():
		if not seen.has(id): active.erase(id)
	var relative := float(time - _base_time)
	spark_material.set_shader_parameter("u_time", relative)
	flare_material.set_shader_parameter("u_time", relative)
	# 살아 있는 명중이 없으면 두 MultiMesh의 정점 처리·드로우를 건너뛴다.
	var alive := _any_alive(time)
	sparks.visible = alive
	flares.visible = alive
	_update_lights(time)


func _spawn(id: int, point: Vector3, incoming: Vector3, start: float) -> void:
	var slot := next_slot
	next_slot = (next_slot + 1) % SLOTS
	active[id] = slot
	slot_starts[slot] = start
	slot_points[slot] = point
	var outward := -incoming.normalized() if incoming.length_squared() > 0.000001 else Vector3.BACK
	var side := Vector3.UP.cross(outward).normalized()
	var basis := Basis(side, Vector3.UP, outward)
	var custom_start := float(start - _base_time)
	var seed := float(posmod(id, 997)) * 0.61803
	for index in range(SPARKS_PER_HIT):
		var instance := slot * SPARKS_PER_HIT + index
		sparks.multimesh.set_instance_transform(instance, Transform3D(basis, point + outward * 0.02))
		sparks.multimesh.set_instance_custom_data(instance, Color(custom_start, seed, float(index), 0.0))
	# 접점 섬광은 몸체 표면 바로 앞에 두어 메시 안에 묻히지 않게 한다.
	flares.multimesh.set_instance_transform(slot, Transform3D(basis, point + outward * 0.05))
	flares.multimesh.set_instance_custom_data(slot, Color(custom_start, seed, 0.0, 0.0))


func _any_alive(time: float) -> bool:
	for start in slot_starts:
		if time - start < SPARK_LIFE: return true
	return false


func _update_lights(time: float) -> void:
	# 가장 최근 명중 두 곳만 짧게 주변 표면을 밝힌다. 명중마다 광원을 만들지 않는다.
	var candidates: Array = []
	for slot in range(SLOTS):
		var age := time - slot_starts[slot]
		if age >= 0.0 and age < GLOW_LIFE: candidates.append([age, slot])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	for index in range(lights.size()):
		var lamp := lights[index]
		lamp.visible = index < candidates.size()
		if not lamp.visible:
			lamp.light_energy = 0.0
			continue
		var age: float = candidates[index][0]
		var point: Vector3 = slot_points[candidates[index][1]]
		lamp.position = point + Vector3.UP * 0.03
		lamp.light_energy = 0.35 * pow(1.0 - age / GLOW_LIFE, 2.0)


func clear() -> void:
	reset()


static func _build_spark_mesh() -> ArrayMesh:
	# 대포 착탄 불티와 같은 가는 쐐기 팔면체. 길이·폭은 셰이더가 정한다.
	var points: Array[Vector3] = [
		Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, -1, 0),
		Vector3(0, 1, 0), Vector3(0, 0, -0.5), Vector3(0, 0, 0.5)
	]
	var indices: Array[int] = [0, 3, 5, 3, 1, 5, 1, 2, 5, 2, 0, 5, 3, 0, 4, 1, 3, 4, 2, 1, 4, 0, 2, 4]
	var vertices := PackedVector3Array()
	for index in indices:
		vertices.append(points[index])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_flare_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	# 백열 핵: 저해상도 구. 반지름 0.048타일.
	var sphere := SphereMesh.new()
	sphere.radius = 0.048
	sphere.height = 0.096
	sphere.radial_segments = 10
	sphere.rings = 5
	var source := sphere.get_mesh_arrays()
	var sphere_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var sphere_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	for index: int in source[Mesh.ARRAY_INDEX]:
		vertices.append(sphere_vertices[index])
		normals.append(sphere_normals[index])
		colors.append(Color(1, 0, 0))
	# 표면 접선(X)과 위(Y)로 뻗는 가는 십자 섬광 갈래.
	var spike: Array[Vector3] = [
		Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, -1, 0),
		Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)
	]
	var faces: Array[int] = [0, 3, 5, 3, 1, 5, 1, 2, 5, 2, 0, 5, 3, 0, 4, 1, 3, 4, 2, 1, 4, 0, 2, 4]
	for scale in [Vector3(0.16, 0.009, 0.009), Vector3(0.009, 0.12, 0.009)]:
		for corner in range(0, faces.size(), 3):
			var a: Vector3 = spike[faces[corner]] * scale
			var b: Vector3 = spike[faces[corner + 1]] * scale
			var c: Vector3 = spike[faces[corner + 2]] * scale
			# 원본 순서가 바깥에서 본 시계 방향이며 Godot의 앞면 규약과 같다.
			var normal := (a - b).cross(c - a).normalized()
			vertices.append_array(PackedVector3Array([a, b, c]))
			normals.append_array(PackedVector3Array([normal, normal, normal]))
			colors.append_array(PackedColorArray([Color.BLACK, Color.BLACK, Color.BLACK]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	if "arrow" in tower_types: return
	_spark_mesh = null
	_flare_mesh = null
