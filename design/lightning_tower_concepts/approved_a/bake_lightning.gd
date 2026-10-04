extends SceneTree

# Editor-only bake: the runtime loads these resources and never builds tubes.
var input_path: String
var output_path: String
const DETAIL_SIDES := 4
const MAIN_SIDES := 6
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var anchors := PackedVector2Array()
var indices := PackedInt32Array()
var total_vertices := 0
var total_triangles := 0

func _initialize() -> void:
	var source_dir := ProjectSettings.globalize_path(get_script().resource_path).get_base_dir()
	input_path = source_dir.path_join("lightning_paths.json")
	output_path = source_dir.path_join("../../../godot/effects/lightning_attack_meshes").simplify_path() + "/"
	DirAccess.make_dir_recursive_absolute(output_path)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	for kind in ["charge", "beam", "feed"]:
		for i in range(data[kind].size()):
			bake(data[kind][i], "%s%02d" % [kind, i])
	bake(data.impact, "impact")
	print("LIGHTNING_BAKED vertices=", total_vertices, " triangles=", total_triangles)
	quit()

func bake(paths: Array, filename: String) -> void:
	vertices.clear()
	normals.clear()
	colors.clear()
	uvs.clear()
	anchors.clear()
	indices.clear()
	for path: Dictionary in paths:
		# White-violet hairline core and dim wider blue/violet plasma share one
		# surface. Additive blending is order independent; no per-layer nodes.
		var group: int = int(path.group)
		var outer := [Color(0.16, 0.10, 0.66, 0.25), Color(0.22, 0.06, 0.58, 0.21), Color(0.15, 0.045, 0.39, 0.16)][group] as Color
		var inner := [Color(0.75, 0.78, 1.0, 1.0), Color(0.48, 0.43, 1.0, 0.9), Color(0.47, 0.22, 0.96, 0.65)][group] as Color
		var outer_width := float(path.skin)
		var inner_width := float(path.core)
		if filename.begins_with("beam"):
			# Game camera: keep the authored branching path, strengthen only tube
			# cross-sections. The main spine is wider than secondary filaments.
			outer_width *= [3.4, 2.5, 1.7][group]
			inner_width *= [3.2, 2.3, 1.6][group]
			outer = [Color(.25, .28, 1.0, .78), Color(.28, .17, .94, .57), Color(.32, .12, .76, .36)][group] as Color
			inner = [Color(.88, .93, 1.0, 1.0), Color(.72, .78, 1.0, .96), Color(.60, .46, 1.0, .82)][group] as Color
		elif filename == "impact":
			outer_width *= 1.8
			inner_width *= 1.65
			outer = Color(.29, .23, .96, .58)
			inner = Color(.83, .86, 1.0, .96)
		# Retain six sides on the dominant charge/beam spine. Fine branches
		# keep every authored bend and taper, with four sides at game size.
		var sides := MAIN_SIDES if group == 0 and filename != "impact" else DETAIL_SIDES
		# Equal mean projected width to the original regular hexagonal tube.
		var width_compensation := 1.0 if sides == MAIN_SIDES else 1.0606601718
		tube(path, outer_width * width_compensation, outer, 0.0, sides)
		tube(path, inner_width * width_compensation, inner, 1.0, sides)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = anchors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = "Approved Lightning A " + filename
	var error := ResourceSaver.save(mesh, output_path + filename + ".res", ResourceSaver.FLAG_COMPRESS)
	assert(error == OK)
	total_vertices += vertices.size()
	total_triangles += indices.size() / 3
	print(filename, " ", vertices.size(), " vertices ", indices.size() / 3, " triangles")

func tube(path: Dictionary, width: float, ink: Color, layer: float, sides: int) -> void:
	var pts := PackedVector3Array()
	for point in path.points:
		pts.append(Vector3(point[0], point[1], point[2]))
	var first := vertices.size()
	for i in range(pts.size()):
		var previous: Vector3 = pts[maxi(0, i - 1)]
		var following: Vector3 = pts[mini(pts.size() - 1, i + 1)]
		var tangent := (following - previous).normalized()
		var side := Vector3.UP.cross(tangent)
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT.cross(tangent)
		side = side.normalized()
		var up := tangent.cross(side).normalized()
		for j in range(sides):
			var theta := float(j) * TAU / float(sides)
			var normal := side * cos(theta) + up * sin(theta)
			vertices.append(pts[i] + normal * width * float(path.radii[i]))
			normals.append(normal)
			colors.append(ink)
			uvs.append(Vector2(float(i) / float(pts.size() - 1), layer))
			anchors.append(Vector2(float(path.anchor[i]), 0.0))
		if i == 0:
			continue
		for j in range(sides):
			var a := first + (i - 1) * sides + j
			var b := first + i * sides + j
			var c := first + i * sides + (j + 1) % sides
			var d := first + (i - 1) * sides + (j + 1) % sides
			indices.append_array(PackedInt32Array([a, b, d, b, c, d]))
	for j in range(1, sides - 1):
		indices.append_array(PackedInt32Array([first, first + j, first + j + 1]))
		var last := first + (pts.size() - 1) * sides
		indices.append_array(PackedInt32Array([last, last + j + 1, last + j]))
