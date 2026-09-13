extends SceneTree

## 실행: --script res://verify_chapter_two_stages.gd -- <chapter_two_frames.json> <chapter_one_frames.json>
## 실제 6~10 맵·균열 타일·경로 보존·장식 경계·맵 교체를 검사한다. 시각 수용은 별도다.
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _point(index: int, columns: int, rows: int) -> Vector3:
	return Vector3(index % columns + 0.5 - columns / 2.0, 0.0, floori(float(index) / columns) + 0.5 - rows / 2.0)

func _meshes(node: Node3D) -> Array:
	var result := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		result.push_front(node)
	return result

func _matches_template(instance: Node3D, source: Node3D) -> bool:
	var actual := _meshes(instance)
	var expected := _meshes(source)
	if actual.size() != expected.size() or actual.is_empty():
		return false
	for i in range(actual.size()):
		if actual[i].mesh != expected[i].mesh:
			return false
	return true

func _check_shared_materials(instance: Node3D, source: Node3D, label: String) -> void:
	var actual := _meshes(instance)
	var expected := _meshes(source)
	_check(_matches_template(instance, source), label + " 원본 메시를 공유하지 않음")
	if actual.size() != expected.size():
		return
	for i in range(actual.size()):
		for surface in range(actual[i].mesh.get_surface_count()):
			var material: Material = actual[i].get_active_material(surface)
			_check(material == expected[i].get_active_material(surface), label + " 인스턴스별 원본 재질 복제")
			_check(material is StandardMaterial3D, label + " 원본 native PBR 재질 누락")
			if material is StandardMaterial3D:
				_check(not material.refraction_enabled, label + " 승인 범위 밖 굴절 활성화")
				var colors = actual[i].mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				if colors != null and not colors.is_empty():
					_check(material.vertex_color_use_as_albedo, label + " 원본 정점색 미적용")

func _check_prop_vertex_colors(prop: Node3D, label: String) -> void:
	# Blender MATERIAL 모드가 흰 COLOR_0와 실제 색의 COLOR_1을 내보내는 회귀 방지.
	# 정점색이 필요한 석재·수정만 검사하며 단색 황동·룬 재질은 제외한다.
	for mesh: MeshInstance3D in _meshes(prop):
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			if material == null:
				continue
			var name := material.resource_name
			if not name.begins_with("ch2_weathered_slate") and not name.begins_with("ch2_crystal_"):
				continue
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var has_nonwhite := false
			if colors != null:
				for color: Color in colors:
					if minf(color.r, minf(color.g, color.b)) < 0.98:
						has_nonwhite = true
						break
			_check(has_nonwhite, label + " " + name + " COLOR_0 색이 누락되거나 전부 흰색임")

func _is_exterior_blocked(start: Vector2i, tiles: Array, columns: int, rows: int) -> bool:
	var pending: Array[Vector2i] = [start]
	var visited := {}
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell) or cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
			continue
		visited[cell] = true
		if tiles[cell.y * columns + cell.x] != "blocked":
			continue
		if cell.x == 0 or cell.y == 0 or cell.x == columns - 1 or cell.y == rows - 1:
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(cell + direction)
	return false

