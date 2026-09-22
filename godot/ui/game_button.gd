extends Button
## Role-aware Flutter GameButton counterpart. Layout remains the owner's choice.
var variant := "secondary"
var compact := false
var _press_tween: Tween

class GradientBox extends StyleBox:
	var base: StyleBoxFlat
	var top: Color
	var bottom: Color
	var diagonal := false
	func _draw(canvas: RID, rect: Rect2) -> void:
		base.draw(canvas, rect)
		var r := rect.grow(-1.2)
		var radius := minf(6.8, minf(r.size.x, r.size.y) / 2)
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for corner in range(4):
			var center := [r.position+Vector2(radius,radius), Vector2(r.end.x-radius,r.position.y+radius), r.end-Vector2(radius,radius), Vector2(r.position.x+radius,r.end.y-radius)][corner] as Vector2
			for step in range(9):
				var angle := PI + corner * PI/2 + step * PI/16
				var point := center + Vector2.from_angle(angle)*radius
				points.append(point)
				var weight := (point.y-r.position.y)/maxf(1,r.size.y)
				if diagonal: weight = (weight+(point.x-r.position.x)/maxf(1,r.size.x))/2
				colors.append(top.lerp(bottom,weight))
		RenderingServer.canvas_item_add_polygon(canvas,points,colors)

static func appearance(role: String, state: String, selected := false) -> StyleBox:
	var accent: Color = {"primary":Color("8ee6ff"),"secondary":Color("8fa8ba"),"confirm":Color("63e6a5"),"danger":Color("ff7043"),"ghost":Color("8ee6ff")}.get(role,Color("8fa8ba"))
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.set_content_margin_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.set_border_width_all(2 if selected else 1)
	box.border_color = Color(accent,0.78)
	box.bg_color = Color(accent,0.14)
	box.shadow_color = Color(accent,0.16)
	box.shadow_size = 7 if selected else 4
	box.shadow_offset = Vector2(0,3)
	if state == "disabled":
		box.border_color = Color("4a617244")
		box.bg_color = Color("22354344")
		box.shadow_size = 0
		return box
	if state == "focus":
		box.border_color = accent
		box.bg_color = Color.TRANSPARENT
		box.shadow_size = 0
		return box
	if role == "ghost":
		box.bg_color = Color.TRANSPARENT
		box.border_color = Color(accent,0.58)
		box.shadow_color = Color(accent,0.08)
		return box
	var result := GradientBox.new()
	result.base = box
	result.top = Color(accent,0.2)
	result.bottom = Color("07111dd6")
	if role == "primary":
		box.border_color = Color("bff4ff")
		box.shadow_color = Color(accent,0.32)
		result.top = Color(accent,0.94)
		result.bottom = Color("22c7e8")
		result.diagonal = true
	for side in range(4): result.set_content_margin(side,box.get_content_margin(side))
	return result

func _ready() -> void:
	button_down.connect(_animate_press.bind(true))
	button_up.connect(_animate_press.bind(false))
	mouse_exited.connect(func(): if not button_pressed: _animate_press(false))
	resized.connect(func(): pivot_offset = size/2)
	pivot_offset = size/2

func apply_role() -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,appearance(variant,state,button_pressed and toggle_mode))
	var color := Color("02070d") if variant == "primary" else (Color("ffc285") if variant == "danger" else (Color("8ee6ff") if variant == "ghost" else Color("e8f8ff")))
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: add_theme_color_override(key,color)
	add_theme_color_override("font_disabled_color",Color("667987"))

func _animate_press(down: bool) -> void:
	if is_instance_valid(_press_tween): _press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self,"scale",Vector2.ONE*(0.96 if down else 1.0),0.09)
