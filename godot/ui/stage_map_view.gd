extends Control
## Chapter map on the stage home: painted background with ambience, one socket per
## stage on the walkway platforms, unlock badges and the path to the selected stage.
## The background and its effects persist across selection changes; only the node
## layer is rebuilt. Taps select stages, vertical drags scroll a map that does not fit.
signal stage_pressed(id: int)
const T = preload("res://ui/app_theme.gd")
const Numbers = preload("res://ui/hud_number.gd")
const Progression = preload("res://content/stage_progression.gd")
const Effects = preload("res://ui/stage_map_effects.gd")
const Stages = preload("res://ui/lobby_stages.gd")
const StageCard = preload("res://ui/lobby_stage_card.gd")
const SOURCE := Vector2(853, 1844)
# Platform centres measured on the background art; index 9 is the rune gate.
const SPOTS := {
	1: [Vector2(178,1250), Vector2(435,1120), Vector2(640,975), Vector2(425,840), Vector2(705,712), Vector2(552,605), Vector2(398,510), Vector2(632,432), Vector2(493,352), Vector2(520,215)],
	2: [Vector2(165,1245), Vector2(412,1092), Vector2(598,980), Vector2(437,860), Vector2(707,730), Vector2(570,640), Vector2(378,555), Vector2(598,462), Vector2(450,390), Vector2(490,235)],
	3: [Vector2(160,1355), Vector2(435,1160), Vector2(590,1000), Vector2(420,860), Vector2(680,725), Vector2(545,625), Vector2(375,505), Vector2(620,395), Vector2(490,310), Vector2(510,205)],
}
const GOLD := Color("e7c66a")
const TEAL := Color("68fff0")
# Visible ring centre of node_socket_gold.png, which sits right and below its canvas centre.
const GOLD_SOCKET_CENTRE := Vector2(131, 130.5) / 256.0
const WHITE := Color("e8f8ff")
const MUTED := Color("7f93a1")
const TAP_SLOP := 10.0

var stages
var font_size: Callable = func(px: int) -> int: return px
var chapter := 0
var content: Control
var background: TextureRect
var effects: Control
var nodes: Control
var map_scale := Vector2.ONE
var shift := 0.0
var scroll := 0.0
var max_scroll := 0.0
var _press := Vector2.INF
var _press_scroll := 0.0
var _dragging := false
var _centers := {}

func _ready() -> void:
	name = "StageMap"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _notification(what: int) -> void:
	# Hidden behind battle: stop every looping effect instead of animating off-screen.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_instance_valid(content):
		content.process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED

func map_point(source: Vector2) -> Vector2:
	return source * map_scale + Vector2(0, shift)

## Fits the chapter's path between `gate_y` (under the header) and `base_y` (above the
## stage card). A short screen squeezes the art a little, then scrolls the rest.
func arrange(value: int, gate_y: float, base_y: float) -> void:
	var spots: Array = SPOTS[value]
	var sx := size.x / SOURCE.x
	var span: float = spots[0].y - spots[9].y
	var sy := clampf((base_y - gate_y) / span, sx * 0.85, sx)
	var next_shift: float = gate_y - spots[9].y * sy
	if (base_y - gate_y) / span > sx:
		# Spare height: centre the path, but never open a gap above the painting.
		next_shift = minf((gate_y + base_y - (spots[9].y + spots[0].y) * sy) / 2, 0.0)
	max_scroll = maxf(0.0, spots[0].y * sy + next_shift - base_y)
	var rebuilt := value != chapter or not is_equal_approx(sx, map_scale.x) or not is_equal_approx(sy, map_scale.y) or not is_equal_approx(next_shift, shift)
	chapter = value
	map_scale = Vector2(sx, sy)
	shift = next_shift
	if rebuilt: _build_background()
	_focus_selected(gate_y, base_y)

func _build_background() -> void:
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	content.name = "MapContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = Vector2(size.x, SOURCE.y * map_scale.y + shift)
	add_child(content)
	background = TextureRect.new()
	background.name = "MapBackground"
	background.texture = T.texture("stage_map/chapter%d_map.jpg" % chapter)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.position = Vector2(0, shift)
	background.size = SOURCE * map_scale
	content.add_child(background)
	effects = Control.new()
	effects.name = "MapEffects"
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(effects)
	Effects.build(effects, chapter, map_point, map_scale.x, background.texture, Rect2(background.position, background.size))
	nodes = Control.new()
	nodes.name = "MapNodes"
	nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(nodes)
	_notification(NOTIFICATION_VISIBILITY_CHANGED)

func _focus_selected(gate_y: float, base_y: float) -> void:
	var ids: Array = Progression.ids_for_chapter(chapter)
	var index := ids.find(stages.selected)
	if index >= 0 and max_scroll > 0:
		var y: float = map_point(SPOTS[chapter][index]).y
		set_scroll(y - (gate_y + base_y) / 2)
	else: set_scroll(0.0)

func set_scroll(value: float) -> void:
	scroll = clampf(value, 0.0, max_scroll)
	if is_instance_valid(content): content.position.y = -scroll

