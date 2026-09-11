extends SceneTree

## 즉시 명중한 탄환의 경로 표시·총구 연결·종료·재사용 검증.
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
	for pair in [[arrow, 701], [cannon, 702]]:
		var projectile: Node3D = pair[0]
		_check(projectile.visible and projectile.body.visible and projectile.nose.visible, "이동 중인 탄체·탄두가 보이지 않음")
		_check(projectile.tracer.visible and projectile.trail_length >= 0.8, "이동 궤적의 가시 길이가 부족함")
		_check(projectile.launch_position.is_equal_approx(scene.turrets[pair[1]]["shot_pose"].origin), "탄환 경로가 실제 발사 총구와 연결되지 않음")
	_check(is_equal_approx(arrow.trail_length, 0.85) and is_equal_approx(cannon.trail_length, 1.10), "예광 궤적 최대 길이 불일치")

	# live 프레임을 한 번도 받지 못한 근접 탄환. 판정점은 포신 앞쪽보다 가까움.
	frame["projectiles"].append([803, 3.8, 4.5, 1.0, 0.0, "arrow", 3.5, 4.5, 701, 1, false, 1.0, 4.4, 4.5])
	scene._apply_frame(frame)
	var completed: Node3D = scene.projectiles[803]["root"]
	_check(completed.visible and completed.tracer.visible and completed.trail_length > 0.2, "첫 화면 전에 명중한 탄환의 예광 궤적 누락")
	_check(not completed.body.visible and not completed.nose.visible, "명중한 탄체가 적을 통과해 계속 이동하는 것처럼 남음")
	_check(is_equal_approx(completed.global_position.x + scene.columns / 2.0, 4.4), "근접 사격의 경로가 실제 피격 몸체에 연결되지 않음")
	var initial_launch: Vector3 = completed.launch_position
	frame["time"] = 1.07
	frame["turrets"][0][3] = PI / 2.0
	scene._apply_frame(frame)
	_check(completed.launch_position.is_equal_approx(initial_launch), "이미 날아간 탄환의 경로가 새 조준을 따라감")
	_check(completed.opacity > 0.2 and completed.opacity < 0.5, "종료 궤적이 140ms 동안 서서히 소멸하지 않음")
	frame["time"] = 1.140001
	scene._apply_frame(frame)
	_check(not completed.visible and is_zero_approx(completed.opacity), "수명이 끝난 탄환 궤적 잔류")
	var recycled_id := completed.get_instance_id()
	frame["projectiles"] = []
	scene._apply_frame(frame)
	_check(scene.projectiles.is_empty() and scene._ballistic_pool["arrow"].size() == 2 and scene._ballistic_pool["cannon"].size() == 1, "종료 탄환 모델 재사용 풀 누락")

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
	var pooled: WeakRef = weakref(scene._ballistic_pool["arrow"][0])
	scene._clear_scene()
	_check(pooled.get_ref() == null and scene._ballistic_pool["arrow"].is_empty() and scene._ballistic_pool["cannon"].is_empty(), "전장 초기화 시 탄환 재사용 풀 잔류")
	print("Projectile verification: %d failures; visible body/tracer, terminal-only hit, muzzle, fade, wrap, chain origin, bounded reuse, cleanup" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
