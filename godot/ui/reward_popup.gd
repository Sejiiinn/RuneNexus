extends Control
## Full-screen result of a claim that can mix reward kinds: item boxes over the
## dimmed screen, closed with a tap or the back key. Single-kind claims keep the
## lighter rising amount of claim_feedback.gd.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const KINDS := [
	["grantedDiamonds", "res://assets/ui/diamond_currency.png", "무료 다이아", Color("8ee6ff")],
	["grantedModuleTickets", "stage_rewards/reward_module_ticket.png", "모듈권", Color("f5cb61")],
	["grantedGemResetTickets", "ui/hud/icons/gem_reset_ticket.png", "젬 리셋권", Color("c9a6ff")],
]
const BOX := 112.0
## Boxes land from in front of the screen: large and clear, settling into place.
const POP_FROM := 1.35
## The dimmed screen and title register first, so the boxes are watched arriving.
const POP_LEAD := 0.3
const POP_SEC := 0.24
const POP_STAGGER := 0.09
## The tap that claimed the reward must not also dismiss its result.
const TAP_GUARD_MSEC := 300
var rewards: Array = []
var _shown_at := 0
var _closing := false

## Item box specs of a server claim receipt, one per granted kind.
static func from_receipt(receipt: Dictionary) -> Array:
	var items: Array = []
	for kind in KINDS:
		var amount := int(receipt.get(kind[0], 0))
		if amount > 0: items.append({"icon":kind[1], "name":kind[2], "amount":amount, "tint":kind[3]})
	return items

static func present(parent, items: Array) -> Control:
	if items.is_empty() or not is_instance_valid(parent): return null
	var popup = load("res://ui/reward_popup.gd").new()
	popup.rewards = items
	parent.add_child(popup)
	return popup

## Closes an open result first, so the back key does not leave its dialog too.
static func dismiss(parent) -> bool:
	if not is_instance_valid(parent): return false
	var popup = parent.get_node_or_null("RewardPopup")
	if popup == null or popup.is_queued_for_deletion(): return false
	popup.close()
	return true

func _ready() -> void:
	name = "RewardPopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown_at = Time.get_ticks_msec()
	var shade := ColorRect.new()
	shade.color = Color("02070df2")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	column.add_child(_text("보상 획득", 28, Color("f3d27a"), 900, 6))
	var row := HBoxContainer.new()
	row.name = "RewardItems"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var items: Array = []
	for item in rewards: items.append(_item(row, item))
	column.add_child(_text("화면을 눌러 닫기", 12, Color("7f97a5"), 500))
	if ProjectSettings.get_setting("accessibility/disable_animations", false): return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	for index in items.size():
		var item: Control = items[index]
		var box: Control = item.get_node("RewardSlot/RewardBox")
		var delay := POP_LEAD + index * POP_STAGGER
		box.pivot_offset = Vector2.ONE * BOX / 2
		box.scale = Vector2.ONE * POP_FROM
		item.modulate.a = 0.0
		box.create_tween().tween_property(box, "scale", Vector2.ONE, POP_SEC).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		item.create_tween().tween_property(item, "modulate:a", 1.0, POP_SEC * 0.6).set_delay(delay)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Time.get_ticks_msec() - _shown_at >= TAP_GUARD_MSEC:
		accept_event()
		close()

func close() -> void:
	if _closing: return
	_closing = true
	if ProjectSettings.get_setting("accessibility/disable_animations", false):
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)

## One box: a plate tinted by its reward with the icon filling it, the amount in
## the corner and the name below.
func _item(row: Container, item: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	# Containers reset their children's scale, so the animated box sits on a plain slot.
	var slot := Control.new()
	slot.name = "RewardSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2.ONE * BOX
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(slot)
	var box := PanelContainer.new()
	box.name = "RewardBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	var plate := Frame.new("ui/components/segment_selected_neutral.png", 4)
	plate.source_center = Rect2(6, 6, 52, 20)
	plate.modulate_color = Color(0.5, 0.62, 0.72, 0.9)
	box.add_theme_stylebox_override("panel", plate)
	box.size = Vector2.ONE * BOX
	slot.add_child(box)
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(layer)
	var inner := BOX - 8.0
	var glow := TextureRect.new()
	glow.texture = _glow(item.tint)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2.ONE * inner
	layer.add_child(glow)
	var icon := TextureRect.new()
	icon.name = "RewardIcon"
	icon.texture = T.texture(item.icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2.ONE * inner * 0.86
	icon.position = (Vector2.ONE * inner - icon.size) / 2
	layer.add_child(icon)
	var amount := _text(HudNumber.exact_integer(item.amount), 13, Color.WHITE, 800, 4)
	amount.name = "RewardAmount"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.position = Vector2(0, inner - 22)
	amount.size = Vector2(inner - 4, 20)
	layer.add_child(amount)
	column.add_child(_text(item.name, 12, Color("b9d6e4"), 700))
	return column

func _glow(color: Color) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(color, 0.5), Color(color, 0.0)])
	texture.gradient = gradient
	return texture

func _text(value: String, size: int, color: Color, weight: int, outline := 0) -> Label:
	var label := T.label(value, size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", T.font(weight))
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", Color("02070d"))
	return label
