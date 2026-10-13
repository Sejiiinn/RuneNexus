extends ProgressBar
## The extra stage grant shares the original bar. Only remaining extra HP
## expands the denominator; spending it restores the ordinary bar's full width.
const ORDINARY_COLOR := Color("6ef6a5")
const ADDITIONAL_COLOR := Color("c7ffb5")
var additional_hp := 0.0

func _init() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("1a2a39")
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORDINARY_COLOR
	add_theme_stylebox_override("background",background)
	add_theme_stylebox_override("fill",fill)

func set_health(ordinary: float,ordinary_max: float,additional: float) -> void:
	var next_additional := maxf(0,additional)
	var next_maximum := maxf(1,ordinary_max+next_additional)
	var next_value := clampf(ordinary,0,maxf(0,ordinary_max))
	if additional_hp==next_additional and max_value==next_maximum and value==next_value: return
	additional_hp = next_additional
	max_value = next_maximum
	value = next_value
	queue_redraw()

func additional_segment() -> Rect2:
	return Rect2(size.x*value/max_value,0,size.x*additional_hp/max_value,size.y)

func _draw() -> void:
	if additional_hp>0:
		draw_rect(additional_segment(),ADDITIONAL_COLOR)
