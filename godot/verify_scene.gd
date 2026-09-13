extends SceneTree

## 웹을 거치지 않는 동일 Godot 장면의 GPU 렌더·캡처 검사.
func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var output := ProjectSettings.globalize_path("res://../captures")
	DirAccess.make_dir_recursive_absolute(output)
	if "--native-materials" in OS.get_cmdline_user_args():
		var success: bool = await load("res://verify_native_materials.gd").run(scene, output.path_join("native-materials"))
		scene.queue_free()
		for index in range(8):
			await process_frame
		quit(0 if success else 1)
		return
	if "--turret-labels" in OS.get_cmdline_user_args():
		scene.options["turret_levels"] = true
		var labels_frame: Dictionary = scene.last_frame.duplicate(true)
		var types: Array = scene.TURRET_MODELS.keys()
		var levels := [1, 2, 4, 6, 8, 10]
		for index in range(labels_frame["turrets"].size()):
			labels_frame["turrets"][index][6] = types[index % types.size()]
			labels_frame["turrets"][index][7] = levels[index % levels.size()]
		scene._apply_frame(labels_frame)
	var compare_camera := "--crystal-camera-comparison" in OS.get_cmdline_user_args()
	if "--crystal-glass" in OS.get_cmdline_user_args() or compare_camera:
		var success := await _verify_crystal_glass(scene, output, compare_camera)
		scene.queue_free()
		for index in range(8):
			await process_frame
		quit(0 if success else 1)
		return
	for sample in [{"camera": "angled", "progress": 0.13}, {"camera": "drone", "progress": 0.52}]:
		scene.options["camera"] = sample["camera"]
		scene._apply_options()
		if scene.camera_transition and scene.camera_transition.is_running():
			await scene.camera_transition.finished
		var frame: Dictionary = scene.last_frame.duplicate(true)
		var target: Array = frame["enemies"][1]
		frame["impacts"] = [[100, target[1], target[2], 1.2, sample["progress"]]]
		scene._apply_frame(frame)
		for index in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var snapshot := root.get_texture().get_image()
		var error := snapshot.save_png(output.path_join(sample["camera"] + ".png"))
		if error != OK:
			push_error("캡처 저장 실패")
			quit(1)
			return
		print("GPU verified %s: %d draw calls, %d primitives, near/far %.3f/%.3f, capture %s" % [
			sample["camera"], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), scene.camera.near, scene.camera.far, output])
	scene.queue_free()
	for index in range(8):
		await process_frame
	quit()


