extends Control
## Selected-stage card on the stage home. The number socket names the stage; the
## middle column shows round progress and the rune reward; the right column shows
## first-clear unlocks over the start/continue action. Tapping an unlock icon opens a
## small bubble with its name and where it appears. Normal|hard tabs sit on the
## card's top-right edge; hard tints the frame and action red and badges the runes.
## The selected difficulty's challenge sits in one line left of the tabs; a tap
## shows its failure rule, family turrets and reward.
const T = preload("res://ui/app_theme.gd")
const Numbers = preload("res://ui/hud_number.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const Progression = preload("res://content/stage_progression.gd")
const Stages = preload("res://ui/lobby_stages.gd")
const StageDifficulty = preload("res://content/stage_difficulty.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
const HEIGHT := 96.0
const TEAL := Color("5cf9e9")
const GOLD := Color("e7c66a")
const WHITE := Color("e8f8ff")
const MUTED := Color("7f93a1")
const SECONDARY := Color("b9d6e4")
const BUTTON_WIDTH := 150.0
const TILE := 32.0
const TILE_STEP := 36.0
const REPEAT_ICON := 22.0
const TAB_WIDTH := 58.0
const TAB_HEIGHT := 24.0
const HARD_RED := Color("ff7a52")
const HARD_TINT := Color(1.0, 0.5, 0.42)

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
## Repeat-reward key ("loot"/"ticket") whose one-line chance bubble is open.
var repeat_tip := ""
## Whether the challenge bubble is open.
var challenge_tip := false
var _catcher: Control

func _ready() -> void:
	name = "StageCard"
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	# A tap on the card itself, outside its buttons, also closes the bubble.
	if (tooltip >= 0 or not repeat_tip.is_empty() or challenge_tip) and event is InputEventMouseButton and event.pressed:
		tooltip = -1
		repeat_tip = ""
		challenge_tip = false
		_rebuild.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(_catcher): _catcher.queue_free()

func show_stage(id: int) -> void:
	if id != stage:
		tooltip = -1
		repeat_tip = ""
		challenge_tip = false
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
	var difficulty: String = stages.card_difficulty(stage)
	var hard := difficulty == StageDifficulty.HARD
	if open: _tabs(w, difficulty, active)
	if open and StageChallenges.has_challenge(stage): _challenge(w, difficulty)
	var card_frame := _framed("stage_details/ui/dialog_frame.png", Rect2(0, 0, w, HEIGHT), Rect2(14, 14, 240, 224))
	card_frame.name = "CardFrame"
	if hard: card_frame.modulate = HARD_TINT
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
	var done: int = int(stages._state().get("roundIndex", 0)) if active else (waves if cleared and not hard else stages.best_rounds(stage, difficulty))
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
	var amount := _label(Numbers.compact_integer(stages.rune_reward(stage, difficulty)), 17, Color("ffcf8a"), 800)
	amount.name = "RuneAmount"
	# Hard sizes the amount to its text so the badge follows it.
	amount.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if hard else Control.SIZE_EXPAND_FILL
	amount.clip_text = not hard
	rune.add_child(amount)
	if hard:
		rune.add_child(_multiplier_badge())
		for spec in stages.hard_repeat_rewards(stage): rune.add_child(_repeat_icon(spec))
	# Right column: first-clear rewards, dimmed with a check once obtained.
	var unlocks: Array = stages.hard_unlock_items(stage) if hard else stages.unlock_items(stage)
	var shown := mini(unlocks.size(), 3)
	var claimed: bool = stages.hard_cleared(stage) if hard else stages.reward_highlighted(stage)
	for k in shown:
		_unlock_tile(k, unlocks[k], Rect2(w - 14 - TILE_STEP * (shown - k), 10, TILE, TILE), claimed)
	_action(Rect2(button_x, 48, button_w, 34), open, active, hard)
	if tooltip >= 0 and tooltip < shown: _tooltip(unlocks[tooltip], w - 14 - TILE_STEP * (shown - tooltip))
	elif repeat_tip.is_empty() and not challenge_tip: _close_catcher()

func _tabs(w: float, difficulty: String, active: bool) -> void:
	var hard_open: bool = stages.hard_open(stage)
	var specs := [[StageDifficulty.NORMAL, "노말", true], [StageDifficulty.HARD, "하드", hard_open]]
	for k in specs.size():
		var mode: String = specs[k][0]
		var selected := mode == difficulty
		var tab := Button.new()
		tab.name = "DifficultyNormal" if mode == StageDifficulty.NORMAL else "DifficultyHard"
		tab.focus_mode = Control.FOCUS_NONE
		# A running run's difficulty is fixed; locked hard explains itself on hover.
		tab.disabled = active or not bool(specs[k][2])
		tab.tooltip_text = "" if specs[k][2] else "노말을 클리어하면 열립니다"
		var red := mode == StageDifficulty.HARD
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = (Color("6b2416f2") if red else Color("0e3a3cf2")) if selected else Color("0b141cdc")
			box.border_color = (HARD_RED if red else GOLD) if selected else Color(MUTED, 0.55)
			box.set_border_width_all(1)
			box.border_width_bottom = 0
			box.corner_radius_top_left = 7
			box.corner_radius_top_right = 7
			if state == "hover" and not selected: box.bg_color = Color("16242ee6")
			tab.add_theme_stylebox_override(state, box)
		_place(tab, Rect2(w - 14 - TAB_WIDTH * (2 - k) - 4 * (1 - k), -TAB_HEIGHT + 1, TAB_WIDTH, TAB_HEIGHT))
		var label := _label(str(specs[k][1]), 12, (Color("ffe1d2") if red else GOLD) if selected else MUTED, 900)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(TAB_WIDTH, TAB_HEIGHT)
		tab.add_child(label)
		if not bool(specs[k][2]):
			# Lock glyph left of the muted name, centred together.
			var lw := T.font(900).get_string_size(str(specs[k][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size.call(12))).x
			var lock := Lock.new()
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock.size = Vector2(9, 11)
			lock.position = Vector2((TAB_WIDTH - lw - 13) / 2, (TAB_HEIGHT - 11) / 2)
			label.position.x = 7
			tab.add_child(lock)
		tab.pressed.connect(func():
			stages.difficulty = mode
			tooltip = -1
			repeat_tip = ""
			challenge_tip = false
			_rebuild.call_deferred())

## Challenge line on the card's top edge, left of the difficulty tabs.
func _challenge(w: float, difficulty: String) -> void:
	var progression: Dictionary = stages.lobby.progression()
	var done := StageChallenges.achieved(progression, stage, difficulty)
	var text_value: String = StageChallenges.lines(stage)[0]
	var text_w := T.font(800).get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size.call(12))).x
	var tabs_x := w - 14 - TAB_WIDTH * 2 - 4
	var strip_w := minf(tabs_x - 6, text_w + 64 + (18 if done else 0))
	var strip := Button.new()
	strip.name = "ChallengeStrip"
	strip.focus_mode = Control.FOCUS_NONE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b141ce6")
	box.border_color = Color(TEAL, 0.5) if done else Color(GOLD, 0.45)
	box.set_border_width_all(1)
	box.border_width_bottom = 0
	box.corner_radius_top_left = 7
	box.corner_radius_top_right = 7
	for state in ["normal", "hover", "pressed", "focus"]: strip.add_theme_stylebox_override(state, box)
	_place(strip, Rect2(0, -TAB_HEIGHT + 1, strip_w, TAB_HEIGHT))
	_image("lobby_challenge_icon.png", Rect2(6, 2, 20, 20), strip)
	var tag := _label("도전", 10, Color(TEAL, 0.9) if done else GOLD, 900)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(tag, Rect2(28, 0, 26, TAB_HEIGHT), strip)
	var text := _label(text_value, 12, Color("9fb3bf") if done else WHITE, 800)
	text.name = "ChallengeText"
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(text, Rect2(55, 0, minf(text_w + 4, strip_w - 55 - (20 if done else 4)), TAB_HEIGHT), strip)
	if done:
		var check := Check.new()
		check.name = "ChallengeCheck"
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(check, Rect2(strip_w - 20, 5, 14, 14), strip)
	strip.pressed.connect(func():
		challenge_tip = not challenge_tip
		tooltip = -1
		repeat_tip = ""
		_rebuild.call_deferred())
	if challenge_tip: _challenge_bubble(difficulty, done)

func _challenge_bubble(difficulty: String, done: bool) -> void:
	var names := {}
	for type in StageChallenges.FAMILIES: names[type] = stages.lobby.display_title(type)
	var words: Array = StageChallenges.lines(stage)
	var lines := [[words[0], 13, WHITE], [words[1], 11, MUTED]]
	var members := StageChallenges.family_members(stage, names)
	if not members.is_empty(): lines.append([members, 11, SECONDARY])
	var bubble_w := 0.0
	for line in lines: bubble_w = maxf(bubble_w, T.font(800).get_string_size(str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size.call(int(line[1])))).x)
	bubble_w = clampf(bubble_w + 28, minf(290.0, size.x - 4), size.x - 4)
	var line_h: float = 19.0 * font_size.call(12) / 12.0
	var bubble_h := 16.0 + lines.size() * line_h + 34
	var bubble := Panel.new()
	bubble.name = "ChallengeTooltip"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 10
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1620f5")
	box.border_color = Color(GOLD, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	bubble.add_theme_stylebox_override("panel", box)
	_place(bubble, Rect2(0, -TAB_HEIGHT - 8 - bubble_h, bubble_w, bubble_h))
	var arrow := Polygon2D.new()
	arrow.color = Color(GOLD, 0.7)
	arrow.polygon = PackedVector2Array([Vector2(34, bubble_h), Vector2(46, bubble_h), Vector2(40, bubble_h + 7)])
	bubble.add_child(arrow)
	var y := 9.0
	for line in lines:
		var label := _label(str(line[0]), int(line[1]), line[2], 800 if int(line[1]) == 13 else 700)
		_place(label, Rect2(13, y, bubble_w - 26, line_h), bubble)
		y += line_h
	var rule := ColorRect.new()
	rule.color = Color(MUTED, 0.3)
	_place(rule, Rect2(13, y + 5, bubble_w - 26, 1), bubble)
	var hard := difficulty == StageDifficulty.HARD
	var head := _label(("하드" if hard else "노말") + " 보상", 11, HARD_RED if hard else TEAL, 900)
	_place(head, Rect2(13, y + 11, 60, 20), bubble)
	var reward := StageChallenges.reward(stage, difficulty)
	var kind := str(reward.get("kind", ""))
	_image({"diamonds":"res://assets/ui/diamond_currency.png", "tickets":"stage_rewards/reward_module_ticket.png"}.get(kind, "stage_rewards/reward_core.png"), Rect2(74, y + 11, 20, 20), bubble)
	var amount_text := str({"diamonds":"%d", "tickets":"%d장"}.get(kind, "코어 포인트 %dP")) % int(reward.get("amount", 0))
	var amount := _label(amount_text, 12, Color("fff1c4"), 900)
	amount.name = "ChallengeReward"
	_place(amount, Rect2(98, y + 11, T.font(900).get_string_size(amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size.call(12))).x + 6, 20), bubble)
	var claimed := StageChallenges.claimed(stages.lobby.progression(), stages.lobby.challenge_claim_keys(), stage, difficulty)
	var note := _label("받음" if done and claimed else "업적 화면에서 받기", 10, MUTED, 700)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(note, Rect2(bubble_w - 150, y + 12, 137, 20), bubble)
	_open_catcher()

