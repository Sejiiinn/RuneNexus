extends SceneTree

## 실제 전투 프레임을 통한 기관총 총구 교대·연기 분리·수명·재사용 회귀 검사.
var failures := 0


func _initialize() -> void:
	# Dummy 렌더러는 MultiMesh 인스턴스 읽기를 제공하지 않음.
	if DisplayServer.get_name() == "headless":
		push_error("기관총 MultiMesh 검사는 실제 렌더러가 필요합니다. --headless 없이 실행하세요.")
		quit(1)
		return
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _check_quiet(effect: Node3D, context: String) -> void:
	for flash: Node3D in effect.flashes:
		_check(not flash.visible, "%s: 포구 화염 잔류" % context)
	for shot: Dictionary in effect.shots:
		_check(not shot["smoke"].visible, "%s: 연기 잔류" % context)
	for index in range(effect.sparks.multimesh.instance_count):
		var pose: Transform3D = effect.sparks.multimesh.get_instance_transform(index)
		_check(pose.basis.is_equal_approx(Basis.from_scale(Vector3.ZERO)), "%s: 불티 잔류" % context)
	_check(is_zero_approx(effect.light.light_energy), "%s: 포구 조명 잔류" % context)


func _check_camera(shot: Dictionary, camera: Camera3D) -> void:
	var smoke: MeshInstance3D = shot["smoke"]
	var material: ShaderMaterial = shot["material"]
	var inverse := smoke.global_transform.affine_inverse()
	var ray: Vector3 = material.get_shader_parameter("u_ray_direction")
	var eye: Vector3 = material.get_shader_parameter("u_camera_local")
	var pose := camera.get_camera_transform()
	_check(ray.is_equal_approx(inverse.basis * -pose.basis.z), "카메라 전환 중 연기 볼륨의 광선 방향 불일치")
	_check(eye.is_equal_approx(inverse * pose.origin), "HUD 오프셋을 포함한 연기 볼륨의 시점 위치 불일치")
	_check(material.get_shader_parameter("u_orthographic") == true, "직교 카메라의 연기 볼륨 투영 모드 누락")


