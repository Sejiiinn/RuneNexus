extends RefCounted
## Fixed death clip + shared deterministic motes. No physics or particle simulation.
static var _motes: MultiMesh
static var _material: ShaderMaterial
static var _body_materials := {}


static func attach(entry: Dictionary) -> void:
	entry.death_bodies = entry.root.find_children("*", "MeshInstance3D", true, false)
	for body: MeshInstance3D in entry.death_bodies:
		for surface in range(body.mesh.get_surface_count()):
			var original := body.get_active_material(surface) as StandardMaterial3D
			if not _body_materials.has(original):
				var material := ShaderMaterial.new()
				material.shader = preload("res://effects/hound_death_body.gdshader")
				material.set_shader_parameter("albedo_map", original.albedo_texture)
				material.set_shader_parameter("normal_map", original.normal_texture)
				material.set_shader_parameter("roughness_map", original.roughness_texture)
				material.set_shader_parameter("emission_map", original.emission_texture)
				material.set_shader_parameter("albedo_tint", original.albedo_color)
				material.set_shader_parameter("roughness_factor", original.roughness)
				material.set_shader_parameter("normal_strength", original.normal_scale)
				material.set_shader_parameter("emission_tint", original.emission * original.emission_energy_multiplier)
				_body_materials[original] = material
			body.set_surface_override_material(surface, _body_materials[original])
	if _motes == null:
		var point := SphereMesh.new()
		point.radius = 0.012
		point.height = 0.024
		point.radial_segments = 6
		point.rings = 3
		_motes = MultiMesh.new()
		_motes.transform_format = MultiMesh.TRANSFORM_3D
		_motes.use_custom_data = true
		_motes.mesh = point
		_motes.instance_count = 12
		for i in range(12):
			var angle := float(i) * 2.399963
			var radius := 0.18 + float(i % 3) * 0.10
			var position := Vector3(cos(angle) * radius, 0.65 + float(i % 4) * 0.11, sin(angle) * radius)
			_motes.set_instance_transform(i, Transform3D(Basis.IDENTITY, position))
			_motes.set_instance_custom_data(i, Color(cos(angle), 0.55 + float(i % 3) * 0.2, sin(angle), float(i) / 12.0))
		_material = ShaderMaterial.new()
		_material.shader = preload("res://effects/hound_death.gdshader")
	var motes := MultiMeshInstance3D.new()
	motes.multimesh = _motes
	motes.material_override = _material
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.custom_aabb = AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, 2.5, 2.0))
	entry.root.add_child(motes)
	entry.death_motes = motes
	sample(entry, 0.0)


static func sample(entry: Dictionary, age: float) -> void:
	var fade := smoothstep(0.12, 0.55, age)
	for body: MeshInstance3D in entry.death_bodies:
		# GeometryInstance3D.transparency is ignored by the shipping Mobile renderer.
		body.set_instance_shader_parameter("death_opacity", 1.0 - fade)
	entry.death_motes.set_instance_shader_parameter("death_age", age)


static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	if "fast" in enemy_types: return
	_motes = null
	_material = null
	_body_materials.clear()
