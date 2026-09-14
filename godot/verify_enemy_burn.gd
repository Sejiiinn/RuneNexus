extends SceneTree

const Burn = preload("res://effects/enemy_burn.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func unit(id: int, kind: String, burning: bool, slowed := false) -> Array:
	return [id, 3.5, 4.0, 0.7, 0.8, 0.62, 0.0, kind, burning, slowed, false, false]


func original_surfaces(entry: Dictionary) -> Array:
	var result: Array = []
	for node: MeshInstance3D in entry["root"].find_children("*", "MeshInstance3D", true, false):
		for surface in range(node.mesh.get_surface_count()):
			var material := node.get_active_material(surface)
			result.append([node, node.mesh, surface, material, material.next_pass])
	return result


func check_surfaces(originals: Array) -> void:
	for record: Array in originals:
		var mesh: MeshInstance3D = record[0]
		check(mesh.mesh == record[1], "화상 때문에 원본 적 메시 리소스를 교체함")
		check(mesh.get_active_material(record[2]) == record[3], "화상 때문에 원본 몸체/핵 재질을 변경함")
		check(record[3].next_pass == record[4], "화상 때문에 공유 원본 재질 next_pass를 변경함")


func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._sync_enemies([])
	var kinds := ["normal", "armored", "shielded", "fast", "tank", "boss", "shieldBoss"]
	var units: Array = []
	var originals: Dictionary = {}
	for i in range(kinds.size()):
		units.append(unit(i, kinds[i], false))
	units.append(unit(11, "tank", false))
	scene._sync_enemies(units)
	for entry: Dictionary in scene.enemies.values():
		check(not entry.has("burn"), "착화 전 불필요한 화상 노드를 생성함")
	for i in range(kinds.size()):
		originals[i] = original_surfaces(scene.enemies[i])
	var unaffected := original_surfaces(scene.enemies[11])
	for i in range(kinds.size()):
		units[i][8] = true
	scene._sync_enemies(units)
	var shared_material: Material
	for i in range(kinds.size()):
		var entry: Dictionary = scene.enemies[i]
		check(entry.has("burn"), "화상 적에 효과가 생성되지 않음: " + kinds[i])
		if not entry.has("burn"):
			continue
		var burn: MultiMeshInstance3D = entry["burn"]
		check(burn.visible and burn.get_parent() == entry["root"], "화상 효과가 원본 적에 붙지 않음")
		check(burn.transform.is_equal_approx(Transform3D.IDENTITY), "화상 로컬 좌표/단위가 변경됨")
		check(burn.global_transform.is_equal_approx(entry["root"].global_transform), "화상이 부모 부유·방향·크기를 따르지 않음")
		check(burn.multimesh.instance_count == 52, "공통 화상 입자 수가 달라짐")
		check(not burn.multimesh.custom_aabb.size.is_zero_approx(), "GPU 운동 범위의 명시적 AABB 누락")
		check(burn.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "투명 화상 입자가 그림자를 렌더함")
		check(not burn.is_processing() and not burn.is_physics_processing(), "화상에 적별 CPU 시뮬레이션을 추가함")
		check(burn.get_child_count() == 0, "단일 화상 MultiMesh 외 개별 입자/광원/애니메이션 노드 추가")
		if shared_material == null:
			shared_material = burn.material_override
		else:
			check(burn.material_override == shared_material, "적 종류별 화상 재질을 복제함")
		check_surfaces(originals[i])
	if failures:
		scene.free()
		print("Enemy burn verification: %d failures" % failures)
		quit(1)
		return
	var first: MultiMeshInstance3D = scene.enemies[4]["burn"]
	units.append(unit(10, "tank", true))
	scene._sync_enemies(units)
	var other: MultiMeshInstance3D = scene.enemies[10]["burn"]
	check(first.multimesh == other.multimesh and first.material_override == other.material_override, "동종 적마다 화상 리소스를 복제함")
	check(scene.enemies[5]["burn"].multimesh == scene.enemies[6]["burn"].multimesh, "shieldBoss가 boss 부착 데이터를 공유하지 않음")
	check(not scene.enemies[11].has("burn"), "다른 적의 화상이 비화상 적에도 효과를 생성함")
	check_surfaces(unaffected)
	Burn.set_time(4.0)
	check(is_equal_approx(shared_material.get_shader_parameter("burn_time"), 4.0), "외부 전투 시계가 shader에 전달되지 않음")
	var buffer_before: PackedFloat32Array = first.multimesh.buffer.duplicate()
	Burn.set_time(4.0)
	check(first.multimesh.buffer == buffer_before, "같은 시각의 화상 입력이 입자 변환을 CPU에서 변경함")
	Burn.set_time(0.25)
	check(is_equal_approx(shared_material.get_shader_parameter("burn_time"), 0.25), "전투 시계 역행 시 이전 화상 시각 잔류")
	check(first.multimesh.buffer == buffer_before, "전투 시각 갱신이 정적 입자 버퍼를 변경함")
	units[4][8] = false
	scene._sync_enemies(units)
	check(not first.visible and other.visible, "화상 만료가 다른 적의 효과를 변경함")
	check_surfaces(originals[4])
	units[4][8] = true
	units[4][1] = 5.1
	units[4][3] = 2.8
	units[4][4] = 1.4
	units[4][5] = 1.2
	scene._sync_enemies(units)
	check(scene.enemies[4]["burn"] == first and first.visible, "화상 재적용 때 효과를 재생성함")
	check(first.global_transform.is_equal_approx(scene.enemies[4]["root"].global_transform), "이동/방향/스케일 갱신 후 화상이 분리됨")
	units[4][9] = true
	scene._sync_enemies(units)
	var frosted := original_surfaces(scene.enemies[4])
	check(first.visible and scene.enemies[4]["frost"].visible, "화상과 냉각 동시 상태 중 한 효과가 사라짐")
	units[4][8] = false
	scene._sync_enemies(units)
	check_surfaces(frosted)
	check(scene.enemies[4]["frost"].visible, "화상 만료가 냉각 효과를 제거함")
	units[4][8] = true
	units[4][7] = "fast"
	scene._sync_enemies(units)
	check(not is_instance_valid(first) and scene.enemies[4]["burn"].visible, "같은 ID 유형 교체 후 이전 화상 잔류")
	var replaced: MultiMeshInstance3D = scene.enemies[4]["burn"]
	units[4] = [4, 3.5, 4.0, 0.7, 0.8, 0.62, 0.0, "fast"]
	scene._sync_enemies(units)
	check(not replaced.visible, "화상 필드 없는 이전 프레임에서 효과 잔류")
	scene._sync_enemies([])
	check(scene.enemies.is_empty() and not is_instance_valid(replaced), "적 제거 뒤 화상 잔류")
	scene._sync_enemies([unit(20, "shieldBoss", true)])
	var reset_burn: MultiMeshInstance3D = scene.enemies[20]["burn"]
	scene._clear_scene()
	check(not is_instance_valid(reset_burn) and scene.enemies.is_empty(), "장면 초기화 뒤 화상 잔류")
	scene.free()
	print("Enemy burn verification: %d failures" % failures)
	quit(1 if failures else 0)
