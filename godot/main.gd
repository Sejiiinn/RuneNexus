extends Node3D
const StageResources = preload("res://presentation/stage_resources.gd")
const StageManifest = preload("res://presentation/stage_manifest.gd")
const EffectPreparation = preload("res://presentation/effect_preparation.gd")
const RuntimeProfile = preload("res://app/runtime_profile.gd")
const FrameMetrics = preload("res://app/frame_metrics.gd")

const TurretLevelLabels = preload("res://ui/turret_level_labels.gd")
const BattlefieldLabels = preload("res://ui/battlefield_labels.gd")
const BattlefieldSelection = preload("res://ui/battlefield_selection.gd")
const BattlefieldEffects = preload("res://ui/battlefield_effects.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const NativeCombatRuntime = preload("res://combat/native_combat_runtime.gd")
const BattlefieldEnvironment = preload("res://environment/battlefield_environment.gd")
const CombatSpaceBackground = preload("res://environment/combat_space_background.gd")
const BattlefieldUnits = preload("res://presentation/battlefield_units.gd")
const BattlefieldProjectiles = preload("res://presentation/battlefield_projectiles.gd")
const BattlefieldPath = preload("res://presentation/battlefield_path.gd")
const LightningPresentation = preload("res://presentation/lightning_presentation.gd")
const TURRET_MODELS = BattlefieldUnits.TURRET_MODELS
const ENEMY_MODELS = BattlefieldUnits.ENEMY_MODELS
const FoliageWind = BattlefieldEnvironment.FoliageWind
const PortalVortex = BattlefieldEnvironment.PortalVortex
const ChapterThreeProps = BattlefieldEnvironment.ChapterThreeProps
const ChapterThreeTiles = BattlefieldEnvironment.ChapterThreeTiles
const ForgeReflectionSky = BattlefieldEnvironment.ForgeReflectionSky
const ReflectionSky = BattlefieldEnvironment.ReflectionSky
const BattlefieldCamera = preload("res://session/battlefield_camera.gd")
const CAMERA_TRANSITION_SECONDS = BattlefieldCamera.CAMERA_TRANSITION_SECONDS
const CAMERA_DEPTH_MARGIN = BattlefieldCamera.CAMERA_DEPTH_MARGIN
const REFLECTION_TERRAIN_LAYER := 1 << 1
const REFLECTION_CRYSTAL_LAYER := 1 << 2

var _screen_feedback = preload("res://session/screen_feedback.gd").new()
var _session_frame_clock = preload("res://session/combat_frame_clock.gd").new()
var _session_now_usec: Callable = func(): return Time.get_ticks_usec()
var _session_control_boundary_usec: int = -1
var _session_host_revision := 0
var _session_has_focus := true
var _session_suspended := false
var _session_input = preload("res://session/battlefield_input.gd").new(self)
var _standalone_session: Node
var _app_mode := "--app" in OS.get_cmdline_user_args() or (not "--session" in OS.get_cmdline_user_args() and not "--fixture" in OS.get_cmdline_user_args() and not "--script" in OS.get_cmdline_args() and not "-s" in OS.get_cmdline_args())
var _native_combat := _new_native_combat()
var _native_combat_base_frame: Dictionary = {}
var camera := Camera3D.new()
var _battlefield_camera := BattlefieldCamera.new(camera)
# Compatibility for scene consumers and existing camera verification scripts.
var camera_mode: String:
	get: return _battlefield_camera.camera_mode
	set(value): _battlefield_camera.camera_mode = value
var camera_transition: Tween:
	get: return _battlefield_camera.camera_transition
	set(value): _battlefield_camera.camera_transition = value
var _camera_envelope: AABB:
	get: return _battlefield_camera._camera_envelope
var sun := DirectionalLight3D.new()
var world := Node3D.new()
var terrain := Node3D.new()
var turrets: Dictionary:
	get: return _units.turrets
var _turret_level_labels := TurretLevelLabels.new()
var _presentation_layer := CanvasLayer.new()
var _presentation_nodes := {"labels": BattlefieldLabels.new(), "selection": BattlefieldSelection.new(), "effects": BattlefieldEffects.new()}
var _applied_groups: Array = []
var enemies: Dictionary:
	get: return _units.enemies
var projectiles: Dictionary:
	get: return _projectile_renderer.projectiles
var _projectile_events = preload("res://effects/projectile_events.gd").new()
var impacts: Dictionary:
	get: return _projectile_renderer.impacts
var impact_pool: Array[Node3D]:
	get: return _projectile_renderer.impact_pool
var impact_lights: Array[OmniLight3D]:
	get: return _projectile_renderer.impact_lights
var _world_environment := Environment.new()
var _fill_light := DirectionalLight3D.new()
var field: Dictionary:
	get: return _projectile_renderer.field
var last_frame := {}
var columns: int:
	get: return _environment.columns
var rows: int:
	get: return _environment.rows
var options := {"camera": "angled", "zoom": 1.0, "shadows": true, "msaa_samples": 2, "shadow_map_size": 2048, "volume": true, "empty": false, "turret_levels": false}
var _applied_shadow_map_size := -1
var _frame_metrics := FrameMetrics.new()
var last_sequence := -1
var _scene_epoch := -1
var received_frames := 0
var standalone_time := 0.0
var standalone_playing := false
var _terrain_library: Node3D:
	get: return _environment._terrain_library
var _chapter_three_props_library: Node3D:
	get: return _environment._chapter_three_props_library
var _chapter_three_terrain_library: Node3D:
	get: return _environment._chapter_three_terrain_library
var _chapter_two_terrain_library: Node3D:
	get: return _environment._chapter_two_terrain_library
var _chapter_two_paving_library: Node3D:
	get: return _environment._chapter_two_paving_library
var _chapter_two_props_library: Node3D:
	get: return _environment._chapter_two_props_library
var _environment_geology_library: Node3D:
	get: return _environment._environment_geology_library
var _environment_props_library: Node3D:
	get: return _environment._environment_props_library
var _environment_manifest: Dictionary:
	get: return _environment._environment_manifest
var _environment_manifests: Array:
	get: return _environment._environment_manifests
var _environment_stage: int:
	get: return _environment._environment_stage
var _using_chapter_environment: bool:
	get: return _environment._using_chapter_environment
var _using_forge: bool:
	get: return _environment._using_forge
var _environment_bounds: AABB:
	get: return _environment._environment_bounds
var _landmark_library: Node3D:
	get: return _environment._landmark_library
var _portal_material: ShaderMaterial:
	get: return _environment._portal_material
var _dressing_library: Node3D:
	get: return _environment._dressing_library
var _dressing_variants: Array:
	get: return _environment._dressing_variants
var _using_dressing: bool:
	get: return _environment._using_dressing
var _foliage_material: ShaderMaterial:
	get: return _environment._foliage_material
var _build_tile_slots: PackedInt32Array:
	get: return _environment._build_tile_slots
var _occupied_build_tiles: Vector2i:
	get: return _environment._occupied_build_tiles
var _terrain_manifest: Dictionary:
	get: return _environment._terrain_manifest
var _current_map: Dictionary:
	get: return _environment._current_map
var _map_revision := -1
var _map_request := {}
var _using_authored: bool:
	get: return _environment._using_authored
var _portals: Array[Node3D]:
	get: return _environment._portals
var _cores: Array[Dictionary]:
	get: return _environment._cores
var _build_preview: Dictionary:
	get: return _units._build_preview
var _projectile_meshes: Dictionary:
	get: return _projectile_renderer._projectile_meshes
var _ballistic_pool: Dictionary:
	get: return _projectile_renderer._ballistic_pool
var _fire_projectile_pool: Array[Node3D]:
	get: return _projectile_renderer._fire_projectile_pool
var _generic_projectile_pool: Dictionary:
	get: return _projectile_renderer._generic_projectile_pool

var _units := BattlefieldUnits.new(world, camera)
var _lightning_presentation := LightningPresentation.new(world)
var _projectile_renderer := BattlefieldProjectiles.new(world, camera)
var _path_guide := BattlefieldPath.new(world)
var _environment := BattlefieldEnvironment.new(terrain, _world_environment, sun, _fill_light)
var _space_background := CombatSpaceBackground.new()
var _camera_models: Array = []
var _stage_preparation_generation := 0
var _realizing_battle := false
var _battle_deferred := false
var _battle_visible := true
var _battle_requested_visible := true
var _stage_manifest: Dictionary = {}
var _pending_stage_manifest: Dictionary = {}
var _preparation_was_deferred := false
var _prepared_stage_key := ""
var _stage_preparation_pending := false
var _stage_preparation_error := ""
var _stage_entry_active := false
var _lighting_attached := false
var effects_prepared := false
var _effects_preparing := false
signal effects_preparation_finished(success: bool)

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


func _ready() -> void:
	_presentation_nodes["effects"].spatial_lightning = true
	RuntimeProfile.configure()
	_frame_metrics.attach(get_viewport())
	_set_profile_enabled(RuntimeProfile.enabled)
	add_child(_space_background)
	add_child(_turret_level_labels)
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
	if not _app_mode:
		_presentation_nodes["effects"].prepare_assets()
		_ensure_battle_base()
		if not _projectile_renderer.initialize(): return
	else:
		begin_deferred_battle_presentation()
	get_viewport().size_changed.connect(_update_camera)
	# Tween은 _process 뒤에 진행되므로 실제 렌더 직전의 카메라로 투영을 보고.
	RenderingServer.frame_pre_draw.connect(_report_presentation)
	_update_camera()
	if _app_mode or "--session" in OS.get_cmdline_user_args():
		var entry := "res://app/app_lifecycle.gd" if _app_mode else "res://session/standalone.gd"
		_standalone_session = load(entry).new()
		add_child(_standalone_session)
		return
	# Explicit fixture mode is retained for isolated visual and combat checks.
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://assets/preview_frame.json"))
	if fixture is Dictionary: _apply_frame(fixture)


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
	_projectile_renderer.field = {}
	_projectile_renderer._projectile_meshes.clear()
	_lightning_presentation.clear()
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
	RuntimeProfile.apply_render_partition(get_viewport(), _native_combat.session.get("phase", "") == "wave")
	_frame_metrics.begin_frame()
	if standalone_playing and not last_frame.is_empty():
		standalone_time += delta
		var frame: Dictionary = last_frame.duplicate(true)
		frame["time"] = standalone_time
		frame["impacts"] = []
		for index in range(mini(3, frame.get("enemies", []).size())):
			var progress := fposmod(standalone_time + index * 0.37, 1.4) / 1.1
			if progress < 1.0:
				var target: Array = frame["enemies"][index]
				frame["impacts"].append([100 + index, target[1], target[2], 1.2, progress])
		_apply_frame(frame)
	if _native_combat.native_session():
		var host_active: bool = _session_has_focus and not _session_suspended
		var activation: int = _session_host_revision
		var session_delta := _session_frame_delta(delta, host_active, activation)
		var combat_tick := RuntimeProfile.begin()
		var advanced := _native_combat.advance_session(session_delta, host_active)
		RuntimeProfile.finish("combat", combat_tick)
		if advanced and not _native_combat_base_frame.is_empty():
			_apply_frame(_native_combat_base_frame)
	if _frame_metrics.advance(delta):
		_frame_metrics.report({"received_frames":received_frames,"sequence":last_sequence,
			"authored_terrain":_using_authored,"combat_active":_native_combat.active,
			"combat_sequence":_native_combat.sequence,"combat_elapsed":_native_combat.elapsed,
			"phase":_native_combat.session.get("phase", ""),"paused":_native_combat.session.get("paused", false)})


func _set_profile_enabled(enabled: bool) -> void:
	_frame_metrics.set_enabled(enabled)


func _apply_options() -> void:
	_presentation_nodes["effects"].diagnostic_skip = str(options.get("diagnostic_skip_canvas", ""))
	RunicFire.set_diagnostic_mode(str(options.get("runic_fire_mode", "all")))
	world.visible = _battle_visible and not bool(options["empty"])
	_apply_graphics_options()
	_update_camera()
	if not last_frame.is_empty():
		_update_impacts(last_frame.get("impacts", []))


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
		float(options.get("zoom", 1.0)), _formal_battlefield_rect(), _native_combat.native_session())


