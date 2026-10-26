extends "res://main_state.gd"
## Graphics options, lighting, camera fit and the 2D overlays projected from it.

func prepare_effects() -> bool:
	var generation := _stage_preparation_generation
	if effects_prepared: return true
	if _effects_preparing:
		await effects_preparation_finished
		if generation != _stage_preparation_generation: return false
		return true if effects_prepared else await prepare_effects()
	_effects_preparing = true
	var preparation = load("res://presentation/effect_preparation.gd").new()
	add_child(preparation)
	var prepared: bool = await preparation.prepare(self, _stage_manifest)
	effects_prepared = prepared and generation == _stage_preparation_generation
	preparation.queue_free()
	_effects_preparing = false
	effects_preparation_finished.emit(effects_prepared)
	return effects_prepared

func _apply_stage_lighting() -> void:
	_environment.apply_stage_lighting()

func _apply_graphics_options() -> void:
	_set_profile_enabled(RuntimeProfile.enabled or bool(options.get("profile", false)))
	# JSON 숫자는 float로 수신될 수 있으므로 숫자 타입과 허용값을 함께 검사.
	var samples = options.get("msaa_samples", 2)
	if not (samples is int or samples is float) or (samples != 0 and samples != 2):
		samples = 2
	var shadow_size = options.get("shadow_map_size", 2048)
	if not (shadow_size is int or shadow_size is float) or (shadow_size != 0 and shadow_size != 512 and shadow_size != 1024 and shadow_size != 2048):
		shadow_size = 2048
	var viewport := get_viewport()
	var msaa := Viewport.MSAA_DISABLED if samples == 0 else Viewport.MSAA_2X
	if viewport.msaa_3d != msaa:
		viewport.msaa_3d = msaa
	# 카메라 등 다른 옵션을 보낼 때 같은 그림자 아틀라스를 다시 만들지 않는다.
	# 끄기는 광원에서 처리하고 마지막 아틀라스를 유지한다.
	if shadow_size > 0 and _applied_shadow_map_size != int(shadow_size):
		RenderingServer.directional_shadow_atlas_set_size(int(shadow_size), bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", false)))
		_applied_shadow_map_size = int(shadow_size)
	sun.shadow_enabled = bool(options.get("shadows", true)) and shadow_size > 0
	# 앱은 기기 설정(30·60)을 전달하고, 개발·검사 실행은 0(제한 없음)을 유지한다.
	var fps = options.get("max_fps", 0)
	if not (fps is int or fps is float) or (fps != 0 and fps != 30 and fps != 60):
		fps = 0
	if Engine.max_fps != int(fps):
		Engine.max_fps = int(fps)
	# 3D만 낮은 해상도로 그린 뒤 확대한다. Canvas UI·라벨은 원래 해상도를 유지한다.
	var render_scale = options.get("render_scale", 1.0)
	if not (render_scale is int or render_scale is float) or not (is_equal_approx(render_scale, 0.5) or is_equal_approx(render_scale, 0.75) or is_equal_approx(render_scale, 1.0)):
		render_scale = 1.0
	if not is_equal_approx(viewport.scaling_3d_scale, render_scale):
		viewport.scaling_3d_scale = render_scale

func _update_camera() -> void:
	_battlefield_camera.update_envelope(terrain, last_frame, Vector2i(columns, rows), _camera_model_libraries())
	_battlefield_camera.update_mode(options["camera"], _using_forge)
	_on_camera_pose_changed()

func _on_camera_pose_changed() -> void:
	_fit_camera_to_frame()
	_update_camera_visuals()

func _fit_camera_to_frame() -> void:
	_battlefield_camera.configure_geometry(Vector2i(columns, rows), _current_map.get("tiles", []),
		_using_chapter_environment, _using_forge, _environment_bounds, _environment_manifest.get("cameraPointsGodot", []))
	_battlefield_camera.fit_frame(get_viewport().get_visible_rect().size, last_frame,
		float(options.get("zoom", 1.0)), _formal_battlefield_rect(), combat_runtime.native_session())

func _formal_battlefield_rect() -> Rect2:
	if not is_instance_valid(session_controller): return Rect2()
	return session_controller.battlefield_rect()

func _update_camera_visuals() -> void:
	_apply_world_shake()
	_projectile_renderer.camera_changed()
	_units.camera_changed()
	# 최초 frame과 tween의 deferred Canvas draw에 카메라 참조를 미리 준비한다.
	_prepare_overlay_context()

func _apply_world_shake() -> void:
	world.position = Vector3.ZERO
	var payload: Dictionary = last_frame.get("presentation", {})
	var requested: Array = options.get("presentation_groups", [])
	var actual_size := get_viewport().get_visible_rect().size
	if requested.has("effects") and _presentation_nodes["effects"].supported_groups().has("effects"):
		var effects: Dictionary = payload.get("effects", {})
		world.position = _battlefield_camera.world_shake_offset(effects,last_frame.get("viewport", []),actual_size)
	var impact := _units._placements.shake_pixels()
	world.position += _battlefield_camera.world_shake_offset({"shake":[impact.x,impact.y]},[actual_size.x,actual_size.y],actual_size)

func _prepare_overlay_context() -> void:
	var map_size := Vector2(columns, rows)
	_presentation_nodes["effects"].prepare_context(camera, map_size, world)
	_presentation_nodes["selection"].prepare_context(camera, map_size, world)

func _present_overlays() -> void:
	_applied_groups.clear()
	var payload: Dictionary = last_frame.get("presentation", {})
	var requested: Array = options.get("presentation_groups", [])
	for group: String in _presentation_nodes:
		var node: Node2D = _presentation_nodes[group]
		var enabled: bool = world.visible and int(last_frame.get("presentationVersion", 0)) == 2 and requested.has(group) and payload.get(group) is Dictionary and node.supported_groups().has(group)
		if group == "selection": enabled = enabled and node.has_frame()
		var canvas_enabled: bool = enabled and not RuntimeProfile.options.get("hide_canvas", false)
		node.visible = canvas_enabled
		node.set_canvas_enabled(canvas_enabled)
		if group == "effects":
			_lightning_presentation.present(node.items, turrets, enemies, Vector2(columns, rows), enabled, bool(options.get("volume", true)))
			_machinegun_ricochet.present(node.items, last_frame.get("enemies", []), Vector2(columns, rows), float(last_frame.get("time", 0.0)), enabled)
		if canvas_enabled:
			if group == "selection":
				node.set_turrets(turrets, _units.turret_revision)
				# 평소 지면 표시는 라벨 뒤, 보상 dim은 남아 있는 모든 효과 앞.
				node.z_index = 100 if node.reward_targeting() else -100
			if group == "labels":
				node.present(camera, Vector2(columns, rows), world, _units.enemy_label_tops())
			else:
				node.present(camera, Vector2(columns, rows), world)
			_applied_groups.append(group)

func presentation() -> Dictionary:
	if not _map_request.is_empty():
		return _map_request.duplicate()
	if last_frame.is_empty():
		return {}
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return {}
	var origin := camera.unproject_position(world.to_global(Vector3(-columns / 2.0, 0.0, -rows / 2.0)))
	var x_axis := camera.unproject_position(world.to_global(Vector3(1.0 - columns / 2.0, 0.0, -rows / 2.0))) - origin
	var y_axis := camera.unproject_position(world.to_global(Vector3(-columns / 2.0, 0.0, 1.0 - rows / 2.0))) - origin
	var height_axis := camera.unproject_position(world.to_global(Vector3(-columns / 2.0, 1.0, -rows / 2.0))) - origin
	return {
		"presentationVersion": 2,
		"mapRevision": _map_revision,
		"sceneEpoch": _scene_epoch,
		"viewportRevision": int(last_frame.get("viewportRevision", 0)),
		"viewport": last_frame.get("viewport", []),
		"appliedGroups": _applied_groups.duplicate(),
		"projection": {
			"origin": [origin.x / size.x, origin.y / size.y],
			"xAxis": [x_axis.x / size.x, x_axis.y / size.y],
			"yAxis": [y_axis.x / size.x, y_axis.y / size.y],
			"heightAxis": [height_axis.x / size.x, height_axis.y / size.y],
		},
		"sequence": last_sequence, "camera": camera_mode,
		"nativeTurretLevels": bool(options["turret_levels"]),
		"nativeEffectEvents": _applied_groups.has("effects"),
		"nativeImpactEffectEvents": _applied_groups.has("effects"),
		"nativeBlastEffectEvents": _applied_groups.has("effects"),
		"nativeLinkedEffectEvents": _applied_groups.has("effects"),
		"nativeChainEffectEvents": _applied_groups.has("effects"),
		"nativeChargeEffectEvents": _applied_groups.has("effects"),
		"nativeSelectionAnimation": _applied_groups.has("selection"),
		"selectionRevision": _presentation_nodes["selection"].selection_revision,
		"transitioning": is_instance_valid(camera_transition) and camera_transition.is_running(),
	}

func _ensure_battle_base() -> void:
	if not _lighting_attached:
		_environment.attach_lighting(self)
		_lighting_attached = true
	_apply_graphics_options()

func begin_deferred_battle_presentation() -> void:
	_stage_preparation_generation += 1
	_battle_deferred = true
	set_battle_visible(false)
