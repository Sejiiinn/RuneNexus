extends RefCounted
const StageResources = preload("res://presentation/stage_resources.gd")

## Approved V3 Blender fire, baked once; short-lived parcels move on the GPU.
## One immutable MultiMesh per enemy kind, one shared material/atlas/clock.
const AttachmentKind = preload("res://effects/enemy_attachment_kind.gd")
const GuardianStatus = preload("res://effects/guardian_status.gd")
const SHADER = preload("res://effects/enemy_burn.gdshader")
const ATLAS := "res://assets/effects/enemy_burn/flame_atlas.png"
const DATA_PATH := "res://assets/effects/enemy_burn/attachments.json"
const PARTICLE_COUNT := 52
static var _material: ShaderMaterial
static var _multimeshes: Dictionary = {}
static var _time := 0.0
static var _definitions := {}
static var _row_offsets := {}


static func _ensure_shared() -> void:
	if _material != null:
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_definitions = document["enemies"]
	var data := Image.create(2, _definitions.size() * PARTICLE_COUNT, false, Image.FORMAT_RGBAF)
	var row := 0
	for kind: String in _definitions:
		var particles: Array = _definitions[kind]["particles"]
		assert(particles.size() == PARTICLE_COUNT, "화상 입자 초기값 개수 불일치")
		_row_offsets[kind] = row
		for index in range(PARTICLE_COUNT):
			var item: Dictionary = particles[index]
			data.set_pixel(0, row, Color(float(item["period_frames"]) / 24.0, float(item["phase_frames"]) / 24.0, item["size"], item["drift"]))
			data.set_pixel(1, row, Color(item["rise"], float(index), 0.0, 0.0))
			row += 1
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("flame_atlas", StageResources.load_resource(ATLAS))
	_material.set_shader_parameter("particle_data", ImageTexture.create_from_image(data))
	_material.set_shader_parameter("burn_time", _time)


static func _instances(kind: String) -> MultiMesh:
	if _multimeshes.has(kind): return _multimeshes[kind]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = quad
	instances.instance_count = PARTICLE_COUNT
	var particles: Array = _definitions[kind]["particles"]
	var bounds := AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 2.0, 1.6))
	for index in range(PARTICLE_COUNT):
		var item: Dictionary = particles[index]
		var anchor: Array = item["anchor"]
		var origin := Vector3(anchor[0], anchor[1], anchor[2])
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin))
		instances.set_instance_custom_data(index, Color(float(_row_offsets[kind] + index), 0.0, 0.0, 0.0))
		bounds = bounds.expand(origin + Vector3(0.5, float(item["rise"]) + 0.5, 0.5))
		bounds = bounds.expand(origin - Vector3(0.5, 0.5, 0.5))
	instances.custom_aabb = bounds
	_multimeshes[kind] = instances
	return instances


static func set_time(time: float) -> void:
	if _time == time:
		return
	_time = time
	GuardianStatus.set_burn_time(time)
	if _material != null:
		_material.set_shader_parameter("burn_time", time)


static func apply(entry: Dictionary, burning: bool, _combat_time: float) -> void:
	if not entry.has("burn"):
		if not burning:
			return
		_ensure_shared()
		if bool(entry.get("guardian_preview", false)):
			entry["burn"] = GuardianStatus.attach(entry, [], [_material], "EnemyBurn")
			entry["burn_active"] = burning
			entry["burn"].visible = burning
			return
		var effect := MultiMeshInstance3D.new()
		effect.name = "EnemyBurn"
		var kind := AttachmentKind.resolve(entry["type"])
		effect.multimesh = _instances(kind)
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


static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	var kinds := {}
	if "magic" in tower_types:
		for kind: String in enemy_types: kinds[AttachmentKind.resolve(kind)] = true
	for kind: String in _multimeshes.keys():
		if not kinds.has(kind): _multimeshes.erase(kind)
	if kinds.is_empty():
		_material = null
		_definitions.clear()
		_row_offsets.clear()
		_time = 0.0
