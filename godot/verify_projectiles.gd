extends SceneTree

## 화살 궤적과 둥근 철구의 실제 비행·명중·짧은 잔여 효과·재사용 검증.
var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _verify_cannon_asset(cannon: Node3D) -> void:
	var authored_root: Node3D = cannon._cannon_model if cannon._cannon_model.name == "cannonball" else cannon._cannon_model.find_child("cannonball", true, false)
	_check(authored_root != null, "철구 GLB 원본 루트 cannonball 누락")
	_check(cannon.body.name == "cannonball_body" and cannon.nose.name == "cannonball_heat", "철구 GLB 몸체·뒤쪽 열 표현 누락")
	_check(not cannon.tracer.visible and cannon.tracer.mesh == null, "철구에 기존 긴 예광 메시가 남음")
	var bounds: AABB = cannon.body.mesh.get_aabb()
	var diameter := bounds.size
	_check(diameter.x >= 0.25 and diameter.x <= 0.31 and diameter.y >= 0.25 and diameter.y <= 0.31 and diameter.z >= 0.25 and diameter.z <= 0.31, "철구 몸체 반지름이 0.14 계약과 다름")
	_check(diameter[diameter.max_axis_index()] / diameter[diameter.min_axis_index()] < 1.12, "철구가 둥근 구형이 아닌 길쭉한 형태로 변경됨")
	var heat_bounds: AABB = cannon.nose.transform * cannon.nose.mesh.get_aabb()
	_check(heat_bounds.get_center().z < 0.0, "철구 열 표현이 뒤쪽 -Z에 있지 않음")
	for surface in range(cannon.body.mesh.get_surface_count()):
		var material: Material = cannon.body.get_active_material(surface)
		_check(material is StandardMaterial3D, "철구 금속 표면이 native 재질이 아님")
		if material is StandardMaterial3D:
			_check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and is_equal_approx(material.albedo_color.a, 1.0), "검은 철구 몸체가 반투명해짐")
	# COLOR_0가 존재해도 native 재질에서 사용하지 않으면 흰 포탄으로 표시된다.
	# 실제 GLB 색 데이터와 적용 플래그를 함께 확인한다.
	for mesh: MeshInstance3D in [cannon.body, cannon.nose]:
		for surface in range(mesh.mesh.get_surface_count()):
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var has_colors: bool = colors != null and not colors.is_empty()
			if mesh == cannon.body:
				_check(has_colors, "검은 철구 GLB의 단조 금속 정점색이 누락됨")
			if has_colors:
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				_check(material != null and material.vertex_color_use_as_albedo, "철구 COLOR_0가 native 재질의 albedo에 적용되지 않음: " + str(mesh.name))
	var second: Node3D = cannon.get_script().new("cannon")
	root.add_child(second)
	_check(cannon.body.mesh == second.body.mesh and cannon.nose.mesh == second.nose.mesh, "철구 인스턴스별로 GLB 메시를 복제함")
	for pair in [[cannon.body, second.body], [cannon.nose, second.nose]]:
		for surface in range(pair[0].mesh.get_surface_count()):
			_check(pair[0].get_active_material(surface) == pair[1].get_active_material(surface), "철구 인스턴스별 native 재질 복제")
	_check(cannon._cannon_flight.volume.mesh is BoxMesh and cannon._cannon_flight.volume.visible, "철구 뒤 입체 연기·화염 볼륨 누락")
	second.update_flight([999, 3.8, 4.5, 1.0, 0.0, "cannon", 3.5, 4.5, 702, 1, false, 1.0, 4.4, 4.5], 1.0, Vector3.ZERO)
	_check(second.visible and not second.body.visible and not second.nose.visible and second._cannon_flight.visible, "첫 화면 전에 명중한 철구가 탄체를 표시하거나 잔여 효과를 잃음")
	_check(is_equal_approx(second.global_position.x, 4.4), "종료 프레임만 수신한 철구의 실제 명중점 오류")
	second.free()


