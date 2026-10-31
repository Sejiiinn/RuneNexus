extends Node3D
class_name FlipbookImpact

## 외부 전투 시계로 재생하는 1.1초 대포 착탄. 자체 _process 없음.
## Blender 연기 시뮬레이션을 게임 시점(약 63°)에서 렌더한 64칸 플립북 카드에 입체 파편·잉걸불·불 잔재·그을음 자국을 더한다.
## 원본과 제작 스크립트: design/effects/cannon_explosion_flipbook/.
const StageResources = preload("res://presentation/stage_resources.gd")
const DURATION: float = 1.1
const SHEET_PATH := "res://assets/effects/cannon_explosion_sheet.png"
const CARD_SHADER: Shader = preload("res://effects/cannon_flipbook_card.gdshader")
const DEBRIS_SHADER: Shader = preload("res://effects/cannon_flipbook_debris.gdshader")
const EMBER_SHADER: Shader = preload("res://effects/cannon_flipbook_embers.gdshader")
const SCORCH_SHADER: Shader = preload("res://effects/cannon_flipbook_scorch.gdshader")
const CARD_SIZE := 5.5                   # 렌더 카메라의 정사영 폭(블래스트 로컬 단위)
const CARD_CENTER := Vector3(0, 1.0, 0)  # 렌더 카메라가 화면 중심에 둔 높이
# 화구·먼지의 진한 부분(시트 알파 0.25 이상의 90%)이 0.15~0.45초에 폭발 반경과 같아지는 기준 반경.
# 0.875 * 137 / 94는 화면에서 잰 시트 크기 환산이고, 그 배율에서 진한 부분이 반경의 1.3배여서 1.3을 곱한다.
# 시뮬레이션을 다시 구우면 다시 잰다.
const REFERENCE_RADIUS := 0.875 * 137.0 / 94.0 * 1.3
const DEBRIS_COUNT := 22
const EMBER_COUNT := 100      # 40 공중형, 60 지면형
const GROUND_EMBERS := 60
const REMNANT_COUNT := 5
const SCORCH_RADIUS := 0.65   # 폭발 반경 0.875칸일 때 그을음 자국 반경(칸)

static var _sheet: Texture2D
static var _rock: ArrayMesh
static var _dot: QuadMesh
static var _debris_table: ImageTexture
static var _ember_table: ImageTexture

var _blast: Node3D
var _card: MeshInstance3D
var _card_material: ShaderMaterial
var _age_materials: Array[ShaderMaterial] = []
var _configured: bool = false


func configure() -> void:
	if _configured:
		return
	if _sheet == null:
		_sheet = StageResources.load_resource(SHEET_PATH)
		_rock = _rock_mesh()
		_dot = QuadMesh.new()
		_dot.size = Vector2.ONE
		_debris_table = _debris_data()
		_ember_table = _ember_data()
	_blast = Node3D.new()
	_blast.name = "CannonFlipbookBlast"
	add_child(_blast)
	_card = MeshInstance3D.new()
	_card.name = "CannonFlipbookCard"
	var quad := QuadMesh.new()
	quad.size = Vector2(CARD_SIZE, CARD_SIZE)
	_card.mesh = quad
	_card_material = ShaderMaterial.new()
	_card_material.shader = CARD_SHADER
	_card_material.set_shader_parameter("sheet", _sheet)
	_card.material_override = _card_material
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blast.add_child(_card)
	# 그을음(-2) → 카드(0) → 파편(1) → 잉걸불(2). 파편은 화구 안에 있는 동안 셰이더가 어둡게·투명하게 둔다.
	_blast.add_child(_particles("CannonFlipbookDebris", _rock, DEBRIS_SHADER, _debris_table, DEBRIS_COUNT, 1))
	_blast.add_child(_particles("CannonFlipbookEmbers", _dot, EMBER_SHADER, _ember_table, EMBER_COUNT + REMNANT_COUNT, 2))
	var scorch := MeshInstance3D.new()
	scorch.name = "CannonFlipbookScorch"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (2.0 * SCORCH_RADIUS * REFERENCE_RADIUS / 0.875)
	scorch.mesh = plane
	scorch.position = Vector3(0, 0.012, 0)
	var scorch_material := ShaderMaterial.new()
	scorch_material.shader = SCORCH_SHADER
	scorch_material.render_priority = -2
	scorch.material_override = scorch_material
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_age_materials.append(scorch_material)
	_blast.add_child(scorch)
	_configured = true
	visible = false


func update_impact(progress: float, radius: float, impact_id: int, camera: Camera3D) -> void:
	if not _configured or camera == null:
		visible = false
		return
	progress = clampf(progress, 0.0, 1.0)
	visible = progress < 1.0
	if not visible:
		return
	# 절대 나이로만 다시 계산해 정지·배속·되감기·풀 재사용이 같은 결과를 낸다.
	var age: float = progress * DURATION
	_blast.scale = Vector3.ONE * (maxf(radius, 0.001) / REFERENCE_RADIUS)
	# 폭발마다 파편·잉걸불·그을음 방향을 바꾼다. 카드는 update_camera가 카메라 쪽으로 다시 세운다.
	_blast.rotation = Vector3(0.0, float(posmod(impact_id, 23)) * 0.317, 0.0)
	_card_material.set_shader_parameter("frame", age * 60.0)
	for material in _age_materials:
		material.set_shader_parameter("age", age)
	update_camera(camera)


