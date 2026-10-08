extends RefCounted

# Paths are inert at script load. Source nodes own the selected stage's meshes/materials.
const TERRAIN_PATH := "res://assets/environment/terrain.glb"
const LANDMARKS_PATH := "res://assets/environment/landmarks.glb"
const DRESSING_PATH := "res://assets/environment/dressing.glb"
const PortalVortex = preload("res://environment/portal_vortex.gdshader")
const ReflectionSky = "res://materials/battlefield_reflection_sky.tres"
const ForgeReflectionSky = "res://materials/forge_reflection_sky.tres"
const FoliageWind = preload("res://environment/foliage_wind.gdshader")
const ChapterThreeProps = preload("res://environment/chapter_three_props.gd")
const ChapterThreeTiles = preload("res://environment/chapter_three_tiles.gd")
const ChapterTwoEnvironment = preload("res://environment/chapter_two_environment.gd")
const BattlefieldCamera = preload("res://session/battlefield_camera.gd")
const TeleportDevice = preload("res://environment/teleport_device.gd")
const TeleportHostCut = preload("res://environment/teleport_host_cut.gd")
const TeleportPairs = preload("res://combat/teleport_pairs.gd")
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


func initialize() -> bool:
	if _initialized:
		return true
	# Metadata is small; no scene or texture is loaded until build_terrain selects a map.
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain_manifest.json"))
	if not (manifest is Dictionary):
		_fail("지형 원본의 맵 정보를 읽지 못했습니다.")
		return false
	_terrain_manifest = manifest
	var dressing_manifests = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dressing_manifests.json"))
	if not dressing_manifests is Array:
		_fail("스테이지 환경 원본의 맵 정보를 읽지 못했습니다.")
		return false
	_dressing_variants = dressing_manifests
	_initialized = true
	return true


func _load_scene(path: String) -> PackedScene:
	var packed := StageResources.load_resource(path) as PackedScene
	if packed != null:
		_asset_load_counts[path] = int(_asset_load_counts.get(path, 0)) + 1
		if path not in _loaded_resource_paths:
			_loaded_resource_paths.append(path)
	return packed


func _prepare_landmarks() -> bool:
	if is_instance_valid(_landmark_library):
		return true
	var packed := _load_scene(LANDMARKS_PATH)
	if packed == null:
		_fail("공용 포탈·코어 GLB를 불러오지 못했습니다.")
		return false
	_landmark_library = packed.instantiate()
	prepare_vertex_colors(_landmark_library)
	var vortex := _landmark_library.find_child("portal_vortex", true, false) as MeshInstance3D
	var crystal := _landmark_library.find_child("core_crystal", true, false) as MeshInstance3D
	if not vortex or not crystal:
		_fail("공용 포탈·코어 GLB의 소용돌이·결정 노드를 찾지 못했습니다.")
		_release_landmarks()
		return false
	# 타일별 복사본도 메시·재질을 공유하고 전투 시계만 한 번 전달.
	_portal_material = ShaderMaterial.new()
	_portal_material.shader = PortalVortex
	vortex.material_override = _portal_material
	vortex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var has_crystal_shell := false
	for surface in range(crystal.mesh.get_surface_count()):
		var material := crystal.mesh.surface_get_material(surface) as StandardMaterial3D
		if material and material.resource_name == "core_crystal_facets":
			# 원본 면색·노멀·PBR 데이터를 보존하고 모든 타일이 한 재질을 공유.
			var crystal_material := material.duplicate() as StandardMaterial3D
			crystal_material.refraction_enabled = false
			crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			crystal.set_surface_override_material(surface, crystal_material)
			has_crystal_shell = true
	if not has_crystal_shell:
		_fail("공용 코어 GLB의 결정 외피 재질을 찾지 못했습니다.")
		_release_landmarks()
		return false
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for mesh: MeshInstance3D in _landmark_library.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	crystal.layers = REFLECTION_CRYSTAL_LAYER
	return true


func _prepare_chapter_one() -> bool:
	if not is_instance_valid(_terrain_library):
		var packed := _load_scene(TERRAIN_PATH)
		if packed == null:
			_fail("챕터 1 지형 GLB를 불러오지 못했습니다.")
			return false
		_terrain_library = packed.instantiate()
		prepare_vertex_colors(_terrain_library)
		_prepare_terrain_surfaces(_terrain_library)
		for mesh: MeshInstance3D in _terrain_library.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	if _foliage_material == null:
		_foliage_material = ShaderMaterial.new()
		_foliage_material.shader = FoliageWind
	return true


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


func _release_landmarks() -> void:
	_free_library("_landmark_library")
	_portal_material = null


func _release_paving() -> void:
	# The expansion node is parented under the paving source and dies with it.
	_free_library("_chapter_two_paving_library")
	_chapter_two_expansion_library = null
	_chapter_two_expansion_paving_loaded = false