func _verify_crystal_glass(scene: Node3D, output: String, compare_camera: bool = false) -> bool:
	scene.set_process(false)
	var frame: Dictionary = scene.last_frame.duplicate(true)
	var view_basis: Basis = scene.camera.global_basis
	var core: Node3D = scene._cores[0]["root"]
	var crystal: MeshInstance3D = scene._cores[0]["crystal"]
	var center := core.global_position + Vector3(0.0, 0.65, 0.0)
	var baseline: Image
	var success := true
	var samples := [
		{"name": "core-glass", "time": 0.0, "reflections": true, "specular": true},
		{"name": "core-glass-no-reflection", "time": 0.0, "reflections": false, "specular": true},
		{"name": "core-glass-no-specular", "time": 0.0, "reflections": true, "specular": false},
		{"name": "core-glass-rotated", "time": 1.1, "reflections": true, "specular": true},
	]
	if compare_camera:
		# 같은 게임 GLB·재질·조명·배율에서 검수/게임 시점만 비교.
		samples = [
			{"name": "core-camera-game", "time": 0.0, "reflections": true, "specular": true, "direction": Vector3(5.0, 27.0, 13.0)},
			{"name": "core-camera-blender", "time": 0.0, "reflections": true, "specular": true, "direction": Vector3(1.7, 5.98, 4.8)},
		]
		print("Camera comparison local mesh bounds=%s crystal scale=%s root scale=%s" % [crystal.get_aabb(), crystal.scale, core.scale])
	for sample in samples:
		frame["time"] = sample["time"]
		scene._apply_frame(frame)
		var environment: Environment = scene.camera.get_world_3d().environment
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if sample["reflections"] else Environment.REFLECTION_SOURCE_DISABLED
		# 지형 광택·굴절 배경은 유지하고 결정 전용 보조광의 정반사만 비교.
		scene.get_node("CoreSpecularLight").light_specular = 1.0 if sample["specular"] else 0.0
		scene.camera.size = 1.8
		scene.camera.h_offset = 0.0
		scene.camera.v_offset = 0.0
		var direction: Vector3 = sample["direction"].normalized() if compare_camera else view_basis.z
		scene.camera.position = center + direction * 4.0
		scene.camera.look_at(center)
		if compare_camera:
			var vertices: PackedVector3Array = crystal.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var silhouette := Rect2(scene.camera.unproject_position(crystal.global_transform * vertices[0]), Vector2.ZERO)
			for vertex in vertices:
				silhouette = silhouette.expand(scene.camera.unproject_position(crystal.global_transform * vertex))
			var axis_low: Vector2 = scene.camera.unproject_position(crystal.global_transform * Vector3(0.0, crystal.get_aabb().position.y, 0.0))
			var axis_high: Vector2 = scene.camera.unproject_position(crystal.global_transform * Vector3(0.0, crystal.get_aabb().end.y, 0.0))
			print("Camera comparison %s: elevation=%.4f degrees axis=%.4f px silhouette=%s px aspect=%.4f mesh vertices=%d" % [sample["name"], rad_to_deg(asin(direction.y)), axis_low.distance_to(axis_high), silhouette.size, silhouette.size.y / silhouette.size.x, vertices.size()])
		var bounds := Rect2(scene.camera.unproject_position(crystal.global_transform * crystal.get_aabb().get_endpoint(0)), Vector2.ZERO)
		for corner in range(1, 8):
			bounds = bounds.expand(scene.camera.unproject_position(crystal.global_transform * crystal.get_aabb().get_endpoint(corner)))
		if baseline == null:
			var front_normal := Vector3.ZERO
			var front_dot := -1.0
			for normal: Vector3 in crystal.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
				var world_normal := (crystal.global_basis * normal).normalized()
				var facing: float = world_normal.dot(scene.camera.global_basis.z)
				if facing > front_dot:
					front_dot = facing
					front_normal = world_normal
			print("Glass front facet normal %s; reflected source direction %s" % [front_normal, 2.0 * front_dot * front_normal - scene.camera.global_basis.z])
			for light: DirectionalLight3D in scene.find_children("*", "DirectionalLight3D", false, false):
				var half_vector: Vector3 = (scene.camera.global_basis.z + light.global_basis.z).normalized()
				var closest := -1.0
				for normal: Vector3 in crystal.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
					closest = maxf(closest, (crystal.global_basis * normal).normalized().dot(half_vector))
				print("Glass light %s: closest half-vector angle %.2f degrees" % [light.name, rad_to_deg(acos(closest))])
		# 공용 환경 반사 필터 완료 후 확인.
		for index in range(24):
			await process_frame
		await RenderingServer.frame_post_draw
		var snapshot := root.get_texture().get_image()
		if snapshot.save_png(output.path_join(sample["name"] + ".png")) != OK:
			push_error("결정 유리 캡처 저장 실패")
			return false
		if baseline == null:
			baseline = snapshot
		else:
			var changed := 0
			var max_difference := 0.0
			for y in range(maxi(0, floori(bounds.position.y)), mini(snapshot.get_height(), ceili(bounds.end.y))):
				for x in range(maxi(0, floori(bounds.position.x)), mini(snapshot.get_width(), ceili(bounds.end.x))):
					var before := baseline.get_pixel(x, y)
					var after := snapshot.get_pixel(x, y)
					var difference := maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
					max_difference = maxf(max_difference, difference)
					if difference > 0.02:
						changed += 1
			print("Glass GPU %s: %d changed pixels, max difference %.4f" % [sample["name"], changed, max_difference])
			if changed < 10:
				push_error("결정의 실제 반사·광원·회전 반응 누락: %s" % sample["name"])
				success = false
	return success
