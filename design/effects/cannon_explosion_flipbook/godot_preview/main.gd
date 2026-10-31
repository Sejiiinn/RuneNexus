extends Node3D
## Flipbook check at the game camera: orthographic, about 63 degrees down (godot/session/battlefield_camera.gd angled pose).
## Run: Godot --path <this folder> --fixed-fps 60 -- [--capture=<dir>] [--size=<ortho height>]

const SHEET := "res://cannon_explosion_sheet.png"
const FRAMES := 64
const CARD := 5.5            # world size of the rendered square (the Blender ortho scale)
const CARD_CENTER := Vector3(0, 1.0, 0)
const DEBRIS_COUNT := 22
# 화구·먼지의 진한 부분(시트 알파 0.25 이상의 90%)이 0.15~0.45초에 폭발 반경과 같아지는 기준 반경.
# 배율 1에서 진한 부분이 반경의 1.3배이므로 1.3을 곱한다. 시뮬레이션을 다시 구우면 다시 잰다.
const REFERENCE_RADIUS := 0.875 * 137.0 / 94.0 * 1.3
const RADIUS := 42.0 / 48.0   # 대포 splashRadius / tileSize
const EMBER_COUNT := 100       # 40 공중형, 60 지면형
const GROUND_EMBERS := 60
const REMNANT_COUNT := 5
var card_material: ShaderMaterial
var particle_materials: Array[ShaderMaterial] = []
var flash: OmniLight3D
var camera: Camera3D
var age := -0.25
var capture_dir := ""
var captured := 0

func _ready() -> void:
	var size := 13.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--size="): size = float(arg.trim_prefix("--size="))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.063, 0.106, 0.125)
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.6
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_hdr_threshold = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(40, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	var noise := NoiseTexture2D.new(); noise.width = 512; noise.height = 512; noise.seamless = true
	noise.noise = FastNoiseLite.new(); noise.noise.frequency = 0.03
	gm.albedo_texture = noise; gm.albedo_color = Color(0.36, 0.34, 0.32); gm.uv1_scale = Vector3(6, 6, 6); gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	for p in [Vector3(-0.9, 0, 0.6), Vector3(1.1, 0, -0.4), Vector3(0.2, 0, -1.3), Vector3(3.2, 0, 1.4), Vector3(-3.0, 0, -2.2)]:
		var dummy := MeshInstance3D.new()
		var capsule := CapsuleMesh.new(); capsule.radius = 0.28; capsule.height = 1.1
		dummy.mesh = capsule; dummy.position = p + Vector3(0, 0.55, 0)
		var dm := StandardMaterial3D.new(); dm.albedo_color = Color(0.55, 0.42, 0.36)
		dummy.material_override = dm
		add_child(dummy)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	var direction := Vector3(5, 27, 13).normalized()
	camera.transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), CARD_CENTER + direction * 30.0)
	camera.far = 80.0
	add_child(camera)
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(CARD, CARD)
	card.mesh = quad
	card_material = ShaderMaterial.new()
	card_material.shader = load("res://flipbook.gdshader")
	card_material.set_shader_parameter("sheet", load(SHEET))
	card.material_override = card_material
	# Parallel to the view plane, exactly like the orthographic render it came from.
	card.transform = Transform3D(camera.transform.basis, CARD_CENTER)
	var blast := Node3D.new()
	blast.name = "Blast"
	blast.scale = Vector3.ONE * (RADIUS / REFERENCE_RADIUS)
	add_child(blast)
	blast.add_child(card)
	# 파편(1)과 잉걸불(2)은 카드 위에 겹쳐 그린다. 파편은 화구 안에 있는 동안 셰이더가 투명하게 둔다.
	blast.add_child(_particles("Debris", _rock_mesh(), "res://debris.gdshader", _debris_data(), DEBRIS_COUNT, 1))
	var dot := QuadMesh.new(); dot.size = Vector2.ONE
	blast.add_child(_particles("Embers", dot, "res://embers.gdshader", _ember_data(), EMBER_COUNT + REMNANT_COUNT, 2))
	# 그을음 자국: 폭발 반경의 약 0.75배, 지면에 곱해 어둡게 한다.
	var scorch := MeshInstance3D.new()
	scorch.name = "Scorch"
	var scorch_plane := PlaneMesh.new(); scorch_plane.size = Vector2.ONE * (2.0 * 0.65 / blast.scale.x)
	scorch.mesh = scorch_plane
	scorch.position = Vector3(0, 0.012, 0)
	var scorch_material := ShaderMaterial.new()
	scorch_material.shader = load("res://scorch.gdshader")
	scorch_material.render_priority = -2
	scorch.material_override = scorch_material
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particle_materials.append(scorch_material)
	blast.add_child(scorch)
	# 섬광이 주변 지면과 적을 비춘다(반경 약 1.5칸, 0.03초 최대, 0.25초까지 지수 감소).
	flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.55, 0.22)
	flash.omni_range = 1.5 * RADIUS / 0.875
	flash.position = Vector3(0, 0.45, 0)
	flash.light_energy = 0.0
	add_child(flash)

