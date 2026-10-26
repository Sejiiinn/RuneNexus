extends "res://main_camera.gd"
## Applies combat frames to the 3D scene: terrain, units, projectiles, impacts.

func _report_presentation() -> void:
	if not _battle_visible or _battle_deferred: return
	_flush_native_frame()
	_units.update_placements()
	_apply_world_shake()
	_turret_level_labels.update(camera, turrets, bool(options["turret_levels"]) and world.visible)
	_stockpile_indicator.update(camera,turrets,world.visible)
	_present_overlays()

## The process-owned idle flush combines input, simulation and child changes.
## Canvas redraws must be queued before frame_pre_draw to reach this render.
func request_native_frame() -> void:
	if combat_base_frame.is_empty(): return
	if not combat_runtime.native_session():
		apply_frame(combat_base_frame)
		return
	_native_frame_pending = true

func _flush_native_frame() -> void:
	if not _native_frame_pending or not _battle_visible or _battle_deferred: return
	_native_frame_pending = false
	if combat_base_frame.is_empty():
		_pending_gem_bursts.clear()
		return
	apply_frame(combat_base_frame)
	# A build followed by equipment in this render must create the model first.
	for receipt in _pending_gem_bursts:
		_units.play_gem_equip_burst(receipt.id, receipt.gem)
	_pending_gem_bursts.clear()

func confirm_turret_placement(id: int, type: String, x: int, y: int) -> void:
	_units.confirm_placement(id,type,x,y)

func cancel_turret_placement(id: int) -> void:
	_units.cancel_placement(id)

func apply_frame(frame: Dictionary) -> void:
	if _battle_deferred or (app_mode and not _battle_visible and not _realizing_battle):
		var epoch := int(frame.get("sceneEpoch", 0))
		if epoch < _scene_epoch: return
		if bool(frame.get("reset", false)) or epoch > _scene_epoch:
			_clear_scene()
			_scene_epoch = epoch
		if not bool(frame.get("reset", false)):
			last_frame = FrameRows.decoded(frame.duplicate(true))
		return
	var owned_snapshot := false
	var whole_tick := RuntimeProfile.begin()
	if combat_runtime.active and not bool(frame.get("reset", false)) and int(frame.get("sceneEpoch", -1)) == _scene_epoch:
		var decorate_tick := RuntimeProfile.begin()
		# Both real native entry points use tile units with canonical Canvas art.
		# The development session needs the same glyph/effect conversion as --app.
		var native_presentation := app_mode or is_instance_valid(session_controller)
		# Native frames already carry canonical 48-pixel Canvas units.
		frame = combat_runtime.decorate_frame(frame, true, native_presentation)
		owned_snapshot = true
		RuntimeProfile.finish("decorate", decorate_tick)
		if combat_runtime.native_session():
			frame.zoom = _session_input.zoom
			options.zoom = _session_input.zoom
			var viewport: Array = frame.get("viewport", [])
			var center: Array = frame.get("screenCenter", [])
			if viewport.size() == 2 and center.size() == 2:
				frame.screenCenter = [center[0] + _session_input.pan.x * viewport[0], center[1] + _session_input.pan.y * viewport[1]]
	# Every consumer below reads named rows, whichever producer built the frame.
	frame = FrameRows.decoded(frame)
	if not _frame_metrics.enabled:
		_apply_frame_impl(frame, owned_snapshot)
		return
	var started := Time.get_ticks_usec()
	_apply_frame_impl(frame, owned_snapshot)
	_frame_metrics.record_apply(started)
	RuntimeProfile.finish("presentation", whole_tick)

