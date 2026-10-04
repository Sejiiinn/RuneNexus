extends Node3D
## One shared 3D mesh/batch. Per-instance GPU age drives the authored burst.
const DUST_SCENE := "res://assets/effects/placement_dust.glb"
const SHADER = preload("res://effects/placement_dust.gdshader")
const MAX_PUFFS := 32
var puffs := 0
const MAX_BURSTS := 32
const DURATION := 19.0/30.0
const MANIFEST := "res://assets/effects/placement_dust.json"
var _particles: Array = []
var map_size := Vector2i(8,10)
var camera: Camera3D
var bursts: Dictionary = {}
var _ids: Array[int] = []
var _epoch_usec := Time.get_ticks_usec()
var _batch: MultiMeshInstance3D
var _material: ShaderMaterial
var _geometry_pose := Transform3D.IDENTITY

func _ready() -> void:
	name = "PlacementDust"
	set_meta("exclude_selection_mask",true)
	var packed = load(DUST_SCENE)
	if not packed is PackedScene:
		push_error("Placement dust 3D mesh is missing")
		return
	var source: Node3D = packed.instantiate()
	var geometry := _find_mesh(source,Transform3D.IDENTITY)
	if geometry.is_empty():
		source.free()
		push_error("Placement dust requires a true 3D MeshInstance3D")
		return
	_geometry_pose = geometry.pose
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_particles = authored.particles
	puffs = _particles.size()
	assert(puffs > 0 and puffs <= MAX_PUFFS,"Dust authored batch exceeds capacity")
	var mesh: Mesh = geometry.mesh
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var volume: Dictionary = authored.volume
	var offsets := PackedVector3Array()
	for offset: Array in volume.warp_offsets: offsets.append(Vector3(offset[0],offset[1],offset[2]))
	var inputs := {
		"shape_range":Vector2(volume.shape_smoothstep[0],volume.shape_smoothstep[1]),
		"noise_scale":float(volume.noise_scale),
		"noise_strength":Vector2(volume.noise_strength[0],volume.noise_strength[1]),
		"warp_scale":float(volume.warp_scale),"warp_amplitude":float(volume.warp_amplitude),
		"warp_offsets":offsets,"index_phase":float(volume.index_phase),
		"noise_advection":Vector3(volume.noise_advection[0],volume.noise_advection[1],volume.noise_advection[2]),
		"density_multiplier":float(volume.density_multiplier),
		"native_tint":Vector3(volume.native_tint[0],volume.native_tint[1],volume.native_tint[2]),
		"native_tint_mix":float(volume.native_tint_mix),
		"ray_steps":clampi(int(volume.native_steps),1,16),"opaque_depth_clip":bool(volume.opaque_depth_clip),
		"color_alpha_factor":Vector2(volume.native_color_alpha_factor[0],volume.native_color_alpha_factor[1])
	}
	for parameter: String in inputs: _material.set_shader_parameter(parameter,inputs[parameter])
	var low: Array = authored.bounds_godot[0]
	var high: Array = authored.bounds_godot[1]
	var mesh_size := Vector3(high[0]-low[0],high[1]-low[1],high[2]-low[2])
	_material.set_shader_parameter("mesh_size",mesh_size)
	var maximum_width := 0.0
	var maximum_height := 0.0
	var paths := PackedVector4Array()
	var sizes := PackedVector4Array()
	var turns := PackedVector2Array()
	for particle: Dictionary in _particles:
		maximum_width = maxf(maximum_width,maxf(particle.start_width,particle.end_width))
		maximum_height = maxf(maximum_height,maxf(particle.start_height,particle.end_height))
		paths.append(Vector4(particle.angle,particle.start_radius,particle.end_radius,particle.lift))
		sizes.append(Vector4(particle.start_width,particle.end_width,particle.start_height,particle.end_height))
		turns.append(Vector2(particle.rotation,particle.spin))
	_material.set_shader_parameter("start_center_factor",float(authored.height_factors[0]))
	_material.set_shader_parameter("end_center_factor",float(authored.height_factors[1]))
	_material.set_shader_parameter("particle_path",paths)
	_material.set_shader_parameter("particle_size",sizes)
	_material.set_shader_parameter("particle_turn",turns)
	var motion := PackedVector4Array()
	var maximum_size := 0.0
	for point: Array in authored.motion_curve:
		motion.append(Vector4(point[0],point[1],point[2],point[3]))
		maximum_size = maxf(maximum_size,float(point[2]))
	var opacity := PackedVector2Array()
	for point: Array in authored.alpha_curve: opacity.append(Vector2(point[0],point[1]))
	_material.set_shader_parameter("motion_curve",motion)
	_material.set_shader_parameter("alpha_curve",opacity)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_PUFFS*MAX_BURSTS
	multimesh.visible_instance_count = 0
	_batch = MultiMeshInstance3D.new()
	_batch.name = "DustPuffs"
	_batch.set_meta("exclude_selection_mask",true)
	_batch.multimesh = multimesh
	_batch.material_override = _material
	_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batch.extra_cull_margin = 1.0
	# The engine cannot see vertex-shader scaling. Bound its largest scale over
	# every puff and its whole life; rotations preserve this bound in any view.
	# Imported mesh LODs still choose detail from the viewport and camera distance.
	_batch.lod_bias = maximum_size*maxf(maximum_width/minf(mesh_size.x,mesh_size.z),maximum_height/mesh_size.y)
	add_child(_batch)
	source.free()

