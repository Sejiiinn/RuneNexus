extends SceneTree

const SaveJson = preload("res://app/save_json.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _check_props(scene: Node3D, map: Dictionary) -> void:
	var library: Node3D = scene._chapter_three_props_library
	var entries: Array = scene.ChapterThreeProps.layout(library, map)
	_check(entries == scene.ChapterThreeProps.layout(library, map.duplicate(true)), "외곽 소품 배치 불안정")
	var group: Node3D = scene.terrain.get_node("chapter_three_props")
	var target: int = scene.ChapterThreeProps.target_count(map)
	_check(group.get_child_count() == entries.size() and entries.size() == target, "외곽 소품 배치 수 오류: %d/%d" % [entries.size(), target])
	var vents := {}
	for panel: Dictionary in scene.ChapterThreeTiles.panel_layout(map):
		if panel["kind"] == "panel_vent":
			vents[int(panel["index"]) * 4 + int(panel["side"])] = true
	var counts := {}
	var visible_kinds := {}
	for entry: Dictionary in entries:
		var kind: String = entry["kind"]
		counts[kind] = int(counts.get(kind, 0)) + 1
		if entry["side"] in [0, 1]:
			visible_kinds[kind] = true
		_check(not vents.has(int(entry["index"]) * 4 + int(entry["side"])), "기존 환기 패널 가림")
		_check(scene.ChapterThreeProps.clear_of_play(entry["bounds"], map), "소품이 플레이 영역 침범")
		print("Forge prop: %s cell=%s side=%d origin=%s" % [kind, entry["cell"], entry["side"], entry["pose"].origin])
	_check(entries.any(func(entry: Dictionary) -> bool: return entry["kind"] == "exhaust_vent" and entry["side"] == 0), "배기구 전면 방향 누락")
	_check(visible_kinds.size() == 3, "기본 시점에서 보이는 소품 종류 누락")
	# 소품 종류는 번갈아 배치해 한 종류만 반복되지 않게 한다.
	for kind in scene.ChapterThreeProps.KINDS:
		_check(absi(int(counts.get(kind, 0)) - ceili(entries.size() / 3.0)) <= 1 and counts.get(kind, 0) >= 1, "소품별 배치 수 변경: " + kind)
	var teleports: Array[Vector2i] = []
	for pair: Dictionary in map.get("teleportPairs", []):
		for role in ["entrance", "exit"]:
			teleports.append(Vector2i(int(pair[role][0]), int(pair[role][1])))
	for slot in range(scene.ChapterThreeProps.BASE_COUNT, entries.size()):
		var cell: Vector2i = entries[slot]["cell"]
		_check(not teleports.any(func(point: Vector2i) -> bool: return point.distance_squared_to(cell) <= 2), "추가 소품이 전송 장치를 가림")
	for first in range(entries.size()):
		for second in range(first + 1, entries.size()):
			_check(not scene.ChapterThreeProps.footprint(entries[first]["bounds"]).intersects(scene.ChapterThreeProps.footprint(entries[second]["bounds"])), "소품끼리 겹침")
	for instance: Node3D in group.get_children():
		var kind: String = instance.get_meta("prop_kind")
		var source: Node3D = library.find_child(kind, true, false)
		var bounds: AABB = scene.ChapterThreeProps.mesh_bounds(source)
		_check(bounds.position.z >= -.001, "벽체 장식이 타일 안쪽을 침범")
		_check(bounds.position.z <= .006, "장식의 벽 체결면이 외벽에서 분리됨")
		_check(bounds.position.y >= -.505, "장식이 타일 기단 아래로 돌출")
		if kind == "exhaust_vent":
			_check(absf(bounds.position.y + .5) < .006, "배기구 하우징이 기단까지 이어지지 않음")
			_check(bounds.end.y <= .31, "배기구 굴뚝이 승인 높이보다 과하게 솟음")
		_check(instance.scale.is_equal_approx(Vector3.ONE), "소품 원본 스케일 변경")
		_check(instance is MeshInstance3D and source is MeshInstance3D, "소품 병합 메시 누락")
		if instance is MeshInstance3D and source is MeshInstance3D:
			_check(instance.mesh == source.mesh, "소품 원본 메시 미공유")
			for surface in range(instance.mesh.get_surface_count()):
				var material: Material = instance.get_active_material(surface)
				_check(material is StandardMaterial3D and material == source.get_active_material(surface), "소품 native PBR 원본 미공유")

func _check_debris(scene: Node3D, map: Dictionary) -> void:
	var Debris = scene._environment.ChapterThreeDebris
	var library: Node3D = scene._environment._chapter_three_debris_library
	var group: Node3D = scene.terrain.get_node("chapter_three_debris")
	var avoid: Array[Rect2] = []
	for prop: Node3D in scene.terrain.get_node("chapter_three_props").get_children():
		avoid.append(scene.ChapterThreeProps.footprint(scene.ChapterThreeProps.mesh_bounds(prop)))
	var entries: Array = Debris.layout(library, map, avoid)
	_check(entries == Debris.layout(library, map.duplicate(true), avoid), "부유 철골 배치 불안정")
	_check(entries.size() == Debris.target_count(map) and group.get_child_count() == entries.size(), "부유 철골 배치 수 오류: %d/%d" % [entries.size(), Debris.target_count(map)])
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var kinds := {}
	for slot in range(entries.size()):
		var entry: Dictionary = entries[slot]
		kinds[entry["kind"]] = true
		var area: Rect2 = scene.ChapterThreeProps.footprint(entry["bounds"])
		for index in range(map["tiles"].size()):
			if map["tiles"][index] != "blocked":
				var tile := Rect2(Vector2(index % columns - columns / 2.0, floori(float(index) / columns) - rows / 2.0), Vector2.ONE)
				_check(not tile.grow(.1).intersects(area), "부유 철골이 플레이 칸에 닿음: %s" % entry["cell"])
		for rect in avoid:
			_check(not rect.intersects(area), "부유 철골이 벽 소품과 겹침")
		for other in range(slot + 1, entries.size()):
			_check(not area.intersects(scene.ChapterThreeProps.footprint(entries[other]["bounds"])), "부유 철골끼리 겹침")
		var instance := group.get_child(slot) as MeshInstance3D
		var source := library.find_child(entry["kind"], true, false) as MeshInstance3D
		_check(instance != null and source != null and instance.mesh == source.mesh, "부유 철골 원본 메시 미공유")
		if instance != null and source != null:
			for surface in range(instance.mesh.get_surface_count()):
				_check(instance.get_active_material(surface) is StandardMaterial3D and instance.get_active_material(surface) == source.get_active_material(surface), "부유 철골 native PBR 원본 미공유")
	_check(kinds.size() == mini(3, entries.size()), "부유 철골 종류 누락")
	# 같은 전투 시간은 같은 자세, 부유 높이는 제한 범위 안.
	var floating: Array[Dictionary] = scene._environment._floating_debris
	_check(floating.size() == entries.size(), "부유 철골 움직임 대상 누락")
	for time: float in [0.0, 7.3, 31.9]:
		Debris.animate(floating, time)
		var first: Array[Transform3D] = []
		for item in floating:
			first.append((item["node"] as Node3D).transform)
			var rest: Transform3D = item["rest"]
			_check(absf((item["node"] as Node3D).position.y - rest.origin.y) <= Debris.BOB_HEIGHT + .0001, "부유 높이 범위 초과")
		Debris.animate(floating, time)
		for index in range(floating.size()):
			_check((floating[index]["node"] as Node3D).transform.is_equal_approx(first[index]), "부유 자세가 전투 시간에 결정되지 않음")
	print("Forge debris: %d girders %s" % [entries.size(), entries.map(func(entry: Dictionary) -> String: return "%s@%s" % [entry["kind"], entry["cell"]])])

func _projected_active_bounds(scene: Node3D, map: Dictionary) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var tiles: Array = map["tiles"]
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
			var point := Vector3(index % columns + corner.x - columns / 2.0, 0, floori(float(index) / columns) + corner.y - rows / 2.0)
			var projected: Vector2 = scene.camera.unproject_position(scene.world.to_global(point))
			low = low.min(projected)
			high = high.max(projected)
	return Rect2(low, high - low)

func _check_flutter_camera(scene: Node3D, frame: Dictionary, stage: int) -> void:
	var map: Dictionary = frame["map"]
	var columns := int(map["columns"])
	var rows := int(map["rows"])
	var occupied := Rect2()
	var initialized := false
	for index in range(map["tiles"].size()):
		if map["tiles"][index] == "blocked":
			continue
		var tile := Rect2(Vector2(index % columns, floori(float(index) / columns)), Vector2.ONE)
		occupied = occupied.merge(tile) if initialized else tile
		initialized = true
	var viewport := Vector2(393, 852)
	var grid_offset := occupied.get_center() - Vector2(columns, rows) / 2.0
	var input := frame.duplicate(true)
	input["viewport"] = [viewport.x, viewport.y]
	input["pixelsPerTile"] = 44.0
	var sequence := int(frame["seq"]) + 1
	for zoom: float in [1.0, 1.25]:
		input["zoom"] = zoom
		var flutter_center := viewport / 2.0 - grid_offset * 44.0 * zoom
		var neutral := Vector2.ZERO
		for pan: Vector2 in [Vector2.ZERO, Vector2(17, -11)]:
			input["screenCenter"] = [flutter_center.x + pan.x, flutter_center.y + pan.y]
			input["seq"] = sequence
			sequence += 1
			scene.apply_frame(input)
			var projected := _projected_active_bounds(scene, map)
			var actual := projected.get_center()
			_check(actual.distance_to(viewport / 2.0 + pan) < .05, "Stage%d 활성 전장 중심 이탈: %s" % [stage, actual])
			if pan == Vector2.ZERO:
				neutral = actual
			else:
				_check((actual - neutral).distance_to(pan) < .05, "Stage%d Flutter 팬 이동량 변경" % stage)
	print("Stage%d Flutter camera: centered x=196.5; zoom 1/1.25 and pan (17,-11) checked" % stage)

func _teleport_jump(map: Dictionary, from: Vector2, to: Vector2) -> bool:
	for pair: Dictionary in map.get("teleportPairs", []):
		if from == Vector2(pair.entrance[0], pair.entrance[1]) + Vector2(0.5, 0.5) and to == Vector2(pair.exit[0], pair.exit[1]) + Vector2(0.5, 0.5):
			return true
	return false

func _check_stage(scene: Node3D, frame: Dictionary, stage: int) -> void:
	scene.apply_frame(frame)
	_check(scene._current_map == frame["map"], "대장간 프레임 적용 실패")
	if scene._current_map != frame["map"]:
		return
	_check(scene._using_forge and is_equal_approx(scene.sun.light_energy, 1.35), "용광로 조명 미적용")
	_check(scene._world_environment.sky == load(scene.ForgeReflectionSky), "용광로 반사 환경 미적용")
	var columns: int = frame["map"]["columns"]
	var rows: int = frame["map"]["rows"]
	_check(scene.columns == columns and scene.rows == rows, "맵 크기 변경")
	_check(not scene._using_authored and not scene._using_dressing and not scene._using_chapter_environment, "기존 장 환경 침범")
	var tiles: Array = frame["map"]["tiles"]
	var grate_count := 0
	var tile_count := 0
	var plain_count := 0
	var ring_count := 0
	# Teleport endpoints carry a device and a host tile whose copied mesh has the opening cut.
	var endpoints := {}
	for pair: Dictionary in frame["map"].get("teleportPairs", []):
		for role in ["entrance", "exit"]:
			endpoints[int(pair[role][1]) * columns + int(pair[role][0])] = true
	for index in range(tiles.size()):
		var point := Vector3(index % columns + .5 - columns / 2.0, 0, floori(float(index) / columns) + .5 - rows / 2.0)
		var at_tile: Array[Node3D] = []
		for node: Node3D in scene.terrain.get_children():
			if node.name in ["chapter_three_panels", "chapter_three_props", "chapter_three_debris"] or node.name.begins_with("Teleport_"):
				continue
			if node.position.is_equal_approx(point):
				at_tile.append(node)
		var expected := 0 if tiles[index] == "blocked" else (2 if tiles[index] in ["spawn", "core"] else 1)
		_check(at_tile.size() == expected, "원래 칸 배치 수 변경: %d" % index)
		for node in at_tile:
			if node in scene._portals or scene._cores.any(func(core: Dictionary) -> bool: return core["root"] == node):
				continue
			tile_count += 1
			var kind := str(node.get_meta("tile_variant", "path_tile"))
			_check(kind in ["path_tile", "grate_tile", "build_tile", "plain_build_tile"], "승인 외 타일")
			_check((kind in ["build_tile", "plain_build_tile"]) == (tiles[index] == "build"), "건설칸 변경")
			if kind == "plain_build_tile":
				plain_count += 1
			elif kind == "build_tile":
				ring_count += 1
			if kind == "grate_tile":
				grate_count += 1
				_check(tiles[index] == "path", "포탈·코어 그레이팅 사용")
			_check(node.scale.is_equal_approx(Vector3.ONE), "원본 크기 변경")
			var source: Node3D = scene._chapter_three_terrain_library.find_child(kind, true, false)
			var actual := node.find_children("*", "MeshInstance3D", true, false)
			var original := source.find_children("*", "MeshInstance3D", true, false)
			if node is MeshInstance3D:
				actual.push_front(node)
			if source is MeshInstance3D:
				original.push_front(source)
			_check(actual.size() == original.size() and not actual.is_empty(), "원본 메시 누락")
			if endpoints.has(index):
				continue
			for mesh_index in range(mini(actual.size(), original.size())):
				_check(actual[mesh_index].mesh == original[mesh_index].mesh, "원본 메시 미공유")
				for surface in range(actual[mesh_index].mesh.get_surface_count()):
					var material = actual[mesh_index].get_active_material(surface)
					_check(material is StandardMaterial3D and material == original[mesh_index].get_active_material(surface), "native PBR 원본 미공유")
	var panels: Node3D = scene.terrain.get_node("chapter_three_panels")
	var slots := {}
	var vent_count := 0
	var vent_categories := {}
	var variants: Dictionary = scene.ChapterThreeTiles.variants(frame["map"])
	_check(scene.ChapterThreeTiles.panel_layout(frame["map"]) == scene.ChapterThreeTiles.panel_layout(frame["map"].duplicate(true)), "동일 맵의 무작위 패널 배치 불안정")
	for batch: MultiMeshInstance3D in panels.get_children():
		var entries: Array = batch.get_meta("panel_entries")
		_check(batch.multimesh.instance_count == entries.size(), "패널 인스턴스 누락")
		var source: MeshInstance3D = scene._chapter_three_terrain_library.find_child(str(batch.name), true, false)
		_check(batch.multimesh.mesh == source.mesh, "패널 원본 메시 미공유")
		for slot in range(entries.size()):
			var entry: Dictionary = entries[slot]
			var key := int(entry["index"]) * 4 + int(entry["side"])
			_check(not slots.has(key), "패널 중복 겹침")
			slots[key] = true
			var transform := batch.multimesh.get_instance_transform(slot)
			var index: int = entry["index"]
			var expected_origin := Vector3(index % columns + .5 - columns / 2.0, 0, floori(float(index) / columns) + .5 - rows / 2.0)
			_check(transform.origin.is_equal_approx(expected_origin), "패널 타일 원점 불일치")
			_check(transform.basis.is_equal_approx(Basis(Vector3.UP, float(entry["side"]) * PI / 2.0)), "패널 측면 회전 오류")
			if entry["kind"] == "panel_vent":
				vent_count += 1
				vent_categories[variants[index] if tiles[index] == "build" else "path"] = true
				_check(scene.ChapterThreeTiles.exposed(frame["map"], index, entry["side"]), "안쪽 면 환기구 배치")
	_check(slots.size() == scene.ChapterThreeTiles.panel_layout(frame["map"]).size(), "노출·개방 타일 패널 누락")
	_check(vent_categories.has("build_tile") and vent_categories.has("plain_build_tile") and vent_categories.has("path"), "포탑 설치 타일 또는 길의 환기구 누락")
	_check(vent_count == maxi(1, floori(float(tile_count) / 10.0)), "외곽 소수 환기구 배치 오류")
	_check(plain_count > 0 and ring_count > 0 and plain_count + ring_count == tiles.count("build"), "두 건설 타일 혼합 배치 오류")
	_check(grate_count > 0 and grate_count < tiles.count("path") / 2, "그레이팅 비율 오류")
	_check(tile_count == tiles.size() - tiles.count("blocked"), "타일 총수 변경")
	_check(scene._portals.size() == tiles.count("spawn") and scene._cores.size() == tiles.count("core"), "포탈·코어 누락")
	_check(scene.turrets.size() == frame["turrets"].size() and scene.enemies.size() == frame["enemies"].size(), "공용 전투 표시 누락")
	_check_props(scene, frame["map"])
	_check_debris(scene, frame["map"])
	var props_id: int = scene.terrain.get_node("chapter_three_props").get_instance_id()
	var debris_id: int = scene.terrain.get_node("chapter_three_debris").get_instance_id()
	var first_id: int = scene.terrain.get_child(0).get_instance_id()
	frame["seq"] = 1
	scene.apply_frame(frame)
	_check(scene.terrain.get_child(0).get_instance_id() == first_id, "동일 맵 재생성")
	_check(scene.terrain.get_node("chapter_three_props").get_instance_id() == props_id, "동일 맵 소품 재생성")
	_check(scene.terrain.get_node("chapter_three_debris").get_instance_id() == debris_id, "동일 맵 부유 철골 재생성")
	var path: Array = frame["verificationPath"]
	for step in range(path.size()):
		var point := Vector2(float(path[step][0]), float(path[step][1]))
		var kind: String = tiles[floori(point.y) * columns + floori(point.x)]
		_check(kind in ["spawn", "path", "core"], "원래 이동 경로 차단")
		if step == 0:
			_check(kind == "spawn", "원래 경로 시작점 변경")
		elif step == path.size() - 1:
			_check(kind == "core", "원래 경로 끝점 변경")
		if step > 0:
			var previous := Vector2(float(path[step - 1][0]), float(path[step - 1][1]))
			_check(is_equal_approx(point.distance_to(previous), 1.0) or _teleport_jump(frame["map"], previous, point), "원래 이동 경로 단절")
	_check_flutter_camera(scene, frame, stage)
	print("Chapter three stage%d: %dx%d, %d tiles, %d grates, %d vents, %d props, %d failures" % [stage, columns, rows, tile_count, grate_count, vent_count, scene.terrain.get_node("chapter_three_props").get_child_count(), failures])

func _verify() -> void:
	# MultiMesh transform getter 검사는 실제 렌더러가 필요하다. 화면 캡처는 생성하지 않는다.
	if DisplayServer.get_name() == "headless":
		push_error("패널 인스턴스 검사는 --headless 없이 실행해야 합니다.")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not FileAccess.file_exists(args[0]):
		push_error("3장 실제 맵 프레임 JSON 경로가 필요합니다.")
		quit(1)
		return
	# Typed parse keeps integer map and teleport coordinates, as ContentCatalog does.
	var frames: Array = SaveJson.parse(FileAccess.get_file_as_string(args[0]))
	var scene: Node3D = load("res://main.tscn").instantiate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(393, 852)
	root.add_child(viewport)
	viewport.add_child(scene)
	await process_frame
	scene.set_process(false)
	var epoch := 1
	for index in range(frames.size()):
		var frame: Dictionary = frames[index].duplicate(true)
		frame["sceneEpoch"] = epoch
		epoch += 1
		_check_stage(scene, frame, int(frame.get("stage", index + 11)))
	for chapter in ["chapter_one_frames.json", "chapter_two_frames.json"]:
		var other: Dictionary = SaveJson.parse(FileAccess.get_file_as_string(args[0].get_base_dir().path_join(chapter)))[0]
		other["sceneEpoch"] = epoch
		epoch += 1
		scene.apply_frame(other)
		_check(scene.terrain.find_child("chapter_three_props", true, false) == null, "다른 장에 용광로 소품 잔류")
		_check(scene.terrain.find_child("chapter_three_debris", true, false) == null and scene._environment._floating_debris.is_empty(), "다른 장에 부유 철골 잔류")
		_check(scene._current_map == other["map"], "다른 장 전환 실패")
		var chapter_light := 1.20 if scene._environment._using_chapter_environment else 1.50
		_check(scene._world_environment.sky == load(scene.ReflectionSky) and is_equal_approx(scene.sun.light_energy, chapter_light), "장 전환 후 공용 조명 복원 실패")
	var restored: Dictionary = frames[0].duplicate(true)
	restored["sceneEpoch"] = epoch
	_check_stage(scene, restored, int(restored.get("stage", 11)))
	# Lobby/restart clears presentation only; the next applied map sets its own lighting.
	scene._clear_scene()
	_check(not scene._using_forge, "장 전환 후 용광로 상태 잔류")
	viewport.queue_free()
	await process_frame
	print("Chapter three verification: %d failures" % failures)
	quit(0 if failures == 0 else 1)