func _verify_events(scene: Node3D, frame: Dictionary) -> void:
	var launch := [2001, 5.0, 4.5, 1.0, 0.0, "arrow", 4.0, 4.5, 701, 1, true, -1.0, null, null]
	var packet := {"generation": 1, "clock": 10.0, "events": [{"event": 1, "data": launch, "clock": 10.0, "speed": 2.0, "remaining": 3.0}]}
	frame["projectiles"] = []
	frame["projectileEvents"] = packet
	frame["time"] = 10.0
	scene._apply_frame(frame)
	var flight: Node3D = scene.projectiles[2001]["root"]
	packet["clock"] = 11.0
	scene._apply_frame(frame)
	_check(is_equal_approx(flight.position.x + scene.columns / 2.0, 7.0), "이벤트 탄환의 전투시계 이동 불일치")
	var frozen := flight.position
	frame["time"] = 10.1
	scene._apply_frame(frame)
	_check(flight.position == frozen, "시각 시계만 진행했는데 탄환 이동")
	packet["clock"] = 14.0
	packet["events"] = []
	scene._apply_frame(frame)
	_check(is_equal_approx(flight.position.x + scene.columns / 2.0, 8.0), "최대거리 초과 이동")
	var finished := launch.duplicate()
	finished[1] = 7.3
	finished[11] = 10.1
	finished[12] = 7.4
	finished[13] = 4.5
	packet["events"] = [{"event": 2, "data": finished, "clock": 14.0, "speed": 0.0}]
	scene._apply_frame(frame)
	_check(not flight.body.visible and is_equal_approx(flight.position.x + scene.columns / 2.0, 7.4), "종료 이벤트가 Flame 피격 좌표/탄체 종료를 보존하지 않음")
	frame["time"] = 10.25
	scene._apply_frame(frame)
	_check(scene.projectiles.is_empty(), "종료 이벤트 재전송으로 탄환 부활")
	packet["generation"] = 2
	packet["events"] = [{"event": 3, "data": launch, "clock": 14.0, "speed": 2.0}]
	scene._apply_frame(frame)
	_check(scene.projectiles.size() == 1, "세대 재시드 실패")
	frame["projectileEvents"] = {"generation": 1, "clock": 0.0, "events": []}
	scene._apply_frame(frame)
	_check(scene.projectiles.size() == 1, "지연된 이전 세대가 현재 비행을 지움")
	frame["projectileEvents"] = packet
	packet["events"] = [{"event": 4, "remove": 2001}]
	scene._apply_frame(frame)
	_check(scene.projectiles.is_empty(), "강제 제거 이벤트 잔류")
	frame.erase("projectileEvents")
	for type in ["sniper", "frost"]:
		frame["projectiles"] = [[3001, 5.0, 4.5, 1.0, 0.0, type], [3002, 6.0, 4.5, 1.0, 0.0, type]]
		scene._apply_frame(frame)
		var first: Node3D = scene.projectiles[3001]["root"]
		var second: Node3D = scene.projectiles[3002]["root"]
		_check(first.get_child(0).mesh == second.get_child(0).mesh, "일반 탄환의 공유 메시가 복제됨")
		var instance_id := second.get_instance_id()
		frame["projectiles"] = []
		scene._apply_frame(frame)
		_check(not first.visible and not second.visible, "풀 반환 탄환 잔류")
		frame["projectiles"] = [[3003, 7.0, 4.5, 0.0, 1.0, type]]
		scene._apply_frame(frame)
		_check(scene.projectiles[3003]["root"].get_instance_id() == instance_id and second.visible, "일반 탄환 풀 재사용 실패")
		frame["projectiles"] = []
		scene._apply_frame(frame)


