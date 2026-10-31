extends Node3D
## Battlefield scene state, the combat session clock and small queries shared
## by every main layer.
const StageResources = preload("res://presentation/stage_resources.gd")
const FrameRows = preload("res://presentation/frame_rows.gd")
const StageManifest = preload("res://presentation/stage_manifest.gd")
const EffectPreparation = preload("res://presentation/effect_preparation.gd")
const RuntimeProfile = preload("res://app/runtime_profile.gd")
const LaunchMode = preload("res://app/launch_mode.gd")
const FrameMetrics = preload("res://app/frame_metrics.gd")

const StockpileIndicator = preload("res://ui/stockpile_indicator.gd")
const TurretLevelLabels = preload("res://ui/turret_level_labels.gd")
const BattlefieldLabels = preload("res://ui/battlefield_labels.gd")
const BattlefieldSelection = preload("res://ui/battlefield_selection.gd")
const BattlefieldEffects = preload("res://ui/battlefield_effects.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const NativeCombatRuntime = preload("res://combat/native_combat_runtime.gd")
const BattlefieldEnvironment = preload("res://environment/battlefield_environment.gd")
const CombatSpaceBackground = preload("res://environment/combat_space_background.gd")
const BattlefieldUnits = preload("res://presentation/battlefield_units.gd")
const SupportCorePresentation = preload("res://presentation/support_core_presentation.gd")
const BattlefieldProjectiles = preload("res://presentation/battlefield_projectiles.gd")
const BattlefieldPath = preload("res://presentation/battlefield_path.gd")
const LightningPresentation = preload("res://presentation/lightning_presentation.gd")
const MachinegunRicochet = preload("res://effects/machinegun_ricochet.gd")
const TURRET_MODELS = BattlefieldUnits.TURRET_MODELS
const ENEMY_MODELS = BattlefieldUnits.ENEMY_MODELS
const FoliageWind = BattlefieldEnvironment.FoliageWind
const PortalVortex = BattlefieldEnvironment.PortalVortex
const ChapterThreeProps = BattlefieldEnvironment.ChapterThreeProps
const ChapterThreeTiles = BattlefieldEnvironment.ChapterThreeTiles
const ForgeReflectionSky = BattlefieldEnvironment.ForgeReflectionSky
const ReflectionSky = BattlefieldEnvironment.ReflectionSky
const SessionController = preload("res://session/session_controller.gd")
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
## The app (--app) or development (--session) session that drives this battlefield.
var session_controller: Node
## Formal app battlefield (lobby, saves, account). Boot sets it before adding the
## scene; without boot it follows the launch flags. Read in _ready.
var app_mode := LaunchMode.default_app_mode()
## Combat simulation for the current stage; replaced when a stage starts.
var combat_runtime := _new_native_combat()
## Session-owned static presentation (map, selection, preview) decorated each frame.
var combat_base_frame: Dictionary = {}
var _native_frame_pending := false
var _pending_gem_bursts: Array = []
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
var _stockpile_indicator := StockpileIndicator.new()
var _presentation_layer := CanvasLayer.new()
var _presentation_nodes := {"labels": BattlefieldLabels.new(), "selection": BattlefieldSelection.new(), "effects": BattlefieldEffects.new()}
var _applied_groups: Array = []
var enemies: Dictionary:
	get: return _units.enemies
var projectiles: Dictionary:
	get: return _projectile_renderer.projectiles
var impacts: Dictionary:
	get: return _projectile_renderer.impacts
var impact_pool: Array[Node3D]:
	get: return _projectile_renderer.impact_pool
var impact_lights: Array[OmniLight3D]:
	get: return _projectile_renderer.impact_lights
var _world_environment := Environment.new()
var _fill_light := DirectionalLight3D.new()
var last_frame := {}
var columns: int:
	get: return _environment.columns
var rows: int:
	get: return _environment.rows
var options := {"camera": "angled", "zoom": 1.0, "shadows": true, "msaa_samples": 2, "shadow_map_size": 2048, "max_fps": 0, "render_scale": 1.0, "volume": true, "empty": false, "turret_levels": false}
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
var _chapter_two_paving_library: Node3D:
	get: return _environment._chapter_two_paving_library
var _chapter_two_props_library: Node3D:
	get: return _environment._chapter_two_props_library
var _environment_manifest: Dictionary:
	get: return _environment._environment_manifest
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
var _support_cores := SupportCorePresentation.new(world)
var _lightning_presentation := LightningPresentation.new(world)
var _machinegun_ricochet := MachinegunRicochet.new()
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

func _set_profile_enabled(enabled: bool) -> void:
	_frame_metrics.set_enabled(enabled)

func _new_native_combat() -> NativeCombatRuntime:
	var runtime = NativeCombatRuntime.new()
	runtime.clock_control_changing.connect(_on_session_clock_changing.bind(weakref(runtime)))
	runtime.clock_control_changed.connect(_on_session_clock_changed.bind(weakref(runtime)))
	return runtime

func _on_session_clock_changing(source: WeakRef) -> void:
	if source.get_ref() != combat_runtime: return
	_session_control_boundary_usec = -1
	# Deterministic commands inside an already accepted simulation frame must
	# not also charge physical CPU time. Manual test drivers own their own time.
	if not is_processing() or combat_runtime._advancing_session: return
	_session_control_boundary_usec = int(_session_now_usec.call())
	var host_active := _battle_visible and not _stage_preparation_pending and _session_has_focus and not _session_suspended
	var elapsed := _session_frame_delta(0.0, host_active, _session_host_revision, _session_control_boundary_usec)
	combat_runtime.accrue_session_time(elapsed, host_active)

func _on_session_clock_changed(source: WeakRef) -> void:
	if source.get_ref() != combat_runtime: return
	if _session_control_boundary_usec < 0 or combat_runtime._advancing_session: return
	var host_active := _battle_visible and not _stage_preparation_pending and _session_has_focus and not _session_suspended
	# Establish the new controls at the same exact boundary, so processing time
	# after it belongs to the new rate rather than being lost or charged twice.
	_session_frame_clock.reset()
	_session_frame_delta(0.0, host_active, _session_host_revision, _session_control_boundary_usec)
	_session_control_boundary_usec = -1

func _set_session_host_state(has_focus: bool, suspended: bool) -> void:
	if has_focus == _session_has_focus and suspended == _session_suspended: return
	# Close the old interval before the host gate or a child's pause command can
	# hide it. These boundaries only accrue debt, never run combat/ACK callbacks.
	var source: WeakRef = weakref(combat_runtime)
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
	return _session_frame_clock.sample(now_usec, host_active and combat_runtime._session_time_enabled(),
		activation, combat_runtime.clock_control_revision)

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
			node.set_canvas_enabled(false)
		_turret_level_labels.hide()
		_stockpile_indicator.hide()
		_screen_feedback.hide()
	else:
		for node: Node2D in _presentation_nodes.values(): node.set_process(true)
		_turret_level_labels.show()
		_stockpile_indicator.show()

func stage_preparation_current(generation: int) -> bool:
	return is_inside_tree() and generation == _stage_preparation_generation

func stage_feedback_frame() -> void:
	# process_frame alone runs before drawing. Wait for submission as well on a
	# real renderer; the next process frame keeps work out of post-draw callbacks.
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	await get_tree().process_frame

func resource_snapshot() -> Dictionary:
	return {"resources":StageResources.snapshot(),"manifest":_stage_manifest.duplicate(true),
		"battle_deferred":_battle_deferred,"battle_visible":_battle_visible,
		"environment":_environment.resource_snapshot(),"render_3d_disabled":get_viewport().disable_3d,
		"effects_prepared":effects_prepared,"preparing":_stage_preparation_pending}

func battle_preparation_pending() -> bool:
	return _stage_preparation_pending

func _camera_model_libraries() -> Array:
	if app_mode and _stage_manifest.is_empty(): return []
	if _camera_models.is_empty():
		for pair in [[TURRET_MODELS, _stage_manifest.get("tower_types", TURRET_MODELS.keys())],
			[ENEMY_MODELS, _stage_manifest.get("enemy_types", ENEMY_MODELS.keys())]]:
			var selected := {}
			for kind: String in pair[1]:
				selected[kind] = StageResources.load_resource(pair[0][kind])
			_camera_models.append(selected)
	return _camera_models
