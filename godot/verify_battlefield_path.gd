extends SceneTree
## Geometry, teleport gaps, cached mesh and authoritative clock without assets.
const Guide = preload("res://presentation/battlefield_path.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

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
		var skipped := {}
		for pair: Dictionary in map.get("teleportPairs",[]):
			for index in range(map.path.find(pair.entrance),map.path.find(pair.exit)): skipped[index] = true
		var expected_edges: int = map.path.size() - 1 - skipped.size()
		check(guide.mesh_instance.mesh != null and guide.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == expected_edges * 6, "content stage " + str(stage.get("id", "?")) + " actual walked edges")
	guide.clear()
	check(guide.mesh_instance.mesh == null and not guide.mesh_instance.visible and guide.material.get_shader_parameter("battle_time") == 0.0, "reset releases geometry and resets phase")
	guide.dispose()
	world.free()
	print("BATTLEFIELD_PATH checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
