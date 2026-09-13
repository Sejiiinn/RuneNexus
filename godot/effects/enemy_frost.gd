extends RefCounted

## 공통 성에 shader를 원래 몸체 재질의 next_pass로 연결한다.
## 적별 데이터는 결정 부착 변환뿐이며 모든 종이 같은 두 원형을 사용한다.
const CRYSTALS = preload("res://assets/effects/enemy_frost/crystals.glb")
const COAT_SHADER = preload("res://effects/enemy_frost.gdshader")
const CRYSTAL_SHADER = preload("res://effects/enemy_frost_crystals.gdshader")
const GRAIN = preload("res://assets/effects/enemy_frost/grain.png")
static var _coat: ShaderMaterial
static var _ice: ShaderMaterial
static var _grain_material: StandardMaterial3D
static var _shard_mesh: Mesh
static var _grain_mesh: Mesh
static var _attachments: Dictionary = {}
static var _variants: Array = []
static var _multimeshes: Dictionary = {}
static var _body_materials: Dictionary = {}


static func _ensure_shared() -> void:
	if _coat != null:
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemy_frost.json"))
	_attachments = data
	_variants = data["_variants"]
	var bytes := FileAccess.get_file_as_bytes("res://assets/enemy_frost_mask.bin.gz").decompress(64 * 64 * 64, FileAccess.COMPRESSION_GZIP)
	assert(bytes.size() == 64 * 64 * 64, "공통 성에 마스크 데이터 크기 불일치")
	var slices: Array[Image] = []
	for z in range(64):
		slices.append(Image.create_from_data(64, 64, false, Image.FORMAT_R8, bytes.slice(z * 4096, (z + 1) * 4096)))
	var mask := ImageTexture3D.new()
	mask.create(Image.FORMAT_R8, 64, 64, 64, false, slices)
	_coat = ShaderMaterial.new()
	_coat.shader = COAT_SHADER
	_coat.set_shader_parameter("rime_mask", mask)
	_coat.set_shader_parameter("grain_texture", GRAIN)
	var palette := Image.create(13, 40, false, Image.FORMAT_RGBAF)
	var colors := [Color(0.29, 0.70, 0.87).srgb_to_linear(), Color(0.65, 0.89, 0.97).srgb_to_linear(), Color(0.87, 0.97, 1.0).srgb_to_linear()]
	var roughness := [0.16, 0.24, 0.44]
	for i in range(40):
		for face in range(13):
			var index := int(_variants[i]["face_materials"][face])
			var color: Color = colors[index]
			color.a = roughness[index]
			palette.set_pixel(face, i, color)
	_ice = ShaderMaterial.new()
	_ice.shader = CRYSTAL_SHADER
	_ice.set_shader_parameter("face_palette", ImageTexture.create_from_image(palette))
	_grain_material = StandardMaterial3D.new()
	_grain_material.albedo_color = Color(0.87, 0.97, 1.0)
	_grain_material.roughness = 0.44
	var library := CRYSTALS.instantiate()
	_shard_mesh = library.find_child("FrostShard", true, false).mesh
	_grain_mesh = library.find_child("FrostGrain", true, false).mesh
	library.free()


static func _transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[3], values[4], values[5]), Vector3(values[6], values[7], values[8])), Vector3(values[9], values[10], values[11]))


static func _instances(kind: String) -> Array:
	var key := "boss" if kind == "shieldBoss" else kind
	if _multimeshes.has(key):
		return _multimeshes[key]
	var shards := MultiMesh.new()
	shards.transform_format = MultiMesh.TRANSFORM_3D
	shards.use_custom_data = true
	shards.mesh = _shard_mesh
	shards.instance_count = 40
	var grains := MultiMesh.new()
	grains.transform_format = MultiMesh.TRANSFORM_3D
	grains.mesh = _grain_mesh
	grains.instance_count = 95
	var shard_index := 0
	var grain_index := 0
	for item: Dictionary in _attachments[key]:
		var pose := _transform(item["transform"])
		if item["mesh"] == "FrostGrain":
			grains.set_instance_transform(grain_index, pose)
			grain_index += 1
		else:
			var variant := int(item["variant"])
			var twist := float(_variants[variant]["twist"])
			shards.set_instance_transform(shard_index, pose)
			shards.set_instance_custom_data(shard_index, Color(variant, cos(twist), sin(twist), 0.0))
			shard_index += 1
	shards.visible_instance_count = shard_index
	grains.visible_instance_count = grain_index
	# The unit mesh tip is displaced by the shader; authored surface bounds plus
	# 0.2 retain all crystal tips in the instance culling bounds.
	shards.custom_aabb = AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 1.6, 1.6))
	_multimeshes[key] = [shards, grains]
	return _multimeshes[key]


static func apply(entry: Dictionary, slowed: bool) -> void:
	if not entry.has("frost"):
		if not slowed:
			return
		_ensure_shared()
		var frost := Node3D.new()
		frost.name = "EnemyFrost"
		entry["root"].add_child(frost)
		entry["frost"] = frost
		var bodies: Array = []
		for mesh: MeshInstance3D in entry["root"].find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var original := mesh.get_active_material(surface)
				if not original is StandardMaterial3D or original.resource_name.ends_with("_crystal"):
					continue
				if not _body_materials.has(original):
					var coated := original.duplicate() as StandardMaterial3D
					coated.next_pass = _coat
					_body_materials[original] = coated
				bodies.append([mesh, surface, mesh.get_surface_override_material(surface), _body_materials[original]])
		entry["frost_bodies"] = bodies
		var instances := _instances(entry["type"])
		for i in range(2):
			var crystals := MultiMeshInstance3D.new()
			crystals.name = "Shards" if i == 0 else "Grains"
			crystals.multimesh = instances[i]
			crystals.material_override = _ice if i == 0 else _grain_material
			frost.add_child(crystals)
		entry["frost_active"] = false
	if entry["frost_active"] == slowed:
		return
	entry["frost_active"] = slowed
	entry["frost"].visible = slowed
	for body: Array in entry["frost_bodies"]:
		body[0].set_surface_override_material(body[1], body[3] if slowed else body[2])
