extends Node2D
const RuntimeProfile = preload("res://app/runtime_profile.gd")

## Presentation-only: every effect uses the authoritative simulation age.
## Creation events use the shared component clock; no wall timer or combat callback.
const WEIGHT_AXIS := 0x77676874 # OpenType wght tag; string keys are ignored.
var items: Array = []
# Routed to main's existing 3D Impact pool; never creates a Canvas surface.
var blast_impacts: Array = []
# Local diagnostic only; normal rendering is the default.
var diagnostic_skip := ""
var camera: Camera3D
var map_size := Vector2.ZERO
var world: Node3D
var _basis := Transform2D.IDENTITY
var _font: Font
var _diamond: Texture2D
var _silhouettes: Texture2D
var _surface: Node2D
var _effect_nodes := {}
var _events := {}
var _generation := -1
var _last_event_id := -1
var _event_clock := 0.0
var _event_squared := 0.0
var _additive := CanvasItemMaterial.new()
const MAX_SURFACE_POOL := 64
var _surface_pool: Array = []
var _input_order: Array = []
var _sorted_indices: Array = []
var _projection_context: Array = []
var _canvas_enabled := true
var _materialization_pending := false
var _unit_oval := PackedVector2Array()
var _blast_rays := PackedVector2Array()
var _blast_dust := PackedVector2Array()
var _text_metrics := {}
var _chain_waves := {}


class EffectSurface extends Node2D:
	var owner_effects: Node2D
	var effect := {}
	var mix_pass := false
	var mix_surface: EffectSurface
	var glyph: DamageGlyph
	var draw_key: Array = []
	var death_styles: Array = []
	var death_particles: Array = []
	var death_key: Array = []
	var geometry_basis := Transform2D.IDENTITY
	var ground_basis := Transform2D.IDENTITY
	var projection_key: Array = []
	var in_front := true

	func _draw() -> void:
		if owner_effects != null:
			var tick := RuntimeProfile.begin()
			owner_effects._draw_effect(effect, self, mix_pass)
			RuntimeProfile.finish("effects_draw", tick)


class DamageGlyph extends Node2D:
	var font: Font
	var text := ""
	var ink := Color.WHITE
	var key: Array = []
	var draw_revision := 0

	func configure(value: String, color: Color, source_font: Font) -> void:
		var next_key := [value, color, source_font]
		if key == next_key: return
		key = next_key
		text = value
		ink = color
		font = source_font
		draw_revision += 1
		queue_redraw()

	func _draw() -> void:
		if font == null: return
		var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var at := Vector2(-extent.x / 2, (font.get_ascent(15) - font.get_descent(15)) / 2)
		draw_string_outline(font, at + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 2, Color(2.0/255, 7.0/255, 13.0/255, 0.42))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)


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