func _load_environment_manifests() -> bool:
	if not _environment_manifests.is_empty():
		return true
	var manifests = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter2_environment_manifests.json"))
	if not manifests is Array:
		_fail("챕터 2 절벽 원본의 맵 정보를 읽지 못했습니다.")
		return false
	_environment_manifests = manifests
	return true


func resource_paths(map: Dictionary) -> Array[String]:
	if not initialize():
		return []
	var theme := str(map.get("theme", "chapterOne"))
	var paths: Array[String] = [LANDMARKS_PATH, ForgeReflectionSky if theme == "chapterThreeForge" else ReflectionSky]
	if theme == "chapterThreeForge":
		paths.append_array(["res://assets/environment/chapter3_tiles.glb", "res://assets/environment/chapter3_props.glb"])
	elif theme == "chapterTwoRift":
		if not _load_environment_manifests():
			return []
		paths.append("res://assets/environment/chapter2_tiles.glb")
		var manifest := _chapter_environment_for_map(map)
		if manifest.is_empty():
			paths.append("res://assets/environment/chapter2_props.glb")
		else:
			var stage := int(manifest["stage"])
			paths.append("res://assets/environment/chapter2_stage%d_geology.glb" % stage)
			paths.append("res://assets/environment/chapter2_stage%d_props.glb" % stage)
			paths.append("res://assets/environment/chapter2_tiles_optimized.glb")
			if _map_uses_expansion_paving(map):
				paths.append("res://assets/environment/chapter2_tiles_expansion.glb")
	elif theme == "chapterOne":
		paths.append(TERRAIN_PATH)
		if _matches_manifest(map, _terrain_manifest):
			paths.append(DRESSING_PATH)
		else:
			for variant: Dictionary in _dressing_variants:
				if _matches_manifest(map, variant):
					paths.append(str(variant["resource"]))
					break
	else:
		return []
	if not map.get("teleportPairs", []).is_empty():
		paths.append(TeleportDevice.MODEL_PATH)
	return paths


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


func prepare_for_map(map: Dictionary) -> bool:
	if not initialize():
		return false
	var theme := str(map.get("theme", "chapterOne"))
	if theme not in ["chapterOne", "chapterTwoRift", "chapterThreeForge"]:
		_fail("지원하지 않는 3D 전장 테마: " + theme)
		return false
	if theme == "chapterTwoRift" and not _load_environment_manifests():
		return false
	if map == _resource_map:
		return true
	# Release rendered copies before their source resources; keep only the next map's intersection.
	_clear_instances()
	if theme != "chapterOne":
		_free_library("_terrain_library")
		_foliage_material = null
	if theme != "chapterOne" or not _matches_manifest(map, _terrain_manifest):
		_free_library("_dressing_library")
	for variant: Dictionary in _dressing_variants:
		if theme != "chapterOne" or not _matches_manifest(map, variant):
			if is_instance_valid(variant.get("library")):
				variant["library"].free()
			variant.erase("library")
	if theme != "chapterThreeForge":
		_free_library("_chapter_three_terrain_library")
		_free_library("_chapter_three_props_library")
	var manifest := _chapter_environment_for_map(map)
	if theme != "chapterTwoRift":
		_free_library("_chapter_two_terrain_library")
		_free_library("_chapter_two_props_library")
		_release_paving()
	elif manifest.is_empty():
		_release_paving()
	else:
		# Authored stage scenery supplies its own props; fallback props would be unused.
		_free_library("_chapter_two_props_library")
		_release_unused_expansion(map)
	if int(manifest.get("stage", 0)) != _environment_stage:
		_release_chapter_environment()
	if map.get("teleportPairs", []).is_empty():
		TeleportDevice.release_resources()
	var next_paths := resource_paths(map)
	if not _sky_path.is_empty() and _sky_path not in next_paths:
		_world_environment.sky = null
		_sky_path = ""
	var outgoing: Array[String] = []
	for path: String in _loaded_resource_paths:
		if path not in next_paths:
			outgoing.append(path)
	StageResources.release(outgoing)
	for path: String in outgoing:
		_loaded_resource_paths.erase(path)
	_resource_map = map.duplicate(true)
	return true


func _release_unused_expansion(map: Dictionary) -> void:
	if not is_instance_valid(_chapter_two_expansion_library) or _map_uses_expansion_paving(map):
		return
	_free_library("_chapter_two_expansion_library")
	_chapter_two_expansion_paving_loaded = false