func _check_props(scene: Node3D, tiles: Array, label: String) -> void:
	var environment := scene.terrain.find_child("chapter_two_environment", true, false) as Node3D
	_check(environment != null, label + " 2장 장식 컨테이너 누락")
	if environment == null:
		return
	_check(environment.get_child_count() > 0 and environment.get_child_count() <= 4, label + " 장식 배치 수가 1~4 범위를 벗어남")
	var used := {}
	var counts := {"rune_pillar": 0, "crystal_cluster": 0, "void_fissure": 0}
	for prop: Node3D in environment.get_children():
		var cell = prop.get_meta("grid_cell", null)
		_check(cell is Vector2i and prop.has_meta("prop_kind"), label + " 장식 원본·타일 대응 정보 누락")
		if not cell is Vector2i:
			continue
		_check(cell.x >= 0 and cell.x < scene.columns and cell.y >= 0 and cell.y < scene.rows, label + " 장식 타일이 맵 밖에 있음")
		var index: int = cell.y * scene.columns + cell.x
		if index < 0 or index >= tiles.size():
			continue
		_check(tiles[index] == "blocked", label + " 장식이 이동·건설·포탈·코어 타일을 점유함")
		_check(_is_exterior_blocked(cell, tiles, scene.columns, scene.rows), label + " 소품 기준칸이 맵 외곽 blocked 영역과 연결되지 않음")
		for previous: Vector2i in used:
			_check(cell.distance_squared_to(previous) >= 9, label + " 소품 기준칸 사이 간격이 3칸보다 좁음")
		used[cell] = true
		_check(prop.scale.is_equal_approx(Vector3.ONE), label + " 장식 원본 스케일 변경")
		_check(is_equal_approx(prop.rotation.y / (PI / 2.0), roundf(prop.rotation.y / (PI / 2.0))), label + " 장식 회전이 직각 배치 계약과 다름")
		var kind := str(prop.get_meta("prop_kind", ""))
		_check(kind in counts, label + " 승인된 장식 3종 이외 모델 사용")
		if counts.has(kind):
			counts[kind] += 1
			_check(counts[kind] <= (2 if kind == "crystal_cluster" else 1), label + " 기둥1·수정2·균열1 배치 상한 초과")
		var template: Node3D = scene._chapter_two_props_library.find_child(kind, true, false)
		_check(template != null, label + " 장식 제작 원본 누락")
		if template != null:
			_check_shared_materials(prop, template, label + " " + kind)
		_check_prop_vertex_colors(prop, label + " " + kind)
		var meshes := _meshes(prop)
		_check(not meshes.is_empty(), label + " 장식 메시 누락")
		if meshes.is_empty():
			continue
		var inverse: Transform3D = scene.world.global_transform.affine_inverse()
		var bounds: AABB = inverse * meshes[0].global_transform * meshes[0].get_aabb()
		for mesh: MeshInstance3D in meshes:
			bounds = bounds.merge(inverse * mesh.global_transform * mesh.get_aabb())
		var origin: Vector3 = inverse * prop.global_position
		var anchor := _point(index, scene.columns, scene.rows)
		_check(absf(origin.x - anchor.x) <= 0.281 and absf(origin.z - anchor.z) <= 0.281, label + " 외곽 이동량이 축별 0.28타일을 초과함")
		_check(bounds.position.x >= origin.x - 0.701 and bounds.end.x <= origin.x + 0.701 and bounds.position.z >= origin.z - 0.701 and bounds.end.z <= origin.z + 0.701, label + " 부유 암반 원본 폭이 루트 기준 1.4타일을 초과함")
		_check(bounds.position.y < -0.55, label + " 소품 아래 두꺼운 부유 암반이 누락됨")
		_check(bounds.position.x >= -scene.columns / 2.0 - 0.451 and bounds.end.x <= scene.columns / 2.0 + 0.451 and bounds.position.z >= -scene.rows / 2.0 - 0.451 and bounds.end.z <= scene.rows / 2.0 + 0.451, label + " 부유 암반이 맵 외곽 0.45타일을 초과함")
		var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		# 기준칸을 넘는 암반도 허용하되 실제 전체 AABB가 모든 플레이 타일과 떨어져야 한다.
		var nearest_playable_distance := INF
		for tile_index in range(tiles.size()):
			if tiles[tile_index] == "blocked":
				continue
			var center := _point(tile_index, scene.columns, scene.rows)
			var playable := Rect2(Vector2(center.x - 0.5, center.z - 0.5), Vector2.ONE)
			var gap := Vector2(
				maxf(0.0, maxf(playable.position.x - footprint.end.x, footprint.position.x - playable.end.x)),
				maxf(0.0, maxf(playable.position.y - footprint.end.y, footprint.position.y - playable.end.y))
			)
			nearest_playable_distance = minf(nearest_playable_distance, gap.length())
			_check(not footprint.intersects(playable.grow(0.0399)), label + " 부유 암반이 플레이 타일 %d를 침범하거나 0.04 간격을 잃음" % tile_index)
		_check(nearest_playable_distance >= 0.0399 and nearest_playable_distance <= 0.05, label + " " + kind + " 부유 암반과 최근접 플레이 타일 간격 %.6f가 0.0399~0.05 범위를 벗어남" % nearest_playable_distance)
	print("%s props: total=%d, rune_pillar=%d, crystal_cluster=%d, void_fissure=%d" % [label, environment.get_child_count(), counts["rune_pillar"], counts["crystal_cluster"], counts["void_fissure"]])

