extends SceneTree

const Frost = preload("res://effects/enemy_frost.gd")
const AttachmentKind = preload("res://effects/enemy_attachment_kind.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_verify")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func unit(id: int, kind: String, slowed: bool) -> Array:
	return [id, 3.5, 4.0, 0.7, 0.8, 0.62, 0.0, kind, false, slowed, false, false]


func original_surfaces(entry: Dictionary) -> Array:
	var result: Array = []
	for node: MeshInstance3D in entry["root"].find_children("*", "MeshInstance3D", true, false):
		if node.get_parent().name in ["EnemyBurn", "EnemyFrost"]:
			continue
		for surface in range(node.mesh.get_surface_count()):
			var material := node.get_active_material(surface)
			result.append([node, node.mesh, surface, material, material.next_pass])
	return result


func check_surfaces(entry: Dictionary, originals: Array, active: bool) -> void:
	var body_meshes := {}
	for record: Array in originals:
		body_meshes[record[0]] = true
	var status_mesh_count := 2 if bool(entry.get("guardian_preview", false)) and entry.has("frost") else 0
	check(entry["root"].find_children("*", "MeshInstance3D", true, false).size() == body_meshes.size() + status_mesh_count, "성에 때문에 예상 밖 몸체 메시를 추가함")
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
			check(current != original and current.next_pass == (Frost._skinned_coats[original] if bool(entry.get("guardian_preview", false)) else Frost._coat), "몸체에 공통 성에 next_pass가 적용되지 않음")
			check(current.albedo_texture == original.albedo_texture and current.normal_texture == original.normal_texture, "원본 몸체 텍스처가 변경됨")
		else:
			check(current == original, "감속 없는 적/만료된 적의 원래 재질이 복구되지 않음")
	if bool(entry.get("guardian_preview", false)):
		if active:
			for record: Array in originals:
				if Frost._skinned_coats.has(record[3]):
					check(bool(Frost._skinned_coats[record[3]].get_shader_parameter("preserve_colored_core")), "움직이는 적의 공통 텍스처 코어 보존 누락")
	else:
		check(core_count > 0, "코어 보존 검사 대상 누락")
	if active:
		check(body_count > 0, "성에 코팅 검사 대상 누락")