func apply_frame(frame: Dictionary, owned_snapshot := false) -> void:
	var generation := int(frame.get("generation", 0))
	if generation < _generation:
		return
	if generation != _generation:
		_events.clear()
		_last_event_id = -1
		_generation = generation
	# Clock only advances with authoritative combat dt. Camera redraws and
	# repeated bridge frames never advance it, including pause/reward/reconnect.
	_event_clock = maxf(_event_clock, float(frame.get("clock", _event_clock)))
	_event_squared = maxf(_event_squared, float(frame.get("squaredSteps", _event_squared)))
	for event in frame.get("events", []):
		var id := int(event.get("id", -1))
		if id <= _last_event_id or event.get("kind") not in ["damage", "diamond", "death", "gem", "impact", "blast", "coreBeam", "rift", "chain", "charge"]:
			continue
		if event.get("kind") == "impact" and event.get("style") not in ["spark", "sniperBlast", "flame", "frost", "lightning", "lightningBlast"]:
			continue
		# IDs increase within a scene, so a bounded journal needs no unbounded
		# tombstones. Retries after expiry or capacity eviction cannot restart.
		_last_event_id = id
		_events[id] = event.duplicate(true)
		if _event_clock - float(event.get("born", 0)) >= float(event.get("duration", 0)):
			_events[id]["deliverySample"] = event.get("kind") != "charge"
		while _events.size() > 256:
			_events.erase(_events.keys()[0])
	# main transfers immutable entries; public callers retain snapshot isolation.
	items = frame.get("items", []).duplicate(not owned_snapshot)
	blast_impacts.clear()
	# One shared logical-position lookup for all links. Visual enemy offsets
	# deliberately never enter this table; missing targets are dead/unmounted.
	var targets := {}
	var targets_loaded := false
	var turret_positions := {}
	var turrets_loaded := false
	for id in _events.keys():
		var event: Dictionary = _events[id]
		var age := maxf(0, _event_clock - float(event["born"]))
		var steps := maxf(0, _event_squared - float(event["bornSquared"]))
		if age >= float(event["duration"]):
			if not bool(event.get("deliverySample", false)):
				_events.erase(id)
				continue
			age = float(event.get("retainedAge", 0))
			steps = float(event.get("retainedSquared", 0))
			event["deliverySample"] = false
		event["age"] = age
		if not targets_loaded and event.get("kind") in ["coreBeam", "chain", "rift"]:
			for target: Array in frame.get("targets", []):
				if target.size() >= 14:
					targets[int(target[0])] = [target[12], target[13]]
			targets_loaded = true
		if event.get("kind") == "charge":
			if not turrets_loaded:
				for turret: Array in frame.get("turrets", []):
					if turret.size() >= 4:
						turret_positions[int(turret[0])] = turret
				turrets_loaded = true
			var owner_id := int(event.get("ownerId", -1))
			if not turret_positions.has(owner_id):
				_events.erase(id)
				continue
			var turret: Array = turret_positions[owner_id]
			var radius := float(event.get("attachmentRadius", 0))
			event["x"] = float(turret[1]) + cos(float(turret[3])) * radius
			event["y"] = float(turret[2]) + sin(float(turret[3])) * radius
		elif event.get("kind") == "coreBeam":
			var ids: Array = event.get("targetIds", [])
			if not ids.is_empty() and targets.has(int(ids[0])):
				event["points"][1] = targets[int(ids[0])]
		elif event.get("kind") == "chain":
			var ids: Array = event.get("targetIds", [-1, -1])
			# Separate endpoints from the generated drawing points so missing
			# targets retain their last logical positions independently.
			if not event.has("endpoints"):
				event["endpoints"] = event["points"].duplicate(true)
			for endpoint in range(2):
				if targets.has(int(ids[endpoint])):
					event["endpoints"][endpoint] = targets[int(ids[endpoint])]
			event["points"] = _chain_points(event)
			event["x"] = event["endpoints"][0][0]
			event["y"] = event["endpoints"][0][1]
		elif event.get("kind") == "rift":
			var points := []
			for target_id in event.get("targetIds", []):
				if targets.has(int(target_id)):
					points.append(targets[int(target_id)])
			event["points"] = points
		if event.get("kind") == "damage":
			var offset := Vector2(0, -34 * age)
			if event.get("motion") == "fallArc":
				offset = Vector2(float(event.get("arcDirection", 1)) * 42 * age,
					-28 * age + 48 / float(event["duration"]) * (age * age + steps))
			event["screenOffset"] = [offset.x, offset.y]
		elif event.get("kind") == "diamond":
			event["screenOffset"] = [0.0, -24.0 * float(event.get("scale", 1.0)) * age]
		if event.get("kind") == "blast":
			blast_impacts.append([id, float(event.get("x", 0)), float(event.get("y", 0)),
				float(event.get("radius", 0)) / maxf(0.001, float(event.get("tileSize", 48))),
				clampf(age / maxf(0.001, float(event["duration"])), 0, 1)])
		else:
			items.append(event)
	# Sorting depends on membership/input order, never age or camera movement.
	var incoming: Array = []
	for index in range(items.size()): incoming.append(int(items[index].get("id", index)))
	if incoming != _input_order:
		_input_order = incoming
		_sorted_indices = range(items.size())
		_sorted_indices.sort_custom(func(a, b): return int(items[a].get("id", 0)) < int(items[b].get("id", 0)))
	var ordered: Array = []
	for index in _sorted_indices: ordered.append(items[index])
	items = ordered
	_materialization_pending = true
	if _can_materialize(): _sync_surfaces()


