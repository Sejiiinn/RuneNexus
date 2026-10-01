extends PanelContainer
## A single transient, input-transparent warning survives wallet refreshes.
const T = preload("res://ui/app_theme.gd")
var lifetime := Timer.new()

func _init() -> void:
	name = "LobbyWarningToast"
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("10171c", 0.97)
	skin.border_color = Color("9a722c")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(3)
	skin.content_margin_left = 10
	skin.content_margin_right = 10
	skin.content_margin_top = 7
	skin.content_margin_bottom = 7
	add_theme_stylebox_override("panel", skin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var icon := T.label("⚠", 17)
	icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	icon.custom_minimum_size.x = 20
	icon.add_theme_color_override("font_color", Color("c39a49"))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := T.label("비용이 변경되었습니다.\n다시 확인해 주세요.", 11)
	text.name = "WarningText"
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.add_theme_color_override("font_color", Color("dbb368"))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	lifetime.one_shot = true
	lifetime.wait_time = 3.8
	add_child(lifetime)
	lifetime.timeout.connect(hide)
	hide()

func present() -> void:
	show()
	lifetime.start()

func dismiss() -> void:
	lifetime.stop()
	hide()

func place(bounds: Vector2, inset: Vector4) -> void:
	var available := bounds - Vector2(inset.x + inset.z, inset.y + inset.w)
	size = Vector2(minf(272, available.x - 48), 0)
	size.y = get_combined_minimum_size().y
	var bottom_gap := 100.0 if available.y > available.x else 18.0
	position = Vector2(inset.x + (available.x - size.x) * 0.5, inset.y + available.y - bottom_gap - size.y)
