extends SceneTree

const Frost = preload("res://effects/enemy_frost.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func unit(id: int, kind: String, slowed: bool) -> Array:
	return [id, 3.5, 4.0, 0.7, 0.8, 0.62, 0.0, kind, false, slowed, false, false]


func original_surfaces(entry: Dictionary) -> Array:
	var result: Array = []
	for node: MeshInstance3D in entry["root"].find_children("*", "MeshInstance3D", true, false):
		for surface in range(node.mesh.get_surface_count()):
			var material := node.get_active_material(surface)
			result.append([node, node.mesh, surface, material, material.next_pass])
	return result


func check_surfaces(entry: Dictionary, originals: Array, active: bool) -> void:
	check(entry["root"].find_children("*", "MeshInstance3D", true, false).size() == 1, "성에 때문에 별도 몸체 메시를 추가함")
	var body_count := 0
	var core_count := 0
	for record: Array in originals:
		var mesh: MeshInstance3D = record[0]
		var original: Material = record[3]
		check(mesh.mesh == record[1], "성에 때문에 원본 적 메시 리소스를 교체/복제함")
		check(original.next_pass == record[4], "공유 원본 재질의 next_pass를 직접 변경함")
		var current := mesh.get_active_material(record[2])
		if original.resource_name.ends_with("_crystal"):
			core_count += 1
			check(current == original, "서리가 적의 원래 코어 재질을 변경함")
		elif active and original is StandardMaterial3D:
			body_count += 1
			check(current != original and current.next_pass == Frost._coat, "몸체에 공통 성에 next_pass가 적용되지 않음")
			check(current.albedo_texture == original.albedo_texture and current.normal_texture == original.normal_texture, "원본 몸체 텍스처가 변경됨")
		else:
			check(current == original, "감속 없는 적/만료된 적의 원래 재질이 복구되지 않음")
	check(core_count > 0, "코어 보존 검사 대상 누락")
	if active:
		check(body_count > 0, "성에 코팅 검사 대상 누락")


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
	scene._sync_enemies(units + [unit(11, "tank", false)])
	check(Frost._coat == null and Frost._multimeshes.is_empty(), "최초 감속 전에 공통 성에 리소스를 생성함")
	for entry: Dictionary in scene.enemies.values():
		check(not entry.has("frost"), "감속 전 불필요한 서리 인스턴스 생성")
	for i in range(kinds.size()):
		originals[i] = original_surfaces(scene.enemies[i])
	var unaffected := original_surfaces(scene.enemies[11])
	for data: Array in units:
		data[9] = true
	units.append(unit(11, "tank", false))
	scene._sync_enemies(units)
	var common_mask = Frost._coat.get_shader_parameter("rime_mask")
	check(common_mask is ImageTexture3D and common_mask.get_width() == 64 and common_mask.get_depth() == 64, "공통 3D 성에 마스크 누락")
	check(Frost._coat.get_shader_parameter("grain_texture") == Frost.GRAIN, "공통 미세 성에 텍스처 누락")
	for i in range(kinds.size()):
		var entry: Dictionary = scene.enemies[i]
		var frost: Node3D = entry["frost"]
		check(frost.visible and frost.get_parent() == entry["root"], "감속 시 원본 적에 서리가 붙지 않음: " + kinds[i])
		check(frost.transform.is_equal_approx(Transform3D.IDENTITY), "서리의 로컬 좌표/단위가 변경됨: " + kinds[i])
		check(frost.global_transform.is_equal_approx(entry["root"].global_transform), "서리가 부모 부유·방향·크기를 따르지 않음")
		check(frost.find_children("*", "MeshInstance3D", true, false).is_empty(), "종별 성에 메시 인스턴스 잔류")
		var instances := frost.find_children("*", "MultiMeshInstance3D", true, false)
		check(instances.size() == 2, "공통 결정이 두 MultiMesh를 사용하지 않음")
		check(instances[0].multimesh.instance_count == 40 and instances[1].multimesh.instance_count == 95, "승인 시안의 결정 개수 변경")
		check(instances[0].multimesh.mesh == Frost._shard_mesh and instances[1].multimesh.mesh == Frost._grain_mesh, "적 종류별 결정 원형 메시를 복제함")
		check(instances[0].material_override == Frost._ice and instances[1].material_override == Frost._grain_material, "적 종류별 결정 재질을 복제함")
		check_surfaces(entry, originals[i], true)
		check(frost.find_children("*", "AnimationPlayer", true, false).is_empty(), "감속과 무관한 서리 자체 시계 추가")
	var first: Node3D = scene.enemies[4]["frost"]
	var first_meshes := first.find_children("*", "MultiMeshInstance3D", true, false)
	check(Frost._multimeshes.size() == 6, "shieldBoss가 boss 부착 리소스를 재사용하지 않음")
	units.append(unit(10, "tank", true))
	scene._sync_enemies(units)
	var other_meshes: Array = scene.enemies[10]["frost"].find_children("*", "MultiMeshInstance3D", true, false)
	check(first_meshes.size() == other_meshes.size(), "동종 서리 메시 개수 불일치")
	for i in range(mini(first_meshes.size(), other_meshes.size())):
		check(first_meshes[i].multimesh == other_meshes[i].multimesh, "동종 적마다 MultiMesh 리소스를 복제함")
		check(first_meshes[i].material_override == other_meshes[i].material_override, "적마다 결정 재질을 복제함")
	check_surfaces(scene.enemies[11], unaffected, false)
	check(not scene.enemies[11].has("frost"), "다른 적의 감속이 비감속 적에 서리 노드를 생성함")
	units[4][9] = false
	scene._sync_enemies(units)
	check(not first.visible and scene.enemies[10]["frost"].visible, "감속 만료가 다른 적의 서리를 변경함")
	check_surfaces(scene.enemies[4], originals[4], false)
	check_surfaces(scene.enemies[11], unaffected, false)
	units[4][9] = true
	units[4][1] = 5.1
	units[4][3] = 2.8
	units[4][4] = 1.4
	units[4][5] = 1.2
	scene._sync_enemies(units)
	check(scene.enemies[4]["frost"] == first and first.visible, "감속 재적용 때 인스턴스를 재생성함")
	check_surfaces(scene.enemies[4], originals[4], true)
	check(first.global_transform.is_equal_approx(scene.enemies[4]["root"].global_transform), "이동/방향/스케일 갱신 후 서리가 분리됨")
	var paused := first.global_transform
	scene._sync_enemies(units)
	check(first.global_transform.is_equal_approx(paused), "같은 전투 입력의 서리 변환이 누적됨")
	units[4][7] = "fast"
	scene._sync_enemies(units)
	check(not is_instance_valid(first) and scene.enemies[4]["frost"].visible, "같은 ID의 적 유형 교체 때 이전 서리 잔류")
	var replaced: Node3D = scene.enemies[4]["frost"]
	units[4] = [4, 3.5, 4.0, 0.7, 0.8, 0.62, 0.0, "fast"]
	scene._sync_enemies(units)
	check(not replaced.visible, "감속 필드가 없는 이전 프레임에서 서리 잔류")
	scene._sync_enemies([])
	check(scene.enemies.is_empty() and not is_instance_valid(replaced), "적 제거 때 서리 노드 잔류")
	scene._sync_enemies([unit(20, "shieldBoss", true)])
	var reset_frost: Node3D = scene.enemies[20]["frost"]
	scene._clear_scene()
	check(not is_instance_valid(reset_frost) and scene.enemies.is_empty(), "장면 초기화 뒤 서리 잔류")
	scene.free()
	print("Enemy frost verification: %d failures" % failures)
	quit(1 if failures else 0)
