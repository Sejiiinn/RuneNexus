extends Node

const Simulation = preload("res://validation/combat_simulation.gd")
var simulation = Simulation.new()
var battlefield: Node3D
var scenario := "fire_4x"
var duration := 30.0
var warmup := 12.0
var elapsed := 0.0
var previous_tick := 0
var start_tick := 0
var intervals: Array = []
var simulation_us: Array = []
var apply_us: Array = []
var render_samples: Array = []
var sample_second := -1
var measuring := false
var done := false
var status: Label
var speed := 4.0
var paused := false
var mode := "standalone"
var summary := {}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"scenario": scenario = parts[1]
			"duration": duration = maxf(5.0, float(parts[1]))
			"warmup": warmup = maxf(2.0, float(parts[1]))
			"mode": mode = parts[1]
	speed = 4.0 if scenario in ["fire_4x", "stress_4x", "combat_normal", "combat_fire", "combat_stress"] else 1.0
	if mode.begins_with("one_x") or mode.begins_with("range_"):
		speed = 1.0
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/preview_frame.json"))
	var capture_scenario := scenario
	if scenario.begins_with("combat_"):
		capture_scenario = "normal" if scenario == "combat_normal" else "fire_4x"
	var capture_path := "res://validation/fixtures/%s.json" % capture_scenario
	if FileAccess.file_exists(capture_path):
		fixture = JSON.parse_string(FileAccess.get_file_as_string(capture_path))
	if mode.begins_with("range_"):
		var selection: Dictionary = fixture["presentation"]["selection"]
		selection["rewardTargeting"] = false
		selection["tiles"] = []
		for index in range(selection["turrets"].size()):
			selection["turrets"][index]["selected"] = mode.begins_with("range_selected_") and index == 0
		if mode.begins_with("range_placement_"):
			selection["tiles"] = [{"position": [2.5, 0.5], "kind": "build"}]
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	battlefield = load("res://main.tscn").instantiate()
	add_child(battlefield)
	if mode.begins_with("range_"):
		battlefield._presentation_nodes["selection"].cache_enabled = not mode.ends_with("uncached")
	battlefield.set_process(false)
	battlefield.standalone_playing = false
	battlefield.options.merge({"profile": false, "burn_effects": true, "runic_fire_mode": "all", "presentation_groups": ["labels", "selection", "effects"], "turret_levels": true}, true)
	# Diagnostic isolation only; production keeps every effect enabled.
	if mode == "one_x_no_particles":
		battlefield.options["runic_fire_mode"] = "no_particles"
	if mode == "one_x_no_burn":
		battlefield.options["burn_effects"] = false
	if mode == "no_ranges":
		# Default fixed-target fixture has only range fills in this group.
		battlefield.options["presentation_groups"] = ["labels", "effects"]
	if mode == "no_levels":
		speed = 1.0
		battlefield.options["turret_levels"] = false
	battlefield._apply_options()
	simulation.configure(fixture, scenario, speed)
	battlefield._apply_frame(simulation.step(0.0))
	_make_hud()
	start_tick = Time.get_ticks_usec()
	print("RN_NATIVE " + JSON.stringify({"event":"ready", "scenario":scenario, "mode":mode, "duration":duration, "viewport":get_viewport().get_visible_rect().size, "renderer":RenderingServer.get_current_rendering_method(), "gpu":RenderingServer.get_video_adapter_name(), "options":battlefield.options}))

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(24, 180)
	row.add_theme_constant_override("separation", 20)
	layer.add_child(row)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 23)
	row.add_child(status)
	var pause_button := Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(func():
		paused = not paused
		simulation.set_paused(paused)
		pause_button.text = "Resume" if paused else "Pause")
	row.add_child(pause_button)
	var speed_button := Button.new()
	speed_button.text = "%dx" % int(speed)
	speed_button.pressed.connect(func():
		speed = 1.0 if speed == 4.0 else 4.0
		simulation.speed = speed
		speed_button.text = "%dx" % int(speed))
	row.add_child(speed_button)

func _process(delta: float) -> void:
	if done:
		return
	var tick := Time.get_ticks_usec()
	elapsed = float(tick - start_tick) / 1000000.0
	if measuring and previous_tick > 0:
		intervals.append(float(tick - previous_tick) / 1000.0)
	previous_tick = tick
	var begin := Time.get_ticks_usec()
	var frame: Dictionary = battlefield.last_frame if mode == "frozen" and measuring else simulation.step(delta)
	var simulated := Time.get_ticks_usec()
	if mode != "frozen" or not measuring:
		battlefield._apply_frame(frame)
	var applied := Time.get_ticks_usec()
	if measuring:
		simulation_us.append(simulated - begin)
		apply_us.append(applied - simulated)
	var second := int(elapsed)
	if second != sample_second:
		sample_second = second
		status.text = "%s | %ds | %d enemies" % [scenario, second, frame.get("enemies", []).size()]
		if measuring:
			render_samples.append({"second":second,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"static_memory":OS.get_static_memory_usage(),"enemies":frame.get("enemies",[]).size(),"projectiles":frame.get("projectiles",[]).size(),"impacts":frame.get("impacts",[]).size()})
	if not measuring and elapsed >= warmup:
		measuring = true
		previous_tick = 0
		print("RN_NATIVE " + JSON.stringify({"event":"begin","scenario":scenario,"mode":mode}))
	if measuring and elapsed >= warmup + duration:
		_finish()

func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered:
		total += float(value)
	return {"n":ordered.size(),"mean":total/ordered.size(),"p50":ordered[ceili(ordered.size()*.5)-1],"p95":ordered[ceili(ordered.size()*.95)-1],"p99":ordered[ceili(ordered.size()*.99)-1],"max":ordered[-1]}

func _finish() -> void:
	done = true
	var frame_stats := _stats(intervals)
	var missed := 0
	for value in intervals:
		if value > 1000.0/60.0 + 0.5:
			missed += 1
	summary = {"event":"complete","scenario":scenario,"mode":mode,"duration":duration,"warmup":warmup,"frame_ms":frame_stats,"fps":1000.0/float(frame_stats.get("mean",INF)),"over_17_17_ms":missed,"simulation_us":_stats(simulation_us),"apply_us":_stats(apply_us),"gpu_time_ms":null,"counters":simulation.counters,"viewport":[get_viewport().size.x,get_viewport().size.y],"samples":render_samples}
	var result_path := "user://benchmark_%s_%s.json" % [mode,scenario]
	var output := FileAccess.open(result_path,FileAccess.WRITE)
	output.store_string(JSON.stringify({"summary":summary,"intervals_ms":intervals},"\t"))
	output.close()
	# Keep log records below Android's per-line limit.
	var compact := summary.duplicate(true)
	compact.erase("samples")
	print("RN_NATIVE " + JSON.stringify(compact))
	for sample in render_samples:
		print("RN_NATIVE " + JSON.stringify({"event":"render_sample","scenario":scenario,"sample":sample}))
	status.text = "%s | %.1f FPS | complete" % [scenario,summary.fps]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
