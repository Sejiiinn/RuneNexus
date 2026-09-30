extends PopupPanel
## The approved runic frame, with native goal rows and a persistent selection.
const Art = preload("res://ui/app_theme.gd")
const ROOT := "ui/hud/target_priority/"
signal id_pressed(id: int)
var _rows: Array[Button] = []
var _selected := -1
var item_count: int:
	get: return _rows.size()
static var _frame_texture: Texture2D

func configure(labels: Dictionary) -> void:
	name = "TargetPriorityOptions"
	transparent_bg = true
	transparent = true
	var frame := StyleBoxTexture.new()
	if _frame_texture == null:
		_frame_texture = Art.texture(ROOT+"frame.png")
	frame.texture = _frame_texture
	# The side runes stay in the fixed upper slice instead of stretching.
	frame.texture_margin_left = 11; frame.texture_margin_right = 11
	frame.texture_margin_top = 94; frame.texture_margin_bottom = 18
	frame.content_margin_left = 10; frame.content_margin_right = 9
	frame.content_margin_top = 10; frame.content_margin_bottom = 10
	add_theme_stylebox_override("panel",frame)
	var column := VBoxContainer.new(); column.name = "TargetPriorityRows"
	column.custom_minimum_size.x = 85
	column.add_theme_constant_override("separation",0)
	add_child(column)
	for key in labels:
		var index := _rows.size()
		var button := Button.new(); button.name = "TargetChoice_"+str(key)
		button.text = labels[key]
		button.custom_minimum_size = Vector2(85,32)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",16)
		button.add_theme_constant_override("h_separation",4)
		button.add_theme_font_override("font",Art.font(700))
		button.add_theme_font_size_override("font_size",13)
		for role in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			button.add_theme_color_override(role,Color("e8eef3"))
		button.pressed.connect(_activate.bind(index))
		column.add_child(button); _rows.append(button)
		_style_row(index,false)
	about_to_popup.connect(func(): _focus_selected.call_deferred())

func set_item_checked(index: int,checked: bool) -> void:
	if checked: _selected = index
	_style_row(index,checked)

func is_item_checked(index: int) -> bool:
	return _rows[index].button_pressed

func get_item_text(index: int) -> String:
	return _rows[index].text

func _style_row(index: int,checked: bool) -> void:
	var button := _rows[index]
	button.set_pressed_no_signal(checked)
	button.icon = Art.texture(ROOT+("radio_checked.png" if checked else "radio_unchecked.png"))
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0a202c") if checked else Color.TRANSPARENT
		if state == "hover" and not checked: style.bg_color = Color("102b35")
		style.set_corner_radius_all(4)
		style.content_margin_left = 4; style.content_margin_right = 2
		style.content_margin_top = 0; style.content_margin_bottom = 0
		button.add_theme_stylebox_override(state,style)
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())

func _focus_selected() -> void:
	if visible and _selected >= 0: _rows[_selected].grab_focus()

func _activate(index: int) -> void:
	hide()
	id_pressed.emit(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