func set_canvas_enabled(enabled: bool) -> void:
	if _canvas_enabled == enabled: return
	_canvas_enabled = enabled
	_materialization_pending = true
	if _can_materialize(): _sync_surfaces()
	else:
		for id in _effect_nodes.keys(): _release_surface(id)


func _can_materialize() -> bool:
	return _canvas_enabled and is_visible_in_tree()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		_materialization_pending = true
		if _can_materialize(): _sync_surfaces()
		else:
			for id in _effect_nodes.keys(): _release_surface(id)


func _exit_tree() -> void:
	for surface: EffectSurface in _surface_pool: surface.free()
	_surface_pool.clear()


func _release_surface(id: int) -> void:
	var surface: EffectSurface = _effect_nodes[id]
	_effect_nodes.erase(id)
	remove_child(surface)
	surface.effect = {}
	surface.draw_key.clear()
	surface.projection_key.clear()
	surface.death_styles.clear()
	surface.death_particles.clear()
	surface.death_key.clear()
	surface.visible = false
	surface.transform = Transform2D.IDENTITY
	surface.modulate = Color.WHITE
	surface.material = null
	if surface.glyph != null: surface.glyph.hide()
	if surface.mix_surface != null:
		surface.mix_surface.effect = {}
		surface.mix_surface.draw_key.clear()
		surface.mix_surface.hide()
	if _surface_pool.size() < MAX_SURFACE_POOL: _surface_pool.append(surface)
	else: surface.free()


func _canvas_effect(effect: Dictionary) -> bool:
	return effect.get("kind") != "blast" and not (effect.get("kind") == "impact" and effect.get("style") in ["flame", "frost"])


func _sync_surfaces() -> void:
	_materialization_pending = false
	var alive := {}
	for index in range(items.size()):
		if _canvas_effect(items[index]): alive[int(items[index].get("id", index))] = true
	for id in _effect_nodes.keys():
		if not alive.has(id): _release_surface(id)
	var draw_index := 0
	for index in range(items.size()):
		var effect: Dictionary = items[index]
		if not _canvas_effect(effect): continue
		var id := int(effect.get("id", index))
		if not _effect_nodes.has(id):
			var fresh: EffectSurface = _surface_pool.pop_back() if not _surface_pool.is_empty() else EffectSurface.new()
			fresh.owner_effects = self
			add_child(fresh)
			_effect_nodes[id] = fresh
		var node: EffectSurface = _effect_nodes[id]
		node.effect = effect
		if node.get_index() != draw_index: move_child(node, draw_index)
		draw_index += 1
		var gem: bool = effect.get("kind") == "gem"
		var wanted_material: Material = _additive if gem else null
		if node.material != wanted_material: node.material = wanted_material
		if gem:
			if node.mix_surface == null:
				node.mix_surface = EffectSurface.new()
				node.mix_surface.owner_effects = self
				node.mix_surface.mix_pass = true
				node.add_child(node.mix_surface)
			node.mix_surface.effect = effect
		elif node.mix_surface != null: node.mix_surface.hide()
		_update_surface(node)


# Store only draw inputs, copying the tiny mutable point list of linked events.
func _draw_key(effect: Dictionary) -> Array:
	var result: Array = []
	for field in ["kind", "age", "duration", "x", "y", "tileSize", "color", "scale", "radius", "text", "feedback", "motion", "hasImage", "style", "enemyType", "enemyTypeIndex"]:
		result.append(effect.get(field))
	result.append(Vector2(float(effect.get("screenOffset", [0, 0])[0]), float(effect.get("screenOffset", [0, 0])[1])))
	var points := PackedVector2Array()
	for point in effect.get("points", []): points.append(Vector2(float(point[0]), float(point[1])))
	result.append(points)
	result.append(diagnostic_skip)
	return result