func update_camera(camera: Camera3D) -> void:
	# 렌더 때처럼 카드를 화면과 평행하게 세운다. 본게임 HUD 맞춤 오프셋을 포함한 실제 렌더 카메라를 쓴다.
	var pose: Transform3D = camera.get_camera_transform()
	var scale_factor: float = _blast.scale.x
	_card.global_transform = Transform3D(pose.basis.orthonormalized().scaled(Vector3.ONE * scale_factor),
		_blast.global_transform * CARD_CENTER)


func _particles(node_name: String, mesh: Mesh, shader: Shader, table: Texture2D, count: int, priority: int) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = count
	# 인스턴스는 정적 단위행렬. 운동은 절대 age에서 GPU가 재구성한다.
	for slot in count:
		instances.set_instance_transform(slot, Transform3D.IDENTITY)
	instances.custom_aabb = AABB(Vector3(-5, -0.5, -5), Vector3(10, 5, 10))
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("data", table)
	material.render_priority = priority
	node.material_override = material
	_age_materials.append(material)
	return node


static func _table(rows: Array) -> ImageTexture:
	var image := Image.create(2, rows.size(), false, Image.FORMAT_RGBAF)
	for i in rows.size():
		image.set_pixel(0, i, rows[i][0])
		image.set_pixel(1, i, rows[i][1])
	return ImageTexture.create_from_image(image)


static func _debris_data() -> ImageTexture:
	var random := RandomNumberGenerator.new()
	random.seed = 2207
	var rows := []
	for i in DEBRIS_COUNT:
		var big := i % 6 == 0
		rows.append([
			Color(random.randf() * TAU, 1.6 + random.randf() * 2.6, 2.2 + random.randf() * 3.6,
				(0.11 + random.randf() * 0.05) if big else (0.06 + random.randf() * 0.06)),
			Color(0.06 + random.randf() * 0.04, 5.0 + random.randf() * 9.0, 0.55 + random.randf() * 0.4,
				0.35 + random.randf() * 0.65),
		])
	return _table(rows)


static func _ember_data() -> ImageTexture:
	var random := RandomNumberGenerator.new()
	random.seed = 3109
	var rows := []
	for i in EMBER_COUNT:
		var grounded := i < GROUND_EMBERS
		# 지면형은 중심 가까이 촘촘하게(속도 분포를 제곱해 바깥은 성기게) 박혀 1.0초 무렵까지 남는다.
		var reach := random.randf()
		rows.append([
			Color(random.randf() * TAU, (0.6 + reach * reach * 3.4) if grounded else (2.0 + random.randf() * 5.5),
				(0.4 + random.randf() * 1.8) if grounded else (2.0 + random.randf() * 6.0), 0.06 + random.randf() * 0.08),
			Color(0.01 + random.randf() * 0.12, 1.05 if grounded else 0.45 + random.randf() * 0.6, random.randf() * TAU,
				1.0 if grounded else 0.0),
		])
	# 불 잔재 5개: 중심 0.4칸 안, 높이 0.1~0.3에서 0.25~0.47초 동안 식는다(블래스트 로컬 단위).
	for i in REMNANT_COUNT:
		rows.append([
			Color(random.randf() * TAU, random.randf() * 0.5, 0.1 + random.randf() * 0.2, 0.36 + random.randf() * 0.16),
			Color(0.24 + random.randf() * 0.04, 0.19 + random.randf() * 0.04, random.randf() * 20.0, 2.0),
		])
	return _table(rows)


## 대포가 없는 스테이지에서는 공유 시트·메시·데이터를 놓아 메모리를 비운다.
static func retain_stage(_enemy_types: Array, tower_types: Array) -> void:
	if "cannon" in tower_types: return
	_sheet = null
	_rock = null
	_dot = null
	_debris_table = null
	_ember_table = null


# 낮은 다각형 돌: 꼭짓점을 흔든 정이십면체. 면마다 빛을 받도록 평면 법선을 쓴다.
static func _rock_mesh() -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 41
	var g := (1.0 + sqrt(5.0)) / 2.0
	var points := [Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0),
		Vector3(0, -1, g), Vector3(0, 1, g), Vector3(0, -1, -g), Vector3(0, 1, -g),
		Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1)]
	for i in points.size():
		points[i] = points[i].normalized() * (0.65 + random.randf() * 0.5)
	var faces := [0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11, 1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8,
		3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9, 4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for f in range(0, faces.size(), 3):
		var a: Vector3 = points[faces[f]]
		var b: Vector3 = points[faces[f + 1]]
		var c: Vector3 = points[faces[f + 2]]
		var outward: bool = (b - a).cross(c - a).dot(a + b + c) > 0.0
		var n := (b - a).cross(c - a).normalized() * (1.0 if outward else -1.0)
		# Godot의 시계 방향 앞면 규약.
		vertices.append_array(PackedVector3Array([a, c, b]) if outward else PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
