extends RefCounted
## Cached tile-space guide; only its combat-clock uniform changes each frame.
const Catalog = preload("res://content/content_catalog.gd")
const GUIDE_SHADER = preload("res://presentation/battlefield_path.gdshader")
const SURFACE_HEIGHT := 0.038 # Above the chapter-three 0.030 raised treads.
const HALF_WIDTH := 0.10
const TRACK_SPACING := 0.16
const PRIMARY_COLOR := Color(0.556863, 0.901961, 1.0)
const SECONDARY_COLOR := Color(1.0, 0.72, 0.46)

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
	var columns := int(map.get("columns", 0))
	var rows := int(map.get("rows", 0))
	if columns <= 0 or rows <= 0: return
	var routes: Array = map.get("routes", [])
	if routes.is_empty(): routes = [{"path": map.get("path", [])}]
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var distance := 0.0
	var prepared: Array = []
	var origins: Array = []
	var default_path: Array = map.get("path",[])
	if map.has("spawnPortals"):
		origins.append(Catalog.map_route_portal(map).id)
	elif not default_path.is_empty(): origins.append(Vector2i(int(default_path[0][0]),int(default_path[0][1])))
	var edge_origins := {}
	for route: Dictionary in routes:
		var cells: Array[Vector2i] = []
		for raw in route.get("path", []):
			if not raw is Array or raw.size() != 2: return
			var cell := Vector2i(int(raw[0]), int(raw[1]))
			if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows: return
			cells.append(cell)
		if cells.size() < 2: continue
		var origin: Variant = Catalog.map_route_portal(map,str(route.get("id",""))).id if map.has("spawnPortals") else cells[0]
		if origin not in origins: origins.append(origin)
		# IN/OUT skips have no walking guide, including adjacent portal pairs.
		var skipped := {}
		for pair: Dictionary in route.get("teleportPairs", map.get("teleportPairs", [])):
			var entrance := cells.find(Vector2i(int(pair.entrance[0]), int(pair.entrance[1])))
			var exit := cells.find(Vector2i(int(pair.exit[0]), int(pair.exit[1])))
			if entrance >= 0 and exit > entrance:
				for edge in range(entrance, exit): skipped[edge] = true
		for index in range(cells.size()-1):
			var delta := cells[index+1]-cells[index]
			if absi(delta.x)+absi(delta.y) != 1: skipped[index] = true
			if skipped.has(index): continue
			var key := _edge_key(cells[index],cells[index+1])
			if not edge_origins.has(key): edge_origins[key] = []
			if origin not in edge_origins[key]: edge_origins[key].append(origin)
		prepared.append({"cells":cells,"skipped":skipped,"origin":origin})
	for edge in edge_origins:
		edge_origins[edge].sort_custom(func(a,b): return origins.find(a) < origins.find(b))
	# Lane handedness follows the primary origin's travel through the whole
	# shared run. A coordinate-sorted edge direction would flip it at corners.
	var edge_directions := {}
	for route: Dictionary in prepared:
		var cells: Array[Vector2i] = route.cells
		for index in range(cells.size()-1):
			if route.skipped.has(index): continue
			var key := _edge_key(cells[index],cells[index+1])
			if route.origin == edge_origins[key][0] and not edge_directions.has(key):
				edge_directions[key] = [cells[index],cells[index+1]]
	# Order lanes by the side from which each origin approaches the shared run.
	# Keep that order through its corners; a fixed positive primary lane would
	# cross an origin entering from the opposite side of the merge.
	for route: Dictionary in prepared:
		var cells: Array[Vector2i] = route.cells
		var previous_origins: Array = []
		var lane_order: Array = []
		for index in range(cells.size()-1):
			if route.skipped.has(index):
				previous_origins = []
				continue
			var key := _edge_key(cells[index],cells[index+1])
			var shared: Array = edge_origins[key]
			if shared.size() < 2 or route.origin != shared[0]:
				previous_origins = []
				continue
			if shared != previous_origins:
				lane_order = _merge_lane_order(cells[index],cells[index+1],shared,prepared)
			if edge_directions[key].size() == 2: edge_directions[key].append(lane_order)
			previous_origins = shared
	var rendered_edges := {}
	for route: Dictionary in prepared:
		var cells: Array[Vector2i] = route.cells
		var origin: Variant = route.origin
		var tint := PRIMARY_COLOR if origins.find(origin) == 0 else SECONDARY_COLOR
		var run: Array[Vector2i] = []
		for index in cells.size():
			var cell := cells[index]
			run.append(cell)
			var last := index == cells.size()-1
			var split: bool = last or route.skipped.has(index)
			if not split:
				# A single portal's shared approach is one line. Different portal
				# origins retain separate, parallel lines over their common tiles.
				var edge := [origin,_edge_key(cell,cells[index+1])]
				split = rendered_edges.has(edge)
				if not split: rendered_edges[edge] = true
			if split:
				var points := _track_points(run,origin,edge_origins,edge_directions,columns,rows)
				distance = _append_run(points,distance,vertices,uvs,indices,colors,tint)
				run.clear()
	if indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	material.set_shader_parameter("pulse_count", maxf(1.0, floorf(distance / 1.32)))
	if not mesh_instance.is_inside_tree() and mesh_instance.get_parent() == null:
		_world.add_child(mesh_instance)
	mesh_instance.show()
	update_time(0.0)

