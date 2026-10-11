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
	_check(root.msaa_3d == Viewport.MSAA_2X and scene.sun.shadow_enabled, "기본 MSAA·그림자 유지 실패")
	for size in [512, 1024, 2048, 0, 512]:
		# Flutter 브리지와 같은 JSON 숫자 타입으로 전환을 검증한다.
		scene.options.merge(JSON.parse_string(JSON.stringify({"msaa_samples": 0, "shadow_map_size": size})), true)
		scene._apply_options()
		await process_frame
		_check(root.msaa_3d == Viewport.MSAA_DISABLED, "MSAA 끄기 적용 실패")
		_check(scene.sun.shadow_enabled == (size > 0), "그림자 켜기·끄기 적용 실패")
		if size > 0:
			_check(scene._applied_shadow_map_size == size, "그림자 해상도 적용 실패")
		scene.options["camera"] = "drone"
		scene._apply_options()
		_check(root.msaa_3d == Viewport.MSAA_DISABLED and scene.sun.shadow_enabled == (size > 0), "카메라 옵션 변경으로 그래픽 옵션 유실")
	scene.options["shadows"] = false
	scene._apply_options()
	_check(not scene.sun.shadow_enabled, "기존 진단용 그림자 끄기가 무시됨")
	scene.options["shadows"] = true
	for invalid in [null, "0", false, -1, 2.5, [], {}]:
		scene.options["msaa_samples"] = invalid
		scene.options["shadow_map_size"] = invalid
		scene._apply_options()
		_check(root.msaa_3d == Viewport.MSAA_2X and scene.sun.shadow_enabled and scene._applied_shadow_map_size == 2048, "잘못된 그래픽 옵션 기본값 처리 실패: " + str(invalid))
	# 개발·검사 실행은 기기 설정 없이 프레임 제한 없음·원래 해상도를 유지한다.
	scene.options.erase("max_fps")
	scene.options.erase("render_scale")
	scene._apply_options()
	_check(Engine.max_fps == 0 and is_equal_approx(root.scaling_3d_scale, 1.0), "기본 프레임 제한·3D 해상도 유지 실패")
	for pair in [[30, 0.5], [60, 0.75], [30, 1.0], [60, 0.5]]:
		scene.options.merge(JSON.parse_string(JSON.stringify({"max_fps": pair[0], "render_scale": pair[1]})), true)
		scene._apply_options()
		_check(Engine.max_fps == pair[0] and is_equal_approx(root.scaling_3d_scale, pair[1]), "프레임 제한·3D 해상도 적용 실패: " + str(pair))
		scene.options["camera"] = "angled" if scene.options["camera"] == "drone" else "drone"
		scene._apply_options()
		_check(Engine.max_fps == pair[0] and is_equal_approx(root.scaling_3d_scale, pair[1]), "카메라 옵션 변경으로 프레임·해상도 유실")
	for invalid in [null, "60", true, 45, 120, 0.6, -1, [], {}]:
		scene.options["max_fps"] = invalid
		scene.options["render_scale"] = invalid
		scene._apply_options()
		_check(Engine.max_fps == 0 and is_equal_approx(root.scaling_3d_scale, 1.0), "잘못된 프레임·해상도 기본값 처리 실패: " + str(invalid))
	scene.free()
	await process_frame
	print("Graphics options verification: ", "PASS" if failures == 0 else "FAIL (%s)" % failures)
	quit(0 if failures == 0 else 1)
