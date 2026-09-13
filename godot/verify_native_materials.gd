extends RefCounted

## 검수 전용. 본게임 재질 선택·저장·조명에는 연결하지 않는다.
static func candidate(source: StandardMaterial3D) -> StandardMaterial3D:
	# 원본 전체 PBR/UV/채널/정점색을 유지한 얕은 복제: 텍스처는 공유.
	var material := source.duplicate() as StandardMaterial3D
	material.resource_name = "core_glass_candidate"
	material.refraction_enabled = true
	material.refraction_scale = 0.05
	# 엔진의 화면 혼합 설정. Transmission/IOR로부터 계산한 값이 아니다.
	material.albedo_color.a = 0.65
	return material


static func material_data(material: Material) -> Dictionary:
	var data := {"name": material.resource_name, "class": material.get_class()}
	if material is StandardMaterial3D:
		for property in ["albedo_color", "metallic", "roughness", "normal_enabled", "normal_scale", "ao_enabled", "emission_enabled", "emission", "emission_energy_multiplier", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "transparency", "cull_mode", "refraction_enabled", "refraction_scale", "roughness_texture_channel", "metallic_texture_channel", "ao_texture_channel"]:
			data[property] = str(material.get(property))
		for property in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture", "ao_texture", "emission_texture"]:
			var texture: Texture2D = material.get(property)
			data[property] = null if texture == null else {"path": texture.resource_path, "size": str(texture.get_size())}
	return data


static func run(scene: Node3D, output: String) -> bool:
	var tree := scene.get_tree()
	scene.set_process(false)
	DirAccess.make_dir_recursive_absolute(output)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	if frame.is_empty():
		frame = JSON.parse_string(FileAccess.get_file_as_string("res://assets/preview_frame.json"))
		scene._apply_frame(frame)
	var crystal := scene._cores[0]["crystal"] as MeshInstance3D
	var core: Node3D = scene._cores[0]["root"]
	var source := crystal.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null or source.resource_name != "core_crystal_facets" or crystal.mesh.get_surface_count() != 1:
		push_error("내장 재질 비교의 원본 surface 계약 오류")
		return false
	var original := crystal.get_active_material(0)
	var native := candidate(source)
	var baseline_label := "A-custom" if original is ShaderMaterial else "A-current"
	var candidates := {baseline_label: original, "B-imported": source, "C-refraction": native}
	var original_foliage: Shader = scene._foliage_material.shader
	# TIME 기반 식생도 모든 순차 캡처에서 동일 위상. 배포 셰이더는 변경하지 않는다.
	var frozen_foliage := Shader.new()
	frozen_foliage.code = original_foliage.code.replace("TIME", "0.0")
	scene._foliage_material.shader = frozen_foliage
	var report := {"platform": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info(), "glb_sha256": FileAccess.get_sha256("res://assets/environment/landmarks.glb"), "mesh_aabb": str(crystal.get_aabb()), "source": material_data(source), "candidate": material_data(native), "foliage_time": 0.0, "samples": [], "representatives": []}
	for model: Node in [scene._landmark_library, scene._terrain_library, scene.TURRET_MODELS["cannon"].instantiate()]:
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var mat := mesh.mesh.surface_get_material(surface)
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var tangents = arrays[Mesh.ARRAY_TANGENT]
				report["representatives"].append({"mesh": mesh.name, "material": material_data(mat), "tangent_count": 0 if tangents == null else tangents.size()})
		if model != scene._landmark_library and model != scene._terrain_library:
			model.free()
	var scenarios := ["game-close", "blender-direction", "angled", "drone", "overlap-angled", "overlap-drone"]
	var viewport := scene.get_viewport()
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	for scenario in scenarios:
		for phase in [0.0, 1.1]:
			var sample_frame := frame.duplicate(true)
			sample_frame["time"] = phase
			sample_frame["nexusHit"] = 0.0
			sample_frame["impacts"] = []
			if scenario.begins_with("overlap"):
				# 기존 표시 입력으로 앞쪽 포탑·투명 체적 효과 겹침을 재현.
				var grid := core.position + Vector3(scene.columns / 2.0, 0, scene.rows / 2.0)
				sample_frame["turrets"] = [[900, grid.x + 0.12, grid.z + 0.65, 0.0, 0, 0.0, "cannon", 1]]
				sample_frame["impacts"] = [[901, grid.x, grid.z + 0.45, 0.75, 0.13 if phase == 0.0 else 0.52]]
			scene.options["camera"] = "drone" if scenario.ends_with("drone") else "angled"
			scene._apply_options()
			if scene.camera_transition and scene.camera_transition.is_running():
				await scene.camera_transition.finished
			scene._apply_frame(sample_frame)
			if scenario in ["game-close", "blender-direction"]:
				var center := core.global_position + Vector3(0.0, 0.65, 0.0)
				var direction := Vector3(5.0, 27.0, 13.0) if scenario == "game-close" else Vector3(1.7, 5.98, 4.8)
				scene.camera.size = 1.8
				scene.camera.h_offset = 0.0
				scene.camera.v_offset = 0.0
				scene.camera.position = center + direction.normalized() * 4.0
				scene.camera.look_at(center)
			for label: String in candidates:
				for entry: Dictionary in scene._cores:
					entry["crystal"].set_surface_override_material(0, candidates[label])
				for index in range(32):
					await tree.process_frame
				await RenderingServer.frame_post_draw
				var name := "%s-%s-%.1f" % [scenario, label, phase]
				var capture := viewport.get_texture().get_image()
				if capture.save_png(output.path_join(name + ".png")) != OK:
					push_error("재질 비교 캡처 저장 실패: " + output)
					return false
				var periods: Array[float] = []
				var last := Time.get_ticks_usec()
				for index in range(60):
					await tree.process_frame
					var now := Time.get_ticks_usec()
					periods.append((now - last) / 1000.0)
					last = now
				periods.sort()
				var sample := {"name": name, "camera_transform": str(scene.camera.transform), "camera_size": scene.camera.size, "camera_offsets": str(Vector2(scene.camera.h_offset, scene.camera.v_offset)), "viewport": str(viewport.get_visible_rect().size), "crystal_transform": str(crystal.global_transform), "frame_sha256": JSON.stringify(sample_frame).sha256_text(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "static_memory": Performance.get_monitor(Performance.MEMORY_STATIC), "video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "texture_memory": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), "render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()), "render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()), "frame_p50_ms": periods[30], "frame_p95_ms": periods[56], "frame_p99_ms": periods[59]}
				report["samples"].append(sample)
				print("NATIVE_SAMPLE " + JSON.stringify(sample))
	for entry: Dictionary in scene._cores:
		entry["crystal"].set_surface_override_material(0, original)
	scene._foliage_material.shader = original_foliage
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "\t"))
	print("NATIVE_COMPLETE " + output)
	return true
