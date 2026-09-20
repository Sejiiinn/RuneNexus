extends Node3D

const TurretLevelLabels = preload("res://ui/turret_level_labels.gd")
const BattlefieldLabels = preload("res://ui/battlefield_labels.gd")
const BattlefieldSelection = preload("res://ui/battlefield_selection.gd")
const BattlefieldEffects = preload("res://ui/battlefield_effects.gd")
const Impact = preload("res://effects/godot_impact.gd")
const FieldCache = preload("res://effects/field_cache.gd")
const WeaponAtlas = preload("res://effects/weapon_atlas.gd")
const MachineGunMuzzle = preload("res://effects/machinegun_muzzle.gd")
const BallisticProjectile = preload("res://effects/ballistic_projectile.gd")
const RunicFire = preload("res://effects/runic_fire.gd")
const EnemyFrost = preload("res://effects/enemy_frost.gd")
const EnemyBurn = preload("res://effects/enemy_burn.gd")
const NativeCombatRuntime = preload("res://combat/native_combat_runtime.gd")
const Terrain = preload("res://assets/environment/terrain.glb")
const Landmarks = preload("res://assets/environment/landmarks.glb")
const Dressing = preload("res://assets/environment/dressing.glb")
const PortalVortex = preload("res://environment/portal_vortex.gdshader")
const ReflectionSky = preload("res://materials/battlefield_reflection_sky.tres")
const ForgeReflectionSky = preload("res://materials/forge_reflection_sky.tres")
const FoliageWind = preload("res://environment/foliage_wind.gdshader")
const ChapterThreeProps = preload("res://environment/chapter_three_props.gd")
const ChapterThreeTiles = preload("res://environment/chapter_three_tiles.gd")
const ChapterTwoEnvironment = preload("res://environment/chapter_two_environment.gd")
const TURRET_MODELS := {
	"arrow": preload("res://assets/turrets/arrow.glb"),
	"cannon": preload("res://assets/turrets/cannon.glb"),
	"magic": preload("res://assets/turrets/magic.glb"),
	"frost": preload("res://assets/turrets/frost.glb"),
	"sniper": preload("res://assets/turrets/sniper.glb"),
	"lightning": preload("res://assets/turrets/lightning.glb"),
}
const ENEMY_MODELS := {
	"normal": preload("res://assets/enemies/normal.glb"),
	"armored": preload("res://assets/enemies/armored.glb"),
	"shielded": preload("res://assets/enemies/shielded.glb"),
	"fast": preload("res://assets/enemies/fast.glb"),
	"tank": preload("res://assets/enemies/tank.glb"),
	"boss": preload("res://assets/enemies/boss.glb"),
	# 실드/HP/상태 표시는 실제 프레임을 유지하고 기존 보스 본체를 공유한다.
	"shieldBoss": preload("res://assets/enemies/boss.glb"),
	"forgeBoss": preload("res://assets/enemies/boss.glb"),
}
const PROJECTILE_COLORS := {
	"arrow": Color("ffe3a3"), "cannon": Color("ffb261"), "magic": Color("ff8528"),
	"frost": Color("94e6ff"), "sniper": Color("ffeec4"), "lightning": Color("c7d8ff"),
}
const CAMERA_TRANSITION_SECONDS := 0.7
const CAMERA_DEPTH_MARGIN := 0.5
const REFLECTION_TERRAIN_LAYER := 1 << 1
const REFLECTION_CRYSTAL_LAYER := 1 << 2

var bridge: Object
var _native_combat := NativeCombatRuntime.new()
var _native_combat_base_frame: Dictionary = {}
var camera := Camera3D.new()
var camera_mode := ""
var camera_transition: Tween
var _camera_terrain_id := 0
var _camera_map_bounds := AABB()
var _camera_actor_bounds := AABB()
var _camera_envelope := AABB()
var _camera_enemy_scale := 1.0
var _camera_impact_radius := 0.0
var sun := DirectionalLight3D.new()
var world := Node3D.new()
var terrain := Node3D.new()
var turrets := {}
var _turret_level_labels := TurretLevelLabels.new()
var _presentation_layer := CanvasLayer.new()
var _presentation_nodes := {"labels": BattlefieldLabels.new(), "selection": BattlefieldSelection.new(), "effects": BattlefieldEffects.new()}
var _applied_groups: Array = []
var enemies := {}
var projectiles := {}
var _projectile_events = preload("res://effects/projectile_events.gd").new()
var impacts := {}
var impact_pool: Array[Node3D] = []
var impact_lights: Array[OmniLight3D] = []
var _world_environment := Environment.new()
var _fill_light := DirectionalLight3D.new()
var field: Dictionary
var last_frame := {}
var columns := 8
var rows := 10
var options := {"camera": "angled", "zoom": 1.0, "shadows": true, "msaa_samples": 2, "shadow_map_size": 2048, "volume": true, "empty": false, "turret_levels": false}
var _applied_shadow_map_size := -1
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
var last_sequence := -1
var _scene_epoch := -1
var received_frames := 0
var standalone_time := 0.0
var standalone_playing := false
var _terrain_library: Node3D
var _chapter_three_props_library: Node3D
var _chapter_three_terrain_library: Node3D
var _chapter_two_terrain_library: Node3D
var _chapter_two_paving_library: Node3D
var _chapter_two_props_library: Node3D
var _environment_geology_library: Node3D
var _environment_props_library: Node3D
var _environment_manifest := {}
var _environment_manifests: Array = []
var _environment_stage := 0
var _using_chapter_environment := false
var _using_forge := false
var _environment_bounds := AABB()
var _landmark_library: Node3D
var _portal_material: ShaderMaterial
var _dressing_library: Node3D
var _dressing_variants: Array = []
var _using_dressing := false
var _foliage_material: ShaderMaterial
var _build_tile_slots := PackedInt32Array()
var _occupied_build_tiles := Vector2i.ZERO
var _terrain_manifest := {}
var _current_map := {}
var _map_revision := -1
var _map_request := {}
var _camera_layout_revision := 0
var _camera_layout_key: Array = []
var _using_authored := false
var _portals: Array[Node3D] = []
var _cores: Array[Dictionary] = []
var _build_preview := {}
var _projectile_meshes := {}
var _ballistic_pool := {"arrow": [], "cannon": []}
var _fire_projectile_pool: Array[Node3D] = []
var _generic_projectile_pool := {"sniper": [], "frost": []}