func _update_surface(node: EffectSurface, projection_changed := false) -> void:
	var key := _draw_key(node.effect)
	if not projection_changed and node.draw_key == key: return
	var previous_key := node.draw_key
	node.draw_key = key
	var effect := node.effect
	var valid := camera != null and world != null and float(effect.get("duration", 0)) > 0 and float(effect.get("age", 0)) < float(effect.get("duration", 0))
	if valid:
		var projection_key := [effect.get("x", 0), effect.get("y", 0), effect.get("tileSize", 48)]
		if projection_changed or node.projection_key != projection_key:
			node.projection_key = projection_key
			var tile := Vector2(float(effect.get("x", 0)), float(effect.get("y", 0)))
			node.in_front = not camera.is_position_behind(world.to_global(Vector3(tile.x - map_size.x / 2, 0, tile.y - map_size.y / 2)))
			if node.in_front: node.ground_basis = _ground_transform(effect)
		valid = node.in_front
	node.visible = valid
	if not valid: return
	node.geometry_basis = _effect_basis(effect, node.ground_basis)
	if effect.get("kind") == "damage":
		if node.glyph == null:
			node.glyph = DamageGlyph.new()
			node.add_child(node.glyph)
		var p := clampf(float(effect.get("age", 0)) / float(effect["duration"]), 0, 1)
		var feedback := str(effect.get("feedback", "neutral"))
		var ink := _color(int(effect.get("color", 0xffffffff)))
		if feedback == "weak": ink = ink.lerp(Color.WHITE, 0.35)
		elif feedback == "resisted": ink = ink.lerp(_color(0xff7e8b96), 0.72)
		node.glyph.configure(str(effect.get("text", "")), ink, _font)
		var scale_factor := (1.0 - p * 0.48 if effect.get("motion") == "fallArc" else 1.0) * (1.14 if feedback == "weak" else 0.82 if feedback == "resisted" else 1.0)
		node.glyph.transform = node.geometry_basis * Transform2D(0, Vector2.ONE * scale_factor, 0, Vector2(0, p * 5 if feedback == "resisted" else 0))
		node.glyph.modulate = Color(1, 1, 1, 1 - p)
		node.glyph.visible = diagnostic_skip != "damage"
	elif node.glyph != null: node.glyph.hide()
	# Neutral/resisted damage only changes its retained glyph transform/modulate.
	# A transition from a previous kind/weak decoration still clears old commands.
	if effect.get("kind") != "damage" or effect.get("feedback") == "weak" or previous_key.is_empty() or previous_key[0] != "damage" or previous_key[10] == "weak":
		node.queue_redraw()
	if node.mix_surface != null and effect.get("kind") == "gem":
		node.mix_surface.geometry_basis = node.geometry_basis
		node.mix_surface.visible = true
		node.mix_surface.queue_redraw()

func clear() -> void:
	_events.clear()
	_generation = -1
	_last_event_id = -1
	_event_clock = 0.0
	_event_squared = 0.0
	items.clear()
	blast_impacts.clear()
	for node: EffectSurface in _effect_nodes.values():
		node.free()
	_effect_nodes.clear()
	for surface: EffectSurface in _surface_pool: surface.free()
	_surface_pool.clear()
	_input_order.clear()
	_sorted_indices.clear()
	_projection_context.clear()
	_text_metrics.clear()
	_chain_waves.clear()
	_materialization_pending = false

func present(active_camera: Camera3D, size: Vector2, active_world: Node3D) -> void:
	prepare_context(active_camera, size, active_world, false)


# frame/tween의 deferred draw 전에 투영 참조를 바인딩한다.
func prepare_context(active_camera: Camera3D, size: Vector2, active_world: Node3D, redraw := true) -> void:
	camera = active_camera
	map_size = size
	world = active_world
	var context := [camera.get_camera_transform(), camera.get_camera_projection(), camera.get_viewport().get_visible_rect(), world.global_transform, map_size]
	var changed := context != _projection_context
	_projection_context = context
	if not _can_materialize(): return
	# The first visible frame may follow hidden ingestion without materialization.
	if _materialization_pending: _sync_surfaces()
	if changed:
		for node: EffectSurface in _effect_nodes.values(): _update_surface(node, true)

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
	if _unit_oval.is_empty():
		for i in range(48): _unit_oval.append(_polar(i * TAU / 48, 1))
	for unit in _unit_oval: points.append(center + unit * size / 2)
	_surface.draw_colored_polygon(points, color)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0, 1))

