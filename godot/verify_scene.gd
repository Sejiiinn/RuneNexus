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
	if "--turret-labels" in OS.get_cmdline_user_args():
		scene.options["turret_levels"] = true
		var labels_frame: Dictionary = scene.last_frame.duplicate(true)
		var types: Array = scene.TURRET_MODELS.keys()
		var levels := [1, 2, 4, 6, 8, 10]
		for index in range(labels_frame["turrets"].size()):
			labels_frame["turrets"][index][6] = types[index % types.size()]
			labels_frame["turrets"][index][7] = levels[index % levels.size()]
		scene._apply_frame(labels_frame)
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
		print("GPU verified %s: %d draw calls, %d primitives, capture %s" % [
			sample["camera"], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), output])
	quit()
