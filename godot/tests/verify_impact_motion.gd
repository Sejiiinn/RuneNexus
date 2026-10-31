extends SceneTree

## 대포 착탄(FlipbookImpact)의 외부 시계 계약 회귀.
## headless는 실제 정점 출력·조명을 검증하지 않으며 실제 화면 확인을 별도로 한다.
## 실행: Godot --headless --path <준비된 프로젝트> --script res://tests/verify_impact_motion.gd
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _new_effect():
	var effect = FlipbookImpact.new()
	root.add_child(effect)
	effect.configure()
	return effect

func _state(effect) -> Array:
	var state: Array = [effect._card_material.get_shader_parameter("frame"), effect._blast.scale, effect._blast.rotation]
	for material: ShaderMaterial in effect._age_materials:
		state.append(material.get_shader_parameter("age"))
	return state

func _check_age(effect, age: float, radius: float, impact_id: int) -> void:
	_check(is_equal_approx(float(effect._card_material.get_shader_parameter("frame")), age * 60.0), "외부 나이가 카드 프레임에 미반영")
	for material: ShaderMaterial in effect._age_materials:
		_check(is_equal_approx(float(material.get_shader_parameter("age")), age), "외부 나이가 입자·그을음에 미반영")
	_check(effect._blast.scale.is_equal_approx(Vector3.ONE * radius / FlipbookImpact.REFERENCE_RADIUS), "반경 배율 미반영")
	_check(is_equal_approx(effect._blast.rotation.y, float(posmod(impact_id, 23)) * 0.317), "impact ID 방향 미반영")

func _card_faces(effect, camera: Camera3D) -> bool:
	var basis: Basis = effect._card.global_transform.basis.orthonormalized()
	return basis.z.dot(camera.get_camera_transform().basis.z) > 0.9999

func _verify() -> void:
	var effect = _new_effect()
	var other = _new_effect()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(5.0, 27.0, 13.0)
	camera.look_at(Vector3.ZERO)
	_check(FlipbookImpact._sheet != null, "폭발 시트 로드 실패")
	_check(effect._card_material.get_shader_parameter("sheet") == other._card_material.get_shader_parameter("sheet"), "효과 간 시트 중복")
	_check(effect._card_material != other._card_material, "동시 폭발이 카드 material을 공유함")
	var groups: Array[MultiMeshInstance3D] = []
	for child in effect._blast.get_children():
		if child is MultiMeshInstance3D: groups.append(child)
	_check(groups.size() == 2, "파편·잉걸불 묶음 누락")
	var counts := groups.map(func(group): return group.multimesh.instance_count)
	_check(counts == [FlipbookImpact.DEBRIS_COUNT, FlipbookImpact.EMBER_COUNT + FlipbookImpact.REMNANT_COUNT], "입자 수 변경")
	var buffers: Array[PackedFloat32Array] = []
	for group in groups:
		buffers.append(group.multimesh.buffer.duplicate())
		for index in range(group.multimesh.instance_count):
			_check(group.multimesh.get_instance_transform(index).is_equal_approx(Transform3D.IDENTITY),
				"정적 입자 transform이 identity가 아님")
	var tables: Array = [FlipbookImpact._debris_table.get_image().get_data(), FlipbookImpact._ember_table.get_image().get_data()]
	other.update_impact(0.1, 0.5, 2, camera)
	var other_state := _state(other)
	effect.update_impact(0.3, 1.2, 100, camera)
	_check_age(effect, 0.33, 1.2, 100)
	_check(effect.visible and _card_faces(effect, camera), "카드가 카메라와 평행하지 않음")
	var paused_state := _state(effect)
	for iteration in range(3):
		await process_frame
	_check(_state(effect) == paused_state, "자체 프레임이 정지한 전투 시계를 진행함")
	camera.position += Vector3(4.0, -6.0, 3.0)
	camera.look_at(Vector3.ZERO)
	effect.update_camera(camera)
	_check(_state(effect) == paused_state, "카메라만 이동했는데 폭발 상태가 진행함")
	_check(_card_faces(effect, camera), "카메라 이동 뒤 카드가 다시 서지 않음")
	_check(effect._card.global_position.is_equal_approx(effect._blast.global_transform * FlipbookImpact.CARD_CENTER), "카드 중심 이탈")
	effect.update_impact(0.3, 1.2, 100, camera)
	_check(_state(effect) == paused_state, "같은 전투 프레임 재입력이 상태를 변경함")
	effect.update_impact(0.8, 2.4, -1, camera)
	_check_age(effect, 0.88, 2.4, -1)
	effect.update_impact(0.3, 1.2, 100, camera)
	_check(_state(effect) == paused_state, "역방향 seek가 이전 상태로 복원되지 않음")
	effect.update_impact(1.5, 1.2, 100, camera)
	_check(not effect.visible, "수명 종료 시 효과가 남음")
	effect.update_impact(-0.5, -3.0, 123, camera)
	_check(effect.visible, "풀 재사용 후 초기 가시성 복구 실패")
	_check_age(effect, 0.0, 0.001, 123)
	_check(_state(other) == other_state, "효과 업데이트가 다른 폭발 상태를 덮어씀")
	for index in range(groups.size()):
		_check(groups[index].multimesh.buffer == buffers[index], "update/seek/재사용이 정적 MultiMesh 버퍼를 변경함")
	_check(tables == [FlipbookImpact._debris_table.get_image().get_data(), FlipbookImpact._ember_table.get_image().get_data()],
		"update가 정적 입자 데이터를 변경함")
	effect.update_impact(0.2, 1.0, 1, null)
	_check(not effect.visible, "카메라 없는 효과가 표시됨")
	effect.free()
	other.free()
	FlipbookImpact.retain_stage([], ["cannon"])
	_check(FlipbookImpact._sheet != null, "대포 스테이지에서 공유 시트를 놓음")
	FlipbookImpact.retain_stage([], ["arrow"])
	_check(FlipbookImpact._sheet == null and FlipbookImpact._ember_table == null, "대포 없는 스테이지에서 공유 자료가 남음")
	camera.free()
	print("IMPACT_MOTION_CONTRACT ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