func resource_snapshot() -> Dictionary:
	var libraries: Array[String] = []
	for property in ["_terrain_library", "_landmark_library", "_dressing_library",
			"_chapter_two_terrain_library", "_chapter_two_props_library", "_chapter_two_paving_library",
			"_chapter_two_expansion_library", "_chapter_three_terrain_library", "_chapter_three_props_library",
			"_environment_geology_library", "_environment_props_library"]:
		var library := get(property) as Node3D
		if is_instance_valid(library):
			libraries.append(library.scene_file_path)
	for variant: Dictionary in _dressing_variants:
		if is_instance_valid(variant.get("library")):
			libraries.append(str(variant["resource"]))
	return {"libraries": libraries, "library_count": libraries.size(),
		"asset_load_counts": _asset_load_counts.duplicate(), "environment_stage": _environment_stage,
		"sky_path": _sky_path, "sky_loaded": _world_environment.sky != null,
		"teleport": TeleportDevice.resource_snapshot()}


func apply_stage_lighting() -> void:
	var path: String = ForgeReflectionSky if _using_forge else ReflectionSky
	if _world_environment.sky == null or _sky_path != path:
		_world_environment.sky = StageResources.load_resource(path) as Sky
		if _world_environment.sky != null:
			_sky_path = path
			_asset_load_counts[path] = int(_asset_load_counts.get(path, 0)) + 1
			if path not in _loaded_resource_paths:
				_loaded_resource_paths.append(path)
	if _using_forge:
		sun.light_energy = 1.35
		sun.light_color = Color(1.0, 0.94, 0.86)
		sun.shadow_blur = 0.85
		_world_environment.ambient_light_energy = 0.10
		_fill_light.light_energy = 0.08
		return
	# 연속 절벽 전장의 기본광을 낮추고 광물 주변의 실제 입사광을 대비시킨다.
	# 다른 맵으로 이동할 때 공용 조명을 정확히 복원한다.
	sun.light_energy = 1.20 if _using_chapter_environment else 1.50
	sun.light_color = Color(0.92, 0.95, 1.0) if _using_chapter_environment else Color(1.0, 0.94, 0.84)
	sun.shadow_blur = 0.85 if _using_chapter_environment else 1.25
	_world_environment.ambient_light_energy = 0.115 if _using_chapter_environment else 0.16
	_fill_light.light_energy = 0.08 if _using_chapter_environment else 0.14


func _add_environment_accent_lights() -> void:
	var accents := Node3D.new()
	accents.name = "stage%d_mineral_lights" % _environment_stage
	terrain.add_child(accents)
	# 원본의 보라색 몸체·청록 끝은 유지하며 주변 암반에도 빛이 닿게 한다.
	var sources := [
		[Vector3(-4.35, 0.63, -4.23), Color(0.24, 0.74, 1.0), 0.45, 1.25],
		[Vector3(-1.65, 0.43, 3.50), Color(0.22, 0.65, 1.0), 0.85, 1.60],
		[Vector3(3.45, 0.43, 2.35), Color(0.22, 0.65, 1.0), 0.85, 1.60],
		[Vector3(3.40, -0.02, -2.48), Color(0.55, 0.20, 1.0), 0.65, 1.35],
	]
	# 6의 기존 화면은 메타데이터가 없을 때 위 좌표를 그대로 보존한다.
	if _environment_manifest.has("accentLights") or _environment_stage != 6:
		sources = []
		for record: Dictionary in _environment_manifest.get("accentLights", []):
			var point: Array = record["positionGodot"]
			var color: Array = record["color"]
			sources.append([Vector3(float(point[0]), float(point[1]), float(point[2])),
				Color(float(color[0]), float(color[1]), float(color[2])),
				float(record.get("energy", 0.85)), float(record.get("range", 1.6))])
	for source: Array in sources:
		var light := OmniLight3D.new()
		light.position = source[0]
		light.light_color = source[1]
		light.light_energy = source[2]
		light.omni_range = source[3]
		light.light_cull_mask = REFLECTION_TERRAIN_LAYER
		light.shadow_enabled = false
		accents.add_child(light)




