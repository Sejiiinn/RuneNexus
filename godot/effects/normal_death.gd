extends RefCounted
## Preserve the approved collapse, then fade its held residue on the combat clock.
const COLLAPSE := 1.4
const FADE_START := COLLAPSE + 0.10
const LIFETIME := FADE_START + 0.35
static var _materials := {}

static func attach(entry: Dictionary) -> void:
	entry.death_bodies = entry.root.find_children("*", "MeshInstance3D", true, false)
	entry.death_originals = []
	entry.death_fading = false
	for body: MeshInstance3D in entry.death_bodies:
		var originals: Array = []
		for surface in range(body.mesh.get_surface_count()):
			var original := body.get_active_material(surface) as StandardMaterial3D
			originals.append(original)
			if not _materials.has(original):
				var material := ShaderMaterial.new()
				material.shader = preload("res://effects/normal_death_body.gdshader")
				material.set_shader_parameter("albedo_map", original.albedo_texture)
				material.set_shader_parameter("normal_map", original.normal_texture)
				material.set_shader_parameter("roughness_map", original.roughness_texture)
				material.set_shader_parameter("emission_map", original.emission_texture)
				material.set_shader_parameter("albedo_tint", original.albedo_color)
				material.set_shader_parameter("roughness_factor", original.roughness)
				material.set_shader_parameter("normal_strength", original.normal_scale)
				material.set_shader_parameter("emission_tint", original.emission * original.emission_energy_multiplier)
				_materials[original] = material
		entry.death_originals.append(originals)
	sample(entry, 0.0)

static func sample(entry: Dictionary, age: float) -> void:
	# Keep authored PBR through collapse/settle, then use the same opaque
	# coverage discard as tank/boss stone. Rewinds restore the original material.
	var fading := age >= FADE_START
	var opacity := 1.0 - smoothstep(FADE_START, LIFETIME, age)
	for index in range(entry.death_bodies.size()):
		var body: MeshInstance3D = entry.death_bodies[index]
		if fading != entry.death_fading:
			for surface in range(body.mesh.get_surface_count()):
				var original: StandardMaterial3D = entry.death_originals[index][surface]
				body.set_surface_override_material(surface, _materials[original] if fading else original)
		body.set_instance_shader_parameter("death_opacity", opacity)
	entry.death_fading = fading
