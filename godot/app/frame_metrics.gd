extends RefCounted
## Owns frame/render timing windows and their opt-in log format.
## Receives a small report context only when a window closes, never the scene.
const RuntimeProfile = preload("res://app/runtime_profile.gd")
var _viewport: Viewport
var _profile_enabled := false
var _profile_window_id := 0
var _profile_intervals := PackedFloat64Array()
var _profile_last_tick := 0
var _profile_parse_us := 0
var _profile_parse_count := 0
var _profile_apply_us := 0
var _profile_apply_count := 0
var _profile_render_cpu_ms := 0.0
var _profile_render_gpu_ms := 0.0
var _profile_render_count := 0
var metrics_elapsed := 0.0
var frame_count := 0
var frame_time_total := 0.0
var frame_time_max := 0.0

var enabled: bool:
	get: return _profile_enabled

func attach(viewport: Viewport) -> void:
	_viewport = viewport

func set_enabled(value: bool) -> void:
	_set_profile_enabled(value)

func begin_frame() -> void:
	if not _profile_enabled: return
	var tick := Time.get_ticks_usec()
	if _profile_last_tick != 0:
		_profile_intervals.append(float(tick - _profile_last_tick) / 1000.0)
	_profile_last_tick = tick

func advance(delta: float) -> bool:
	metrics_elapsed += delta
	frame_count += 1
	frame_time_total += delta
	frame_time_max = maxf(frame_time_max, delta)
	return metrics_elapsed >= 1.0

func record_apply(started: int) -> void:
	_profile_apply_us += Time.get_ticks_usec() - started
	_profile_apply_count += 1

func report(context: Dictionary) -> void:
	var viewport := _viewport.get_visible_rect().size
	var metrics := {
		"fps": frame_count / frame_time_total,
		"frame_ms": frame_time_total * 1000.0 / frame_count,
		"max_frame_ms": frame_time_max * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"received_frames": context.received_frames, "sequence": context.sequence,
		"viewport": [viewport.x, viewport.y], "authored_terrain": context.authored_terrain,
		"renderer": RenderingServer.get_current_rendering_method(),
		"combat_active": context.combat_active,
		"combat_sequence": context.combat_sequence,
		"combat_elapsed": context.combat_elapsed,
	}
	if _profile_enabled:
		_profile_window_id += 1
		_profile_intervals.sort()
		metrics.merge({
			"profile": true,
			"profile_window_id": _profile_window_id,
			"process_frame": Engine.get_process_frames(),
			"frame_intervals_ms": Array(_profile_intervals),
			"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			"texture_memory": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
			"frame_interval_p50_ms": _profile_percentile(0.50),
			"frame_interval_p95_ms": _profile_percentile(0.95),
			"frame_interval_p99_ms": _profile_percentile(0.99),
			"profile_frame_samples": _profile_intervals.size(),
			"json_parse_ms": float(_profile_parse_us) / maxf(1.0, _profile_parse_count) / 1000.0,
			"apply_frame_ms": float(_profile_apply_us) / maxf(1.0, _profile_apply_count) / 1000.0,
			"profile_apply_samples": _profile_apply_count,
			"profile_parse_samples": _profile_parse_count,
			"render_cpu_ms": _profile_render_cpu_ms / maxf(1.0, _profile_render_count),
			"render_gpu_ms": _profile_render_gpu_ms / maxf(1.0, _profile_render_count),
			"profile_render_samples": _profile_render_count,
		})
		_reset_profile_window()
	if RuntimeProfile.enabled:
		var costs := RuntimeProfile.drain()
		for label in costs:
			print("APP_COST ", label, " ", JSON.stringify(costs[label]))
		metrics.erase("frame_intervals_ms")
		metrics["phase"] = context.phase
		metrics["paused"] = context.paused
		print("APP_PROFILE ", JSON.stringify(metrics))
	metrics_elapsed = 0.0
	frame_count = 0
	frame_time_total = 0.0
	frame_time_max = 0.0

func _reset_profile_window() -> void:
	_profile_intervals.clear()
	_profile_parse_us = 0
	_profile_parse_count = 0
	_profile_apply_us = 0
	_profile_apply_count = 0
	_profile_render_cpu_ms = 0.0
	_profile_render_gpu_ms = 0.0
	_profile_render_count = 0


func _profile_percentile(fraction: float) -> float:
	if _profile_intervals.is_empty():
		return 0.0
	return _profile_intervals[clampi(ceili(fraction * _profile_intervals.size()) - 1, 0, _profile_intervals.size() - 1)]


func _profile_render_frame() -> void:
	# 최근 완료된 루트 viewport 렌더만 측정. Script/별도 mask viewport는 제외.
	var rid := _viewport.get_viewport_rid()
	_profile_render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_profile_render_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_profile_render_count += 1


func _set_profile_enabled(enabled: bool) -> void:
	if enabled == _profile_enabled:
		return
	_profile_enabled = enabled
	RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), enabled)
	if enabled:
		RenderingServer.frame_post_draw.connect(_profile_render_frame)
	else:
		RenderingServer.frame_post_draw.disconnect(_profile_render_frame)
	_profile_last_tick = 0
	_reset_profile_window()



func dispose() -> void:
	if RenderingServer.frame_post_draw.is_connected(_profile_render_frame):
		RenderingServer.frame_post_draw.disconnect(_profile_render_frame)
	if is_instance_valid(_viewport):
		RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), false)
	_profile_enabled = false
	_viewport = null
