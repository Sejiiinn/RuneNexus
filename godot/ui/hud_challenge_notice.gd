extends RefCounted
## Battle challenge notice (docs/design_decisions/combat_ui.md 「도전 조건 안내」):
## a strip under the top HUD, between the gem shortcut and the camera toggle,
## styled like the lobby card's challenge line. It shows the condition once when
## a tracked, not yet achieved challenge is first seen intact, and a failure
## once when that condition breaks. Nothing stays on the HUD. A run already
## broken when first seen (a resumed run) shows neither.
const T = preload("res://ui/app_theme.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
const StageDifficulty = preload("res://content/stage_difficulty.gd")
const GOLD := Color("e7c66a")
const WHITE := Color("e8f8ff")
const MUTED := Color("9fb3bf")
const FAIL := Color("ff7a52")
const HARD_RED := Color("ff7a52")
const START_HOLD := 3.0
const FAIL_HOLD := 2.5
var hud: Control
var notice: PanelContainer
var _run_key: Variant = null
## null until the run is first seen; then whether the condition still holds.
var _intact: Variant = null

func _init(owner: Control) -> void:
	hud = owner

## Observes the run on each HUD refresh; returns "start", "fail" or "".
func observe(state: Dictionary, stage_id: int) -> String:
	var key := [str(state.get("economyRunId", "")), stage_id, StageDifficulty.of(state)]
	if key != _run_key:
		_run_key = key
		_intact = null
	# Rewards and the result own the screen; a notice never lingers over them.
	if not str(state.get("phase", "")) in ["preparation", "wave"]: clear()
	var kind := step(state, stage_id)
	if not kind.is_empty(): show(kind, stage_id, StageDifficulty.is_hard(state))
	return kind

## Pure transition of the observed run: "start", "fail" or "".
func step(state: Dictionary, stage_id: int) -> String:
	if _intact == false: return ""
	if not str(state.get("phase", "")) in ["preparation", "wave"]: return ""
	if not StageChallenges.has_challenge(stage_id) or not state.has(StageChallenges.PEAK_FIELD) \
			or StageChallenges.achieved(state.get("progression", {}), stage_id, StageDifficulty.of(state)):
		_intact = false
		return ""
	var met := StageChallenges.met(state, stage_id)
	if _intact == null:
		_intact = met
		return "start" if met else ""
	if not met:
		_intact = false
		return "fail"
	return ""

func clear() -> void:
	if is_instance_valid(notice): notice.queue_free()
	notice = null

func show(kind: String, stage_id: int, hard: bool) -> void:
	clear()
	var failed := kind == "fail"
	notice = PanelContainer.new()
	notice.name = "ChallengeNotice"
	notice.set_meta("kind", kind)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c0f0ce8") if failed else Color("0b141ce6")
	box.border_color = Color(FAIL, 0.75) if failed else Color(GOLD, 0.6)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10; box.content_margin_right = 12
	box.content_margin_top = 6; box.content_margin_bottom = 6
	notice.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	notice.add_child(row)
	var icon := TextureRect.new()
	icon.texture = T.texture("lobby_challenge_icon.png")
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = Color(1, 0.55, 0.45) if failed else Color.WHITE
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	_label(top, "도전 실패" if failed else "도전", 11, FAIL if failed else GOLD, 900)
	if hard and not failed: _label(top, "하드", 11, HARD_RED, 900)
	var lines: Array = StageChallenges.lines(stage_id)
	_label(top, StageChallenges.broken_line(stage_id) if failed else str(lines[0]), 13, WHITE, 800).name = "ChallengeNoticeText"
	_label(column, "클리어 보상은 그대로 받습니다" if failed else str(lines[1]), 11, MUTED, 700)
	hud.add_child(notice)
	notice.modulate.a = 0.0
	place.call_deferred(notice)

## Centers the strip under the top HUD between the side controls; a strip too
## wide for that gap drops below them to the full width.
func place(target: PanelContainer) -> void:
	if not is_instance_valid(target) or target != notice: return
	var insets: Vector4 = hud.safe_insets()
	var width := hud.get_viewport_rect().size.x
	var y: float = hud.top.offset_top + hud.top.size.y + 6
	var side := 8.0 + maxf(insets.x, insets.z) + 68.0 + 8.0
	var size := target.get_combined_minimum_size()
	if size.x > width - side * 2: y += 40
	target.size = size
	var rest := Vector2((width - size.x) / 2.0, y)
	target.position = rest - Vector2(0, 8)
	var hold := FAIL_HOLD if target.get_meta("kind", "") == "fail" else START_HOLD
	var tween := target.create_tween()
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, 0.25)
	tween.tween_property(target, "position", rest, 0.25)
	tween.chain().tween_property(target, "modulate:a", 0.0, 0.4).set_delay(hold)
	tween.chain().tween_callback(target.queue_free)

func _label(parent: Node, text: String, size: int, color: Color, weight: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", T.font(weight))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label
