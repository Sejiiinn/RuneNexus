extends SceneTree

## Flutter 실제 맵 fixture로 공용 3D 타일·랜드마크·카메라·맵 교체를 검사한다.
## 실행: --script res://verify_chapter_one_stages.gd -- <frames.json>
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _point(index: int, columns: int, rows: int) -> Vector3:
	return Vector3(index % columns + 0.5 - columns / 2.0, 0.0, floori(float(index) / columns) + 0.5 - rows / 2.0)

func _check_dressing(scene: Node3D, frame: Dictionary, label: String) -> void:
	var dressing := scene.terrain.find_child("stage1_dressing", true, false) as Node3D
	_check(scene._using_dressing and dressing != null, label + " 맵 전용 환경 장식 누락")
	if dressing == null:
		return
	_check(dressing.global_transform.is_equal_approx(Transform3D.IDENTITY), label + " 환경 장식 원점·스케일 불일치")
	_check(dressing.find_children("*", "MeshInstance3D", true, false).size() == 2, label + " 풀·바위 2메시 병합 불일치")
	var foliage := dressing.find_child("stage1_dressing_foliage", true, false) as MeshInstance3D
	var rocks := dressing.find_child("stage1_dressing_rocks", true, false) as MeshInstance3D
	_check(foliage != null and rocks != null, label + " 풀·바위 모델 누락")
	if foliage == null or rocks == null:
		return
	_check(foliage.material_override == scene._foliage_material, label + " 공용 바람·점유 셰이더 누락")
	_check(foliage.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED, label + " 식생 양면 그림자 누락")
	_check(foliage.extra_cull_margin >= 0.022, label + " 바람 경계 여유 누락")
	for surface: Dictionary in foliage.mesh.get("_surfaces"):
		_check(surface.get("lods", []).is_empty(), label + " 잎 형태를 줄이는 자동 LOD 활성화")
	var tiles: Array = frame["map"]["tiles"]
	var build_points: Array[Vector3] = []
	for index in range(tiles.size()):
		if tiles[index] == "build":
			build_points.append(_point(index, scene.columns, scene.rows))
	_check(build_points.size() <= 32, label + " 건설칸 점유 마스크 범위 초과")
	var arrays := foliage.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var wind: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var removal: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	_check(wind.size() == vertices.size() and removal.size() == vertices.size(), label + " 바람·제거 UV 누락")
	if wind.size() != vertices.size() or removal.size() != vertices.size():
		return
	var removable := 0
	var permanent := 0
	for index in range(vertices.size()):
		_check(wind[index].x >= 0 and wind[index].x <= 1, label + " 바람 가중치 범위 오류")
		if removal[index].y > 0.5:
			removable += 1
			var slot := int(roundf(removal[index].x))
			_check(slot >= 0 and slot < build_points.size(), label + " 제거 슬롯 범위 오류")
			if slot >= 0 and slot < build_points.size() and is_zero_approx(wind[index].x):
				var offset := Vector3(scene.columns / 2.0, 0, scene.rows / 2.0)
				var ground := vertices[index] + offset
				var target := build_points[slot] + offset
				_check(Vector2(ground.x, ground.z).floor() == Vector2(target.x, target.z).floor(), label + " 중앙 식생 뿌리와 제거 슬롯의 타일 불일치")
		else:
			permanent += 1
	_check(removable > 0 and permanent > 0, label + " 중앙·외곽 식생 누락")
	var occupied_frame := frame.duplicate(true)
	for slot in range(build_points.size()):
		var point := build_points[slot]
		occupied_frame["turrets"] = [[901, point.x + scene.columns / 2.0, point.z + scene.rows / 2.0, 0, 0, 0, "cannon", 1]]
		scene._apply_frame(occupied_frame)
		var expected := Vector2i(1 << slot, 0) if slot < 16 else Vector2i(0, 1 << (slot - 16))
		_check(scene._foliage_material.get_shader_parameter("occupied_build_tiles") == expected, label + " 설치 타일의 중앙 식생 가림 오류")
	occupied_frame["turrets"] = []
	scene._apply_frame(occupied_frame)
	_check(scene._foliage_material.get_shader_parameter("occupied_build_tiles") == Vector2i.ZERO, label + " 철거 후 중앙 식생 가림 잔류")
	scene._apply_frame(frame)

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not FileAccess.file_exists(args[0]):
		push_error("스테이지 1~5 실제 프레임 JSON 경로가 필요합니다.")
		quit(1)
		return
	var frames = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not frames is Array or frames.size() != 5:
		push_error("스테이지 순서의 프레임 5개가 필요합니다.")
		quit(1)
		return
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var epoch := 1
	# Stage1 복귀까지 검사해 전용 환경·식생 상태가 다음 맵에 남지 않게 한다.
	for stage_index in [0, 1, 2, 3, 4, 1, 0]:
		var frame: Dictionary = frames[stage_index].duplicate(true)
		frame["sceneEpoch"] = epoch
		frame["seq"] = 0
		epoch += 1
		scene._apply_frame(frame)
		var label := "Stage %d" % (stage_index + 1)
		var map: Dictionary = frame["map"]
		var columns := int(map["columns"])
		var rows := int(map["rows"])
		var tiles: Array = map["tiles"]
		_check(scene._current_map == map, label + " 맵 수신 실패")
		_check(scene._using_authored == (stage_index == 0), label + " 전용 지형 선택 오류")
		_check_dressing(scene, frame, label)
		_check(scene._portals.size() == tiles.count("spawn"), label + " 포탈 수 오류")
		_check(scene._cores.size() == tiles.count("core"), label + " 코어 수 오류")
		var path: Array = frame["verificationPath"]
		for index in range(path.size()):
			var point := Vector2(float(path[index][0]), float(path[index][1]))
			var tile: String = tiles[floori(point.y) * columns + floori(point.x)]
			_check(tile in ["spawn", "path", "core"], label + " 경로가 건설·빈 타일을 통과함")
			if index == 0:
				_check(tile == "spawn", label + " 경로 시작 포탈 불일치")
			elif index == path.size() - 1:
				_check(tile == "core", label + " 경로 끝 코어 불일치")
			if index > 0:
				var previous := Vector2(float(path[index - 1][0]), float(path[index - 1][1]))
				_check(is_equal_approx(point.distance_to(previous), 1.0), label + " 경로 단절")
		_check(scene.enemies.size() == frame["enemies"].size(), label + " 적 모델 누락")
		_check(scene.turrets.size() == frame["turrets"].size(), label + " 포탑 모델 누락")
		for data: Array in frame["turrets"]:
			var point := Vector3(float(data[1]) - columns / 2.0, 0, float(data[2]) - rows / 2.0)
			_check(scene.turrets[int(data[0])]["root"].position.is_equal_approx(point), label + " 포탑 위치 오류")
		for index in range(tiles.size()):
			var point := _point(index, columns, rows)
			if tiles[index] == "spawn":
				_check(scene._portals.any(func(node: Node3D) -> bool: return node.position.is_equal_approx(point)), label + " 포탈 위치 오류")
			elif tiles[index] == "core":
				_check(scene._cores.any(func(core: Dictionary) -> bool: return core["root"].position.is_equal_approx(point)), label + " 코어 위치 오류")
			if stage_index == 0:
				continue
			var at_tile := 0
			for node: Node3D in scene.terrain.get_children():
				if node.find_child("stage1_dressing_foliage", true, false) != null:
					continue
				if node.position.is_equal_approx(point):
					at_tile += 1
			var expected := 0 if tiles[index] == "blocked" else (2 if tiles[index] in ["spawn", "core"] else 1)
			_check(at_tile == expected, label + " 타일 %d 배치 오류" % index)
		var terrain_id: int = scene.terrain.get_child(0).get_instance_id()
		frame["seq"] = 1
		scene._apply_frame(frame)
		_check(scene.terrain.get_child(0).get_instance_id() == terrain_id, label + " 동일 맵 재생성")
		for mode in ["angled", "drone"]:
			scene.options["camera"] = mode
			scene._apply_options()
			if scene.camera_transition:
				scene.camera_transition.pause()
				scene.camera_transition.custom_step(scene.CAMERA_TRANSITION_SECONDS)
			var camera: Camera3D = scene.camera
			_check(is_finite(camera.size) and camera.size > 0.0, label + " 카메라 배율 오류")
			var viewport := root.get_visible_rect().grow(0.01)
			for index in range(tiles.size()):
				if tiles[index] == "blocked":
					continue
				for corner in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5)]:
					var screen := camera.unproject_position(_point(index, columns, rows) + corner)
					_check(viewport.has_point(screen), label + " " + mode + " 전장 타일이 화면 밖으로 잘림")
			for index in range(8):
				var depth: float = -(camera.global_transform.affine_inverse() * scene._camera_envelope.get_endpoint(index)).z
				_check(depth >= camera.near - 0.001 and depth <= camera.far + 0.001, label + " " + mode + " 깊이 잘림")
		print("%s verified: %dx%d, %d terrain nodes, authored=%s" % [label, columns, rows, scene.terrain.get_child_count(), scene._using_authored])
	# 크기만 같은 다른 맵에는 원본 장식을 잘못 배치하지 않는다.
	var changed: Dictionary = frames[1].duplicate(true)
	changed["sceneEpoch"] = epoch
	var changed_tiles: Array = changed["map"]["tiles"]
	changed_tiles[changed_tiles.find("build")] = "blocked"
	changed["turrets"] = []
	scene._apply_frame(changed)
	_check(not scene._using_dressing, "다른 타일 배열에 환경 장식이 잘못 연결됨")
	_check(scene.terrain.find_child("stage1_dressing_foliage", true, false) == null, "불일치 맵에 이전 식생이 남음")
	_check(scene._build_tile_slots.is_empty(), "불일치 맵에 이전 점유 슬롯이 남음")
	scene.queue_free()
	await process_frame
	print("Chapter one stages verification: %d failures" % failures)
	quit(0 if failures == 0 else 1)
