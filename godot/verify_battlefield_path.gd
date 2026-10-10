extends SceneTree
## Geometry, teleport gaps, cached mesh and authoritative clock without assets.
const Guide = preload("res://presentation/battlefield_path.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func tracks_cross(first: Array[Vector3],second: Array[Vector3]) -> bool:
	for a in range(first.size()-1):
		for b in range(second.size()-1):
			if Geometry2D.segment_intersects_segment(Vector2(first[a].x,first[a].z),Vector2(first[a+1].x,first[a+1].z),Vector2(second[b].x,second[b].z),Vector2(second[b+1].x,second[b+1].z)) != null: return true
	return false

func colored_centers(guide,blue: bool) -> Array[Vector3]:
	var arrays: Array = guide.mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var result: Array[Vector3] = []
	for index in range(0,vertices.size(),2):
		if (colors[index].b > colors[index].r) == blue: result.append((vertices[index]+vertices[index+1])*0.5)
	return result

func verify_corner_lanes() -> void:
	var primary := Vector2i(-4,-4)
	var secondary := Vector2i(-5,-5)
	for turn in [-1,1]:
		for rotation in range(4):
			var points: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(1,turn)]
			for index in points.size():
				for step in rotation: points[index] = Vector2i(-points[index].y,points[index].x)
			var origins := {}
			var directions := {}
			for index in range(points.size()-1):
				var key := Guide._edge_key(points[index],points[index+1])
				origins[key] = [primary,secondary]
				directions[key] = [points[index],points[index+1]]
			var first := Guide._track_points(points,primary,origins,directions,1,1)
			var second := Guide._track_points(points,secondary,origins,directions,1,1)
			check(not tracks_cross(first,second),"parallel corner never crosses rotation=%d turn=%d" % [rotation,turn])
			points.reverse()
			var opposed := Guide._track_points(points,secondary,origins,directions,1,1)
			check(not tracks_cross(first,opposed),"opposed traversal preserves spatial lane rotation=%d turn=%d" % [rotation,turn])
			opposed.reverse()
			check(opposed == second,"opposed path uses same geometric lane")