func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._sync_enemies([])
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemy_frost.json"))
	for kind: String in scene.ENEMY_MODELS:
		var key := AttachmentKind.resolve(kind)
		check(definitions.has(key), "모델 지원종의 frost 부착 데이터 누락: " + kind)
		check(scene.ENEMY_MODELS.has(key) and scene.ENEMY_MODELS[kind] == scene.ENEMY_MODELS[key], "모델과 frost 부착 별칭 불일치: " + kind)
	var kinds := ["normal", "armored", "shielded", "fast", "tank", "boss", "shieldBoss", "forgeBoss"]
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
		if bool(entry.get("guardian_preview", false)):
			check(frost.visible and entry["root"].is_ancestor_of(frost), "움직이는 적에 서리가 붙지 않음")
			check(frost.find_children("*", "MeshInstance3D", true, false).size() == 2, "움직이는 적의 공통 결정 메시 누락")
			check_surfaces(entry, originals[i], true)
			continue
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
	var first: Node3D = scene.enemies[1]["frost"]
	var first_meshes := first.find_children("*", "MultiMeshInstance3D", true, false)
	check(Frost._multimeshes.size() == 6, "보스 변형이 boss 부착 리소스를 재사용하지 않음")
	var boss_meshes: Array = scene.enemies[5]["frost"].find_children("*", "MultiMeshInstance3D", true, false)
	for index in [6, 7]:
		var variant_meshes: Array = scene.enemies[index]["frost"].find_children("*", "MultiMeshInstance3D", true, false)
		for part in range(2):
			check(boss_meshes[part].multimesh == variant_meshes[part].multimesh, "보스 변형이 boss 냉각 데이터를 공유하지 않음: " + kinds[index])
	units.append(unit(10, "armored", true))
	scene._sync_enemies(units)
	var other_meshes: Array = scene.enemies[10]["frost"].find_children("*", "MultiMeshInstance3D", true, false)
	check(first_meshes.size() == other_meshes.size(), "동종 서리 메시 개수 불일치")
	for i in range(mini(first_meshes.size(), other_meshes.size())):
		check(first_meshes[i].multimesh == other_meshes[i].multimesh, "동종 적마다 MultiMesh 리소스를 복제함")
		check(first_meshes[i].material_override == other_meshes[i].material_override, "적마다 결정 재질을 복제함")
	check_surfaces(scene.enemies[11], unaffected, false)
	check(not scene.enemies[11].has("frost"), "다른 적의 감속이 비감속 적에 서리 노드를 생성함")
	units[1][9] = false
	scene._sync_enemies(units)
	check(not first.visible and scene.enemies[10]["frost"].visible, "감속 만료가 다른 적의 서리를 변경함")
	check_surfaces(scene.enemies[1], originals[1], false)
	check_surfaces(scene.enemies[11], unaffected, false)
	units[1][9] = true
	units[1][1] = 5.1
	units[1][3] = 2.8
	units[1][4] = 1.4
	units[1][5] = 1.2
	scene._sync_enemies(units)
	check(scene.enemies[1]["frost"] == first and first.visible, "감속 재적용 때 인스턴스를 재생성함")
	check_surfaces(scene.enemies[1], originals[1], true)
	check(first.global_transform.is_equal_approx(scene.enemies[1]["root"].global_transform), "이동/방향/스케일 갱신 후 서리가 분리됨")
	var paused := first.global_transform
	scene._sync_enemies(units)
	check(first.global_transform.is_equal_approx(paused), "같은 전투 입력의 서리 변환이 누적됨")
	units[1][7] = "fast"
	scene._sync_enemies(units)
	check(not is_instance_valid(first) and scene.enemies[1]["frost"].visible, "같은 ID의 적 유형 교체 때 이전 서리 잔류")
	var replaced: Node3D = scene.enemies[1]["frost"]
	units[1] = [1, 3.5, 4.0, 0.7, 0.8, 0.62, 0.0, "fast"]
	scene._sync_enemies(units)
	check(not replaced.visible, "감속 필드가 없는 이전 프레임에서 서리 잔류")
	scene._sync_enemies([])
	check(scene.enemies.is_empty() and not is_instance_valid(replaced), "적 제거 때 서리 노드 잔류")
	scene._sync_enemies([unit(20, "shieldBoss", true)])
	var reset_frost: Node3D = scene.enemies[20]["frost"]
	scene._clear_scene()
	check(not is_instance_valid(reset_frost) and scene.enemies.is_empty(), "장면 초기화 뒤 서리 잔류")
	check_boss_lifecycle(scene)
	scene.free()
	print("Enemy frost checks: %d" % checks)
	print("Enemy frost verification: %d failures" % failures)
	quit(1 if failures else 0)


func check_boss_lifecycle(scene: Node3D) -> void:
	for kind: String in ["boss", "shieldBoss", "forgeBoss"]:
		scene._sync_enemies([unit(81, kind, false)])
		var entry: Dictionary = scene.enemies[81]
		var originals := original_surfaces(entry)
		scene._sync_enemies([unit(81, kind, true)])
		var frost: Node3D = entry["frost"]
		check(frost.visible and not entry.has("burn"), kind + " 최초 냉각 단독 적용")
		check_surfaces(entry, originals, true)
		scene._sync_enemies([unit(81, kind, false)])
		check(not frost.visible, kind + " 냉각 해제")
		check_surfaces(entry, originals, false)
		scene._sync_enemies([unit(81, kind, true)])
		check(entry["frost"] == frost and frost.visible, kind + " 냉각 재적용 리소스 재사용")
		check_surfaces(entry, originals, true)
		scene._sync_enemies([])
		check(not is_instance_valid(frost), kind + " 제거 시 냉각 노드 정리")
		scene._sync_enemies([unit(81, kind, true)])
		var reset_root: Node3D = scene.enemies[81]["root"]
		scene._apply_frame({"sceneEpoch": scene._scene_epoch + 1, "reset": true})
		check(scene.enemies.is_empty() and not is_instance_valid(reset_root), kind + " epoch reset 시 냉각 노드 정리")
		print("Boss frost lifecycle: ", kind, " first/expire/reapply/remove/epoch reset checked")
