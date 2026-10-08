extends RefCounted
const StageResources = preload("res://presentation/stage_resources.gd")
## Shared authored stone/core, one collapse pulse and combat-clock-only residue.
## Root-owned attachments disappear with their walker/corpse; no process/tweens.
const LIFETIME := 2.75
const COLLAPSE := 2.2
const FADE_END := 2.65
const CONTACT := 70.0 / 60.0
const CORE_EMISSION := 0.30
const CORE_LIGHT := 0.004
const CORE_SHADER = preload("res://effects/boss_core.gdshader")
const CORE_MASK := "res://assets/effects/boss_core_mask.png"
static var _materials := {}
static var _chip_meshes: Array[BoxMesh] = []
static var _chip_material: ShaderMaterial
static var _puff_mesh: SphereMesh
static var _puff_material: ShaderMaterial


static func prepare(entry: Dictionary, model: Node3D) -> void:
	# Called before status/death attachments are added, so only the authored body
	# receives the core shader. Imported/shared glTF materials stay untouched.
	entry.boss_bodies = model.find_children("*", "MeshInstance3D", true, false)
	entry.boss_materials = []
	for body: MeshInstance3D in entry.boss_bodies:
		for surface in range(body.mesh.get_surface_count()):
			var original := body.get_active_material(surface) as StandardMaterial3D
			if original == null: continue
			if not _materials.has(original):
				var material := ShaderMaterial.new()
				material.shader = CORE_SHADER
				material.resource_name = original.resource_name
				material.set_shader_parameter("albedo_map", original.albedo_texture)
				material.set_shader_parameter("roughness_map", original.roughness_texture)
				material.set_shader_parameter("metallic_map", original.metallic_texture)
				material.set_shader_parameter("emission_map", original.emission_texture)
				material.set_shader_parameter("core_mask", StageResources.load_resource(CORE_MASK))
				material.set_shader_parameter("albedo_factor", original.albedo_color)
				material.set_shader_parameter("emission_factor", Vector3(original.emission.r, original.emission.g, original.emission.b))
				material.set_shader_parameter("roughness_factor", original.roughness)
				material.set_shader_parameter("metallic_factor", original.metallic)
				material.set_shader_parameter("specular_factor", original.metallic_specular)
				material.set_shader_parameter("authored_emission_scale", original.emission_energy_multiplier)
				# Frost coats sample the original maps while preserving this shader.
				material.set_meta("frost_source_material", original)
				_materials[original] = material
			body.set_surface_override_material(surface, _materials[original])
			entry.boss_materials.append(_materials[original])
		body.set_instance_shader_parameter("core_strength", CORE_EMISSION)
		body.set_instance_shader_parameter("death_light", 1.0)
		body.set_instance_shader_parameter("death_opacity", 1.0)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return
	entry.boss_skeleton = skeletons[0]
	var attachment := BoneAttachment3D.new()
	attachment.name = "BossCoreAttachment"
	attachment.bone_name = "spine"
	entry.boss_skeleton.add_child(attachment)
	var light := OmniLight3D.new()
	light.name = "BossCoreLight"
	light.position = Vector3(0.02707356, 0.20618251, 0.25710177)
	light.light_color = Color(1.0, 0.10, 0.035)
	light.light_energy = CORE_LIGHT
	light.omni_range = 0.32
	light.omni_attenuation = 2.0
	light.light_specular = 0.45
	light.shadow_enabled = false
	attachment.add_child(light)
	entry.boss_core_light = light


static func attach(entry: Dictionary, walker: Dictionary) -> void:
	entry.death_skeleton = entry.boss_skeleton
	entry.death_start_pose = []
	if not walker.is_empty() and is_instance_valid(walker.root) and walker.has("boss_skeleton"):
		var live: Skeleton3D = walker.boss_skeleton
		for bone in range(live.get_bone_count()):
			entry.death_start_pose.append(live.get_bone_pose(bone))
	entry.death_settled = false
	entry.death_pose_time = -INF
	entry.death_pose_evaluations = 0
	_setup_debris(entry)
	sample(entry, 0.0)


