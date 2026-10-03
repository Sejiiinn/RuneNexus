extends Node3D

## Approved Lightning A: actual spatial current tubes and a softly bounded aura.
## The caller owns event identity, pooling and authoritative event age. This node
## has no process callback, wall clock, targeting, physics, damage or runtime light.
## All entry-point positions/transforms are WORLD coordinates. Charge pose origin
## is the sphere center, with +Z toward the target. Supply actual electrode tips.
## Tube resources were baked from the approved Blender curves (six-sided main
## spines and four-sided fine branches, original
## control points and tapered radii). No mesh creation/branch generation per shot.
const CHARGE_SECONDS := 0.30
const DISCHARGE_SECONDS := 0.28
const CHARGE_RADIUS := 0.275
const MAX_ELECTRODES := 4
const TUBE_SHADER := preload("res://effects/lightning_attack_tubes.gdshader")
const AURA_SHADER := preload("res://effects/lightning_attack_aura.gdshader")
const CHARGE_MESHES := [
	preload("res://effects/lightning_attack_meshes/charge00.res"),
	preload("res://effects/lightning_attack_meshes/charge01.res"),
	preload("res://effects/lightning_attack_meshes/charge02.res"),
	preload("res://effects/lightning_attack_meshes/charge03.res"),
]
const BEAM_MESHES := [
	preload("res://effects/lightning_attack_meshes/beam00.res"),
	preload("res://effects/lightning_attack_meshes/beam01.res"),
	preload("res://effects/lightning_attack_meshes/beam02.res"),
	preload("res://effects/lightning_attack_meshes/beam03.res"),
	preload("res://effects/lightning_attack_meshes/beam04.res"),
	preload("res://effects/lightning_attack_meshes/beam05.res"),
]
const FEED_MESHES := [
	preload("res://effects/lightning_attack_meshes/feed00.res"),
	preload("res://effects/lightning_attack_meshes/feed01.res"),
	preload("res://effects/lightning_attack_meshes/feed02.res"),
	preload("res://effects/lightning_attack_meshes/feed03.res"),
]
const IMPACT_MESH := preload("res://effects/lightning_attack_meshes/impact.res")
static var _aura_mesh: SphereMesh

var _configured := false
var _volume_enabled := true
var _charge: MeshInstance3D
var _beam: MeshInstance3D
var _impact: MeshInstance3D
var _aura: MeshInstance3D
var _contact_aura: MeshInstance3D
var _charge_material: ShaderMaterial
var _beam_material: ShaderMaterial
var _impact_material: ShaderMaterial
var _aura_material: ShaderMaterial
var _contact_material: ShaderMaterial
var _feeds: Array[MeshInstance3D] = []
var _feed_materials: Array[ShaderMaterial] = []


func _init() -> void:
	name = "SpatialLightningAttack"
	visible = false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_prepare()


func reset() -> void:
	# No particles, timers or accumulated simulation state survive pool reuse.
	visible = false


func set_volume_enabled(enabled: bool) -> void:
	_volume_enabled = enabled
	if not enabled and _configured:
		_aura.visible = false
		_contact_aura.visible = false
	# Re-enabling takes effect at the next authoritative sample. It never
	# resurrects an expired or reset effect on its own.