func _apply_frame_impl(frame: Dictionary, owned_snapshot: bool = false) -> void:
	var epoch := int(frame.get("sceneEpoch", 0))
	if epoch < _scene_epoch:
		return
	if bool(frame.get("reset", false)):
		_clear_scene()
		_scene_epoch = epoch
		return
	if epoch > _scene_epoch:
		_clear_scene()
		_scene_epoch = epoch
	if int(frame.get("seq", -1)) < last_sequence:
		return
	var revision := int(frame.get("mapRevision", -1))
	var map: Dictionary = frame.get("map", {})
	if map.is_empty():
		# Legacy frames always require a full map. Revision-only frames reuse
		# exactly the map already applied in this epoch, never a previous scene.
		if revision < 0:
			return
		if _current_map.is_empty() or revision != _map_revision:
			_map_request = {"presentationVersion": 2, "sceneEpoch": _scene_epoch,
				"viewportRevision": int(frame.get("viewportRevision", 0)),
				"viewport": frame.get("viewport", []), "sequence": int(frame.get("seq", -1)),
				"mapRevision": revision, "mapRequired": true}
			return
	elif map != _current_map and not _build_terrain(map):
		return
	_map_revision = revision
	_map_request.clear()
	last_frame = frame.duplicate()
	last_sequence = int(frame.get("seq", -1))
	received_frames += 1
	var payload: Dictionary = frame.get("presentation", {})
	for group: String in _presentation_nodes:
		if payload.get(group) is Dictionary:
			var group_frame: Dictionary = payload[group].duplicate()
			group_frame["viewport"] = frame.get("viewport", [])
			if group == "effects":
				group_frame["targets"] = frame.get("enemies", [])
				group_frame["turrets"] = frame.get("turrets", [])
				group_frame["playbackSpeed"] = float(combat_runtime.session.get("speed", 1.0))
			var node: Node2D = _presentation_nodes[group]
			var canvas_enabled: bool = world.visible and int(frame.get("presentationVersion", 0)) == 2 and options.get("presentation_groups", []).has(group) and node.supported_groups().has(group) and not RuntimeProfile.options.get("hide_canvas", false)
			node.set_canvas_enabled(canvas_enabled)
			if group in ["labels", "effects", "selection"]:
				node.apply_frame(group_frame, owned_snapshot)
			else:
				node.apply_frame(group_frame)
			if RuntimeProfile.options.get("hide_canvas", false): _presentation_nodes[group].hide()
		else:
			_presentation_nodes[group].clear()
	# Native event progress is computed once per authoritative combat-clock frame.
	# Preserve legacy snapshots (and prefer them on fallback) without retaining
	# the previous frame's event-derived arrays on the next submission.
	var merged_impacts := {}
	for impact: FrameRows.Impact in FrameRows.rows("impacts", _presentation_nodes["effects"].blast_impacts):
		merged_impacts[impact.id] = impact
	for impact: FrameRows.Impact in frame.get("impacts", []):
		merged_impacts[impact.id] = impact
	last_frame["impacts"] = merged_impacts.values()
	var camera_tick := RuntimeProfile.begin()
	_update_camera()
	RuntimeProfile.finish("camera", camera_tick)
	var session_presentation_tick := RuntimeProfile.begin()
	_update_session_presentation()
	RuntimeProfile.finish("session_presentation", session_presentation_tick)
	var turrets_tick := RuntimeProfile.begin()
	_sync_turrets(frame.get("turrets", []))
	_sync_support_cores(frame)
	RuntimeProfile.finish("turrets", turrets_tick)
	var enemies_tick := RuntimeProfile.begin()
	_sync_enemies(frame.get("enemies", []))
	RuntimeProfile.finish("enemies", enemies_tick)
	var projectiles_tick := RuntimeProfile.begin()
	_sync_projectiles(last_frame.get("projectiles", []))
	RuntimeProfile.finish("projectiles", projectiles_tick)
	_sync_build_preview(frame.get("buildPreview"))
	var impacts_tick := RuntimeProfile.begin()
	_update_impacts(last_frame.get("impacts", []))
	RuntimeProfile.finish("impacts", impacts_tick)
	_environment.update_frame(frame)
	_path_guide.update_time(float(frame.get("time", 0.0)))

