extends Node2D

## 내구도·상태 보조 표시는 Flutter EnemyRenderer의 크기와 순서를 유지한다.
## 화상과 냉각은 적 본체에 붙는 공통 3D 효과가 담당한다.
var labels := {}
var core: CoreLabel
var tile_size := 48.0
var textures := {}
const MAX_POOLED_LABELS := 128
var _pool: Array[EnemyLabel] = []
var _canvas_enabled := true
var _projection_key: Array = []
var _projection_revision := 0
var _factor := 1.0


func _init() -> void:
	var path := "res://assets/ui/diamond_currency.png"
	if ResourceLoader.exists(path):
		textures["diamond_currency"] = load(path)
	core = CoreLabel.new()
	add_child(core)
	core.visible = false


func supported_groups() -> Array:
	return ["labels"] if textures.has("diamond_currency") else []


func clear() -> void:
	for label: EnemyLabel in labels.values():
		label.free()
	labels.clear()
	for label in _pool: label.free()
	_pool.clear()
	core.set_data({}, tile_size)
	core.visible = false


## Owned snapshots must never be mutated after delivery; external callers retain isolation.
func apply_frame(data: Dictionary, owned_snapshot := false) -> void:
	if not owned_snapshot: data = data.duplicate(true)
	tile_size = maxf(0.01, float(data.get("logicalTileSize", 48.0)))
	var alive := {}
	for entry: Dictionary in data.get("enemies", []):
		var id: int = int(entry["id"])
		alive[id] = true
		if not labels.has(id):
			var label: EnemyLabel = _pool.pop_back() if not _pool.is_empty() else EnemyLabel.new()
			label.textures = textures
			if label.get_parent() == null: add_child(label)
			else: move_child(label, -1)
			labels[id] = label
		var label: EnemyLabel = labels[id]
		label.set_data(entry)
		# Queue content changes in the update phase, before frame_pre_draw projects positions.
		# Already culled labels keep their dirty state until present() makes them visible.
		if _canvas_enabled and is_visible_in_tree() and label.visible:
			label.flush_redraw()
	for id in labels.keys():
		if not alive.has(id):
			var label: EnemyLabel = labels[id]
			labels.erase(id)
			label.reset()
			if _pool.size() < MAX_POOLED_LABELS: _pool.append(label)
			else: label.free()
	var incoming_core = data.get("core")
	core.set_data(incoming_core if incoming_core is Dictionary else {}, tile_size)
	if _canvas_enabled and is_visible_in_tree() and core.visible:
		core.flush_redraw()


func set_canvas_enabled(enabled: bool) -> void:
	_canvas_enabled = enabled


func present(camera: Camera3D, map_size: Vector2, world: Node3D) -> void:
	if not _canvas_enabled or not is_visible_in_tree(): return
	var available := textures.has("diamond_currency")
	if not available: return
	var viewport := camera.get_viewport().get_visible_rect()
	var projection_key := [camera.get_camera_transform(), camera.get_camera_projection(), viewport, world.global_transform, map_size, tile_size]
	if projection_key != _projection_key:
		_projection_key = projection_key
		_projection_revision += 1
		var origin := world.to_global(Vector3.ZERO)
		_factor = camera.unproject_position(world.to_global(Vector3.RIGHT)).distance_to(camera.unproject_position(origin)) / tile_size
	var factor := _factor
	for label: EnemyLabel in labels.values():
		var p: Array = label.data["position"]
		var logical_position := Vector2(float(p[0]), float(p[1]))
		var dimensions: Array = label.data["size"]
		var dimensions_key := Vector2(float(dimensions[0]), float(dimensions[1]))
		if label.projection_revision != _projection_revision or label.logical_position != logical_position or label.projected_size != dimensions_key:
			label.projection_revision = _projection_revision
			label.logical_position = logical_position
			label.projected_size = dimensions_key
			var point := world.to_global(Vector3(logical_position.x - map_size.x / 2.0, 0.3, logical_position.y - map_size.y / 2.0))
			label.visible = not camera.is_position_behind(point)
			if label.visible:
				var screen := camera.unproject_position(point)
				# Includes the bars and the widest animated ring, with conservative padding.
				var margin := (maxf(dimensions_key.x, dimensions_key.y) * 1.5 + 12.0) * factor
				label.visible = viewport.grow(margin).has_point(screen)
				if label.visible:
					label.position = screen
					label.scale = Vector2.ONE * factor
		if not label.visible: continue
		label.flush_redraw()
	if core.data.is_empty():
		core.hide()
		return
	var p: Array = core.data["position"]
	var logical_position := Vector2(float(p[0]), float(p[1]))
	if core.projection_revision != _projection_revision or core.logical_position != logical_position:
		core.projection_revision = _projection_revision
		core.logical_position = logical_position
		var point := world.to_global(Vector3(logical_position.x - map_size.x / 2.0, 0.0, logical_position.y - map_size.y / 2.0))
		core.visible = not camera.is_position_behind(point)
		if core.visible:
			var center := camera.unproject_position(point)
			# Existing cooldown follows the ground-plane tilt.
			var x := (camera.unproject_position(point + world.global_basis.x) - center) / tile_size
			var y := (camera.unproject_position(point + world.global_basis.z) - center) / tile_size
			core.transform = Transform2D(x, y, center)
			# Bound every transformed corner; the padding covers border and outline.
			var extent := tile_size + 16.0
			var screen_bounds := Rect2(center, Vector2.ZERO)
			for corner in [Vector2(-extent,-extent),Vector2(extent,-extent),Vector2(-extent,extent),Vector2(extent,extent)]:
				screen_bounds = screen_bounds.expand(core.transform * corner)
			core.visible = viewport.intersects(screen_bounds, true)
	if core.visible: core.flush_redraw()


