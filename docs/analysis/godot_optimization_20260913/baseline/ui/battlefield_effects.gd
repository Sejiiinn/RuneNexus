extends Node2D

## Presentation-only: every effect uses the authoritative simulation age.
## Repeated snapshots replace state; no timer, restart, or damage callback here.
const WEIGHT_AXIS := 0x77676874 # OpenType wght tag; string keys are ignored.
var items: Array = []
var camera: Camera3D
var map_size := Vector2.ZERO
var world: Node3D
var _origin := Vector2.ZERO
var _basis := Transform2D.IDENTITY
var _font: Font
var _diamond: Texture2D
var _silhouettes: Texture2D
var _surface: Node2D
var _effect_nodes := {}
var _additive := CanvasItemMaterial.new()


class EffectSurface extends Node2D:
	var owner_effects: Node2D
	var effect := {}
	var mix_pass := false
	var mix_surface: EffectSurface

	func _draw() -> void:
		if owner_effects != null:
			owner_effects._draw_effect(effect, self, mix_pass)


func _ready() -> void:
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var base_font = load("res://assets/ui/Roboto-VF.ttf")
	var korean_font = load("res://assets/ui/NotoSansKR-VF.ttf")
	if base_font is Font and korean_font is Font:
		var korean_variation := FontVariation.new()
		korean_variation.base_font = korean_font
		korean_variation.variation_opentype = {WEIGHT_AXIS: 900.0}
		base_font.fallbacks = [korean_variation]
		var variation := FontVariation.new()
		variation.base_font = base_font
		variation.variation_opentype = {WEIGHT_AXIS: 900.0}
		_font = variation
	_diamond = load("res://assets/ui/diamond_currency.png")
	_silhouettes = load("res://assets/ui/death_silhouettes.png")

func supported_groups() -> Array:
	return ["effects"] if _font != null and _diamond != null and _silhouettes != null else []

func apply_frame(frame: Dictionary) -> void:
	items = frame.get("items", []).duplicate(true)
	var alive := {}
	for index in range(items.size()):
		var effect: Dictionary = items[index]
		var id: int = int(effect.get("id", index))
		alive[id] = true
		if not _effect_nodes.has(id):
			var node := EffectSurface.new()
			node.owner_effects = self
			add_child(node)
			_effect_nodes[id] = node
		var node: EffectSurface = _effect_nodes[id]
		node.effect = effect
		move_child(node, index)
		var gem: bool = effect.get("kind") == "gem"
		node.material = _additive if gem else null
		if gem:
			if node.mix_surface == null:
				node.mix_surface = EffectSurface.new()
				node.mix_surface.owner_effects = self
				node.mix_surface.mix_pass = true
				node.add_child(node.mix_surface)
			node.mix_surface.effect = effect
			node.mix_surface.queue_redraw()
		elif node.mix_surface != null:
			node.mix_surface.free()
			node.mix_surface = null
		node.queue_redraw()
	for id in _effect_nodes.keys():
		if not alive.has(id):
			_effect_nodes[id].free()
			_effect_nodes.erase(id)

func clear() -> void:
	items.clear()
	for node: EffectSurface in _effect_nodes.values():
		node.free()
	_effect_nodes.clear()

func present(active_camera: Camera3D, size: Vector2, active_world: Node3D) -> void:
	camera = active_camera
	map_size = size
	world = active_world
	for node: EffectSurface in _effect_nodes.values():
		node.queue_redraw()
		if node.mix_surface != null:
			node.mix_surface.queue_redraw()

func _project(tile: Vector2, height := 0.0) -> Vector2:
	return camera.unproject_position(world.to_global(Vector3(tile.x - map_size.x / 2.0, height, tile.y - map_size.y / 2.0)))

func _color(value: int, alpha := 1.0) -> Color:
	return Color(float((value >> 16) & 255) / 255.0, float((value >> 8) & 255) / 255.0, float(value & 255) / 255.0, alpha)

func _polar(angle: float, radius: float) -> Vector2:
	return Vector2(cos(angle), sin(angle)) * radius

