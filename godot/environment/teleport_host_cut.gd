extends RefCounted
## Cut only the portal opening in copied host geometry. Side/bottom materials,
## UVs and untouched map resources remain owned by the chapter terrain.

const OPENING_HALF := 0.439
const FLOOR_Y := -0.115


static func apply(terrain: Node3D, centers: Array[Vector3]) -> Dictionary:
	var report := {"meshes_changed": 0, "triangles_cut": 0, "multimesh_slots": 0}
	if centers.is_empty(): return report
	var inverse := terrain.global_transform.affine_inverse()
	var meshes := terrain.find_children("*", "MeshInstance3D", true, false)
	for instance: MeshInstance3D in meshes:
		var transform := inverse * instance.global_transform
		var relevant := _relevant_centers(transform * instance.get_aabb(), centers)
		if relevant.is_empty(): continue
		var result := _cut_mesh(instance.mesh, transform, relevant)
		if int(result.get("cut", 0)) == 0: continue
		var overrides: Array = []
		for old_surface: int in result.surfaces:
			overrides.append(instance.get_surface_override_material(old_surface))
		instance.mesh = result.mesh
		for i in range(overrides.size()): instance.set_surface_override_material(i, overrides[i])
		report.meshes_changed += 1
		report.triangles_cut += int(result.cut)
	# Chapter 2 paving shares MultiMesh resources. Extract only endpoint slots;
	# all other instances and their transforms retain the shared original mesh.
	for batch: MultiMeshInstance3D in terrain.find_children("*", "MultiMeshInstance3D", true, false):
		var original := batch.multimesh
		if original == null or original.mesh == null: continue
		var remaining: Array[int] = []
		var changed := false
		for slot in range(original.instance_count):
			var local := original.get_instance_transform(slot)
			var transform := inverse * batch.global_transform * local
			var relevant := _relevant_centers(transform * original.mesh.get_aabb(), centers)
			var result := {} if relevant.is_empty() else _cut_mesh(original.mesh, transform, relevant)
			if int(result.get("cut", 0)) == 0:
				remaining.append(slot)
				continue
			var tile := MeshInstance3D.new()
			tile.name = "TeleportHostOpening"
			tile.mesh = result.mesh
			tile.transform = transform
			tile.layers = batch.layers
			tile.cast_shadow = batch.cast_shadow
			tile.material_override = batch.material_override
			terrain.add_child(tile)
			report.meshes_changed += 1
			report.triangles_cut += int(result.cut)
			report.multimesh_slots += 1
			changed = true
		if not changed: continue
		var replacement := MultiMesh.new()
		replacement.transform_format = original.transform_format
		replacement.use_colors = original.use_colors
		replacement.use_custom_data = original.use_custom_data
		replacement.mesh = original.mesh
		replacement.instance_count = remaining.size()
		for i in range(remaining.size()):
			var old := remaining[i]
			replacement.set_instance_transform(i, original.get_instance_transform(old))
			if original.use_colors: replacement.set_instance_color(i, original.get_instance_color(old))
			if original.use_custom_data: replacement.set_instance_custom_data(i, original.get_instance_custom_data(old))
		batch.multimesh = replacement
	return report


