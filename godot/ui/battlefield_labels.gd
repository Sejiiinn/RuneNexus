extends Node2D

## Flutter EnemyRenderer showBody:false의 크기·순서·자산을 유지한다.
var labels := {}
var core: CoreLabel
var tile_size := 48.0
var textures := {}
const ASSET_ROOT := "res://assets/ui/labels/"


func _init() -> void:
	for name in ["burn_ember", "burn_glow", "burn_smoke", "slow_shard", "diamond_currency"]:
		var path: String = ASSET_ROOT + name + ".png"
		if ResourceLoader.exists(path):
			textures[name] = load(path)
	core = CoreLabel.new()
	add_child(core)
	core.visible = false


func supported_groups() -> Array:
	return ["labels"] if textures.size() == 5 else []


func clear() -> void:
	for label: EnemyLabel in labels.values():
		label.free()
	labels.clear()
	core.data = {}
	core.visible = false


func apply_frame(data: Dictionary) -> void:
	tile_size = maxf(0.01, float(data.get("logicalTileSize", 48.0)))
	var alive := {}
	for entry: Dictionary in data.get("enemies", []):
		var id: int = int(entry["id"])
		alive[id] = true
		if not labels.has(id):
			var label := EnemyLabel.new()
			label.textures = textures
			add_child(label)
			labels[id] = label
		labels[id].data = entry.duplicate(true)
		labels[id].queue_redraw()
	for id in labels.keys():
		if not alive.has(id):
			labels[id].free()
			labels.erase(id)
	var incoming_core = data.get("core")
	core.data = incoming_core.duplicate(true) if incoming_core is Dictionary else {}
	core.tile_size = tile_size
	core.queue_redraw()


func present(camera: Camera3D, map_size: Vector2, world: Node3D) -> void:
	var origin := world.to_global(Vector3.ZERO)
	var pixels := camera.unproject_position(world.to_global(Vector3.RIGHT)).distance_to(camera.unproject_position(origin))
	var factor := pixels / tile_size
	var available := not supported_groups().is_empty()
	for label: EnemyLabel in labels.values():
		var p: Array = label.data["position"]
		var point := world.to_global(Vector3(float(p[0]) - map_size.x / 2.0, 0.3, float(p[1]) - map_size.y / 2.0))
		label.visible = not camera.is_position_behind(point) and available
		label.position = camera.unproject_position(point)
		label.scale = Vector2.ONE * factor
	core.visible = not core.data.is_empty() and available
	if core.visible:
		var p: Array = core.data["position"]
		var point := world.to_global(Vector3(float(p[0]) - map_size.x / 2.0, 0.0, float(p[1]) - map_size.y / 2.0))
		core.visible = not camera.is_position_behind(point)
		var center := camera.unproject_position(point)
		# 기존 쿨다운은 지면 Canvas transform 안에 있으므로 그 기울기도 보존.
		var x := (camera.unproject_position(point + world.global_basis.x) - center) / tile_size
		var y := (camera.unproject_position(point + world.global_basis.z) - center) / tile_size
		core.transform = Transform2D(x, y, center)