func build_terrain(map: Dictionary) -> bool:
	var next_columns := int(map.get("columns", 0))
	var next_rows := int(map.get("rows", 0))
	var tiles: Array = map.get("tiles", [])
	if next_columns <= 0 or next_rows <= 0 or tiles.size() != next_columns * next_rows:
		_fail("3D 전장의 맵 크기와 타일 수가 맞지 않습니다.")
		return false
	var teleport_error := TeleportPairs.validate_map(map)
	if not teleport_error.is_empty():
		_fail("텔레포트 맵 계약 오류: " + teleport_error)
		return false
	var theme := str(map.get("theme", "chapterOne"))
	if theme not in ["chapterOne", "chapterTwoRift", "chapterThreeForge"]:
		_fail("지원하지 않는 3D 전장 테마: " + theme)
		return false
	if not prepare_for_map(map) or not _prepare_landmarks():
		return false
	var chapter_three := theme == "chapterThreeForge"
	if chapter_three and (not _prepare_chapter_three() or not _prepare_chapter_three_props()):
		return false
	var chapter_two := theme == "chapterTwoRift"
	var matched_manifest := _chapter_environment_for_map(map)
	if chapter_two and not _prepare_chapter_two(matched_manifest.is_empty()):
		return false
	if not chapter_two and not chapter_three and not _prepare_chapter_one():
		return false
	var tile_library := _chapter_two_terrain_library if chapter_two else (_chapter_three_terrain_library if chapter_three else _terrain_library)
	var forge_variants := ChapterThreeTiles.variants(map) if chapter_three else {}
	columns = next_columns
	rows = next_rows
	_clear_instances()
	# 이전 맵의 인스턴스를 해제한 뒤 다음 원본을 읽어 대형 지형 캐시가 누적되지 않게 한다.
	if matched_manifest.is_empty():
		_release_chapter_environment()
	elif not _prepare_chapter_environment(matched_manifest):
		return false
	_using_chapter_environment = not matched_manifest.is_empty()
	if _using_forge != chapter_three:
		camera_reset_requested.emit()
	_using_forge = chapter_three
	apply_stage_lighting()
	_environment_bounds = AABB()
	if _using_chapter_environment:
		terrain.add_child(_environment_geology_library.duplicate())
		terrain.add_child(_environment_props_library.duplicate())
		_add_environment_accent_lights()
		_environment_bounds = BattlefieldCamera.mesh_bounds(_environment_geology_library).merge(BattlefieldCamera.mesh_bounds(_environment_props_library))
	var authored := _terrain_library.find_child("stage1_environment", true, false) if is_instance_valid(_terrain_library) else null
	_using_authored = not chapter_two and not chapter_three and authored != null and int(_terrain_manifest.get("columns", 0)) == columns \
		and int(_terrain_manifest.get("rows", 0)) == rows and _terrain_manifest.get("tileTypes", []) == tiles
	_build_tile_slots.clear()
	if _using_authored:
		if not is_instance_valid(_dressing_library):
			var packed := _load_scene(DRESSING_PATH)
			if packed == null:
				_fail("스테이지 1 환경 GLB를 불러오지 못했습니다.")
				return false
			_dressing_library = packed.instantiate()
			if not _prepare_dressing(_dressing_library):
				_free_library("_dressing_library")
				return false
		terrain.add_child(authored.duplicate())
		# 동일한 맵 원본에 배치된 환경 장식만 지형 수명에 연결.
		terrain.add_child(_dressing_library.duplicate())
	_using_dressing = _using_authored
	if not _using_authored and not chapter_two and not chapter_three:
		for variant: Dictionary in _dressing_variants:
			if int(variant.get("columns", 0)) != columns or int(variant.get("rows", 0)) != rows or variant.get("tileTypes", []) != tiles:
				continue
			# 선택 맵의 장식만 보관하고 같은 맵 로비 복귀·재시작에는 재사용.
			if not is_instance_valid(variant.get("library")):
				var packed := _load_scene(str(variant["resource"]))
				if packed == null:
					_fail("스테이지 환경 GLB를 불러오지 못했습니다.")
					return false
				var library := packed.instantiate() as Node3D
				if not _prepare_dressing(library):
					library.free()
					return false
				variant["library"] = library
			terrain.add_child(variant["library"].duplicate())
			_using_dressing = true
			break
	if _using_dressing:
		_build_tile_slots.resize(tiles.size())
		_build_tile_slots.fill(-1)
	if _using_chapter_environment and not _build_chapter_two_paving(tiles):
		return false
	var names := {"path": "path_tile", "build": "build_tile", "spawn": "portal", "core": "core"}
	var build_slot := 0
	for index in range(tiles.size()):
		var tile: String = tiles[index]
		if _using_dressing and tile == "build":
			# Blender UV2와 같은 맵 순회의 건설칸 슬롯.
			_build_tile_slots[index] = build_slot
			build_slot += 1
		if tile == "blocked" or (_using_authored and tile != "spawn" and tile != "core"):
			continue
		if not names.has(tile):
			_fail("지원하지 않는 맵 타일: %s" % tile)
			return false
		if _using_chapter_environment and tile in ["path", "build"]:
			continue
		var point := Vector3(float(index % columns) + 0.5 - columns / 2.0, 0.0, floor(float(index) / float(columns)) + 0.5 - rows / 2.0)
		if not _using_authored and not _using_chapter_environment and (tile == "spawn" or tile == "core"):
			var foundation: Node3D = tile_library.find_child("path_tile", true, false).duplicate()
			foundation.position = point
			if chapter_two:
				foundation.rotation.y = float(index % 4) * PI / 2.0
			terrain.add_child(foundation)
		var library := _landmark_library if tile == "spawn" or tile == "core" else tile_library
		var model_name: String = forge_variants.get(index, names[tile])
		var model := library.find_child(model_name, true, false)
		if not model:
			_fail("지형 GLB 노드를 찾지 못했습니다: %s" % names[tile])
			return false
		var instance: Node3D = model.duplicate()
		instance.position = point
		if chapter_two:
			if tile in ["path", "build"]:
				# 원본의 형상·재질을 보존하며 정사각 타일의 반복 방향만 분산.
				instance.rotation.y = float(index % 4) * PI / 2.0
			instance.set_meta("tile_type", tile)
			instance.set_meta("grid_cell", Vector2i(index % columns, floori(float(index) / columns)))
		if chapter_three:
			instance.set_meta("tile_type", tile)
			instance.set_meta("tile_variant", model_name)
			instance.set_meta("grid_cell", Vector2i(index % columns, floori(float(index) / columns)))
		terrain.add_child(instance)
		if tile == "spawn":
			_portals.append(instance)
		elif tile == "core":
			var crystal := instance.find_child("core_crystal", true, false) as Node3D
			_cores.append({"root": instance, "crystal": crystal, "rest_position": crystal.position, "rest_basis": crystal.basis})
	if chapter_three and not ChapterThreeTiles.populate_panels(terrain, _chapter_three_terrain_library, map):
		_fail("챕터 3 교체형 패널 메시를 확인하지 못했습니다.")
		return false
	if chapter_three and not ChapterThreeProps.populate(terrain, _chapter_three_props_library, map):
		_fail("챕터 3 외곽 소품의 안전한 배치를 확인하지 못했습니다.")
		return false
	if chapter_two and not _using_chapter_environment and not ChapterTwoEnvironment.populate(terrain, _chapter_two_props_library, map):
		_fail("챕터 2 환경 소품의 배치 계약을 확인하지 못했습니다.")
		return false
	if not _build_teleport_devices(map):
		return false
	# JSON 숫자형까지 보존해 같은 맵을 매 프레임 재생성하지 않음.
	_current_map = map.duplicate(true)
	return true


