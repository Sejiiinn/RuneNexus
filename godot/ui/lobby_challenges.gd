extends RefCounted
## Achievement dialog (docs/stage_difficulty_design.md#도전과제): chapter switch,
## normal/hard collection progress and every stage's challenge with its normal
## and hard reward chips. A gold chip is claimable; a claimed one fades with a
## check. Diamonds and tickets are claimed from the server, core points locally.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
const StageProgression = preload("res://content/stage_progression.gd")
const Stages = preload("res://ui/lobby_stages.gd")
const TEAL := Color("5cf9e9")
const GOLD := Color("e7c66a")
const MUTED := Color("7f97a5")
const WHITE := Color("e8f8ff")
const SECONDARY := Color("b9d6e4")
const HARD_RED := Color("ff7a52")
## Collection completion rewards, granted with the medals (next stage of work).
const COLLECTION_REWARDS := {1: ["코어 내구도 +5%", "모든 포탑 피해 증폭 +3%"], 2: ["치명타 피해 +10%", "보스 피해 증폭 +5%"], 3: ["포탑 사거리 +3%", "모든 포탑 피해 증폭 +3%"]}

var lobby
var chapter := 0
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
	var keys: Array = lobby.challenge_claim_keys()
	_chapter_row(body)
	for difficulty in ["normal", "hard"]:
		var hard: bool = difficulty == "hard"
		_collection(body, "하드 컬렉션" if hard else "노말 컬렉션", StageChallenges.chapter_count(p, chapter, difficulty), HARD_RED if hard else TEAL, COLLECTION_REWARDS.get(chapter, ["", ""])[1 if hard else 0])
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
	if not notice.is_empty():
		var note := _label(body, notice, 11, Color("ffb4a2"))
		note.name = "ChallengeNotice"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
		_chip(row, id, difficulty, state)

func _chip(row: HBoxContainer, id: int, difficulty: String, state: String) -> void:
	var hard := difficulty == "hard"
	var reward := StageChallenges.reward(id, difficulty)
	var kind := str(reward.get("kind", ""))
	var plate := Button.new()
	plate.name = "Challenge_%d_%s" % [id, difficulty]
	plate.focus_mode = Control.FOCUS_NONE
	plate.custom_minimum_size = Vector2(64, 36)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: Frame
	if state == "claim":
		style = Frame.new("ui/components/segment_selected_gold.png", 4)
	else:
		style = Frame.new("ui/components/segment_selected_neutral.png", 4)
		# Received rewards fade back; unearned ones keep a lit plate.
		style.modulate_color = Color(0.3, 0.36, 0.4, 0.35) if state == "done" else Color(0.55, 0.66, 0.74, 0.75)
	style.source_center = Rect2(6, 6, 52, 20)
	for look in ["normal", "hover", "pressed", "disabled", "focus"]: plate.add_theme_stylebox_override(look, style)
	plate.disabled = state != "claim" or not pending.is_empty()
	row.add_child(plate)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 3)
	plate.add_child(inner)
	if state == "done": _label(inner, "✓", 11, HARD_RED if hard else TEAL)
	var faded := HBoxContainer.new()
	faded.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faded.add_theme_constant_override("separation", 3)
	faded.modulate = Color(1, 1, 1, 0.38) if state == "done" else Color.WHITE
	inner.add_child(faded)
	var path: String = {"diamonds":"res://assets/ui/diamond_currency.png", "tickets":"stage_rewards/reward_module_ticket.png"}.get(kind, "stage_rewards/reward_core.png")
	var icon := TextureRect.new()
	icon.texture = T.texture(path)
	icon.custom_minimum_size = Vector2.ONE * (14 if kind == "diamonds" else 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faded.add_child(icon)
	var amount := int(reward.get("amount", 0))
	_label(faded, "%dP" % amount if kind == "corePoints" else str(amount), 12, Color("fff1c4") if state == "claim" else WHITE)
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
