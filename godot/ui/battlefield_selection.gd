extends Node2D
## Native camera projection of Dart-resolved selection state. No combat queries.
var _frame: Dictionary = {}
var selection_revision := -1
var _animation_clock := 0.0
var _selection_time := 0.0
var _aim: Dictionary = {}
var _show_all_ranges := false
const MAX_RANGE_PATHS := 256
var _range_paths: Dictionary = {}
var _range_context: Array = []
var _range_unit_circle := PackedVector2Array()
var _camera: Camera3D
var _world: Node3D
var _map_size := Vector2.ZERO
var _tile := 48.0
var _dim: ColorRect
var _dim_material: ShaderMaterial
var _clip_material: ShaderMaterial
var _turrets: Dictionary = {}
# A separate white silhouette pass shares the selected meshes; no duplicate
# terrain, materials, lighting or gameplay scene is created.
var _mask_viewport: SubViewport
var _mask_camera: Camera3D
var _mask_root: Node3D
var _mask_material: StandardMaterial3D
var _mask_meshes: Dictionary = {}

# Keep submission order: each turret's static ornaments precede its animated
# ornaments, followed by tiles/reward outlines, exactly as the original draw.
class SelectionLayer extends Node2D:
	var renderer: Node2D
	var data: Dictionary
	var role: String
	var index := -1
	func _draw() -> void:
		renderer._paint_layer(self)

var _layers: Array[SelectionLayer] = []
var _layers_dirty := true
var _draw_target: Node2D
var _tile_paths: Dictionary = {}
var _arc_units: Dictionary = {}
var _scales: Dictionary = {}
var _mask_sources: Array[MeshInstance3D] = []
var _mask_targets: Array[Node3D] = []
var _mask_tree_dirty := true
var _mask_context: Array = []
var _dim_context: Array = []
var _mask_observed: Array[Node] = []
var _turret_roots: Array = []
var _turret_revision := -1
var _mask_updates := 0
var _mask_geometry_dirty := false
var _mask_resources: Array[Mesh] = []
var _static_redraws := 0
var _dynamic_redraws := 0

func supported_groups() -> Array:
	return ["selection"] if is_instance_valid(_dim_material) and is_instance_valid(_clip_material) and is_instance_valid(_mask_camera) else []

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree(): _clear_mask()
		else: _layers_dirty = true

# Revision is supplied by the model owner. Untracked callers retain content checks.
func set_turrets(turrets: Dictionary, revision := -1) -> void:
	if revision >= 0 and revision == _turret_revision and is_same(_turrets, turrets):
		return
	_turrets = turrets
	_turret_revision = revision
	var roots: Array = []
	for entry in turrets.values(): roots.append(entry.get("root"))
	if roots != _turret_roots:
		_turret_roots = roots
		_mask_tree_dirty = true

func _ready() -> void:
	_dim = ColorRect.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.show_behind_parent = true
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D target_mask : filter_linear, repeat_disable;
uniform vec4 clip_rect = vec4(0.0);
uniform vec2 canvas_size = vec2(1.0);
void fragment() {
 vec2 p = SCREEN_UV * canvas_size;
 bool in_clip = p.x >= clip_rect.x && p.y >= clip_rect.y && p.x <= clip_rect.z && p.y <= clip_rect.w;
 float alpha = 173.0 / 255.0;
 if (in_clip) alpha *= 1.0 - texture(target_mask, SCREEN_UV).a;
 COLOR = vec4(2.0/255.0,7.0/255.0,13.0/255.0,alpha);
}"""
	_dim_material = ShaderMaterial.new()
	_dim_material.shader = shader
	_dim.material = _dim_material
	add_child(_dim)
	_dim.hide()
	var clip_shader := Shader.new()
	clip_shader.code = """shader_type canvas_item;
