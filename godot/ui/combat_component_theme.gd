extends RefCounted
## Native Godot theme skin: one intact PNG per surface, engine-managed nine-patch.
const ButtonSkin = preload("res://ui/button_skin.gd")
const ROLES := {"secondary":"CombatSecondary","primary":"CombatPrimary","danger":"CombatDanger","selected":"CombatSelected"}

static func surface(asset: String, padding := Vector2(10,7)) -> StyleBoxTexture:
	return ButtonSkin.surface(asset, padding)

static func install(theme: Theme) -> void:
	theme.set_type_variation("CombatModal","PanelContainer")
	theme.set_stylebox("panel","CombatModal",surface("modal",Vector2(16,16)))
	for role in ROLES:
		var type: String = ROLES[role]
		theme.set_type_variation(type,"Button")
		for state in ButtonSkin.STATES:
			theme.set_stylebox(state,type,ButtonSkin.appearance(role,state))
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			theme.set_color(state,type,ButtonSkin.font_color(role))
		theme.set_color("font_disabled_color",type,Color("7b909e"))

static func apply(button: Button, role := "secondary") -> void:
	for state in ButtonSkin.STATES:
		button.remove_theme_stylebox_override(state)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		button.remove_theme_color_override(state)
	button.theme_type_variation = ROLES.get(role,"CombatSecondary")