func _formal_battlefield_rect() -> Rect2:
	if not _app_mode or not is_instance_valid(_standalone_session): return Rect2()
	var hud = _standalone_session.hud
	if not is_instance_valid(hud) or not hud.has_method("battlefield_rect"): return Rect2()
	return hud.battlefield_rect()


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
		if node.has_method("set_canvas_enabled"): node.set_canvas_enabled(canvas_enabled)
		if group == "effects":
			_lightning_presentation.present(node.items, turrets, enemies, Vector2(columns, rows), enabled, bool(options.get("volume", true)))
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
		"nativeProjectileEvents": true,
		"nativeSelectionAnimation": _applied_groups.has("selection"),
		"selectionRevision": _presentation_nodes["selection"].selection_revision,
		"transitioning": is_instance_valid(camera_transition) and camera_transition.is_running(),
	}


func _report_presentation() -> void:
	if not _battle_visible or _battle_deferred: return
	_units.update_placements()
	_apply_world_shake()
	_turret_level_labels.update(camera, turrets, bool(options["turret_levels"]) and world.visible)
	_present_overlays()

func confirm_turret_placement(id: int, type: String, x: int, y: int) -> void:
	_units.confirm_placement(id,type,x,y)

func cancel_turret_placement(id: int) -> void:
	_units.cancel_placement(id)