func _ready() -> void:
	if Engine.has_singleton("RuneNexusPreview"):
		bridge = Engine.get_singleton("RuneNexusPreview")
	elif OS.get_name() == "Android":
		_fail("Flutter 전투 브리지가 등록되지 않았습니다.")
		return
	add_child(_turret_level_labels)
	_presentation_layer.layer = 2
	add_child(_presentation_layer)
	for node: Node2D in _presentation_nodes.values():
		_presentation_layer.add_child(node)
		node.hide()
	add_child(world)
	world.add_child(terrain)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# 실제 맵·모델·효과 경계로 _fit_camera_depth에서 설정한다.
	camera.current = true
	var environment_node := WorldEnvironment.new()
	var environment := _world_environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b20")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.86, 1.0)
	environment.ambient_light_energy = 0.16
	# 공용 하늘 반사. 배경과 확산 환경광은 별도 설정을 유지한다.
	environment.sky = ReflectionSky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	# 상면 총광량은 유지하고 약한 환경·보조광으로 그늘의 석재 면을 살린다.
	sun.rotation_degrees = Vector3(-48, -125, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.50
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	# 작은 직교 전장에 그림자 해상도를 모으고 낮은 기단·잎의 접촉을 보존.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# 낮은 depth bias는 석재 상면에 자기 그림자 줄무늬를 만들어 기존 값을 유지.
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.35
	# Mobile에서도 PCF를 사용해 접촉은 남기고 그림자 경계만 완만하게 한다.
	sun.shadow_blur = 1.25
	add_child(sun)
	_apply_graphics_options()
	var fill := _fill_light
	fill.rotation_degrees = Vector3(-40, 135, 0)
	fill.light_color = Color(0.65, 0.8, 1.0)
	fill.light_energy = 0.14
	add_child(fill)
	# 낮은 고정 입사각의 결정 전용 보조광: 급경사 면의 실제 반사 하이라이트.
	var crystal_light := DirectionalLight3D.new()
	crystal_light.name = "CoreSpecularLight"
	crystal_light.rotation_degrees = Vector3(10.0, 30.17, 0.0)
	crystal_light.light_color = Color(0.68, 0.95, 1.0)
	crystal_light.light_energy = 0.16
	crystal_light.light_cull_mask = REFLECTION_CRYSTAL_LAYER
	crystal_light.shadow_enabled = false
	add_child(crystal_light)
	for index in range(4):
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.42, 0.08)
		light.light_energy = 0.0
		world.add_child(light)
		impact_lights.append(light)
	field = FieldCache.load_shared()
	if field.is_empty():
		_fail("폭발 필드 캐시를 불러오지 못했습니다.")
		return
	_terrain_library = Terrain.instantiate()
	_prepare_vertex_colors(_terrain_library)
	_prepare_terrain_surfaces(_terrain_library)
	_landmark_library = Landmarks.instantiate()
	_prepare_vertex_colors(_landmark_library)
	var vortex := _landmark_library.find_child("portal_vortex", true, false) as MeshInstance3D
	var crystal := _landmark_library.find_child("core_crystal", true, false) as MeshInstance3D
	if not vortex or not crystal:
		_fail("공용 포탈·코어 GLB의 소용돌이·결정 노드를 찾지 못했습니다.")
		return
	# 타일별 복사본도 메시·재질을 공유하고 전투 시계만 한 번 전달.
	_portal_material = ShaderMaterial.new()
	_portal_material.shader = PortalVortex
	vortex.material_override = _portal_material
	vortex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var has_crystal_shell := false
	for surface in range(crystal.mesh.get_surface_count()):
		var material := crystal.mesh.surface_get_material(surface) as StandardMaterial3D
		if material and material.resource_name == "core_crystal_facets":
			# 원본 면색·노멀·PBR 데이터를 보존하고 모든 타일이 한 재질을 공유.
			var crystal_material := material.duplicate() as StandardMaterial3D
			crystal_material.refraction_enabled = false
			crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			crystal.set_surface_override_material(surface, crystal_material)
			has_crystal_shell = true
	if not has_crystal_shell:
		_fail("공용 코어 GLB의 결정 외피 재질을 찾지 못했습니다.")
		return
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dressing_library = Dressing.instantiate()
	# 기존 표시 레이어 유지. 모든 PBR 소재는 공용 환경 반사를 수신.
	for library: Node3D in [_terrain_library, _landmark_library]:
		for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	crystal.layers = REFLECTION_CRYSTAL_LAYER
	# 전장 전체의 바람에 하나의 재질·GPU 시계 공유.
	_foliage_material = ShaderMaterial.new()
	_foliage_material.shader = FoliageWind
	if not _prepare_dressing(_dressing_library):
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/terrain_manifest.json"))
	if not (manifest is Dictionary):
		_fail("지형 원본의 맵 정보를 읽지 못했습니다.")
		return
	_terrain_manifest = manifest
	var dressing_manifests = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dressing_manifests.json"))
	if not dressing_manifests is Array:
		_fail("스테이지 환경 원본의 맵 정보를 읽지 못했습니다.")
		return
	_dressing_variants = dressing_manifests
	get_viewport().size_changed.connect(_update_camera)
	# Tween은 _process 뒤에 진행되므로 실제 렌더 직전의 카메라로 투영을 보고.
	RenderingServer.frame_pre_draw.connect(_report_presentation)
	_update_camera()
	if bridge:
		bridge.report_ready()
	else:
		# 네이티브 데스크톱 검수 입력. Android에서는 실제 Flutter 전투만 사용.
		var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://assets/preview_frame.json"))
		if fixture is Dictionary:
			_apply_frame(fixture)
		print("RuneNexus Godot scene ready; Space: impacts, C: camera, S: shadows, V: volume")


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_report_presentation):
		RenderingServer.frame_pre_draw.disconnect(_report_presentation)
	if is_instance_valid(_terrain_library):
		_terrain_library.free()
	if is_instance_valid(_chapter_three_props_library):
		_chapter_three_props_library.free()
	if is_instance_valid(_chapter_three_terrain_library):
		_chapter_three_terrain_library.free()
	if is_instance_valid(_chapter_two_terrain_library):
		_chapter_two_terrain_library.free()
	if is_instance_valid(_chapter_two_paving_library):
		_chapter_two_paving_library.free()
	if is_instance_valid(_chapter_two_props_library):
		_chapter_two_props_library.free()
	if is_instance_valid(_environment_geology_library):
		_environment_geology_library.free()
	if is_instance_valid(_environment_props_library):
		_environment_props_library.free()
	if is_instance_valid(_landmark_library):
		_landmark_library.free()
	if is_instance_valid(_dressing_library):
		_dressing_library.free()
	for variant: Dictionary in _dressing_variants:
		if is_instance_valid(variant.get("library")):
			variant["library"].free()


func _fail(message: String) -> void:
	push_error(message)
	if bridge:
		bridge.report_error(message)


func _process(delta: float) -> void:
	if _profile_enabled:
		var tick := Time.get_ticks_usec()
		if _profile_last_tick != 0:
			_profile_intervals.append(float(tick - _profile_last_tick) / 1000.0)
		_profile_last_tick = tick
	if bridge:
		var pending_frame: Dictionary = {}
		var combat_changed := false
		var option_text: String = bridge.take_options()
		if not option_text.is_empty():
			var incoming = JSON.parse_string(option_text)
			if incoming is Dictionary:
				options.merge(incoming, true)
				_apply_options()
		var frame_text: String = bridge.take_frame()
		if not frame_text.is_empty():
			var parse_start := Time.get_ticks_usec() if _profile_enabled else 0
			var incoming = JSON.parse_string(frame_text)
			if _profile_enabled:
				_profile_parse_us += Time.get_ticks_usec() - parse_start
				_profile_parse_count += 1
			if incoming is Dictionary:
				if bool(incoming.get("reset", false)) or int(incoming.get("sceneEpoch", -1)) > _scene_epoch:
					_apply_frame(incoming)
				else:
					pending_frame = incoming
				if not bool(incoming.get("reset", false)) and int(incoming.get("sceneEpoch", -1)) == _scene_epoch:
					_native_combat_base_frame = incoming.duplicate(true)
		# Android Java singleton methods are dynamically exposed.
		var combat_text: String = bridge.take_combat()
		if not combat_text.is_empty():
			var command = JSON.parse_string(combat_text)
			if command is Dictionary and int(command.get("epoch", -1)) == _scene_epoch:
				var response: Dictionary = _native_combat.process_command(command)
				bridge.report_combat(JSON.stringify(response, "", false, true))
				combat_changed = _native_combat.active
		# One presentation update consumes the latest combat and UI state together.
		if not pending_frame.is_empty():
			_apply_frame(pending_frame)
		elif combat_changed and not _native_combat_base_frame.is_empty():
			_apply_frame(_native_combat_base_frame.duplicate(true))
	elif standalone_playing and not last_frame.is_empty():
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
	metrics_elapsed += delta
	frame_count += 1
	frame_time_total += delta
	frame_time_max = maxf(frame_time_max, delta)
	if metrics_elapsed >= 1.0:
		var viewport := get_viewport().get_visible_rect().size
		var metrics := {
			"fps": frame_count / frame_time_total,
			"frame_ms": frame_time_total * 1000.0 / frame_count,
			"max_frame_ms": frame_time_max * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"received_frames": received_frames, "sequence": last_sequence,
			"viewport": [viewport.x, viewport.y], "authored_terrain": _using_authored,
			"renderer": RenderingServer.get_current_rendering_method(),
			"combat_active": _native_combat.active,
			"combat_sequence": _native_combat.sequence,
			"combat_elapsed": _native_combat.elapsed,
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
		if bridge:
			bridge.report_metrics(JSON.stringify(metrics))
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
	# 최근 완료된 루트 viewport 렌더만 측정. Script/Flutter/별도 mask viewport는 제외.
	var rid := get_viewport().get_viewport_rid()
	_profile_render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_profile_render_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_profile_render_count += 1


func _set_profile_enabled(enabled: bool) -> void:
	if enabled == _profile_enabled:
		return
	_profile_enabled = enabled
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), enabled)
	if enabled:
		RenderingServer.frame_post_draw.connect(_profile_render_frame)
	else:
		RenderingServer.frame_post_draw.disconnect(_profile_render_frame)
	_profile_last_tick = 0
	_reset_profile_window()


func _apply_options() -> void:
	_presentation_nodes["effects"].diagnostic_skip = str(options.get("diagnostic_skip_canvas", ""))
	RunicFire.set_diagnostic_mode(str(options.get("runic_fire_mode", "all")))
	world.visible = not bool(options["empty"])
	_apply_graphics_options()
	_update_camera()
	if not last_frame.is_empty():
		_update_impacts(last_frame.get("impacts", []))


func _apply_stage_lighting() -> void:
	_world_environment.sky = ForgeReflectionSky if _using_forge else ReflectionSky
	_world_environment.background_color = Color("203139") if _using_forge else Color("101b20")
	if _using_forge:
		sun.light_energy = 1.35
		sun.light_color = Color(1.0, 0.94, 0.86)
		sun.shadow_blur = 0.85
		_world_environment.ambient_light_energy = 0.10
		_fill_light.light_energy = 0.08
		return
	# 연속 절벽 전장의 기본광을 낮추고 광물 주변의 실제 입사광을 대비시킨다.
	# 다른 맵으로 이동할 때 공용 조명을 정확히 복원한다.
	sun.light_energy = 1.20 if _using_chapter_environment else 1.50
	sun.light_color = Color(0.92, 0.95, 1.0) if _using_chapter_environment else Color(1.0, 0.94, 0.84)
	sun.shadow_blur = 0.85 if _using_chapter_environment else 1.25
	_world_environment.ambient_light_energy = 0.115 if _using_chapter_environment else 0.16
	_fill_light.light_energy = 0.08 if _using_chapter_environment else 0.14


func _add_environment_accent_lights() -> void:
	var accents := Node3D.new()
	accents.name = "stage%d_mineral_lights" % _environment_stage
	terrain.add_child(accents)
	# 원본의 보라색 몸체·청록 끝은 유지하며 주변 암반에도 빛이 닿게 한다.
	var sources := [
		[Vector3(-4.35, 0.63, -4.23), Color(0.24, 0.74, 1.0), 0.45, 1.25],
		[Vector3(-1.65, 0.43, 3.50), Color(0.22, 0.65, 1.0), 0.85, 1.60],
		[Vector3(3.45, 0.43, 2.35), Color(0.22, 0.65, 1.0), 0.85, 1.60],
		[Vector3(3.40, -0.02, -2.48), Color(0.55, 0.20, 1.0), 0.65, 1.35],
	]
	# 6의 기존 화면은 메타데이터가 없을 때 위 좌표를 그대로 보존한다.
	if _environment_manifest.has("accentLights") or _environment_stage != 6:
		sources = []
		for record: Dictionary in _environment_manifest.get("accentLights", []):
			var point: Array = record["positionGodot"]
			var color: Array = record["color"]
			sources.append([Vector3(float(point[0]), float(point[1]), float(point[2])),
				Color(float(color[0]), float(color[1]), float(color[2])),
				float(record.get("energy", 0.85)), float(record.get("range", 1.6))])
	for source: Array in sources:
		var light := OmniLight3D.new()
		light.position = source[0]
		light.light_color = source[1]
		light.light_energy = source[2]
		light.omni_range = source[3]
		light.light_cull_mask = REFLECTION_TERRAIN_LAYER
		light.shadow_enabled = false
		accents.add_child(light)