func _build_teleport_devices(map: Dictionary) -> bool:
	var pairs: Array = map.get("teleportPairs", [])
	if pairs.is_empty(): return true
	var centers: Array[Vector3] = []
	for pair: Dictionary in pairs:
		for role in ["entrance", "exit"]:
			var cell: Array = pair[role]
			centers.append(Vector3(float(cell[0]) + 0.5 - columns / 2.0, 0.0, float(cell[1]) + 0.5 - rows / 2.0))
	_teleport_cut_report = TeleportHostCut.apply(terrain, centers)
	var endpoint := 0
	for pair: Dictionary in pairs:
		for role in ["entrance", "exit"]:
			var device := TeleportDevice.new()
			device.name = "Teleport_%s_%s" % [str(pair.color), role]
			if not device.configure(str(pair.color), role == "exit"):
				device.free()
				_fail("텔레포트 모델을 준비하지 못했습니다.")
				return false
			device.position = centers[endpoint]
			device.set_meta("grid_cell", Vector2i(int(pair[role][0]), int(pair[role][1])))
			terrain.add_child(device)
			_teleport_devices.append(device)
			endpoint += 1
	return true




func _prepare_chapter_three_props() -> bool:
	if is_instance_valid(_chapter_three_props_library):
		return true
	var packed := _load_scene("res://assets/environment/chapter3_props.glb")
	if packed == null:
		_fail("챕터 3 환경 소품 GLB를 불러오지 못했습니다.")
		return false
	_chapter_three_props_library = packed.instantiate()
	for kind in ChapterThreeProps.KINDS:
		if _chapter_three_props_library.find_child(kind, true, false) == null:
			_fail("챕터 3 환경 GLB 노드 누락: " + kind)
			_chapter_three_props_library.free()
			_chapter_three_props_library = null
			return false
	prepare_vertex_colors(_chapter_three_props_library)
	for mesh: MeshInstance3D in _chapter_three_props_library.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	return true


func _prepare_chapter_three() -> bool:
	if is_instance_valid(_chapter_three_terrain_library):
		return true
	var packed := _load_scene("res://assets/environment/chapter3_tiles.glb")
	if packed == null:
		_fail("챕터 3 타일 GLB를 불러오지 못했습니다.")
		return false
	_chapter_three_terrain_library = packed.instantiate()
	for kind in ["path_tile", "grate_tile", "build_tile", "plain_build_tile", "panel_solid", "panel_vent"]:
		if _chapter_three_terrain_library.find_child(kind, true, false) == null:
			_fail("챕터 3 타일 GLB 노드 누락: " + kind)
			_chapter_three_terrain_library.free()
			_chapter_three_terrain_library = null
			return false
	prepare_vertex_colors(_chapter_three_terrain_library)
	# 승인 원본의 PBR·색·거칠기·형태를 유지한다. 1장 석재 보정은 적용하지 않는다.
	for mesh: MeshInstance3D in _chapter_three_terrain_library.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	return true


