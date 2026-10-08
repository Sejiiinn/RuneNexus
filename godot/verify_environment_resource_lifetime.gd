extends SceneTree
## Heavy environment resources are selected by the next map, not by script loading.
const Battlefield = preload("res://environment/battlefield_environment.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Resources = preload("res://presentation/stage_resources.gd")
const Teleport = preload("res://environment/teleport_device.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _sources(battlefield: RefCounted) -> Dictionary:
	var sources := {}
	if battlefield._world_environment.sky != null:
		sources[battlefield.resource_snapshot().sky_path] = weakref(battlefield._world_environment.sky)
	for property in ["_terrain_library", "_landmark_library", "_dressing_library",
			"_chapter_two_terrain_library", "_chapter_two_props_library", "_chapter_two_paving_library",
			"_chapter_two_expansion_library", "_chapter_three_terrain_library", "_chapter_three_props_library",
			"_environment_geology_library", "_environment_props_library"]:
		var node := battlefield.get(property) as Node3D
		if is_instance_valid(node):
			sources[node.scene_file_path] = weakref(node)
	for variant: Dictionary in battlefield._dressing_variants:
		if is_instance_valid(variant.get("library")):
			sources[str(variant.resource)] = weakref(variant.library)
	return sources

func _first_mesh_reference(battlefield: RefCounted, property: String) -> WeakRef:
	var node := battlefield.get(property) as Node3D
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		return weakref(mesh.mesh)
	return null

func _verify() -> void:
	_check(not ResourceLoader.has_cached(Battlefield.TERRAIN_PATH), "Script preload loaded chapter-one terrain")
	_check(not ResourceLoader.has_cached(Battlefield.LANDMARKS_PATH), "Script preload loaded landmarks")
	_check(not ResourceLoader.has_cached(Battlefield.ReflectionSky) and not ResourceLoader.has_cached(Battlefield.ForgeReflectionSky), "Script preload loaded a reflection sky")
	_check(Resources.snapshot().count == 0, "Script preload populated heavy resource cache")
	var catalog := Catalog.new()
	_check(catalog.load_catalog(), "Compiled map catalog loads")
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var terrain := Node3D.new()
	scene_root.add_child(terrain)
	var sun := DirectionalLight3D.new()
	var fill := DirectionalLight3D.new()
	var battlefield := Battlefield.new(terrain, Environment.new(), sun, fill)
	battlefield.failed.connect(func(message: String) -> void: _check(false, message))
	battlefield.attach_lighting(scene_root)
	_check(battlefield._world_environment.sky == null, "Attaching lighting must not load a reflection sky")
	_check(battlefield.initialize(), "Environment metadata initializes")
	_check(battlefield.resource_snapshot().library_count == 0, "initialize() must not instantiate any heavy libraries")
	_check(Resources.snapshot().count == 0, "initialize() must not retain PackedScene resources")
	var previous := {}
	var previous_mesh: WeakRef
	var previous_mesh_path := ""
	# Start in another chapter, cover all authored maps, and test both teleport intersection/removal.
	for stage in [11, 12, 6, 7, 1, 2, 17, 20, 18, 21, 22, 23, 24, 25, 3, 4, 5, 8, 9, 10, 13, 14, 15, 16, 19, 1]:
		var map := catalog.stage_map(catalog.stage_index(stage))
		var paths := battlefield.resource_paths(map)
		_check(not paths.is_empty(), "Stage %d has a heavy-resource manifest" % stage)
		_check(battlefield.build_terrain(map), "Stage %d builds with its original assets" % stage)
		var current := _sources(battlefield)
		for path: String in previous:
			_check((previous[path].get_ref() != null) == (path in current), "Stage %d source lifetime: %s" % [stage, path])
			if path in current:
				_check(previous[path].get_ref() == current[path].get_ref(), "Stage %d preserves shared source: %s" % [stage, path])
			else:
				_check(not ResourceLoader.has_cached(path), "Stage %d releases outgoing PackedScene: %s" % [stage, path])
		if previous_mesh != null and previous_mesh_path not in current:
			_check(previous_mesh.get_ref() == null, "Stage %d releases outgoing mesh/material ownership" % stage)
		for path: String in current:
			_check(path in paths, "Stage %d retained an unused environment library: %s" % [stage, path])
		for path: String in paths:
			_check(path in current or path == Teleport.MODEL_PATH, "Stage %d missed an environment library: %s" % [stage, path])
		for path: String in Resources.snapshot().paths:
			_check(path in paths, "Stage %d retained an unused PackedScene: %s" % [stage, path])
		var has_teleport: bool = not map.get("teleportPairs", []).is_empty()
		_check(Teleport.resource_snapshot().model_loaded == has_teleport, "Stage %d teleport model lifetime" % stage)
		_check((Teleport.resource_snapshot().material_count > 0) == has_teleport, "Stage %d teleport material lifetime" % stage)
		# Lobby and restart clear only instances, preserving heavy sources and import work.
		var loads: Dictionary = battlefield.resource_snapshot().asset_load_counts
		var cache_loads: int = Resources.snapshot().loads
		battlefield.clear()
		_check(terrain.get_child_count() == 0, "Stage %d lobby clears rendered terrain" % stage)
		_check(battlefield.build_terrain(map), "Stage %d same-map restart builds" % stage)
		_check(battlefield.resource_snapshot().asset_load_counts == loads, "Stage %d restart does not reload source libraries" % stage)
		_check(Resources.snapshot().loads == cache_loads, "Stage %d restart does not reload PackedScenes" % stage)
		var restarted := _sources(battlefield)
		for path: String in current:
			_check(current[path].get_ref() == restarted[path].get_ref(), "Stage %d restart reuses source: %s" % [stage, path])
		previous = restarted
		if map.theme == "chapterThreeForge":
			previous_mesh = _first_mesh_reference(battlefield, "_chapter_three_terrain_library")
			previous_mesh_path = "res://assets/environment/chapter3_tiles.glb"
		elif map.theme == "chapterTwoRift":
			previous_mesh = _first_mesh_reference(battlefield, "_environment_geology_library")
			previous_mesh_path = "res://assets/environment/chapter2_stage%d_geology.glb" % stage
		else:
			previous_mesh = _first_mesh_reference(battlefield, "_terrain_library")
			previous_mesh_path = Battlefield.TERRAIN_PATH
		print("Environment resource scope verified: stage %d (%d source resources)" % [stage, current.size()])
	battlefield.dispose()
	for path: String in previous:
		_check(previous[path].get_ref() == null, "dispose releases source: " + path)
	_check(Resources.snapshot().count == 0, "dispose releases every owned PackedScene")
	_check(battlefield.resource_snapshot().library_count == 0, "dispose clears source references")
	_check(battlefield._portal_material == null and battlefield._foliage_material == null, "dispose clears material references")
	_check(battlefield._world_environment.sky == null, "dispose releases the active sky and its gradient texture")
	_check(not Teleport.resource_snapshot().model_loaded and Teleport.resource_snapshot().material_count == 0, "dispose clears teleport resources")
	scene_root.free()
	print("Environment resource lifetime: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
