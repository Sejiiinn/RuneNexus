extends Control
## Selected-stage card on the stage home. The number socket names the stage; the
## middle column shows round progress and the rune reward; the right column shows
## first-clear unlocks over the start/continue action. Tapping an unlock icon opens a
## small bubble with its name and where it appears.
const T = preload("res://ui/app_theme.gd")
const Numbers = preload("res://ui/hud_number.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const Progression = preload("res://content/stage_progression.gd")
const Stages = preload("res://ui/lobby_stages.gd")
const HEIGHT := 96.0
const TEAL := Color("5cf9e9")
const GOLD := Color("e7c66a")
const WHITE := Color("e8f8ff")
const MUTED := Color("7f93a1")
const SECONDARY := Color("b9d6e4")
const BUTTON_WIDTH := 150.0
const TILE := 32.0
const TILE_STEP := 36.0

class Check extends Control:
	func _draw() -> void:
		draw_circle(size / 2, size.x / 2, Color("0e5f5a"))
		draw_polyline(PackedVector2Array([size * Vector2(0.27,0.52), size * Vector2(0.44,0.68), size * Vector2(0.74,0.34)]), Color("68fff0"), 2, true)

class Lock extends Control:
	func _draw() -> void:
		var c := Color("7f93a1")
		draw_arc(Vector2(size.x / 2, size.y * 0.42), size.x * 0.3, PI, TAU, 16, c, 2, true)
		draw_rect(Rect2(0, size.y * 0.42, size.x, size.y * 0.58), c)

var stages
var font_size: Callable = func(px: int) -> int: return px
var stage := 0
var tooltip := -1
var _catcher: Control

func _ready() -> void:
	name = "StageCard"
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	# A tap on the card itself, outside its buttons, also closes the bubble.
	if tooltip >= 0 and event is InputEventMouseButton and event.pressed:
		tooltip = -1
		_rebuild.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(_catcher): _catcher.queue_free()

func show_stage(id: int) -> void:
	if id != stage: tooltip = -1
	stage = id
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if stage <= 0: return
	var w := size.x
	var active: bool = stages.active(stage)
	var open: bool = active or stages.unlocked(stage)
	var cleared: bool = stages.cleared(stage)
	_framed("stage_details/ui/dialog_frame.png", Rect2(0, 0, w, HEIGHT), Rect2(14, 14, 240, 224))
	var socket := _image("stage_map/stage_number_socket.png", Rect2(10, 12, 64, 72))
	socket.name = "NumberSocket"
	if not open: socket.modulate = Color(0.6, 0.6, 0.6)
	var number := _label(Progression.stage_label(stage), 19, GOLD if open else MUTED, 900)
	number.name = "StageNumber"
	_place(number, Rect2(10, 12, 64, 72))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Middle column: the round bar stops short of the action button beneath the icons.
	var col_x := 86.0
	# Narrow screens give the action a little less room so the reward still fits.
	var button_w := clampf(w * 0.38, 120.0, BUTTON_WIDTH)
	var button_x := w - 14 - button_w
	var bar_w := maxf(40.0, button_x - 12 - col_x)
	var waves: int = stages.lobby.app.catalog.wave_count(stage - 1)
	var done: int = int(stages._state().get("roundIndex", 0)) if active else (waves if cleared else stages.best_rounds(stage))
	done = clampi(done, 0, waves)
	_place(_label("라운드", 10, MUTED, 700), Rect2(col_x, 12, 60, 14))
	var count := _label("%d / %d" % [done, waves], 11, SECONDARY, 800)
	count.name = "RoundCount"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(count, Rect2(col_x, 11, bar_w, 16))
	var track := ColorRect.new()
	track.name = "RoundTrack"
	track.color = Color("1c2c3a")
	_place(track, Rect2(col_x, 32, bar_w, 6))
	var fill := ColorRect.new()
	fill.name = "RoundFill"
	fill.color = TEAL
	_place(fill, Rect2(col_x, 32, bar_w * done / maxf(1, waves), 6))
	var rune := HBoxContainer.new()
	rune.name = "RuneReward"
	rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rune.add_theme_constant_override("separation", 4)
	_place(rune, Rect2(col_x, 54, button_x - 6 - col_x, 22))
	var icon := _image("ui/hud/icons/rune.png", Rect2(0, 0, 17, 17), rune)
	icon.custom_minimum_size = Vector2(17, 17)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amount := _label(Numbers.compact_integer(stages.rune_reward(stage)), 17, Color("ffcf8a"), 800)
	amount.name = "RuneAmount"
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune.add_child(amount)
	# Right column: first-clear unlocks, dimmed with a check once obtained.
	var unlocks: Array = stages.unlock_items(stage)
	var shown := mini(unlocks.size(), 3)
	var claimed: bool = stages.reward_highlighted(stage)
	for k in shown:
		_unlock_tile(k, unlocks[k], Rect2(w - 14 - TILE_STEP * (shown - k), 10, TILE, TILE), claimed)
	_action(Rect2(button_x, 48, button_w, 34), open, active)
	if tooltip >= 0 and tooltip < shown: _tooltip(unlocks[tooltip], w - 14 - TILE_STEP * (shown - tooltip))
	else: _close_catcher()

func _action(rect: Rect2, open: bool, active: bool) -> void:
	var art := _image("ui/stage_reference/continue_button_idle.png", rect)
	art.stretch_mode = TextureRect.STRETCH_SCALE
	if not open: art.modulate = Color(0.32, 0.38, 0.44)
	var button := Button.new()
	button.name = "ContinueRun" if active else ("StageStart" if open else "StageLocked")
	for state in ["normal", "disabled", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["hover", "pressed"]:
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color(1, 1, 1, 0.08 if state == "hover" else 0.16)
		highlight.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, highlight)
	_place(button, rect)
	var text := ("▶  이어서 진행" if active else "▶  전투 시작") if open else "%s 클리어 필요" % Progression.stage_label(Stages.previous_stage(stage))
	button.tooltip_text = text
	button.disabled = not open or stages.lobby.app.get("startup_blocked") == true
	var id := stage
	button.pressed.connect(func(): stages.start(id))
	var label := _label(text, 14, Color("06141e") if open else MUTED, 900)
	label.remove_theme_constant_override("outline_size")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = rect.size
	if not open:
		# Lock glyph and requirement centred together as one line.
		var lw := minf(T.font(900).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size.call(14))).x, rect.size.x - 26)
		var start := (rect.size.x - lw - 18) / 2
		label.position.x = start + 18
		label.size.x = lw + 2
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var lock := Lock.new()
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.position = Vector2(start, (rect.size.y - 16) / 2)
		lock.size = Vector2(14, 16)
		button.add_child(lock)
	button.add_child(label)