func _apply_frame(frame: Dictionary) -> void:
	if _battle_deferred or (_app_mode and not _battle_visible and not _realizing_battle):
		var epoch := int(frame.get("sceneEpoch", 0))
		if epoch < _scene_epoch: return
		if bool(frame.get("reset", false)) or epoch > _scene_epoch:
			_clear_scene()
			_scene_epoch = epoch
		if not bool(frame.get("reset", false)):
			last_frame = frame.duplicate(true)
		return
	var owned_snapshot := false
	var whole_tick := RuntimeProfile.begin()
	if _native_combat.active and not bool(frame.get("reset", false)) and int(frame.get("sceneEpoch", -1)) == _scene_epoch:
		var decorate_tick := RuntimeProfile.begin()
		# Both real native entry points use tile units with canonical Canvas art.
		# The development session needs the same glyph/effect conversion as --app.
		var native_presentation := _app_mode or is_instance_valid(_standalone_session)
		frame = _native_combat.decorate_frame(frame, true, native_presentation)
		owned_snapshot = true
		RuntimeProfile.finish("decorate", decorate_tick)
		if native_presentation:
			frame = preload("res://ui/app_presentation.gd").normalize(frame)
		if _native_combat.native_session():
			frame.zoom = _session_input.zoom
			options.zoom = _session_input.zoom
			var viewport: Array = frame.get("viewport", [])
			var center: Array = frame.get("screenCenter", [])
			if viewport.size() == 2 and center.size() == 2:
				frame.screenCenter = [center[0] + _session_input.pan.x * viewport[0], center[1] + _session_input.pan.y * viewport[1]]
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
				group_frame["playbackSpeed"] = float(_native_combat.session.get("speed", 1.0))
			var node: Node2D = _presentation_nodes[group]
			var canvas_enabled: bool = world.visible and int(frame.get("presentationVersion", 0)) == 2 and options.get("presentation_groups", []).has(group) and node.supported_groups().has(group) and not RuntimeProfile.options.get("hide_canvas", false)
			if node.has_method("set_canvas_enabled"): node.set_canvas_enabled(canvas_enabled)
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
	for data: Array in _presentation_nodes["effects"].blast_impacts:
		merged_impacts[int(data[0])] = data
	for data: Array in frame.get("impacts", []):
		merged_impacts[int(data[0])] = data
	last_frame["impacts"] = merged_impacts.values()
	if frame.get("projectileEvents") is Dictionary:
		last_frame["projectiles"] = _projectile_events.sample(frame["projectileEvents"], float(frame.get("time", 0.0)))
	else:
		_projectile_events.clear()
	var camera_tick := RuntimeProfile.begin()
	_update_camera()
	RuntimeProfile.finish("camera", camera_tick)
	var session_presentation_tick := RuntimeProfile.begin()
	_update_session_presentation()
	RuntimeProfile.finish("session_presentation", session_presentation_tick)
	var turrets_tick := RuntimeProfile.begin()
	_sync_turrets(frame.get("turrets", []))
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
	_lightning_presentation.clear()
	_native_combat.active = false
	_native_combat = _new_native_combat()
	_session_frame_clock.reset()
	_session_input.reset()
	_battlefield_camera.reset()
	_screen_feedback.hide()
	_native_combat_base_frame.clear()
	_projectile_events.clear()
	world.position = Vector3.ZERO
	_turret_level_labels.clear()
	for node: Node2D in _presentation_nodes.values():
		node.clear()
		node.hide()
	_applied_groups.clear()
	_units.clear()
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
	_units._sync_turrets(units)
	var selection = _presentation_nodes["selection"]
	_units.sync_gem_orbits(selection._frame, selection.selection_revision, float(last_frame.get("time", 0.0)))
	_environment.update_occupancy(units, TURRET_MODELS)


