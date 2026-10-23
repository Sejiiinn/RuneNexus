extends RefCounted
## Three shared status meshes retain batching. A six-bone presentation-only skin
## follows the rigid GLB pieces; combat state and the model itself stay rigid.
static var _surfaces := {}
static var _meshes := {}
static var _materials := {}
static var _skin: Skin
const BURN_COUNTS := [24, 8, 5, 5, 5, 5]
const SHARD_COUNTS := [16, 8, 4, 4, 4, 4]
const GRAIN_COUNTS := [43, 20, 8, 8, 8, 8]

static func _surface(mesh: Mesh) -> Dictionary:
	var key := mesh.get_instance_id()
	if _surfaces.has(key): return _surfaces[key]
	var triangles: Array = []
	var area := 0.0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for offset in range(0, count, 3):
			var a := indices[offset] if not indices.is_empty() else offset
			var b := indices[offset+1] if not indices.is_empty() else offset+1
			var c := indices[offset+2] if not indices.is_empty() else offset+2
			var weight := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length() * .5
			if weight < .00000001: continue
			area += weight
			triangles.append([vertices[a], vertices[b], vertices[c], (normals[a]+normals[b]+normals[c]).normalized(), area])
	var result := {"source": mesh, "triangles": triangles, "area": area}
	_surfaces[key] = result
	return result

static func _sample(data: Dictionary, index: int, count: int) -> Array:
	var target: float = data.area * (float(index) + .5) / float(count)
	var triangles: Array = data.triangles
	var low := 0
	var high := triangles.size() - 1
	while low < high:
		var mid := (low+high)/2
		if float(triangles[mid][4]) < target: low = mid+1
		else: high = mid
	var triangle: Array = triangles[low]
	var u := sqrt(fposmod(float(index)*.61803398875+.29, 1.0))
	var v := fposmod(float(index)*.41421356237+.17, 1.0)
	return [triangle[0]*(1.0-u)+triangle[1]*(u*(1.0-v))+triangle[2]*(u*v), triangle[3]]