func _unlock_tile(index: int, item: Array, rect: Rect2, claimed: bool) -> void:
	var tile := Button.new()
	tile.name = "Unlock%d" % index
	tile.tooltip_text = str(item[0])
	for state in ["normal", "hover", "pressed", "disabled", "focus"]: tile.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_place(tile, rect)
	var frame := _framed("quests/ui/icon_socket.png", Rect2(Vector2.ZERO, rect.size), Rect2(), 4.0, tile)
	if claimed: frame.modulate = Color(0.6, 0.6, 0.6)
	var icon := _image(Stages.unlock_icon(item), Rect2(Vector2(4, 4), rect.size - Vector2(8, 8)), tile)
	icon.modulate = Color(1, 1, 1, 0.35) if claimed else Color.WHITE
	if claimed:
		var check := Check.new()
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.position = rect.size - Vector2(12, 12)
		check.size = Vector2(14, 14)
		tile.add_child(check)
	tile.pressed.connect(func():
		tooltip = -1 if tooltip == index else index
		_rebuild.call_deferred())

func _tooltip(item: Array, icon_x: float) -> void:
	var dest := Stages.unlock_destination(item)
	var name_px := int(font_size.call(13))
	var dest_px := int(font_size.call(10))
	var name_w := T.font(800).get_string_size(str(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
	var bubble_w := minf(maxf(name_w, T.font(700).get_string_size(dest, HORIZONTAL_ALIGNMENT_LEFT, -1, dest_px).x) + 52, size.x - 4)
	var bubble_h := maxf(44.0, name_px + dest_px + 20)
	var bx := clampf(icon_x + TILE / 2 - bubble_w / 2, 2, size.x - 2 - bubble_w)
	var bubble := Panel.new()
	bubble.name = "UnlockTooltip"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1620f5")
	box.border_color = Color(GOLD, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	bubble.add_theme_stylebox_override("panel", box)
	_place(bubble, Rect2(bx, -6 - bubble_h, bubble_w, bubble_h))
	var arrow := Polygon2D.new()
	arrow.color = Color(GOLD, 0.7)
	arrow.polygon = PackedVector2Array([Vector2(icon_x + 10, -7), Vector2(icon_x + 22, -7), Vector2(icon_x + 16, 1)])
	add_child(arrow)
	_image(Stages.unlock_icon(item), Rect2(9, (bubble_h - 26) / 2, 26, 26), bubble)
	var title := _label(str(item[0]), 13, WHITE, 800)
	title.name = "TooltipName"
	title.position = Vector2(42, 3)
	title.size = Vector2(bubble_w - 46, name_px + 6)
	bubble.add_child(title)
	var where := _label(dest, 10, GOLD, 700)
	where.name = "TooltipDestination"
	where.position = Vector2(42, bubble_h - dest_px - 10)
	where.size = Vector2(bubble_w - 46, dest_px + 4)
	bubble.add_child(where)
	# Pressed look on the tapped icon.
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = Color(GOLD, 0.95)
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(6)
	ring.add_theme_stylebox_override("panel", rs)
	_place(ring, Rect2(icon_x - 1, 9, TILE + 2, TILE + 2))
	_open_catcher()

## A tap anywhere outside the card closes the bubble; the card itself stays above it.
func _open_catcher() -> void:
	if is_instance_valid(_catcher) or get_parent() == null: return
	_catcher = Control.new()
	_catcher.name = "TooltipCatcher"
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			tooltip = -1
			_rebuild.call_deferred())
	get_parent().add_child(_catcher)
	get_parent().move_child(_catcher, get_index())

func _close_catcher() -> void:
	if is_instance_valid(_catcher):
		_catcher.queue_free()
		_catcher = null

func _place(c: Control, rect: Rect2, parent: Control = null) -> Control:
	(parent if parent else self).add_child(c)
	c.position = rect.position
	c.size = rect.size
	return c

func _image(path: String, rect: Rect2, parent: Control = null) -> TextureRect:
	var t := TextureRect.new()
	t.texture = T.texture(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(t, rect, parent)
	return t

func _framed(path: String, rect: Rect2, center := Rect2(), scale := 4.0, parent: Control = null) -> Panel:
	## Existing UI frame art, drawn the way the lobby draws it (master pixels shrunk).
	var box := Frame.new(path, 0)
	if center.size != Vector2.ZERO:
		box.source_scale = scale
		box.source_center = center
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", box)
	_place(panel, rect, parent)
	return panel

func _label(value: String, px: int, color: Color, weight := 800) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font", T.font(weight))
	l.add_theme_font_size_override("font_size", int(font_size.call(px)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color("03080ce6"))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
