extends Control
## A presentation clock keeps the pause cue breathing while combat is stopped.
var _elapsed := 0.0

func _ready() -> void:
	name = "PauseIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -66; offset_right = 66
	offset_top = -66; offset_bottom = 66
	var caption := Label.new()
	caption.text = "일시정지"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(0,110); caption.size = Vector2(132,22)
	caption.add_theme_font_size_override("font_size",16)
	caption.add_theme_color_override("font_color",Color("e4faff"))
	caption.add_theme_color_override("font_outline_color",Color("030b16"))
	caption.add_theme_constant_override("outline_size",5)
	add_child(caption)
	hide()
	set_process(false)

func set_paused(value: bool) -> void:
	if visible == value: return
	visible = value
	_elapsed = 0.0
	modulate.a = 1.0
	set_process(value)
	if value: queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	# The faint phase still identifies pause; there is no fully blank interval.
	modulate.a = 0.52 + 0.48 * (0.5 + 0.5 * cos(_elapsed * TAU / 1.6))

func _draw() -> void:
	var center := Vector2(66,66)
	draw_circle(center,42,Color("071321dc"))
	draw_arc(center,42,0,TAU,64,Color("73d9e5b0"),1.5,true)
	for x in [51.0,72.0]:
		draw_style_box(_bar_style(),Rect2(x,46,9,40))

func _bar_style() -> StyleBoxFlat:
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color("d5f8ff")
	bar.set_corner_radius_all(2)
	return bar