# Static identity instances; the shaders rebuild every position from the absolute age (pause/speed/pool safe).
func _particles(node_name: String, mesh: Mesh, shader_path: String, data: Texture2D, count: int, priority: int) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = count
	for slot in count: instances.set_instance_transform(slot, Transform3D.IDENTITY)
	instances.custom_aabb = AABB(Vector3(-5, -0.5, -5), Vector3(10, 5, 10))
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	material.set_shader_parameter("data", data)
	# After the card (priority 0), so chunks and embers are not veiled by the flipbook.
	material.render_priority = priority
	node.material_override = material
	particle_materials.append(material)
	return node

static func _table(rows: Array) -> ImageTexture:
	var image := Image.create(2, rows.size(), false, Image.FORMAT_RGBAF)
	for i in rows.size():
		image.set_pixel(0, i, rows[i][0]); image.set_pixel(1, i, rows[i][1])
	return ImageTexture.create_from_image(image)

static func _debris_data() -> ImageTexture:
	var random := RandomNumberGenerator.new(); random.seed = 2207
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
	var random := RandomNumberGenerator.new(); random.seed = 3109
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

# Low-poly irregular rock: a jittered icosahedron with flat faces so each facet catches the sun.
static func _rock_mesh() -> ArrayMesh:
	var random := RandomNumberGenerator.new(); random.seed = 41
	var g := (1.0 + sqrt(5.0)) / 2.0
	var points := [Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0),
		Vector3(0, -1, g), Vector3(0, 1, g), Vector3(0, -1, -g), Vector3(0, 1, -g),
		Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1)]
	for i in points.size(): points[i] = points[i].normalized() * (0.65 + random.randf() * 0.5)
	var faces := [0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11, 1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8,
		3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9, 4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1]
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	for f in range(0, faces.size(), 3):
		var a: Vector3 = points[faces[f]]; var b: Vector3 = points[faces[f + 1]]; var c: Vector3 = points[faces[f + 2]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot(a + b + c) < 0.0: n = -n
		# Godot front faces are clockwise as seen from outside.
		vertices.append_array(PackedVector3Array([a, c, b]) if (b - a).cross(c - a).dot(a + b + c) > 0.0 else PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _process(delta: float) -> void:
	age += delta
	var frame := age * 60.0
	card_material.set_shader_parameter("frame", frame)
	for material in particle_materials: material.set_shader_parameter("age", age)
	flash.light_energy = 0.0 if age < 0.0 else 4.5 * (age / 0.03 if age < 0.03 else exp(-(age - 0.03) * 14.0))
	visible = true
	if capture_dir != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("p%04d.png" % captured))
		captured += 1
		if captured >= 100: get_tree().quit()
	elif age > 1.6:
		age = -0.25
