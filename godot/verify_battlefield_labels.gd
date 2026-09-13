extends SceneTree

const Labels = preload("res://ui/battlefield_labels.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_verify")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _verify() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	scene.add_child(camera)
	camera.position = Vector3(0, 10, 8)
	camera.look_at(Vector3.ZERO)
	var world := Node3D.new()
	scene.add_child(world)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var labels := Labels.new()
	layer.add_child(labels)
	var enemy := {"id": 7, "position": [4.0, 3.0], "size": [26.0, 26.0], "hp": 40.0, "maxHp": 100.0, "armor": 30.0, "maxArmor": 100.0, "shield": 12.0, "maxShield": 24.0, "effectTime": 0.45, "enemyCount": 1, "burning": true, "slowed": true, "poisoned": true, "riftMarked": true, "diamondCarrier": true}
	var core := {"position": [6.5, 4.5], "progress": 0.5, "accent": 0xff8ee6ff, "active": true}
	labels.apply_frame({"logicalTileSize": 48, "enemies": [enemy], "core": core})
	labels.present(camera, Vector2(8, 6), world)
	await process_frame
	check(labels.supported_groups() == ["labels"], "원본 상태 자산 로딩 실패")
	check(labels.labels.size() == 1 and labels.core.visible, "적 정보/코어 누락")
	var node: Node2D = labels.labels[7]
	var initial := node.position
	var segments := Labels.EnemyLabel.durability_segments(enemy)
	check(segments.is_equal_approx(Vector3(0.2, 0.15, 0.5)), "HP+장갑 분모 또는 보호막 분할 변경")
	camera.position = Vector3(5, 11, 7)
	camera.look_at(Vector3.ZERO)
	world.position = Vector3(1.0, 0, 0)
	labels.present(camera, Vector2(8, 6), world)
	check(not node.position.is_equal_approx(initial), "새 프레임 없이 카메라/월드 이동 반영 실패")
	var projected := camera.unproject_position(world.to_global(Vector3(0, 0.3, 0)))
	check(node.position.is_equal_approx(projected), "타일-월드-화면 좌표 불일치")
	var scale_before := node.scale
	camera.size = 6
	labels.present(camera, Vector2(8, 6), world)
	check(node.scale.x > scale_before.x, "확대 시 표시 크기 불일치")
	labels.apply_frame({"logicalTileSize": 48, "enemies": [enemy], "core": core})
	check(labels.labels[7] == node, "동일 ID를 재생성함")
	check(is_equal_approx(float(node.data["effectTime"]), 0.45), "Godot 자체 시계로 정지한 상태 진행")
	enemy["hp"] = -10.0
	enemy["armor"] = 0.0
	enemy["maxArmor"] = 0.0
	enemy["maxHp"] = 0.0
	check(Labels.EnemyLabel.durability_segments(enemy).x == 0.0, "0 최대 체력 처리 실패")
	labels.apply_frame({"enemies": []})
	labels.present(camera, Vector2(8, 6), world)
	check(labels.labels.is_empty() and not labels.core.visible, "제거된 적/코어 잔상")
	labels.apply_frame({"enemies": [enemy]})
	labels.clear()
	check(labels.labels.is_empty() and not labels.core.visible, "장면 초기화 누락")
	print("Battlefield labels verification: %d failures" % failures)
	layer.free()
	scene.free()
	quit(1 if failures else 0)
