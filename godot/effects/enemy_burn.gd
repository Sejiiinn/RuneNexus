extends RefCounted

## Approved V3 Blender fire, baked once; short-lived parcels move on the GPU.
## One immutable MultiMesh per enemy kind, one shared material/atlas/clock.
const SHADER = preload("res://effects/enemy_burn.gdshader")
const ATLAS = preload("res://assets/effects/enemy_burn/flame_atlas.png")
const DATA_PATH := "res://assets/effects/enemy_burn/attachments.json"
const PARTICLE_COUNT := 52
static var _material: ShaderMaterial
static var _multimeshes: Dictionary = {}
static var _time := 0.0


static func _ensure_shared() -> void:
	if _material != null:
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var definitions: Dictionary = document["enemies"]
	var data := Image.create(2, definitions.size() * PARTICLE_COUNT, false, Image.FORMAT_RGBAF)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var row := 0
	for kind: String in definitions:
		var particles: Array = definitions[kind]["particles"]
		assert(particles.size() == PARTICLE_COUNT, "화상 입자 초기값 개수 불일치")
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		instances.mesh = quad
		instances.instance_count = PARTICLE_COUNT
		var bounds := AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 2.0, 1.6))
		for index in range(PARTICLE_COUNT):
			var item: Dictionary = particles[index]
			var anchor: Array = item["anchor"]
			var origin := Vector3(anchor[0], anchor[1], anchor[2])
			instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin))
			instances.set_instance_custom_data(index, Color(float(row), 0.0, 0.0, 0.0))
			data.set_pixel(0, row, Color(float(item["period_frames"]) / 24.0, float(item["phase_frames"]) / 24.0, item["size"], item["drift"]))
			data.set_pixel(1, row, Color(item["rise"], float(index), 0.0, 0.0))
			# Includes travel plus the full billboard diagonal at every camera angle.
			bounds = bounds.expand(origin + Vector3(0.5, float(item["rise"]) + 0.5, 0.5))
			bounds = bounds.expand(origin - Vector3(0.5, 0.5, 0.5))
			row += 1
		instances.custom_aabb = bounds
		_multimeshes[kind] = instances
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("flame_atlas", ATLAS)
	_material.set_shader_parameter("particle_data", ImageTexture.create_from_image(data))
	_material.set_shader_parameter("burn_time", _time)


static func set_time(time: float) -> void:
	if _time == time:
		return
	_time = time
	if _material != null:
		_material.set_shader_parameter("burn_time", time)


static func apply(entry: Dictionary, burning: bool, _combat_time: float) -> void:
	if not entry.has("burn"):
		if not burning:
			return
		_ensure_shared()
		var effect := MultiMeshInstance3D.new()
		effect.name = "EnemyBurn"
		var kind: String = "boss" if entry["type"] == "shieldBoss" else entry["type"]
		effect.multimesh = _multimeshes[kind]
		effect.material_override = _material
		effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		entry["root"].add_child(effect)
		# Different enemies do not pulse in lockstep; this value never needs updating.
		effect.set_instance_shader_parameter("phase_offset", float(entry["root"].get_instance_id() % 997) / 997.0 * 4.0)
		entry["burn"] = effect
		entry["burn_active"] = false
	if entry["burn_active"] == burning:
		return
	entry["burn_active"] = burning
	entry["burn"].visible = burning