# cap: 0 butt, 1 round, 2 square, matching the original Paint call.
func _line(a: Vector2, b: Vector2, color: Color, width: float, cap := 1) -> void:
	if cap == 2 and not a.is_equal_approx(b):
		var extension := (b - a).normalized() * width / 2.0
		_surface.draw_line(a - extension, b + extension, color, width, true)
	else:
		_surface.draw_line(a, b, color, width, true)
		if cap == 1:
			_circle(a, width / 2.0, color)
			_circle(b, width / 2.0, color)

func _round_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	_surface.draw_polyline(points, color, width, true)
	for point in points:
		_circle(point, width / 2.0, color)

func _ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	_surface.draw_arc(center, maxf(radius, 0.001), 0, TAU, 64, color, width, true)

func _circle(center: Vector2, radius: float, color: Color) -> void:
	_surface.draw_circle(center, maxf(radius, 0.001), color, true, -1, true)

func _oval(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		points.append(center + _polar(i * TAU / 48, 1) * size / 2)
	_surface.draw_colored_polygon(points, color)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0, 1))

## The glyphs face the screen; their moving anchors still use the source
## component's logical board coordinates, as _renderBattlefieldLabels does.
func effect_transform(effect: Dictionary) -> Transform2D:
	var tile := Vector2(float(effect.get("x", 0)), float(effect.get("y", 0)))
	var origin := _project(tile)
	var source_tile := maxf(0.001, float(effect.get("tileSize", 48)))
	var bx := (_project(tile + Vector2.RIGHT) - origin) / source_tile
	var by := (_project(tile + Vector2.DOWN) - origin) / source_tile
	if effect.get("kind") in ["damage", "diamond"]:
		var offset: Array = effect.get("screenOffset", [0, 0])
		var anchor := origin + bx * float(offset[0]) + by * float(offset[1])
		return Transform2D(Vector2(bx.length(), 0), Vector2(0, bx.length()), anchor)
	return Transform2D(bx, by, origin)

func _draw_effect(effect: Dictionary, surface: Node2D, mix_pass: bool) -> void:
	if camera == null or world == null:
		return
	var duration := float(effect.get("duration", 0))
	var age := float(effect.get("age", 0))
	if duration <= 0 or age >= duration:
		return
	var tile := Vector2(float(effect.get("x", 0)), float(effect.get("y", 0)))
	var at := world.to_global(Vector3(tile.x - map_size.x / 2, 0.0, tile.y - map_size.y / 2))
	if camera.is_position_behind(at):
		return
	_surface = surface
	_origin = _project(tile)
	_basis = effect_transform(effect)
	_surface.draw_set_transform_matrix(_basis)
	var p := clampf(age / duration, 0, 1)
	var c := _color(int(effect.get("color", 0xffffffff)))
	var scale_factor := float(effect.get("scale", 1))
	match str(effect.get("kind", "")):
		"damage": _damage(effect, p, c)
		"diamond": _reward(effect, p, scale_factor)
		"impact": _impact(effect, p, c)
		"charge": _charge(p, c, scale_factor)
		"chain", "coreBeam": _beam(effect, p, c, scale_factor)
		"rift": _rift(effect, p, c, scale_factor)
		"gem": _gem(p, c, scale_factor, mix_pass)
		"death": _death(effect, p, c)
	_surface.draw_set_transform_matrix(Transform2D.IDENTITY)

