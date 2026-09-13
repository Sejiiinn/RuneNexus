extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var labels: CanvasLayer = scene._turret_level_labels
	scene.options["turret_levels"] = true
	scene._report_presentation()
	_check(labels.badges.size() == scene.turrets.size(), "확정 포탑의 레벨 표시 누락")
	_check(scene.presentation()["nativeTurretLevels"], "Flutter 중복 방지 capability 누락")
	var id: int = scene.turrets.keys()[0]
	var badge: Sprite2D = labels.badges[id]
	var initial: Vector2 = badge.position
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["turrets"][0][7] = 10
	frame["turrets"][0][3] += 1.7
	scene._apply_frame(frame)
	scene._report_presentation()
	_check(badge.frame == 9, "레벨 변경을 기존 배지에 반영하지 못함")
	_check(badge.position.is_equal_approx(initial), "조준 회전이 기단의 배지를 움직임")
	scene.options["camera"] = "drone"
	scene._apply_options()
	var transition: Tween = scene.camera_transition
	transition.pause()
	var previous: Vector2 = badge.position
	for index in range(4):
		transition.custom_step(scene.CAMERA_TRANSITION_SECONDS / 4.0)
		# 실제 렌더 직전 콜백: 새 Flutter 프레임 없이 현재 카메라를 따른다.
		scene._report_presentation()
		_check(badge.position.distance_to(previous) > 0.01, "카메라 전환 중 배지 좌표가 이전 프레임에 남음")
		previous = badge.position
	var entry: Dictionary = scene.turrets[id]
	var bounds: AABB = entry["level_bounds"]
	var lower := -INF
	for corner in range(8):
		lower = maxf(lower, scene.camera.unproject_position(entry["root"].global_transform * bounds.get_endpoint(corner)).y)
	_check(badge.position.y < lower and lower - badge.position.y < 3.0, "배지가 기단 하단에 붙지 않음")
	var before_zoom: Vector2 = badge.scale
	scene.options["zoom"] = 1.4
	scene._apply_options()
	scene._report_presentation()
	_check(badge.scale.x > before_zoom.x, "확대 중 배지 크기가 포탑을 따라가지 않음")
	frame["turrets"].remove_at(0)
	scene._apply_frame(frame)
	scene._report_presentation()
	_check(not labels.badges.has(id), "철거한 포탑의 배지가 남음")
	scene.options["turret_levels"] = false
	scene._report_presentation()
	_check(not labels.visible and not scene.presentation()["nativeTurretLevels"], "레거시 표시로 전환 실패")
	scene._apply_frame({"reset": true})
	_check(labels.badges.is_empty(), "전장 종료 뒤 배지 노드가 남음")
	print("Turret labels verification: %d failures; camera without Flutter frames, aim, zoom, level, removal, capability, reset" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