func _find_mesh(node: Node3D, parent_pose: Transform3D) -> Dictionary:
	var pose := parent_pose*node.transform
	if node is MeshInstance3D: return {"mesh":node.mesh,"pose":pose}
	for child in node.get_children():
		if child is Node3D:
			var geometry := _find_mesh(child,pose)
			if not geometry.is_empty(): return geometry
	return {}

func begin_cue(id: int, cue: Dictionary) -> void:
	emit_build(id,Vector3(cue.x+0.5-map_size.x/2.0,0,cue.y+0.5-map_size.y/2.0))

func emit_build(id: int, origin: Vector3) -> void:
	if bursts.has(id) or not is_instance_valid(_batch): return
	if _ids.size() >= MAX_BURSTS: cancel_build(_ids[0])
	bursts[id] = {"origin":origin,"started":_seconds(),"seed":id*17+int(Time.get_ticks_usec()%997)}
	_ids.append(id)
	_write_burst(_ids.size()-1,id)
	_batch.multimesh.visible_instance_count = _ids.size()*puffs
	update_time()

func cancel_build(id: int) -> void:
	var slot := _ids.find(id)
	if slot < 0: return
	bursts.erase(id)
	_ids.remove_at(slot)
	for index in range(slot,_ids.size()): _write_burst(index,_ids[index])
	_batch.multimesh.visible_instance_count = _ids.size()*puffs

func _write_burst(slot: int, id: int) -> void:
	var burst: Dictionary = bursts[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(burst.seed)
	var rotation := rng.randf_range(-PI,PI)
	for puff in puffs:
		var pose := Transform3D(Basis(Vector3.UP,rotation),burst.origin)
		_batch.multimesh.set_instance_transform(slot*puffs+puff,pose*_geometry_pose)
		_batch.multimesh.set_instance_custom_data(slot*puffs+puff,Color(float(burst.started),DURATION,float(puff),0.0))

func _seconds() -> float:
	return (Time.get_ticks_usec()-_epoch_usec)/1000000.0

func update_time() -> void:
	if _material:
		_material.set_shader_parameter("real_time",_seconds())
		if is_instance_valid(camera): _material.set_shader_parameter("orthographic",camera.projection == Camera3D.PROJECTION_ORTHOGONAL)

func clear() -> void:
	bursts.clear()
	_ids.clear()
	if is_instance_valid(_batch): _batch.multimesh.visible_instance_count = 0