func sample_charge(charge_pose: Transform3D, age: float, duration: float = CHARGE_SECONDS,
		sequence: int = 0, electrode_sources: PackedVector3Array = PackedVector3Array()) -> void:
	_prepare()
	if not _valid_sample(age, duration) or not charge_pose.origin.is_finite():
		reset()
		return
	visible = true
	_beam.visible = false
	_impact.visible = false
	_contact_aura.visible = false
	var progress := age / duration
	var size := lerpf(0.20, 1.0, smoothstep(0.0, 0.72, progress))
	size *= 1.0 - 0.18 * smoothstep(0.78, 1.0, progress)
	var energy := lerpf(0.18, 1.15, smoothstep(0.0, 0.87, progress))
	var phase := posmod(int(floor(age * 24.0)) + sequence, CHARGE_MESHES.size())
	# Turrets currently use uniform scale. Keep the sphere spherical even if a
	# caller passes a nonuniform parent transform, and preserve its mean size.
	var scale_value := maxf(0.001, charge_pose.basis.get_scale().abs().dot(Vector3.ONE) / 3.0)
	var pose := Transform3D(charge_pose.basis.orthonormalized(), charge_pose.origin)
	_charge.visible = true
	_charge.mesh = CHARGE_MESHES[phase]
	_charge.global_transform = Transform3D(pose.basis.scaled_local(Vector3.ONE * size * scale_value), pose.origin)
	_charge.force_update_transform()
	_set_current(_charge_material, energy, age, sequence)
	_set_aura(_aura, _aura_material, pose.origin, CHARGE_RADIUS * size * scale_value, energy, age, sequence)
	for index in range(MAX_ELECTRODES):
		var feed := _feeds[index]
		feed.visible = index < electrode_sources.size()
		if not feed.visible:
			continue
		# The external source positions are the actual two turret electrodes.
		# Tiny alternating termination offsets preserve distinct spatial feeds.
		var side := -1.0 if index % 2 == 0 else 1.0
		var endpoint := pose.origin + pose.basis.x * (0.055 * side * size * scale_value)
		feed.mesh = FEED_MESHES[phase]
		_set_link(feed, _feed_materials[index], electrode_sources[index], endpoint, scale_value)
		_set_current(_feed_materials[index], energy * 0.86, age, sequence + index)


func sample_discharge(source: Vector3, target: Vector3, age: float,
		duration: float = DISCHARGE_SECONDS, sequence: int = 0, radius_scale: float = 1.0) -> void:
	_prepare()
	if not _valid_sample(age, duration) or not source.is_finite() or not target.is_finite():
		reset()
		return
	visible = true
	for feed in _feeds:
		feed.visible = false
	var progress := age / duration
	var visual_scale := clampf(radius_scale, 0.1, 4.0)
	var phase := mini(BEAM_MESHES.size() - 1, int(floor(progress * float(BEAM_MESHES.size()))))
	var energy := pow(maxf(0.0, 1.0 - progress), 0.58)
	# Immediate forceful discharge, then the authored progressively sparse forks.
	_beam.mesh = BEAM_MESHES[phase]
	_set_link(_beam, _beam_material, source, target, visual_scale)
	_set_current(_beam_material, energy * (1.0 + 0.32 * (1.0 - smoothstep(0.0, 0.24, progress))), age, sequence)
	var basis := _link_basis(source, target)
	var rupture := 1.0 - smoothstep(0.04, 0.48, progress)
	_charge.visible = rupture > 0.001
	if _charge.visible:
		_charge.mesh = CHARGE_MESHES[posmod(sequence + phase, CHARGE_MESHES.size())]
		_charge.global_transform = Transform3D(basis.scaled_local(Vector3.ONE * visual_scale * (0.86 + progress)), source)
		_charge.force_update_transform()
		_set_current(_charge_material, rupture * 0.7, age, sequence)
	_set_aura(_aura, _aura_material, source,
		CHARGE_RADIUS * visual_scale * (1.12 + minf(progress, 0.45) * 0.8), rupture * 0.9, age, sequence)
	# The target position is the caller's real enemy contact, not an authored dummy.
	# Forks spread through a slanted plane with depth, oriented to the incoming bolt.
	_impact.visible = true
	var impact_size := visual_scale * lerpf(0.82, 1.10, smoothstep(0.0, 0.15, progress))
	_impact.global_transform = Transform3D(basis.scaled_local(Vector3.ONE * impact_size), target)
	_impact.force_update_transform()
	_set_current(_impact_material, energy, age, sequence)
	_set_aura(_contact_aura, _contact_material, target,
		visual_scale * (0.10 + 0.075 * smoothstep(0.0, 0.3, progress)), energy, age, sequence)


