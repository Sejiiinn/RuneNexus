extends SceneTree

## 기관총 명중의 3D 도탄 불티 라우팅·슬롯 수명·실제 전투 페이로드 회귀 검사.
const Ricochet = preload("res://effects/machinegun_ricochet.gd")
const EffectFormat = preload("res://combat/effect_presentation.gd")
var failures := 0
var checks := 0
var clock := {"usec": 1000000}


func _initialize() -> void:
	# Dummy 렌더러는 MultiMesh 인스턴스 읽기를 제공하지 않음.
	if DisplayServer.get_name() == "headless":
		push_error("도탄 불티 MultiMesh 검사는 실제 렌더러가 필요합니다. --headless 없이 실행하세요.")
		quit(1)
		return
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _hit(id: int, age: float, x := 3.0, direction := [1.0, 0.0], target := 7) -> Dictionary:
	return {"id": id, "kind": "impact", "style": "spark", "turretType": "arrow", "x": x, "y": 5.0,
		"direction": direction, "targetId": target, "age": age, "duration": 0.28}


func _verify() -> void:
	_verify_routing()
	_verify_slots()
	await _verify_native_battle()
	print("MACHINEGUN_RICOCHET checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _verify_routing() -> void:
	_check(EffectFormat.is_spatial_ricochet(_hit(1, 0.0)), "기관총 명중이 3D 도탄으로 라우팅되지 않음")
	var sniper := _hit(2, 0.0)
	sniper.erase("turretType")
	sniper.erase("direction")
	_check(not EffectFormat.is_spatial_ricochet(sniper), "저격 명중의 2D 섬광이 3D 도탄으로 바뀜")
	var undirected := _hit(3, 0.0)
	undirected.erase("direction")
	_check(not EffectFormat.is_spatial_ricochet(undirected), "방향 없는 명중을 3D 도탄으로 처리함")
	var effects = load("res://ui/battlefield_effects.gd").new()
	_check(effects._canvas_effect(_hit(4, 0.0)), "전용 표시가 없는 캔버스는 기존 2D 섬광을 유지해야 함")
	effects.spatial_ricochet = true
	_check(not effects._canvas_effect(_hit(4, 0.0)), "3D 도탄 사용 시 기관총 2D 섬광이 중복 표시됨")
	_check(effects._canvas_effect(sniper), "3D 도탄 사용 시 저격 2D 섬광이 사라짐")
	effects.free()


func _verify_slots() -> void:
	var effect: Node3D = Ricochet.new()
	root.add_child(effect)
	var size := Vector2(8, 10)
	effect.present([_hit(10, 0.02)], [], size, 50.0, true)
	_check(effect.visible and int(effect.active.get(10, -1)) == 0, "새 명중이 슬롯을 받지 못함")
	var custom: Color = effect.sparks.multimesh.get_instance_custom_data(0)
	_check(is_equal_approx(custom.r, -0.02), "불티 시작 시각이 명중 age를 반영하지 않음: %s" % custom)
	var pose: Transform3D = effect.sparks.multimesh.get_instance_transform(0)
	_check(pose.basis.z.is_equal_approx(Vector3.LEFT) and is_equal_approx(pose.origin.y, Ricochet.HEIGHT), "불티가 탄이 들어온 반대 방향을 향하지 않음: %s" % pose)
	_check(is_equal_approx(pose.origin.x, -1.0 - 0.02), "명중점의 맵 중심 변환 불일치: %s" % pose.origin)
	_check(effect.lights[0].visible and effect.lights[0].light_energy > 0.0, "명중 직후 표면광 없음")
	# 같은 이벤트의 이후 프레임은 자세·시작 시각을 다시 쓰지 않는다.
	effect.sparks.multimesh.set_instance_custom_data(0, Color(123, 0, 0, 0))
	effect.present([_hit(10, 0.06)], [], size, 50.04, true)
	_check(is_equal_approx(effect.sparks.multimesh.get_instance_custom_data(0).r, 123.0), "같은 명중을 매 프레임 다시 생성함")
	_check(is_equal_approx(float(effect.spark_material.get_shader_parameter("u_time")), 0.04), "공유 시계 전달 불일치")
	# 차선 오프셋은 맞은 몸체의 표시 위치만 더한다.
	var row := [7, 3.2, 5.1, 0, 0, 1, 0, "normal", false, false, false, false, 3.0, 5.0]
	effect.present([_hit(10, 0.08), _hit(11, 0.0)], [row], size, 50.06, true)
	var lane: Transform3D = effect.flares.multimesh.get_instance_transform(1)
	_check(is_equal_approx(lane.origin.x, -0.8 - 0.05) and is_equal_approx(lane.origin.z, 0.1), "차선 표시 오프셋 미반영: %s" % lane.origin)
	# 재연결 등으로 수명이 지난 뒤 처음 도착한 이벤트는 재생하지 않는다.
	effect.present([_hit(12, Ricochet.SPARK_LIFE + 0.01)], [], size, 50.1, true)
	_check(int(effect.active.get(12, 0)) == -1 and effect.next_slot == 2, "수명이 지난 명중을 재생함")
	_check(not effect.active.has(10) and not effect.active.has(11), "사라진 이벤트의 ID가 남음")
	effect.present([], [], size, 50.3, true)
	_check(effect.lights.all(func(lamp): return not lamp.visible), "명중 뒤 표면광 잔류")
	# 고정 풀은 가장 오래된 슬롯부터 덮어쓴다.
	var burst: Array = []
	for index in range(Ricochet.SLOTS + 1): burst.append(_hit(100 + index, 0.0))
	effect.present(burst, [], size, 50.4, true)
	_check(int(effect.active[100 + Ricochet.SLOTS]) == 2 and effect.next_slot == 3, "풀 순환 슬롯 불일치")
	# 시계 되감기·비활성화는 이전 불티를 이어 그리지 않는다.
	effect.present([_hit(200, 0.0)], [], size, 10.0, true)
	_check(effect.active.size() == 1 and int(effect.active[200]) == 0, "되감기 뒤 이전 슬롯 유지")
	var stale := 0
	for index in range(1, Ricochet.SLOTS):
		if effect.flares.multimesh.get_instance_custom_data(index).r > Ricochet.INACTIVE: stale += 1
	_check(stale == 0, "되감기 뒤 이전 섬광 %d개 잔류" % stale)
	_check(effect.sparks.visible and effect.flares.visible, "살아 있는 명중의 불티가 숨겨짐")
	# 상대 시계 재기준 뒤 이전 슬롯이 GPU에서 다시 재생되지 않는다.
	effect.present([], [], size, 700.0, true)
	_check(is_zero_approx(float(effect.flare_material.get_shader_parameter("u_time"))), "600초 뒤 상대 시계가 재기준되지 않음")
	_check(effect.flares.multimesh.get_instance_custom_data(0).r <= Ricochet.INACTIVE and effect.sparks.multimesh.get_instance_custom_data(0).r <= Ricochet.INACTIVE, "재기준 뒤 이전 슬롯 시작 시각이 남아 다시 재생됨")
	effect.present([], [], size, 710.0, true)
	_check(not effect.sparks.visible and not effect.flares.visible, "살아 있는 명중이 없는데 불티 MultiMesh를 그림")
	effect.present([_hit(200, 0.0)], [], size, 710.0, false)
	_check(not effect.visible and effect.active.is_empty(), "비활성 표시에서 도탄 유지")
	effect.free()


func _verify_native_battle() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	scene._session_now_usec = func(): return clock.usec
	root.add_child(scene)
	await process_frame
	var app = load("res://session/standalone.gd").new()
	app.content_enabled = false
	scene._standalone_session = app
	scene.add_child(app)
	await process_frame
	app.fixture.turret.definition.attackRate = 6.0
	var map: Dictionary = app.fixture.stages[0].map
	for index in range(map.tiles.size()):
		if map.tiles[index] == "build" and Vector2(index % int(map.columns) + .5, index / int(map.columns) + .5).distance_to(Vector2(4.5, 4.5)) < 1.2:
			app.board_tap(Vector2i(index % int(map.columns), index / int(map.columns)))
			break
	app.build_selected()
	app.start_wave()
	var effects = scene._presentation_nodes["effects"]
	var found := {}
	for frame in range(1200):
		clock.usec += 16667
		await process_frame
		for item: Dictionary in effects.items:
			if item.get("kind") == "impact" and item.get("style") == "spark":
				found = item
				break
		if not found.is_empty(): break
	_check(not found.is_empty(), "고정 전투에서 기관총 명중이 발생하지 않음")
	if not found.is_empty():
		var direction: Array = found.get("direction", [])
		_check(found.get("turretType") == "arrow" and direction.size() == 2 and Vector2(direction[0], direction[1]).is_normalized(), "기관총 명중에 탄 방향이 없음: %s" % found)
		_check(scene._native_combat.enemies.has(str(found.get("targetId"))), "명중 대상 ID 불일치: %s" % found)
		_check(not effects._canvas_effect(found), "본게임에서 기관총 2D 섬광이 계속 표시됨")
		_check(scene._machinegun_ricochet.active.has(int(found.id)), "본게임 명중이 3D 도탄으로 표시되지 않음")
	scene.queue_free()
	await process_frame