func _text(text: String, center: Vector2, size: int, color: Color, shadow: Color, shadow_offset: Vector2) -> void:
	if _font == null:
		return
	var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pos := center + Vector2(-extent.x / 2, (_font.get_ascent(size) - _font.get_descent(size)) / 2)
	_surface.draw_string_outline(_font, pos + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, shadow)
	_surface.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _damage(e: Dictionary, p: float, c: Color) -> void:
	var alpha := 1 - p
	var feedback := str(e.get("feedback", "neutral"))
	var motion_scale := 1.0 - p * 0.48 if e.get("motion") == "fallArc" else 1.0
	var feedback_scale := 1.14 if feedback == "weak" else (0.82 if feedback == "resisted" else 1.0)
	if feedback == "weak":
		c = c.lerp(Color.WHITE, 0.35)
		for i in range(3):
			var angle := -PI * 0.72 + i * PI * 0.72
			_line(_polar(angle, 8 + p * 2), _polar(angle, 13 + p * 4), _color(0xfffff0a6, alpha * 0.72), 1.1)
	elif feedback == "resisted":
		c = c.lerp(_color(0xff7e8b96), 0.72)
	var scale_factor := motion_scale * feedback_scale
	var text_basis := _basis * Transform2D(0, Vector2(scale_factor, scale_factor), 0, Vector2(0, p * 5 if feedback == "resisted" else 0))
	_surface.draw_set_transform_matrix(text_basis)
	_text(str(e.get("text", "")), Vector2.ZERO, 15, _with_alpha(c, alpha), _color(0xff02070d, 0.42 * alpha), Vector2.ONE)
	_surface.draw_set_transform_matrix(_basis)

func _reward(e: Dictionary, p: float, s: float) -> void:
	var appear := clampf(p / 0.16, 0, 1)
	var alpha := 1 - pow(p, 2.4)
	var sc := 0.78 + appear * 0.3 - p * 0.08
	# Soft source glow uses concentric, low-alpha ellipses instead of a hard disk.
	for i in range(7, 0, -1):
		_oval(Vector2(-22, 0) * s, Vector2(40 + i * 2, 30 + i * 2) * s, _color(0xff5ed8ff, 0.28 * appear * alpha / 7))
	if _diamond != null and bool(e.get("hasImage", false)):
		_surface.draw_texture_rect(_diamond, Rect2(Vector2(-34, -16) * s, Vector2.ONE * 30 * s * sc), false, Color(1, 1, 1, alpha))
	for i in range(5):
		var at := Vector2(-20, 0) * s + _polar(i * TAU / 5 - PI / 2, (12 + p * 18) * s)
		_circle(at, (1.7 - p * 0.7) * s, _color(0xffcff4ff, 0.85 * alpha * alpha))
	if _font != null:
		var size := maxi(1, int(round(22 * s)))
		var text := str(e.get("text", ""))
		var extent := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		_text(text, Vector2(-4 * s + extent.x / 2, 0), size, _color(0xffeafbff, alpha), _color(0xff02070d, 0.9 * alpha), Vector2(1, 1.5) * s)

func _charge(p: float, c: Color, s: float) -> void:
	var pulse := sin(p * PI)
	var radius := (3.15 + p * 3.85) * s
	_circle(Vector2.ZERO, radius * 2.4, _with_alpha(c, 0.12 + pulse * 0.16))
	_circle(Vector2.ZERO, radius * 1.35, _color(0xff8cfff3, 0.28 + pulse * 0.3))
	_circle(Vector2.ZERO, radius * 0.58, Color(1, 1, 1, 0.72))
	for i in range(3):
		var angle := p * PI * 5 + i * TAU / 3
		_line(_polar(angle, radius * 0.95), _polar(angle + 0.55, radius * 1.55), _color(0xffbffbff, 0.68), 1.35 * s)

