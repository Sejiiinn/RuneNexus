extends "res://main_stage_preparation.gd"
## Battlefield scene entry: startup, per-frame processing, input and host notifications.
## Layers below it (state → camera → frame → stage preparation) may only call
## downward; GDScript rejects an upward call at parse time.

func _ready() -> void:
	_presentation_nodes["effects"].spatial_lightning = true
	_presentation_nodes["effects"].spatial_ricochet = true
	world.add_child(_machinegun_ricochet)
	RuntimeProfile.configure()
	_frame_metrics.attach(get_viewport())
	_set_profile_enabled(RuntimeProfile.enabled)
	add_child(_space_background)
	add_child(_turret_level_labels)
	add_child(_stockpile_indicator)
	_presentation_layer.layer = 2
	add_child(_presentation_layer)
	for group: String in _presentation_nodes:
		var node: Node2D = _presentation_nodes[group]
		RuntimeProfile.tag_canvas(node, group)
		_presentation_layer.add_child(node)
		node.hide()
	_presentation_layer.add_child(_screen_feedback)
	RuntimeProfile.tag_canvas(_screen_feedback, "feedback")
	add_child(world)
	world.add_child(terrain)
	add_child(camera)
	add_child(_battlefield_camera)
	_battlefield_camera.pose_changed.connect(_on_camera_pose_changed)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# 실제 맵·모델·효과 경계로 _fit_camera_depth에서 설정한다.
	camera.current = true
	_apply_graphics_options()
	_units.failure.connect(_fail)
	_projectile_renderer.failure.connect(_fail)
	_environment.failed.connect(_fail)
	_environment.camera_reset_requested.connect(func(): camera_mode = "")
	if not _environment.initialize(): return
	if not app_mode:
		_presentation_nodes["effects"].prepare_assets()
		_ensure_battle_base()
		if not _projectile_renderer.initialize(): return
	else:
		begin_deferred_battle_presentation()
	get_viewport().size_changed.connect(_update_camera)
	# Tween은 _process 뒤에 진행되므로 실제 렌더 직전의 카메라로 투영을 보고.
	RenderingServer.frame_pre_draw.connect(_report_presentation)
	_update_camera()
	if app_mode or LaunchMode.development_session():
		var entry := "res://app/app_lifecycle.gd" if app_mode else "res://session/standalone.gd"
		session_controller = load(entry).new()
		add_child(session_controller)
		return
	# Explicit fixture mode is retained for isolated visual and combat checks.
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://assets/preview_frame.json"))
	if fixture is Dictionary: apply_frame(fixture)

func _exit_tree() -> void:
	_frame_metrics.dispose()
	_units.clear_placements()
	world.position = Vector3.ZERO
	if RenderingServer.frame_pre_draw.is_connected(_report_presentation):
		RenderingServer.frame_pre_draw.disconnect(_report_presentation)
	_environment.dispose()
	_path_guide.dispose()
	_camera_models.clear()
	_units.clear()
	_units.retain_stage([])
	_projectile_renderer.clear()
	_projectile_renderer._projectile_meshes.clear()
	_lightning_presentation.clear()
	_machinegun_ricochet.clear()
	EffectPreparation.retain_stage([], [])
	StageResources.clear()

func _fail(message: String) -> void:
	if _stage_entry_active:
		_stage_preparation_error = message
		return
	push_error(message)
	var boot=get_tree().get_first_node_in_group("rune_app_boot")
	if boot!=null: boot.fail_preparation(message)

func _process(delta: float) -> void:
	if not _battle_visible or _stage_preparation_pending: return
	RuntimeProfile.apply_render_partition(get_viewport(), combat_runtime.session.get("phase", "") == "wave")
	_frame_metrics.begin_frame()
	if standalone_playing and not last_frame.is_empty():
		standalone_time += delta
		var frame: Dictionary = last_frame.duplicate(true)
		frame["time"] = standalone_time
		frame["impacts"] = []
		for index in range(mini(3, frame.get("enemies", []).size())):
			var progress := fposmod(standalone_time + index * 0.37, 1.4) / 1.1
			if progress < 1.0:
				var target: FrameRows.Enemy = frame["enemies"][index]
				frame["impacts"].append([100 + index, target.x, target.y, 1.2, progress])
		apply_frame(frame)
	if combat_runtime.native_session():
		var host_active: bool = _session_has_focus and not _session_suspended
		if app_mode and is_instance_valid(session_controller) and session_controller.get("services") != null:
			host_active = host_active and not session_controller.services.blocks_play()
		var activation: int = _session_host_revision
		var session_delta := _session_frame_delta(delta, host_active, activation)
		var combat_tick := RuntimeProfile.begin()
		var advanced := combat_runtime.advance_session(session_delta, host_active)
		RuntimeProfile.finish("combat", combat_tick)
		if advanced and not combat_base_frame.is_empty():
			request_native_frame()
		# Schedule from the render process, not input: input's deferred queue can
		# flush during physics before this frame's simulation has advanced.
		_flush_native_frame.call_deferred()
	if _frame_metrics.advance(delta):
		_frame_metrics.report({"received_frames":received_frames,"sequence":last_sequence,
			"authored_terrain":_using_authored,"combat_active":combat_runtime.active,
			"combat_sequence":combat_runtime.sequence,"combat_elapsed":combat_runtime.elapsed,
			"phase":combat_runtime.session.get("phase", ""),"paused":combat_runtime.session.get("paused", false)})

func apply_options() -> void:
	_presentation_nodes["effects"].diagnostic_skip = str(options.get("diagnostic_skip_canvas", ""))
	RunicFire.set_diagnostic_mode(str(options.get("runic_fire_mode", "all")))
	world.visible = _battle_visible and not bool(options["empty"])
	_apply_graphics_options()
	_update_camera()
	if not last_frame.is_empty():
		_update_impacts(last_frame.get("impacts", []))

func _unhandled_key_input(event: InputEvent) -> void:
	if app_mode: return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: standalone_playing = not standalone_playing
		KEY_C: options["camera"] = "drone" if options["camera"] == "angled" else "angled"
		KEY_S: options["shadows"] = not options["shadows"]
		KEY_V: options["volume"] = not options["volume"]
	apply_options()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(session_controller):
		match session_controller.board_input_policy():
			SessionController.BoardInput.IGNORE: return
			SessionController.BoardInput.CANCEL_CONTACTS:
				_session_input.contacts.clear()
				return
	_session_input.handle(event)

func _notification(what: int) -> void:
	# Both the formal app and development sessions use the actual Godot host
	# lifecycle. A suspended engine need not render an inactive frame at all.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_set_session_host_state(false, _session_suspended)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_set_session_host_state(true, _session_suspended)
		NOTIFICATION_APPLICATION_PAUSED:
			_set_session_host_state(_session_has_focus, true)
		NOTIFICATION_APPLICATION_RESUMED:
			_set_session_host_state(_session_has_focus, false)