uniform vec4 clip_rect = vec4(0.0);
uniform vec2 canvas_size = vec2(1.0);
void fragment() {
 vec2 p = SCREEN_UV * canvas_size;
 if(p.x<clip_rect.x || p.y<clip_rect.y || p.x>clip_rect.z || p.y>clip_rect.w) discard;
}"""
	_clip_material = ShaderMaterial.new()
	_clip_material.shader = clip_shader
	_create_mask()

func has_frame() -> bool:
	return not _frame.is_empty()

func reward_targeting() -> bool:
	return bool(_frame.get("rewardTargeting", false))

func set_canvas_enabled(enabled: bool) -> void:
	visible = enabled

func apply_frame(frame: Dictionary, owned_snapshot := false) -> void:
	var changed := false
	var old_clock := _animation_clock
	var old_time := _selection_time
	var next_aim: Dictionary = {}
	if frame.has("revision"):
		var revision := int(frame["revision"])
		if frame.get("state") is Dictionary:
			if revision != selection_revision or _frame.is_empty():
				_frame = frame["state"].duplicate(not owned_snapshot)
				changed = true
			selection_revision = revision
		elif revision != selection_revision:
			clear()
			return
		_frame["viewport"] = frame.get("viewport", [])
		_animation_clock = float(frame.get("clock", 0.0))
		_selection_time = float(frame.get("time", 0.0))
		for aim: Array in frame.get("aim", []):
			if aim.size() == 4: next_aim[int(aim[0])] = aim
	else:
		selection_revision = -1
		changed = _frame != frame
		if changed: _frame = frame.duplicate(not owned_snapshot)
		_selection_time = float(frame.get("time", 0.0))
	if _frame.get("preserveLegacyOrnaments", false): next_aim.clear()
	var aim_changed := _aim != next_aim
	_aim = next_aim
	if changed:
		_layers_dirty = true
		_mask_tree_dirty = true
		_show_all_ranges = false
		for tile in _frame.get("tiles", []):
			if tile.get("kind", "") == "build":
				_show_all_ranges = true
				break
	elif is_visible_in_tree():
		for layer in _layers:
			if (layer.role == "reward" and old_time != _selection_time) or (layer.role == "dynamic" and (aim_changed or (old_clock != _animation_clock and _has_animation(layer.data, layer.index)))):
				layer.queue_redraw()
				_dynamic_redraws += 1

func _has_animation(data: Dictionary, index: int) -> bool:
	return not data.get("gemColors", []).is_empty() or not _aim_for(data, index).is_empty() or data.get("aimTarget") != null

func _aim_for(data: Dictionary, index: int) -> Array:
	if bool(_frame.get("preserveLegacyOrnaments", false)): return []
	return _aim.get(int(data.get("id", index)) if _frame.get("aimKey", "index") == "id" else index, [])

func clear() -> void:
	_frame = {}
	selection_revision = -1
	_animation_clock = 0.0
	_aim.clear()
	_show_all_ranges = false
	_range_paths.clear()
	_range_context.clear()
	_tile_paths.clear()
	_scales.clear()
	_layers_dirty = true
	for layer in _layers: layer.free()
	_layers.clear()
	_turrets = {}
	_turret_roots.clear()
	_turret_revision = -1
	material = null
	if is_instance_valid(_dim): _dim.hide()
	_clear_mask()
	queue_redraw()

func present(camera: Camera3D, map_size: Vector2, world: Node3D) -> void:
	prepare_context(camera, map_size, world, false)
	_update_dim()


# 초기 frame/tween에서도 draw 입력을 즉시 준비하되 mask 렌더 동기화는 한 번만 한다.
func prepare_context(camera: Camera3D, map_size: Vector2, world: Node3D, redraw := true) -> void:
	_camera = camera
	_world = world
	_map_size = map_size
	_tile = maxf(float(_frame.get("logicalTileSize", 48.0)), 1.0)
	# Exact inputs to _project, including camera offsets, zoom, viewport and shake.
	# Unrelated combat updates do not invalidate static range geometry.
	var context := [camera.get_camera_transform(), camera.get_camera_projection(),
		camera.get_viewport().get_visible_rect(), world.global_transform, map_size, _tile]
	if context != _range_context:
		_range_context = context
		_range_paths.clear()
		_tile_paths.clear()
		_scales.clear()
		if not is_visible_in_tree():
			_layers_dirty = true
			return
		for layer in _layers:
			layer.queue_redraw()
			if layer.role == "static" or layer.role == "tile": _static_redraws += 1
			else: _dynamic_redraws += 1
	if is_visible_in_tree() and _layers_dirty: _rebuild_layers()

func _project(point: Vector2, height: float = 0.04) -> Vector2:
	return _camera.unproject_position(_world.to_global(Vector3(point.x - _map_size.x / 2.0, height, point.y - _map_size.y / 2.0)))

func _position(data: Dictionary) -> Vector2:
	var p: Array = data.get("position", [0.0, 0.0])
	return Vector2(float(p[0]), float(p[1]))

func _color(value: Variant, alpha: float = -1.0) -> Color:
	var argb := int(value) if value != null else 0xffffffff
	var result := Color(float((argb >> 16) & 255) / 255.0, float((argb >> 8) & 255) / 255.0, float(argb & 255) / 255.0, float((argb >> 24) & 255) / 255.0)
	if alpha >= 0.0: result.a = alpha
	return result

func _scale_at(p: Vector2) -> float:
	if not _scales.has(p):
		if _scales.size() >= 512: _scales.clear()
		_scales[p] = _project(p + Vector2(0.5, 0)).distance_to(_project(p - Vector2(0.5, 0))) / _tile
	return _scales[p]

func _path(center: Vector2, radius: float, start: float = 0.0, sweep: float = TAU) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(12, int(absf(sweep) / TAU * 96.0))
	var key := Vector2(sweep, count)
	if not _arc_units.has(key):
		var unit := PackedVector2Array()
		for i in range(count + 1):
			var angle := sweep * float(i) / count
			unit.append(Vector2(cos(angle), sin(angle)))
		if _arc_units.size() >= 64: _arc_units.clear()
		_arc_units[key] = unit
	var rotation := Transform2D(start, Vector2.ZERO)
	for direction in _arc_units[key]:
		points.append(_project(center + (rotation * direction) * radius))
	return points

func _ring(p: Vector2, radius: float, color: Color, width: float, fill: bool = false, start: float = 0.0, sweep: float = TAU) -> void:
	var points := _range_path(p, radius) if start == 0.0 and sweep == TAU else _path(p, radius, start, sweep)
	_draw_ring_path(points, p, color, width, fill)

func _range_path(center: Vector2, radius: float) -> PackedVector2Array:
	# Only static full range circles use this cache; animated gem arcs do not.
	var key := Vector3(center.x, center.y, radius)
	if _range_paths.has(key):
		return _range_paths[key]
	if _range_unit_circle.is_empty():
		for i in range(97):
			var angle := TAU * float(i) / 96
			_range_unit_circle.append(Vector2(cos(angle), sin(angle)))
	var points := PackedVector2Array()
	for direction in _range_unit_circle:
		points.append(_project(center + direction * radius))
	# Bound obsolete radii/positions retained across upgrades and construction.
	if _range_paths.size() >= MAX_RANGE_PATHS:
		_range_paths.clear()
	_range_paths[key] = points
	return points

func _range_ring(p: Vector2, radius: float, color: Color, width: float, fill: bool = false) -> void:
	_draw_ring_path(_range_path(p, radius), p, color, width, fill)

func _draw_ring_path(points: PackedVector2Array, p: Vector2, color: Color, width: float, fill: bool) -> void:
	if fill: _draw_target.draw_colored_polygon(points, color)
	else: _draw_target.draw_polyline(points, color, maxf(width * _scale_at(p), 0.3), true)

func _tile_path(p: Vector2, inset: float, radius: float = 0.0) -> PackedVector2Array:
	var key := Vector4(p.x, p.y, inset, radius)
	if _tile_paths.has(key): return _tile_paths[key]
	if _tile_paths.size() >= 512: _tile_paths.clear()
	var half := 0.5 - inset
	var result := PackedVector2Array()
	if radius <= 0:
		for delta in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half), Vector2(-half, -half)]:
			result.append(_project(p + delta))
		_tile_paths[key] = result
		return result
	for corner in range(4):
		var angle := -PI + corner * PI / 2.0
		var c := p + Vector2(-half + radius if corner == 0 or corner == 3 else half - radius, -half + radius if corner < 2 else half - radius)
		for step in range(9):
			var a := angle + float(step) / 8.0 * PI / 2.0
			result.append(_project(c + Vector2(cos(a), sin(a)) * radius))
	result.append(result[0])
	_tile_paths[key] = result
	return result

func _outline(points: PackedVector2Array, color: Color, width: float, p: Vector2) -> void:
	_draw_target.draw_polyline(points, color, maxf(width * _scale_at(p), 0.3), true)

func _rebuild_layers() -> void:
	for layer in _layers: layer.free()
	_layers.clear()
	_layers_dirty = false
	var rewarding := reward_targeting()
	var entries: Array = _frame.get("turrets", [])
	for index in range(entries.size()):
		var turret: Dictionary = entries[index]
		if rewarding and not _is_reward_target(_position(turret)): continue
		_add_layer(turret, "static", index)
		if not _frame.get("preserveLegacyOrnaments", false) or _has_animation(turret, index): _add_layer(turret, "dynamic", index)
	for data in _frame.get("rewardTargets" if rewarding else "tiles", []):
		_add_layer(data, "reward" if rewarding else "tile")

func _add_layer(data: Dictionary, role: String, index := -1) -> void:
	var layer := SelectionLayer.new()
	layer.renderer = self
	layer.data = data
	layer.role = role
	layer.index = index
	layer.use_parent_material = true
	add_child(layer)
	_layers.append(layer)
	if role == "static" or role == "tile": _static_redraws += 1
	else: _dynamic_redraws += 1

func _paint_layer(layer: SelectionLayer) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_world): return
	_draw_target = layer
	match layer.role:
		"static": _draw_turret(layer.data, reward_targeting(), layer.index)
		"dynamic": _draw_turret_dynamic(layer.data, layer.index)
		"tile": _draw_tile(layer.data)
		"reward": _draw_reward(layer.data)

func _is_reward_target(p: Vector2) -> bool:
	for target in _frame.get("rewardTargets", []):
		if _position(target).is_equal_approx(p): return true
	return false

func _draw_turret(data: Dictionary, rewarding: bool, index := -1) -> void:
	var p := _position(data)
	var color := _color(data.get("color"))
	var radius := float(data.get("range", 0.0))
	var selected := bool(data.get("selected", false))
	if not rewarding:
		if selected or _show_all_ranges:
			_range_ring(p, radius, _color(data.get("color"), 0.08), 0, true)
		if selected:
			var preview: Variant = data.get("previewRange")
			if preview != null and float(preview) > radius:
				_range_ring(p, float(preview), _color(data.get("color"), 0.045), 0, true)
				_range_ring(p, float(preview), _color(data.get("color"), 0.34), 1.3)
			_range_ring(p, radius, _color(data.get("color"), 0.48), 1.8)
			var outline := _tile_path(p, 2.0 / _tile, 0.09)
			_outline(outline, _color(data.get("color"), 0.2), 8, p)
			_outline(outline, _color(data.get("color"), 0.95), 3.2, p)
			_ring(p, 0.42, _color(data.get("color"), 0.95), 3.2)
			_ring(p, 0.32, Color(1, 1, 1, 238.0 / 255.0), 1.4)
	var tier := int(data.get("auraTier", 0))
	if selection_revision >= 0 and not _frame.get("preserveLegacyOrnaments", false) and data.get("level") != null:
		var level := int(data["level"])
		tier = 0 if level <= 1 else 4 if level >= 10 else 3 if level >= 8 else 2 if level >= 5 else 1
	if tier > 0:
		var r := 0.28 + tier * 0.015
		_ring(p, r, _color(0xffffd45a, 0.045 + tier * 0.02), _tile * (0.034 + tier * 0.004))
		_ring(p, r, _color(0xffffe78c, 0.16 + tier * 0.055), 1.0 + tier * 0.25)
		if tier >= 3:
			for angle in [-PI / 2, 0.0, PI / 2, PI]:
				var direction := Vector2(cos(angle), sin(angle))
				_draw_target.draw_line(_project(p + direction * r), _project(p + direction * (r + 0.035)), _color(0xfffff0b0, 0.92 if tier >= 4 else 0.7), (1.8 if tier >= 4 else 1.45) * _scale_at(p), true)
	if not data.get("gemColors", []).is_empty():
		_ring(p, 0.43, _color(0xff020812, 0.76), _tile * 0.03 * 2.1)

func _draw_turret_dynamic(data: Dictionary, index: int) -> void:
	var p := _position(data)
	var color := _color(data.get("color"))
	var phase := animation_phase(data)
	var gems: Array = data.get("gemColors", [])
	if not gems.is_empty():
		var pulse := 0.88 + sin(phase * 2.4) * 0.12
		var gap := 0.0 if gems.size() == 1 else 0.22
		var sweep := PI * 1.64 if gems.size() == 1 else TAU / gems.size() - gap
		var offset := -PI / 2 - (sweep / 2 if gems.size() == 1 else 0.0) + phase
		for i in range(gems.size()):
			var start := offset if gems.size() == 1 else offset + i * TAU / gems.size() + gap / 2
			var gem := _color(gems[i]).lerp(Color.WHITE, 0.12)
			gem.a = 0.34 * pulse
			var arc := _path(p, 0.43, start, sweep)
			_draw_ring_path(arc, p, gem, _tile * 0.1, false)
			gem.a = 0.96 * pulse
			_draw_ring_path(arc, p, gem, _tile * 0.03, false)
			var direction := Vector2(cos(start + sweep / 2), sin(start + sweep / 2))
			_draw_target.draw_line(_project(p + direction * 0.39), _project(p + direction * 0.47), Color(1, 1, 1, 0.72 * pulse), _tile * 0.011 * _scale_at(p), true)
	var target: Variant = data.get("aimTarget")
	var progress := float(data.get("aimProgress", 0.0))
	if selection_revision >= 0:
		var aim: Array = _aim_for(data, index)
		target = [aim[1], aim[2]] if aim.size() == 4 else null
		progress = float(aim[3]) if aim.size() == 4 else 0.0
	if target != null and progress > 0:
		color.a = (0.16 + progress * 0.42) * (0.55 + sin(phase * 8) * 0.18)
		_draw_target.draw_line(_project(p), _project(Vector2(float(target[0]), float(target[1]))), color, _tile * (0.018 + progress * 0.014) * _scale_at(p), true)
		color.a = 0.16 + progress * 0.16
		_ring(p, 0.08 + progress * 0.07, color, _tile * 0.025)

func animation_phase(data: Dictionary) -> float:
	if selection_revision >= 0 and data.get("phaseOrigin") != null:
		return fposmod(float(data["phaseOrigin"]) + _animation_clock * 0.45, TAU)
	return float(data.get("animationPhase", 0.0))

func _draw_tile(data: Dictionary) -> void:
	var p := _position(data)
	var kind := str(data.get("kind", "build"))
	var outline := _tile_path(p, 2.0 / _tile)
	if kind == "core": _draw_target.draw_colored_polygon(outline, _color(0x228ee6ff))
	if data.get("range") != null:
		_range_ring(p, float(data.range), _color(data.get("color"), 0.09), 0, true)
		_range_ring(p, float(data.range), _color(data.get("color"), 0.42), 1.6)
	_outline(outline, _color(0xccb16dff if kind == "portal" else 0xcc8ee6ff if kind == "core" else 0x668ee6ff), 3, p)

func _draw_reward(data: Dictionary) -> void:
	var p := _position(data)
	var scale := minf(float(_frame.get("visualScale", 1.0)), _tile / 24.0)
	var inset := 2.0 * scale / _tile
	var outline := _tile_path(p, inset, 3.0 * scale / _tile)
	var pulse := 0.9 + sin(_selection_time * PI / 1.8) * 0.1
	_outline(outline, _color(0xffffd95c, 0.11 * pulse), 6 * scale, p)
	_outline(outline, _color(0xffffd95c, 0.22 * pulse), 3.5 * scale, p)
	_outline(outline, _color(0xffffe989, 0.95), 1.35 * scale, p)
	if not bool(data.get("requiresReplacement", false)): return
	_outline(_tile_path(p, inset + 3 * scale / _tile, 3 * scale / _tile), _color(0xffffe989, 0.85), 1.1 * scale, p)
	var center := _project(p + Vector2(0.5 - 4 * scale / _tile, -0.5 + 4 * scale / _tile))
	var s := scale * _scale_at(p)
	var r := 7.5 * s
	_draw_target.draw_circle(center, r + 1.5 * s, _color(0xffffd95c, 0.15 * pulse))
	_draw_target.draw_circle(center, r, _color(0xff101a20))
	_draw_target.draw_arc(center, r, 0, TAU, 48, _color(0xffffe989), 1.15 * s, true)
	for start in [-PI * 0.85, PI * 0.15]:
		var finish: float = start + PI * 0.7
		_draw_target.draw_arc(center, r * 0.48, start, finish, 20, _color(0xffffe989), 1.15 * s, true)
		var radial := Vector2(cos(finish), sin(finish))
		var tangent := Vector2(-sin(finish), cos(finish))
		var tip := center + radial * r * 0.48
		_draw_target.draw_polyline(PackedVector2Array([tip - tangent * 2.2 * s + radial * 1.6 * s, tip, tip - tangent * 2.2 * s - radial * 1.6 * s]), _color(0xffffe989), 1.15 * s, true)

func _update_dim() -> void:
	if not is_instance_valid(_dim): return
	var active := is_visible_in_tree() and bool(_frame.get("rewardTargeting", false)) and is_instance_valid(_camera) and is_instance_valid(_world)
	_dim.visible = active
	material = _clip_material if active else null
	if not active:
		if not _mask_context.is_empty() or not _mask_sources.is_empty(): _clear_mask()
		return
	var viewport := get_viewport_rect()
	_dim.position = viewport.position
	_dim.size = viewport.size
	var clip := viewport
	var raw: Variant = _frame.get("rewardViewport")
	# Bridge viewport is logical pixels; native surface may use physical pixels.
	var logical: Array = _frame.get("viewport", [viewport.size.x, viewport.size.y])
	if logical.size() < 2: logical = [viewport.size.x, viewport.size.y]
	var ratio := viewport.size / Vector2(maxf(float(logical[0]), 1), maxf(float(logical[1]), 1))
	if raw != null: clip = Rect2(Vector2(float(raw[0]), float(raw[1])) * ratio, Vector2(float(raw[2]), float(raw[3])) * ratio)
	var context := [viewport, clip]
	if context != _dim_context:
		_dim_context = context
		_dim_material.set_shader_parameter("canvas_size", viewport.size)
		_clip_material.set_shader_parameter("canvas_size", viewport.size)
		_dim_material.set_shader_parameter("clip_rect", Vector4(clip.position.x, clip.position.y, clip.end.x, clip.end.y))
		_clip_material.set_shader_parameter("clip_rect", Vector4(clip.position.x, clip.position.y, clip.end.x, clip.end.y))
	_update_mask(viewport.size)

func _create_mask() -> void:
	_mask_viewport = SubViewport.new()
	_mask_viewport.name = "RewardTargetSilhouette"
	_mask_viewport.own_world_3d = true
	_mask_viewport.size = Vector2i(2, 2)
	_mask_viewport.transparent_bg = true
	_mask_viewport.gui_disable_input = true
	_mask_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_mask_viewport)
	_mask_root = Node3D.new()
	_mask_viewport.add_child(_mask_root)
	_mask_camera = Camera3D.new()
	_mask_viewport.add_child(_mask_camera)
	_mask_camera.current = true
	_mask_camera.cull_mask = 1
	_mask_material = StandardMaterial3D.new()
	_mask_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mask_material.albedo_color = Color.WHITE
	_mask_material.disable_fog = true
	_dim_material.set_shader_parameter("target_mask", _mask_viewport.get_texture())

func _update_mask(viewport_size: Vector2) -> void:
	if not is_instance_valid(_mask_viewport): return
	var context := [_camera.get_camera_transform(), _camera.get_camera_projection(), viewport_size, get_viewport().msaa_3d]
	var changed := context != _mask_context or _mask_geometry_dirty
	_mask_geometry_dirty = false
	if changed:
		_mask_context = context
		_mask_viewport.size = Vector2i(maxi(2, roundi(viewport_size.x)), maxi(2, roundi(viewport_size.y)))
		_mask_viewport.msaa_3d = get_viewport().msaa_3d
		_mask_camera.projection = _camera.projection
		_mask_camera.keep_aspect = _camera.keep_aspect
		_mask_camera.fov = _camera.fov
		_mask_camera.size = _camera.size
		_mask_camera.near = _camera.near
		_mask_camera.far = _camera.far
		_mask_camera.frustum_offset = _camera.frustum_offset
		_mask_camera.h_offset = _camera.h_offset
		_mask_camera.v_offset = _camera.v_offset
		_mask_camera.global_transform = _camera.global_transform
	if _mask_tree_dirty:
		_disconnect_mask_observers()
		_mask_sources.clear()
		_mask_targets.clear()
		for data in _frame.get("rewardTargets", []):
			var target := _target_model(_position(data))
			if is_instance_valid(target):
				_mask_targets.append(target)
				_collect_mask_meshes(target)
		_mask_tree_dirty = false
	var alive: Dictionary = {}
	for source in _mask_sources:
		if not is_instance_valid(source) or not source.is_visible_in_tree() or source.mesh == null: continue
		if source.mesh not in _mask_resources:
			_mask_resources.append(source.mesh)
			source.mesh.changed.connect(_mask_geometry_changed)
		var id := source.get_instance_id()
		alive[id] = true
		if not _mask_meshes.has(id):
			var clone := MeshInstance3D.new()
			clone.material_override = _mask_material
			clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			clone.layers = 1
			_mask_root.add_child(clone)
			_mask_meshes[id] = clone
			changed = true
		var clone: MeshInstance3D = _mask_meshes[id]
		if clone.mesh != source.mesh:
			if clone.mesh != null: _mask_tree_dirty = true
			clone.mesh = source.mesh
			changed = true
		if clone.global_transform != source.global_transform:
			clone.global_transform = source.global_transform
			changed = true
	for id in _mask_meshes.keys():
		if alive.has(id): continue
		_mask_meshes[id].free()
		_mask_meshes.erase(id)
		changed = true
	if changed:
		_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_mask_updates += 1

func _mask_geometry_changed() -> void:
	_mask_geometry_dirty = true

func _mask_hierarchy_changed(_node: Node) -> void:
	_mask_tree_dirty = true

func _collect_mask_meshes(source: Node3D) -> void:
	_mask_observed.append(source)
	source.child_entered_tree.connect(_mask_hierarchy_changed)
	source.child_exiting_tree.connect(_mask_hierarchy_changed)
	if source is MeshInstance3D: _mask_sources.append(source)
	for child in source.get_children():
		if child is Node3D: _collect_mask_meshes(child)

func _disconnect_mask_observers() -> void:
	for node in _mask_observed:
		if not is_instance_valid(node): continue
		node.child_entered_tree.disconnect(_mask_hierarchy_changed)
		node.child_exiting_tree.disconnect(_mask_hierarchy_changed)
	_mask_observed.clear()
	for mesh in _mask_resources:
		mesh.changed.disconnect(_mask_geometry_changed)
	_mask_resources.clear()

func _target_model(p: Vector2) -> Node3D:
	for entry in _turrets.values():
		var model: Node3D = entry.get("root")
		if not is_instance_valid(model): continue
		var local := _world.to_local(model.global_position)
		if Vector2(local.x + _map_size.x / 2, local.z + _map_size.y / 2).distance_to(p) < 0.1:
			return model
	return null

func _clear_mask() -> void:
	_disconnect_mask_observers()
	_mask_sources.clear()
	_mask_targets.clear()
	_mask_context.clear()
	_mask_geometry_dirty = false
	_mask_tree_dirty = true
	if not is_instance_valid(_mask_viewport): return
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mask_viewport.size = Vector2i(2, 2)
	for clone: MeshInstance3D in _mask_meshes.values(): clone.free()
	_mask_meshes.clear()
