extends SceneTree

## --script res://verify_chapter_two_paving.gd -- <chapter_two_frames.json>
## 실제 6~10 맵의 모든 받침, 원래 회전·좌표, 방향별 열린 측면, 공유 메시와 맵 교체 검사.
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _check_stage(scene: Node3D, frame: Dictionary) -> Array:
	var tiles: Array = frame["map"]["tiles"]
	var columns: int = scene.columns
	var rows: int = scene.rows
	var seen := {}
	var batches := []
	_check(scene._using_chapter_environment, "실제 6~10 환경 원본이 선택되지 않음")
	for node: Node in scene.terrain.get_children():
		if not node is MultiMeshInstance3D or not node.has_meta("tile_indices"):
			continue
		batches.append(weakref(node))
		var indices: Array = node.get_meta("tile_indices")
		var kind := str(node.get_meta("tile_type"))
		var mask := int(node.get_meta("neighbor_mask"))
		var instances: MultiMesh = node.multimesh
		_check(indices.size() == instances.instance_count, "배치 인스턴스·타일 대응 수 불일치")
		_check(instances.mesh.get_surface_count() == 2, "타일 윗면·측면 재질 surface 누락")
		_check(node.layers == (1 | scene.REFLECTION_TERRAIN_LAYER), "반사 레이어 누락")
		_check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "타일 그림자 누락")
		var source: Node3D = scene._chapter_two_paving_library.find_child("%s_tile_mask_%d" % [kind, mask], true, false)
		_check(source != null and source.get_child(0).mesh == instances.mesh, "배치별 원본 mesh 공유 실패")
		for surface in range(instances.mesh.get_surface_count()):
			var material := instances.mesh.surface_get_material(surface) as StandardMaterial3D
			_check(material != null, "MultiMesh surface 재질 연결 누락")
			if material:
				_check(not material.refraction_enabled and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "불투명 PBR 계약 변경")
		for slot in range(indices.size()):
			var index := int(indices[slot])
			_check(not seen.has(index), "동일 타일 받침 중복")
			seen[index] = true
			_check(index >= 0 and index < tiles.size(), "잘못된 타일 index")
			if index < 0 or index >= tiles.size(): continue
			_check(tiles[index] != "blocked", "blocked 칸을 타일로 채움")
			_check(kind == ("build" if tiles[index] == "build" else "path"), "포탈/코어 받침 포함 타일 종류 오류")
			var pose := instances.get_instance_transform(slot)
			var cell := Vector2i(index % columns, floori(float(index) / columns))
			var position := Vector3(cell.x + 0.5 - columns / 2.0, 0, cell.y + 0.5 - rows / 2.0)
			var basis := Basis.from_euler(Vector3(0, float(index % 4) * PI / 2.0, 0))
			_check(pose.origin.is_equal_approx(position) and pose.basis.is_equal_approx(basis), "기존 타일 위치·회전·크기 변경")
			# 구현은 전역이웃을 역회전. 검사는 각 local 측면을 정회전해 실제 점유를 확인한다.
			var directions := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
			for side in range(4):
				var direction: Vector3 = pose.basis * directions[side]
				var neighbor := cell + Vector2i(roundi(direction.x), roundi(direction.z))
				var occupied := neighbor.x >= 0 and neighbor.x < columns and neighbor.y >= 0 and neighbor.y < rows
				if occupied: occupied = tiles[neighbor.y * columns + neighbor.x] != "blocked"
				_check(((mask & (1 << side)) != 0) == occupied, "열린/맞닿은 측면 mask 방향 오류")
	_check(seen.size() == tiles.size() - tiles.count("blocked"), "길·건설·포탈·코어 받침 누락")
	_check(scene._portals.size() == tiles.count("spawn") and scene._cores.size() == tiles.count("core"), "포탈·코어 원본 누락")
	for mode in ["angled", "drone"]:
		scene.options["camera"] = mode
		scene._apply_options()
		if scene.camera_transition:
			scene.camera_transition.pause()
			scene.camera_transition.custom_step(scene.CAMERA_TRANSITION_SECONDS)
		for corner in range(8):
			var depth: float = -(scene.camera.global_transform.affine_inverse() * scene._camera_envelope.get_endpoint(corner)).z
			_check(depth >= scene.camera.near - 0.001 and depth <= scene.camera.far + 0.001, "MultiMesh 포함 camera 깊이 잘림")
	print("Paving verified: %d instances in %d groups" % [seen.size(), batches.size()])
	return batches

func _verify() -> void:
	# MultiMesh getter는 dummy renderer에서 실제 transform을 돌려주지 않는다.
	# 이 검사는 --headless 없이 실제 렌더러로 실행한다.
	if DisplayServer.get_name() == "headless":
		push_error("타일 인스턴스 검사는 --headless 없이 실제 렌더러로 실행해야 합니다.")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("실제 6~10 frame fixture 경로가 필요합니다.")
		quit(1)
		return
	var frames = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not frames is Array or frames.size() != 5:
		push_error("실제 6~10 frame 5개가 필요합니다.")
		quit(1)
		return
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var previous := []
	var epoch := 1
	for stage in [0, 1, 2, 3, 4, 0]:
		var frame: Dictionary = frames[stage].duplicate(true)
		frame["sceneEpoch"] = epoch
		frame["seq"] = 0
		scene._apply_frame(frame)
		for reference: WeakRef in previous:
			_check(reference.get_ref() == null, "이전 맵 타일 batch 해제 실패")
		previous = _check_stage(scene, frame)
		frame["seq"] = 1
		scene._apply_frame(frame)
		for reference: WeakRef in previous:
			_check(reference.get_ref() != null, "동일 맵 갱신에 batch 재생성")
		epoch += 1
	scene.queue_free()
	await process_frame
	print("Chapter two paving: %d failures" % failures)
	quit(0 if failures == 0 else 1)
