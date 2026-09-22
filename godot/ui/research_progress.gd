extends Control
## Flutter research slot fill / 2.4-second catalog border animation.
var catalog := false
var progress := 0.0:
	set(value): progress = value; queue_redraw()
var phase := 0.0
var _tween: Tween
var _gradient: GradientTexture2D
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(catalog)
	if catalog:
		_gradient = GradientTexture2D.new()
		_gradient.gradient = Gradient.new()
		_gradient.gradient.offsets = PackedFloat32Array([0,0.5,1])
		_gradient.gradient.colors = PackedColorArray([Color("33d8ff26"),Color("00000010"),Color("e7c66a22")])
		_gradient.fill_from = Vector2.ZERO
		_gradient.fill_to = Vector2.ONE
func set_progress(value: float) -> void:
	if is_instance_valid(_tween): _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self,"progress",clampf(value,0,1),0.85)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	phase = fposmod(phase+delta/2.4,1.0)
	queue_redraw()
func _draw() -> void:
	if not catalog:
		draw_rect(Rect2(0,0,size.x*progress,size.y),Color("e7c66a22"))
		if progress>0: draw_line(Vector2(size.x*progress,0),Vector2(size.x*progress,size.y),Color("e7c66a88"))
		return
	if _gradient != null: draw_texture_rect(_gradient,Rect2(Vector2.ZERO,size),false)
	var path := PackedVector2Array()
	var r := 7.0
	var centers := [Vector2(size.x-1.1-r,1.1+r),Vector2(size.x-1.1-r,size.y-1.1-r),Vector2(1.1+r,size.y-1.1-r),Vector2(1.1+r,1.1+r)]
	for corner in range(4):
		for step in range(9):
			path.append(centers[corner]+Vector2.from_angle(-PI/2+corner*PI/2+step*PI/16)*r)
	path.append(path[0])
	draw_polyline(path,Color("e7c66a44"),2.2,true)
	var length := 0.0
	for i in range(path.size()-1): length += path[i].distance_to(path[i+1])
	_segment(path,length,phase*length,length*0.22,Color("e7c66a"),2.4)
	_segment(path,length,fposmod(phase+0.5,1)*length,length*0.22*0.55,Color("e7c66a44"),2.2)
func _segment(path: PackedVector2Array,total: float,start: float,length: float,color: Color,width: float) -> void:
	for wrap in [0.0,total]:
		var cursor := 0.0
		for i in range(path.size()-1):
			var extent := path[i].distance_to(path[i+1])
			var a := maxf(cursor,start-wrap); var b := minf(cursor+extent,start+length-wrap)
			if b>a and extent>0:
				draw_line(path[i].lerp(path[i+1],(a-cursor)/extent),path[i].lerp(path[i+1],(b-cursor)/extent),color,width,true)
			cursor += extent
