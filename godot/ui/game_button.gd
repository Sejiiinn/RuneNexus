extends Button
## Role-aware Flutter GameButton counterpart. Layout remains the owner's choice.
var variant := "secondary"
var compact := false
var _press_tween: Tween

const ButtonSkin = preload("res://ui/button_skin.gd")

static func appearance(role: String, state: String, selected := false) -> StyleBox:
	return ButtonSkin.appearance(role, state, selected, Vector2(12,6))

func _ready() -> void:
	button_down.connect(_animate_press.bind(true))
	button_up.connect(_animate_press.bind(false))
	mouse_exited.connect(func(): if not button_pressed: _animate_press(false))
	resized.connect(func(): pivot_offset = size/2)
	pivot_offset = size/2

func apply_role() -> void:
	for state in ButtonSkin.STATES:
		add_theme_stylebox_override(state,appearance(variant,state,button_pressed and toggle_mode))
	var color := ButtonSkin.font_color(variant)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: add_theme_color_override(key,color)
	add_theme_color_override("font_disabled_color",Color("7b909e"))

func _animate_press(down: bool) -> void:
	if is_instance_valid(_press_tween): _press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self,"scale",Vector2.ONE*(0.96 if down else 1.0),0.09)