func _sync_enemies(units: Array) -> void:
	_units.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_units.sync_guardian_events(_native_combat)
	_units._sync_enemies(units)
	_units.sync_sniper_aim()


func play_gem_equip_burst(id: int, gem: String) -> void:
	_units.play_gem_equip_burst(id, gem)


func _sync_build_preview(data) -> void:
	_units.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_units._sync_build_preview(data)


func _sync_projectiles(units: Array) -> void:
	_projectile_renderer.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_projectile_renderer._sync_projectiles(units, turrets)


func _update_impacts(units: Array) -> void:
	_projectile_renderer.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_projectile_renderer._update_impacts(units)


func _unhandled_key_input(event: InputEvent) -> void:
	if _app_mode: return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: standalone_playing = not standalone_playing
		KEY_C: options["camera"] = "drone" if options["camera"] == "angled" else "angled"
		KEY_S: options["shadows"] = not options["shadows"]
		KEY_V: options["volume"] = not options["volume"]
	_apply_options()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_standalone_session) and _app_mode:
		var app = _standalone_session
		if app.in_lobby: return
		if is_instance_valid(app.hud) and app.hud.has_method("blocks_board_input") and app.hud.blocks_board_input():
			_session_input.contacts.clear()
			return
	_session_input.handle(event)