func _apply_graphics_options() -> void:
	_set_profile_enabled(bool(options.get("profile", false)))
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
	_update_camera_envelope()
	var requested_mode: String = options["camera"]
	if requested_mode != "drone":
		requested_mode = "angled"
	if requested_mode != camera_mode:
		var drone := requested_mode == "drone"
		var angled_position := Vector3(5, 20, 13) if _using_forge else Vector3(5, 27, 13)
		var target_position := Vector3(0, 30, 0.001) if drone else angled_position
		var target_basis := Basis.looking_at(-target_position, Vector3.FORWARD if drone else Vector3.UP)
		if camera_mode.is_empty():
			camera.transform = Transform3D(target_basis, target_position)
		else:
			if camera_transition:
				camera_transition.kill()
			# 재입력 시 현재 궤도에서 이어지는 0.7초 cubic 감속.
			var start_rotation := camera.quaternion
			var target_rotation := target_basis.get_rotation_quaternion()
			var start_distance := camera.position.length()
			var target_distance := target_position.length()
			camera_transition = create_tween().set_ignore_time_scale(true)
			camera_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			camera_transition.tween_method(func(weight: float) -> void:
				var pose := Basis(start_rotation.slerp(target_rotation, weight))
				camera.transform = Transform3D(pose, pose.z * lerpf(start_distance, target_distance, weight))
				_fit_camera_to_frame()
				_update_camera_visuals()
			, 0.0, 1.0, CAMERA_TRANSITION_SECONDS)
		camera_mode = requested_mode
	_fit_camera_to_frame()
	_update_camera_visuals()


func _fit_camera_to_frame() -> void:
	_fit_camera_depth()
	var visible_size := get_viewport().get_visible_rect().size
	# 깊이는 움직이는 actor/impact를 따라 매번 갱신하고 평면 fit만 캐시한다.
	# global_transform은 tween 자세·거리도 포함. world shake는 평면 fit 입력이 아니다.
	var key: Array = [
		_camera_layout_revision, camera.global_transform, visible_size,
		last_frame.get("viewport", []), last_frame.get("screenCenter", []),
		last_frame.has("pixelsPerTile"), last_frame.get("pixelsPerTile", 0.0),
		last_frame.get("zoom", 1.0), options.get("zoom", 1.0), columns, rows,
	]
	if key == _camera_layout_key:
		return
	_camera_layout_key = key
	_fit_camera_layout(visible_size)


func _fit_camera_layout(visible_size: Vector2) -> void:
	var logical_viewport: Array = last_frame.get("viewport", [])
	var screen_center: Array = last_frame.get("screenCenter", [])
	if logical_viewport.size() != 2 or screen_center.size() != 2 or not last_frame.has("pixelsPerTile"):
		# HUD 없는 검수 화면은 기울어진 지형의 투영 폭·높이까지 포함.
		var aspect := visible_size.x / maxf(1.0, visible_size.y)
		if _using_chapter_environment:
			var rectangle := _environment_camera_rect()
			camera.size = maxf(rectangle.size.y + 0.16, (rectangle.size.x + 0.16) / aspect) / maxf(0.01, float(options["zoom"]))
			camera.h_offset = rectangle.get_center().x
			camera.v_offset = rectangle.get_center().y
			return
		var basis := camera.global_basis
		var width := absf(basis.x.x) * columns + absf(basis.x.z) * rows
		var height := absf(basis.y.x) * columns + absf(basis.y.z) * rows
		camera.size = maxf(height + 1.2, (width + 1.2) / aspect) / maxf(0.01, float(options["zoom"]))
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	var viewport := Vector2(maxf(1.0, float(logical_viewport[0])), maxf(1.0, float(logical_viewport[1])))
	var inverse := camera.global_transform.affine_inverse()
	var bounds_min := Vector2(INF, INF)
	var bounds_max := Vector2(-INF, -INF)
	var min_column := columns
	var max_column := 0
	var min_row := rows
	var max_row := 0
	var tiles: Array = _current_map.get("tiles", [])
	for index in range(tiles.size()):
		if tiles[index] == "blocked":
			continue
		var x := index % columns
		var z := floori(float(index) / float(columns))
		min_column = mini(min_column, x)
		max_column = maxi(max_column, x + 1)
		min_row = mini(min_row, z)
		max_row = maxi(max_row, z + 1)
		for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
			var point: Vector3 = inverse * Vector3(float(x) + corner.x - columns / 2.0, 0.0, float(z) + corner.y - rows / 2.0)
			bounds_min = bounds_min.min(Vector2(point.x, point.y))
			bounds_max = bounds_max.max(Vector2(point.x, point.y))
	if _using_chapter_environment:
		# 절벽의 깊이·외곽과 배치 장식까지 같은 HUD 전장 영역 안에 수용한다.
		var rectangle := _environment_camera_rect().grow(0.08)
		bounds_min = bounds_min.min(rectangle.position)
		bounds_max = bounds_max.max(rectangle.end)
	if not bounds_min.is_finite():
		bounds_min = Vector2(-0.5, -0.5)
		bounds_max = Vector2(0.5, 0.5)
		min_column = 0
		max_column = 1
		min_row = 0
		max_row = 1
	var span := bounds_max - bounds_min
	var fit := clampf(minf(float(max_column - min_column) / maxf(span.x, 0.001), float(max_row - min_row) / maxf(span.y, 0.001)), 0.1, 1.0)
	var ppu := maxf(1.0, float(last_frame["pixelsPerTile"]) * float(last_frame.get("zoom", 1.0)) * fit)
	var center := (bounds_min + bounds_max) / 2.0
	var target_center := Vector2(float(screen_center[0]), float(screen_center[1]))
	if _using_forge:
		# Flutter는 전체 격자 중심을 전달하므로 비대칭 빈 테두리의 오프셋을 되돌린다.
		# 투영 경계는 이미 활성 타일 중심이며, 사용자 팬·줌은 그대로 유지한다.
		var grid_offset := Vector2(min_column + max_column - columns, min_row + max_row - rows) * 0.5
		target_center += grid_offset * float(last_frame["pixelsPerTile"]) * float(last_frame.get("zoom", 1.0))
	camera.size = viewport.y / ppu
	# 비대칭 직교 투영을 카메라 수평·수직 오프셋으로 표현.
	camera.h_offset = center.x + (viewport.x / 2.0 - target_center.x) / ppu
	camera.v_offset = center.y + (target_center.y - viewport.y / 2.0) / ppu


func _environment_camera_rect() -> Rect2:
	var inverse := camera.global_transform.affine_inverse()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	# 원본에서 준비한 실제 지형·소품의 지지점만 투영한다. 전체 AABB의 빈 모서리는 제외.
	var points: Array = _environment_manifest.get("cameraPointsGodot", [])
	if not points.is_empty():
		for coordinate: Array in points:
			var point: Vector3 = inverse * Vector3(float(coordinate[0]), float(coordinate[1]), float(coordinate[2]))
			low = low.min(Vector2(point.x, point.y))
			high = high.max(Vector2(point.x, point.y))
		return Rect2(low, high - low)
	for index in range(8):
		var point: Vector3 = inverse * _environment_bounds.get_endpoint(index)
		low = low.min(Vector2(point.x, point.y))
		high = high.max(Vector2(point.x, point.y))
	return Rect2(low, high - low)


func _camera_mesh_bounds(node: Node3D, parent_pose := Transform3D.IDENTITY) -> AABB:
	# 맵 생성·모델 캐시 준비 때만 순회. 매 프레임 메시를 조사하지 않는다.
	var pose: Transform3D = parent_pose * node.transform
	var bounds := AABB(pose.origin, Vector3.ZERO)
	if node is MeshInstance3D:
		bounds = pose * node.get_aabb()
	elif node is MultiMeshInstance3D and node.multimesh != null:
		bounds = pose * node.multimesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			bounds = bounds.merge(_camera_mesh_bounds(child, pose))
	return bounds