static func sample(entry: Dictionary, age: float) -> void:
	entry.death_age = age
	var pose_time := clampf(age, 0.0, COLLAPSE)
	# A paused frame and settled hold never re-evaluate or re-blend the rig.
	# Rewinding into collapse invalidates the cache and resumes manual sampling.
	if pose_time != float(entry.death_pose_time):
		if entry.player.current_animation != "BossDeath" or not entry.player.is_playing():
			entry.player.play("BossDeath")
		entry.player.seek(pose_time, true)
		entry.death_pose_evaluations += 1
		entry.death_pose_time = pose_time
		entry.death_settled = age >= COLLAPSE
		if entry.death_settled: entry.player.pause()
		var blend := smoothstep(0.0, 0.15, age)
		if blend < 1.0:
			var skeleton: Skeleton3D = entry.death_skeleton
			for bone in range(entry.death_start_pose.size()):
				var authored := skeleton.get_bone_pose(bone)
				skeleton.set_bone_pose(bone, entry.death_start_pose[bone].interpolate_with(authored, blend))
	var light := 1.0 - smoothstep(0.3, 0.9, age)
	var pulse := sin(PI * clampf(age / 0.10, 0.0, 1.0))
	var opacity := 1.0 - smoothstep(COLLAPSE, FADE_END, age)
	for body: MeshInstance3D in entry.boss_bodies:
		body.set_instance_shader_parameter("death_light", light)
		body.set_instance_shader_parameter("core_strength", (CORE_EMISSION + 2.8 * pulse) * light)
		body.set_instance_shader_parameter("death_opacity", opacity)
		body.visible = age < FADE_END
	entry.boss_core_light.light_energy = CORE_LIGHT * (1.0 + 2.0 * pulse) * light
	entry.boss_core_light.visible = light > 0.0
	_sample_debris(entry, age - CONTACT)


static func _setup_debris(entry: Dictionary) -> void:
	# Tiny contact accents from the accepted collapse, sharing immutable meshes.
	if _chip_material == null:
		_chip_material = ShaderMaterial.new()
		_chip_material.shader = preload("res://effects/boss_death_chip.gdshader")
		for index in range(3):
			var box := BoxMesh.new()
			box.size = Vector3(0.018, 0.027, 0.021) * (1.0 + 0.15 * index)
			_chip_meshes.append(box)
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.09
		_puff_mesh.height = 0.18
		_puff_mesh.radial_segments = 12
		_puff_mesh.rings = 6
		_puff_material = ShaderMaterial.new()
		_puff_material.shader = preload("res://effects/boss_death_dust.gdshader")
	entry.death_chips = []
	for index in range(5):
		var mesh := MeshInstance3D.new()
		mesh.name = "BossDeathChip%d" % index
		mesh.mesh = _chip_meshes[index % 3]
		mesh.material_override = _chip_material
		entry.root.add_child(mesh)
		var angle := float(index) * 2.399
		entry.death_chips.append({"mesh": mesh,
			"origin": Vector3(-0.357, 0.035, 0.026) if index < 3 else Vector3(-0.59, 0.035, 0.54),
			"velocity": Vector3(cos(angle) * 0.6, 0.65 + float(index % 3) * 0.08, sin(angle) * 0.3),
			"spin": Vector3(2 + index, 4 - index, 1 + index)})
		mesh.visible = false
	entry.death_puffs = []
	for index in range(4):
		var mesh := MeshInstance3D.new()
		mesh.name = "BossDeathPuff%d" % index
		mesh.mesh = _puff_mesh
		mesh.material_override = _puff_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		entry.root.add_child(mesh)
		var angle := float(index) * PI * 0.5
		entry.death_puffs.append({"mesh": mesh,
			"origin": (Vector3(-0.357, 0.045, 0.026) if index < 3 else Vector3(-0.59, 0.045, 0.54)) + Vector3(cos(angle) * 0.06, 0.0, sin(angle) * 0.06),
			"velocity": Vector3(cos(angle) * 0.2, 0.035, sin(angle) * 0.2)})
		mesh.visible = false


static func _sample_debris(entry: Dictionary, age: float) -> void:
	for chip: Dictionary in entry.death_chips:
		chip.mesh.visible = age >= 0.0 and age < 0.5
		if not chip.mesh.visible: continue
		chip.mesh.position = chip.origin + chip.velocity * age + Vector3(0.0, -1.5 * age * age, 0.0)
		chip.mesh.position.y = maxf(chip.mesh.position.y, 0.025)
		chip.mesh.rotation = chip.spin * age
		chip.mesh.set_instance_shader_parameter("death_opacity", 1.0 - smoothstep(0.25, 0.5, age))
	for puff: Dictionary in entry.death_puffs:
		puff.mesh.visible = age >= 0.0 and age < 0.6
		if not puff.mesh.visible: continue
		puff.mesh.position = puff.origin + puff.velocity * age
		puff.mesh.scale = Vector3(1.0, 0.3, 0.8) * (1.0 + age * 2.5)
		puff.mesh.set_instance_shader_parameter("dust_alpha", 1.0 - smoothstep(0.1, 0.6, age))


static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	if "boss" in enemy_types or "shieldBoss" in enemy_types or "forgeBoss" in enemy_types: return
	_materials.clear()
	_chip_meshes.clear()
	_chip_material = null
	_puff_mesh = null
	_puff_material = null