func _local_points(e: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in e.get("points", []):
		result.append(_basis.affine_inverse() * _project(Vector2(float(point[0]), float(point[1]))))
	return result

func _beam(e: Dictionary, p: float, c: Color, s: float) -> void:
	var points := _local_points(e)
	if points.size() < 2:
		return
	var chain: bool = e.get("kind") == "chain"
	var alpha := (1 - p) * (0.95 if chain else 0.92)
	var widths := [8.0, 4.2, 1.45] if chain else [10.0, 4.8, 1.6]
	var colors := [_with_alpha(c, alpha * (0.22 if chain else 0.18)), _color(0xff8cfff3, alpha * 0.52) if chain else _with_alpha(c, alpha * 0.42), Color(1, 1, 1, alpha)]
	for i in range(3):
		_round_polyline(points, colors[i], widths[i] * s)
	for i in range(2):
		var factor := 0.72 if not chain and i == 1 else 1.0
		var at := points[0] if i == 0 else points[-1]
		_circle(at, (6.2 if chain else 6.4) * s * factor, _with_alpha(c, alpha * (0.22 if chain else 0.26) * factor))
		_circle(at, (2.4 if chain else 2.3) * s * factor, Color(1, 1, 1, alpha * 0.9 * factor))

func _rift(e: Dictionary, p: float, c: Color, s: float) -> void:
	var alpha := 1 - p
	var radius := (10 + 24 * p) * s
	_ring(Vector2.ZERO, radius, _with_alpha(c, alpha * 0.12), 8 * s)
	for i in range(4):
		var angle := p * TAU + i * PI / 2
		var ring_color := _with_alpha(c, alpha * 0.7)
		_surface.draw_arc(Vector2.ZERO, radius, angle, angle + PI * 0.34, 16, ring_color, 2.4 * s, true)
		_circle(_polar(angle, radius), 1.2 * s, ring_color)
		_circle(_polar(angle + PI * 0.34, radius), 1.2 * s, ring_color)
	_circle(Vector2.ZERO, (3.4 + 3.2 * alpha) * s, Color(1, 1, 1, alpha * 0.9))
	var link_alpha := alpha * (1 - clampf(p - 0.25, 0, 0.75) / 0.75)
	for at in _local_points(e):
		_line(Vector2.ZERO, at, _with_alpha(c, link_alpha * 0.5), 1.8 * s)
		_line(Vector2.ZERO, at, Color(1, 1, 1, link_alpha * 0.72), 0.8 * s)
		_circle(at, 4.2 * s, _with_alpha(c, link_alpha * 0.32))

func _impact(e: Dictionary, p: float, c: Color) -> void:
	var r := float(e.get("radius", 1))
	var alpha := 1 - p
	match str(e.get("style", "")):
		"spark":
			for i in range(6):
				var angle := i * PI / 3 + p * 0.55
				_line(_polar(angle, r * 0.12), _polar(angle, r * (0.48 + p * 0.34)), _with_alpha(Color.WHITE if i % 2 == 0 else c, alpha * 0.9), 1.4, 2)
			_circle(Vector2.ZERO, r * (0.14 + p * 0.08), Color(1, 1, 1, alpha))
		"flame":
			for i in range(3):
				_oval(Vector2((i - 1) * r * 0.16, -r * p * (0.32 + i * 0.08)), Vector2(r * (0.22 + p * 0.12), r * (0.5 + p * 0.18)), _with_alpha(c, alpha * 0.7))
			_circle(Vector2.ZERO, r * (0.12 + p * 0.1), _color(0xffffd45a, alpha * 0.7))
			for i in range(4):
				var angle := -PI * 0.8 + i * PI * 0.42
				_circle(Vector2(cos(angle) * r * (0.22 + p * 0.38), sin(angle) * r * (0.2 + p * 0.24)), r * 0.035, _color(0xffffd45a, alpha * 0.9))
		"frost":
			_ring(Vector2.ZERO, r * (0.18 + p * 0.82), _with_alpha(c, alpha * 0.72), 2)
			_circle(Vector2.ZERO, r * (0.12 + p * 0.36), _with_alpha(c, alpha * 0.12))
			for i in range(6):
				var angle := i * PI / 3 + p * 0.22
				_line(_polar(angle, r * (0.16 + p * 0.2)), _polar(angle, r * (0.42 + p * 0.28)), _with_alpha(c, alpha * 0.72), 2, 0)
			for i in range(5):
				var at := _polar(i * TAU / 5 + p * 0.35, r * (0.34 + p * 0.38))
				_line(at - Vector2(r * 0.05, 0), at + Vector2(r * 0.05, 0), _color(0xffe8fbff, alpha), 1.3)
				_line(at - Vector2(0, r * 0.05), at + Vector2(0, r * 0.05), _color(0xffe8fbff, alpha), 1.3)
		"lightning":
			_ring(Vector2.ZERO, r * (0.22 + p * 0.62), _with_alpha(c, alpha * 0.66), 2)
			_circle(Vector2.ZERO, r * (0.1 + p * 0.12), Color(1, 1, 1, alpha * 0.8))
			for i in range(5):
				var angle := i * TAU / 5 + p * 0.48
				var bend := _polar(angle + 0.22, r * (0.36 + p * 0.22))
				_line(_polar(angle, r * (0.16 + p * 0.12)), bend, _color(0xff8cfff3, alpha), 1.6)
				_line(bend, _polar(angle - 0.18, r * (0.52 + p * 0.28)), _color(0xff8cfff3, alpha), 1.6)
		"sniperBlast", "lightningBlast":
			_blast(p, c, r, e.get("style") == "lightningBlast")

func _blast(p: float, c: Color, r: float, lightning: bool) -> void:
	var alpha := 1 - p
	var flash := Color.WHITE if lightning else _color(0xfff7fdff)
	var core := _color(0xffcfa7ff if lightning else 0xff7fd8ff)
	var shard := _color(0xff8cfff3 if lightning else 0xff58c7f2)
	var dust := _color(0xff9dddea if lightning else 0xffa9d6e8)
	_ring(Vector2.ZERO, r * (0.24 + p * 0.9), _color(0xffe8fbff, alpha * 0.62), 3.1)
	_ring(Vector2.ZERO, r * (0.38 + p * 0.58), _with_alpha(c, alpha * 0.78), 2.2)
	_circle(Vector2.ZERO, r * (0.22 + p * 0.12), _with_alpha(flash, clampf(1 - p * 1.4, 0, 1)))
	_circle(Vector2.ZERO, r * (0.2 + p * 0.2), _with_alpha(core, alpha * 0.65))
	for i in range(8):
		var angle := i * TAU / 8 + 0.2
		_line(_polar(angle, r * (0.18 + p * 0.18)), _polar(angle, r * (0.42 + p * 0.42)), _with_alpha(flash if i % 2 == 0 else shard, alpha * 0.74), 1.7)
	for i in range(7):
		var at := _polar(i * TAU / 7 + 0.28, r * (0.28 + p * 0.76)) * Vector2(1, 0.72)
		_circle(at, r * (0.08 + p * 0.05), _with_alpha(dust, alpha * 0.38))

func _ease_out(value: float) -> float:
	return 1 - pow(1 - value, 3)

func _gem(p: float, c: Color, s: float, mix_pass := false) -> void:
	var alpha := pow(1 - p, 0.72)
	if mix_pass:
		var radius := (5.6 + 5.4 * sin(p * PI)) * s
		var polygon := PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.84, 0), Vector2(0, radius), Vector2(-radius * 0.84, 0)])
		_surface.draw_colored_polygon(polygon, _with_alpha(c, alpha * 0.88))
		polygon.append(polygon[0])
		_round_polyline(polygon, Color(1, 1, 1, alpha * 0.86), 1.2 * s)
		return
	var seal_alpha := alpha * (1 - clampf(p - 0.54, 0, 0.46) / 0.46)
	var radius := (18 + 24 * _ease_out(clampf(p / 0.62, 0, 1))) * s
	var rotation_angle := -PI / 2 + p * 0.32
	_ring(Vector2.ZERO, radius * 0.92, _with_alpha(c, seal_alpha * 0.15), 8 * s)
	for i in range(6):
		var angle := rotation_angle + i * PI / 3
		_line(_polar(angle, radius), _polar(angle + PI / 3, radius), _with_alpha(c, seal_alpha * 0.72), 1.5 * s)
		var at := _polar(angle, radius * 0.72)
		var tangent := _polar(angle + PI / 2, (3.4 + (1.4 if i % 2 == 0 else 0.0)) * s)
		_line(at - tangent, at + tangent, Color(1, 1, 1, seal_alpha * 0.84), 1.25 * s, 2)
	var spark_alpha := alpha * (1 - clampf(p - 0.32, 0, 0.36) / 0.36)
	var spark_ease := _ease_out(clampf(p / 0.44, 0, 1))
	for i in range(8):
		var angle := i * PI / 4 + 0.18
		_line(_polar(angle, (42 - 18 * spark_ease) * s), _polar(angle, (26 - 10 * spark_ease) * s), _with_alpha(Color.WHITE if i % 2 == 0 else c, spark_alpha * (0.95 if i % 2 == 0 else 0.72)), 1.8 * s)
	var bp := clampf((p - 0.24) / 0.34, 0, 1)
	if bp > 0:
		var ba := alpha * sin(bp * PI)
		var half := (12 + 6 * (1 - _ease_out(bp))) * s
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := Vector2(sx, sy) * half
				_line(corner, corner - Vector2(sx * 8 * s, 0), Color(1, 1, 1, ba * 0.9), 1.8 * s, 2)
				_line(corner, corner - Vector2(0, sy * 8 * s), Color(1, 1, 1, ba * 0.9), 1.8 * s, 2)
		_ring(Vector2.ZERO, half - 4.2 * s, _with_alpha(c, ba * 0.38), 4.4 * s)
	var gem_radius := (5.6 + 5.4 * sin(p * PI)) * s
	_circle(Vector2.ZERO, gem_radius * 1.8, _with_alpha(c, alpha * 0.22))