func _update_camera_envelope() -> void:
	if terrain.get_child_count() == 0:
		return
	if _camera_actor_bounds.size == Vector3.ZERO:
		var models := AABB()
		for library: Dictionary in [TURRET_MODELS, ENEMY_MODELS]:
			for packed: PackedScene in library.values():
				var model: Node3D = packed.instantiate()
				models = models.merge(_camera_mesh_bounds(model))
				model.free()
		# 공통 서리 결정의 최대 부착 길이도 포함한다.
		models = models.grow(0.2)
		# 적·포탑이 모든 방향으로 회전해도 담는 수평 반경.
		var radius := 0.0
		for index in range(8):
			var corner := models.get_endpoint(index)
			radius = maxf(radius, Vector2(corner.x, corner.z).length())
		_camera_actor_bounds = AABB(Vector3(-radius, models.position.y, -radius),
			Vector3(radius * 2.0, models.size.y, radius * 2.0))
	var terrain_id := terrain.get_child(0).get_instance_id()
	if terrain_id != _camera_terrain_id:
		_camera_terrain_id = terrain_id
		_camera_enemy_scale = 1.0
		_camera_impact_radius = 0.0
		_camera_map_bounds = AABB(Vector3(-columns / 2.0, 0.0, -rows / 2.0), Vector3(columns, 0.0, rows))
		_camera_map_bounds = _camera_map_bounds.merge(_camera_mesh_bounds(terrain).grow(0.05))
	# 브리지의 실제 크기를 수용하고 효과가 끝나도 맵 수명 동안 범위를 유지한다.
	# 발사·소멸마다 shadow map 범위가 왕복하는 것을 피한다.
	for data: Array in last_frame.get("enemies", []):
		_camera_enemy_scale = maxf(_camera_enemy_scale, absf(float(data[5])))
	for data: Array in last_frame.get("impacts", []):
		_camera_impact_radius = maxf(_camera_impact_radius, float(data[3]))
	for key in ["turrets", "enemies", "projectiles", "impacts"]:
		for data: Array in last_frame.get(key, []):
			_camera_map_bounds = _camera_map_bounds.expand(Vector3(float(data[1]) - columns / 2.0, 0.0, float(data[2]) - rows / 2.0))
			if key == "projectiles" and data.size() >= 12:
				_camera_map_bounds = _camera_map_bounds.expand(Vector3(float(data[6]) - columns / 2.0, 0.0, float(data[7]) - rows / 2.0))
				if data.size() >= 14 and data[12] != null and data[13] != null:
					_camera_map_bounds = _camera_map_bounds.expand(Vector3(float(data[12]) - columns / 2.0, 0.0, float(data[13]) - rows / 2.0))
	# 포구 연기는 총구에서 최대 0.37 전진 + 반길이 0.35, 위로 0.17 + 반폭 0.22.
	# 1타일 여유는 포구 화염·반동·건설 미리보기의 0.12 부유도 포함한다.
	var actor := AABB(_camera_actor_bounds.position * _camera_enemy_scale, _camera_actor_bounds.size * _camera_enemy_scale).grow(1.0)
	# 1.35타일 예광과 포탄 코끝을 포함. 폭발은 godot_impact.gd의 전체 입자 AABB.
	var horizontal := maxf(1.35, maxf(actor.end.x, 5.0 * _camera_impact_radius))
	var low := minf(_camera_map_bounds.position.y, minf(actor.position.y, -0.25 * _camera_impact_radius))
	var high := maxf(_camera_map_bounds.end.y, maxf(actor.end.y, 3.75 * _camera_impact_radius))
	_camera_envelope = AABB(Vector3(_camera_map_bounds.position.x - horizontal, low, _camera_map_bounds.position.z - horizontal),
		Vector3(_camera_map_bounds.size.x + 2.0 * horizontal, high - low, _camera_map_bounds.size.z + 2.0 * horizontal))


func _fit_camera_depth() -> void:
	if _camera_envelope.size == Vector3.ZERO:
		return
	# 직교 카메라는 sun.max_distance를 사용하지 않으므로 실제 수신 깊이를 제한.
	# h/v_offset는 시선에 수직인 이동이어서 깊이에 영향을 주지 않는다.
	var inverse := camera.global_transform.affine_inverse()
	var nearest := INF
	var farthest := -INF
	for index in range(8):
		var depth := -(inverse * _camera_envelope.get_endpoint(index)).z
		nearest = minf(nearest, depth)
		farthest = maxf(farthest, depth)
	camera.near = maxf(0.05, nearest - CAMERA_DEPTH_MARGIN)
	camera.far = maxf(camera.near + 1.0, farthest + CAMERA_DEPTH_MARGIN)


func _update_camera_visuals() -> void:
	_apply_world_shake()
	for effect: Node3D in impacts.values():
		if effect.visible:
			effect.update_camera(camera)
	for entry: Dictionary in turrets.values():
		_update_weapon_camera(entry)
	for entry: Dictionary in projectiles.values():
		if entry["root"] is BallisticProjectile and entry["root"].visible:
			entry["root"].update_camera(camera)
	# 최초 frame과 tween의 deferred Canvas draw에 카메라 참조를 미리 준비한다.
	_prepare_overlay_context()


func _apply_world_shake() -> void:
	world.position = Vector3.ZERO
	var payload: Dictionary = last_frame.get("presentation", {})
	var requested: Array = options.get("presentation_groups", [])
	if not requested.has("effects") or not _presentation_nodes["effects"].supported_groups().has("effects"):
		return
	var effects: Dictionary = payload.get("effects", {})
	var shake: Array = effects.get("shake", [])
	var viewport: Array = last_frame.get("viewport", [])
	if shake.size() != 2 or viewport.size() != 2:
		return
	# 기존 Canvas의 logical pixel 이동을 현재 카메라의 화면 평면으로 옮긴다.
	var units_per_pixel := camera.size / maxf(float(viewport[1]), 1.0)
	var actual_size := get_viewport().get_visible_rect().size
	var units_per_x_pixel := camera.size * actual_size.x / maxf(actual_size.y, 1.0) / maxf(float(viewport[0]), 1.0)
	world.position = camera.global_basis.x * float(shake[0]) * units_per_x_pixel - camera.global_basis.y * float(shake[1]) * units_per_pixel


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
		node.visible = enabled
		if enabled:
			if group == "selection":
				node.set_turrets(turrets)
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
	# Android Java 싱글턴은 동적 호출이므로 Object.has_method 검사 생략.
	if bridge and (not last_frame.is_empty() or not _map_request.is_empty()):
		bridge.report_presentation(JSON.stringify(presentation()))


func _apply_frame(frame: Dictionary) -> void:
	if _native_combat.active and not bool(frame.get("reset", false)) and int(frame.get("sceneEpoch", -1)) == _scene_epoch:
		frame = _native_combat.decorate_frame(frame)
	if not _profile_enabled:
		_apply_frame_impl(frame)
		return
	var started := Time.get_ticks_usec()
	_apply_frame_impl(frame)
	_profile_apply_us += Time.get_ticks_usec() - started
	_profile_apply_count += 1


func _apply_frame_impl(frame: Dictionary) -> void:
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
			var group_frame: Dictionary = payload[group].duplicate(true)
			group_frame["viewport"] = frame.get("viewport", [])
			if group == "effects":
				group_frame["targets"] = frame.get("enemies", [])
				group_frame["turrets"] = frame.get("turrets", [])
			_presentation_nodes[group].apply_frame(group_frame)
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
	_update_camera()
	_sync_turrets(frame.get("turrets", []))
	_sync_enemies(frame.get("enemies", []))
	_sync_projectiles(last_frame.get("projectiles", []))
	_sync_build_preview(frame.get("buildPreview"))
	_update_impacts(last_frame.get("impacts", []))
	var time := float(frame.get("time", 0.0))
	_portal_material.set_shader_parameter("battle_time", time)
	_portal_material.set_shader_parameter("alert", clampf(float(frame.get("portalAlert", 0.0)), 0.0, 1.0))
	var core_hit := clampf(float(frame.get("nexusHit", 0.0)), 0.0, 1.0)
	for core in _cores:
		var crystal: Node3D = core["crystal"]
		# 석재 받침은 고정하고 결정만 원본 피벗에서 부유·회전.
		crystal.position = core["rest_position"] + Vector3(0.0, sin(time * 2.5) * 0.018, 0.0)
		crystal.basis = Basis(Vector3.UP, time * 0.22) * core["rest_basis"]
		crystal.scale *= 1.0 + core_hit * 0.025


func _clear_scene() -> void:
	_native_combat = NativeCombatRuntime.new()
	_native_combat_base_frame.clear()
	_projectile_events.clear()
	world.position = Vector3.ZERO
	_turret_level_labels.clear()
	for node: Node2D in _presentation_nodes.values():
		node.clear()
		node.hide()
	_applied_groups.clear()
	if camera_transition:
		camera_transition.kill()
	camera_mode = ""
	for collection: Dictionary in [turrets, enemies, projectiles]:
		for entry: Dictionary in collection.values():
			entry["root"].free()
		collection.clear()
	for pool: Array in _ballistic_pool.values() + _generic_projectile_pool.values():
		for projectile: Node3D in pool:
			projectile.free()
		pool.clear()
	for projectile: Node3D in _fire_projectile_pool:
		projectile.free()
	_fire_projectile_pool.clear()
	if not _build_preview.is_empty():
		_build_preview["root"].free()
		_build_preview.clear()
	for effect: Node3D in impacts.values():
		effect.free()
	impacts.clear()
	for effect in impact_pool:
		effect.free()
	impact_pool.clear()
	for child in terrain.get_children():
		child.free()
	for light in impact_lights:
		light.light_energy = 0.0
	_portals.clear()
	_cores.clear()
	_current_map = {}
	_map_revision = -1
	_map_request.clear()
	_camera_layout_revision += 1
	_camera_layout_key.clear()
	last_frame = {}
	last_sequence = -1
	received_frames = 0
	standalone_playing = false
	standalone_time = 0.0
	_using_authored = false
	_using_dressing = false
	_using_forge = false
	camera_mode = ""
	_release_chapter_environment()
	_apply_stage_lighting()
	_build_tile_slots.clear()
	if _occupied_build_tiles != Vector2i.ZERO:
		_occupied_build_tiles = Vector2i.ZERO
		_foliage_material.set_shader_parameter("occupied_build_tiles", _occupied_build_tiles)