static func _mesh(entry: Dictionary, template: Mesh, mode: String, offset: int) -> ArrayMesh:
	var key := mode
	for body: MeshInstance3D in entry.parts: key += ":"+str(body.mesh.get_instance_id())
	if _meshes.has(key): return _meshes[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var arrays := template.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var source_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if source_uv.is_empty(): source_uv.resize(source_vertices.size())
	var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var global_index := 0
	for part in range(entry.parts.size()):
		var data := _surface(entry.parts[part].mesh)
		var count: int = BURN_COUNTS[part] if mode == "burn" else (SHARD_COUNTS[part] if mode == "shards" else GRAIN_COUNTS[part])
		for index in range(count):
			var sample := _sample(data, index, count)
			var normal: Vector3 = sample[1]
			var basis := Basis.IDENTITY
			if mode != "burn":
				basis = Basis(Quaternion(Vector3.UP, normal))
				var size := Vector3(.027, .07 + .04*fposmod(float(index)*.618, 1.0), .027) if mode == "shards" else Vector3.ONE * .010
				basis = basis * Basis.from_scale(size)
			var pose := Transform3D(basis, sample[0]+normal*.002)
			var twist := float(global_index)*2.399963
			var base := vertices.size()
			for vertex_index in range(source_vertices.size()):
				var vertex := source_vertices[vertex_index]
				var source_normal := source_normals[vertex_index]
				if mode == "shards":
					if source_uv[vertex_index].y < .5:
						var x := vertex.x
						vertex.x = cos(twist)*x+sin(twist)*vertex.z/.68
						vertex.z = -.68*sin(twist)*x+cos(twist)*vertex.z
					var nx := source_normal.x
					source_normal.x = cos(twist)*nx+.68*sin(twist)*source_normal.z
					source_normal.z = -sin(twist)*nx/.68+cos(twist)*source_normal.z
				vertices.append(pose.origin if mode == "burn" else pose*vertex)
				normals.append((basis.inverse().transposed()*source_normal).normalized())
				uv.append(source_uv[vertex_index])
				uv2.append(Vector2(vertex.x, vertex.y) if mode == "burn" else Vector2.ZERO)
				custom.append_array(PackedFloat32Array([offset+global_index if mode == "burn" else global_index%40, 0.0, 0.0, 0.0]))
				bones.append_array(PackedInt32Array([part,0,0,0]))
				weights.append_array(PackedFloat32Array([1,0,0,0]))
			for vertex_index in source_indices: indices.append(base+vertex_index)
			global_index += 1
	var output := []
	output.resize(Mesh.ARRAY_MAX)
	output[Mesh.ARRAY_VERTEX] = vertices
	output[Mesh.ARRAY_NORMAL] = normals
	output[Mesh.ARRAY_TEX_UV] = uv
	output[Mesh.ARRAY_TEX_UV2] = uv2
	output[Mesh.ARRAY_CUSTOM0] = custom
	output[Mesh.ARRAY_BONES] = bones
	output[Mesh.ARRAY_WEIGHTS] = weights
	output[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	# Source pivots, bob, orbit drift and GPU flame rise all remain inside this.
	result.custom_aabb = AABB(Vector3(-1.1,-.2,-1.1), Vector3(2.2,2.2,2.2))
	_meshes[key] = result
	return result

static func _skeleton(entry: Dictionary) -> Skeleton3D:
	if entry.has("status_skeleton"): return entry.status_skeleton
	var skeleton := Skeleton3D.new()
	skeleton.name = "StatusSkeleton"
	entry.root.add_child(skeleton)
	for part: MeshInstance3D in entry.parts: skeleton.add_bone(part.name)
	if _skin == null:
		_skin = Skin.new()
		for index in range(entry.parts.size()): _skin.add_bind(index, Transform3D.IDENTITY)
	entry.status_skeleton = skeleton
	update(entry)
	return skeleton

static func _effect(entry: Dictionary, label: String, templates: Array, materials: Array, offset: int = 0) -> Node3D:
	var skeleton := _skeleton(entry)
	var container := Node3D.new()
	container.name = label
	entry.root.add_child(container)
	for index in range(templates.size()):
		var mode := "burn" if label in ["EnemyBurn", "EnemyPoison"] else ("shards" if index == 0 else "grains")
		# Poison reuses the burn particle mesh but keeps its own material.
		var material_key := "poison" if label == "EnemyPoison" else mode
		var effect := MeshInstance3D.new()
		effect.mesh = _mesh(entry, templates[index], mode, offset)
		if materials[index] is ShaderMaterial:
			if not _materials.has(material_key):
				var adapted: ShaderMaterial = materials[index].duplicate()
				adapted.set_shader_parameter("skinned_status", true)
				_materials[material_key] = adapted
			effect.material_override = _materials[material_key]
		else: effect.material_override = materials[index]
		effect.skin = _skin
		effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		effect.set_meta("exclude_selection_mask", true)
		effect.set_meta("exclude_enemy_status", true)
		container.add_child(effect)
		effect.skeleton = effect.get_path_to(skeleton)
		if mode == "burn":
			effect.set_instance_shader_parameter("phase_offset", float(entry.root.get_instance_id()%997)/997.0*4.0)
			effect.set_instance_shader_parameter("world_up_motion", true)
	return container

static func burn(entry: Dictionary, active: bool, material: ShaderMaterial, offset: int) -> void:
	if not entry.has("burn"):
		if not active: return
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		entry.burn = _effect(entry, "EnemyBurn", [quad], [material], offset)
	entry.burn.visible = active
	entry.burn_active = active

static func poison(entry: Dictionary, active: bool, material: ShaderMaterial, offset: int) -> void:
	if not entry.has("poison"):
		if not active: return
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		entry.poison = _effect(entry, "EnemyPoison", [quad], [material], offset)
	entry.poison.visible = active
	entry.poison_active = active

static func frost(entry: Dictionary, active: bool, coat: ShaderMaterial, templates: Array, materials: Array) -> void:
	if not entry.has("frost"):
		if not active: return
		var bodies: Array = []
		for part in range(entry.parts.size()):
			var body: MeshInstance3D = entry.parts[part]
			for surface in range(body.mesh.get_surface_count()):
				var source := body.get_active_material(surface) as StandardMaterial3D
				if source == null: continue
				var adapted := coat.duplicate() as ShaderMaterial
				var rest: Transform3D = entry.rest_parts[part]
				adapted.set_shader_parameter("coordinate_transform", rest)
				adapted.set_shader_parameter("preserve_emission_core", source.emission_enabled and source.emission_texture != null)
				adapted.set_shader_parameter("body_emission", source.emission_texture)
				adapted.set_shader_parameter("body_albedo", source.albedo_texture)
				var coated := source.duplicate() as StandardMaterial3D
				coated.next_pass = adapted
				bodies.append([body, surface, body.get_surface_override_material(surface), coated])
		entry.frost_bodies = bodies
		entry.frost = _effect(entry, "EnemyFrost", templates, materials)
	entry.frost.visible = active
	entry.frost_active = active
	for item: Array in entry.frost_bodies: item[0].set_surface_override_material(item[1], item[3] if active else item[2])

static func update(entry: Dictionary) -> void:
	if not entry.has("status_skeleton"): return
	var skeleton: Skeleton3D = entry.status_skeleton
	var inverse: Transform3D = entry.root.global_transform.affine_inverse()
	for index in range(entry.parts.size()):
		var pose: Transform3D = inverse * entry.parts[index].global_transform
		skeleton.set_bone_pose(index, pose)

static func set_time(time: float) -> void:
	if _materials.has("burn"): _materials.burn.set_shader_parameter("burn_time", time)
	if _materials.has("poison"): _materials.poison.set_shader_parameter("burn_time", time)

static func clear() -> void:
	_surfaces.clear()
	_meshes.clear()
	_materials.clear()
	_skin = null

static func retain_stage(enemy_types: Array, tower_types: Array) -> void:
	var particles := "magic" in tower_types or "poison" in tower_types
	if not "shielded" in enemy_types or (not particles and not "frost" in tower_types):
		clear()
		return
	for mode: String in _materials.keys():
		var needed: bool = {"burn": "magic" in tower_types, "poison": "poison" in tower_types}.get(mode, "frost" in tower_types)
		if not needed: _materials.erase(mode)
	# Burn and poison share the particle mesh.
	for key: String in _meshes.keys():
		if (key.begins_with("burn:") and not particles) or (not key.begins_with("burn:") and not "frost" in tower_types): _meshes.erase(key)
