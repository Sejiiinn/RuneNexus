extends Button
## Compact close control: scale the complete square artwork, never a wide frame.
const ART := "res://assets/app/ui/components/close_button.png"

func _init() -> void:
	custom_minimum_size = Vector2(32,32)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = "닫기"
	var artwork := load(ART) as Texture2D
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var surface := StyleBoxTexture.new()
		surface.texture = artwork
		surface.set_texture_margin_all(0)
		surface.set_content_margin_all(0)
		if state == "hover": surface.modulate_color = Color(1.15,1.15,1.15)
		elif state in ["pressed","hover_pressed"]: surface.modulate_color = Color(0.72,0.82,0.88)
		elif state == "disabled": surface.modulate_color = Color(0.5,0.5,0.5,0.6)
		add_theme_stylebox_override(state,surface)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("b5f2ff")
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(3)
	add_theme_stylebox_override("focus",focus)