func _build_terrain(map: Dictionary) -> bool:
	var next_columns := int(map.get("columns", 0))
	var next_rows := int(map.get("rows", 0))
	var tiles: Array = map.get("tiles", [])
	if next_columns <= 0 or next_rows <= 0 or tiles.size() != next_columns * next_rows:
		_fail("3D 전장의 맵 크기와 타일 수가 맞지 않습니다.")
		return false
	var theme := str(map.get("theme", "chapterOne"))
	if theme not in ["chapterOne", "chapterTwoRift", "chapterThreeForge"]:
		_fail("지원하지 않는 3D 전장 테마: " + theme)
		return false
	var chapter_three := theme == "chapterThreeForge"
	if chapter_three and (not _prepare_chapter_three() or not _prepare_chapter_three_props()):
		return false
	var chapter_two := theme == "chapterTwoRift"
	if chapter_two and not _prepare_chapter_two():
		return false
	if chapter_two and _environment_manifests.is_empty():
		var manifests = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter2_environment_manifests.json"))
		if not manifests is Array:
			_fail("챕터 2 절벽 원본의 맵 정보를 읽지 못했습니다.")
			return false
		_environment_manifests = manifests
	var matched_manifest: Dictionary = {}
	if chapter_two:
		for manifest: Dictionary in _environment_manifests:
			if int(manifest.get("columns", 0)) == next_columns and int(manifest.get("rows", 0)) == next_rows and manifest.get("tileTypes", []) == tiles:
				matched_manifest = manifest
				break
	var tile_library := _chapter_two_terrain_library if chapter_two else (_chapter_three_terrain_library if chapter_three else _terrain_library)
	var forge_variants := ChapterThreeTiles.variants(map) if chapter_three else {}
	columns = next_columns
	rows = next_rows
	for child in terrain.get_children():
		child.free()
	_portals.clear()
	_cores.clear()
	# 이전 맵의 인스턴스를 해제한 뒤 다음 원본을 읽어 대형 지형 캐시가 누적되지 않게 한다.
	if matched_manifest.is_empty():
		_release_chapter_environment()
	elif not _prepare_chapter_environment(matched_manifest):
		return false
	_using_chapter_environment = not matched_manifest.is_empty()
	if _using_forge != chapter_three:
		camera_mode = ""
	_using_forge = chapter_three
	_apply_stage_lighting()
	_environment_bounds = AABB()
	if _using_chapter_environment:
		terrain.add_child(_environment_geology_library.duplicate())
		terrain.add_child(_environment_props_library.duplicate())
		_add_environment_accent_lights()
		_environment_bounds = _camera_mesh_bounds(_environment_geology_library).merge(_camera_mesh_bounds(_environment_props_library))
	var authored := _terrain_library.find_child("stage1_environment", true, false)
	_using_authored = not chapter_two and not chapter_three and authored != null and int(_terrain_manifest.get("columns", 0)) == columns \
		and int(_terrain_manifest.get("rows", 0)) == rows and _terrain_manifest.get("tileTypes", []) == tiles
	_build_tile_slots.clear()
	if _using_authored:
		terrain.add_child(authored.duplicate())
		# 동일한 맵 원본에 배치된 환경 장식만 지형 수명에 연결.
		terrain.add_child(_dressing_library.duplicate())
	_using_dressing = _using_authored
	if not _using_authored and not chapter_two and not chapter_three:
		for variant: Dictionary in _dressing_variants:
			if int(variant.get("columns", 0)) != columns or int(variant.get("rows", 0)) != rows or variant.get("tileTypes", []) != tiles:
				continue
			# 첫 진입에만 해당 맵 장식을 준비하고 이후 맵 재방문은 자원을 공유.
			if not is_instance_valid(variant.get("library")):
				var packed := load(str(variant["resource"])) as PackedScene
				if packed == null:
					_fail("스테이지 환경 GLB를 불러오지 못했습니다.")
					return false
				var library := packed.instantiate() as Node3D
				if not _prepare_dressing(library):
					library.free()
					return false
				variant["library"] = library
			terrain.add_child(variant["library"].duplicate())
			_using_dressing = true
			break
	if _using_dressing:
		_build_tile_slots.resize(tiles.size())
		_build_tile_slots.fill(-1)
	if _using_chapter_environment and not _build_chapter_two_paving(tiles):
		return false
	var names := {"path": "path_tile", "build": "build_tile", "spawn": "portal", "core": "core"}
	var build_slot := 0
	for index in range(tiles.size()):
		var tile: String = tiles[index]
		if _using_dressing and tile == "build":
			# Blender UV2와 같은 맵 순회의 건설칸 슬롯.
			_build_tile_slots[index] = build_slot
			build_slot += 1
		if tile == "blocked" or (_using_authored and tile != "spawn" and tile != "core"):
			continue
		if not names.has(tile):
			_fail("지원하지 않는 맵 타일: %s" % tile)
			return false
		if _using_chapter_environment and tile in ["path", "build"]:
			continue
		var point := Vector3(float(index % columns) + 0.5 - columns / 2.0, 0.0, floor(float(index) / float(columns)) + 0.5 - rows / 2.0)
		if not _using_authored and not _using_chapter_environment and (tile == "spawn" or tile == "core"):
			var foundation: Node3D = tile_library.find_child("path_tile", true, false).duplicate()
			foundation.position = point
			if chapter_two:
				foundation.rotation.y = float(index % 4) * PI / 2.0
			terrain.add_child(foundation)
		var library := _landmark_library if tile == "spawn" or tile == "core" else tile_library
		var model_name: String = forge_variants.get(index, names[tile])
		var model := library.find_child(model_name, true, false)
		if not model:
			_fail("지형 GLB 노드를 찾지 못했습니다: %s" % names[tile])
			return false
		var instance: Node3D = model.duplicate()
		instance.position = point
		if chapter_two:
			if tile in ["path", "build"]:
				# 원본의 형상·재질을 보존하며 정사각 타일의 반복 방향만 분산.
				instance.rotation.y = float(index % 4) * PI / 2.0
			instance.set_meta("tile_type", tile)
			instance.set_meta("grid_cell", Vector2i(index % columns, floori(float(index) / columns)))
		if chapter_three:
			instance.set_meta("tile_type", tile)
			instance.set_meta("tile_variant", model_name)
			instance.set_meta("grid_cell", Vector2i(index % columns, floori(float(index) / columns)))
		terrain.add_child(instance)
		if tile == "spawn":
			_portals.append(instance)
		elif tile == "core":
			var crystal := instance.find_child("core_crystal", true, false) as Node3D
			_cores.append({"root": instance, "crystal": crystal, "rest_position": crystal.position, "rest_basis": crystal.basis})
	if chapter_three and not ChapterThreeTiles.populate_panels(terrain, _chapter_three_terrain_library, map):
		_fail("챕터 3 교체형 패널 메시를 확인하지 못했습니다.")
		return false
	if chapter_three and not ChapterThreeProps.populate(terrain, _chapter_three_props_library, map):
		_fail("챕터 3 외곽 소품의 안전한 배치를 확인하지 못했습니다.")
		return false
	if chapter_two and not _using_chapter_environment and not ChapterTwoEnvironment.populate(terrain, _chapter_two_props_library, map):
		_fail("챕터 2 환경 소품의 배치 계약을 확인하지 못했습니다.")
		return false
	# JSON 숫자형까지 보존해 같은 맵을 매 프레임 재생성하지 않음.
	_current_map = map.duplicate(true)
	_camera_layout_revision += 1
	return true


func _prepare_chapter_three_props() -> bool:
	if is_instance_valid(_chapter_three_props_library):
		return true
	var packed := load("res://assets/environment/chapter3_props.glb") as PackedScene
	if packed == null:
		_fail("챕터 3 환경 소품 GLB를 불러오지 못했습니다.")
		return false
	_chapter_three_props_library = packed.instantiate()
	for kind in ChapterThreeProps.KINDS:
		if _chapter_three_props_library.find_child(kind, true, false) == null:
			_fail("챕터 3 환경 GLB 노드 누락: " + kind)
			_chapter_three_props_library.free()
			_chapter_three_props_library = null
			return false
	_prepare_vertex_colors(_chapter_three_props_library)
	for mesh: MeshInstance3D in _chapter_three_props_library.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	return true


func _prepare_chapter_three() -> bool:
	if is_instance_valid(_chapter_three_terrain_library):
		return true
	var packed := load("res://assets/environment/chapter3_tiles.glb") as PackedScene
	if packed == null:
		_fail("챕터 3 타일 GLB를 불러오지 못했습니다.")
		return false
	_chapter_three_terrain_library = packed.instantiate()
	for kind in ["path_tile", "grate_tile", "build_tile", "plain_build_tile", "panel_solid", "panel_vent"]:
		if _chapter_three_terrain_library.find_child(kind, true, false) == null:
			_fail("챕터 3 타일 GLB 노드 누락: " + kind)
			_chapter_three_terrain_library.free()
			_chapter_three_terrain_library = null
			return false
	_prepare_vertex_colors(_chapter_three_terrain_library)
	# 승인 원본의 PBR·색·거칠기·형태를 유지한다. 1장 석재 보정은 적용하지 않는다.
	for mesh: MeshInstance3D in _chapter_three_terrain_library.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	return true


func _release_chapter_environment() -> void:
	if is_instance_valid(_environment_geology_library):
		_environment_geology_library.free()
	if is_instance_valid(_environment_props_library):
		_environment_props_library.free()
	_environment_geology_library = null
	_environment_props_library = null
	_environment_stage = 0
	_environment_manifest = {}
	_using_chapter_environment = false
	_environment_bounds = AABB()


