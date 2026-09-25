extends RefCounted
## Shared metallic button surfaces, independent of app and combat themes.
const ROOT := "res://assets/app/ui/combat_components/native/"
const STATES := ["normal", "hover", "pressed", "disabled", "focus"]

static func surface(asset: String, padding := Vector2(10,7)) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var path := ROOT + asset + ".png"
	style.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	style.set_texture_margin_all(14 if asset == "modal" else 11)
	style.content_margin_left = padding.x; style.content_margin_right = padding.x
	style.content_margin_top = padding.y; style.content_margin_bottom = padding.y
	return style

static func appearance(role: String, state: String, selected := false, padding := Vector2(10,7)) -> StyleBox:
	if state == "focus":
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("b5f2ff")
		focus.set_border_width_all(1)
		focus.content_margin_left = padding.x; focus.content_margin_right = padding.x
		focus.content_margin_top = padding.y; focus.content_margin_bottom = padding.y
		return focus
	var asset_role: String = {"confirm":"primary", "ghost":"secondary"}.get(role, role)
	if asset_role not in ["primary", "secondary", "danger", "selected"]: asset_role = "secondary"
	if selected: asset_role = "selected"
	var down := state in ["pressed", "hover_pressed"]
	var asset := "disabled" if state == "disabled" else asset_role
	if down and asset_role == "secondary": asset = "selected"
	var style := surface(asset, padding)
	if asset_role == "secondary" and state == "normal": style.modulate_color = Color(0.7,0.8,0.86)
	if state == "hover": style.modulate_color = Color(1.12,1.12,1.12)
	elif down and asset_role != "secondary": style.modulate_color = Color(0.82,0.9,0.94)
	return style

static func font_color(role: String) -> Color:
	return Color("ffd7c5") if role == "danger" else Color("e8f8ff")
