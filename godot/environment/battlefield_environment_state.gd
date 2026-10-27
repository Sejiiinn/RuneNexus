extends RefCounted
## Battlefield environment state, scene loading helpers, shared queries and
## instance clearing used by every environment layer.

# Paths are inert at script load. Source nodes own the selected stage's meshes/materials.
const TERRAIN_PATH := "res://assets/environment/terrain.glb"
const LANDMARKS_PATH := "res://assets/environment/landmarks.glb"
const DRESSING_PATH := "res://assets/environment/dressing.glb"
const PortalVortex = preload("res://environment/portal_vortex.gdshader")
const ReflectionSky = "res://materials/battlefield_reflection_sky.tres"
const ForgeReflectionSky = "res://materials/forge_reflection_sky.tres"
const FoliageWind = preload("res://environment/foliage_wind.gdshader")
const ChapterThreeProps = preload("res://environment/chapter_three_props.gd")
const ChapterThreeDebris = preload("res://environment/chapter_three_debris.gd")
const ChapterThreeTiles = preload("res://environment/chapter_three_tiles.gd")
const ChapterTwoEnvironment = preload("res://environment/chapter_two_environment.gd")
const BattlefieldCamera = preload("res://session/battlefield_camera.gd")
const TeleportDevice = preload("res://environment/teleport_device.gd")
const TeleportHostCut = preload("res://environment/teleport_host_cut.gd")
const TeleportPairs = preload("res://combat/teleport_pairs.gd")
const FrameRows = preload("res://presentation/frame_rows.gd")
const StageResources = preload("res://presentation/stage_resources.gd")
const REFLECTION_TERRAIN_LAYER := 1 << 1
const REFLECTION_CRYSTAL_LAYER := 1 << 2

signal failed(message: String)
signal camera_reset_requested

var terrain: Node3D
var _world_environment: Environment
var sun: DirectionalLight3D
var _fill_light: DirectionalLight3D
var columns := 8
var rows := 10
var _terrain_library: Node3D
var _chapter_three_props_library: Node3D
var _chapter_three_debris_library: Node3D
var _floating_debris: Array[Dictionary] = []
var _chapter_three_terrain_library: Node3D
var _chapter_two_terrain_library: Node3D
var _chapter_two_paving_library: Node3D
var _chapter_two_expansion_paving_loaded := false
var _chapter_two_expansion_library: Node3D
var _chapter_two_props_library: Node3D
var _environment_geology_library: Node3D
var _environment_props_library: Node3D
var _environment_manifest := {}
var _environment_manifests: Array = []
var _environment_stage := 0
var _using_chapter_environment := false
var _using_forge := false
var _environment_bounds := AABB()
var _landmark_library: Node3D
var _portal_material: ShaderMaterial
var _dressing_library: Node3D
var _dressing_variants: Array = []
var _using_dressing := false
var _foliage_material: ShaderMaterial
var _build_tile_slots := PackedInt32Array()
var _occupied_build_tiles := Vector2i.ZERO
var _terrain_manifest := {}
var _current_map := {}
var _using_authored := false
var _portals: Array[Node3D] = []
var _cores: Array[Dictionary] = []
var _teleport_devices: Array[Node3D] = []
var _teleport_cut_report := {}
var _initialized := false
var _resource_map := {}
var _asset_load_counts := {}
var _loaded_resource_paths: Array[String] = []
var _sky_path := ""

func _init(terrain_node: Node3D, environment: Environment, sun_light: DirectionalLight3D, fill_light: DirectionalLight3D) -> void:
	terrain = terrain_node
	_world_environment = environment
	sun = sun_light
	_fill_light = fill_light

func _load_scene(path: String) -> PackedScene:
	var packed := StageResources.load_resource(path) as PackedScene
	if packed != null:
		_asset_load_counts[path] = int(_asset_load_counts.get(path, 0)) + 1
		if path not in _loaded_resource_paths:
			_loaded_resource_paths.append(path)
	return packed

static func _matches_manifest(map: Dictionary, manifest: Dictionary) -> bool:
	return int(manifest.get("columns", 0)) == int(map.get("columns", 0)) \
		and int(manifest.get("rows", 0)) == int(map.get("rows", 0)) \
		and manifest.get("tileTypes", []) == map.get("tiles", [])

func _chapter_environment_for_map(map: Dictionary) -> Dictionary:
	if str(map.get("theme", "chapterOne")) != "chapterTwoRift":
		return {}
	for manifest: Dictionary in _environment_manifests:
		if _matches_manifest(map, manifest):
			return manifest
	return {}

func _free_library(property: String) -> void:
	var library := get(property) as Node3D
	if is_instance_valid(library):
		library.free()
	set(property, null)

static func _map_uses_expansion_paving(map: Dictionary) -> bool:
	var map_columns := int(map.get("columns", 0))
	var map_rows := int(map.get("rows", 0))
	var tiles: Array = map.get("tiles", [])
	if map_columns <= 0 or map_rows <= 0:
		return false
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		var mask := _paving_mask(index, tiles, map_columns, map_rows)
		# The authored expansion GLB adds these three missing topology variants.
		if mask == 1 or (tiles[index] != "build" and mask == 3):
			return true
	return false

func _chapter_two_paving_mask(index: int, tiles: Array) -> int:
	return _paving_mask(index, tiles, columns, rows)

static func _paving_mask(index: int, tiles: Array, map_columns: int, map_rows: int) -> int:
	var cell := Vector2i(index % map_columns, floori(float(index) / map_columns))
	var inverse := Basis(Vector3.UP, float(index % 4) * PI / 2.0).inverse()
	var mask := 0
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := cell + offset
		if neighbor.x < 0 or neighbor.x >= map_columns or neighbor.y < 0 or neighbor.y >= map_rows:
			continue
		if tiles[neighbor.y * map_columns + neighbor.x] == "blocked":
			continue
		var local := inverse * Vector3(offset.x, 0, offset.y)
		if roundi(local.x) == -1: mask |= 1
		elif roundi(local.x) == 1: mask |= 2
		elif roundi(local.z) == -1: mask |= 4
		elif roundi(local.z) == 1: mask |= 8
	return mask

func _prepare_terrain_surfaces(model: Node) -> void:
	# 원본 atlas의 색·노멀 유지. 틈의 AO와 비스듬한 시점의 필터만 설정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if material.resource_name.begins_with("stage1_authored_"):
				material.ao_light_affect = 0.8
				material.normal_scale = 1.2 if material.resource_name.ends_with("build") else 1.0

static func prepare_vertex_colors(model: Node) -> void:
	# GLB COLOR_0 보존: 일부 다중 primitive 재질의 누락된 사용 플래그 보정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material := mesh.get_active_material(surface)
			if colors != null and not colors.is_empty() and material is StandardMaterial3D:
				material.vertex_color_use_as_albedo = true

func _clear_instances() -> void:
	for child: Node in terrain.get_children():
		child.free()
	_portals.clear()
	_cores.clear()
	_teleport_devices.clear()
	_floating_debris.clear()
	_teleport_cut_report.clear()
	_current_map = {}
	_build_tile_slots.clear()
	_occupied_build_tiles = Vector2i.ZERO
	if _foliage_material != null:
		_foliage_material.set_shader_parameter("occupied_build_tiles", _occupied_build_tiles)

func _fail(message: String) -> void:
	failed.emit(message)
