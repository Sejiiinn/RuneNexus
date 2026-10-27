extends "res://environment/battlefield_environment_state.gd"
## Stage manifests, resource lists and loading/releasing each chapter library.

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
		paths.append_array(["res://assets/environment/chapter3_tiles.glb", "res://assets/environment/chapter3_props.glb", ChapterThreeDebris.MODEL_PATH])
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
		_free_library("_chapter_three_debris_library")
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
			"_chapter_three_debris_library", "_environment_geology_library", "_environment_props_library"]:
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

func _prepare_chapter_three_debris() -> bool:
	if is_instance_valid(_chapter_three_debris_library):
		return true
	var packed := _load_scene(ChapterThreeDebris.MODEL_PATH)
	if packed == null:
		_fail("챕터 3 부유 철골 GLB를 불러오지 못했습니다.")
		return false
	_chapter_three_debris_library = packed.instantiate()
	for kind in ChapterThreeDebris.ALL_KINDS:
		if not _chapter_three_debris_library.find_child(kind, true, false) is MeshInstance3D:
			_fail("챕터 3 부유 철골 GLB 노드 누락: " + kind)
			_chapter_three_debris_library.free()
			_chapter_three_debris_library = null
			return false
	for mesh: MeshInstance3D in _chapter_three_debris_library.find_children("*", "MeshInstance3D", true, false):
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