static func _relevant_centers(bounds: AABB, centers: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if bounds.end.y < FLOOR_Y: return result
	for center in centers:
		if bounds.end.x > center.x - OPENING_HALF and bounds.position.x < center.x + OPENING_HALF \
		and bounds.end.z > center.z - OPENING_HALF and bounds.position.z < center.z + OPENING_HALF:
			result.append(center)
	return result


static func _cut_mesh(source: Mesh, transform: Transform3D, centers: Array[Vector3]) -> Dictionary:
	var target := ArrayMesh.new()
	var surfaces: Array[int] = []
	var cut := 0
	for surface in range(source.get_surface_count()):
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return {"cut": 0}
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices == null or source_indices.is_empty():
			source_indices = PackedInt32Array()
			for i in range(vertices.size()): source_indices.append(i)
		var indices := PackedInt32Array()
		for offset in range(0, source_indices.size(), 3):
			var triangle: Array = []
			for corner in range(3):
				var index: int = source_indices[offset + corner]
				triangle.append({"index": index, "position": transform * vertices[index]})
			var polygons: Array = [triangle]
			var touched := false
			for center in centers:
				var next: Array = []
				for polygon: Array in polygons:
					var remainder := polygon
					var outside: Array = []
					for plane in [Plane(Vector3.RIGHT, center.x - OPENING_HALF), Plane(Vector3.LEFT, -center.x - OPENING_HALF),
						Plane(Vector3.BACK, center.z - OPENING_HALF), Plane(Vector3.FORWARD, -center.z - OPENING_HALF), Plane(Vector3.UP, FLOOR_Y)]:
						if remainder.is_empty(): break
						var split := _split(remainder, plane, arrays)
						if split.outside.size() >= 3: outside.append(split.outside)
						remainder = split.inside
					if remainder.size() >= 3:
						touched = true
						next.append_array(outside)
					else:
						next.append(polygon)
				polygons = next
			if touched: cut += 1
			for polygon: Array in polygons:
				for i in range(1, polygon.size() - 1):
					for vertex in [polygon[0], polygon[i], polygon[i + 1]]:
						indices.append(_append_vertex(vertex, arrays))
		arrays[Mesh.ARRAY_INDEX] = indices
		if not indices.is_empty():
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			target.surface_set_material(target.get_surface_count() - 1, source.surface_get_material(surface))
			surfaces.append(surface)
	return {"mesh": target, "surfaces": surfaces, "cut": cut}


static func _split(polygon: Array, plane: Plane, arrays: Array) -> Dictionary:
	var inside: Array = []
	var outside: Array = []
	for i in range(polygon.size()):
		var a: Dictionary = polygon[i]
		var b: Dictionary = polygon[(i + 1) % polygon.size()]
		var da := plane.distance_to(a.position)
		var db := plane.distance_to(b.position)
		if da >= -0.0000001: inside.append(a)
		if da < -0.0000001: outside.append(a)
		if (da >= -0.0000001) != (db >= -0.0000001):
			var t := da / (da - db)
			var vertex := _interpolate(a, b, t, arrays)
			inside.append(vertex)
			outside.append(vertex)
	return {"inside": inside, "outside": outside}


static func _attributes(vertex: Dictionary, arrays: Array) -> Dictionary:
	if vertex.has("attributes"): return vertex.attributes
	var result := {}
	var index := int(vertex.index)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[slot] != null and not arrays[slot].is_empty(): result[slot] = arrays[slot][index]
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	if tangents != null and not tangents.is_empty():
		result[Mesh.ARRAY_TANGENT] = Vector4(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2], tangents[index * 4 + 3])
	return result


static func _interpolate(a: Dictionary, b: Dictionary, t: float, arrays: Array) -> Dictionary:
	var aa := _attributes(a, arrays)
	var bb := _attributes(b, arrays)
	var attributes := {}
	for slot in aa: attributes[slot] = aa[slot].lerp(bb[slot], t)
	if attributes.has(Mesh.ARRAY_NORMAL): attributes[Mesh.ARRAY_NORMAL] = attributes[Mesh.ARRAY_NORMAL].normalized()
	return {"index": -1, "position": a.position.lerp(b.position, t), "attributes": attributes}


static func _append_vertex(vertex: Dictionary, arrays: Array) -> int:
	if int(vertex.index) >= 0: return int(vertex.index)
	var index: int = arrays[Mesh.ARRAY_VERTEX].size()
	for slot in vertex.attributes:
		var value = vertex.attributes[slot]
		if slot == Mesh.ARRAY_TANGENT:
			for component in [value.x, value.y, value.z, value.w]: arrays[slot].append(component)
		else:
			arrays[slot].append(value)
	return index