func _prepare_chapter_environment(manifest: Dictionary) -> bool:
	var stage := int(manifest["stage"])
	if _environment_stage == stage and is_instance_valid(_environment_geology_library) and is_instance_valid(_environment_props_library):
		return true
	_release_chapter_environment()
	var geology := load("res://assets/environment/chapter2_stage%d_geology.glb" % stage) as PackedScene
	var props := load("res://assets/environment/chapter2_stage%d_props.glb" % stage) as PackedScene
	if geology == null or props == null:
		_fail("스테이지 %d 절벽·환경 GLB를 불러오지 못했습니다." % stage)
		return false
	_environment_geology_library = geology.instantiate()
	_environment_props_library = props.instantiate()
	var geology_name := "stage%d_geology" % stage
	var props_name := "stage%d_props" % stage
	var has_geology_root := _environment_geology_library.name == geology_name or _environment_geology_library.find_child(geology_name, true, false) != null
	var has_props_root := _environment_props_library.name == props_name or _environment_props_library.find_child(props_name, true, false) != null
	if not has_geology_root or not has_props_root:
		_fail("스테이지 %d 절벽·환경 GLB의 루트 계약이 맞지 않습니다." % stage)
		_release_chapter_environment()
		return false
	_environment_stage = stage
	_environment_manifest = manifest
	for library in [_environment_geology_library, _environment_props_library]:
		_prepare_vertex_colors(library)
		_prepare_terrain_surfaces(library)
		for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material:
					material.refraction_enabled = false
	return true


func _prepare_chapter_two() -> bool:
	if is_instance_valid(_chapter_two_terrain_library) and is_instance_valid(_chapter_two_props_library):
		return true
	var tiles := load("res://assets/environment/chapter2_tiles.glb") as PackedScene
	var props := load("res://assets/environment/chapter2_props.glb") as PackedScene
	if tiles == null or props == null:
		_fail("챕터 2 지형·환경 GLB를 불러오지 못했습니다.")
		return false
	_chapter_two_terrain_library = tiles.instantiate()
	_chapter_two_props_library = props.instantiate()
	for kind in ["path_tile", "build_tile"]:
		if _chapter_two_terrain_library.find_child(kind, true, false) == null:
			_fail("챕터 2 지형 GLB 노드 누락: " + kind)
			_chapter_two_terrain_library.free()
			_chapter_two_props_library.free()
			_chapter_two_terrain_library = null
			_chapter_two_props_library = null
			return false
	for library in [_chapter_two_terrain_library, _chapter_two_props_library]:
		_prepare_vertex_colors(library)
		_prepare_terrain_surfaces(library)
		for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material:
					# 원본 알파·투과 의도와 PBR는 보존. 공용 내장 굴절 비사용 정책만 적용.
					material.refraction_enabled = false
	return true


func _prepare_chapter_two_paving() -> bool:
	if is_instance_valid(_chapter_two_paving_library):
		return true
	var packed := load("res://assets/environment/chapter2_tiles_optimized.glb") as PackedScene
	if packed == null:
		_fail("챕터 2 병합 타일 GLB를 불러오지 못했습니다.")
		return false
	_chapter_two_paving_library = packed.instantiate()
	_prepare_vertex_colors(_chapter_two_paving_library)
	_prepare_terrain_surfaces(_chapter_two_paving_library)
	# 두 GLB의 동일 이름 PBR 재질과 9개 이미지 SHA-256을 오프라인 검증했다.
	# 근거: docs/analysis/godot_optimization_20260913/texture_identity.json
	# 이미 준비한 texture를 slot별 공유한다. 로딩 중 GPU readback/이미지 비교는 하지 않는다.
	var shared_materials := {}
	for source: MeshInstance3D in _chapter_two_terrain_library.find_children("*", "MeshInstance3D", true, false):
		for surface in range(source.mesh.get_surface_count()):
			var material := source.get_active_material(surface) as StandardMaterial3D
			if material and material.resource_name in ["chapter2_build", "chapter2_path", "chapter2_side"]:
				shared_materials[material.resource_name] = material
	var prepared_materials := {}
	for source: MeshInstance3D in _chapter_two_paving_library.find_children("*", "MeshInstance3D", true, false):
		for surface in range(source.mesh.get_surface_count()):
			var material := source.get_active_material(surface) as StandardMaterial3D
			if material:
				if not prepared_materials.has(material.get_instance_id()) and shared_materials.has(material.resource_name):
					var shared: StandardMaterial3D = shared_materials[material.resource_name]
					for slot in range(BaseMaterial3D.TEXTURE_MAX):
						material.set_texture(slot, shared.get_texture(slot))
					prepared_materials[material.get_instance_id()] = true
				material.refraction_enabled = false
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				# MultiMesh는 MeshInstance의 surface override를 읽지 않으므로 공유 mesh에 연결.
				source.mesh.surface_set_material(surface, material)
	return true


func _chapter_two_paving_mask(index: int, tiles: Array) -> int:
	var cell := Vector2i(index % columns, floori(float(index) / columns))
	var inverse := Basis(Vector3.UP, float(index % 4) * PI / 2.0).inverse()
	var mask := 0
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := cell + offset
		if neighbor.x < 0 or neighbor.x >= columns or neighbor.y < 0 or neighbor.y >= rows:
			continue
		if tiles[neighbor.y * columns + neighbor.x] == "blocked":
			continue
		var local := inverse * Vector3(offset.x, 0, offset.y)
		if roundi(local.x) == -1: mask |= 1
		elif roundi(local.x) == 1: mask |= 2
		elif roundi(local.z) == -1: mask |= 4
		elif roundi(local.z) == 1: mask |= 8
	return mask


func _build_chapter_two_paving(tiles: Array) -> bool:
	if not _prepare_chapter_two_paving():
		return false
	var groups := {}
	for index in range(tiles.size()):
		var tile: String = tiles[index]
		if tile == "blocked":
			continue
		var kind := "build" if tile == "build" else "path"
		var mask := _chapter_two_paving_mask(index, tiles)
		var variant := "%s_tile_mask_%d" % [kind, mask]
		if not groups.has(variant):
			var root := _chapter_two_paving_library.find_child(variant, true, false) as Node3D
			if root == null or root.get_child_count() != 1 or not root.get_child(0) is MeshInstance3D:
				_fail("챕터 2 병합 타일 노드 누락: " + variant)
				return false
			var source := root.get_child(0) as MeshInstance3D
			if root.transform != Transform3D.IDENTITY or source.transform != Transform3D.IDENTITY:
				_fail("챕터 2 병합 타일 원점 계약 오류: " + variant)
				return false
			groups[variant] = {"mesh": source.mesh, "indices": [], "poses": [], "kind": kind, "mask": mask}
		var point := Vector3(float(index % columns) + 0.5 - columns / 2.0, 0.0, floori(float(index) / columns) + 0.5 - rows / 2.0)
		groups[variant]["indices"].append(index)
		groups[variant]["poses"].append(Transform3D(Basis(Vector3.UP, float(index % 4) * PI / 2.0), point))
	for variant: String in groups:
		var group: Dictionary = groups[variant]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group["mesh"]
		multimesh.instance_count = group["poses"].size()
		for slot in range(multimesh.instance_count):
			multimesh.set_instance_transform(slot, group["poses"][slot])
		var batch := MultiMeshInstance3D.new()
		batch.name = variant + "_batch"
		batch.multimesh = multimesh
		batch.layers = 1 | REFLECTION_TERRAIN_LAYER
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		batch.set_meta("tile_type", group["kind"])
		batch.set_meta("tile_indices", group["indices"])
		batch.set_meta("neighbor_mask", group["mask"])
		terrain.add_child(batch)
	return true


func _prepare_terrain_surfaces(model: Node) -> void:
	# 원본 atlas의 색·노멀 유지. 틈의 AO와 비스듬한 시점의 필터만 설정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if material.resource_name.begins_with("stage1_authored_"):
				material.ao_light_affect = 0.8
				material.normal_scale = 1.2 if material.resource_name.ends_with("build") else 1.0


func _prepare_dressing(library: Node3D) -> bool:
	_prepare_vertex_colors(library)
	var foliage := library.find_child("stage1_dressing_foliage", true, false) as MeshInstance3D
	var rocks := library.find_child("stage1_dressing_rocks", true, false) as MeshInstance3D
	if foliage == null or rocks == null:
		_fail("환경 GLB의 풀·바위 메시를 찾지 못했습니다.")
		return false
	for mesh: MeshInstance3D in library.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1 | REFLECTION_TERRAIN_LAYER
	foliage.material_override = _foliage_material
	foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	foliage.extra_cull_margin = 0.03
	return true


func _prepare_vertex_colors(model: Node) -> void:
	# GLB COLOR_0 보존: 일부 다중 primitive 재질의 누락된 사용 플래그 보정.
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material := mesh.get_active_material(surface)
			if colors != null and not colors.is_empty() and material is StandardMaterial3D:
				material.vertex_color_use_as_albedo = true


func _new_turret(type: String) -> Dictionary:
	var root: Node3D = TURRET_MODELS[type].instantiate()
	_prepare_vertex_colors(root)
	world.add_child(root)
	var barrel: Node3D = root.find_child("turret_barrel", true, false)
	var muzzle: Node3D = root.find_child("muzzle", true, false)
	var entry := {
		"root": root, "type": type, "head": root.find_child("turret_head", true, false),
		"barrel": barrel, "muzzle": muzzle, "barrel_rest_z": barrel.position.z,
		"flashes": [], "smokes": [], "smoke_starts": [-INF, -INF],
		"last_shot": -1, "last_time": -INF, "fire_start": -INF, "active_port": 0,
	}
	entry["level_bounds"] = TurretLevelLabels.base_bounds(root, entry["head"], root.transform.affine_inverse())
	if type == "magic":
		# 발광 홈은 금속 반사광으로 희게 날리지 않고 원본 주황색을 유지한다.
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material != null and material.resource_name.begins_with("Runes |"):
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var effect := RunicFire.new(false)
		root.add_child(effect)
		entry["fire_effect"] = effect
		entry["flame_port"] = root.find_child("upper_flame_port", true, false)
		return entry
	if type == "arrow":
		var effect := MachineGunMuzzle.new()
		root.add_child(effect)
		entry["muzzle_effect"] = effect
		return entry
	for index in range(2):
		var flash := WeaponAtlas.new()
		flash.configure(true)
		flash.position.x = (-0.062 if index == 0 else 0.062) if type == "arrow" else 0.0
		flash.position.z = 0.018
		muzzle.add_child(flash)
		entry["flashes"].append(flash)
		var smoke := WeaponAtlas.new()
		smoke.configure(false, Color("697586") if type == "arrow" else Color.WHITE)
		smoke.position.x = flash.position.x
		muzzle.add_child(smoke)
		entry["smokes"].append(smoke)
	return entry


