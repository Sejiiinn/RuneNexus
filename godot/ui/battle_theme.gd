extends RefCounted
## Flutter GamePalette/GameButton roles; image frames remain asset-specific.
const Assets = preload("res://ui/app_theme.gd")
static func box(fill: Color = Color("091624f0"), edge: Color = Color("334957"), inset: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(inset)
	return s
static func create() -> Theme:
	var t := Theme.new()
	t.default_font = Assets.create().default_font
	t.default_font_size = 12
	t.set_font("font","Button",Assets.font(900))
	t.set_color("font_color","Label",Color("e8f8ff"))
	t.set_stylebox("panel","PanelContainer",box())
	for state in ["normal","hover","pressed","disabled","focus"]:
		t.set_stylebox(state,"Button",Assets.GameButton.appearance("secondary",state))
	t.set_color("font_color","Button",Color("e8f8ff"))
	t.set_color("font_disabled_color","Button",Color("667987"))
	t.set_constant("separation","VBoxContainer",5)
	t.set_constant("separation","HBoxContainer",5)
	preload("res://ui/combat_component_theme.gd").install(t)
	return t
