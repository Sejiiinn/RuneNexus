extends Node2D
## Native camera projection of Dart-resolved selection state. No combat queries.
var _frame: Dictionary = {}
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

func supported_groups() -> Array:
	return ["selection"] if is_instance_valid(_dim_material) and is_instance_valid(_clip_material) and is_instance_valid(_mask_camera) else []

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_clear_mask()

func set_turrets(turrets: Dictionary) -> void:
	_turrets = turrets

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

func apply_frame(frame: Dictionary) -> void:
	_frame = frame.duplicate(true)

func clear() -> void:
	_frame.clear()
	_turrets = {}
	material = null
	if is_instance_valid(_dim): _dim.hide()
	_clear_mask()
	queue_redraw()

func present(camera: Camera3D, map_size: Vector2, world: Node3D) -> void:
	_camera = camera
	_world = world
	_map_size = map_size
	_tile = maxf(float(_frame.get("logicalTileSize", 48.0)), 1.0)
	_update_dim()
	queue_redraw()

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
	return _project(p + Vector2(0.5, 0)).distance_to(_project(p - Vector2(0.5, 0))) / _tile

func _path(center: Vector2, radius: float, start: float = 0.0, sweep: float = TAU) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(12, int(absf(sweep) / TAU * 96.0))
	for i in range(count + 1):
		var angle := start + sweep * float(i) / count
		points.append(_project(center + Vector2(cos(angle), sin(angle)) * radius))
	return points

func _ring(p: Vector2, radius: float, color: Color, width: float, fill: bool = false, start: float = 0.0, sweep: float = TAU) -> void:
	var points := _path(p, radius, start, sweep)
	if fill: draw_colored_polygon(points, color)
	else: draw_polyline(points, color, maxf(width * _scale_at(p), 0.3), true)

func _tile_path(p: Vector2, inset: float, radius: float = 0.0) -> PackedVector2Array:
	var half := 0.5 - inset
	var result := PackedVector2Array()
	if radius <= 0:
		for delta in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half), Vector2(-half, -half)]:
			result.append(_project(p + delta))
		return result
	for corner in range(4):
		var angle := -PI + corner * PI / 2.0
		var c := p + Vector2(-half + radius if corner == 0 or corner == 3 else half - radius, -half + radius if corner < 2 else half - radius)
		for step in range(9):
			var a := angle + float(step) / 8.0 * PI / 2.0
			result.append(_project(c + Vector2(cos(a), sin(a)) * radius))
	result.append(result[0])
	return result

func _outline(points: PackedVector2Array, color: Color, width: float, p: Vector2) -> void:
	draw_polyline(points, color, maxf(width * _scale_at(p), 0.3), true)

func _draw() -> void:
	if _frame.is_empty() or not is_instance_valid(_camera) or not is_instance_valid(_world): return
	var rewarding := bool(_frame.get("rewardTargeting", false))
	# Dim is a child drawn behind this node. During targeting only eligible
	# targets retain their ornaments; the same native models remain in place.
	for turret in _frame.get("turrets", []):
		if rewarding and not _is_reward_target(_position(turret)): continue
		_draw_turret(turret, rewarding)
	if not rewarding:
		for tile in _frame.get("tiles", []): _draw_tile(tile)
	else:
		for target in _frame.get("rewardTargets", []): _draw_reward(target)

func _is_reward_target(p: Vector2) -> bool:
	for target in _frame.get("rewardTargets", []):
		if _position(target).is_equal_approx(p): return true
	return false