func _sync_turrets(units: Array) -> void:
	var alive := {}
	var occupied := Vector2i.ZERO
	for data: Array in units:
		var id := int(data[0])
		# 구 검수 배열에만 cannon 기본값 사용. 명시된 다른 유형은 대체하지 않음.
		var type := str(data[6]) if data.size() > 6 else "cannon"
		if not TURRET_MODELS.has(type):
			_fail("스테이지 1에서 지원하지 않는 포탑: %s" % type)
			continue
		alive[id] = true
		if _using_dressing:
			var x := floori(float(data[1]))
			var z := floori(float(data[2]))
			if x >= 0 and x < columns and z >= 0 and z < rows:
				var slot := _build_tile_slots[z * columns + x]
				if slot >= 0 and slot < 16:
					occupied.x |= 1 << slot
				elif slot >= 16 and slot < 32:
					occupied.y |= 1 << (slot - 16)
		if turrets.has(id) and turrets[id]["type"] != type:
			turrets[id]["root"].free()
			turrets.erase(id)
		if not turrets.has(id):
			turrets[id] = _new_turret(type)
		var entry: Dictionary = turrets[id]
		entry["root"].visible = not (type == "magic" and options.get("runic_fire_mode", "all") == "no_model")
		entry["level"] = int(data[7]) if data.size() > 7 else 1
		entry["root"].position = Vector3(float(data[1]) - columns / 2.0, 0.0, float(data[2]) - rows / 2.0)
		entry["head"].rotation.y = PI / 2.0 - float(data[3])
		_update_fire(entry, int(data[4]), float(data[5]))
	for id in turrets.keys():
		if not alive.has(id):
			turrets[id]["root"].free()
			turrets.erase(id)
	# 확정 포탑의 점유가 바뀔 때만 전장 전체의 중앙 풀 가림을 갱신.
	if occupied != _occupied_build_tiles:
		_occupied_build_tiles = occupied
		_foliage_material.set_shader_parameter("occupied_build_tiles", occupied)


func _update_fire(entry: Dictionary, shot_sequence: int, feedback: float) -> void:
	var time := float(last_frame.get("time", 0.0))
	if time < float(entry["last_time"]):
		entry["fire_start"] = -INF
		entry["smoke_starts"] = [-INF, -INF]
		if entry.has("muzzle_effect"):
			entry["muzzle_effect"].reset()
		if entry.has("fire_effect"):
			entry["fire_effect"].reset()
			entry["last_shot"] = -1
			entry.erase("shot_pose")
	var previous := int(entry["last_shot"])
	var fired := (previous >= 0 and previous != shot_sequence) or (previous < 0 and shot_sequence > 0 and feedback > 0.0)
	if fired:
		entry["fire_start"] = time
		entry["active_port"] = posmod(shot_sequence, 2)
		entry["smoke_starts"][entry["active_port"]] = time
	entry["last_shot"] = shot_sequence
	entry["last_time"] = time
	var age := maxf(0.0, time - float(entry["fire_start"]))
	var heavy: bool = entry["type"] == "cannon"
	var machine_gun: bool = entry["type"] == "arrow"
	var duration := 0.11 if heavy else (0.12 if machine_gun else 0.085)
	var recovery := 0.34 if heavy else (0.075 if machine_gun else 0.14)
	var kick := age / 0.018 if age < 0.018 else pow(clampf(1.0 - (age - 0.018) / recovery, 0.0, 1.0), 2.0)
	entry["barrel"].position.z = float(entry["barrel_rest_z"]) - kick * (0.12 if heavy else (0.025 if machine_gun else 0.045))
	if fired and (heavy or machine_gun or entry["type"] == "magic"):
		var muzzle: Node3D = entry["muzzle"]
		var pose := muzzle.global_transform.orthonormalized()
		pose.origin = muzzle.to_global(Vector3((0.062 if int(entry["active_port"]) == 1 else -0.062) if machine_gun else 0.0, 0.0, 0.018))
		entry["shot_pose"] = pose
	if entry.has("fire_effect"):
		if fired:
			entry["fire_effect"].fire(entry["muzzle"], time, shot_sequence)
		entry["fire_effect"].update_turret(entry["flame_port"], entry["muzzle"], time)
		return
	if machine_gun:
		# 최신 조준·반동 위치에서 이번 한 발만 기록. 건너뛴 순번은 재연하지 않음.
		if fired:
			entry["muzzle_effect"].fire(entry["muzzle"], time, shot_sequence)
		entry["muzzle_effect"].update_effect(entry["muzzle"], time, camera)
		return
	for index in range(2):
		var flash: MeshInstance3D = entry["flashes"][index]
		flash.visible = index == int(entry["active_port"]) and age < duration
		if flash.visible:
			var progress := age / duration
			flash.set_frame(floori(progress * 8.0), (1.0 - progress * 0.65) * (0.95 if heavy else 0.8))
			var growth := 0.8 + sin(progress * PI) * 0.35
			flash.display_size = Vector2(0.60 if heavy else (0.90 if machine_gun else 0.26), 0.29 if heavy else (0.70 if machine_gun else 0.18)) * growth
		var smoke: MeshInstance3D = entry["smokes"][index]
		var smoke_age := time - float(entry["smoke_starts"][index])
		var smoke_duration := 0.60 if heavy else (0.65 if machine_gun else 0.36)
		smoke.visible = smoke_age >= 0.0 and smoke_age < smoke_duration
		if smoke.visible:
			var progress := smoke_age / smoke_duration
			var opacity := 0.85 * (1.0 - progress * 0.35) if machine_gun else (0.35 if heavy else 0.17) * (1.0 - progress)
			smoke.set_frame(floori(progress * 8.0), opacity)
			smoke.display_angle = 0.18 * sin(float(index) + progress)
			smoke.position.y = 0.02 + progress * (0.17 if heavy else 0.09)
			smoke.position.z = 0.06 + progress * (0.14 if heavy else 0.07)
			var size := (0.25 if heavy else (0.80 if machine_gun else 0.11)) * (1.0 + progress * 1.4)
			smoke.display_size = Vector2(size, size)
	_update_weapon_camera(entry)


func _update_weapon_camera(entry: Dictionary) -> void:
	if entry.has("fire_effect"):
		return
	if entry.has("muzzle_effect"):
		entry["muzzle_effect"].update_camera(camera)
		return
	var muzzle: Node3D = entry["muzzle"]
	var source := camera.unproject_position(muzzle.global_position)
	var target := camera.unproject_position(muzzle.to_global(Vector3.BACK))
	var direction := target - source
	for flash: MeshInstance3D in entry["flashes"]:
		flash.display_angle = atan2(-direction.y, direction.x)
		flash.update_camera(camera)
	for smoke: MeshInstance3D in entry["smokes"]:
		smoke.update_camera(camera)


func _sync_enemies(units: Array) -> void:
	var time := float(last_frame.get("time", 0.0))
	# 공통 GPU 입자 시계는 전투 프레임마다 한 번만 전달한다.
	EnemyBurn.set_time(time)
	var alive := {}
	for data: Array in units:
		var id := int(data[0])
		var type := str(data[7]) if data.size() > 7 else "tank"
		if not ENEMY_MODELS.has(type):
			_fail("스테이지 1에서 지원하지 않는 적: %s" % type)
			continue
		alive[id] = true
		if enemies.has(id) and enemies[id]["type"] != type:
			enemies[id]["root"].free()
			enemies.erase(id)
		if not enemies.has(id):
			var model: Node3D = ENEMY_MODELS[type].instantiate()
			_prepare_vertex_colors(model)
			world.add_child(model)
			enemies[id] = {"root": model, "type": type}
		var root: Node3D = enemies[id]["root"]
		# 전투 판정의 기존 slowed 필드를 사용하며 부유·회전·크기는 원본 부모를 따른다.
		EnemyFrost.apply(enemies[id], data.size() > 9 and bool(data[9]))
		# Diagnostic A/B switch: visual only; incoming combat burn state stays intact.
		EnemyBurn.apply(enemies[id], data.size() > 8 and bool(data[8]) and bool(options.get("burn_effects", true)), time)
		var hover := 0.025 if type in ["normal", "fast", "shielded"] else 0.008
		root.position = Vector3(float(data[1]) - columns / 2.0, sin(float(data[4])) * hover, float(data[2]) - rows / 2.0)
		root.rotation.y = PI / 2.0 - float(data[3])
		root.scale = Vector3.ONE * float(data[5])
	for id in enemies.keys():
		if not alive.has(id):
			enemies[id]["root"].free()
			enemies.erase(id)


