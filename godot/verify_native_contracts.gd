extends SceneTree

## 검수 후보 고유 계약. 시각 수용·Android 성능을 대신하지 않는다.
const Native = preload("res://verify_native_materials.gd")
var failures := 0
var checks := 0
var report := {"materials": [], "shared_candidate": {}, "visual_acceptance": "not assessed by headless contracts"}


func _initialize() -> void:
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _stored(material: StandardMaterial3D) -> Dictionary:
	var result := {}
	for property: Dictionary in material.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			result[property["name"]] = material.get(property["name"])
	return result


func _candidate_contract(source: StandardMaterial3D) -> StandardMaterial3D:
	var before := _stored(source)
	var native := Native.candidate(source)
	_check(native != source, "후보가 원본 재질을 직접 변경함")
	var changed: Array[String] = []
	var textures := 0
	for property: String in before:
		var original: Variant = before[property]
		var value: Variant = native.get(property)
		_check(source.get(property) == original, "후보 생성이 원본을 변경함: %s/%s" % [source.resource_name, property])
		if original != value:
			changed.append(property)
		if property == "resource_name":
			_check(value == "core_glass_candidate", "검수 후보 식별 이름 오류")
		elif property == "refraction_enabled":
			_check(value == true, "내장 굴절 활성화 누락")
		elif property == "refraction_scale":
			_check(is_equal_approx(value, 0.05), "명시한 엔진 굴절 설정 변경")
		elif property == "albedo_color":
			_check(Vector3(value.r, value.g, value.b) == Vector3(original.r, original.g, original.b) and is_equal_approx(value.a, 0.65), "원본 면색 RGB 또는 명시한 엔진 알파 오류")
		else:
			_check(value == original, "원본 storage 속성 보존 실패: %s/%s" % [source.resource_name, property])
		if original is Texture:
			textures += 1
			_check(value == original, "후보가 원본 텍스처를 중복 생성함: " + property)
	report["materials"].append({"source": Native.material_data(source), "candidate": Native.material_data(native), "storage_properties": before.size(), "changed_properties": changed, "shared_texture_properties": textures})
	return native


func _import_contracts(model: Node, tested: Dictionary) -> void:
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
			# 텍스처 없는 코어만으로는 원본 텍스처 공유/채널 보존을 검증할 수 없다.
			if not tested.has(material):
				tested[material] = true
				_candidate_contract(material)


func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var tested := {}
	var cannon: Node3D = scene.TURRET_MODELS["cannon"].instantiate()
	for model: Node in [scene._landmark_library, scene._terrain_library, cannon]:
		_import_contracts(model, tested)
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
	scene._apply_frame(frame)
	_check(scene._cores.size() == 2, "내장 후보의 다중 코어 검사 배치 실패")
	var crystal: MeshInstance3D = scene._cores[0]["crystal"]
	var source := crystal.mesh.surface_get_material(0) as StandardMaterial3D
	var before := _stored(source)
	var native := Native.candidate(source)
	var supports := {}
	for entry: Dictionary in scene._cores:
		entry["crystal"].set_surface_override_material(0, native)
		for child: Node3D in entry["root"].get_children():
			if child != entry["crystal"]:
				supports[child] = child.transform
	var rest := crystal.transform
	frame["time"] = 1.1
	frame["nexusHit"] = 0.75
	scene._apply_frame(frame)
	_check(not crystal.transform.is_equal_approx(rest), "내장 후보에서 결정 회전/부유/피격 입력 미반영")
	var paused := crystal.transform
	scene._apply_frame(frame)
	_check(crystal.transform.is_equal_approx(paused), "내장 후보에서 같은 전투 시각의 결정 변형 누적")
	for support: Node3D in supports:
		_check(support.transform.is_equal_approx(supports[support]), "내장 후보 애니메이션이 받침을 움직임")
	for entry: Dictionary in scene._cores:
		var instance: MeshInstance3D = entry["crystal"]
		_check(instance.get_active_material(0) == native and instance.mesh == crystal.mesh, "전투 프레임 뒤 내장 후보 재질/메시 공유 해제")
		_check(instance.mesh.surface_get_material(0) == source, "후보 override가 원본 mesh surface 재질을 변경함")
	_check(_stored(source) == before, "다중 코어/애니메이션 검사 뒤 GLB 원본 변경")
	report["shared_candidate"] = {"instances": scene._cores.size(), "material_instances": 1, "rest_transform": str(rest), "animated_transform": str(paused), "supports_checked": supports.size(), "source_unchanged": _stored(source) == before}
	report["engine"] = Engine.get_version_info()
	report["landmarks_sha256"] = FileAccess.get_sha256("res://assets/environment/landmarks.glb")
	report["checks"] = checks
	report["failures"] = failures
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file := FileAccess.open(argument.trim_prefix("--output="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Native candidate contracts: %d checks, %d failures; original storage, texture identity, linear vertex color, normal/tangent/channels, shared candidate animation" % [checks, failures])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
