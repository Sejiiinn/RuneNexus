extends RefCounted
## Authored collapse and combat-clock residue. All data is presentation only.
const LIFETIME := 1.4
const COLLAPSE := 0.7
static var _materials := {}
static var _dust: MultiMesh
static var _dust_material: ShaderMaterial

static func attach(entry: Dictionary, walker: Dictionary) -> void:
	entry.death_bodies = entry.root.find_children("*", "MeshInstance3D", true, false)
	for body: MeshInstance3D in entry.death_bodies:
		for surface in range(body.mesh.get_surface_count()):
			var original := body.get_active_material(surface)
			if not _materials.has(original):
				var material := ShaderMaterial.new()
				if original.resource_name.begins_with("Tank_Amber"):
					material.shader = preload("res://effects/tank_death_core.gdshader")
					material.set_shader_parameter("shell",original.resource_name.contains("Shell"))
				else:
					material.shader = preload("res://effects/tank_death_body.gdshader")
					var stone := original as StandardMaterial3D
					material.set_shader_parameter("albedo_map",stone.albedo_texture)
					material.set_shader_parameter("normal_map",stone.normal_texture)
					material.set_shader_parameter("roughness_map",stone.roughness_texture)
					material.set_shader_parameter("emission_map",stone.emission_texture)
				material.resource_name = original.resource_name
				_materials[original] = material
			body.set_surface_override_material(surface,_materials[original])
	entry.death_skeleton = entry.root.find_children("*","Skeleton3D",true,false)[0]
	entry.death_start_pose = []
	if not walker.is_empty() and is_instance_valid(walker.root):
		var live: Skeleton3D = walker.root.find_children("*","Skeleton3D",true,false)[0]
		for bone in range(live.get_bone_count()):
			entry.death_start_pose.append(live.get_bone_pose(bone))
	if _dust == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(.24,.15)
		_dust = MultiMesh.new()
		_dust.transform_format = MultiMesh.TRANSFORM_3D
		_dust.use_custom_data = true
		_dust.mesh = quad
		_dust.instance_count = 8
		for i in range(8):
			var angle := float(i % 4)*PI*.5
			# Keep the stone opaque and place the small puffs outside its footprint.
			var center := Vector3(.40,.065,.06) if i < 4 else Vector3(.0,.065,.70)
			var spread := Vector3(cos(angle)*.15,0.0,sin(angle)*.07)
			_dust.set_instance_transform(i,Transform3D(Basis.IDENTITY,center+spread))
			_dust.set_instance_custom_data(i,Color(cos(angle),sin(angle),0.0,.37 if i<4 else .65))
		_dust_material = ShaderMaterial.new()
		_dust_material.shader = preload("res://effects/tank_death_dust.gdshader")
	var dust := MultiMeshInstance3D.new()
	dust.multimesh = _dust
	dust.material_override = _dust_material
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.custom_aabb = AABB(Vector3(-1,0,-1),Vector3(2,1,2))
	entry.root.add_child(dust)
	entry.death_dust = dust
	sample(entry,0.0)

static func sample(entry: Dictionary, age: float) -> void:
	# No reset pose pop when the kill interrupts either support or swing gait.
	var skeleton: Skeleton3D = entry.death_skeleton
	var blend := smoothstep(0.0,.10,age)
	if blend < 1.0:
		for bone in range(entry.death_start_pose.size()):
			var authored: Transform3D = skeleton.get_bone_pose(bone)
			skeleton.set_bone_pose(bone,entry.death_start_pose[bone].interpolate_with(authored,blend))
	var opacity := 1.0-smoothstep(1.08,LIFETIME,age)
	# A single small amber flash, then the light dies by 0.15 combat seconds.
	var light := (1.0+.55*sin(PI*clampf(age/.10,0.0,1.0)))*(1.0-smoothstep(.10,.15,age))
	for body: MeshInstance3D in entry.death_bodies:
		body.set_instance_shader_parameter("death_opacity",opacity)
		body.set_instance_shader_parameter("death_light",light)
	entry.death_dust.set_instance_shader_parameter("death_age",age)


static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	if "tank" in enemy_types: return
	_materials.clear()
	_dust = null
	_dust_material = null