## The glyphs face the screen; their moving anchors still use the source
## component's logical board coordinates, as _renderBattlefieldLabels does.
func effect_transform(effect: Dictionary) -> Transform2D:
	return _effect_basis(effect, _ground_transform(effect))


func _ground_transform(effect: Dictionary) -> Transform2D:
	var tile := Vector2(float(effect.get("x", 0)), float(effect.get("y", 0)))
	var origin := _project(tile)
	var source_tile := maxf(0.001, float(effect.get("tileSize", 48)))
	return Transform2D((_project(tile + Vector2.RIGHT) - origin) / source_tile,
		(_project(tile + Vector2.DOWN) - origin) / source_tile, origin)


func _effect_basis(effect: Dictionary, ground: Transform2D) -> Transform2D:
	if effect.get("kind") in ["damage", "diamond"]:
		var offset: Array = effect.get("screenOffset", [0, 0])
		var anchor := ground.origin + ground.x * float(offset[0]) + ground.y * float(offset[1])
		return Transform2D(Vector2(ground.x.length(), 0), Vector2(0, ground.x.length()), anchor)
	return ground

func _draw_effect(effect: Dictionary, surface: Node2D, mix_pass: bool) -> void:
	if diagnostic_skip == "damage" and effect.get("kind") == "damage":
		return
	if diagnostic_skip == "flame" and effect.get("kind") == "impact" and effect.get("style") == "flame":
		return
	if camera == null or world == null:
		return
	var duration := float(effect.get("duration", 0))
	var age := float(effect.get("age", 0))
	if duration <= 0 or age >= duration:
		return
	_surface = surface
	_basis = surface.geometry_basis
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

func _metrics(text: String, size: int) -> Vector2:
	var key := [text, size]
	if not _text_metrics.has(key):
		if _text_metrics.size() >= 256: _text_metrics.erase(_text_metrics.keys()[0])
		_text_metrics[key] = Vector2(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, (_font.get_ascent(size) - _font.get_descent(size)) / 2)
	return _text_metrics[key]