func _release_chapter_environment() -> void:
	if is_instance_valid(_environment_geology_library):
		_environment_geology_library.free()
	if is_instance_valid(_environment_props_library):
		_environment_props_library.free()
	_environment_geology_library = null
	_environment_props_library = null
	_environment_stage = 0
	_environment_manifest = {}
	_using_chapter_environment = false
	_environment_bounds = AABB()


func _prepare_chapter_environment(manifest: Dictionary) -> bool:
	var stage := int(manifest["stage"])
	if _environment_stage == stage and is_instance_valid(_environment_geology_library) and is_instance_valid(_environment_props_library):
		return true
	_release_chapter_environment()
	var geology := _load_scene("res://assets/environment/chapter2_stage%d_geology.glb" % stage)
	var props := _load_scene("res://assets/environment/chapter2_stage%d_props.glb" % stage)
	if geology == null or props == null:
		_fail("스테이지 %d 절벽·환경 GLB를 불러오지 못했습니다." % stage)
		return false
	_environment_geology_library = geology.instantiate()
	_environment_props_library = props.instantiate()
	var geology_name := "stage%d_geology" % stage
	var props_name := "stage%d_props" % stage
	var has_geology_root := _environment_geology_library.name == geology_name or _environment_geology_library.find_child(geology_name, true, false) != null
	var has_props_root := _environment_props_library.name == props_name or _environment_props_library.find_child(props_name, true, false) != null
	if not has_geology_root or not has_props_root:
		_fail("스테이지 %d 절벽·환경 GLB의 루트 계약이 맞지 않습니다." % stage)
		_release_chapter_environment()
		return false
	_environment_stage = stage
	_environment_manifest = manifest
	for library in [_environment_geology_library, _environment_props_library]:
		prepare_vertex_colors(library)
		_prepare_terrain_surfaces(library)
		for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material:
					material.refraction_enabled = false
					if stage >= 21 and material.resource_name == "ch2_crystal_mineral_facets":
						# 승인 원본 IOR Level=.28 → KHR specularFactor=.56.
						# Godot importer가 이 확장을 무시해 기본 .5로 읽는 손실만 복원한다.
						material.metallic_specular = 0.28
	return true


func _prepare_chapter_two(include_props := true) -> bool:
	var prepared: Array[Node3D] = []
	if not is_instance_valid(_chapter_two_terrain_library):
		var tiles := _load_scene("res://assets/environment/chapter2_tiles.glb")
		if tiles == null:
			_fail("챕터 2 지형 GLB를 불러오지 못했습니다.")
			return false
		_chapter_two_terrain_library = tiles.instantiate()
		for kind in ["path_tile", "build_tile"]:
			if _chapter_two_terrain_library.find_child(kind, true, false) == null:
				_fail("챕터 2 지형 GLB 노드 누락: " + kind)
				_free_library("_chapter_two_terrain_library")
				return false
		prepared.append(_chapter_two_terrain_library)
	if include_props and not is_instance_valid(_chapter_two_props_library):
		var props := _load_scene("res://assets/environment/chapter2_props.glb")
		if props == null:
			_fail("챕터 2 환경 GLB를 불러오지 못했습니다.")
			return false
		_chapter_two_props_library = props.instantiate()
		prepared.append(_chapter_two_props_library)
	for library in prepared:
		prepare_vertex_colors(library)
		_prepare_terrain_surfaces(library)
		for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material:
					# 원본 알파·투과 의도와 PBR는 보존. 공용 내장 굴절 비사용 정책만 적용.
					material.refraction_enabled = false
	return true


func _prepare_chapter_two_paving() -> bool:
	if is_instance_valid(_chapter_two_paving_library):
		return true
	var packed := _load_scene("res://assets/environment/chapter2_tiles_optimized.glb")
	if packed == null:
		_fail("챕터 2 병합 타일 GLB를 불러오지 못했습니다.")
		return false
	_chapter_two_paving_library = packed.instantiate()
	prepare_vertex_colors(_chapter_two_paving_library)
	_prepare_terrain_surfaces(_chapter_two_paving_library)
	# 두 GLB의 동일 이름 PBR 재질과 9개 이미지 SHA-256을 오프라인 검증했다.
	# 근거: docs/analysis/godot_optimization_20260913/texture_identity.json
	# 이미 준비한 texture를 slot별 공유한다. 로딩 중 GPU readback/이미지 비교는 하지 않는다.
	var shared_materials := {}
	for source: MeshInstance3D in _chapter_two_terrain_library.find_children("*", "MeshInstance3D", true, false):
		for surface in range(source.mesh.get_surface_count()):
			var material := source.get_active_material(surface) as StandardMaterial3D
			if material and material.resource_name in ["chapter2_build", "chapter2_path", "chapter2_side"]:
				shared_materials[material.resource_name] = material
	var prepared_materials := {}
	for source: MeshInstance3D in _chapter_two_paving_library.find_children("*", "MeshInstance3D", true, false):
		for surface in range(source.mesh.get_surface_count()):
			var material := source.get_active_material(surface) as StandardMaterial3D
			if material:
				if not prepared_materials.has(material.get_instance_id()) and shared_materials.has(material.resource_name):
					var shared: StandardMaterial3D = shared_materials[material.resource_name]
					for slot in range(BaseMaterial3D.TEXTURE_MAX):
						material.set_texture(slot, shared.get_texture(slot))
					prepared_materials[material.get_instance_id()] = true
				material.refraction_enabled = false
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				# MultiMesh는 MeshInstance의 surface override를 읽지 않으므로 공유 mesh에 연결.
				source.mesh.surface_set_material(surface, material)
	return true


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


