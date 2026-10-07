extends RefCounted
## Cached tile-space guide; only its combat-clock uniform changes each frame.
const GUIDE_SHADER = preload("res://presentation/battlefield_path.gdshader")
const SURFACE_HEIGHT := 0.038 # Above the chapter-three 0.030 raised treads.
const HALF_WIDTH := 0.10

var mesh_instance := MeshInstance3D.new()
var material := ShaderMaterial.new()
var _world: Node3D
var _battle_time := -1.0

func _init(world: Node3D) -> void:
	_world = world
	mesh_instance.name = "MovementPathGuide"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shader = GUIDE_SHADER
	mesh_instance.material_override = material

func build(map: Dictionary) -> void:
	clear()
	var path: Array = map.get("path", [])
	var columns := int(map.get("columns", 0))
	var rows := int(map.get("rows", 0))
	if path.size() < 2 or columns <= 0 or rows <= 0:
		return
	var cells: Array[Vector2i] = []
	for raw in path:
		if not raw is Array or raw.size() != 2:
			return
		var cell := Vector2i(int(raw[0]), int(raw[1]))
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
			return
		cells.append(cell)
	# Skip the original route between IN and OUT, including adjacent portals.
	# Never draw a diagonal across a disconnected teleport jump.
	var skipped := {}
	for pair: Dictionary in map.get("teleportPairs", []):
		var entrance := cells.find(Vector2i(int(pair.entrance[0]), int(pair.entrance[1])))
		var exit := cells.find(Vector2i(int(pair.exit[0]), int(pair.exit[1])))
		if entrance >= 0 and exit > entrance:
			for edge in range(entrance, exit): skipped[edge] = true
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var run: Array[Vector3] = []
	var distance := 0.0
	for index in cells.size():
		var cell := cells[index]
		run.append(Vector3(cell.x + 0.5 - columns / 2.0, SURFACE_HEIGHT, cell.y + 0.5 - rows / 2.0))
		var last := index == cells.size() - 1
		var disconnected := not last and absi(cell.x - cells[index + 1].x) + absi(cell.y - cells[index + 1].y) != 1
		if last or skipped.has(index) or disconnected:
			distance = _append_run(run, distance, vertices, uvs, indices)
			run.clear()
	if indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	material.set_shader_parameter("pulse_count", maxf(1.0, floorf(distance / 1.32)))
	if not mesh_instance.is_inside_tree() and mesh_instance.get_parent() == null:
		_world.add_child(mesh_instance)
	mesh_instance.show()
	update_time(0.0)

func _append_run(points: Array[Vector3], start_distance: float, vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> float:
	if points.size() < 2: return start_distance
	var base := vertices.size()
	var distance := start_distance
	for index in points.size():
		var incoming := (points[index] - points[index - 1]).normalized() if index > 0 else (points[1] - points[0]).normalized()
		var outgoing := (points[index + 1] - points[index]).normalized() if index < points.size() - 1 else incoming
		var before := Vector3(-incoming.z, 0.0, incoming.x)
		var after := Vector3(-outgoing.z, 0.0, outgoing.x)
		var across := (before + after).normalized()
		if across.is_zero_approx(): across = after
		var offset := across * HALF_WIDTH / maxf(0.5, across.dot(after))
		if index > 0: distance += points[index].distance_to(points[index - 1])
		vertices.append(points[index] - offset)
		vertices.append(points[index] + offset)
		uvs.append(Vector2(distance, -HALF_WIDTH))
		uvs.append(Vector2(distance, HALF_WIDTH))
		if index > 0:
			var a := base + (index - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	return distance

func update_time(time: float) -> void:
	if time == _battle_time: return
	_battle_time = time
	material.set_shader_parameter("battle_time", time)

func clear() -> void:
	mesh_instance.hide()
	mesh_instance.mesh = null
	_battle_time = -1.0
	material.set_shader_parameter("battle_time", 0.0)

func dispose() -> void:
	if is_instance_valid(mesh_instance): mesh_instance.free()
