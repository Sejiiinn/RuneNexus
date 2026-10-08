extends Node3D
## Reusable one-tile device. No placement or independent clock is implicit.

const StageResources = preload("res://presentation/stage_resources.gd")
const MODEL_PATH := "res://assets/teleport/teleport_device.glb"
const SurfaceShader = preload("res://environment/teleport_surface.gdshader")
const ParticleShader = preload("res://environment/teleport_particle.gdshader")
const COLORS := {"blue": Color(0.006, 0.19, 1.0), "orange": Color(1.0, 0.14, 0.002)}
const FOOTPRINT_HALF := 0.5
const LOOP_SECONDS := 4.0

static var _model: PackedScene
static var _materials: Dictionary = {}
var color_key := "blue"
var outflow := false
var battle_time := 0.0
var _surface_material: ShaderMaterial
var _particle_material: ShaderMaterial


static func release_resources() -> void:
	# Call only after outgoing stage devices are freed. A teleport-to-teleport map keeps this cache.
	_model = null
	_materials.clear()
	StageResources.release([MODEL_PATH])


static func resource_snapshot() -> Dictionary:
	return {"model_loaded": _model != null, "material_count": _materials.size()}


func configure(color: String, is_out: bool) -> bool:
	if not COLORS.has(color): return false
	if _model == null: _model = StageResources.load_resource(MODEL_PATH) as PackedScene
	if _model == null: return false
	for child in get_children(): child.free()
	color_key = color
	outflow = is_out
	var library := _model.instantiate() as Node3D
	var frame := library.find_child("teleport_frame", true, false) as MeshInstance3D
	var surface := library.find_child("teleport_out_surface" if outflow else "teleport_in_surface", true, false) as MeshInstance3D
	var particle := library.find_child("teleport_particle", true, false) as MeshInstance3D
	var core := library.find_child("teleport_out_core", true, false) as MeshInstance3D
	if frame == null or surface == null or particle == null or core == null:
		library.free()
		return false
	var key := color + ("_out" if outflow else "_in")
	if not _materials.has(key):
		var surface_material := ShaderMaterial.new()
		surface_material.shader = SurfaceShader
		surface_material.set_shader_parameter("outflow", outflow)
		surface_material.set_shader_parameter("flow_color", Vector3(COLORS[color].r, COLORS[color].g, COLORS[color].b))
		var particles := ShaderMaterial.new()
		particles.shader = ParticleShader
		particles.set_shader_parameter("outflow", outflow)
		particles.set_shader_parameter("flow_color", Vector3(COLORS[color].r, COLORS[color].g, COLORS[color].b))
		_materials[key] = {"surface": surface_material, "particle": particles}
	_surface_material = _materials[key].surface
	_particle_material = _materials[key].particle
	var body := frame.duplicate() as MeshInstance3D
	body.name = "Frame"
	for slot in range(body.mesh.get_surface_count()):
		var original := body.get_active_material(slot) as StandardMaterial3D
		if original != null and original.resource_name.contains("rune emission"):
			var rune_key := color + "_runes"
			if not _materials.has(rune_key):
				var rune := original.duplicate() as StandardMaterial3D
				rune.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				rune.albedo_color = COLORS[color].linear_to_srgb()
				rune.emission_enabled = true
				rune.emission = COLORS[color].linear_to_srgb()
				rune.emission_energy_multiplier = 2.4
				_materials[rune_key] = rune
			body.set_surface_override_material(slot, _materials[rune_key])
	add_child(body)
	var flow := surface.duplicate() as MeshInstance3D
	flow.name = "FlowSurface"
	flow.material_override = _surface_material
	flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flow)
	var moving := MultiMeshInstance3D.new()
	moving.name = "RadialLights"
	moving.multimesh = MultiMesh.new()
	moving.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	moving.multimesh.use_custom_data = true
	moving.multimesh.mesh = particle.mesh
	moving.multimesh.instance_count = 15
	for arm in range(3):
		for packet in range(5):
			var index := arm * 5 + packet
			moving.multimesh.set_instance_transform(index, Transform3D.IDENTITY)
			moving.multimesh.set_instance_custom_data(index, Color(float(arm), float(packet) / 5.0, 0.0, 1.0))
	moving.multimesh.custom_aabb = AABB(Vector3(-0.5, -0.1, -0.5), Vector3(1.0, 0.15, 1.0))
	moving.material_override = _particle_material
	moving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moving)
	if outflow:
		var emergence := core.duplicate() as MeshInstance3D
		emergence.name = "EmergenceCore"
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.albedo_color = Color(0.58, 0.58, 0.58).lerp(COLORS[color], 0.42)
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 8.0
		emergence.material_override = material
		emergence.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(emergence)
	library.free()
	set_meta("teleport_color", color)
	set_meta("teleport_direction", "out" if outflow else "in")
	update_time(0.0)
	return true


func update_time(time: float) -> void:
	battle_time = time
	_surface_material.set_shader_parameter("battle_time", time)
	_particle_material.set_shader_parameter("battle_time", time)


static func radial_light_position(time: float, is_out: bool, arm: int, packet: int) -> Vector3:
	# Mirrors the authored path and GPU equation for bounds/clock regression.
	var t := fposmod(time / LOOP_SECONDS + float(packet) / 5.0, 1.0)
	var q := 0.055 + 0.9 * (t if is_out else 1.0 - t)
	var angle := float(arm) * TAU / 3.0 + (3.0 if is_out else 13.0 / 3.0) * q
	var radius := 0.428 * q
	var height := 0.014 + 0.028 * pow(1.0 - q, 1.6) if is_out else 0.003 - 0.088 * pow(1.0 - q, 2.0)
	return Vector3(radius * cos(angle), height, -radius * sin(angle))
