extends SceneTree

## 실제 프레임 경로의 화염 포탑 조준·정지·탄환 위치·풀·장면 초기화 검증.
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
	frame["turrets"] = [[701, 3.5, 3.5, 0.0, 0, 0.0, "magic", 1]]
	frame["enemies"] = []
	frame["projectiles"] = []
	frame["impacts"] = []
	frame["buildPreview"] = null
	frame["seq"] = 900
	frame["time"] = 2.0
	scene._apply_frame(frame)
	var turret: Dictionary = scene.turrets[701]
	_check(turret.has("fire_effect") and turret["flashes"].is_empty(), "화염 전용 내장 효과 대신 이전 atlas 사용")
	_check(turret["flame_port"] != null and turret["muzzle"] != null, "원본 화구 마커 누락")
	var rest_height: float = turret["barrel"].position.y
	frame["turrets"][0][4] = 1
	frame["turrets"][0][5] = 1.0
	frame["seq"] += 1
	frame["time"] = 2.05
	scene._apply_frame(frame)
	_check(turret.has("shot_pose"), "실제 총구 발사 포즈 기록 누락")
	_check(is_equal_approx(turret["barrel"].position.y, rest_height), "반동이 원본 포신 높이를 변경")
	var transforms := {}
	for mesh: MeshInstance3D in turret["root"].find_children("*", "MeshInstance3D", true, false):
		transforms[mesh] = mesh.global_transform
	scene._apply_frame(frame)
	for mesh: MeshInstance3D in transforms:
		_check(mesh.global_transform.is_equal_approx(transforms[mesh]), "같은 전투 시각의 불꽃/포탑 변형 누적")
	frame["seq"] += 1
	frame["time"] = 2.08
	frame["projectiles"] = [[801, 5.1, 3.5, 1.0, 0.0, "magic", 3.8, 3.5, 701, 1, false, -1.0, null, null]]
	scene._apply_frame(frame)
	var projectile: Node3D = scene.projectiles[801]["root"]
	var expected := Vector3(5.1 - scene.columns / 2.0, 0.45, 3.5 - scene.rows / 2.0)
	_check(projectile.global_position.is_equal_approx(expected), "화염 탄환이 실제 전투 위치에서 이탈")
	_check(scene.projectiles[801]["launch_position"].is_equal_approx(turret["shot_pose"].origin), "발사 화구와 탄환 시작점 분리")
	frame["projectiles"][0][11] = 2.08
	frame["projectiles"][0][12] = 5.3
	frame["projectiles"][0][13] = 3.6
	frame["seq"] += 1
	frame["time"] = 2.10
	scene._apply_frame(frame)
	_check(is_equal_approx(projectile.global_position.x, 5.3 - scene.columns / 2.0) and is_equal_approx(projectile.global_position.z, 3.6 - scene.rows / 2.0), "종료 잔불이 실제 적 명중 위치를 따르지 않음")
	frame["projectiles"] = []
	frame["seq"] += 1
	scene._apply_frame(frame)
	_check(scene._fire_projectile_pool.size() == 1, "화염 탄환 풀 반환 누락")
	frame["projectiles"] = [[802, 6.0, 4.0, 1.0, 0.0, "magic", 5.5, 4.0, null, 0, true, -1.0, null, null]]
	frame["seq"] += 1
	frame["time"] = 2.12
	scene._apply_frame(frame)
	_check(scene.projectiles[802]["root"] == projectile, "화염 탄환 재사용 대신 새 효과 생성")
	_check(scene.projectiles[802]["launch_position"].is_equal_approx(Vector3(5.5 - scene.columns / 2.0, 0.45, 4.0 - scene.rows / 2.0)), "연쇄 탄환에 이전 총구 포즈 잔존")
	frame["seq"] += 1
	frame["time"] = 0.1
	frame["turrets"][0][4] = 0
	frame["turrets"][0][5] = 0.0
	scene._apply_frame(frame)
	_check(not turret.has("shot_pose"), "시간 역행 뒤 이전 발사 포즈 잔존")
	scene._clear_scene()
	_check(scene.turrets.is_empty() and scene.projectiles.is_empty() and scene._fire_projectile_pool.is_empty(), "장면 초기화 뒤 화염 효과 잔존")
	print("Runic fire runtime integration failures: %d" % failures)
	scene.free()
	quit(1 if failures else 0)