func _draw_turret(data: Dictionary, rewarding: bool) -> void:
	var p := _position(data)
	var color := _color(data.get("color"))
	var radius := float(data.get("range", 0.0))
	var selected := bool(data.get("selected", false))
	if not rewarding:
		_ring(p, radius, _color(data.get("color"), 0.08), 0, true)
		if selected:
			var preview: Variant = data.get("previewRange")
			if preview != null and float(preview) > radius:
				_ring(p, float(preview), _color(data.get("color"), 0.045), 0, true)
				_ring(p, float(preview), _color(data.get("color"), 0.34), 1.3)
			_ring(p, radius, _color(data.get("color"), 0.48), 1.8)
			var outline := _tile_path(p, 2.0 / _tile, 0.09)
			_outline(outline, _color(data.get("color"), 0.2), 8, p)
			_outline(outline, _color(data.get("color"), 0.95), 3.2, p)
			_ring(p, 0.42, _color(data.get("color"), 0.95), 3.2)
			_ring(p, 0.32, Color(1, 1, 1, 238.0 / 255.0), 1.4)
	var tier := int(data.get("auraTier", 0))
	if tier > 0:
		var r := 0.28 + tier * 0.015
		_ring(p, r, _color(0xffffd45a, 0.045 + tier * 0.02), _tile * (0.034 + tier * 0.004))
		_ring(p, r, _color(0xffffe78c, 0.16 + tier * 0.055), 1.0 + tier * 0.25)
		if tier >= 3:
			for angle in [-PI / 2, 0.0, PI / 2, PI]:
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(_project(p + direction * r), _project(p + direction * (r + 0.035)), _color(0xfffff0b0, 0.92 if tier >= 4 else 0.7), (1.8 if tier >= 4 else 1.45) * _scale_at(p), true)
	var phase := float(data.get("animationPhase", 0.0))
	var gems: Array = data.get("gemColors", [])
	if not gems.is_empty():
		_ring(p, 0.43, _color(0xff020812, 0.76), _tile * 0.03 * 2.1)
		var pulse := 0.88 + sin(phase * 2.4) * 0.12
		var gap := 0.0 if gems.size() == 1 else 0.22
		var sweep := PI * 1.64 if gems.size() == 1 else TAU / gems.size() - gap
		var offset := -PI / 2 - (sweep / 2 if gems.size() == 1 else 0.0) + phase
		for i in range(gems.size()):
			var start := offset if gems.size() == 1 else offset + i * TAU / gems.size() + gap / 2
			var gem := _color(gems[i]).lerp(Color.WHITE, 0.12)
			gem.a = 0.34 * pulse
			_ring(p, 0.43, gem, _tile * 0.1, false, start, sweep)
			gem.a = 0.96 * pulse
			_ring(p, 0.43, gem, _tile * 0.03, false, start, sweep)
			var direction := Vector2(cos(start + sweep / 2), sin(start + sweep / 2))
			draw_line(_project(p + direction * 0.39), _project(p + direction * 0.47), Color(1, 1, 1, 0.72 * pulse), _tile * 0.011 * _scale_at(p), true)
	var target: Variant = data.get("aimTarget")
	var progress := float(data.get("aimProgress", 0.0))
	if target != null and progress > 0:
		color.a = (0.16 + progress * 0.42) * (0.55 + sin(phase * 8) * 0.18)
		draw_line(_project(p), _project(Vector2(float(target[0]), float(target[1]))), color, _tile * (0.018 + progress * 0.014) * _scale_at(p), true)
		color.a = 0.16 + progress * 0.16
		_ring(p, 0.08 + progress * 0.07, color, _tile * 0.025)

func _draw_tile(data: Dictionary) -> void:
	var p := _position(data)
	var kind := str(data.get("kind", "build"))
	var outline := _tile_path(p, 2.0 / _tile)
	if kind == "core": draw_colored_polygon(outline, _color(0x228ee6ff))
	if data.get("range") != null:
		_ring(p, float(data.range), _color(data.get("color"), 0.09), 0, true)
		_ring(p, float(data.range), _color(data.get("color"), 0.42), 1.6)
	_outline(outline, _color(0xccb16dff if kind == "portal" else 0xcc8ee6ff if kind == "core" else 0x668ee6ff), 3, p)

