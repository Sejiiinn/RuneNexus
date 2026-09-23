extends Node3D

## Presentation only: combat owns cooldown, area damage and slow. One static
## shared 32-instance batch; vertex motion uses the external combat clock.
const CHARGE_SHADER = preload("res://effects/frost_charge.gdshader")
const MIST_SHADER = preload("res://effects/frost_mist.gdshader")
const MIST_MODEL = preload("res://assets/effects/frost_tower/mist-volume.glb")
const MIST_DURATION := 1.05
static var _instances: MultiMesh
static var _noise: NoiseTexture2D
static var _charge_material: ShaderMaterial
var charge := 1.0
var mist := MultiMeshInstance3D.new()
var mist_material := ShaderMaterial.new()
var lamp := OmniLight3D.new()
var _fins: Array[MeshInstance3D] = []
var _last_time := -INF
var _last_shot := -1
var _fire_start := -INF
var _radius := 1.58

static func _ensure_shared() -> void:
	if _instances != null: return
	var source := MIST_MODEL.instantiate()
	_instances = MultiMesh.new()
	_instances.transform_format = MultiMesh.TRANSFORM_3D
	_instances.use_custom_data = true
	_instances.mesh = source.find_children("*", "MeshInstance3D", true, false)[0].mesh
	_instances.instance_count = 32
	for i in 32:
		_instances.set_instance_transform(i, Transform3D.IDENTITY)
		_instances.set_instance_custom_data(i, Color(fposmod(i * .618, 1.), fposmod(i * .381966, 1.), .25 + .75 * fposmod(i * .719, 1.), 1.))
	source.free()
	_noise = NoiseTexture2D.new()
	_noise.width = 128
	_noise.height = 128
	_noise.seamless = true
	var noise := FastNoiseLite.new()
	noise.frequency = .045
	noise.fractal_octaves = 3
	_noise.noise = noise
	_charge_material = ShaderMaterial.new()
	_charge_material.shader = CHARGE_SHADER

func configure(tower: Node3D) -> void:
	_ensure_shared()
	name = "FrostChargeMist"
	for mesh: MeshInstance3D in tower.find_children("*", "MeshInstance3D", true, false):
		var matched := false
		for i in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(i)
			if material != null and ("cold aluminum fins" in material.resource_name or "cold circulating core" in material.resource_name):
				mesh.set_surface_override_material(i, _charge_material)
				matched = true
		if matched:
			var pose := tower.global_transform.affine_inverse() * mesh.global_transform
			mesh.set_instance_shader_parameter("height_plane", Vector4(pose.basis.x.y, pose.basis.y.y, pose.basis.z.y, pose.origin.y))
			_fins.append(mesh)
	mist.multimesh = _instances
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist_material.shader = MIST_SHADER
	mist_material.set_shader_parameter("noise_tex", _noise)
	mist.material_override = mist_material
	mist.visible = false
	add_child(mist)
	lamp.position = Vector3(0, .28, 0)
	lamp.omni_range = 1.15
	lamp.light_color = Color("26c3e5")
	lamp.shadow_enabled = false
	lamp.light_energy = 0.0
	add_child(lamp)

func update_state(time: float, shot: int, _feedback: float, state: Dictionary, show_mist: bool, light_enabled: bool) -> void:
	var rewound := time < _last_time or shot < _last_shot
	if rewound: _fire_start = -INF
	var fired := not rewound and _last_shot >= 0 and shot > _last_shot
	if fired:
		_fire_start = time
		_radius = maxf(.01, float(state.get("radius", 1.58)))
		mist_material.set_shader_parameter("effect_radius", _radius)
		mist.custom_aabb = AABB(Vector3(-_radius, -.2, -_radius), Vector3(_radius * 2, 1.4, _radius * 2))
	_last_time = time
	_last_shot = shot
	var cooldown := maxf(0.0, float(state.get("cooldown", 0.0)))
	var total := maxf(cooldown, float(state.get("duration", 0.0)))
	charge = clampf(1.0 - cooldown / maxf(.000001, total), 0.0, 1.0)
	for mesh in _fins: mesh.set_instance_shader_parameter("charge", charge)
	var energy := charge * .65 if light_enabled else 0.0
	if lamp.light_energy != energy: lamp.light_energy = energy
	lamp.visible = energy > 0.0
	var age := (time - _fire_start) / MIST_DURATION
	mist.visible = show_mist and age >= 0.0 and age < 1.0
	if mist.visible: mist_material.set_shader_parameter("age", age)
