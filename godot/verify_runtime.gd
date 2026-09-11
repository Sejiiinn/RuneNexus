extends SceneTree

## 실제 전투 계약의 모델 유형·HUD 투영·발사·맵 교체·세션 초기화 회귀 검사.
var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _vector(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


func _check_projection(scene: Node3D, frame: Dictionary) -> void:
	var presentation: Dictionary = scene.presentation()
	var projection: Dictionary = presentation["projection"]
	var origin := _vector(projection["origin"])
	var x_axis := _vector(projection["xAxis"])
	var y_axis := _vector(projection["yAxis"])
	var height_axis := _vector(projection["heightAxis"])
	var viewport := root.get_visible_rect().size
	for point: Vector3 in [Vector3(1.5, 0.0, 2.5), Vector3(6.5, 0.8, 8.5), Vector3(3.2, 0.3, 4.1)]:
		var affine := origin + x_axis * point.x + y_axis * point.z + height_axis * point.y
		var actual: Vector2 = scene.camera.unproject_position(point - Vector3(scene.columns / 2.0, 0.0, scene.rows / 2.0)) / viewport
		_check(affine.distance_to(actual) < 0.00001, "HUD의 월드 좌표 투영과 실제 카메라 불일치")
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var tiles: Array = frame["map"]["tiles"]
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
			var point: Vector2 = origin + x_axis * (float(index % scene.columns) + corner.x) \
				+ y_axis * (floor(float(index) / scene.columns) + corner.y)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	var target := _vector(frame["screenCenter"]) / _vector(frame["viewport"])
	_check(((minimum + maximum) / 2.0).distance_to(target) < 0.00001, "전장 경계 중심과 Flutter HUD 가용 영역 중심 불일치: actual=%s target=%s viewport=%s offset=(%s, %s) size=%s" % [(minimum + maximum) / 2.0, target, viewport, scene.camera.h_offset, scene.camera.v_offset, scene.camera.size])
	_check(int(presentation["sequence"]) == int(frame["seq"]), "렌더 투영의 전투 프레임 번호 불일치")
	var determinant := x_axis.x * y_axis.y - x_axis.y * y_axis.x
	var selected := Vector2(5.5, 3.5)
	var screen := x_axis * selected.x + y_axis * selected.y
	var restored := Vector2(screen.x * y_axis.y - screen.y * y_axis.x, x_axis.x * screen.y - x_axis.y * screen.x) / determinant
	_check(restored.distance_to(selected) < 0.00001, "Godot 투영으로 터치 타일 역변환 실패")


func _verify() -> void:
	root.size = Vector2i(880, 760)
	root.content_scale_size = Vector2i(440, 380)
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	_check(scene._using_authored, "원본 스테이지 1 GLB 통합 지형 미사용")
	_check(scene.terrain.find_child("stage1_environment", true, false) != null, "원본 통합 지형 노드 누락")
	frame["viewport"] = [440.0, 380.0]
	frame["screenCenter"] = [200.0, 165.0]
	frame["pixelsPerTile"] = 25.0
	frame["zoom"] = 1.15
	frame["seq"] = 31
	frame["time"] = 1.0
	frame["turrets"] = []
	frame["enemies"] = []
	frame["projectiles"] = []
	var turret_types: Array = scene.TURRET_MODELS.keys()
	var enemy_types: Array = scene.ENEMY_MODELS.keys()
	for index in range(6):
		frame["turrets"].append([index, index + 1.5, 3.5, 0.2 * index, 0, 0, turret_types[index], 2])
		frame["enemies"].append([index + 10, index + 1.5, 5.5, 0.3 * index, 0.5, 1.25, 0.4, enemy_types[index], true, true, true, true])
		frame["projectiles"].append([index + 20, index + 1.5, 4.5, 1.0, 0.5, turret_types[index]])
	frame["buildPreview"] = [100, 2.5, 6.5, 0.3, 10, 1, "sniper", 1]
	frame["impacts"] = [[100, 4.5, 5.5, 1.2, 0.52]]
	scene._apply_frame(frame)
	_check(scene.turrets.size() == 6 and scene.enemies.size() == 6 and scene.projectiles.size() == 6, "실제 6종 전투 모델 누락")
	for index in range(6):
		var turret: Node3D = scene.turrets[index]["root"]
		var enemy: Node3D = scene.enemies[index + 10]["root"]
		var projectile: Node3D = scene.projectiles[index + 20]["root"]
		_check(turret.scene_file_path == "res://assets/turrets/%s.glb" % turret_types[index], "포탑 유형별 원본 GLB 불일치")
		_check(enemy.scene_file_path == "res://assets/enemies/%s.glb" % enemy_types[index], "적 유형별 원본 GLB 불일치")
		_check(turret.position.distance_to(Vector3(index + 1.5 - scene.columns / 2.0, 0.0, 3.5 - scene.rows / 2.0)) < 0.0001, "포탑 전투 좌표 변환 실패")
		_check(enemy.scale.is_equal_approx(Vector3.ONE * 1.25), "적 원본 크기 배율 미적용")
		_check(projectile.global_basis.z.normalized().dot(Vector3(1.0, 0.0, 0.5).normalized()) > 0.9999, "탄환 방향 변환 실패")
		_check(projectile.get_child_count() == 3, "탄환 본체·탄두·예광 표현 누락")
	_check_projection(scene, frame)
	var preview: Dictionary = scene._build_preview
	_check(preview["type"] == "sniper" and preview["root"].position.y > 0.08, "건설 미리보기 원본 유형·부유 위치 실패")
	for flash: MeshInstance3D in preview["flashes"]:
		_check(not flash.visible, "건설 미리보기가 발사 이펙트를 표시함")
	var cannon: Dictionary = scene.turrets[1]
	var original_cannon: Node3D = cannon["root"]
	var original_enemy: Node3D = scene.enemies[10]["root"]
	var original_projectile: Node3D = scene.projectiles[20]["root"]
	frame["turrets"][1][4] = 1
	frame["turrets"][1][5] = 1.0
	scene._apply_frame(frame)
	_check(cannon["flashes"][1].visible and cannon["smokes"][1].visible, "발사 순번에 따른 포구·연기 재생 실패")
	frame["time"] = 1.018
	scene._apply_frame(frame)
	_check(is_equal_approx(cannon["barrel"].position.z, float(cannon["barrel_rest_z"]) - 0.12), "포신 최대 반동 위치 실패")
	_check(scene.turrets[1]["root"] == original_cannon and scene.enemies[10]["root"] == original_enemy and scene.projectiles[20]["root"] == original_projectile, "연속 프레임에서 기존 모델을 재생성함")
	frame["time"] = 1.7
	scene._apply_frame(frame)
	_check(not cannon["flashes"][1].visible and not cannon["smokes"][1].visible, "종료한 발사 이펙트 잔류")
	_check(is_equal_approx(cannon["barrel"].position.z, float(cannon["barrel_rest_z"])), "발사 후 포신 복귀 실패")
	var first_x := _vector(scene.presentation()["projection"]["xAxis"])
	frame["zoom"] = 1.725
	scene._apply_frame(frame)
	var zoomed_x := _vector(scene.presentation()["projection"]["xAxis"])
	_check(is_equal_approx(zoomed_x.length() / first_x.length(), 1.5), "실제 전투 확대 비율 실패")
	_check_projection(scene, frame)
	scene.options["camera"] = "drone"
	scene._apply_options()
	var transition: Tween = scene.camera_transition
	transition.pause()
	transition.custom_step(0.21)
	_check_projection(scene, frame)
	transition.custom_step(0.49)
	_check_projection(scene, frame)
	_check(_vector(scene.presentation()["projection"]["xAxis"]).y < 0.00001, "드론 시점의 가로축 회전 오류")
	# 화면 비율 변경에도 동일한 논리 뷰포트 계약을 사용.
	root.size = Vector2i(900, 1600)
	root.content_scale_size = Vector2i(450, 800)
	await process_frame
	frame["viewport"] = [450.0, 800.0]
	frame["screenCenter"] = [225.0, 310.0]
	scene._apply_frame(frame)
	_check_projection(scene, frame)
	var replacement: Dictionary = frame.duplicate(true)
	replacement["map"] = {"columns": 3, "rows": 2, "tiles": ["spawn", "path", "core", "build", "blocked", "build"]}
	replacement["seq"] = 32
	replacement["turrets"] = []
	replacement["enemies"] = []
	replacement["projectiles"] = []
	replacement["impacts"] = []
	replacement["buildPreview"] = null
	scene._apply_frame(replacement)
	_check(not scene._using_authored and scene.terrain.get_child_count() == 7, "다른 맵의 원본 타일 기반 재구성 실패")
	_check(scene.turrets.is_empty() and scene.enemies.is_empty() and scene.projectiles.is_empty() and scene._build_preview.is_empty(), "삭제된 전투 모델 잔류")
	_check(scene.impacts.is_empty() and scene.impact_pool.size() == 1, "종료한 착탄 효과 재사용 풀 이동 실패")
	_check_projection(scene, replacement)
	var shared_texture: Texture3D = scene.field["texture"]
	scene._apply_frame({"reset": true})
	_check(scene.terrain.get_child_count() == 0 and scene.impacts.is_empty() and scene.impact_pool.is_empty(), "세션 초기화 후 전장·착탄 잔류")
	_check(scene.last_frame.is_empty() and scene.last_sequence == -1 and scene.presentation().is_empty(), "초기화 후 이전 투영·프레임 잔류")
	_check(scene.field["texture"] == shared_texture, "세션 초기화가 공유 볼륨 자산을 해제함")
	_check(not replacement.is_empty(), "세션 초기화가 전달받은 프레임 원본을 변경함")
	scene._apply_frame(frame)
	_check(scene._using_authored and scene.turrets.size() == 6 and scene.enemies.size() == 6, "새 전투 세션의 기존 자산 재사용 실패")
	print("Runtime verification: %d failures; all 6 turret/enemy/projectile types, authored/fallback terrain, weapon feedback, HUD/input projection, reset" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