func _build_chapter_two_paving(tiles: Array) -> bool:
	if not _prepare_chapter_two_paving():
		return false
	var groups := {}
	for index in range(tiles.size()):
		var tile: String = tiles[index]
		if tile == "blocked":
			continue
		var kind := "build" if tile == "build" else "path"
		var mask := _chapter_two_paving_mask(index, tiles)
		var variant := "%s_tile_mask_%d" % [kind, mask]
		if not groups.has(variant):
			var root := _chapter_two_paving_library.find_child(variant, true, false) as Node3D
			if root == null and not _chapter_two_expansion_paving_loaded:
				# 기존 맵 마스크·재질을 유지하고 새 맵의 인접 형태만 저장된 타일 파생 원본에서 읽는다.
				var expansion := _load_scene("res://assets/environment/chapter2_tiles_expansion.glb")
				if expansion != null:
					var extra := expansion.instantiate()
					prepare_vertex_colors(extra)
					_prepare_terrain_surfaces(extra)
					for mesh: MeshInstance3D in extra.find_children("*", "MeshInstance3D", true, false):
						for surface in range(mesh.mesh.get_surface_count()):
							var material := mesh.get_active_material(surface) as StandardMaterial3D
							if material:
								material.refraction_enabled = false
								material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
								mesh.mesh.surface_set_material(surface,material)
					_chapter_two_expansion_library = extra
					_chapter_two_paving_library.add_child(extra)
					_chapter_two_expansion_paving_loaded = true
					root = _chapter_two_paving_library.find_child(variant,true,false) as Node3D
			if root == null or root.get_child_count() != 1 or not root.get_child(0) is MeshInstance3D:
				_fail("챕터 2 병합 타일 노드 누락: " + variant)
				return false
			var source := root.get_child(0) as MeshInstance3D
			if root.transform != Transform3D.IDENTITY or source.transform != Transform3D.IDENTITY:
				_fail("챕터 2 병합 타일 원점 계약 오류: " + variant)
				return false
			groups[variant] = {"mesh": source.mesh, "indices": [], "poses": [], "kind": kind, "mask": mask}
		var point := Vector3(float(index % columns) + 0.5 - columns / 2.0, 0.0, floori(float(index) / columns) + 0.5 - rows / 2.0)
		groups[variant]["indices"].append(index)
		groups[variant]["poses"].append(Transform3D(Basis(Vector3.UP, float(index % 4) * PI / 2.0), point))
	for variant: String in groups:
		var group: Dictionary = groups[variant]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group["mesh"]
		multimesh.instance_count = group["poses"].size()
		for slot in range(multimesh.instance_count):
			multimesh.set_instance_transform(slot, group["poses"][slot])
		var batch := MultiMeshInstance3D.new()
		batch.name = variant + "_batch"
		batch.multimesh = multimesh
		batch.layers = 1 | REFLECTION_TERRAIN_LAYER
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		batch.set_meta("tile_type", group["kind"])
		batch.set_meta("tile_indices", group["indices"])
		batch.set_meta("neighbor_mask", group["mask"])
		terrain.add_child(batch)
	return true


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


func _prepare_dressing(library: Node3D) -> bool:
	prepare_vertex_colors(library)
	var foliage := library.find_child("stage1_dressing_foliage", true, false) as MeshInstance3D
	var rocks := library.find_child("stage1_dressing_rocks", true, false) as MeshInstance3D
	if foliage == null or rocks == null:
		_fail("환경 GLB의 풀·바위 메시를 찾지 못했습니다.")
		return false
	for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	foliage.material_override = _foliage_material
	foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	foliage.extra_cull_margin = 0.03
	return true


static func prepare_vertex_colors(model: Node) -> void:
	# GLB COLOR_0 보존: 일부 다중 primitive 재질의 누락된 사용 플래그 보정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material := mesh.get_active_material(surface)
			if colors != null and not colors.is_empty() and material is StandardMaterial3D:
				material.vertex_color_use_as_albedo = true




