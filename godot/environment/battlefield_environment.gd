extends RefCounted

const Terrain = preload("res://assets/environment/terrain.glb")
const Landmarks = preload("res://assets/environment/landmarks.glb")
const Dressing = preload("res://assets/environment/dressing.glb")
const PortalVortex = preload("res://environment/portal_vortex.gdshader")
const ReflectionSky = preload("res://materials/battlefield_reflection_sky.tres")
const ForgeReflectionSky = preload("res://materials/forge_reflection_sky.tres")
const FoliageWind = preload("res://environment/foliage_wind.gdshader")
const ChapterThreeProps = preload("res://environment/chapter_three_props.gd")
const ChapterThreeTiles = preload("res://environment/chapter_three_tiles.gd")
const ChapterTwoEnvironment = preload("res://environment/chapter_two_environment.gd")
const BattlefieldCamera = preload("res://session/battlefield_camera.gd")
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

func _init(terrain_node: Node3D, environment: Environment, sun_light: DirectionalLight3D, fill_light: DirectionalLight3D) -> void:
	terrain = terrain_node
	_world_environment = environment
	sun = sun_light
	_fill_light = fill_light


func initialize() -> bool:
	_terrain_library = Terrain.instantiate()
	prepare_vertex_colors(_terrain_library)
	_prepare_terrain_surfaces(_terrain_library)
	_landmark_library = Landmarks.instantiate()
	prepare_vertex_colors(_landmark_library)
	var vortex := _landmark_library.find_child("portal_vortex", true, false) as MeshInstance3D
	var crystal := _landmark_library.find_child("core_crystal", true, false) as MeshInstance3D
	if not vortex or not crystal:
		_fail("공용 포탈·코어 GLB의 소용돌이·결정 노드를 찾지 못했습니다.")
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
		return false
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dressing_library = Dressing.instantiate()
	# 기존 표시 레이어 유지. 모든 PBR 소재는 공용 환경 반사를 수신.
	for library: Node3D in [_terrain_library, _landmark_library]:
		for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	crystal.layers = REFLECTION_CRYSTAL_LAYER
	# 전장 전체의 바람에 하나의 재질·GPU 시계 공유.
	_foliage_material = ShaderMaterial.new()
	_foliage_material.shader = FoliageWind
	if not _prepare_dressing(_dressing_library):
		return false
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
	return true


func apply_stage_lighting() -> void:
	_world_environment.sky = ForgeReflectionSky if _using_forge else ReflectionSky
	_world_environment.background_color = Color("203139") if _using_forge else Color("101b20")
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
	var theme := str(map.get("theme", "chapterOne"))
	if theme not in ["chapterOne", "chapterTwoRift", "chapterThreeForge"]:
		_fail("지원하지 않는 3D 전장 테마: " + theme)
		return false
	var chapter_three := theme == "chapterThreeForge"
	if chapter_three and (not _prepare_chapter_three() or not _prepare_chapter_three_props()):
		return false
	var chapter_two := theme == "chapterTwoRift"
	if chapter_two and not _prepare_chapter_two():
		return false
	if chapter_two and _environment_manifests.is_empty():
		var manifests = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter2_environment_manifests.json"))
		if not manifests is Array:
			_fail("챕터 2 절벽 원본의 맵 정보를 읽지 못했습니다.")
			return false
		_environment_manifests = manifests
	var matched_manifest: Dictionary = {}
	if chapter_two:
		for manifest: Dictionary in _environment_manifests:
			if int(manifest.get("columns", 0)) == next_columns and int(manifest.get("rows", 0)) == next_rows and manifest.get("tileTypes", []) == tiles:
				matched_manifest = manifest
				break
	var tile_library := _chapter_two_terrain_library if chapter_two else (_chapter_three_terrain_library if chapter_three else _terrain_library)
	var forge_variants := ChapterThreeTiles.variants(map) if chapter_three else {}
	columns = next_columns
	rows = next_rows
	for child in terrain.get_children():
		child.free()
	_portals.clear()
	_cores.clear()
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
	var authored := _terrain_library.find_child("stage1_environment", true, false)
	_using_authored = not chapter_two and not chapter_three and authored != null and int(_terrain_manifest.get("columns", 0)) == columns \
		and int(_terrain_manifest.get("rows", 0)) == rows and _terrain_manifest.get("tileTypes", []) == tiles
	_build_tile_slots.clear()
	if _using_authored:
		terrain.add_child(authored.duplicate())
		# 동일한 맵 원본에 배치된 환경 장식만 지형 수명에 연결.
		terrain.add_child(_dressing_library.duplicate())
	_using_dressing = _using_authored
	if not _using_authored and not chapter_two and not chapter_three:
		for variant: Dictionary in _dressing_variants:
			if int(variant.get("columns", 0)) != columns or int(variant.get("rows", 0)) != rows or variant.get("tileTypes", []) != tiles:
				continue
			# 첫 진입에만 해당 맵 장식을 준비하고 이후 맵 재방문은 자원을 공유.
			if not is_instance_valid(variant.get("library")):
				var packed := load(str(variant["resource"])) as PackedScene
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
	# JSON 숫자형까지 보존해 같은 맵을 매 프레임 재생성하지 않음.
	_current_map = map.duplicate(true)
	return true




