extends RefCounted
## Native Godot theme skin: one intact PNG per surface, engine-managed nine-patch.
const Art = preload("res://ui/app_theme.gd")
const ROOT := "ui/combat_components/native/"
const ROLES := {"secondary":"CombatSecondary","primary":"CombatPrimary","danger":"CombatDanger","selected":"CombatSelected"}

static func surface(asset: String, padding := Vector2(10,7)) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = Art.texture(ROOT+asset+".png")
	style.set_texture_margin_all(14 if asset == "modal" else 11)
	style.content_margin_left = padding.x; style.content_margin_right = padding.x
	style.content_margin_top = padding.y; style.content_margin_bottom = padding.y
	return style

static func install(theme: Theme) -> void:
	theme.set_type_variation("CombatModal","PanelContainer")
	theme.set_stylebox("panel","CombatModal",surface("modal",Vector2(16,16)))
	for role in ROLES:
		var type: String = ROLES[role]
		theme.set_type_variation(type,"Button")
		for state in ["normal","hover","pressed","disabled","focus"]:
			if state == "focus":
				var focus := StyleBoxFlat.new(); focus.bg_color = Color.TRANSPARENT
				focus.border_color = Color("b5f2ff"); focus.set_border_width_all(1)
				focus.content_margin_left = 10; focus.content_margin_right = 10
				focus.content_margin_top = 7; focus.content_margin_bottom = 7
				theme.set_stylebox(state,type,focus)
				continue
			var asset: String = "disabled" if state == "disabled" else role
			if state == "pressed" and role == "secondary": asset = "selected"
			var style := surface(asset)
			if role == "secondary" and state == "normal": style.modulate_color = Color(0.7,0.8,0.86)
			if state == "hover": style.modulate_color = Color(1.12,1.12,1.12)
			elif state == "pressed" and role != "secondary": style.modulate_color = Color(0.82,0.9,0.94)
			theme.set_stylebox(state,type,style)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			theme.set_color(state,type,Color("ffd7c5") if role == "danger" else Color("e8f8ff"))
		theme.set_color("font_disabled_color",type,Color("7b909e"))

static func apply(button: Button, role := "secondary") -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.remove_theme_stylebox_override(state)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		button.remove_theme_color_override(state)
	button.theme_type_variation = ROLES.get(role,"CombatSecondary")
