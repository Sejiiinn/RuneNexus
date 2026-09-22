extends StyleBox
## Flutter's AssetImage(scale:4) + centerSlice, without lowering master resolution.
const Art = preload("res://ui/app_theme.gd")
const CENTERS := {"panel_frame":Rect2(14,14,348,132),"card_frame":Rect2(11,11,149,94),"row_frame":Rect2(11,10,335,24),"row_frame_locked":Rect2(11,11,335,37),"button_frame":Rect2(8,8,135,18),"chip_frame":Rect2(8,7,44,13)}
var texture: Texture2D
var modulate_color := Color.WHITE
var source_center := Rect2()
var source_scale := 4.0

func _init(path: String = "", inset: int = 8) -> void:
	texture = Art.texture(path) if not path.is_empty() else null
	if path.begins_with("ui/components/"):
		source_center = CENTERS.get(path.get_file().get_basename(),Rect2())
	set_content_margin_all(inset)

func _draw(item: RID, rectangle: Rect2) -> void:
	if not texture:
		RenderingServer.canvas_item_add_rect(item,rectangle,Color("091624")*modulate_color)
		return
	if source_center.size == Vector2.ZERO:
		RenderingServer.canvas_item_add_texture_rect(item,rectangle,texture.get_rid(),false,modulate_color)
		return
	var pixels := texture.get_size()
	var logical := pixels / source_scale
	var right := logical.x-source_center.end.x
	var bottom := logical.y-source_center.end.y
	var xs := [0.0,source_center.position.x*source_scale,source_center.end.x*source_scale,pixels.x]
	var ys := [0.0,source_center.position.y*source_scale,source_center.end.y*source_scale,pixels.y]
	var dx := [0.0,minf(source_center.position.x,rectangle.size.x/2),maxf(rectangle.size.x/2,rectangle.size.x-right),rectangle.size.x]
	var dy := [0.0,minf(source_center.position.y,rectangle.size.y/2),maxf(rectangle.size.y/2,rectangle.size.y-bottom),rectangle.size.y]
	for x in range(3):
		for y in range(3):
			var source := Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y])
			var target := Rect2(rectangle.position+Vector2(dx[x],dy[y]),Vector2(dx[x+1]-dx[x],dy[y+1]-dy[y]))
			RenderingServer.canvas_item_add_texture_rect_region(item,target,texture.get_rid(),source,modulate_color,false,true)
