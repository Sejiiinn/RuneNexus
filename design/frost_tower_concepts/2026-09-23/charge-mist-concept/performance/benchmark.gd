extends Node3D

const CONDITIONS := ["mist_0", "mist_1", "mist_4_overlap", "mist_8_overlap", "mist_8_spread", "light_off", "light_on"]
const WARMUP_MS := 1000
const SAMPLE_MS := 3000
const MIN_FRAMES := 300
const OUT_REL := "../../../design/frost_tower_concepts/2026-09-23/charge-mist-concept/performance"

var concept: Node3D
var mists: Array[MultiMeshInstance3D] = []
var viewport_rid: RID
var render_time_available := false
var setup_time_available := false
var rows: Array[Dictionary] = []


func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	concept = load("res://concept.tscn").instantiate()
	add_child(concept)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	concept.set_process(false)
	concept.call("apply_time", 5.15)
	var camera: Camera3D = concept.get("camera")
	camera.size = 9.5
	var first: MultiMeshInstance3D = concept.get("mist")
	mists.append(first)
	for i in range(7):
		var copy := MultiMeshInstance3D.new()
		copy.multimesh = first.multimesh
		copy.material_override = first.material_override
		copy.custom_aabb = first.custom_aabb
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		concept.add_child(copy)
		mists.append(copy)
	viewport_rid = get_viewport().get_viewport_rid()
	render_time_available = ClassDB.class_has_method("RenderingServer", "viewport_get_measured_render_time_cpu") and ClassDB.class_has_method("RenderingServer", "viewport_get_measured_render_time_gpu")
	setup_time_available = ClassDB.class_has_method("RenderingServer", "get_frame_setup_time_cpu")
	if render_time_available:
		RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var order := CONDITIONS.duplicate()
	for pass_index in range(2):
		if pass_index == 1:
			order.reverse()
		for condition in order:
			_set_condition(condition)
			var warmup_start := Time.get_ticks_msec()
			while Time.get_ticks_msec() - warmup_start < WARMUP_MS:
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
			var samples: Array[Dictionary] = []
			var sample_start := Time.get_ticks_msec()
			var previous_tick := Time.get_ticks_usec()
			while Time.get_ticks_msec() - sample_start < SAMPLE_MS or samples.size() < MIN_FRAMES:
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var tick := Time.get_ticks_usec()
				var sample := {
					"interval_ms": float(tick - previous_tick) / 1000.0,
					"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					"reported_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				}
				if render_time_available:
					sample["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
					sample["render_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
				if setup_time_available:
					sample["frame_setup_cpu_ms"] = RenderingServer.get_frame_setup_time_cpu()
				samples.append(sample)
				previous_tick = tick
			rows.append({"pass": pass_index + 1, "condition": condition, "samples": samples})
			print("BENCHMARK_CONDITION ", pass_index + 1, " ", condition, " ", samples.size())
	if render_time_available:
		RenderingServer.viewport_set_measure_render_time(viewport_rid, false)
	var out_dir := ProjectSettings.globalize_path("res://").path_join(OUT_REL).simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var metadata := {
		"engine_version": Engine.get_version_info(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"viewport_size": get_viewport().get_visible_rect().size,
		"camera_size": camera.size,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"render_time_api_available": render_time_available,
		"frame_setup_api_available": setup_time_available,
		"warmup_ms": WARMUP_MS,
		"minimum_sample_ms": SAMPLE_MS,
		"minimum_frames": MIN_FRAMES,
		"mist_age": 0.5,
		"mist_instances_per_effect": 32,
		"mist_triangles_per_instance": 576,
		"mist_triangles_per_effect": 18432,
		"description": "Desktop GUI render of approved concept; fixed scene, camera and enemy; mist copies only. GPU viewport times may lag frame intervals. Concurrent user Godot sessions were preserved."
	}
	var file := FileAccess.open(out_dir.path_join("raw.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"metadata": metadata, "trials": rows}, "  "))
	file.close()
	for condition in ["mist_8_overlap", "mist_8_spread"]:
		_set_condition(condition)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(condition + ".png"))
	print("BENCHMARK_COMPLETE ", out_dir)
	get_tree().quit()


func _set_condition(condition: String) -> void:
	concept.call("apply_time", 5.15)
	var charge_mat: ShaderMaterial = concept.get("charge_mat")
	var mist_mat: ShaderMaterial = concept.get("mist_mat")
	var lamp: OmniLight3D = concept.get("lamp")
	charge_mat.set_shader_parameter("charge", 1.0 if condition.begins_with("light_") else 0.0)
	lamp.light_energy = 0.65 if condition == "light_on" else 0.0
	mist_mat.set_shader_parameter("age", 0.5)
	var count := 0
	if condition == "mist_1":
		count = 1
	elif condition == "mist_4_overlap":
		count = 4
	elif condition == "mist_8_overlap" or condition == "mist_8_spread":
		count = 8
	var positions := [
		Vector3(-2.3, 0, -1.6), Vector3(0, 0, -1.6), Vector3(2.3, 0, -1.6),
		Vector3(-2.3, 0, 0), Vector3(2.3, 0, 0),
		Vector3(-2.3, 0, 1.6), Vector3(0, 0, 1.6), Vector3(2.3, 0, 1.6),
	]
	for i in mists.size():
		mists[i].visible = i < count
		mists[i].position = positions[i] if condition == "mist_8_spread" else Vector3.ZERO
