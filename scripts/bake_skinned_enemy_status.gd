extends SceneTree
## Offline only: bake the common status shapes onto each authored skin.
## Copy into an isolated prepared project, then run --headless --script
## res://bake_skinned_enemy_status.gd -- boss (or normal/fast/tank). Copy the three
## assets/enemies/<kind>_status_*.res outputs back to the source asset folder.
var enemy_kind := "normal"

const Frost = preload("res://effects/enemy_frost.gd")
const Burn = preload("res://effects/enemy_burn.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): enemy_kind = args[0]
	assert(enemy_kind in ["normal", "fast", "tank", "boss"])
	var model = load("res://assets/enemies/" + enemy_kind + ".glb").instantiate()
	root.add_child(model)
	var body: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var skeleton := body.get_node(body.skeleton) as Skeleton3D
	assert(body.skin != null and skeleton != null, "Status bake requires an authored skin")
	assert(body.mesh.get_surface_count() == 1, "Status bake expects the atlas body as one surface")
	print("SKINNED_STATUS_COORDINATE_SCALE ", enemy_kind, " ", body.global_transform.basis.get_scale())
	Frost._ensure_shared()
	Burn._ensure_shared()
	var output := {}
	for label in ["EnemyFrost", "EnemyBurn"]:
		var groups := _build_groups(model, body, skeleton, _source_templates(label), enemy_kind == "boss")
		_bake_meshes(body, skeleton, groups, label)
		output[label] = []
		for group: Dictionary in groups:
			var instances := []
			for item: Array in group.instances:
				var pose: Transform3D = item[0]
				var custom: Color = item[1]
				instances.append([pose.basis.x.x,pose.basis.x.y,pose.basis.x.z,pose.basis.y.x,pose.basis.y.y,pose.basis.y.z,pose.basis.z.x,pose.basis.z.y,pose.basis.z.z,pose.origin.x,pose.origin.y,pose.origin.z,custom.r,custom.g,custom.b,custom.a])
			output[label].append({"bone":group.bone,"template":group.template,"instances":instances})
	var file := FileAccess.open("res://" + enemy_kind + "-status-attachments.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	file.close()
	print("SKINNED_STATUS_BAKED ", enemy_kind, " ", output.EnemyFrost.size(), " frost bone groups / ",output.EnemyBurn.size()," burn bone groups")
	model.free()
	quit()


static func _colored_core(color: Color) -> bool:
	return (color.g > color.r * 1.25 and color.b > color.r * 1.25) or (color.r > color.g * 1.25 and color.b > color.g * 1.25)


static func _build_groups(root: Node3D, body: MeshInstance3D, skeleton: Skeleton3D, templates: Array, preserve_red_core := false) -> Array:
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var material := body.get_active_material(0) as StandardMaterial3D
	var atlas: Image = material.albedo_texture.get_image()
	# Blue body stone must receive effects; only the authored emitting rune is exempt.
	var emission: Image = material.emission_texture.get_image() if material.emission_enabled and material.emission_texture != null else null
	if emission != null and emission.is_compressed(): emission.decompress()
	if atlas.is_compressed(): atlas.decompress()
	var mesh_to_root := root.global_transform.affine_inverse() * body.global_transform
	var root_to_skeleton := skeleton.global_transform.affine_inverse() * root.global_transform
	var triangles: Array = []
	var area := 0.0
	for offset in range(0, indices.size(), 3):
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		var uv := (uvs[a] + uvs[b] + uvs[c]) / 3.0
		var color := atlas.get_pixel(clampi(int(uv.x * atlas.get_width()), 0, atlas.get_width()-1), clampi(int(uv.y * atlas.get_height()), 0, atlas.get_height()-1))
		# Boss chest pigment is authored separately from its emitting eyes/rune cuts.
		if preserve_red_core and color.r > color.g * 1.5 and color.r > color.b * 1.5: continue
		if emission != null:
			var glow := emission.get_pixel(clampi(int(uv.x * emission.get_width()), 0, emission.get_width()-1), clampi(int(uv.y * emission.get_height()), 0, emission.get_height()-1))
			if maxf(glow.r, maxf(glow.g, glow.b)) > 0.01: continue
		elif _colored_core(color): continue
		var size := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length() * 0.5
		if size < 0.000001: continue
		area += size
		triangles.append([a, b, c, area])
	var random := RandomNumberGenerator.new()
	random.seed = 260927
	var grouped := {}
	for template_index in range(templates.size()):
		var template: Dictionary = templates[template_index]
		var count: int = template.instances.size()
		for index in range(count):
			var sample := random.randf() * area
			var low := 0
			var high := triangles.size() - 1
			while low < high:
				var mid := (low + high) / 2
				if float(triangles[mid][3]) < sample: low = mid + 1
				else: high = mid
			var triangle: Array = triangles[low]
			var a: int = triangle[0]
			var b: int = triangle[1]
			var c: int = triangle[2]
			var u := sqrt(random.randf())
			var v := random.randf()
			var point := vertices[a] * (1.0-u) + vertices[b] * (u*(1.0-v)) + vertices[c] * (u*v)
			var normal := (mesh_to_root.basis * (normals[a] + normals[b] + normals[c])).normalized()
			var dominant := 0
			for influence in range(1,4):
				if weights[a*4+influence] > weights[a*4+dominant]: dominant = influence
			var bind := bones[a*4+dominant]
			var bone := body.skin.get_bind_bone(bind)
			if bone < 0: bone = skeleton.find_bone(body.skin.get_bind_name(bind))
			assert(bone >= 0, "Authored status skin binding missing")
			var source: Transform3D = template.instances[index][0]
			var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis.from_scale(source.basis.get_scale()) if template_index == 0 and templates.size() > 1 else source.basis
			# Godot folds glTF normalization into imported vertices and inverse binds.
			# Sample the actual rest-skinned surface, not mesh node scale alone.
			var rest_to_root := root.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(bone) * body.skin.get_bind_pose(bind)
			normal = (rest_to_root.basis * (normals[a] + normals[b] + normals[c])).normalized()
			if template_index == 0 and templates.size() > 1:
				basis = Basis(Quaternion(Vector3.UP, normal)) * Basis.from_scale(source.basis.get_scale())
			var pose := Transform3D(basis, rest_to_root * point + normal * 0.003)
			pose = skeleton.get_bone_global_rest(bone).affine_inverse() * root_to_skeleton * pose
			var group_key := Vector2i(template_index,bone)
			if not grouped.has(group_key): grouped[group_key] = []
			grouped[group_key].append([pose, template.instances[index][1]])
	var result: Array = []
	for key: Vector2i in grouped:
		result.append({"bone":key.y,"template":key.x,"mesh":templates[key.x].mesh,"instances":grouped[key]})
	return result


func _bake_meshes(body: MeshInstance3D, skeleton: Skeleton3D, groups: Array, label: String) -> void:
	for template_index in range(2 if label == "EnemyFrost" else 1):
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var custom := PackedFloat32Array()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		var indices := PackedInt32Array()
		for group: Dictionary in groups:
			if group.template != template_index: continue
			var bind := -1
			for index in range(body.skin.get_bind_count()):
				if body.skin.get_bind_bone(index) == int(group.bone) or body.skin.get_bind_name(index) == skeleton.get_bone_name(group.bone):
					bind = index
					break
			assert(bind >= 0)
			var template: Mesh = group.mesh
			var source := template.surface_get_arrays(0)
			var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
			var source_uv: PackedVector2Array = source[Mesh.ARRAY_TEX_UV] if source[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			if source_uv.is_empty(): source_uv.resize(source_vertices.size())
			var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
			for item: Array in group.instances:
				var pose: Transform3D = body.skin.get_bind_pose(bind).affine_inverse() * item[0]
				var values: Color = item[1]
				var base := vertices.size()
				for vertex_index in range(source_vertices.size()):
					var vertex := source_vertices[vertex_index]
					var normal := source_normals[vertex_index]
					if label == "EnemyFrost" and template_index == 0:
						# Bake the existing crystal shader's ring twist before transforming.
						if source_uv[vertex_index].y < 0.5:
							var x := vertex.x
							vertex.x = values.g * x + values.b * vertex.z / 0.68
							vertex.z = -0.68 * values.b * x + values.g * vertex.z
						var nx := normal.x
						normal.x = values.g * nx + 0.68 * values.b * normal.z
						normal.z = -values.b * nx / 0.68 + values.g * normal.z
					vertices.append(pose.origin if label == "EnemyBurn" else pose * vertex)
					normals.append((pose.basis.inverse().transposed() * normal).normalized())
					uv.append(source_uv[vertex_index])
					uv2.append(Vector2(vertex.x,vertex.y) if label == "EnemyBurn" else Vector2.ZERO)
					custom.append_array(PackedFloat32Array([values.r,values.g,values.b,values.a]))
					bones.append_array(PackedInt32Array([bind,0,0,0]))
					weights.append_array(PackedFloat32Array([1,0,0,0]))
				for vertex_index in source_indices: indices.append(base + vertex_index)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		assert(mesh.get_surface_count() == 1)
		mesh.custom_aabb = AABB(Vector3(-8,-8,-8),Vector3(16,16,16))
		var kind := "burn" if label == "EnemyBurn" else ("frost_shards" if template_index == 0 else "frost_grains")
		assert(ResourceSaver.save(mesh,"res://assets/enemies/" + enemy_kind + "_status_" + kind + ".res") == OK)
		print("SKINNED_STATUS_MESH ",kind," vertices=",vertices.size()," triangles=",indices.size()/3," surfaces=",mesh.get_surface_count())


func _source_templates(label: String) -> Array:
	# Read authoritative CPU definitions: dummy RenderingServer MultiMesh getters
	# return identity/zero, so no renderer readback is allowed in this offline bake.
	if label == "EnemyFrost":
		var result := [{"mesh":Frost._shard_mesh,"instances":[]},{"mesh":Frost._grain_mesh,"instances":[]}]
		for item: Dictionary in Frost._attachments[enemy_kind]:
			var grain: bool = item.mesh == "FrostGrain"
			var values := Color()
			if not grain:
				var variant := int(item.variant)
				var twist := float(Frost._variants[variant].twist)
				values = Color(variant,cos(twist),sin(twist),0.0)
			result[1 if grain else 0].instances.append([Frost._transform(item.transform),values])
		return result
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Burn.DATA_PATH)).enemies
	var first_row := 0
	for kind: String in definitions:
		if kind == enemy_kind: break
		first_row += definitions[kind].particles.size()
	var instances: Array = []
	for i in range(definitions[enemy_kind].particles.size()):
		var anchor: Array = definitions[enemy_kind].particles[i].anchor
		instances.append([Transform3D(Basis.IDENTITY,Vector3(anchor[0],anchor[1],anchor[2])),Color(first_row+i,0,0,0)])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return [{"mesh":quad,"instances":instances}]