func update_occupancy(units: Array, supported_types: Dictionary) -> void:
	var occupied := Vector2i.ZERO
	if _using_dressing:
		for data: Array in units:
			var type := str(data[6]) if data.size() > 6 else "cannon"
			if not supported_types.has(type):
				continue
			var x := floori(float(data[1]))
			var z := floori(float(data[2]))
			if x >= 0 and x < columns and z >= 0 and z < rows:
				var slot := _build_tile_slots[z * columns + x]
				if slot >= 0 and slot < 16:
					occupied.x |= 1 << slot
				elif slot >= 16 and slot < 32:
					occupied.y |= 1 << (slot - 16)
	if occupied != _occupied_build_tiles:
		_occupied_build_tiles = occupied
		if _foliage_material != null:
			_foliage_material.set_shader_parameter("occupied_build_tiles", occupied)


func update_frame(frame: Dictionary) -> void:
	var time := float(frame.get("time", 0.0))
	for device in _teleport_devices:
		device.update_time(time)
	if _portal_material != null:
		_portal_material.set_shader_parameter("battle_time", time)
		_portal_material.set_shader_parameter("alert", clampf(float(frame.get("portalAlert", 0.0)), 0.0, 1.0))
	var core_hit := clampf(float(frame.get("nexusHit", 0.0)), 0.0, 1.0)
	for core: Dictionary in _cores:
		var crystal: Node3D = core["crystal"]
		# 석재 받침은 고정하고 결정만 원본 피벗에서 부유·회전.
		crystal.position = core["rest_position"] + Vector3(0.0, sin(time * 2.5) * 0.018, 0.0)
		crystal.basis = Basis(Vector3.UP, time * 0.22) * core["rest_basis"]
		crystal.scale *= 1.0 + core_hit * 0.025


func _clear_instances() -> void:
	for child: Node in terrain.get_children():
		child.free()
	_portals.clear()
	_cores.clear()
	_teleport_devices.clear()
	_teleport_cut_report.clear()
	_current_map = {}
	_build_tile_slots.clear()
	_occupied_build_tiles = Vector2i.ZERO
	if _foliage_material != null:
		_foliage_material.set_shader_parameter("occupied_build_tiles", _occupied_build_tiles)


func clear() -> void:
	# Lobby/restart clears presentation only; selected-map source resources stay reusable.
	_clear_instances()
	_using_authored = false
	_using_dressing = false
	_using_forge = false
	_using_chapter_environment = false
	_environment_bounds = AABB()


func dispose() -> void:
	clear()
	for property in ["_terrain_library", "_chapter_three_props_library", "_chapter_three_terrain_library",
			"_chapter_two_terrain_library", "_chapter_two_props_library", "_dressing_library"]:
		_free_library(property)
	_release_paving()
	_release_chapter_environment()
	_release_landmarks()
	for variant: Dictionary in _dressing_variants:
		if is_instance_valid(variant.get("library")):
			variant["library"].free()
		variant.erase("library")
	_foliage_material = null
	_resource_map = {}
	_world_environment.sky = null
	_sky_path = ""
	TeleportDevice.release_resources()
	StageResources.release(_loaded_resource_paths)
	_loaded_resource_paths.clear()



func _fail(message: String) -> void:
	failed.emit(message)


func attach_lighting(scene_root: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := _world_environment
	# 배경만 공통 Canvas로 표시하고 PBR 반사와 챕터별 조명은 유지한다.
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = -1
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.86, 1.0)
	environment.ambient_light_energy = 0.16
	# 공용 하늘 반사. 배경과 확산 환경광은 별도 설정을 유지한다.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	scene_root.add_child(environment_node)
	# 상면 총광량은 유지하고 약한 환경·보조광으로 그늘의 석재 면을 살린다.
	sun.rotation_degrees = Vector3(-48, -125, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.50
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	# 작은 직교 전장에 그림자 해상도를 모으고 낮은 기단·잎의 접촉을 보존.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# 낮은 depth bias는 석재 상면에 자기 그림자 줄무늬를 만들어 기존 값을 유지.
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.35
	# Mobile에서도 PCF를 사용해 접촉은 남기고 그림자 경계만 완만하게 한다.
	sun.shadow_blur = 1.25
	scene_root.add_child(sun)
	var fill := _fill_light
	fill.rotation_degrees = Vector3(-40, 135, 0)
	fill.light_color = Color(0.65, 0.8, 1.0)
	fill.light_energy = 0.14
	scene_root.add_child(fill)
	# 낮은 고정 입사각의 결정 전용 보조광: 급경사 면의 실제 반사 하이라이트.
	var crystal_light := DirectionalLight3D.new()
	crystal_light.name = "CoreSpecularLight"
	crystal_light.rotation_degrees = Vector3(10.0, 30.17, 0.0)
	crystal_light.light_color = Color(0.68, 0.95, 1.0)
	crystal_light.light_energy = 0.16
	crystal_light.light_cull_mask = REFLECTION_CRYSTAL_LAYER
	crystal_light.shadow_enabled = false
	scene_root.add_child(crystal_light)
