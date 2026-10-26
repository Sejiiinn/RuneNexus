extends "res://main_frame.gd"
## Stage resource preparation, its cancellation and the battle presentation commit.

func prepare_stage_resources(catalog, index: int, derived: Dictionary, restored_state: Dictionary = {}) -> bool:
	_stage_entry_active = true
	_stage_preparation_error = ""
	_preparation_was_deferred = _battle_deferred
	var manifest := StageManifest.for_stage(catalog, index, derived, restored_state)
	var paths: Array = manifest.paths
	for path: String in EffectPreparation.resource_paths(manifest.enemy_types, manifest.tower_types):
		if path not in paths: paths.append(path)
	var environment_paths: Array = _environment.resource_paths(manifest.map)
	if environment_paths.is_empty(): return false
	for path: String in environment_paths:
		if path not in paths: paths.append(path)
	manifest.key = "%s:%s:%s" % [manifest.stage_id, str(manifest.enemy_types), str(manifest.tower_types)]
	_pending_stage_manifest = manifest
	_battle_deferred = true
	# Retained same-stage Continue/restart needs no overlay or asynchronous work.
	if manifest.key == _prepared_stage_key and effects_prepared: return true
	_stage_preparation_generation += 1
	var generation := _stage_preparation_generation
	_stage_preparation_pending = true
	var boot = get_tree().get_first_node_in_group("rune_app_boot")
	if boot != null: boot.set_battle_preparing(true)
	if is_instance_valid(session_controller): session_controller.refresh_ui()
	set_battle_visible(_battle_requested_visible)
	await stage_feedback_frame()
	if not stage_preparation_current(generation): return false
	return await StageResources.prepare_threaded(paths, self, generation)

func request_stage_preparation_cancel() -> void:
	_stage_preparation_generation += 1

func cancel_stage_preparation() -> void:
	_stage_entry_active = false
	_pending_stage_manifest.clear()
	StageResources.retain(_stage_manifest.get("paths", []), _prepared_stage_key)
	_battle_deferred = _preparation_was_deferred
	_stage_preparation_pending = false
	set_battle_visible(_battle_requested_visible)

func _commit_stage_resources() -> bool:
	if _pending_stage_manifest.is_empty(): return true
	var manifest := _pending_stage_manifest
	var key: String = manifest.key
	if key != _prepared_stage_key:
		effects_prepared = false
		_prepared_stage_key = ""
		_camera_models.clear()
		_battlefield_camera._camera_actor_bounds = AABB()
		# The durable transition has committed. Retire old instances only now.
		_units.clear()
		_lightning_presentation.clear()
		_machinegun_ricochet.clear()
		if not _environment.prepare_for_map(manifest.map): return false
		if _stage_preparation_pending: await stage_feedback_frame()
		_units.retain_stage(manifest.enemy_types)
		if not _projectile_renderer.configure_stage(manifest.tower_types): return false
		EffectPreparation.retain_stage(manifest.enemy_types, manifest.tower_types)
		StageResources.retain(manifest.paths, key)
		effects_prepared = false
		_prepared_stage_key = key
	_stage_manifest = manifest
	_pending_stage_manifest = {}
	return true

func realize_battle_presentation() -> bool:
	var generation := _stage_preparation_generation
	if not await _commit_stage_resources(): return false
	# Finish the ownership commit before honoring Back; it must never leave half
	# an old stage retained after the durable run has already changed.
	if not stage_preparation_current(generation): return false
	if _stage_preparation_pending: await stage_feedback_frame()
	if not stage_preparation_current(generation): return false
	_ensure_battle_base()
	_presentation_nodes["effects"].prepare_assets()
	if _stage_preparation_pending: await stage_feedback_frame()
	if not stage_preparation_current(generation): return false
	_battle_deferred = false
	var frame: Dictionary = combat_base_frame if not combat_base_frame.is_empty() else last_frame
	if frame.is_empty(): return false
	_realizing_battle = true
	apply_frame(frame)
	_realizing_battle = false
	if _stage_preparation_pending: await stage_feedback_frame()
	if not stage_preparation_current(generation) or not _stage_preparation_error.is_empty(): return false
	if app_mode and not effects_prepared:
		if not await prepare_effects(): return false
	if not stage_preparation_current(generation) or not _stage_preparation_error.is_empty(): return false
	_stage_preparation_pending = false
	_stage_entry_active = false
	set_battle_visible(_battle_requested_visible)
	return true
