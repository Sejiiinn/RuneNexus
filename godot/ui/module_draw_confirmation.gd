extends RefCounted
## The approved compact confirmation uses the existing single metal frame.
const T = preload("res://ui/app_theme.gd")
const ButtonSkin = preload("res://ui/button_skin.gd")

static func build(lobby, body: VBoxContainer, count: int, turret: String, quote: Dictionary, callback: Callable, enabled: bool) -> void:
	lobby.modal.set_meta("compact_draw_confirmation", true)
	lobby.modal.set_meta("width_fraction", 0.87)
	lobby.set_modal_stylebox(ButtonSkin.surface("modal", Vector2(12, 10)))
	var header: HBoxContainer = lobby.modal_frame.get_child(0).get_child(0)
	header.get_child(0).add_theme_font_size_override("font_size", 18)
	# At these small sizes, extra-heavy Korean strokes close the two counters in ㅂ.
	header.get_child(0).add_theme_font_override("font", T.font(700))
	header.get_child(1).custom_minimum_size = Vector2(28, 28)
	body.add_theme_constant_override("separation", 8)
	var target := T.label("%s 포탑 모듈 %d개" % [lobby.NAMES.get(turret, turret), count], 14)
	target.name = "ModuleDrawTarget"
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target.custom_minimum_size.y = 32
	body.add_child(target)
	var cost := VBoxContainer.new()
	cost.name = "ModuleDrawCost"
	cost.add_theme_constant_override("separation", 3)
	body.add_child(cost)
	var title := T.label("사용 비용", 11)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("87a6b8"))
	cost.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	cost.add_child(row)
	_amount(row, "stage_rewards/reward_module_ticket.png", "%d장" % int(quote.moduleTickets), "ModuleTicketAmount")
	if int(quote.diamonds) > 0:
		var plus := T.label("+", 14)
		plus.autowrap_mode = TextServer.AUTOWRAP_OFF
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.add_theme_color_override("font_color", Color("87a6b8"))
		row.add_child(plus)
		_amount(row, "res://assets/ui/diamond_currency.png", "%d개" % int(quote.diamonds), "DrawDiamondAmount")
	var action := T.button("%d개 뽑기" % count, callback, "primary")
	action.name = "DrawModulesConfirm"
	action.custom_minimum_size.y = 44
	action.add_theme_font_size_override("font_size", 16)
	action.add_theme_font_override("font", T.font(600))
	action.disabled = not enabled
	body.add_child(action)
	lobby._layout_modal.call_deferred()

static func _amount(parent: HBoxContainer, path: String, value: String, node_name: String) -> void:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	parent.add_child(group)
	var icon := TextureRect.new()
	icon.texture = T.texture(path)
	icon.custom_minimum_size = Vector2(25, 25)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(icon)
	var amount := T.label(value, 15)
	amount.name = node_name
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	group.add_child(amount)