func _draw_reward(data: Dictionary) -> void:
	var p := _position(data)
	var scale := minf(float(_frame.get("visualScale", 1.0)), _tile / 24.0)
	var inset := 2.0 * scale / _tile
	var outline := _tile_path(p, inset, 3.0 * scale / _tile)
	var pulse := 0.9 + sin(float(_frame.get("time", 0.0)) * PI / 1.8) * 0.1
	_outline(outline, _color(0xffffd95c, 0.11 * pulse), 6 * scale, p)
	_outline(outline, _color(0xffffd95c, 0.22 * pulse), 3.5 * scale, p)
	_outline(outline, _color(0xffffe989, 0.95), 1.35 * scale, p)
	if not bool(data.get("requiresReplacement", false)): return
	_outline(_tile_path(p, inset + 3 * scale / _tile, 3 * scale / _tile), _color(0xffffe989, 0.85), 1.1 * scale, p)
	var center := _project(p + Vector2(0.5 - 4 * scale / _tile, -0.5 + 4 * scale / _tile))
	var s := scale * _scale_at(p)
	var r := 7.5 * s
	draw_circle(center, r + 1.5 * s, _color(0xffffd95c, 0.15 * pulse))
	draw_circle(center, r, _color(0xff101a20))
	draw_arc(center, r, 0, TAU, 48, _color(0xffffe989), 1.15 * s, true)
	for start in [-PI * 0.85, PI * 0.15]:
		var finish: float = start + PI * 0.7
		draw_arc(center, r * 0.48, start, finish, 20, _color(0xffffe989), 1.15 * s, true)
		var radial := Vector2(cos(finish), sin(finish))
		var tangent := Vector2(-sin(finish), cos(finish))
		var tip := center + radial * r * 0.48
		draw_polyline(PackedVector2Array([tip - tangent * 2.2 * s + radial * 1.6 * s, tip, tip - tangent * 2.2 * s - radial * 1.6 * s]), _color(0xffffe989), 1.15 * s, true)

func _update_dim() -> void:
	if not is_instance_valid(_dim): return
	var active := bool(_frame.get("rewardTargeting", false)) and is_instance_valid(_camera) and is_instance_valid(_world)
	_dim.visible = active
	material = _clip_material if active else null
	if not active:
		_clear_mask()
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
	_mask_viewport.size = Vector2i(maxi(2, roundi(viewport_size.x)), maxi(2, roundi(viewport_size.y)))
	_mask_viewport.msaa_3d = get_viewport().msaa_3d
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	var alive: Dictionary = {}
	for data in _frame.get("rewardTargets", []):
		var target := _target_model(_position(data))
		if is_instance_valid(target): _sync_mask_meshes(target, alive)
	for id in _mask_meshes.keys():
		if alive.has(id): continue
		_mask_meshes[id].free()
		_mask_meshes.erase(id)

func _target_model(p: Vector2) -> Node3D:
	for entry in _turrets.values():
		var model: Node3D = entry.get("root")
		if not is_instance_valid(model): continue
		var local := _world.to_local(model.global_position)
		if Vector2(local.x + _map_size.x / 2, local.z + _map_size.y / 2).distance_to(p) < 0.1:
			return model
	return null

func _sync_mask_meshes(source: Node3D, alive: Dictionary) -> void:
	if not source.is_visible_in_tree(): return
	if source is MeshInstance3D and source.mesh != null:
		var id := source.get_instance_id()
		alive[id] = true
		if not _mask_meshes.has(id):
			var clone := MeshInstance3D.new()
			clone.material_override = _mask_material
			clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			clone.layers = 1
			_mask_root.add_child(clone)
			_mask_meshes[id] = clone
		var clone: MeshInstance3D = _mask_meshes[id]
		clone.mesh = source.mesh
		clone.global_transform = source.global_transform
	for child in source.get_children():
		if child is Node3D: _sync_mask_meshes(child, alive)

func _clear_mask() -> void:
	if not is_instance_valid(_mask_viewport): return
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mask_viewport.size = Vector2i(2, 2)
	for clone: MeshInstance3D in _mask_meshes.values(): clone.free()
	_mask_meshes.clear()