func _death(e: Dictionary, p: float, c: Color) -> void:
	var r := float(e.get("radius", 1))
	var alpha := pow(1 - p, 0.72)
	var type := str(e.get("enemyType", "normal"))
	var type_index := int(e.get("enemyTypeIndex", 0))
	var boss := type in ["boss", "shieldBoss", "forgeBoss"]
	if _silhouettes != null:
		var extent := r * (1 - p * 0.14) * 1.5
		_surface.draw_texture_rect_region(_silhouettes, Rect2(Vector2(-extent / 2, -extent / 2 - r * p * 0.18), Vector2.ONE * extent), Rect2(type_index * 192, 0, 192, 192), Color(1, 1, 1, alpha * 0.5))
	var count := 18 if boss else int({"tank": 13, "fast": 10, "shielded": 11, "armored": 12}.get(type, 9))
	var drift := r * (0.96 if boss else float({"tank": 0.82, "fast": 0.92, "shielded": 0.78, "armored": 0.76}.get(type, 0.68)))
	var size_factor := 0.3 if boss else float({"tank": 0.28, "fast": 0.2, "shielded": 0.24, "armored": 0.25}.get(type, 0.22))
	for i in range(count):
		var seed := sin((i + 1) * 12.9898 + type_index * 78.233)
		var angle_origin := i * 2.399963229728653
		var angle := angle_origin + seed * 0.45
		var origin := _polar(angle_origin, r) * Vector2(0.2, 0.16)
		var fast_bias := absf(cos(angle)) * 0.32 if type == "fast" else 0.0
		var distance := p * (drift + r * fast_bias)
		var rise := r * p * (0.2 + absf(seed) * 0.28)
		var center := origin + _polar(angle, distance) + Vector2(0, rise * 0.08)
		var pixel_size := r * size_factor * (1 - p * 0.34)
		var extent := Vector2(pixel_size, pixel_size * (0.72 + absf(seed) * 0.42))
		var rounded := StyleBoxFlat.new()
		rounded.bg_color = _with_alpha(c if i % 2 == 0 else _color(0xffe8fbff), alpha * 0.74)
		rounded.set_corner_radius_all(maxi(1, int(pixel_size * 0.18)))
		_surface.draw_set_transform_matrix(_basis * Transform2D(angle + p * (0.6 if seed > 0 else -0.6), center))
		_surface.draw_style_box(rounded, Rect2(-extent / 2, extent))
	_surface.draw_set_transform_matrix(_basis)