func _text(text: String, center: Vector2, size: int, color: Color, shadow: Color, shadow_offset: Vector2) -> void:
	if _font == null:
		return
	var metric := _metrics(text, size)
	var pos := center + Vector2(-metric.x / 2, metric.y)
	_surface.draw_string_outline(_font, pos + shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, shadow)
	_surface.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _damage(e: Dictionary, p: float, c: Color) -> void:
	var alpha := 1 - p
	var feedback := str(e.get("feedback", "neutral"))
	if feedback == "weak":
		c = c.lerp(Color.WHITE, 0.35)
		for i in range(3):
			var angle := -PI * 0.72 + i * PI * 0.72
			_line(_polar(angle, 8 + p * 2), _polar(angle, 13 + p * 4), _color(0xfffff0a6, alpha * 0.72), 1.1)
	elif feedback == "resisted":
		c = c.lerp(_color(0xff7e8b96), 0.72)

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
		var extent := _metrics(text, size)
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
	var inverse := _basis.affine_inverse()
	for point in e.get("points", []):
		result.append(inverse * _project(Vector2(float(point[0]), float(point[1]))))
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
	if _blast_rays.is_empty():
		for i in range(8): _blast_rays.append(_polar(i * TAU / 8 + 0.2, 1))
		for i in range(7): _blast_dust.append(_polar(i * TAU / 7 + 0.28, 1))
	for i in range(8):
		var direction := _blast_rays[i]
		_line(direction * (r * (0.18 + p * 0.18)), direction * (r * (0.42 + p * 0.42)), _with_alpha(flash if i % 2 == 0 else shard, alpha * 0.74), 1.7)
	for direction in _blast_dust:
		var at := direction * (r * (0.28 + p * 0.76)) * Vector2(1, 0.72)
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
	if seal_alpha > 0: _ring(Vector2.ZERO, radius * 0.92, _with_alpha(c, seal_alpha * 0.15), 8 * s)
	for i in range(6) if seal_alpha > 0 else []:
		var angle: float = rotation_angle + i * PI / 3
		_line(_polar(angle, radius), _polar(angle + PI / 3, radius), _with_alpha(c, seal_alpha * 0.72), 1.5 * s)
		var at := _polar(angle, radius * 0.72)
		var tangent := _polar(angle + PI / 2, (3.4 + (1.4 if i % 2 == 0 else 0.0)) * s)
		_line(at - tangent, at + tangent, Color(1, 1, 1, seal_alpha * 0.84), 1.25 * s, 2)
	var spark_alpha := alpha * (1 - clampf(p - 0.32, 0, 0.36) / 0.36)
	var spark_ease := _ease_out(clampf(p / 0.44, 0, 1))
	for i in range(8) if spark_alpha > 0 else []:
		var angle: float = i * PI / 4 + 0.18
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
	var surface: EffectSurface = _surface
	var particle_key := [type, type_index, count]
	if surface.death_key != particle_key:
		surface.death_key = particle_key
		surface.death_particles.clear()
		for i in range(count):
			var seed := sin((i + 1) * 12.9898 + type_index * 78.233)
			var angle_origin := i * 2.399963229728653
			var angle := angle_origin + seed * 0.45
			surface.death_particles.append([seed, angle, _polar(angle_origin, 1), _polar(angle, 1), absf(cos(angle)) * 0.32 if type == "fast" else 0.0])
	for i in range(count):
		var particle: Array = surface.death_particles[i]
		var seed: float = particle[0]
		var angle: float = particle[1]
		var origin: Vector2 = particle[2] * r * Vector2(0.2, 0.16)
		var fast_bias: float = particle[4]
		var distance := p * (drift + r * fast_bias)
		var rise := r * p * (0.2 + absf(seed) * 0.28)
		var center := origin + Vector2(particle[3]) * distance + Vector2(0, rise * 0.08)
		var pixel_size := r * size_factor * (1 - p * 0.34)
		var extent := Vector2(pixel_size, pixel_size * (0.72 + absf(seed) * 0.42))
		if surface.death_styles.size() <= i: surface.death_styles.append(StyleBoxFlat.new())
		var rounded: StyleBoxFlat = surface.death_styles[i]
		rounded.bg_color = _with_alpha(c if i % 2 == 0 else _color(0xffe8fbff), alpha * 0.74)
		rounded.set_corner_radius_all(maxi(1, int(pixel_size * 0.18)))
		_surface.draw_set_transform_matrix(_basis * Transform2D(angle + p * (0.6 if seed > 0 else -0.6), center))
		_surface.draw_style_box(rounded, Rect2(-extent / 2, extent))
	_surface.draw_set_transform_matrix(_basis)


func _chain_points(event: Dictionary) -> Array:
	var endpoints: Array = event.get("endpoints", event["points"])
	var start := Vector2(float(endpoints[0][0]), float(endpoints[0][1]))
	var end := Vector2(float(endpoints[1][0]), float(endpoints[1][1]))
	var delta := end - start
	var length := delta.length()
	if length <= 0:
		return [endpoints[0], endpoints[1]]
	var normal := Vector2(-delta.y / length, delta.x / length)
	var amplitude := minf(18.0 * float(event.get("scale", 1)) / float(event["tileSize"]), length * 0.16)
	var seed := float(event.get("boltSeed", 0))
	if not _chain_waves.has(seed):
		if _chain_waves.size() >= 256: _chain_waves.erase(_chain_waves.keys()[0])
		var waves: Array = []
		for index in range(1, 5): waves.append(sin(seed + index * 1.7) * 0.5 + 0.5)
		_chain_waves[seed] = waves
	var points := [endpoints[0]]
	for index in range(1, 5):
		var wave: float = _chain_waves[seed][index - 1]
		var point := start + delta * (index / 5.0) + normal * ((wave - 0.5) * amplitude)
		points.append([point.x, point.y])
	points.append(endpoints[1])
	return points
