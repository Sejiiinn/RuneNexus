extends RefCounted
## Achievement dialog (docs/stage_difficulty_design.md#도전과제) with 「스테이지 |
## 누적 | 훈장」 tabs. The stage tab has a chapter switch, normal/hard collection
## progress and every stage's challenge with its normal and hard reward chips. A
## gold chip is claimable; a claimed one fades with a check. Diamonds and tickets
## are claimed from the server, core points and medals locally. The cumulative
## tab shows each lifetime count with its next tier reward (diamonds from the
## server, the fifth tier's medal locally). The medal tab shows the collection
## and cumulative medals and the owned medals' stat totals.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
const Cumulative = preload("res://content/cumulative_achievements.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const StageProgression = preload("res://content/stage_progression.gd")
const Stages = preload("res://ui/lobby_stages.gd")
const TEAL := Color("5cf9e9")
const GOLD := Color("e7c66a")
const MUTED := Color("7f97a5")
const WHITE := Color("e8f8ff")
const SECONDARY := Color("b9d6e4")
const HARD_RED := Color("ff7a52")
## Claimable rows, sockets and cells glow warm gold over the steel frame.
const CLAIM_TINT := Color(1.35, 1.08, 0.55)
const TABS := [["stage", "스테이지"], ["cumulative", "누적"], ["medal", "훈장"]]

static var _shine_texture: GradientTexture2D
var lobby
var chapter := 0
var tab := "stage"
var notice := ""
var pending := ""

func setup(owner) -> void:
	lobby = owner

func open() -> void:
	if chapter <= 0: chapter = clampi(lobby.stages.chapter, 1, Stages.CHAPTERS.size())
	notice = ""
	var body: VBoxContainer = lobby.open_modal("업적")
	lobby.modal.set_meta("challenge_dialog", true)
	lobby.modal.set_meta("max_width", 430)
	render(body)

## Rebuilds the open dialog, keeping its scroll position.
func refresh() -> void:
	if not is_instance_valid(lobby.modal) or not lobby.modal.get_meta("challenge_dialog", false): return
	var body: VBoxContainer = lobby.refresh_modal_body(lobby.modal)
	if body != null: render(body)

func render(body: VBoxContainer) -> void:
	body.add_theme_constant_override("separation", 8)
	var p: Dictionary = lobby.progression()
	_tabs(body)
	if tab == "medal": _medals(body, p)
	elif tab == "cumulative": _cumulative(body, p)
	else: _stages(body, p)
	if not notice.is_empty():
		var note := _label(body, notice, 11, Color("ffb4a2"))
		note.name = "ChallengeNotice"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _tabs(body: VBoxContainer) -> void:
	var track := PanelContainer.new(); track.name = "ChallengeTabs"
	var frame := Frame.new("ui/components/segmented_control_frame.png", 3)
	frame.source_center = Rect2(8, 8, 122, 27)
	track.add_theme_stylebox_override("panel", frame)
	body.add_child(track)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	track.add_child(row)
	for spec in TABS:
		var on: bool = tab == spec[0]
		var button := Button.new()
		button.name = "ChallengeTab_" + spec[0]
		button.text = spec[1]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", T.font(800))
		button.add_theme_font_size_override("font_size", 13)
		var selected := Frame.new("ui/components/segment_selected_gold.png", 4)
		selected.source_center = Rect2(6, 6, 52, 20)
		for look in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(look, selected if on else StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color("f3e2a6") if on else Color("6f8796"))
		button.add_theme_color_override("font_hover_color", Color("f3e2a6") if on else SECONDARY)
		var target: String = spec[0]
		button.pressed.connect(func():
			if tab == target: return
			tab = target
			notice = ""
			refresh())
		row.add_child(button)

func _stages(body: VBoxContainer, p: Dictionary) -> void:
	var keys: Array = lobby.challenge_claim_keys()
	_chapter_row(body)
	for difficulty in ["normal", "hard"]:
		var hard: bool = difficulty == "hard"
		var stat: Array = StageChallenges.MEDAL_STATS.get(StageChallenges.medal_id(chapter, difficulty), [])
		_collection(body, "하드 컬렉션" if hard else "노말 컬렉션", StageChallenges.chapter_count(p, chapter, difficulty), HARD_RED if hard else TEAL, StageChallenges.stat_text(stat[0], stat[1]) if not stat.is_empty() else "")
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	body.add_child(heading)
	_label(heading, "   스테이지 조건", 11, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for spec in [["노말", TEAL], ["하드", HARD_RED]]:
		var head := _label(heading, spec[0], 11, spec[1])
		head.custom_minimum_size.x = 64
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 4
	heading.add_child(spacer)
	for id in StageProgression.ids_for_chapter(chapter):
		_stage_row(body, int(id), p, keys)

## Medal shelf: collection medals (normal row, hard row, chapters as columns)
## then cumulative medals. Ready medals are gold and claimed by a tap.
func _medals(body: VBoxContainer, p: Dictionary) -> void:
	var summary := HBoxContainer.new()
	body.add_child(summary)
	_label(summary, "  보유 훈장", 11, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(summary, "%d / %d  " % [StageChallenges.medal_total(p), StageChallenges.MEDAL_STATS.size() + Cumulative.ORDER.size()], 12, WHITE).name = "MedalOwnedCount"
	var collection := _medal_grid(body, "MedalGrid")
	for difficulty in ["normal", "hard"]:
		for chapter_number in range(1, 4):
			var id := StageChallenges.medal_id(chapter_number, difficulty)
			var owned := StageChallenges.medal_owned(p, id)
			var progress := "%d / %d" % [StageChallenges.chapter_count(p, chapter_number, difficulty), StageProgression.ids_for_chapter(chapter_number).size()]
			_medal(collection, "Medal_%d" % id, "challenge_medals/medal_ch%d_%s.png" % [chapter_number, difficulty],
				"챕터 %d %s" % [chapter_number, "하드" if difficulty == "hard" else "노말"], StageChallenges.MEDAL_STATS[id],
				owned, StageChallenges.medal_ready(p, id) and not owned, progress, _claim_medal.bind(id))
	_label(body, "  누적 훈장", 11, MUTED).custom_minimum_size.y = 22
	var cumulative := _medal_grid(body, "CumulativeMedalGrid")
	for id in Cumulative.ORDER:
		var owned := Cumulative.medal_owned(p, id)
		var last: int = Cumulative.TIERS[id][Cumulative.MEDAL_TIER - 1]
		_medal(cumulative, "Medal_" + id, "challenge_medals/medal_%s.png" % _snake(id), Cumulative.NAMES[id], Cumulative.MEDAL_STATS[id],
			owned, Cumulative.medal_ready(p, id) and not owned, "%s / %s" % [_compact(mini(Cumulative.count(p, id), last)), _compact(last)], _claim_tier.bind(id, Cumulative.MEDAL_TIER))
	_label(body, "  훈장 능력치", 11, MUTED).custom_minimum_size.y = 22
	var stats := _framed_row(body, 10)
	stats.get_parent().name = "MedalStats"
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	stats.add_child(column)
	var totals: Dictionary = StageChallenges.achievement_stats(p)
	if totals.is_empty():
		_label(column, "받은 훈장이 없습니다", 12, MUTED)
	for stat in StageChallenges.STAT_NAMES:
		if not totals.has(stat): continue
		var line := HBoxContainer.new()
		column.add_child(line)
		_label(line, StageChallenges.STAT_NAMES[stat], 12, SECONDARY).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(line, "+%s%%" % String.num(float(totals[stat]) * 100.0, 1).trim_suffix(".0"), 12, TEAL)

func _medal_grid(body: VBoxContainer, name: String) -> GridContainer:
	var grid := GridContainer.new(); grid.name = name
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	return grid

func _medal(grid: GridContainer, cell_name: String, texture: String, title_text: String, spec: Array, owned: bool, ready: bool, progress: String, claim: Callable) -> void:
	var cell := Button.new(); cell.name = cell_name
	cell.focus_mode = Control.FOCUS_NONE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size.y = 132
	var style: StyleBox
	if ready:
		var gold := Frame.new("ui/components/segment_selected_gold.png", 4)
		gold.source_center = Rect2(6, 6, 52, 20)
		style = gold
	else:
		style = Frame.new("ui/components/row_frame.png", 6)
	for look in ["normal", "hover", "pressed", "disabled", "focus"]: cell.add_theme_stylebox_override(look, style)
	cell.disabled = not ready or not pending.is_empty()
	cell.pressed.connect(claim)
	grid.add_child(cell)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 4; column.offset_right = -4
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	cell.add_child(column)
	var icon := TextureRect.new()
	icon.texture = T.texture(texture)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unearned medals stay a dim silhouette of the same art.
	if not owned and not ready: icon.modulate = Color(0.24, 0.29, 0.34, 0.9)
	column.add_child(icon)
	var title := _label(column, title_text, 11, WHITE if owned or ready else MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat := _label(column, StageChallenges.stat_text(spec[0], spec[1]), 10, SECONDARY if owned else MUTED)
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ready:
		var mark := _claim_mark(column)
		mark.name = "MedalState"
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_shine(cell)
		return
	var state_label := _label(column, "보유" if owned else progress, 11, TEAL if owned else MUTED)
	state_label.name = "MedalState"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _claim_medal(id: int) -> void:
	notice = ""
	if not lobby.app.apply_growth_command({"kind":"claimCollectionMedal", "medalId":id}):
		notice = "훈장을 받지 못했습니다. 잠시 후 다시 시도해 주세요."
	refresh()

## Lifetime counts, each with its next unreceived tier reward.
func _cumulative(body: VBoxContainer, p: Dictionary) -> void:
	var keys: Array = lobby.challenge_claim_keys()
	var summary := HBoxContainer.new()
	body.add_child(summary)
	var count: Array = StageChallenges.achievement_count(p)
	_label(summary, "  달성 업적", 11, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(summary, "%d / %d  " % [count[0], count[1]], 12, WHITE).name = "AchievementCount"
	for id in Cumulative.ORDER:
		_cumulative_row(body, p, keys, id)

func _cumulative_row(body: VBoxContainer, p: Dictionary, keys: Array, id: String) -> void:
	var row := _framed_row(body, 8)
	row.get_parent().name = "Cumulative_" + id
	var socket_frame := Frame.new("quests/ui/icon_socket.png", 4)
	var socket := PanelContainer.new()
	socket.add_theme_stylebox_override("panel", socket_frame)
	socket.custom_minimum_size = Vector2(40, 40)
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(socket)
	var icon := TextureRect.new()
	icon.texture = T.texture(Cumulative.ICONS[id])
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	socket.add_child(icon)
	var thresholds: Array = Cumulative.TIERS[id]
	var value := Cumulative.count(p, id)
	var reached := Cumulative.reached(p, id)
	var tier := Cumulative.next_tier(p, keys, id)
	var complete := tier == 0
	var claimable := not complete and tier <= reached
	if claimable:
		_highlight(row)
		socket_frame.modulate_color = CLAIM_TINT
	var target: int = thresholds[(tier if not complete else Cumulative.MEDAL_TIER) - 1]
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 4)
	row.add_child(middle)
	var top := HBoxContainer.new()
	middle.add_child(top)
	_label(top, Cumulative.NAMES[id], 13, WHITE).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(top, "%d단계 / %d" % [reached, Cumulative.MEDAL_TIER], 10, GOLD if reached == Cumulative.MEDAL_TIER else MUTED).name = "CumulativeTier"
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	middle.add_child(bottom)
	var progress := _label(bottom, "%s / %s%s" % [HudNumber.exact_integer(mini(value, target)), HudNumber.exact_integer(target), Cumulative.UNITS.get(id, "")], 11, SECONDARY)
	progress.name = "CumulativeProgress"
	var track := ColorRect.new()
	track.color = Color("1c2c3a")
	track.custom_minimum_size = Vector2(0, 6)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(track)
	var fill := ColorRect.new()
	fill.color = GOLD if claimable or complete else TEAL
	track.add_child(fill)
	var ratio := clampf(float(value) / float(target), 0.0, 1.0)
	track.resized.connect(func(): fill.size = Vector2(track.size.x * ratio, 6))
	_tier_chip(row, id, tier, "done" if complete else "claim" if claimable else "open")

## The next tier's reward: diamonds, or the medal at tier 5.
func _tier_chip(row: HBoxContainer, id: String, tier: int, state: String) -> void:
	var medal := state == "done" or tier == Cumulative.MEDAL_TIER
	var icon := "challenge_medals/medal_%s.png" % _snake(id) if medal else "res://assets/ui/diamond_currency.png"
	var plate := _reward_plate(row, "CumulativeClaim_" + id, 72, state, icon, 20 if medal else 14, "훈장" if medal else HudNumber.exact_integer(Cumulative.DIAMONDS[tier - 1]), TEAL)
	if state == "claim": plate.pressed.connect(_claim_tier.bind(id, tier))

## A reward plate of the stage and cumulative tabs. A claimable plate is gold,
## adds a 「받기」 tag under the amount and a passing light sweep; an earned
## but received one fades back with a check; an unearned one keeps a lit plate.
func _reward_plate(row: HBoxContainer, plate_name: String, width: int, state: String, icon_path: String, icon_size: int, amount: String, check_color: Color) -> Button:
	var plate := Button.new()
	plate.name = plate_name
	plate.focus_mode = Control.FOCUS_NONE
	plate.custom_minimum_size = Vector2(width, 46 if state == "claim" else 36)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: Frame
	if state == "claim":
		style = Frame.new("ui/components/segment_selected_gold.png", 4)
	else:
		style = Frame.new("ui/components/segment_selected_neutral.png", 4)
		style.modulate_color = Color(0.3, 0.36, 0.4, 0.35) if state == "done" else Color(0.55, 0.66, 0.74, 0.75)
	style.source_center = Rect2(6, 6, 52, 20)
	for look in ["normal", "hover", "pressed", "disabled", "focus"]: plate.add_theme_stylebox_override(look, style)
	plate.disabled = state != "claim" or not pending.is_empty()
	row.add_child(plate)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	plate.add_child(column)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 3)
	column.add_child(inner)
	if state == "done": _label(inner, "✓", 11, check_color)
	var faded := HBoxContainer.new()
	faded.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faded.add_theme_constant_override("separation", 3)
	faded.modulate = Color(1, 1, 1, 0.38) if state == "done" else Color.WHITE
	inner.add_child(faded)
	var icon := TextureRect.new()
	icon.texture = T.texture(icon_path)
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faded.add_child(icon)
	_label(faded, amount, 12, Color("fff1c4") if state == "claim" else WHITE)
	if state == "claim":
		_claim_mark(column).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_shine(plate)
	return plate

## The 「받기」 tag of claimable plates and medal cells.
func _claim_mark(parent: Node) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.name = "ClaimMark"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f3d27a")
	fill.set_corner_radius_all(3)
	fill.content_margin_left = 8; fill.content_margin_right = 8
	tag.add_theme_stylebox_override("panel", fill)
	parent.add_child(tag)
	_label(tag, "받기", 10, Color("2b1d02")).add_theme_font_override("font", T.font(800))
	return tag

## A slanted light band crossing the claimable control every few seconds.
func _shine(target: Control) -> void:
	target.clip_contents = true
	if _shine_texture == null:
		_shine_texture = GradientTexture2D.new()
		_shine_texture.width = 32
		_shine_texture.height = 32
		_shine_texture.fill_from = Vector2(0, 0.5)
		_shine_texture.fill_to = Vector2(1, 0.5)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color(1, 0.95, 0.75, 0), Color(1, 0.95, 0.75, 0.55), Color(1, 0.95, 0.75, 0)])
		_shine_texture.gradient = gradient
	var band := TextureRect.new()
	band.name = "ClaimShine"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.texture = _shine_texture
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	band.material = additive
	band.position.x = -4096
	target.add_child(band)
	# The band leans about 20 degrees and outgrows the control, so tall medal
	# cells and short plates both show one slanted streak.
	band.rotation = deg_to_rad(20)
	var sweep := func(t: float):
		var width := clampf(target.size.y * 0.6, 18.0, 36.0)
		band.size = Vector2(width, target.size.y * 1.4)
		band.pivot_offset = band.size * 0.5
		var reach := target.size.y * 0.3 + width
		band.position = Vector2(lerpf(-reach, target.size.x + reach - width, t), -target.size.y * 0.2)
	var tween := band.create_tween().set_loops()
	tween.tween_method(sweep, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1.6)

## Warm gold row frame for a row with a claimable reward.
func _highlight(row: HBoxContainer) -> void:
	var frame: StyleBox = row.get_parent().get_theme_stylebox("panel")
	if frame is StyleBoxTexture: frame.modulate_color = CLAIM_TINT

func _claim_tier(id: String, tier: int) -> void:
	if not pending.is_empty(): return
	notice = ""
	if tier == Cumulative.MEDAL_TIER:
		if not lobby.app.apply_growth_command({"kind":"claimCumulativeMedal", "achievementId":id}):
			notice = "훈장을 받지 못했습니다. 잠시 후 다시 시도해 주세요."
		refresh()
		return
	var service = lobby.app.get("services")
	if service == null or not service.connected():
		lobby.open_service("계정 및 저장")
		return
	pending = Cumulative.reward_key(id, tier)
	refresh()
	var result: Dictionary = await service.perform("claim_achievement", {"achievementId":id, "tier":tier})
	pending = ""
	if lobby.app.get("services") != service: return
	if not result.get("ok", false): notice = "보상을 받지 못했습니다. 계정 및 저장에서 동기화 상태를 확인해 주세요."
	refresh()

## "killBosses" → "kill_bosses" (medal art file names).
static func _snake(id: String) -> String:
	return id.to_snake_case()

## Short counts on medal cells: 1,200 and 200K.
static func _compact(value: int) -> String:
	return HudNumber.exact_integer(value) if value < 10000 else HudNumber.compact_integer(value)

func _chapter_row(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "ChallengeChapter"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	var count: int = Stages.CHAPTERS.size()
	for spec in [["‹", -1, "ChallengePrevChapter"], ["", 0, ""], ["›", 1, "ChallengeNextChapter"]]:
		if int(spec[1]) == 0:
			var title := _label(row, "챕터 %d · %s" % [chapter, Stages.CHAPTERS[chapter - 1]], 14, WHITE)
			title.name = "ChallengeChapterTitle"
			title.custom_minimum_size.x = 170
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			continue
		var target := chapter + int(spec[1])
		var arrow := Button.new()
		arrow.name = spec[2]
		arrow.text = spec[0]
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.custom_minimum_size = Vector2(36, 36)
		arrow.disabled = target < 1 or target > count
		arrow.add_theme_font_size_override("font_size", 20)
		arrow.add_theme_color_override("font_color", SECONDARY)
		arrow.add_theme_color_override("font_disabled_color", Color(MUTED, 0.3))
		arrow.pressed.connect(func():
			chapter = target
			notice = ""
			refresh())
		row.add_child(arrow)

func _collection(body: VBoxContainer, title: String, done: int, color: Color, reward: String) -> void:
	var row := _framed_row(body, 10)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	row.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	_label(top, title, 12, color).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(top, "%d / 10" % done, 11, SECONDARY)
	var track := ColorRect.new()
	track.color = Color("1c2c3a")
	track.custom_minimum_size = Vector2(0, 6)
	left.add_child(track)
	var fill := ColorRect.new()
	fill.color = color
	track.add_child(fill)
	track.resized.connect(func(): fill.size = Vector2(track.size.x * done / 10.0, 6))
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 118
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	row.add_child(right)
	_label(right, "완성 보상", 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(right, reward, 12, WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _stage_row(body: VBoxContainer, id: int, p: Dictionary, keys: Array) -> void:
	var row := _framed_row(body, 6)
	row.get_parent().name = "ChallengeRow%d" % id
	var number := _label(row, StageProgression.stage_label(id), 13, WHITE)
	number.custom_minimum_size.x = 34
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 1)
	row.add_child(words)
	var lines: Array = StageChallenges.lines(id)
	_label(words, lines[0], 12, WHITE).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label(words, lines[1], 10, MUTED).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for difficulty in ["normal", "hard"]:
		var state := "open"
		if StageChallenges.achieved(p, id, difficulty):
			state = "done" if StageChallenges.claimed(p, keys, id, difficulty) else "claim"
		if state == "claim": _highlight(row)
		_chip(row, id, difficulty, state)

func _chip(row: HBoxContainer, id: int, difficulty: String, state: String) -> void:
	var reward := StageChallenges.reward(id, difficulty)
	var kind := str(reward.get("kind", ""))
	var path: String = {"diamonds":"res://assets/ui/diamond_currency.png", "tickets":"stage_rewards/reward_module_ticket.png"}.get(kind, "stage_rewards/reward_core.png")
	var amount := int(reward.get("amount", 0))
	var plate := _reward_plate(row, "Challenge_%d_%s" % [id, difficulty], 64, state, path, 14 if kind == "diamonds" else 18, "%dP" % amount if kind == "corePoints" else str(amount), HARD_RED if difficulty == "hard" else TEAL)
	plate.pressed.connect(_claim.bind(id, difficulty))

func _claim(id: int, difficulty: String) -> void:
	if not pending.is_empty(): return
	notice = ""
	if StageChallenges.reward(id, difficulty).get("kind") == "corePoints":
		if not lobby.app.apply_growth_command({"kind":"claimChallengeCorePoint", "stageNumber":id}):
			notice = "보상을 받지 못했습니다. 잠시 후 다시 시도해 주세요."
		refresh()
		return
	var service = lobby.app.get("services")
	if service == null or not service.connected():
		lobby.open_service("계정 및 저장")
		return
	pending = StageChallenges.reward_key(id, difficulty)
	refresh()
	var result: Dictionary = await service.perform("claim_challenge", {"stageNumber":id, "difficulty":difficulty})
	pending = ""
	if lobby.app.get("services") != service: return
	if not result.get("ok", false): notice = "보상을 받지 못했습니다. 계정 및 저장에서 동기화 상태를 확인해 주세요."
	refresh()

func _framed_row(parent: Node, inset := 8) -> HBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Frame.new("ui/components/row_frame.png", inset))
	parent.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	frame.add_child(row)
	return row

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := T.label(text, size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(label)
	return label