func _prepare_chapter_three_props() -> bool:
	if is_instance_valid(_chapter_three_props_library):
		return true
	var packed := load("res://assets/environment/chapter3_props.glb") as PackedScene
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
	var packed := load("res://assets/environment/chapter3_tiles.glb") as PackedScene
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
	var geology := load("res://assets/environment/chapter2_stage%d_geology.glb" % stage) as PackedScene
	var props := load("res://assets/environment/chapter2_stage%d_props.glb" % stage) as PackedScene
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
	return true


func _prepare_chapter_two() -> bool:
	if is_instance_valid(_chapter_two_terrain_library) and is_instance_valid(_chapter_two_props_library):
		return true
	var tiles := load("res://assets/environment/chapter2_tiles.glb") as PackedScene
	var props := load("res://assets/environment/chapter2_props.glb") as PackedScene
	if tiles == null or props == null:
		_fail("챕터 2 지형·환경 GLB를 불러오지 못했습니다.")
		return false
	_chapter_two_terrain_library = tiles.instantiate()
	_chapter_two_props_library = props.instantiate()
	for kind in ["path_tile", "build_tile"]:
		if _chapter_two_terrain_library.find_child(kind, true, false) == null:
			_fail("챕터 2 지형 GLB 노드 누락: " + kind)
			_chapter_two_terrain_library.free()
			_chapter_two_props_library.free()
			_chapter_two_terrain_library = null
			_chapter_two_props_library = null
			return false
	for library in [_chapter_two_terrain_library, _chapter_two_props_library]:
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
	var packed := load("res://assets/environment/chapter2_tiles_optimized.glb") as PackedScene
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
	var cell := Vector2i(index % columns, floori(float(index) / columns))
	var inverse := Basis(Vector3.UP, float(index % 4) * PI / 2.0).inverse()
	var mask := 0
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := cell + offset
		if neighbor.x < 0 or neighbor.x >= columns or neighbor.y < 0 or neighbor.y >= rows:
			continue
		if tiles[neighbor.y * columns + neighbor.x] == "blocked":
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
		_foliage_material.set_shader_parameter("occupied_build_tiles", occupied)


func update_frame(frame: Dictionary) -> void:
	var time := float(frame.get("time", 0.0))
	_portal_material.set_shader_parameter("battle_time", time)
	_portal_material.set_shader_parameter("alert", clampf(float(frame.get("portalAlert", 0.0)), 0.0, 1.0))
	var core_hit := clampf(float(frame.get("nexusHit", 0.0)), 0.0, 1.0)
	for core: Dictionary in _cores:
		var crystal: Node3D = core["crystal"]
		# 석재 받침은 고정하고 결정만 원본 피벗에서 부유·회전.
		crystal.position = core["rest_position"] + Vector3(0.0, sin(time * 2.5) * 0.018, 0.0)
		crystal.basis = Basis(Vector3.UP, time * 0.22) * core["rest_basis"]
		crystal.scale *= 1.0 + core_hit * 0.025


func clear() -> void:
	for child: Node in terrain.get_children():
		child.free()
	_portals.clear()
	_cores.clear()
	_current_map = {}
	_using_authored = false
	_using_dressing = false
	_using_forge = false
	_release_chapter_environment()
	apply_stage_lighting()
	_build_tile_slots.clear()
	if _occupied_build_tiles != Vector2i.ZERO:
		_occupied_build_tiles = Vector2i.ZERO
		_foliage_material.set_shader_parameter("occupied_build_tiles", _occupied_build_tiles)


func dispose() -> void:
	clear()
	if is_instance_valid(_terrain_library):
		_terrain_library.free()
	if is_instance_valid(_chapter_three_props_library):
		_chapter_three_props_library.free()
	if is_instance_valid(_chapter_three_terrain_library):
		_chapter_three_terrain_library.free()
	if is_instance_valid(_chapter_two_terrain_library):
		_chapter_two_terrain_library.free()
	if is_instance_valid(_chapter_two_paving_library):
		_chapter_two_paving_library.free()
	if is_instance_valid(_chapter_two_props_library):
		_chapter_two_props_library.free()
	if is_instance_valid(_environment_geology_library):
		_environment_geology_library.free()
	if is_instance_valid(_environment_props_library):
		_environment_props_library.free()
	if is_instance_valid(_landmark_library):
		_landmark_library.free()
	if is_instance_valid(_dressing_library):
		_dressing_library.free()
	for variant: Dictionary in _dressing_variants:
		if is_instance_valid(variant.get("library")):
			variant["library"].free()



func _fail(message: String) -> void:
	failed.emit(message)


func attach_lighting(scene_root: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := _world_environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b20")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.86, 1.0)
	environment.ambient_light_energy = 0.16
	# 공용 하늘 반사. 배경과 확산 환경광은 별도 설정을 유지한다.
	environment.sky = ReflectionSky
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