## Rebuilds sockets, badges, labels and the trail for the current selection.
func refresh_nodes() -> void:
	if not is_instance_valid(nodes): return
	for child in nodes.get_children():
		nodes.remove_child(child)
		child.queue_free()
	_centers.clear()
	var animated := Effects.animations_enabled()
	var ids: Array = Progression.ids_for_chapter(chapter)
	var selected_index := ids.find(stages.selected)
	if selected_index > 0:
		var trail := Effects.Trail.new()
		trail.name = "SelectionTrail"
		trail.animated = animated
		for i in selected_index + 1: trail.points.append(map_point(SPOTS[chapter][i]))
		trail.size = content.size
		nodes.add_child(trail)
	var k := map_scale.x / (420.0 / 853.0)
	for i in ids.size():
		var id: int = ids[i]
		var open: bool = stages.unlocked(id)
		var cleared: bool = stages.cleared(id)
		var state := "selected" if id == stages.selected else ("cleared" if cleared else ("open" if open else "locked"))
		var d := (54.0 if state == "selected" else (48.0 if i == 9 else 44.0)) * clampf(k, 0.85, 1.25)
		var c := map_point(SPOTS[chapter][i])
		_centers[id] = c
		var rect := Rect2(c - Vector2(d, d) / 2, Vector2(d, d))
		var holder := Control.new()
		holder.name = "Stage%s" % Progression.stage_label(id).replace("-", "_")
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_meta("stage_id", id)
		holder.set_meta("state", state)
		nodes.add_child(holder)
		holder.position = rect.position
		holder.size = rect.size
		if state == "selected" and animated:
			var halo := Effects.Halo.new()
			halo.size = rect.size
			holder.add_child(halo)
		var socket := _texture(holder, "stage_map/node_socket_gold.png" if state == "selected" else ("ui/components/gem_socket_selected.png" if state == "cleared" else "ui/components/gem_socket_empty.png"), Rect2(Vector2.ZERO, rect.size))
		if state == "locked": socket.modulate = Color(0.55, 0.55, 0.6)
		# Centre the gold ring, not its canvas, on the stage number.
		if state == "selected": socket.position -= (GOLD_SOCKET_CENTRE - Vector2(0.5, 0.5)) * d
		var number := _label(Progression.stage_label(id), 13 if state == "selected" else 11, GOLD if state == "selected" else (WHITE if open else MUTED))
		number.name = "Number"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.size = rect.size
		holder.add_child(number)
		# One badge per first-clear unlock; obtained ones stay with a teal check.
		var claimed: bool = stages.reward_highlighted(id)
		var unlocks: Array = stages.unlock_items(id)
		for b in mini(unlocks.size(), 3):
			# The gate node sits under the header wallet, so its badges go left.
			var at := c + (Vector2(-d / 2 - 18 - b * 21, -d / 2 - 6) if i == 9 else Vector2(d / 2 - 6 + b * 21, -d / 2 - 6))
			var badge := _badge(unlocks[b], Rect2(at, Vector2(22, 22)), open, animated, claimed)
			badge.name = "UnlockBadge%d_%d" % [id, b]
			badge.set_meta("claimed", claimed)
		if open and state != "selected":
			_rune_amount(nodes, id, Rect2(c.x - 30, c.y + d / 2 - 1, 60, 14), 10)

func _texture(parent: Control, path: String, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = T.texture(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = rect.position
	t.size = rect.size
	parent.add_child(t)
	return t

func _label(value: String, px: int, color: Color, weight := 900) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font", T.font(weight))
	l.add_theme_font_size_override("font_size", int(font_size.call(px)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color("03080ce6"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _badge(item: Array, rect: Rect2, bright: bool, animated: bool, claimed: bool) -> Panel:
	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1620f0")
	box.border_color = Color(TEAL, 0.75) if claimed else Color(GOLD, 0.8 if bright else 0.3)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", box)
	badge.position = rect.position
	badge.size = rect.size
	nodes.add_child(badge)
	var icon := _texture(badge, Stages.unlock_icon(item), Rect2(Vector2(3, 3), rect.size - Vector2(6, 6)))
	icon.modulate = Color.WHITE if bright else Color(1, 1, 1, 0.45)
	if claimed:
		var check := StageCard.Check.new()
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.position = rect.size - Vector2(8, 8)
		check.size = Vector2(11, 11)
		check.z_index = 1  # above the next badge, which overlaps this one's corner
		badge.add_child(check)
	elif bright and animated:
		var shimmer := Effects.Shimmer.new()
		shimmer.target = icon
		shimmer.delay = randf() * 4.0
		icon.add_child(shimmer)
	return badge

func _rune_amount(parent: Control, id: int, rect: Rect2, px: int) -> void:
	var row := HBoxContainer.new()
	row.name = "RuneReward"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.position = rect.position
	row.size = rect.size
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.texture = T.texture("ui/hud/icons/rune.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(px, px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(_label(Numbers.compact_integer(stages.rune_reward(id)), px, Color("ffcf8a"), 800))

## Nearest stage socket within reach of a tap, in map-view coordinates.
func stage_at(point: Vector2) -> int:
	var best := 0
	var reach := 34.0 * maxf(1.0, map_scale.x / (420.0 / 853.0))
	for id in _centers:
		var distance: float = (_centers[id] - Vector2(0, scroll)).distance_to(point)
		if distance < reach:
			reach = distance
			best = id
	return best

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			set_scroll(scroll + (-40.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press = event.position
				_press_scroll = scroll
				_dragging = false
			elif _press != Vector2.INF:
				if not _dragging:
					var id := stage_at(event.position)
					if id > 0: stage_pressed.emit(id)
				_press = Vector2.INF
			accept_event()
	elif event is InputEventMouseMotion and _press != Vector2.INF:
		if not _dragging and event.position.distance_to(_press) > TAP_SLOP: _dragging = true
		if _dragging: set_scroll(_press_scroll - (event.position.y - _press.y))
		accept_event()