func _update_session_presentation() -> void:
	var logical: Array = last_frame.get("viewport", [])
	var size := Vector2(logical[0],logical[1]) if logical.size() == 2 else get_viewport().get_visible_rect().size
	_screen_feedback.update_state(_native_combat, size)
	if not _native_combat.native_session(): return
	var collapsing: bool = _native_combat.session.get("phase") in ["coreDestruction", "failure"] and not _cores.is_empty()
	var core: Vector3 = _cores[0].root.global_position if collapsing else Vector3.ZERO
	var camera_adjusted := _battlefield_camera.apply_session_offsets(_session_input.pan, _session_input.zoom,
		size, logical.is_empty(), collapsing, core, _native_combat.destruction_elapsed,
		get_viewport().get_visible_rect().size)
	# Project effects after native drag/collapse offsets, using the final camera.
	# The base camera update above runs before these session-specific offsets.
	if camera_adjusted: _update_camera_visuals()


func _new_native_combat() -> NativeCombatRuntime:
	var runtime = NativeCombatRuntime.new()
	runtime.clock_control_changing.connect(_on_session_clock_changing.bind(weakref(runtime)))
	runtime.clock_control_changed.connect(_on_session_clock_changed.bind(weakref(runtime)))
	return runtime

func _on_session_clock_changing(source: WeakRef) -> void:
	if source.get_ref() != _native_combat: return
	_session_control_boundary_usec = -1
	# Deterministic commands inside an already accepted simulation frame must
	# not also charge physical CPU time. Manual test drivers own their own time.
	if not is_processing() or _native_combat._advancing_session: return
	_session_control_boundary_usec = int(_session_now_usec.call())
	var host_active := _battle_visible and not _stage_preparation_pending and _session_has_focus and not _session_suspended
	var elapsed := _session_frame_delta(0.0, host_active, _session_host_revision, _session_control_boundary_usec)
	_native_combat.accrue_session_time(elapsed, host_active)

func _on_session_clock_changed(source: WeakRef) -> void:
	if source.get_ref() != _native_combat: return
	if _session_control_boundary_usec < 0 or _native_combat._advancing_session: return
	var host_active := _battle_visible and not _stage_preparation_pending and _session_has_focus and not _session_suspended
	# Establish the new controls at the same exact boundary, so processing time
	# after it belongs to the new rate rather than being lost or charged twice.
	_session_frame_clock.reset()
	_session_frame_delta(0.0, host_active, _session_host_revision, _session_control_boundary_usec)
	_session_control_boundary_usec = -1

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


func _set_session_host_state(has_focus: bool, suspended: bool) -> void:
	if has_focus == _session_has_focus and suspended == _session_suspended: return
	# Close the old interval before the host gate or a child's pause command can
	# hide it. These boundaries only accrue debt, never run combat/ACK callbacks.
	var source: WeakRef = weakref(_native_combat)
	_on_session_clock_changing(source)
	_session_has_focus = has_focus
	_session_suspended = suspended
	_session_host_revision += 1
	# Rebase at the same timestamp, including host-only resume without a command.
	# A second gate/repeated notification cannot charge background time twice.
	_on_session_clock_changed(source)


