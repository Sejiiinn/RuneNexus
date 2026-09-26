extends Node3D
const RuntimeProfile = preload("res://app/runtime_profile.gd")
const FrameMetrics = preload("res://app/frame_metrics.gd")

const TurretLevelLabels = preload("res://ui/turret_level_labels.gd")
const BattlefieldLabels = preload("res://ui/battlefield_labels.gd")
const BattlefieldSelection = preload("res://ui/battlefield_selection.gd")
const BattlefieldEffects = preload("res://ui/battlefield_effects.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const NativeCombatRuntime = preload("res://combat/native_combat_runtime.gd")
const BattlefieldEnvironment = preload("res://environment/battlefield_environment.gd")
const BattlefieldUnits = preload("res://presentation/battlefield_units.gd")
const BattlefieldProjectiles = preload("res://presentation/battlefield_projectiles.gd")
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
var _session_activation_revision := -1
var _session_input = preload("res://session/battlefield_input.gd").new(self)
var _standalone_session: Node
var _app_mode := "--app" in OS.get_cmdline_user_args() or (not "--session" in OS.get_cmdline_user_args() and not "--fixture" in OS.get_cmdline_user_args() and not "--script" in OS.get_cmdline_args() and not "-s" in OS.get_cmdline_args())
var _native_combat := NativeCombatRuntime.new()
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
var _projectile_renderer := BattlefieldProjectiles.new(world, camera)
var _environment := BattlefieldEnvironment.new(terrain, _world_environment, sun, _fill_light)


func _ready() -> void:
	RuntimeProfile.configure()
	_frame_metrics.attach(get_viewport())
	_set_profile_enabled(RuntimeProfile.enabled)
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
	_environment.attach_lighting(self)
	_apply_graphics_options()
	_units.failure.connect(_fail)
	_projectile_renderer.failure.connect(_fail)
	_environment.failed.connect(_fail)
	_environment.camera_reset_requested.connect(func(): camera_mode = "")
	if not _projectile_renderer.initialize() or not _environment.initialize():
		return
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
	if RenderingServer.frame_pre_draw.is_connected(_report_presentation):
		RenderingServer.frame_pre_draw.disconnect(_report_presentation)
	_environment.dispose()


func _fail(message: String) -> void:
	push_error(message)
	var boot=get_tree().get_first_node_in_group("rune_app_boot")
	if boot!=null: boot.fail_preparation(message)


func _process(delta: float) -> void:
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
		var host_active: bool = true
		var activation: int = 0
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
	world.visible = not bool(options["empty"])
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
	_battlefield_camera.update_envelope(terrain, last_frame, Vector2i(columns, rows), [TURRET_MODELS, ENEMY_MODELS])
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
	if not requested.has("effects") or not _presentation_nodes["effects"].supported_groups().has("effects"):
		return
	var effects: Dictionary = payload.get("effects", {})
	world.position = _battlefield_camera.world_shake_offset(effects, last_frame.get("viewport", []),
		get_viewport().get_visible_rect().size)


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
		if canvas_enabled:
			if group == "selection":
				node.set_turrets(turrets, _units.turret_revision)
				# 평소 지면 표시는 라벨 뒤, 보상 dim은 남아 있는 모든 효과 앞.
				node.z_index = 100 if node.reward_targeting() else -100
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
	_turret_level_labels.update(camera, turrets, bool(options["turret_levels"]) and world.visible)
	_present_overlays()


func _apply_frame(frame: Dictionary) -> void:
	var owned_snapshot := false
	var whole_tick := RuntimeProfile.begin()
	if _native_combat.active and not bool(frame.get("reset", false)) and int(frame.get("sceneEpoch", -1)) == _scene_epoch:
		var decorate_tick := RuntimeProfile.begin()
		frame = _native_combat.decorate_frame(frame, true)
		owned_snapshot = true
		RuntimeProfile.finish("decorate", decorate_tick)
		if _app_mode:
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


func _clear_scene() -> void:
	_native_combat = NativeCombatRuntime.new()
	_session_activation_revision = -1
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
	_projectile_renderer.clear()
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
	_battlefield_camera.invalidate_layout()
	return true


func _sync_turrets(units: Array) -> void:
	_units.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_units._sync_turrets(units)
	_environment.update_occupancy(units, TURRET_MODELS)


func _sync_enemies(units: Array) -> void:
	_units.configure(float(last_frame.get("time", 0.0)), Vector2i(columns, rows), options)
	_units._sync_enemies(units)


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


func _session_frame_delta(delta: float, host_active: bool, activation: int) -> float:
	if not host_active: return 0.0
	# A suspended engine may never sample inactive. The platform generation is
	# observed after resume and discards even an arbitrarily long first delta.
	if activation != _session_activation_revision:
		_session_activation_revision = activation
		return 0.0
	return delta