func _prepare() -> void:
	if _configured:
		return
	_charge_material = _material(TUBE_SHADER)
	_beam_material = _material(TUBE_SHADER)
	_impact_material = _material(TUBE_SHADER)
	_aura_material = _material(AURA_SHADER)
	_contact_material = _material(AURA_SHADER)
	_contact_material.set_shader_parameter("impact", true)
	_charge = _mesh_node("ChargeCurrents", CHARGE_MESHES[0], _charge_material)
	_beam = _mesh_node("DischargeCurrent", BEAM_MESHES[0], _beam_material)
	_impact = _mesh_node("ContactForks", IMPACT_MESH, _impact_material)
	if _aura_mesh == null:
		_aura_mesh = SphereMesh.new()
		# The low-detail hull encloses the exact analytic sphere integrated
		# by the shader; radius_world still defines the visible boundary.
		_aura_mesh.radius = 1.04
		_aura_mesh.height = 2.08
		_aura_mesh.radial_segments = 16
		_aura_mesh.rings = 8
	_aura = _mesh_node("SphericalChargeAura", _aura_mesh, _aura_material)
	_contact_aura = _mesh_node("ContactPlasma", _aura_mesh, _contact_material)
	for i in range(MAX_ELECTRODES):
		var material := _material(TUBE_SHADER)
		_feed_materials.append(material)
		_feeds.append(_mesh_node("ElectrodeFeed%d" % i, FEED_MESHES[0], material))
	_configured = true


func _material(shader: Shader) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	return result


func _mesh_node(label: String, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = mesh
	result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	result.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	result.visible = false
	add_child(result)
	return result


func _set_current(material: ShaderMaterial, energy: float, age: float, sequence: int) -> void:
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("event_age", age)
	material.set_shader_parameter("seed_phase", float(posmod(sequence, 97)) * 0.618)


func _set_link(node: MeshInstance3D, material: ShaderMaterial,
		start: Vector3, end: Vector3, thickness: float) -> void:
	var distance := start.distance_to(end)
	node.visible = distance > 0.001 and start.is_finite() and end.is_finite()
	if not node.visible:
		return
	# Uniform node scaling sets thickness; the shader stretches only longitudinal
	# center positions, keeping the live target attached at every sample.
	node.global_transform = Transform3D(_link_basis(start, end).scaled_local(Vector3.ONE * thickness), start)
	node.force_update_transform()
	material.set_shader_parameter("beam_length", distance / thickness)
	# GPU-deformed center positions need CPU-visible bounds for scene culling.
	# Late authored forks extend to station 1.03434; include their overshoot.
	node.custom_aabb = AABB(Vector3(-0.70, -0.70, -0.35), Vector3(1.40, 1.40, distance / thickness * 1.04 + 0.85))


func _set_aura(node: MeshInstance3D, material: ShaderMaterial, center: Vector3,
		radius: float, energy: float, age: float, sequence: int) -> void:
	node.visible = _volume_enabled and energy > 0.001
	if not node.visible:
		return
	node.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius), center)
	node.force_update_transform()
	material.set_shader_parameter("radius_world", radius)
	_set_current(material, energy, age, sequence)


static func _link_basis(start: Vector3, end: Vector3) -> Basis:
	var direction := end - start
	if direction.length_squared() < 0.000001:
		return Basis.IDENTITY
	var forward := direction.normalized()
	var right := Vector3.UP.cross(forward)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT.cross(forward)
	right = right.normalized()
	return Basis(right, forward.cross(right).normalized(), forward)


static func _valid_sample(age: float, duration: float) -> bool:
	return is_finite(age) and is_finite(duration) and age >= 0.0 and duration > 0.0 and age < duration