class EnemyLabel extends Node2D:
	var data := {}
	var textures := {}

	static func durability_segments(d: Dictionary) -> Vector3:
		var maximum := float(d.get("maxHp", 0.0))
		if float(d.get("maxArmor", 0.0)) > 0.0:
			var total := maxf(1.0, maximum + float(d["maxArmor"]))
			return Vector3(clampf(float(d["hp"]) / total, 0.0, 1.0), clampf(float(d["armor"]) / total, 0.0, 1.0), clampf(float(d.get("shield", 0.0)) / maxf(0.001, float(d.get("maxShield", 0.0))), 0.0, 1.0))
		return Vector3(0.0 if maximum <= 0.0 else clampf(float(d["hp"]) / maximum, 0.0, 1.0), 0.0, clampf(float(d.get("shield", 0.0)) / maxf(0.001, float(d.get("maxShield", 0.0))), 0.0, 1.0))

	func sprite(name: String, center: Vector2, radius: float, alpha := 1.0) -> void:
		if textures.has(name):
			draw_texture_rect(textures[name], Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(1, 1, 1, alpha))

	func _draw() -> void:
		if data.is_empty():
			return
		var dimensions: Array = data["size"]
		var size := Vector2(float(dimensions[0]), float(dimensions[1]))
		var w := size.x
		var t := float(data["effectTime"])
		var crowded := int(data["enemyCount"]) >= 60
		# 기존 renderer의 top-left 좌표계를 화면 정면 중심으로 옮긴다.
		draw_set_transform(-size / 2.0)
		var center := size / 2.0
		if data.get("diamondCarrier", false) and textures.has("diamond_currency"):
			draw_texture_rect(textures["diamond_currency"], Rect2(Vector2.ZERO, size * 0.32), false)
		if data.get("burning", false):
			var offsets := [Vector2(-0.31, -0.25), Vector2(-0.11, -0.34), Vector2(0.13, -0.31), Vector2(0.32, -0.19)]
			for i in range(2 if crowded else 4):
				var phase := fposmod(t * 3.4 + i * 0.31, 1.0)
				var ember: Vector2 = center + offsets[i] * size - Vector2(0, phase * size.y * 0.34)
				var radius := w * (0.045 + (1.0 - phase) * 0.035)
				sprite("burn_glow", ember, radius * 2.2)
				sprite("burn_ember", ember, radius)
				if i % 2 == 0:
					sprite("burn_smoke", ember + Vector2(w * 0.04, -size.y * 0.1), radius * 1.5, 0.22 * phase)
		if data.get("poisoned", false):
			draw_arc(center, w * 0.5, 0, TAU, 64, Color("9dff4a66"), 2.0, true)
		if data.get("slowed", false):
			for i in range(2 if crowded else 3):
				var angle := t * 0.9 + i * TAU / 3.0
				rounded_arc(center, w * 0.48, angle, angle + PI * 0.34, Color("bfefffcc"), w * 0.077)
			var offsets := [Vector2(0.34, 0), Vector2(0, 0.34), Vector2(-0.34, 0), Vector2(0, -0.34)]
			for i in range(2 if crowded else 4):
				sprite("slow_shard", center + offsets[i] * size, w * 0.075 / 0.34)
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
		var segments := durability_segments(data)
		var bar_width := w - 2.0
		if float(data["maxShield"]) > 0 and float(data["shield"]) > 0:
			draw_rect(Rect2(1, -9, bar_width, 3), Color("102b3a"))
			draw_rect(Rect2(1, -9, bar_width * segments.z, 3), Color("62d9ff"))
		draw_rect(Rect2(1, -5, bar_width, 3), Color("321118"))
		draw_rect(Rect2(1, -5, bar_width * segments.x, 3), Color("ff4e5d"))
		if segments.y > 0:
			draw_rect(Rect2(1 + bar_width * segments.x, -5, bar_width * segments.y, 3), Color("b7bdc8"))

	func rounded_arc(center: Vector2, radius: float, start: float, end: float, color: Color, width: float) -> void:
		draw_arc(center, radius, start, end, 24, color, width, true)
		draw_circle(center + Vector2.from_angle(start) * radius, width / 2.0, color)
		draw_circle(center + Vector2.from_angle(end) * radius, width / 2.0, color)


class CoreLabel extends Node2D:
	var data := {}
	var tile_size := 48.0

	func _draw() -> void:
		if data.is_empty():
			return
		var width := tile_size * 0.86
		var height := maxf(4.0, tile_size * 0.11)
		var rect := Rect2(-width / 2.0, tile_size * 0.56, width, height)
		var encoded := int(data["accent"])
		var accent := Color(float((encoded >> 16) & 255) / 255.0, float((encoded >> 8) & 255) / 255.0, float(encoded & 255) / 255.0)
		var border := StyleBoxFlat.new()
		border.bg_color = Color("02070dee")
		border.set_corner_radius_all(ceili(height / 2.0 + 1.8))
		draw_style_box(border, rect.grow(1.8))
		var background := StyleBoxFlat.new()
		background.bg_color = Color("102434aa")
		background.set_corner_radius_all(ceili(height / 2.0))
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
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = Color(accent, 0.68)
		outline.set_border_width_all(1)
		outline.set_corner_radius_all(ceili(height / 2.0))
		draw_style_box(outline, rect)
