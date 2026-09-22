extends RefCounted
## Battle-only chrome: the lobby's actual metal artwork, quiet inner controls.
const Art = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")

static func panel(padding := 7) -> StyleBox:
	return Frame.new("ui/components/panel_frame.png",padding)

## Edge-attached dock reuses the panel interior and straight metal top rail.
## Floating corner caps and opaque exterior pixels are intentionally excluded.
class DockFrame extends StyleBox:
	var texture: Texture2D
	func _draw(item: RID, rect: Rect2) -> void:
		RenderingServer.canvas_item_add_texture_rect_region(item,rect,texture.get_rid(),Rect2(56,56,1392,528),Color.WHITE,false,true)
		RenderingServer.canvas_item_add_texture_rect_region(item,Rect2(rect.position,Vector2(rect.size.x,4)),texture.get_rid(),Rect2(56,0,1392,56),Color.WHITE,false,true)

static func docked_panel(padding := 5) -> StyleBox:
	var frame := DockFrame.new()
	frame.texture = Art.texture("ui/components/panel_frame.png")
	frame.set_content_margin_all(padding)
	return frame

static func primary(state: String) -> StyleBox:
	var frame = Frame.new("lobby_primary_button.png",0)
	frame.source_scale = 3.0
	frame.source_center = Rect2(12,14,276,28)
	frame.content_margin_left = 12
	frame.content_margin_right = 12
	if state == "disabled": frame.modulate_color = Color("627780")
	elif state == "pressed": frame.modulate_color = Color("9bc3cd")
	elif state in ["hover","focus"]: frame.modulate_color = Color("c9f4ff")
	return frame

static func quiet(state: String, selected := false, accent := Color("65c9df"), padding := Vector2(4,2)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("113d4be6") if selected else Color("07111d88")
	box.border_color = Color(accent,0.85 if selected else 0.0)
	box.set_border_width_all(1 if selected else 0)
	box.set_corner_radius_all(2)
	if state in ["hover","pressed","focus"]:
		box.bg_color = Color("194452")
		box.border_color = Color(accent,0.65)
		box.set_border_width_all(1)
	if state == "disabled": box.bg_color = Color("07111d44"); box.border_color = Color("4a617244")
	box.content_margin_left = padding.x; box.content_margin_right = padding.x
	box.content_margin_top = padding.y; box.content_margin_bottom = padding.y
	return box

static func divider() -> VSeparator:
	var line := VSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("52708055"); style.thickness = 1; style.vertical = true
	line.add_theme_stylebox_override("separator",style)
	line.add_theme_constant_override("separation",1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line
