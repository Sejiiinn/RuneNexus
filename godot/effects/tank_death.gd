extends RefCounted
## Approved rigid rubble clip, then held stone residue on the combat clock.
const COLLAPSE := 2.5
const FADE_START := COLLAPSE + 0.10
const LIFETIME := FADE_START + 0.35
const HANDOFF_SECONDS := 0.10
# Godot sanitizes periods in mesh node names, while bone names retain them.
const CHUNK_BONES := {
	"Head": "Head", "Chest_L": "Spine", "Chest_R": "Spine",
	"Pelvis": "Pelvis", "Foot_L": "Foot.L", "Foot_R": "Foot.R",
	"Forearm_L": "Forearm.L", "Forearm_R": "Forearm.R",
	"Thigh_L": "Thigh.L", "Thigh_R": "Thigh.R",
	"UpperArm_L": "UpperArm.L", "UpperArm_R": "UpperArm.R",
}
static var _materials := {}

static func attach(entry: Dictionary, walker: Dictionary) -> void:
	entry.death_bodies = entry.root.find_children("*", "MeshInstance3D", true, false)
	entry.death_originals = []
	entry.death_start_transforms = {}
	entry.death_fading = false
	var live: Skeleton3D
	if not walker.is_empty() and is_instance_valid(walker.root):
		var rigs: Array = walker.root.find_children("*", "Skeleton3D", true, false)
		if not rigs.is_empty(): live = rigs[0] as Skeleton3D
	for body: MeshInstance3D in entry.death_bodies:
		var originals: Array = []
		for surface in range(body.mesh.get_surface_count()):
			var original := body.get_active_material(surface) as StandardMaterial3D
			originals.append(original)
			if original != null and not _materials.has(original):
				var material := ShaderMaterial.new()
				material.shader = preload("res://effects/tank_death_body.gdshader")
				material.resource_name = original.resource_name
				material.set_shader_parameter("albedo_map", original.albedo_texture)
				material.set_shader_parameter("normal_map", original.normal_texture)
				material.set_shader_parameter("roughness_map", original.roughness_texture)
				material.set_shader_parameter("metallic_map", original.metallic_texture)
				material.set_shader_parameter("ao_map", original.ao_texture)
				material.set_shader_parameter("emission_map", original.emission_texture)
				material.set_shader_parameter("albedo_tint", original.albedo_color)
				material.set_shader_parameter("roughness_factor", original.roughness)
				material.set_shader_parameter("metallic_factor", original.metallic)
				material.set_shader_parameter("normal_strength", original.normal_scale)
				material.set_shader_parameter("emission_tint", original.emission * original.emission_energy_multiplier if original.emission_enabled else Color.BLACK)
				material.set_shader_parameter("use_albedo", original.albedo_texture != null)
				material.set_shader_parameter("use_normal", original.normal_enabled and original.normal_texture != null)
				material.set_shader_parameter("use_roughness", original.roughness_texture != null)
				material.set_shader_parameter("use_metallic", original.metallic_texture != null)
				material.set_shader_parameter("use_emission", original.emission_enabled and original.emission_texture != null)
				material.set_shader_parameter("use_ao", original.ao_enabled and original.ao_texture != null)
				_materials[original] = material
		entry.death_originals.append(originals)
		# Each chunk starts at the interrupted live bone delta. No corpse rig
		# or index correspondence is assumed; source object tracks stay intact.
		var chunk := String(body.name).trim_prefix("DeathStone_")
		if live == null or not CHUNK_BONES.has(chunk): continue
		var bone := live.find_bone(CHUNK_BONES[chunk])
		if bone < 0: continue
		var to_root: Transform3D = walker.root.global_transform.affine_inverse() * live.global_transform
		var delta := to_root * live.get_bone_global_pose(bone) * live.get_bone_global_rest(bone).affine_inverse() * to_root.affine_inverse()
		var authored: Transform3D = entry.root.global_transform.affine_inverse() * body.global_transform
		entry.death_start_transforms[body] = body.get_parent().global_transform.affine_inverse() * entry.root.global_transform * delta * authored
	sample(entry, 0.0)

static func sample(entry: Dictionary, age: float) -> void:
	# update_deaths seeks the authored clip before this blend, so pause/rewind
	# cannot accumulate a second handoff over an already blended transform.
	var blend := smoothstep(0.0, HANDOFF_SECONDS, age)
	if blend < 1.0:
		for body: MeshInstance3D in entry.death_start_transforms:
			body.transform = entry.death_start_transforms[body].interpolate_with(body.transform, blend)
	var fading := age >= FADE_START
	var opacity := 1.0 - smoothstep(FADE_START, LIFETIME, age)
	for index in range(entry.death_bodies.size()):
		var body: MeshInstance3D = entry.death_bodies[index]
		if fading != entry.death_fading:
			for surface in range(body.mesh.get_surface_count()):
				var original: StandardMaterial3D = entry.death_originals[index][surface]
				if original != null:
					body.set_surface_override_material(surface, _materials[original] if fading else original)
		body.set_instance_shader_parameter("death_opacity", opacity)
	entry.death_fading = fading

static func retain_stage(enemy_types: Array, _tower_types: Array) -> void:
	if "tank" not in enemy_types: _materials.clear()