func _verify() -> void:
	root.size = Vector2i(880, 760)
	root.content_scale_size = Vector2i(440, 380)
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["viewport"] = [440.0, 380.0]
	frame["screenCenter"] = [200.0, 165.0]
	frame["pixelsPerTile"] = 25.0
	frame["zoom"] = 1.15
	frame["seq"] = 101
	frame["time"] = 1.0
	frame["turrets"] = [[701, 3.5, 4.5, 0.0, 0, 0.0, "arrow", 1]]
	frame["enemies"] = []
	frame["projectiles"] = []
	frame["impacts"] = []
	frame["buildPreview"] = null
	scene._apply_frame(frame)
	var entry: Dictionary = scene.turrets[701]
	_check(entry.has("muzzle_effect"), "기관총 전투 모델의 3D 발사 효과 누락")
	if not entry.has("muzzle_effect"):
		scene.free()
		quit(1)
		return
	var effect: Node3D = entry["muzzle_effect"]
	var muzzle: Node3D = entry["muzzle"]
	_check(effect.shots.size() == 6 and effect.flashes.size() == 2, "기관총의 고정 연기 6개·교대 총구 2개 누락")
	if effect.shots.size() != 6 or effect.flashes.size() != 2:
		scene.free()
		quit(1)
		return
	_check(effect.sparks.multimesh.instance_count == 24, "기관총 불티의 고정 인스턴스 수 불일치")
	_check(entry["flashes"].is_empty() and entry["smokes"].is_empty(), "기관총에 이전 평면 발사 효과가 중복 생성됨")
	_check_quiet(effect, "발사 전")
	var child_count := effect.get_child_count()
	var smoke_ids: Array[int] = []
	for shot: Dictionary in effect.shots:
		smoke_ids.append(shot["smoke"].get_instance_id())
	for flash: Node3D in effect.flashes:
		_check(flash.scene_file_path == "res://assets/effects/machinegun_muzzle.glb", "포구 화염이 원본 3D 모델을 사용하지 않음")

	frame["turrets"][0][4] = 1
	frame["turrets"][0][5] = 1.0
	scene._apply_frame(frame)
	_check(effect.flashes[1].visible and not effect.flashes[0].visible, "홀수 발사 순번의 오른쪽 총구 재생 실패")
	_check(effect.flashes[1].global_position.is_equal_approx(muzzle.to_global(Vector3(0.062, 0, 0.018))), "오른쪽 화염이 실제 총구에서 벗어남")
	_check(effect.shots[0]["smoke"].visible and effect.next_slot == 1, "첫 발의 연기 기록 실패")
	frame["time"] = 1.01
	scene._apply_frame(frame)
	_check(effect.next_slot == 1 and is_equal_approx(effect.fire_start, 1.0), "같은 발사 순번을 수신할 때 효과를 다시 시작함")
	frame["time"] = 1.02
	frame["turrets"][0][4] = 2
	scene._apply_frame(frame)
	_check(effect.flashes[0].visible and not effect.flashes[1].visible, "짝수 발사 순번의 왼쪽 총구 재생 실패")
	_check(effect.flashes[0].global_position.is_equal_approx(muzzle.to_global(Vector3(-0.062, 0, 0.018))), "왼쪽 화염이 실제 총구에서 벗어남")
	_check(effect.next_slot == 2 and effect.shots[0]["smoke"].visible and effect.shots[1]["smoke"].visible, "두 발의 연기가 독립적으로 유지되지 않음")

	# 같은 전투 시간에 조준·위치를 바꿔 연기와 총구의 좌표 책임을 분리 검증.
	var first_smoke: MeshInstance3D = effect.shots[0]["smoke"]
	var second_smoke: MeshInstance3D = effect.shots[1]["smoke"]
	var first_pose := first_smoke.global_transform
	var second_pose := second_smoke.global_transform
	var first_spark: Transform3D = effect.sparks.multimesh.get_instance_transform(0)
	var flash_position: Vector3 = effect.flashes[0].global_position
	frame["turrets"][0][1] = 4.5
	frame["turrets"][0][3] = PI / 2.0
	scene._apply_frame(frame)
	_check(first_smoke.global_transform.is_equal_approx(first_pose) and second_smoke.global_transform.is_equal_approx(second_pose), "이미 발사한 연기가 포탑 이동·조준 회전을 따라감")
	_check(effect.sparks.multimesh.get_instance_transform(0).is_equal_approx(first_spark), "이미 발사한 불티가 포탑 이동·조준 회전을 따라감")
	_check(effect.flashes[0].global_position.distance_to(flash_position) > 0.1, "활성 화염이 변경된 총구 위치를 따라가지 않음")
	_check(effect.flashes[0].global_position.is_equal_approx(muzzle.to_global(Vector3(-0.062, 0, 0.018))), "조준 변경 후 활성 화염과 총구 불일치")
	frame["time"] = 1.03
	frame["turrets"][0][4] = 9
	frame["turrets"][0][5] = 0.0
	scene._apply_frame(frame)
	_check(effect.next_slot == 3 and effect.flashes[1].visible, "건너뛴 발사 순번을 재연하거나 피드백이 없는 새 발사를 누락함")

	# 이전 연기를 만료시킨 뒤 새 한 발의 각 수명 경계 검사.
	frame["time"] = 2.0
	scene._apply_frame(frame)
	_check_quiet(effect, "발사 종료 후")
	frame["turrets"][0][4] = 10
	scene._apply_frame(frame)
	var timed_shot: Dictionary = effect.shots[3]
	frame["time"] = 2.054
	scene._apply_frame(frame)
	_check(effect.flashes[0].visible and effect.light.light_energy > 0.0, "55ms 이전에 포구 화염·조명이 종료됨")
	frame["time"] = 2.055001
	scene._apply_frame(frame)
	_check(not effect.flashes[0].visible and is_zero_approx(effect.light.light_energy), "55ms 이후 포구 화염·조명이 남음")
	_check(timed_shot["smoke"].visible, "포구 화염 종료와 함께 연기가 조기 종료됨")
	frame["time"] = 2.149
	scene._apply_frame(frame)
	_check(effect.sparks.multimesh.get_instance_transform(12).basis.get_scale().length() > 0.0, "150ms 이전에 불티가 종료됨")
	frame["time"] = 2.150001
	scene._apply_frame(frame)
	for index in range(12, 16):
		_check(effect.sparks.multimesh.get_instance_transform(index).basis.is_equal_approx(Basis.from_scale(Vector3.ZERO)), "150ms 이후 불티가 남음")
	frame["time"] = 2.319
	scene._apply_frame(frame)
	_check(timed_shot["smoke"].visible, "320ms 이전에 연기가 종료됨")
	frame["time"] = 2.320001
	scene._apply_frame(frame)
	_check_quiet(effect, "320ms 이후")

	# 6개 용량을 두 번 넘기는 연속 발사에서도 동일한 노드만 재사용.
	for index in range(13):
		frame["time"] = 3.0 + index * 0.01
		frame["turrets"][0][4] = 11 + index
		scene._apply_frame(frame)
		_check(effect.shots.size() == 6 and effect.get_child_count() == child_count, "연속 발사 중 발사 효과 노드 수가 증가함")
		_check(effect.sparks.multimesh.instance_count == 24, "연속 발사 중 불티 인스턴스 수가 증가함")
		for slot in range(6):
			_check(effect.shots[slot]["smoke"].get_instance_id() == smoke_ids[slot], "연속 발사 중 연기 노드를 새로 생성함")
	_check(effect.next_slot == 5, "기관총 발사 기록이 고정 용량을 순환하지 않음")
	for shot: Dictionary in effect.shots:
		_check(shot["smoke"].visible and float(shot["start"]) >= 3.069, "고정 연기 슬롯에 최근 여섯 발이 유지되지 않음")

	frame["time"] = 1.0
	scene._apply_frame(frame)
	_check_quiet(effect, "전투 시간 되돌림")
	_check(effect.next_slot == 0, "전투 시간 되돌림 후 발사 기록이 초기화되지 않음")
	frame["time"] = 1.01
	frame["turrets"][0][4] = 24
	scene._apply_frame(frame)
	_check(effect.flashes[0].visible and effect.shots[0]["smoke"].visible and effect.next_slot == 1, "시간 초기화 후 새 발사 효과를 시작하지 못함")

	# 전투 프레임 없이 카메라 Tween만 진행해 연기의 시선 갱신 확인.
	var camera_shot: Dictionary = effect.shots[0]
	var smoke_pose: Transform3D = camera_shot["smoke"].global_transform
	var ray_before: Vector3 = camera_shot["material"].get_shader_parameter("u_ray_direction")
	var received_before: int = scene.received_frames
	scene.options["camera"] = "drone"
	scene._apply_options()
	var transition: Tween = scene.camera_transition
	transition.pause()
	transition.custom_step(0.21)
	_check_camera(camera_shot, scene.camera)
	var ray_during: Vector3 = camera_shot["material"].get_shader_parameter("u_ray_direction")
	_check(not ray_during.is_equal_approx(ray_before), "카메라 전환 중 연기 광선 방향이 고정됨")
	transition.custom_step(0.49)
	_check_camera(camera_shot, scene.camera)
	_check(scene.received_frames == received_before and is_equal_approx(float(frame["time"]), 1.01), "카메라 독립 갱신 검사가 전투 프레임을 진행함")
	_check(camera_shot["smoke"].global_transform.is_equal_approx(smoke_pose), "카메라 전환이 이미 발사한 연기의 월드 위치를 변경함")

	var owned_nodes: Array[WeakRef] = [weakref(effect), weakref(effect.sparks), weakref(effect.light)]
	for shot: Dictionary in effect.shots:
		owned_nodes.append(weakref(shot["smoke"]))
	for flash: Node3D in effect.flashes:
		owned_nodes.append(weakref(flash))
	frame["turrets"] = []
	scene._apply_frame(frame)
	_check(scene.turrets.is_empty(), "제거한 기관총의 전투 모델 잔류")
	for reference in owned_nodes:
		_check(reference.get_ref() == null, "기관총 제거 후 월드 고정 연기·불티·조명·화염 노드 잔류")
	print("Machinegun verification: %d failures; shot sequence, alternating ports, detached smoke/sparks, lifetimes, bounded reuse, rollback, camera, cleanup" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