func verify_merge_lanes(guide) -> void:
	for side in [-1,1]:
		for rotation in range(4):
			for primary_straight in [false,true]:
				for bends_after_merge in [false,true]:
					var first: Array[Vector2i] = [Vector2i(side*2,0),Vector2i(side,0),Vector2i.ZERO,Vector2i(0,1),Vector2i(1,1) if bends_after_merge else Vector2i(0,2)]
					var second: Array[Vector2i] = [Vector2i(0,-2),Vector2i(0,-1),Vector2i.ZERO,Vector2i(0,1),first[-1]]
					var paths: Array = []
					for cells in [second,first] if primary_straight else [first,second]:
						var path: Array = []
						for cell: Vector2i in cells:
							for step in rotation: cell = Vector2i(-cell.y,cell.x)
							cell += Vector2i(2,2)
							path.append([cell.x,cell.y])
						paths.append({"path":path})
					var map := {"columns":5,"rows":5,"path":paths[0].path,"routes":paths}
					guide.build(map)
					var blue := colored_centers(guide,true)
					var orange := colored_centers(guide,false)
					var label := "side=%d rotation=%d straight=%s corner=%s" % [side,rotation,primary_straight,bends_after_merge]
					check(not tracks_cross(blue,orange),"merge approaches never cross " + label)
					map.routes.reverse()
					guide.build(map)
					check(colored_centers(guide,true) == blue and colored_centers(guide,false) == orange,"merge lane is independent of route declaration " + label)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var guide := Guide.new(world)
	var map := {"columns":4,"rows":3,"path":[[0,0],[1,0],[1,1],[2,1]]}
	var original: Dictionary = map.duplicate(true)
	guide.build(map)
	check(map == original, "presentation never changes route input")
	check(guide.mesh_instance.get_parent() == world and guide.mesh_instance.visible, "guide attached to battle world")
	var mesh: ArrayMesh = guide.mesh_instance.mesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	check(vertices.size() == 8 and arrays[Mesh.ARRAY_INDEX].size() == 18, "one joined ribbon with three edges")
	check(guide.material.get_shader_parameter("pulse_count") == 2.0, "pulse brightness period uses actual walked route length")
	for index in map.path.size():
		var midpoint := (vertices[index*2] + vertices[index*2+1]) * 0.5
		var cell: Array = map.path[index]
		check(midpoint.is_equal_approx(Vector3(float(cell[0]) + 0.5 - 2.0, Guide.SURFACE_HEIGHT, float(cell[1]) + 0.5 - 1.5)), "tile center " + str(index))
		check(is_equal_approx(uvs[index*2].x,float(index)), "pulse UV follows walked distance " + str(index))
	guide.update_time(2.0)
	guide.update_time(2.0)
	check(guide.material.get_shader_parameter("battle_time") == 2.0 and guide.mesh_instance.mesh == mesh, "paused frames preserve phase and cached geometry")
	guide.update_time(6.0)
	check(guide.material.get_shader_parameter("battle_time") == 6.0 and guide.mesh_instance.mesh == mesh, "4x combat advance changes clock without rebuilding")
	guide.update_time(0.25)
	check(guide.material.get_shader_parameter("battle_time") == 0.25, "restored combat clock can rewind")
	map = {"columns":8,"rows":1,"path":[[0,0],[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0]],"teleportPairs":[{"entrance":[1,0],"exit":[3,0]},{"entrance":[4,0],"exit":[6,0]}]}
	guide.build(map)
	arrays = guide.mesh_instance.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size() == 12 and arrays[Mesh.ARRAY_INDEX].size() == 18, "two teleports omit all original skipped edges")
	map = {"columns":4,"rows":3,"path":[[0,0],[1,0],[3,2],[2,2],[1,2]],"teleportPairs":[{"entrance":[1,0],"exit":[3,2]}]}
	guide.build(map)
	arrays = guide.mesh_instance.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size() == 10 and arrays[Mesh.ARRAY_INDEX].size() == 18, "disconnected teleport has separate ribbons, no cross-board line")
	map = {"columns":3,"rows":1,"path":[[0,0],[1,0],[2,0]],"teleportPairs":[{"entrance":[0,0],"exit":[1,0]}]}
	guide.build(map)
	check(guide.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 6, "adjacent teleport edge also omitted")
	guide.build({"columns":2,"rows":2,"tiles":[]})
	check(guide.mesh_instance.mesh == null and not guide.mesh_instance.visible, "legacy presentation map without path clears previous guide")
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/game_content.json"))
	for stage: Dictionary in content.stages:
		map = stage.map
		guide.build(map)
		var routes: Array = map.get("routes",[])
		if routes.is_empty(): routes = [{"path":map.path}]
		var edges := {}
		for route: Dictionary in routes:
			var path: Array = route.path
			var skipped := {}
			for pair: Dictionary in route.get("teleportPairs",map.get("teleportPairs",[])):
				var entrance := path.find(pair.entrance)
				var exit := path.find(pair.exit)
				if entrance >= 0 and exit > entrance:
					for index in range(entrance,exit): skipped[index] = true
			for index in range(path.size()-1):
				var from := Vector2i(int(path[index][0]),int(path[index][1]))
				var to := Vector2i(int(path[index+1][0]),int(path[index+1][1]))
				if not skipped.has(index) and absi(from.x-to.x)+absi(from.y-to.y) == 1:
					edges[[path[0],Guide._edge_key(from,to)]] = true
		var expected_edges := edges.size()
		check(guide.mesh_instance.mesh != null and guide.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == expected_edges * 6, "content stage " + str(stage.get("id", "?")) + " actual walked edges")
	map = {"columns":5,"rows":5,"path":[[0,2],[1,2],[2,2],[3,2]],"routes":[
		{"id":"north","path":[[0,2],[1,2],[1,1],[2,1],[3,1],[3,2]]},
		{"id":"south","path":[[0,2],[1,2],[1,3],[2,3],[3,3],[3,2]]}]}
	guide.build(map)
	check(guide.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 9*6,"both branches rendered, shared approach once")
	for tint: Color in guide.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		check(tint.b > tint.r,"same-origin branches stay blue")
	# Separate portals keep their own colors and parallel common segments.
	map.routes = [
		{"id":"west","path":[[0,2],[1,2],[2,2],[2,3],[2,4]]},
		{"id":"north","path":[[2,0],[2,1],[2,2],[2,3],[2,4]]}]
	map.path = map.routes[0].path
	guide.build(map)
	arrays = guide.mesh_instance.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_INDEX].size() == 8*6,"different portals retain both shared tracks")
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	check(colors[0].b > colors[0].r and colors[-1].r > colors[-1].b,"origin blue and orange colors")
	vertices = arrays[Mesh.ARRAY_VERTEX]
	var blue_center := (vertices[6]+vertices[7])*0.5
	var orange_center := (vertices[16]+vertices[17])*0.5
	check(is_equal_approx(blue_center.distance_to(orange_center),Guide.TRACK_SPACING),"shared lanes retain visible separation")
	check(blue_center.x < orange_center.x,"west approach joins left lane without crossing north approach")
	var blue_end := (vertices[8]+vertices[9])*0.5
	var orange_end := (vertices[18]+vertices[19])*0.5
	check(is_equal_approx(blue_end.distance_to(orange_end),Guide.TRACK_SPACING),"parallel separation preserved through common destination")
	var blue_before := colored_centers(guide,true)
	var orange_before := colored_centers(guide,false)
	map.routes.reverse()
	guide.build(map)
	check(colored_centers(guide,true) == blue_before and colored_centers(guide,false) == orange_before,"route declaration order cannot swap origin color or lane")
	# Explicit portal identity follows the shared default route resolver.
	map.routes.reverse() # Restore the validated default path as first route.
	map.spawnPortals = [{"id":"A","label":"West","cell":[0,2]},{"id":"B","label":"North","cell":[2,0]}]
	for route: Dictionary in map.routes: route.spawnPortalId = "A" if route.id == "west" else "B"
	guide.build(map)
	check(colored_centers(guide,true) == blue_before and colored_centers(guide,false) == orange_before,"explicit portal identity preserves original guide geometry and colors")
	map.spawnPortals.reverse()
	guide.build(map)
	check(colored_centers(guide,true) == blue_before and colored_centers(guide,false) == orange_before,"portal declaration order cannot change default route colors")
	verify_corner_lanes()
	verify_merge_lanes(guide)
	map = {"columns":7,"rows":5,"path":[[0,2],[1,2],[2,2],[3,2],[4,2],[4,3],[5,3],[6,3]],"routes":[
		{"path":[[0,2],[1,2],[2,2],[3,2],[4,2],[4,3],[5,3],[6,3]]},
		{"path":[[0,2],[0,1],[1,1],[2,1],[3,1],[4,1],[4,2],[3,2],[3,3],[3,4],[4,4],[5,4],[5,3],[6,3]]}]}
	guide.build(map)
	check(guide.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 18*6,"same-origin reversed shared edge is drawn only once")
	map.routes.reverse()
	guide.build(map)
	check(guide.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 18*6,"reversed declaration still deduplicates same-origin edges")
	guide.clear()
	check(guide.mesh_instance.mesh == null and not guide.mesh_instance.visible and guide.material.get_shader_parameter("battle_time") == 0.0, "reset releases geometry and resets phase")
	guide.dispose()
	world.free()
	print("BATTLEFIELD_PATH checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