func _check_stage(scene: Node3D, frame: Dictionary, label: String) -> void:
	var map: Dictionary = frame["map"]
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	_check(scene._current_map == map and scene.columns == columns and scene.rows == rows, label + " 실제 맵 전달 실패")
	_check(not scene._using_authored and not scene._using_dressing, label + " 1장 전용 지형·식생을 잘못 사용함")
	_check(scene.terrain.find_child("stage1_environment", true, false) == null and scene.terrain.find_child("stage1_dressing_foliage", true, false) == null, label + " 이전 1장 지형·식생 잔류")
	_check(scene._portals.size() == tiles.count("spawn") and scene._cores.size() == tiles.count("core"), label + " 실제 포탈·코어 수 불일치")
	var path: Array = frame["verificationPath"]
	for i in range(path.size()):
		var p := Vector2(float(path[i][0]), float(path[i][1]))
		var tile: String = tiles[floori(p.y) * columns + floori(p.x)]
		_check(tile in ["spawn", "path", "core"], label + " 경로가 이동 불가능 타일을 통과함")
		if i == 0:
			_check(tile == "spawn", label + " 경로 시작 포탈 변경")
		elif i == path.size() - 1:
			_check(tile == "core", label + " 경로 끝 코어 변경")
		if i > 0:
			var previous := Vector2(float(path[i - 1][0]), float(path[i - 1][1]))
			_check(is_equal_approx(p.distance_to(previous), 1.0), label + " 기존 경로 단절")
	for index in range(tiles.size()):
		var p := _point(index, columns, rows)
		var at_tile: Array[Node3D] = []
		for node: Node3D in scene.terrain.get_children():
			if node.name == "chapter_two_environment":
				continue
			if node.position.is_equal_approx(p):
				at_tile.append(node)
		var expected := 0 if tiles[index] == "blocked" else (2 if tiles[index] in ["spawn", "core"] else 1)
		_check(at_tile.size() == expected, label + " 타일 %d 배치 수 불일치" % index)
		if tiles[index] == "spawn":
			_check(scene._portals.any(func(node: Node3D) -> bool: return node.position.is_equal_approx(p)), label + " 포탈 위치 변경")
		elif tiles[index] == "core":
			_check(scene._cores.any(func(core: Dictionary) -> bool: return core["root"].position.is_equal_approx(p)), label + " 코어 위치 변경")
		if tiles[index] != "blocked":
			var source_name := "build_tile" if tiles[index] == "build" else "path_tile"
			var template: Node3D = scene._chapter_two_terrain_library.find_child(source_name, true, false)
			var matches := at_tile.filter(func(node: Node3D) -> bool: return _matches_template(node, template))
			_check(matches.size() == 1, label + " 2장 타일 종류·포탈/코어 받침 불일치")
			if matches.size() == 1:
				var instance: Node3D = matches[0]
				_check(instance.scale.is_equal_approx(Vector3.ONE), label + " 단위 타일 원본 스케일 변경")
				_check(is_equal_approx(instance.rotation.y / (PI / 2.0), roundf(instance.rotation.y / (PI / 2.0))), label + " 단위 타일 회전이 직각을 벗어남")
				_check_shared_materials(instance, template, label + " " + source_name)
	_check(scene.turrets.size() == frame["turrets"].size(), label + " 포탑 누락")
	for turret: Array in frame["turrets"]:
		var p := Vector3(float(turret[1]) - columns / 2.0, 0, float(turret[2]) - rows / 2.0)
		_check(scene.turrets[int(turret[0])]["root"].position.is_equal_approx(p), label + " 건설 위치 변경")
	_check(scene.enemies.size() == frame["enemies"].size(), label + " 2장 적 모델 누락")
	for enemy: Array in frame["enemies"]:
		var id := int(enemy[0])
		if scene.enemies.has(id):
			_check(scene.enemies[id]["type"] == str(enemy[7]), label + " 적 표시 타입·실드 정보 계약 변경")
	_check_props(scene, tiles, label)
	var first_id: int = scene.terrain.get_child(0).get_instance_id()
	frame["seq"] = 1
	scene._apply_frame(frame)
	_check(scene.terrain.get_child(0).get_instance_id() == first_id, label + " 동일 맵을 매 프레임 재생성함")
	for mode in ["angled", "drone"]:
		scene.options["camera"] = mode
		scene._apply_options()
		if scene.camera_transition:
			scene.camera_transition.pause()
			scene.camera_transition.custom_step(scene.CAMERA_TRANSITION_SECONDS)
		var camera: Camera3D = scene.camera
		var viewport := root.get_visible_rect().grow(0.01)
		for index in range(tiles.size()):
			if tiles[index] == "blocked":
				continue
			for corner in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5)]:
				_check(viewport.has_point(camera.unproject_position(_point(index, columns, rows) + corner)), label + " " + mode + " 전장 타일이 화면 밖으로 잘림")
		for i in range(8):
			var depth: float = -(camera.global_transform.affine_inverse() * scene._camera_envelope.get_endpoint(i)).z
			_check(depth >= camera.near - 0.001 and depth <= camera.far + 0.001, label + " " + mode + " 깊이 잘림")
	var presentation: Dictionary = scene.presentation()
	_check(int(presentation.get("sequence", -1)) == 1 and int(presentation.get("sceneEpoch", -1)) == int(frame["sceneEpoch"]), label + " 최신 전장 적용 응답 누락")

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not FileAccess.file_exists(args[0]) or not FileAccess.file_exists(args[1]):
		push_error("2장·1장 실제 맵 fixture 두 경로가 필요합니다.")
		quit(1)
		return
	var frames = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var chapter_one = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not frames is Array or frames.size() != 5 or not chapter_one is Array or chapter_one.size() != 5:
		push_error("각 장의 실제 프레임 5개가 필요합니다.")
		quit(1)
		return
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var epoch := 1
	for index in [0, 1, 2, 3, 4, 0]:
		var frame: Dictionary = frames[index].duplicate(true)
		frame["sceneEpoch"] = epoch
		frame["seq"] = 0
		epoch += 1
		_check(frame["map"].get("theme") == "chapterTwoRift", "2장 균열 테마 직렬화 누락")
		scene._apply_frame(frame)
		_check_stage(scene, frame, "Stage %d" % (index + 6))
		print("Stage %d rift verified: %dx%d" % [index + 6, scene.columns, scene.rows])
	var restored: Dictionary = chapter_one[0].duplicate(true)
	restored["sceneEpoch"] = epoch
	restored["seq"] = 0
	scene._apply_frame(restored)
	_check(scene._using_authored and scene._using_dressing, "2장 방문 후 1장 전용 지형·식생 복원 실패")
	_check(scene.terrain.find_child("chapter_two_environment", true, false) == null, "1장 복귀 후 균열 장식 잔류")
	# 테마가 없는 기존 frame은 같은 1장 지형으로 처리한다.
	restored["map"].erase("theme")
	restored["sceneEpoch"] = epoch + 1
	scene._apply_frame(restored)
	_check(scene._using_authored and scene._using_dressing, "기존 theme 없는 1장 입력 호환성 파괴")
	scene.queue_free()
	await process_frame
	print("Chapter two stages verification: %d failures" % failures)
	quit(0 if failures == 0 else 1)
