extends SceneTree

## 실제 장면의 카메라 전환·재입력·정지 전투 회귀 검사.
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
	var camera: Camera3D = scene.camera
	var initial := camera.transform
	_check(camera.position.distance_to(Vector3(5, 27, 13)) < 0.0001, "최초 시점 오류")
	var frame: Dictionary = scene.last_frame.duplicate(true)
	var target: Array = frame["enemies"][1]
	frame["impacts"] = [[100, target[1], target[2], 1.2, 0.52]]
	scene._apply_frame(frame)
	var material: ShaderMaterial = scene.impacts[100]._volume_material
	var initial_ray: Vector3 = material.get_shader_parameter("u_ray_direction")
	var age: float = material.get_shader_parameter("u_age")
	scene.options["camera"] = "drone"
	scene._apply_options()
	_check(camera.transform.is_equal_approx(initial), "버튼 입력 순간 시점이 점프함")
	var transition: Tween = scene.camera_transition
	transition.pause()
	var distances: Array[float] = []
	for index in range(4):
		var previous := camera.position
		transition.custom_step(scene.CAMERA_TRANSITION_SECONDS / 4.0)
		distances.append(previous.distance_to(camera.position))
		_check(camera.global_basis.z.dot(camera.global_position.normalized()) > 0.9999, "전환 중 전장 중심 이탈")
	_check(distances[0] > distances[1] and distances[1] > distances[2] and distances[2] > distances[3], "전환 후반 감속 실패")
	_check(camera.position.distance_to(Vector3(0, 30, 0.001)) < 0.0001, "드론 시점 도착 오차")
	_check(initial_ray.distance_to(material.get_shader_parameter("u_ray_direction")) > 0.1, "정지 전투의 볼륨 광선 갱신 누락")
	_check(is_equal_approx(age, material.get_shader_parameter("u_age")), "카메라 이동이 정지한 전투 시계를 변경함")
	var settled := camera.transform
	transition.custom_step(1.0)
	_check(camera.transform.is_equal_approx(settled), "도착 후 시점 흔들림")

	scene.options["camera"] = "angled"
	scene._apply_options()
	transition = scene.camera_transition
	transition.pause()
	transition.custom_step(0.1)
	var intermediate := camera.transform
	var previous_size := camera.size
	scene.options["zoom"] = 1.5
	scene._apply_options()
	scene._update_camera()
	_check(scene.camera_transition == transition and camera.transform.is_equal_approx(intermediate), "확대·화면 크기 변경이 전환을 재시작함")
	_check(camera.size < previous_size, "전환 중 확대 미반영")
	scene.options["camera"] = "drone"
	scene._apply_options()
	_check(camera.transform.is_equal_approx(intermediate), "빠른 방향 변경 시 시점이 점프함")
	_check(not transition.is_valid(), "이전 전환이 중복 실행됨")
	transition = scene.camera_transition
	transition.pause()
	transition.custom_step(scene.CAMERA_TRANSITION_SECONDS)
	_check(camera.position.distance_to(Vector3(0, 30, 0.001)) < 0.0001, "재입력 후 목표 시점 도착 실패")
	scene.options["camera"] = "angled"
	scene._apply_options()
	transition = scene.camera_transition
	transition.pause()
	transition.custom_step(scene.CAMERA_TRANSITION_SECONDS)
	_check(camera.transform.is_equal_approx(initial), "고정 시점 복귀 오차")
	print("Camera verification: %d failures; quarter travel %s" % [failures, distances])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
