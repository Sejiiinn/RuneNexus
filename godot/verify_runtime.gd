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


func _check_landmarks(scene: Node3D, frame: Dictionary) -> void:
	var shared_frame := frame.duplicate(true)
	shared_frame["map"] = {"columns": 3, "rows": 2, "tiles": ["spawn", "build", "core", "core", "path", "spawn"]}
	shared_frame["time"] = 0.0
	scene._apply_frame(shared_frame)
	_check(scene._portals.size() == 2 and scene._cores.size() == 2, "여러 타일의 공용 포탈·코어 누락")
	var first_portal: Node3D = scene._portals[0]
	var first_vortex := first_portal.find_child("portal_vortex", true, false) as MeshInstance3D
	var second_vortex := scene._portals[1].find_child("portal_vortex", true, false) as MeshInstance3D
	_check(first_vortex != null and second_vortex != null, "독립 공용 GLB 대신 기존 포탈 사용")
	if first_vortex == null or second_vortex == null:
		return
	_check(first_vortex.mesh == second_vortex.mesh and first_vortex.material_override == second_vortex.material_override, "복수 포탈의 메시·재질이 중복 생성됨")
	var vortex_material := first_vortex.material_override as ShaderMaterial
	_check(vortex_material != null and vortex_material.shader == scene.PortalVortex, "입체 소용돌이 공유 셰이더 누락")
	var core: Dictionary = scene._cores[0]
	var core_root: Node3D = core["root"]
	var crystal: Node3D = core["crystal"]
	var crystal_mesh := crystal as MeshInstance3D
	var other_crystal := scene._cores[1]["crystal"] as MeshInstance3D
	var environment: Environment = scene.camera.get_world_3d().environment
	_check(scene.world.find_children("*", "ReflectionProbe", true, false).is_empty(), "공용 sky 반사와 불필요한 probe가 중복됨")
	_check(environment.sky == scene.ReflectionSky and environment.sky.radiance_size == Sky.RADIANCE_SIZE_128 and environment.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "공용 128px 환경 반사 누락")
	var crystal_light := scene.get_node("CoreSpecularLight") as DirectionalLight3D
	_check(crystal_light != null and crystal_light.light_cull_mask == crystal_mesh.layers and not crystal_light.shadow_enabled, "결정 전용 보조광의 레이어·그림자 비용 계약 오류")
	var crystal_light_transform := crystal_light.transform
	var crystal_size := crystal_mesh.get_aabb().size
	_check(crystal_size.y >= 0.82 and crystal_size.y / maxf(crystal_size.x, crystal_size.z) >= 2.8, "코어 결정의 길쭉한 형태·슬림 비율 누락")
	var shell_count := 0
	for surface in range(crystal_mesh.mesh.get_surface_count()):
		var material := crystal_mesh.get_active_material(surface)
		var original := crystal_mesh.mesh.surface_get_material(surface)
		if original.resource_name == "core_crystal_facets":
			var shell := material as StandardMaterial3D
			_check(shell != null and other_crystal.get_active_material(surface) == shell, "결정의 내장 PBR 공유 재질 누락")
			_check(not shell.refraction_enabled and shell.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "화면 굴절/알파 혼합이 다시 활성화됨")
			_check(shell.albedo_color == original.albedo_color and is_equal_approx(shell.roughness, original.roughness) and is_equal_approx(shell.metallic, original.metallic) and shell.emission == original.emission and shell.emission_energy_multiplier == original.emission_energy_multiplier, "내장 결정의 원본 면색/PBR/발광이 변경됨")
			_check(shell.vertex_color_use_as_albedo and not shell.vertex_color_is_srgb, "결정의 선형 정점 면색 누락")
			shell_count += 1
	_check(shell_count == 1 and crystal_mesh.mesh.get_surface_count() == 1 and crystal_mesh.get_child_count() == 0, "단일 결정 내부에 불투명 물체·표면이 남음")
	_check(crystal_mesh.mesh == other_crystal.mesh, "복수 코어 결정 메시 공유 오류")
	var rest_crystal := crystal.transform
	var rest_root := core_root.transform
	var rest_portal := first_portal.transform
	var supports := {}
	for child: Node3D in core_root.get_children():
		if child != crystal:
			supports[child] = child.transform
	# 타일 바닥과 별개인 에셋 경계·추가 조명/애니메이터 예산.
	for model: Node3D in [first_portal, core_root]:
		_check(model.find_children("*", "Light3D", true, false).is_empty(), "공용 랜드마크에 개체별 광원 추가")
		_check(model.find_children("*", "AnimationPlayer", true, false).is_empty(), "공용 랜드마크에 개체별 애니메이터 추가")
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var local := model.global_transform.affine_inverse() * mesh.global_transform
			var bounds := local * mesh.get_aabb()
			_check(bounds.position.x >= -0.49 and bounds.end.x <= 0.49 and bounds.position.z >= -0.49 and bounds.end.z <= 0.49, "랜드마크가 타일 수평 경계를 침범함: %s" % mesh.name)
			_check(bounds.position.y >= -0.001 and bounds.end.y <= 1.2, "랜드마크 바닥 원점·높이 계약 오류: %s" % mesh.name)
	shared_frame["time"] = 2.0
	shared_frame["portalAlert"] = 1.0
	shared_frame["nexusHit"] = 1.0
	scene._apply_frame(shared_frame)
	_check(first_portal.transform.is_equal_approx(rest_portal) and core_root.transform.is_equal_approx(rest_root), "포탈 석재·코어 받침 전체가 전투 반응으로 변형됨")
	_check(not crystal.transform.is_equal_approx(rest_crystal), "코어 결정 부유·회전 누락")
	for support: Node3D in supports:
		_check(support.transform.is_equal_approx(supports[support]), "결정 애니메이션이 코어 지지 구조를 움직임")
	var paused_crystal := crystal.transform
	scene._apply_frame(shared_frame)
	_check(crystal.transform.is_equal_approx(paused_crystal), "같은 전투 시각의 결정 변형 누적")
	_check(vortex_material != null and is_equal_approx(float(vortex_material.get_shader_parameter("battle_time")), 2.0), "소용돌이가 정지·배속을 결정하는 전투 시각을 따르지 않음")
	_check(scene._portals[0] == first_portal and scene._cores[0]["root"] == core_root, "같은 맵 프레임에 공용 랜드마크 재생성")
	_check(scene.camera.get_world_3d().environment.sky == environment.sky, "전투 프레임에서 공유 반사 환경이 변경됨")
	_check(crystal_light.transform.is_equal_approx(crystal_light_transform), "보조광이 결정·카메라를 따라 움직임")


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
	_check_landmarks(scene, replacement)
	var shared_texture: Texture3D = scene.field["texture"]
	scene._apply_frame({"reset": true})
	_check(scene.terrain.get_child_count() == 0 and scene.impacts.is_empty() and scene.impact_pool.is_empty(), "세션 초기화 후 전장·착탄 잔류")
	_check(scene.last_frame.is_empty() and scene.last_sequence == -1 and scene.presentation().is_empty(), "초기화 후 이전 투영·프레임 잔류")
	_check(scene.field["texture"] == shared_texture, "세션 초기화가 공유 볼륨 자산을 해제함")
	_check(not replacement.is_empty(), "세션 초기화가 전달받은 프레임 원본을 변경함")
	scene._apply_frame(frame)
	_check(scene._using_authored and scene.turrets.size() == 6 and scene.enemies.size() == 6, "새 전투 세션의 기존 자산 재사용 실패")
	print("Runtime verification: %d failures; all 6 turret/enemy/projectile types, authored/fallback terrain, shared landmarks, weapon feedback, HUD/input projection, reset" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