## Small socketed icon beside the runes; a tap shows its chance in one line.
func _repeat_icon(spec: Array) -> Control:
	var key: String = spec[0]
	var button := Button.new()
	button.name = "HardRepeat_" + key
	button.tooltip_text = str(spec[2])
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(REPEAT_ICON, REPEAT_ICON)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var frame := _framed("quests/ui/icon_socket.png", Rect2(Vector2.ZERO, Vector2(REPEAT_ICON, REPEAT_ICON)), Rect2(), 4.0, button)
	if repeat_tip == key: frame.modulate = Color(1.3, 1.15, 0.9)
	_image(str(spec[1]), Rect2(Vector2(3, 3), Vector2(REPEAT_ICON - 6, REPEAT_ICON - 6)), button)
	button.pressed.connect(func():
		repeat_tip = "" if repeat_tip == key else key
		tooltip = -1
		challenge_tip = false
		_rebuild.call_deferred())
	if repeat_tip == key: _repeat_bubble(button, str(spec[2]))
	return button

func _repeat_bubble(anchor: Control, value: String) -> void:
	var px := int(font_size.call(12))
	var bubble_w := T.font(800).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 24
	var bubble_h := float(px) + 16
	var bubble := Panel.new()
	bubble.name = "RepeatTooltip"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 10
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1620f5")
	box.border_color = Color(GOLD, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	bubble.add_theme_stylebox_override("panel", box)
	_place(bubble, Rect2(REPEAT_ICON / 2 - bubble_w / 2, -8 - bubble_h, bubble_w, bubble_h), anchor)
	var arrow := Polygon2D.new()
	arrow.color = Color(GOLD, 0.7)
	arrow.polygon = PackedVector2Array([Vector2(bubble_w / 2 - 6, bubble_h), Vector2(bubble_w / 2 + 6, bubble_h), Vector2(bubble_w / 2, bubble_h + 7)])
	bubble.add_child(arrow)
	var label := _label(value, 12, WHITE, 800)
	label.name = "RepeatTooltipText"
	label.clip_text = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(label, Rect2(Vector2.ZERO, Vector2(bubble_w, bubble_h)), bubble)
	_open_catcher()

func _multiplier_badge() -> Control:
	var badge := PanelContainer.new()
	badge.name = "HardMultiplier"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color("5a1d12e6")
	box.border_color = HARD_RED
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", box)
	var text := _label("×%s" % str(StageDifficulty.RUNE_MULTIPLIER), 11, Color("ffd2c0"), 900)
	text.clip_text = false
	badge.add_child(text)
	return badge

func _action(rect: Rect2, open: bool, active: bool, hard := false) -> void:
	var art := _image("results/ui/confirm_button_danger_frame.png" if hard and open else "ui/stage_reference/continue_button_idle.png", rect)
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
	var label := _label(text, 14, (Color("fff0db") if hard else Color("06141e")) if open else MUTED, 900)
	if not hard: label.remove_theme_constant_override("outline_size")
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
		repeat_tip = ""
		challenge_tip = false
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
			repeat_tip = ""
			challenge_tip = false
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