static func _edge_key(from: Vector2i,to: Vector2i) -> Array:
	return [from,to] if from.x < to.x or (from.x == to.x and from.y < to.y) else [to,from]

static func _merge_lane_order(from: Vector2i,to: Vector2i,origins: Array,routes: Array) -> Array:
	var direction := Vector2(to-from).normalized()
	var normal := Vector2(-direction.y,direction.x)
	var sides := {}
	for origin in origins:
		sides[origin] = 0.0
		for route: Dictionary in routes:
			if route.origin != origin: continue
			var cells: Array[Vector2i] = route.cells
			for index in range(1,cells.size()-1):
				if cells[index] == from and cells[index+1] == to and not route.skipped.has(index-1):
					sides[origin] = Vector2(cells[index-1]-from).dot(normal)
					break
	var ordered := origins.duplicate()
	ordered.sort_custom(func(a,b): return origins.find(a) < origins.find(b) if is_equal_approx(sides[a],sides[b]) else sides[a] > sides[b])
	return ordered

static func _lane(from: Vector2i,to: Vector2i,origin: Variant,edge_origins: Dictionary,edge_directions: Dictionary) -> float:
	var key := _edge_key(from,to)
	var shared: Array = edge_origins.get(key,[])
	if edge_directions.has(key) and edge_directions[key].size() > 2: shared = edge_directions[key][2]
	if shared.size() < 2: return 0.0
	# Keep lane identity through turns, even if another route traverses an edge
	# in reverse. Merge geometry decides which origin occupies each side.
	var offset := (float(shared.size()-1)*0.5-float(shared.find(origin)))*TRACK_SPACING
	return offset if edge_directions[key][0] == from else -offset

static func _track_points(cells: Array[Vector2i],origin: Variant,edge_origins: Dictionary,edge_directions: Dictionary,columns: int,rows: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if cells.size() < 2: return points
	for index in cells.size():
		var cell := cells[index]
		var incoming := Vector2(cells[index]-cells[index-1]).normalized() if index > 0 else Vector2(cells[1]-cell).normalized()
		var outgoing := Vector2(cells[index+1]-cell).normalized() if index < cells.size()-1 else incoming
		var before := Vector2(-incoming.y,incoming.x)
		var after := Vector2(-outgoing.y,outgoing.x)
		var incoming_lane := _lane(cells[index-1],cell,origin,edge_origins,edge_directions) if index > 0 else _lane(cell,cells[1],origin,edge_origins,edge_directions)
		var outgoing_lane := _lane(cell,cells[index+1],origin,edge_origins,edge_directions) if index < cells.size()-1 else incoming_lane
		# Intersect the two offset edge lines at a corner. On straight approach
		# tiles blend the offsets, so entry into parallel lanes has no jump.
		var shift := before*incoming_lane + after*outgoing_lane
		if before.dot(after) > 0.5: shift *= 0.5
		points.append(Vector3(cell.x+0.5-columns/2.0+shift.x,SURFACE_HEIGHT,cell.y+0.5-rows/2.0+shift.y))
	return points

func _append_run(points: Array[Vector3], start_distance: float, vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, colors: PackedColorArray, tint: Color) -> float:
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
		colors.append(tint)
		colors.append(tint)
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
