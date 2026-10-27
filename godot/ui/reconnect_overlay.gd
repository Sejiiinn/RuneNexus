extends Control
## Dims the current screen and blocks input while services quietly reconnect
## after a foreground return. The account gate opens only if that fails.
## Other server waits reuse it through caption_text and active_check.
const T = preload("res://ui/app_theme.gd")
const FADE_SEC := 0.2
const TURN_SEC := 0.9
var services
var caption_text := "서버에 다시 연결하는 중"
## Replaces services.reconnecting as the visibility condition when valid.
var active_check: Callable
## Input is blocked at once; the shade waits so quick replies do not flash.
var show_delay := 0.0
var spinner: Control
var _angle := 0.0
var _fade: Tween
var _active := false

func _ready() -> void:
	name = "ReconnectOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("02070dd0")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	spinner = Control.new()
	spinner.name = "ReconnectSpinner"
	spinner.custom_minimum_size = Vector2.ONE * 44
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spinner.draw.connect(_draw_spinner)
	column.add_child(spinner)
	var caption := T.label(caption_text, 13)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_color_override("font_outline_color", Color("02070d"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	hide()
	if services != null: services.changed.connect(sync)
	sync()

func sync() -> void:
	var active: bool = bool(active_check.call()) if active_check.is_valid() \
		else services != null and services.get("reconnecting") == true
	if active == _active: return
	_active = active
	if _fade != null: _fade.kill()
	if active:
		if not visible:
			_angle = 0.0
			modulate.a = 0.0
		show()
		_fade = create_tween()
		if show_delay > 0 and modulate.a == 0.0: _fade.tween_interval(show_delay)
		_fade.tween_property(self, "modulate:a", 1.0, FADE_SEC)
	else:
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 0.0, FADE_SEC * 0.5)
		_fade.tween_callback(hide)

func _process(delta: float) -> void:
	if not visible or ProjectSettings.get_setting("accessibility/disable_animations", false): return
	_angle = fposmod(_angle + TAU * delta / TURN_SEC, TAU)
	spinner.queue_redraw()

func _draw_spinner() -> void:
	var center := spinner.size / 2
	var radius := minf(center.x, center.y) - 3
	spinner.draw_arc(center, radius, 0, TAU, 48, Color("50cadd33"), 3, true)
	spinner.draw_arc(center, radius, _angle, _angle + TAU * 0.28, 24, Color("50cadd"), 3, true)