class EnemyLabel extends Node2D:
	var data := {}
	var textures := {}

	var projection_revision := -1
	var logical_position := Vector2.ZERO
	var projected_size := Vector2.ZERO
	var dirty := true
	var static_dirty := true
	var rift_dirty := true
	var _bar_key: Array = []
	var _static_key: Array = []
	var _rift_key: Array = []
	var decoration: StaticDecoration
	var rift: RiftDecoration

	func reset() -> void:
		hide()
		projection_revision = -1
		data = {}
		_bar_key.clear(); _static_key.clear(); _rift_key.clear()
		dirty = true; static_dirty = true; rift_dirty = true
		if decoration != null: decoration.hide(); decoration.data = {}
		if rift != null: rift.hide(); rift.data = {}

	func set_data(value: Dictionary) -> void:
		data = value
		var dimensions: Array = data["size"]
		var size := Vector2(float(dimensions[0]), float(dimensions[1]))
		var bar_key := [size, data.get("hp"), data.get("maxHp"), data.get("armor"), data.get("maxArmor"), data.get("shield"), data.get("maxShield")]
		if bar_key != _bar_key: dirty = true; _bar_key = bar_key
		var static_key := [size, data.get("diamondCarrier", false), data.get("poisoned", false)]
		if static_key != _static_key: static_dirty = true; _static_key = static_key
		var marked: bool = data.get("riftMarked", false)
		var rift_key := [size, marked, data.get("effectTime", 0.0) if marked else 0.0]
		if rift_key != _rift_key: rift_dirty = true; _rift_key = rift_key

	func flush_redraw() -> void:
		if dirty: queue_redraw(); dirty = false
		if static_dirty:
			var enabled: bool = data.get("diamondCarrier", false) or data.get("poisoned", false)
			if enabled and decoration == null:
				decoration = StaticDecoration.new()
				decoration.show_behind_parent = true
				decoration.textures = textures
				add_child(decoration)
				move_child(decoration, 0)
			if decoration != null:
				decoration.visible = enabled
				decoration.data = data
				if enabled: decoration.queue_redraw()
			static_dirty = false
		if rift_dirty:
			var enabled: bool = data.get("riftMarked", false)
			if enabled and rift == null:
				rift = RiftDecoration.new()
				rift.show_behind_parent = true
				add_child(rift)
			if rift != null:
				rift.visible = enabled
				rift.data = data
				if enabled: rift.queue_redraw()
			rift_dirty = false

	static func durability_segments(d: Dictionary) -> Vector3:
		var maximum := float(d.get("maxHp", 0.0))
		if float(d.get("maxArmor", 0.0)) > 0.0:
			var total := maxf(1.0, maximum + float(d["maxArmor"]))
			return Vector3(clampf(float(d["hp"]) / total, 0.0, 1.0), clampf(float(d["armor"]) / total, 0.0, 1.0), clampf(float(d.get("shield", 0.0)) / maxf(0.001, float(d.get("maxShield", 0.0))), 0.0, 1.0))
		return Vector3(0.0 if maximum <= 0.0 else clampf(float(d["hp"]) / maximum, 0.0, 1.0), 0.0, clampf(float(d.get("shield", 0.0)) / maxf(0.001, float(d.get("maxShield", 0.0))), 0.0, 1.0))

	func _draw() -> void:
		if data.is_empty():
			return
		var dimensions: Array = data["size"]
		var size := Vector2(float(dimensions[0]), float(dimensions[1]))
		var w := size.x
		draw_set_transform(-size / 2.0)
		var segments := durability_segments(data)
		var bar_width := w - 2.0
		if float(data["maxShield"]) > 0 and float(data["shield"]) > 0:
			draw_rect(Rect2(1, -9, bar_width, 3), Color("102b3a"))
			draw_rect(Rect2(1, -9, bar_width * segments.z, 3), Color("62d9ff"))
		draw_rect(Rect2(1, -5, bar_width, 3), Color("321118"))
		draw_rect(Rect2(1, -5, bar_width * segments.x, 3), Color("ff4e5d"))
		if segments.y > 0:
			draw_rect(Rect2(1 + bar_width * segments.x, -5, bar_width * segments.y, 3), Color("b7bdc8"))


