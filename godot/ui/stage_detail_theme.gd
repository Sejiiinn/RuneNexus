extends RefCounted
## Approved stage-detail concept 02: gold edges, rune stone, and cyan action.
const Art = preload("res://ui/app_theme.gd")
const ROOT := "stage_details/v2/"
const GOLD := Color("baa36a")
const CYAN := Color("8ee6ff")
const FONT_TITLE := 22
const FONT_ACTION := 18
const FONT_PRIMARY := 16
const FONT_SECONDARY := 12

static func box(asset: String, padding: float = 0) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = Art.texture(ROOT+asset+".png")
	result.set_content_margin_all(padding)
	if asset == "dialog_frame": result.modulate_color = Color(0.72,0.72,0.72,1)
	var margins: Vector4 = {
		"dialog_frame":Vector4(55,110,55,55),
		"reward_row":Vector4(12,10,12,10),
		"action_button":Vector4(16,12,16,12),
		"reward_heading":Vector4(10,10,10,10),
		"close_button":Vector4.ZERO,
		"divider":Vector4(12,0,12,0),
	}.get(asset,Vector4.ZERO)
	result.set_texture_margin(SIDE_LEFT,margins.x)
	result.set_texture_margin(SIDE_TOP,margins.y)
	result.set_texture_margin(SIDE_RIGHT,margins.z)
	result.set_texture_margin(SIDE_BOTTOM,margins.w)
	return result

static func status() -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color("041921cc")
	result.border_color = GOLD
	result.set_border_width_all(1)
	result.set_corner_radius_all(10)
	result.content_margin_left = 10
	result.content_margin_right = 10
	result.content_margin_top = 1
	result.content_margin_bottom = 1
	return result

static func apply_action(button: Button) -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := box("action_button",10)
		if state == "hover": style.modulate_color = Color(1.12,1.12,1.12)
		elif state == "pressed": style.modulate_color = Color("aec9ce")
		elif state == "disabled": style.modulate_color = Color("647d82a6")
		style.modulate_color *= Color(0.88,0.88,0.88,1)
		button.add_theme_stylebox_override(state,style)
