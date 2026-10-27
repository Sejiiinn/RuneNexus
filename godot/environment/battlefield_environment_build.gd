extends "res://environment/battlefield_environment_libraries.gd"
## Lighting and terrain assembly for a map: tiles, paving, props and teleport devices.

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
	if chapter_three and (not _prepare_chapter_three() or not _prepare_chapter_three_props() or not _prepare_chapter_three_debris()):
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
	if chapter_three:
		_floating_debris = ChapterThreeDebris.populate(terrain, _chapter_three_debris_library, map)
		if _floating_debris.size() < ChapterThreeDebris.MIN_COUNT:
			_fail("챕터 3 부유 철골의 안전한 배치를 확인하지 못했습니다.")
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