class StaticDecoration extends Node2D:
	var data := {}
	var textures := {}
	func _draw() -> void:
		if data.is_empty(): return
		var dimensions: Array = data["size"]
		var size := Vector2(float(dimensions[0]), float(dimensions[1]))
		var w := size.x
		var center := size / 2.0
		draw_set_transform(-size / 2.0)
		if data.get("diamondCarrier", false) and textures.has("diamond_currency"):
			draw_texture_rect(textures["diamond_currency"], Rect2(Vector2.ZERO, size * 0.32), false)
		if data.get("poisoned", false):
			draw_arc(center, w * 0.5, 0, TAU, 64, Color("9dff4a66"), 2.0, true)

class RiftDecoration extends Node2D:
	var data := {}
	func _draw() -> void:
		if data.is_empty(): return
		var dimensions: Array = data["size"]
		var size := Vector2(float(dimensions[0]), float(dimensions[1]))
		var w := size.x
		var center := size / 2.0
		var t := float(data["effectTime"])
		draw_set_transform(-size / 2.0)
		if data.get("riftMarked", false):
			var phase := fposmod(t * 1.45, 1.0)
			var radius := w * (0.55 + phase * 0.08)
			draw_arc(center, radius, 0, TAU, 64, Color(0.812, 0.655, 1, 0.13), w * 0.16, true)
			var color := Color(207.0 / 255.0, 167.0 / 255.0, 1, 0.58 - phase * 0.2)
			for i in range(4):
				var angle := phase * TAU + i * PI / 2.0
				rounded_arc(center, radius, angle, angle + PI * 0.26, color, w * 0.055)
			for sign_x in [-1, 1]:
				var delta := Vector2(sign_x, 1) * w * 0.16
				draw_line(center - delta, center + delta, color, w * 0.055, true)
				draw_circle(center - delta, w * 0.055 / 2.0, color)
				draw_circle(center + delta, w * 0.055 / 2.0, color)

	func rounded_arc(center: Vector2, radius: float, start: float, end: float, color: Color, width: float) -> void:
		draw_arc(center, radius, start, end, 24, color, width, true)
		draw_circle(center + Vector2.from_angle(start) * radius, width / 2.0, color)
		draw_circle(center + Vector2.from_angle(end) * radius, width / 2.0, color)


class CoreLabel extends Node2D:
	var data := {}
	var projection_revision := -1
	var logical_position := Vector2.ZERO
	var tile_size := 48.0
	var dirty := true
	var _draw_key: Array = []
	var _style_key: Array = []
	var border := StyleBoxFlat.new()
	var background := StyleBoxFlat.new()
	var outline := StyleBoxFlat.new()

	func set_data(value: Dictionary, tile: float) -> void:
		if data.is_empty() or value.is_empty(): projection_revision = -1
		data = value
		tile_size = tile
		var key := [tile, value.get("progress"), value.get("accent"), value.get("active", false)]
		if key != _draw_key: dirty = true; _draw_key = key
		if value.is_empty(): return
		var style_key := [tile, value["accent"]]
		if style_key != _style_key:
			_style_key = style_key
			var height := maxf(4.0, tile_size * 0.11)
			var encoded := int(data["accent"])
			var accent := Color(float((encoded >> 16) & 255) / 255.0, float((encoded >> 8) & 255) / 255.0, float(encoded & 255) / 255.0)
			border.bg_color = Color("02070dee")
			border.set_corner_radius_all(ceili(height / 2.0 + 1.8))
			background.bg_color = Color("102434aa")
			background.set_corner_radius_all(ceili(height / 2.0))
			outline.draw_center = false
			outline.border_color = Color(accent, 0.68)
			outline.set_border_width_all(1)
			outline.set_corner_radius_all(ceili(height / 2.0))

	func flush_redraw() -> void:
		if dirty: queue_redraw(); dirty = false

	func _draw() -> void:
		if data.is_empty():
			return
		var width := tile_size * 0.86
		var height := maxf(4.0, tile_size * 0.11)
		var rect := Rect2(-width / 2.0, tile_size * 0.56, width, height)
		var encoded := int(data["accent"])
		var accent := Color(float((encoded >> 16) & 255) / 255.0, float((encoded >> 8) & 255) / 255.0, float(encoded & 255) / 255.0)
		draw_style_box(border, rect.grow(1.8))
		draw_style_box(background, rect)
		var fill_width := clampf(float(data["progress"]), 0, 1) * width
		if fill_width > 0:
			var left := accent.lerp(Color("02070d"), 0.35)
			var right := accent.lerp(Color.WHITE, 0.55 if data.get("active", false) else 0.0)
			# 둥근 채움의 테두리와 선형 색 변화를 논리 픽셀 단위로 유지.
			var count := maxi(2, ceili(fill_width * 2.0))
			var radius := minf(height / 2.0, fill_width / 2.0)
			for i in range(count):
				var x := fill_width * (i + 0.5) / count
				var inset := 0.0
				var edge := minf(x, fill_width - x)
				if edge < radius:
					inset = radius - sqrt(maxf(0, radius * radius - pow(radius - edge, 2)))
				draw_rect(Rect2(rect.position + Vector2(x - fill_width / count / 2.0, inset), Vector2(fill_width / count + 0.01, height - inset * 2)), left.lerp(right, x / width))
		draw_style_box(outline, rect)
