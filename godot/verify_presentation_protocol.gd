extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _verify() -> void:
	root.size = Vector2i(390, 844)
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame.merge({"sceneEpoch": 100, "seq": 20, "viewportRevision": 2,
		"viewport": [390, 844], "presentationVersion": 2}, true)
	scene._apply_frame(frame)
	scene._report_presentation()
	var applied: Dictionary = scene.presentation()
	_check(applied["sceneEpoch"] == 100 and applied["sequence"] == 20, "적용 확인의 세대·순서 불일치")
	_check(applied["viewportRevision"] == 2 and applied["viewport"] == [390, 844], "화면 크기 세대 누락")
	_check(applied["presentationVersion"] == 2, "표시 계약 버전 누락")
	scene.options["presentation_groups"] = ["labels", "selection", "effects"]
	frame["presentation"] = {"labels": {"enemies": []}, "selection": {"turrets": [], "tiles": []}, "effects": {"items": [], "shake": [3.4, -1.53]}}
	scene._apply_frame(frame)
	scene._report_presentation()
	applied = scene.presentation()
	_check(applied["appliedGroups"].size() == 3, "모듈 통합 적용 확인 누락")
	var before: Vector2 = scene.camera.unproject_position(Vector3.ZERO)
	var after: Vector2 = scene.camera.unproject_position(scene.world.to_global(Vector3.ZERO))
	var viewport_size := scene.get_viewport().get_visible_rect().size
	var logical_delta: Vector2 = (after - before) * Vector2(390.0, 844.0) / viewport_size
	_check(logical_delta.distance_to(Vector2(3.4, -1.53)) < 0.001, "카메라 기준 코어 흔들림 단위 변경")
	scene.options["presentation_groups"] = []
	scene._update_camera_visuals()
	_check(scene.world.position == Vector3.ZERO, "효과 미지원 시 네이티브 흔들림을 남김")
	frame["seq"] = 19
	frame["turrets"] = []
	scene._apply_frame(frame)
	_check(scene.last_sequence == 20 and not scene.turrets.is_empty(), "늦은 프레임이 현재 장면을 덮음")
	scene._apply_frame({"reset": true, "sceneEpoch": 99})
	_check(not scene.last_frame.is_empty(), "이전 화면의 dispose가 새 전장을 지움")
	frame["sceneEpoch"] = 101
	frame["seq"] = 0
	scene._apply_frame(frame)
	_check(scene.last_sequence == 0 and scene.turrets.is_empty(), "새 장면 초기화/순서 재시작 실패")
	# Versioned static maps remain valid across many dynamic frames.
	frame["seq"] = 1
	frame["mapRevision"] = 1
	scene._apply_frame(frame)
	var terrain_id: int = scene.terrain.get_child(0).get_instance_id()
	var map_snapshot: Dictionary = scene._current_map.duplicate(true)
	var dynamic: Dictionary = frame.duplicate(true)
	dynamic.erase("map")
	dynamic["seq"] = 2
	dynamic["time"] = 3.0
	scene._apply_frame(dynamic)
	_check(scene.last_sequence == 2 and scene.presentation()["mapRevision"] == 1, "동적 프레임 적용/맵 ACK 실패")
	_check(scene.terrain.get_child(0).get_instance_id() == terrain_id and scene._current_map == map_snapshot, "정적 맵을 다시 만들거나 변경함")
	dynamic["seq"] = 3
	dynamic["mapRevision"] = 2
	scene._apply_frame(dynamic)
	_check(scene.last_sequence == 2 and scene.presentation().get("mapRequired", false), "맵 불일치 프레임을 적용하거나 복구 요청 누락")
	frame["seq"] = 4
	frame["mapRevision"] = 2
	frame["map"] = map_snapshot.duplicate(true)
	# Same dimensions/theme, different tile content must rebuild.
	var changed_index := -1
	for i in range(frame["map"]["tiles"].size()):
		if frame["map"]["tiles"][i] == "build":
			changed_index = i
			break
	_check(changed_index >= 0, "맵 변경 검사 타일 없음")
	if changed_index >= 0:
		frame["map"]["tiles"][changed_index] = "path"
	scene._apply_frame(frame)
	_check(scene.last_sequence == 4 and scene.presentation()["mapRevision"] == 2 and not scene.presentation().has("mapRequired"), "맵 재전송 복구 실패")
	_check(scene._current_map == frame["map"] and scene._current_map != map_snapshot, "같은 크기/테마의 타일 변경 누락")
	# A fresh epoch must never reuse the old static map.
	dynamic["sceneEpoch"] = 102
	dynamic["seq"] = 0
	scene._apply_frame(dynamic)
	_check(scene.last_sequence == -1 and scene.presentation().get("mapRequired", false), "새 epoch에서 이전 맵 재사용")
	_check(not scene.presentation().has("projection"), "복구 메타데이터가 준비된 프레임을 가장함")
	frame["sceneEpoch"] = 102
	frame["seq"] = 1
	frame.erase("mapRevision")
	scene._apply_frame(frame)
	_check(scene.last_sequence == 1 and not scene.presentation().has("mapRequired"), "레거시 전체 프레임 복구 실패")
	scene._apply_frame({"reset": true, "sceneEpoch": 102})
	_check(scene.world.position == Vector3.ZERO, "장면 리셋 뒤 흔들림 잔류")
	_check(scene.presentation().is_empty(), "초기화 후 과거 적용 상태를 보고함")
	print("Presentation protocol: %d failures" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
