extends SceneTree

## 실제 GLB의 예산·바람 입력과 공용 장면의 맵 전환·재진입 회귀 검사.
var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _verify() -> void:
	var source := FileAccess.get_file_as_bytes("res://assets/environment/dressing.glb")
	var document: Dictionary = JSON.parse_string(source.slice(20, 20 + source.decode_u32(12)).get_string_from_utf8())
	_check(document.get("meshes", []).size() == 2, "환경 장식이 병합 메시 2개 예산을 초과함")
	_check(document.get("textures", []).is_empty() and document.get("images", []).is_empty(), "환경 장식에 추가 텍스처가 포함됨")
	_check(document.get("skins", []).is_empty() and document.get("animations", []).is_empty(), "환경 장식에 런타임 스킨·키프레임 애니메이션이 포함됨")

	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	for key in ["turrets", "enemies", "projectiles", "impacts"]:
		frame[key] = []
	frame["buildPreview"] = null
	scene._apply_frame(frame)
	var dressing := scene.terrain.find_child("stage1_dressing", true, false) as Node3D
	_check(scene._using_authored and dressing != null, "일치하는 스테이지 1 지형에 환경 장식이 연결되지 않음")
	if dressing == null:
		scene.free()
		quit(1)
		return
	_check(dressing.global_transform.is_equal_approx(Transform3D.IDENTITY), "환경 장식의 월드 원점·스케일 불일치")
	var meshes := dressing.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 2, "장면에 환경 장식 메시 2개보다 많은 노드가 생성됨")
	_check(dressing.find_children("*", "AnimationPlayer", true, false).is_empty(), "환경 장식에 CPU 애니메이션 노드가 생성됨")
	_check(dressing.find_children("*", "Light3D", true, false).is_empty(), "환경 장식에 추가 광원이 생성됨")
	var triangle_count := 0
	for mesh: MeshInstance3D in meshes:
		_check(mesh.mesh.get_surface_count() == 1, "%s: 재질별 드로콜 병합 실패" % mesh.name)
		_check(mesh.get_script() == null, "%s: 개체별 CPU 갱신 스크립트가 연결됨" % mesh.name)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangle_count += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			_check(colors.size() == vertices.size(), "%s: 정점색 누락" % mesh.name)
			for color in colors:
				_check(is_equal_approx(color.a, 1.0), "%s: 불투명 정점 알파 손실" % mesh.name)
	_check(triangle_count > 0 and triangle_count <= 24000, "환경 장식이 24,000 triangle 예산을 초과함")
	var foliage := dressing.find_child("stage1_dressing_foliage", true, false) as MeshInstance3D
	var rocks := dressing.find_child("stage1_dressing_rocks", true, false) as MeshInstance3D
	_check(foliage != null and rocks != null, "풀·바위 필수 메시 누락")
	if foliage == null or rocks == null:
		scene.free()
		quit(1)
		return
	var material := foliage.get_active_material(0) as ShaderMaterial
	_check(material != null and material.shader == scene.FoliageWind, "공유 바람 셰이더 연결 실패")
	_check(foliage.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "풀의 추가 그림자 생성 패스가 활성화됨")
	_check(foliage.extra_cull_margin >= 0.022, "바람 최대 변위를 감싸는 bounds 여유 누락")
	var rock_material := rocks.get_active_material(0) as StandardMaterial3D
	_check(rock_material != null and rock_material.vertex_color_use_as_albedo, "바위의 실제 조명·정점색 재질 누락")
	if rock_material:
		_check(rock_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "바위 재질에 투명 패스가 활성화됨")
		_check(not rock_material.vertex_color_is_srgb, "바위의 선형 정점색이 sRGB로 중복 변환됨")
	var coordinates: PackedVector2Array = foliage.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var roots := 0
	var tips := 0
	var phases := {}
	for coordinate in coordinates:
		_check(coordinate.x >= 0.0 and coordinate.x <= 1.0, "풀 굽힘 가중치의 GLB 입력 범위 오류")
		_check(coordinate.y >= -0.001 and coordinate.y <= TAU + 0.001, "군락별 바람 위상의 GLB V축 변환 오류")
		if is_zero_approx(coordinate.x):
			roots += 1
		if is_equal_approx(coordinate.x, 1.0):
			tips += 1
		phases[snappedf(coordinate.y, 0.001)] = true
	_check(roots > 0 and tips > 0 and phases.size() >= 8, "고정 뿌리·움직이는 잎 끝·군락별 바람 위상 누락")
	var build_points: Array[Vector2] = []
	var tiles: Array = frame["map"]["tiles"]
	for index in range(tiles.size()):
		if tiles[index] == "build":
			build_points.append(Vector2(index % scene.columns + 0.5, floori(float(index) / scene.columns) + 0.5))
	_check(build_points.size() == 32, "중앙 풀의 건설칸 32개 계약 불일치")
	var foliage_arrays := foliage.mesh.surface_get_arrays(0)
	var removal: PackedVector2Array = foliage_arrays[Mesh.ARRAY_TEX_UV2]
	_check(removal.size() == coordinates.size(), "중앙 풀의 UV2 제거 정보 누락")
	var removable_vertices := 0
	var permanent_vertices := 0
	var foliage_vertices: PackedVector3Array = foliage_arrays[Mesh.ARRAY_VERTEX]
	for index in range(removal.size()):
		var coordinate := removal[index]
		_check(coordinate.y == 0.0 or coordinate.y == 1.0, "중앙 풀 제거 flag의 GLB V축 변환 오류")
		if coordinate.y == 1.0:
			_check(coordinate.x == roundf(coordinate.x) and coordinate.x >= 0.0 and coordinate.x < 32.0, "중앙 풀의 건설칸 슬롯 범위 오류")
			removable_vertices += 1
			if coordinate.x >= 0.0 and coordinate.x < build_points.size() and is_zero_approx(coordinates[index].x):
				var ground := Vector2(foliage_vertices[index].x + scene.columns / 2.0, foliage_vertices[index].z + scene.rows / 2.0)
				_check(ground.floor() == build_points[int(coordinate.x)].floor(), "중앙 풀의 실제 뿌리 위치와 제거 슬롯의 타일 불일치")
		else:
			permanent_vertices += 1
	_check(removable_vertices > 0 and permanent_vertices > 0, "중앙 제거 식생 또는 영구 가장자리 식생 누락")
	var foliage_indices: PackedInt32Array = foliage_arrays[Mesh.ARRAY_INDEX]
	for index in range(0, foliage_indices.size(), 3):
		var first := removal[foliage_indices[index]]
		_check(first == removal[foliage_indices[index + 1]] and first == removal[foliage_indices[index + 2]], "한 삼각형에 서로 다른 제거 슬롯·flag가 섞임")
	if failures > 0:
		scene.free()
		quit(1)
		return

	# 정지·4배속 입력·시간 되돌림에서도 노드와 자원을 그대로 유지.
	var foliage_mesh := foliage.mesh
	var rock_mesh := rocks.mesh
	var pose := foliage.transform
	var original_dressing_id := dressing.get_instance_id()
	for time in [0.0, 0.0, 0.04, 0.08, 10.0, 0.0]:
		frame["time"] = time
		scene._apply_frame(frame)
		await process_frame
		if not is_instance_valid(foliage):
			_check(false, "같은 맵의 프레임이 풀 노드를 해제함")
			scene.free()
			quit(1)
			return
		_check(foliage.transform.is_equal_approx(pose), "전투 프레임이 풀의 CPU 좌표를 갱신함")
		_check(foliage.mesh == foliage_mesh and foliage.get_active_material(0) == material, "전투 프레임마다 풀 자원이 교체됨")
		_check(scene.terrain.find_child("stage1_dressing", true, false).get_instance_id() == original_dressing_id, "같은 맵의 프레임이 장식을 재생성함")
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i.ZERO, "빈 건설칸의 중앙 풀이 숨겨짐")
	frame["buildPreview"] = [901, build_points[0].x, build_points[0].y, 0.0, 0, 0, "cannon", 1]
	scene._apply_frame(frame)
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i.ZERO, "건설 미리보기가 중앙 풀을 제거함")
	frame["buildPreview"] = null
	scene._apply_frame(frame)
	var empty_snapshot: Image
	var inspected_regions: Array[Rect2i] = []
	if DisplayServer.get_name() != "headless":
		# 바람 시계를 고정해 GPU 가림 전후를 같은 장면으로 비교.
		Engine.time_scale = 0.0
		for slot in [0, 16]:
			var minimum := Vector2(INF, INF)
			var maximum := Vector2(-INF, -INF)
			for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
				for height in [0.0, 0.4]:
					var point := Vector3(build_points[slot].x - 0.5 + corner.x - scene.columns / 2.0, height, build_points[slot].y - 0.5 + corner.y - scene.rows / 2.0)
					var screen: Vector2 = scene.camera.unproject_position(point)
					minimum = minimum.min(screen)
					maximum = maximum.max(screen)
			inspected_regions.append(Rect2i(Rect2(minimum.floor(), maximum.ceil() - minimum.floor())).intersection(Rect2i(Vector2i.ZERO, root.size)))
		await process_frame
		await RenderingServer.frame_post_draw
		empty_snapshot = root.get_texture().get_image()
	frame["turrets"] = [[902, build_points[0].x, build_points[0].y, 0.0, 0, 0, "cannon", 1]]
	scene._apply_frame(frame)
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i(1, 0), "설치한 칸 외의 중앙 풀까지 제거하거나 첫 슬롯을 누락함")
	if empty_snapshot:
		# 포탑 본체를 숨겨 풀의 실제 GPU 변위만 검사.
		scene.turrets[902]["root"].visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var occupied_snapshot := root.get_texture().get_image()
		var target_before := empty_snapshot.get_region(inspected_regions[0]).get_data()
		var target_after := occupied_snapshot.get_region(inspected_regions[0]).get_data()
		var target_max_delta := 0
		for index in range(target_before.size()):
			target_max_delta = maxi(target_max_delta, absi(int(target_before[index]) - int(target_after[index])))
		_check(target_max_delta > 1, "GPU에서 설치칸 중앙 풀이 제거되지 않음")
		var control_before := empty_snapshot.get_region(inspected_regions[1]).get_data()
		var control_after := occupied_snapshot.get_region(inspected_regions[1]).get_data()
		var control_max_delta := 0
		for index in range(control_before.size()):
			control_max_delta = maxi(control_max_delta, absi(int(control_before[index]) - int(control_after[index])))
		# 병합 메시의 일부를 접을 때 발생하는 8비트 래스터 양자화 오차만 허용.
		_check(control_max_delta <= 1, "GPU 가림이 다른 건설칸의 풀까지 변경함")
		frame["turrets"] = []
		scene._apply_frame(frame)
		await process_frame
		await RenderingServer.frame_post_draw
		var restored_snapshot := root.get_texture().get_image()
		_check(empty_snapshot.get_data() == restored_snapshot.get_data(), "GPU에서 철거 후 원래의 풀·바위 장면이 복구되지 않음")
		Engine.time_scale = 1.0
		frame["turrets"] = [[902, build_points[0].x, build_points[0].y, 0.0, 0, 0, "cannon", 1]]
		scene._apply_frame(frame)
	frame["turrets"].append([903, build_points[16].x, build_points[16].y, 0.0, 0, 0, "cannon", 1])
	scene._apply_frame(frame)
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i(1, 1), "16번째 비트 경계의 별도 건설칸 점유 누락")
	frame["turrets"][0][1] = build_points[15].x
	frame["turrets"][0][2] = build_points[15].y
	frame["turrets"][1][1] = build_points[31].x
	frame["turrets"][1][2] = build_points[31].y
	scene._apply_frame(frame)
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i(32768, 32768), "포탑 위치 변경 뒤 이전 풀이 복구되지 않거나 마지막 슬롯이 누락됨")
	for index in range(3):
		scene._apply_frame(frame)
		_check(foliage.mesh == foliage_mesh and foliage.get_active_material(0) == material and material.get_shader_parameter("occupied_build_tiles") == Vector2i(32768, 32768), "같은 점유의 반복 프레임이 풀 자원·점유 상태를 변경함")
	frame["turrets"].remove_at(0)
	scene._apply_frame(frame)
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i(0, 32768), "한 포탑 철거가 다른 칸의 가림을 해제하거나 철거한 칸을 복구하지 않음")
	frame["turrets"] = []
	scene._apply_frame(frame)
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i.ZERO, "마지막 포탑 철거 후 중앙 풀 가림 잔류")
	frame["turrets"] = [[902, build_points[0].x, build_points[0].y, 0.0, 0, 0, "cannon", 1]]
	scene._apply_frame(frame)
	var owned: WeakRef = weakref(dressing)
	scene._apply_frame({"reset": true})
	_check(owned.get_ref() == null and scene.terrain.get_child_count() == 0, "전장 초기화 후 환경 장식 노드 잔류")
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i.ZERO, "전장 초기화 후 중앙 풀 가림 잔류")
	for index in range(3):
		scene._apply_frame(frame)
		dressing = scene.terrain.find_child("stage1_dressing", true, false)
		_check(scene.terrain.find_children("stage1_dressing", "Node3D", true, false).size() == 1, "재진입 때 장식이 누락되거나 중복됨")
		foliage = dressing.find_child("stage1_dressing_foliage", true, false)
		rocks = dressing.find_child("stage1_dressing_rocks", true, false)
		_check(foliage.mesh == foliage_mesh and rocks.mesh == rock_mesh and foliage.get_active_material(0) == material, "재진입 때 공유 메시·바람 재질이 복제됨")
		_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i(1, 0), "재진입 뒤 확정 포탑의 중앙 풀 가림 복원 실패")
		var mismatched: Dictionary = frame.duplicate(true)
		# 크기가 같은 다른 맵도 원본 장식을 적용하지 않음.
		mismatched["map"]["tiles"][0] = "path" if mismatched["map"]["tiles"][0] != "path" else "build"
		owned = weakref(dressing)
		scene._apply_frame(mismatched)
		_check(not scene._using_authored and scene.terrain.find_child("stage1_dressing", true, false) == null, "다른 타일 배열에 스테이지 1 장식이 적용됨")
		_check(owned.get_ref() == null, "맵 전환 뒤 이전 장식 노드 잔류")
		_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i.ZERO, "다른 맵으로 이동한 뒤 스테이지 1 풀 가림 잔류")
	frame["turrets"] = []
	scene._apply_frame(frame)
	_check(material.get_shader_parameter("occupied_build_tiles") == Vector2i.ZERO, "포탑 없는 전장에 재진입한 뒤 중앙 풀 가림 잔류")
	var library: WeakRef = weakref(scene._dressing_library)
	scene.free()
	_check(library.get_ref() == null, "공용 장면 종료 후 환경 장식 라이브러리 잔류")
	print("Environment verification: %d failures; 2 meshes, %d triangles, 0 textures, %d wind phases; build occupancy/removal/preview, shared resources, reset/re-entry, map isolation" % [failures, triangle_count, phases.size()])
	quit(0 if failures == 0 else 1)
