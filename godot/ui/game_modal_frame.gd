extends StyleBox
## Flutter GameModalFrame cut corners, tone, ambient light and inset rails.
## Shared by battle and lobby; content margins are independent of frame geometry.
var accent := Color("8ee6ff")
var tone := "standard"
var _cached_rect := Rect2()
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

static func create(color := Color("8ee6ff"),surface_tone := "standard",padding := 18.0) -> StyleBox:
	var frame = load("res://ui/game_modal_frame.gd").new()
	frame.accent = color; frame.tone = surface_tone
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: frame.set_content_margin(side,padding)
	return frame

static func outline(rect: Rect2,cut: float) -> PackedVector2Array:
	cut = clampf(cut,0.0,maxf(0.0,minf(rect.size.x,rect.size.y)*0.5-0.01))
	var a := rect.position; var b := rect.end
	return PackedVector2Array([Vector2(a.x+cut,a.y),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),Vector2(b.x,b.y-cut),Vector2(b.x-cut,b.y),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),Vector2(a.x,a.y+cut)])

func _draw(canvas: RID,rect: Rect2) -> void:
	# Containers can draw once before their first nonzero layout.
	if rect.size.x <= 12 or rect.size.y <= 12: return
	if rect != _cached_rect: _build_fill(rect)
	# Layered soft silhouette preserves the source drop shadow without an image asset.
	for radius in range(18,0,-2):
		var shadow := outline(Rect2(rect.position+Vector2(0,5),rect.size).grow(radius),14+radius)
		RenderingServer.canvas_item_add_polygon(canvas,shadow,PackedColorArray([Color(0,0,0,0.035)]))
	RenderingServer.canvas_item_add_triangle_array(canvas,_indices,_vertices,_colors)
	var outer := outline(rect.grow(-1),14); outer.append(outer[0])
	RenderingServer.canvas_item_add_polyline(canvas,outer,PackedColorArray([Color(accent,0.78)]),1.35,true)
	var inner := outline(rect.grow(-5),10); inner.append(inner[0])
	RenderingServer.canvas_item_add_polyline(canvas,inner,PackedColorArray([Color(accent,0.2)]),1,true)
	var rail := PackedVector2Array([rect.position+Vector2(22,1.5),Vector2(rect.get_center().x,rect.position.y+1.5),Vector2(rect.end.x-22,rect.position.y+1.5)])
	RenderingServer.canvas_item_add_polyline(canvas,rail,PackedColorArray([Color(accent,0),Color(accent,0.92),Color(accent,0)]),1.5,true)
	var center := Vector2(rect.get_center().x,rect.position.y+1.5)
	for radius in range(9,0,-1):
		var extent := 7.78+radius
		var glow := PackedVector2Array([center+Vector2(0,-extent),center+Vector2(extent,0),center+Vector2(0,extent),center+Vector2(-extent,0)])
		RenderingServer.canvas_item_add_polygon(canvas,glow,PackedColorArray([Color(accent,0.035)]))
	var rune := PackedVector2Array([center+Vector2(0,-7.78),center+Vector2(7.78,0),center+Vector2(0,7.78),center+Vector2(-7.78,0)])
	RenderingServer.canvas_item_add_polygon(canvas,rune,PackedColorArray([Color("02070d")]))
	rune.append(rune[0]); RenderingServer.canvas_item_add_polyline(canvas,rune,PackedColorArray([accent]),1.4,true)

func _build_fill(rect: Rect2) -> void:
	_cached_rect = rect; _vertices.clear(); _colors.clear(); _indices.clear()
	var boundary := outline(rect.grow(-1),14)
	var top: Color = {"standard":Color("102638"),"reward":Color("272416"),"danger":Color("2a1719")}.get(tone,Color("102638"))
	var bottom: Color = {"standard":Color("050c15"),"reward":Color("080d10"),"danger":Color("0b090d")}.get(tone,Color("050c15"))
	# One cached triangle batch approximates Flutter's two gradients without textures.
	for y in range(16):
		for x in range(12):
			var cell := Rect2(rect.position+rect.size*Vector2(x/12.0,y/16.0),rect.size/Vector2(12,16))
			for polygon in Geometry2D.intersect_polygons(boundary,PackedVector2Array([cell.position,Vector2(cell.end.x,cell.position.y),cell.end,Vector2(cell.position.x,cell.end.y)])):
				var offset := _vertices.size()
				for point in polygon:
					_vertices.append(point)
					var gradient_t: float = (point-rect.position).dot(rect.size)/rect.size.length_squared()
					var base := top.lerp(bottom,gradient_t)
					var radius := point.distance_to(rect.position+rect.size*Vector2(0.5,-0.1))/(minf(rect.size.x,rect.size.y)*1.15)
					_colors.append(base.lerp(accent,0.16*clampf(1-radius,0,1)))
				for index in Geometry2D.triangulate_polygon(polygon): _indices.append(offset+index)

static func dismiss(control: Control) -> void:
	if not is_instance_valid(control): return
	if ProjectSettings.get_setting("accessibility/disable_animations",false):
		control.queue_free(); return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_input(control)
	var tween := control.create_tween().set_parallel(true)
	tween.tween_property(control,"modulate:a",0.0,0.21).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var panel := _find_panel(control)
	if panel != null:
		panel.pivot_offset = panel.size*0.5
		tween.tween_property(panel,"scale",Vector2.ONE*0.94,0.21).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(panel,"position:y",panel.position.y+panel.size.y*0.035,0.21).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var reference: WeakRef = weakref(control)
	tween.chain().tween_callback(func():
		var target = reference.get_ref()
		if is_instance_valid(target): target.queue_free())

static func _ignore_input(node: Node) -> void:
	for child in node.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_input(child)

static func _find_panel(node: Node) -> Control:
	if node is PanelContainer: return node
	for child in node.get_children():
		var found := _find_panel(child)
		if found != null: return found
	return null