func _session_frame_delta(_engine_delta: float, host_active: bool, activation: int, now_usec: int = -1) -> float:
	# Engine _process delta is capped after stalls. Sample actual monotonic time
	# instead, while rejecting suspended/paused/hidden intervals at their gates.
	if now_usec < 0: now_usec = int(_session_now_usec.call())
	return _session_frame_clock.sample(now_usec, host_active and _native_combat._session_time_enabled(),
		activation, _native_combat.clock_control_revision)


func _ensure_battle_base() -> void:
	if not _lighting_attached:
		_environment.attach_lighting(self)
		_lighting_attached = true
	_apply_graphics_options()

func begin_deferred_battle_presentation() -> void:
	_stage_preparation_generation += 1
	_battle_deferred = true
	set_battle_visible(false)

func set_battle_visible(active: bool) -> void:
	if active != _battle_requested_visible: _session_frame_clock.reset()
	_battle_requested_visible = active
	_battle_visible = active and not _battle_deferred and not _stage_preparation_pending
	world.visible = _battle_visible and not bool(options.get("empty", false))
	world.process_mode = Node.PROCESS_MODE_INHERIT if _battle_visible else Node.PROCESS_MODE_DISABLED
	_space_background.visible = _battle_visible
	_space_background.process_mode = Node.PROCESS_MODE_INHERIT if _battle_visible else Node.PROCESS_MODE_DISABLED
	camera.current = _battle_visible
	get_viewport().disable_3d = not _battle_visible
	_battlefield_camera.set_process(_battle_visible)
	if is_instance_valid(camera_transition) and camera_transition.is_valid():
		if _battle_visible: camera_transition.play()
		else: camera_transition.pause()
	if not _battle_visible:
		for node: Node2D in _presentation_nodes.values():
			node.hide()
			node.set_process(false)
			if node.has_method("set_canvas_enabled"): node.set_canvas_enabled(false)
		_turret_level_labels.hide()
		_screen_feedback.hide()
	else:
		for node: Node2D in _presentation_nodes.values(): node.set_process(true)
		_turret_level_labels.show()

func stage_preparation_current(generation: int) -> bool:
	return is_inside_tree() and generation == _stage_preparation_generation

func stage_feedback_frame() -> void:
	# process_frame alone runs before drawing. Wait for submission as well on a
	# real renderer; the next process frame keeps work out of post-draw callbacks.
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	await get_tree().process_frame

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
	if boot != null:
		boot._effects_pending = true
		boot._refresh()
	if is_instance_valid(_standalone_session): _standalone_session._refresh_ui()
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
	var frame: Dictionary = _native_combat_base_frame if not _native_combat_base_frame.is_empty() else last_frame
	if frame.is_empty(): return false
	_realizing_battle = true
	_apply_frame(frame)
	_realizing_battle = false
	if _stage_preparation_pending: await stage_feedback_frame()
	if not stage_preparation_current(generation) or not _stage_preparation_error.is_empty(): return false
	if _app_mode and not effects_prepared:
		if not await prepare_effects(): return false
	if not stage_preparation_current(generation) or not _stage_preparation_error.is_empty(): return false
	_stage_preparation_pending = false
	_stage_entry_active = false
	set_battle_visible(_battle_requested_visible)
	return true

func resource_snapshot() -> Dictionary:
	return {"resources":StageResources.snapshot(),"manifest":_stage_manifest.duplicate(true),
		"battle_deferred":_battle_deferred,"battle_visible":_battle_visible,
		"environment":_environment.resource_snapshot(),"render_3d_disabled":get_viewport().disable_3d,
		"effects_prepared":effects_prepared,"preparing":_stage_preparation_pending}

func battle_preparation_pending() -> bool:
	return _stage_preparation_pending


func _camera_model_libraries() -> Array:
	if _app_mode and _stage_manifest.is_empty(): return []
	if _camera_models.is_empty():
		for pair in [[TURRET_MODELS, _stage_manifest.get("tower_types", TURRET_MODELS.keys())],
			[ENEMY_MODELS, _stage_manifest.get("enemy_types", ENEMY_MODELS.keys())]]:
			var selected := {}
			for kind: String in pair[1]:
				selected[kind] = StageResources.load_resource(pair[0][kind])
			_camera_models.append(selected)
	return _camera_models