func _clear_scene() -> void:
	_native_frame_pending = false
	_pending_gem_bursts.clear()
	_lightning_presentation.clear()
	_machinegun_ricochet.clear()
	combat_runtime.active = false
	combat_runtime = _new_native_combat()
	_session_frame_clock.reset()
	_session_input.reset()
	_battlefield_camera.reset()
	_screen_feedback.hide()
	combat_base_frame.clear()
	world.position = Vector3.ZERO
	_turret_level_labels.clear()
	_stockpile_indicator.clear()
	for node: Node2D in _presentation_nodes.values():
		node.clear()
		node.hide()
	_applied_groups.clear()
	_units.clear()
	_support_cores.clear()
	_projectile_renderer.clear(effects_prepared)
	_path_guide.clear()
	_environment.clear()
	_map_revision = -1
	_map_request.clear()
	last_frame = {}
	last_sequence = -1
	received_frames = 0
	standalone_playing = false
	standalone_time = 0.0
	camera_mode = ""

func _build_terrain(map: Dictionary) -> bool:
	if not _environment.build_terrain(map):
		return false
	_path_guide.build(map)
	_space_background.prepare()
	_space_background.apply_theme(str(map.get("theme", "chapterOne")))
	_battlefield_camera.invalidate_layout()
	return true

func _sync_turrets(units: Array) -> void:
	_units.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_units._sync_turrets(FrameRows.rows("turrets", units))
	var selection = _presentation_nodes["selection"]
	_units.sync_gem_orbits(selection._frame, selection.selection_revision, float(last_frame.get("time", 0.0)))
	_environment.update_occupancy(units, TURRET_MODELS, _support_cores.cores.keys())

## Support cores live in the run state, not in combat frames; the frame only
## carries the build preview tile.
func _sync_support_cores(frame: Dictionary) -> void:
	var state: Dictionary = {}
	if is_instance_valid(session_controller) and session_controller.get("run_domain") != null:
		state = session_controller.run_domain.state
	var preview: Variant = frame.get("supportCorePreview")
	_support_cores.sync(state, Vector2i(int(preview[0]), int(preview[1])) if preview is Array and preview.size() == 2 else null, Vector2i(columns, rows), float(frame.get("time", 0.0)))

func _sync_enemies(units: Array) -> void:
	_units.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_units.sync_guardian_events(combat_runtime)
	_units._sync_enemies(FrameRows.rows("enemies", units))
	_units.sync_sniper_aim()

func play_gem_equip_burst(id: int, gem: String) -> void:
	if _native_frame_pending:
		_pending_gem_bursts.append({"id":id,"gem":gem})
	else:
		_units.play_gem_equip_burst(id, gem)

func _sync_build_preview(data) -> void:
	_units.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_units._sync_build_preview(FrameRows.build_preview(data))

func _sync_projectiles(units: Array) -> void:
	_projectile_renderer.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_projectile_renderer._sync_projectiles(FrameRows.rows("projectiles", units), turrets)

func _update_impacts(units: Array) -> void:
	_projectile_renderer.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_projectile_renderer._update_impacts(FrameRows.rows("impacts", units))

func _update_session_presentation() -> void:
	var logical: Array = last_frame.get("viewport", [])
	var size := Vector2(logical[0],logical[1]) if logical.size() == 2 else get_viewport().get_visible_rect().size
	_screen_feedback.update_state(combat_runtime, size)
	if not combat_runtime.native_session(): return
	var collapsing: bool = combat_runtime.session.get("phase") in ["coreDestruction", "failure"] and not _cores.is_empty()
	var core: Vector3 = _cores[0].root.global_position if collapsing else Vector3.ZERO
	var camera_adjusted := _battlefield_camera.apply_session_offsets(_session_input.pan, _session_input.zoom,
		size, logical.is_empty(), collapsing, core, combat_runtime.destruction_elapsed,
		get_viewport().get_visible_rect().size)
	# Project effects after native drag/collapse offsets, using the final camera.
	# The base camera update above runs before these session-specific offsets.
	if camera_adjusted: _update_camera_visuals()