func _sync_build_preview(data) -> void:
	var type := str(data[6]) if data is Array and data.size() > 6 else "cannon"
	if not _build_preview.is_empty() and (data == null or _build_preview["type"] != type):
		_build_preview["root"].free()
		_build_preview.clear()
	if not (data is Array) or data.size() < 6:
		return
	if not TURRET_MODELS.has(type):
		_fail("지원하지 않는 건설 미리보기 포탑: %s" % type)
		return
	if _build_preview.is_empty():
		_build_preview = _new_turret(type)
		for mesh: GeometryInstance3D in _build_preview["root"].find_children("*", "GeometryInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_preview["root"].position = Vector3(float(data[1]) - columns / 2.0, 0.10 + sin(float(last_frame.get("time", 0.0)) * 3.0) * 0.02, float(data[2]) - rows / 2.0)
	_build_preview["head"].rotation.y = PI / 2.0 - float(data[3])
	_build_preview["barrel"].position.z = _build_preview["barrel_rest_z"]
	if _build_preview.has("fire_effect"):
		_build_preview["fire_effect"].update_turret(_build_preview["flame_port"], _build_preview["muzzle"], float(last_frame.get("time", 0.0)))


func _new_projectile(type: String) -> Node3D:
	if _generic_projectile_pool.has(type) and not _generic_projectile_pool[type].is_empty():
		var reused: Node3D = _generic_projectile_pool[type].pop_back()
		reused.visible = true
		return reused
	if type == "magic":
		if not _fire_projectile_pool.is_empty():
			return _fire_projectile_pool.pop_back()
		return RunicFire.new(true)
	if _ballistic_pool.has(type):
		var pool: Array = _ballistic_pool[type]
		if not pool.is_empty():
			return pool.pop_back()
		return BallisticProjectile.new(type)
	if not _projectile_meshes.has(type):
		var heavy := type == "cannon"
		var ballistic := type in ["cannon", "arrow", "sniper"]
		var radius := 0.028 if heavy else (0.011 if type == "sniper" else 0.009)
		var length := 0.13 if heavy else 0.075
		var material := StandardMaterial3D.new()
		if ballistic:
			material.albedo_color = Color("45494d") if heavy else Color("c8a269")
			material.metallic = 0.5 if heavy else 0.72
			material.roughness = 0.65 if heavy else 0.42
		else:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = PROJECTILE_COLORS[type]
		var body := CylinderMesh.new()
		body.top_radius = radius
		body.bottom_radius = radius
		body.height = length
		body.radial_segments = 8
		body.material = material
		var nose := CylinderMesh.new()
		nose.top_radius = 0.0
		nose.bottom_radius = radius
		nose.height = length * 0.32
		nose.radial_segments = 8
		nose.material = material
		var tracer_length := 0.10 if heavy else 0.13
		var tracer := CylinderMesh.new()
		tracer.top_radius = 0.007 if heavy else 0.0035
		tracer.bottom_radius = 0.002 if heavy else 0.0015
		tracer.height = tracer_length
		tracer.radial_segments = 5
		var tracer_material := StandardMaterial3D.new()
		tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color: Color = PROJECTILE_COLORS[type]
		color.a = 0.32 if heavy else 0.55
		tracer_material.albedo_color = color
		tracer.material = tracer_material
		_projectile_meshes[type] = {"meshes": [body, nose, tracer], "z": [0.0, length * 0.66, -(length + tracer_length) / 2.0]}
	var root := Node3D.new()
	root.name = "Projectile_" + type
	var template: Dictionary = _projectile_meshes[type]
	for index in range(3):
		var mesh := MeshInstance3D.new()
		mesh.mesh = template["meshes"][index]
		mesh.rotation.x = PI / 2.0
		mesh.position.z = float(template["z"][index])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
	return root


func _sync_projectiles(units: Array) -> void:
	var alive := {}
	for data: Array in units:
		var id := int(data[0])
		var type := str(data[5]) if data.size() > 5 else "cannon"
		if not TURRET_MODELS.has(type):
			_fail("지원하지 않는 탄환: %s" % type)
			continue
		alive[id] = true
		if projectiles.has(id) and projectiles[id]["type"] != type:
			projectiles[id]["root"].free()
			projectiles.erase(id)
		if not projectiles.has(id):
			var model := _new_projectile(type)
			if not model.is_inside_tree():
				world.add_child(model)
			projectiles[id] = {"root": model, "type": type}
		var root: Node3D = projectiles[id]["root"]
		if type == "magic":
			_update_fire_projectile(projectiles[id], data)
			continue
		if root is BallisticProjectile:
			var pose = null
			if data.size() >= 12 and data[8] != null and not bool(data[10]):
				var owner: Dictionary = turrets.get(int(data[8]), {})
				if int(owner.get("last_shot", -1)) == int(data[9]):
					pose = owner.get("shot_pose")
			root.update_flight(data, float(last_frame.get("time", 0.0)), Vector3(-columns / 2.0, 0.0, -rows / 2.0), pose)
			root.update_camera(camera)
			continue
		root.position = Vector3(float(data[1]) - columns / 2.0, 0.56 if type == "cannon" else 0.45, float(data[2]) - rows / 2.0)
		root.rotation.y = PI / 2.0 - atan2(float(data[4]), float(data[3]))
	for id in projectiles.keys():
		if not alive.has(id):
			var projectile: Node3D = projectiles[id]["root"]
			var type: String = projectiles[id]["type"]
			if type == "magic" and _fire_projectile_pool.size() < 64:
				projectile.reset()
				_fire_projectile_pool.append(projectile)
			elif projectile is BallisticProjectile and _ballistic_pool[type].size() < 64:
				projectile.reset()
				_ballistic_pool[type].append(projectile)
			elif _generic_projectile_pool.has(type) and _generic_projectile_pool[type].size() < 64:
				projectile.visible = false
				projectile.transform = Transform3D.IDENTITY
				_generic_projectile_pool[type].append(projectile)
			else:
				projectile.free()
			projectiles.erase(id)


func _update_fire_projectile(entry: Dictionary, data: Array) -> void:
	var root: Node3D = entry["root"]
	var time := float(last_frame.get("time", 0.0))
	var map_offset := Vector3(-columns / 2.0, 0.0, -rows / 2.0)
	var point := Vector3(float(data[1]), 0.45, float(data[2])) + map_offset
	var direction := Vector3(float(data[3]), 0.0, float(data[4])).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector3.BACK
	var metadata := data.size() >= 12
	var finished_at := float(data[11]) if metadata else -1.0
	var finished := finished_at >= 0.0
	if time < float(entry.get("last_time", -INF)):
		root.reset()
		entry.erase("launch_position")
	entry["last_time"] = time
	if not entry.has("launch_position"):
		var launch := point - direction * 0.30
		if metadata:
			launch = Vector3(float(data[6]), 0.45, float(data[7])) + map_offset
			if not bool(data[10]):
				var owner: Dictionary = turrets.get(int(data[8]), {}) if data[8] != null else {}
				var pose = owner.get("shot_pose")
				if int(owner.get("last_shot", -1)) == int(data[9]) and pose is Transform3D:
					launch = pose.origin
				# magic의 origin에는 이미 Dart 화구 오프셋이 포함된다.
		entry["launch_position"] = launch
	if finished and data.size() >= 14 and data[12] != null and data[13] != null:
		point.x = float(data[12]) + map_offset.x
		point.z = float(data[13]) + map_offset.z
	var offset: Vector3 = point - entry["launch_position"]
	var travelled := offset.dot(direction)
	if travelled > 0.01:
		direction = offset.normalized()
	var right := Vector3.UP.cross(direction).normalized()
	root.global_transform = Transform3D(Basis(right, direction.cross(right), direction), point)
	var age := fposmod(time - finished_at, 1200.0) if finished else 0.0
	var opacity := pow(clampf(1.0 - age / 0.14, 0.0, 1.0), 1.4) if finished else 1.0
	# 전투 좌표·명중 시점은 그대로 두고 종료 후 짧은 잔불만 표시한다.
	root.update_projectile(time, not finished and travelled > 0.01, opacity if travelled > 0.01 else 0.0)


func _update_impacts(units: Array) -> void:
	var alive := {}
	for light in impact_lights:
		light.light_energy = 0.0
	var light_index := 0
	for data: Array in units:
		var id := int(data[0])
		alive[id] = true
		if not impacts.has(id):
			var effect: Node3D
			if impact_pool.is_empty():
				effect = Impact.new()
				world.add_child(effect)
				effect.configure(field["texture"], field["manifest"])
			else:
				effect = impact_pool.pop_back()
			impacts[id] = effect
		var effect: Node3D = impacts[id]
		effect.visible = bool(options["volume"])
		effect.position = Vector3(float(data[1]) - columns / 2.0, 0, float(data[2]) - rows / 2.0)
		if effect.visible:
			effect.update_impact(float(data[4]), float(data[3]), id, camera)
			if float(data[4]) < 0.68 and light_index < impact_lights.size():
				var light := impact_lights[light_index]
				light.position = effect.position + Vector3(0, 0.3 + float(data[3]) * 0.12, 0)
				light.omni_range = float(data[3]) * 3.2
				light.light_energy = 1.6 * pow(1.0 - float(data[4]) / 0.68, 2)
				light_index += 1
	for id in impacts.keys():
		if not alive.has(id):
			var effect: Node3D = impacts[id]
			effect.visible = false
			impact_pool.append(effect)
			impacts.erase(id)


func _unhandled_key_input(event: InputEvent) -> void:
	if bridge or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: standalone_playing = not standalone_playing
		KEY_C: options["camera"] = "drone" if options["camera"] == "angled" else "angled"
		KEY_S: options["shadows"] = not options["shadows"]
		KEY_V: options["volume"] = not options["volume"]
	_apply_options()
