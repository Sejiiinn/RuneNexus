extends SceneTree

## 실제 장면의 카메라 전환·재입력·정지 전투 회귀 검사.
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _check_point(camera: Camera3D, point: Vector3, label: String) -> void:
	var depth := -(camera.get_camera_transform().affine_inverse() * point).z
	_check(depth >= camera.near - 0.0001 and depth <= camera.far + 0.0001,
		"%s 깊이 잘림: %s / near %.3f far %.3f" % [label, point, camera.near, camera.far])

func _check_depth(scene: Node3D, label: String) -> void:
	var camera: Camera3D = scene.camera
	_check(camera.near > 0.0 and camera.far > camera.near, label + " 깊이 범위 역전")
	for index in range(8):
		_check_point(camera, scene._camera_envelope.get_endpoint(index), label + " 공통 경계")
	# 실제 기하와 효과 전체 수명 AABB를 독립적으로 검사한다.
	for node: GeometryInstance3D in scene.world.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree():
			continue
		var bounds := AABB()
		if node is MeshInstance3D:
			bounds = node.get_aabb()
		elif node is MultiMeshInstance3D:
			bounds = node.multimesh.get_aabb()
		for index in range(8):
			_check_point(camera, node.global_transform * bounds.get_endpoint(index), label + " " + str(node.name))

func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var camera: Camera3D = scene.camera
	var initial := camera.transform
	_check(camera.position.distance_to(Vector3(5, 27, 13)) < 0.0001, "최초 시점 오류")
	_check_depth(scene, "최초 고정 시점")
	_check(camera.far - camera.near < 50.0, "작은 전장의 불필요한 깊이 범위를 줄이지 못함")
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
		_check_depth(scene, "고정→드론 전환 %d" % index)
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
	_check_depth(scene, "전환 중 확대")
	scene.options["camera"] = "drone"
	scene._apply_options()
	_check(camera.transform.is_equal_approx(intermediate), "빠른 방향 변경 시 시점이 점프함")
	_check(not transition.is_valid(), "이전 전환이 중복 실행됨")
	transition = scene.camera_transition
	transition.pause()
	transition.custom_step(scene.CAMERA_TRANSITION_SECONDS)
	_check(camera.position.distance_to(Vector3(0, 30, 0.001)) < 0.0001, "재입력 후 목표 시점 도착 실패")
	_check_depth(scene, "재입력 후 드론")
	scene.options["camera"] = "angled"
	scene._apply_options()
	transition = scene.camera_transition
	transition.pause()
	transition.custom_step(scene.CAMERA_TRANSITION_SECONDS)
	_check(camera.transform.is_equal_approx(initial), "고정 시점 복귀 오차")
	# 큰 적·맵 경계의 폭발·종료 탄체를 실제 브리지 입력으로 수용한다.
	var expanded: Dictionary = frame.duplicate(true)
	expanded["enemies"] = [[701, 0.0, 0.0, 1.1, 1.57, 1.7, 0.0, "boss"]]
	expanded["impacts"] = [[702, float(scene.columns), float(scene.rows), 2.4, 0.48]]
	expanded["projectiles"] = [[703, 0.0, 0.0, 1.0, 0.0, "cannon", -0.5, 0.0, null, 0, true, -1.0]]
	scene._apply_frame(expanded)
	_check_depth(scene, "큰 모델·경계 폭발")
	for progress in [0.01, 0.52, 0.96]:
		expanded["impacts"][0][4] = progress
		scene._apply_frame(expanded)
		_check_depth(scene, "폭발 수명 %.2f" % progress)
	var retained := Vector2(camera.near, camera.far)
	expanded["enemies"] = []
	expanded["impacts"] = []
	expanded["projectiles"] = []
	scene._apply_frame(expanded)
	_check(retained.is_equal_approx(Vector2(camera.near, camera.far)), "효과 소멸로 깊이 범위가 왕복함")
	# HUD 오프셋·가로/세로 viewport는 구도만 바꾸고 깊이는 보존한다.
	for viewport in [[412.0, 915.0], [915.0, 412.0]]:
		expanded["viewport"] = viewport
		expanded["screenCenter"] = [viewport[0] * 0.35, viewport[1] * 0.6]
		expanded["pixelsPerTile"] = 32.0
		expanded["zoom"] = 1.2
		scene._apply_frame(expanded)
		_check(retained.is_equal_approx(Vector2(camera.near, camera.far)), "HUD 정렬이 깊이 범위를 변경함")
		_check_depth(scene, "HUD viewport %s" % str(viewport))
	# 같은 맵 재시작도 이전 전투의 확대 경계를 버리고 다시 계산한다.
	scene._apply_frame({"reset": true})
	scene._apply_frame(frame)
	_check(camera.far - camera.near < retained.y - retained.x, "맵 재생성 시 이전 효과 경계를 유지함")
	_check_depth(scene, "맵 재생성")
	print("Camera verification: %d failures; quarter travel %s" % [failures, distances])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
