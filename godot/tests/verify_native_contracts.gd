extends SceneTree

## GLB import와 코어 결정 움직임 계약. 시각 수용·Android 성능을 대신하지 않는다.
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _import_contracts(model: Node) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			_check(material != null, "GLB 표준 재질 누락: " + str(mesh.name))
			if material == null:
				continue
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			_check(normals.size() == vertices.size(), "임포트 노멀 수 불일치: " + str(mesh.name))
			var colors: Variant = arrays[Mesh.ARRAY_COLOR]
			if colors != null and not colors.is_empty():
				_check(material.vertex_color_use_as_albedo and not material.vertex_color_is_srgb, "GLB 선형 정점색 사용/이중 감마 변환 오류: " + material.resource_name)
			if material.normal_texture != null:
				var tangents: Variant = arrays[Mesh.ARRAY_TANGENT]
				var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
				_check(material.normal_enabled, "임포트 normal texture 비활성: " + material.resource_name)
				_check(uv != null and uv.size() == vertices.size(), "normal map UV 누락: " + str(mesh.name))
				_check(tangents != null and tangents.size() == vertices.size() * 4, "임포트 생성 tangent 누락: " + str(mesh.name))
			if material.roughness_texture != null:
				_check(material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN, "glTF roughness G 채널 오류: " + material.resource_name)
			if material.metallic_texture != null:
				_check(material.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE, "glTF metallic B 채널 오류: " + material.resource_name)
			if material.ao_texture != null:
				_check(material.ao_enabled and material.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED, "glTF AO R 채널 오류: " + material.resource_name)


func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var cannon: Node3D = (scene.StageResources.load_resource(scene.TURRET_MODELS["cannon"]) as PackedScene).instantiate()
	for model: Node in [scene._landmark_library, scene._terrain_library, cannon]:
		_import_contracts(model)
	cannon.free()
	var frame: Dictionary = scene.last_frame.duplicate(true)
	frame["map"] = {"columns": 3, "rows": 2, "tiles": ["spawn", "build", "core", "core", "path", "blocked"]}
	frame["time"] = 0.0
	frame["turrets"] = []
	frame["enemies"] = []
	frame["projectiles"] = []
	frame["impacts"] = []
	frame["nexusHit"] = 0.0
	frame["buildPreview"] = null
	scene.apply_frame(frame)
	_check(scene._cores.size() == 2, "다중 코어 검사 배치 실패")
	var crystal: MeshInstance3D = scene._cores[0]["crystal"]
	var supports := {}
	for entry: Dictionary in scene._cores:
		for child: Node3D in entry["root"].get_children():
			if child != entry["crystal"]:
				supports[child] = child.transform
	var rest := crystal.transform
	frame["time"] = 1.1
	frame["nexusHit"] = 0.75
	scene.apply_frame(frame)
	_check(not crystal.transform.is_equal_approx(rest), "결정 회전/부유/피격 입력 미반영")
	var paused := crystal.transform
	scene.apply_frame(frame)
	_check(crystal.transform.is_equal_approx(paused), "같은 전투 시각의 결정 변형 누적")
	for support: Node3D in supports:
		_check(support.transform.is_equal_approx(supports[support]), "결정 애니메이션이 받침을 움직임")
	print("Native import contracts: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