func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["time"] = 1.0
	frame["turrets"] = [[701, 3.5, 4.5, 0.0, 1, 1.0, "arrow", 1], [702, 3.5, 6.5, 0.0, 1, 1.0, "cannon", 1]]
	frame["enemies"] = []
	frame["impacts"] = []
	frame["projectiles"] = [
		[801, 5.4, 4.5, 1.0, 0.0, "arrow", 3.5, 4.5, 701, 1, false, -1.0, null, null],
		[802, 5.9, 6.5, 1.0, 0.0, "cannon", 3.5, 6.5, 702, 1, false, -1.0, null, null],
	]
	scene._apply_frame(frame)
	var arrow: Node3D = scene.projectiles[801]["root"]
	var cannon: Node3D = scene.projectiles[802]["root"]
	_verify_cannon_asset(cannon)
	for pair in [[arrow, 701], [cannon, 702]]:
		var projectile: Node3D = pair[0]
		_check(projectile.visible and projectile.body.visible, "이동 중인 탄체가 보이지 않음")
		_check(projectile.launch_position.is_equal_approx(scene.turrets[pair[1]]["shot_pose"].origin), "탄환 경로가 실제 발사 총구와 연결되지 않음")
	_check(arrow.nose.visible and arrow.tracer.visible and is_equal_approx(arrow.trail_length, 0.85), "기존 화살 탄두·예광 궤적 변경")
	_check(cannon.trail_length > 0.0 and cannon.trail_length <= 0.28, "철구 뒤 효과가 몸체 지름보다 길거나 누락됨")
	_check(is_equal_approx(cannon.global_position.x + scene.columns / 2.0, 5.9) and is_equal_approx(cannon.global_position.z + scene.rows / 2.0, 6.5), "철구 표시를 위해 실제 비행 좌표를 변경함")

	# live 프레임을 한 번도 받지 못한 근접 탄환. 판정점은 포신 앞쪽보다 가까움.
	frame["projectiles"].append([803, 3.8, 4.5, 1.0, 0.0, "arrow", 3.5, 4.5, 701, 1, false, 1.0, 4.4, 4.5])
	frame["projectiles"][1][11] = 1.0
	frame["projectiles"][1][12] = 6.1
	frame["projectiles"][1][13] = 6.5
	scene._apply_frame(frame)
	var completed: Node3D = scene.projectiles[803]["root"]
	_check(completed.visible and completed.tracer.visible and completed.trail_length > 0.2, "첫 화면 전에 명중한 탄환의 예광 궤적 누락")
	_check(not completed.body.visible and not completed.nose.visible, "명중한 탄체가 적을 통과해 계속 이동하는 것처럼 남음")
	_check(is_equal_approx(completed.global_position.x + scene.columns / 2.0, 4.4), "근접 사격의 경로가 실제 피격 몸체에 연결되지 않음")
	_check(not cannon.body.visible and not cannon.nose.visible and not cannon._cannon_model.visible and cannon.visible and cannon._cannon_flight.visible, "철구 명중 즉시 탄체·열을 숨기고 잔여 효과는 유지해야 함")
	_check(is_equal_approx(cannon.global_position.x + scene.columns / 2.0, 6.1), "철구 명중 표시가 실제 충돌 몸체 좌표와 다름")
	var cannon_launch: Vector3 = cannon.launch_position
	var initial_launch: Vector3 = completed.launch_position
	frame["time"] = 1.07
	frame["turrets"][0][3] = PI / 2.0
	scene._apply_frame(frame)
	_check(completed.launch_position.is_equal_approx(initial_launch), "이미 날아간 탄환의 경로가 새 조준을 따라감")
	_check(completed.opacity > 0.2 and completed.opacity < 0.5, "종료 궤적이 140ms 동안 서서히 소멸하지 않음")
	_check(cannon.launch_position.is_equal_approx(cannon_launch), "명중 철구의 발사 원점이 변경됨")
	_check(not cannon.body.visible and cannon.opacity > 0.2 and cannon.opacity < 0.5, "철구의 짧은 잔여 효과가 140ms 동안 소멸하지 않음")
	frame["time"] = 1.140001
	scene._apply_frame(frame)
	_check(not completed.visible and is_zero_approx(completed.opacity), "수명이 끝난 탄환 궤적 잔류")
	_check(not cannon.visible and is_zero_approx(cannon.opacity), "140ms 이후 철구 잔여 효과가 남음")
	var recycled_id := completed.get_instance_id()
	frame["projectiles"] = []
	scene._apply_frame(frame)
	_check(scene.projectiles.is_empty() and scene._ballistic_pool["arrow"].size() == 2 and scene._ballistic_pool["cannon"].size() == 1, "종료 탄환 모델 재사용 풀 누락")

	_check(not cannon.initialized and not cannon.visible and not cannon._cannon_flight.visible and is_zero_approx(cannon.trail_length) and is_zero_approx(cannon.opacity), "풀에 반환한 철구의 비행·잔여 효과 상태가 초기화되지 않음")
	# headless dummy RenderingServer는 MultiMesh 버퍼를 저장하지 않고 identity를 반환한다.
	# 실제 렌더러로 실행할 때만 GPU 인스턴스 초기화까지 확인한다.
	if not cannon._cannon_flight.sparks.multimesh.buffer.is_empty():
		for index in range(cannon._cannon_flight.sparks.multimesh.instance_count):
			_check(cannon._cannon_flight.sparks.multimesh.get_instance_transform(index).basis == Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), "풀에 반환한 철구의 불티가 초기화되지 않음")
	else:
		print("MultiMesh readback unavailable in dummy renderer; hidden/reset parent state verified")
	var recycled_cannon_id: int = cannon.get_instance_id()
	frame["projectiles"] = [[805, 5.1, 6.5, 1.0, 0.0, "cannon", 3.5, 6.5, 702, 2, false, -1.0, null, null]]
	scene._apply_frame(frame)
	var reused_cannon: Node3D = scene.projectiles[805]["root"]
	_check(reused_cannon.get_instance_id() == recycled_cannon_id and reused_cannon.body.visible and reused_cannon.nose.visible and is_equal_approx(reused_cannon.opacity, 1.0), "재사용 철구가 이전 명중의 숨김·fade 상태를 이어받음")
	frame["projectiles"] = []
	scene._apply_frame(frame)

	# 타이머 순환과 연쇄 발사는 포탑 총구와 분리된 원점 사용.
	frame["time"] = 0.02
	frame["projectiles"] = [[804, 6.0, 4.5, 1.0, 0.0, "arrow", 5.0, 4.5, 701, 1, true, 1199.99, null, null]]
	scene._apply_frame(frame)
	var chain: Node3D = scene.projectiles[804]["root"]
	_check(chain.get_instance_id() == recycled_id, "탄환 모델을 재사용하지 않음")
	_check(chain.visible and chain.opacity > 0.5, "1200초 타이머 순환 시 새 궤적이 즉시 사라짐")
	_check(chain.launch_position.is_equal_approx(Vector3(5.0 - scene.columns / 2.0, 0.45, 4.5 - scene.rows / 2.0)), "연쇄 탄환이 최초 포탑에서 다시 발사된 것으로 표시됨")
	frame["projectiles"] = []
	for index in range(150):
		frame["projectiles"].append([900 + index, 5.4, 4.5, 1.0, 0.0, "arrow"])
	scene._apply_frame(frame)
	frame["projectiles"] = []
	scene._apply_frame(frame)
	_check(scene._ballistic_pool["arrow"].size() == 64, "발사 수에 따라 숨긴 탄환 모델이 무한히 쌓임")
	_verify_events(scene, frame)
	var pooled: WeakRef = weakref(scene._ballistic_pool["arrow"][0])
	scene._clear_scene()
	_check(pooled.get_ref() == null and scene._ballistic_pool["arrow"].is_empty() and scene._ballistic_pool["cannon"].is_empty() and scene._generic_projectile_pool["sniper"].is_empty() and scene._generic_projectile_pool["frost"].is_empty(), "전장 초기화 시 탄환 재사용 풀 잔류")
	print("Projectile verification: %d failures; arrow unchanged, round cannonball, terminal hit, muzzle, 140ms fade, wrap, chain origin, bounded reuse, cleanup" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
