extends RefCounted
## Shared native UI, reusing the shipped metallic rune frames and Korean font.
const GameButton = preload("res://ui/game_button.gd")
static var _fonts := {}
const ROOT := "res://assets/app/"
static func texture(path: String) -> Texture2D:
	var full := path if path.begins_with("res://") else ROOT + path
	return load(full) as Texture2D if ResourceLoader.exists(full) else null

static func panel() -> StyleBox:
	var tex := texture("ui/components/panel_frame.png")
	if tex:
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.set_texture_margin_all(20)
		box.set_content_margin_all(12)
		return box
	var fallback := StyleBoxFlat.new()
	fallback.bg_color = Color("101e25f2")
	fallback.set_content_margin_all(12)
	return fallback

static func create() -> Theme:
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 16
	t.set_color("font_color", "Label", Color("e1eee9"))
	t.set_stylebox("panel", "PanelContainer", panel())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := panel()
		if s is StyleBoxTexture: s.texture = texture("ui/components/button_frame.png")
		if s is StyleBoxTexture and (state == "hover" or state == "pressed"): s.modulate_color = Color("b9ffeb")
		if s is StyleBoxTexture and state == "disabled": s.modulate_color = Color("71817f")
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		t.set_stylebox(state, "Button", s)
	t.set_color("font_color", "Button", Color("e3ede6"))
	t.set_color("font_disabled_color", "Button", Color("71817f"))
	return t

static func label(value: String, font_size: int = 16) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_font_override("font", font(900 if font_size >= 18 else (800 if font_size <= 10 else 700)))
	l.add_theme_color_override("font_color", Color("e8f8ff") if font_size >= 18 else Color("b9d6e4"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func font(weight: int = 700) -> Font:
	if _fonts.has(weight): return _fonts[weight]
	if not ResourceLoader.exists("res://assets/ui/NotoSansKR-VF.ttf"): return ThemeDB.fallback_font
	var result := FontVariation.new()
	result.base_font = load("res://assets/ui/NotoSansKR-VF.ttf")
	result.variation_opentype = {2003265652:float(weight)}
	_fonts[weight] = result
	return result

static func button(value: String, callback: Callable, variant: String = "secondary", compact: bool = false) -> Button:
	var b := GameButton.new()
	b.text = value
	b.variant = variant
	b.compact = compact
	b.custom_minimum_size.y = 30 if compact else 38
	b.add_theme_font_override("font",font(900))
	b.add_theme_font_size_override("font_size",10 if compact else 12)
	if callback.is_valid(): b.pressed.connect(callback)
	# Apply before entering the tree so owner-specific image overrides take precedence.
	b.apply_role()
	return b

static func animate_modal(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	if ProjectSettings.get_setting("accessibility/disable_animations",false): return
	control.modulate.a = 0
	var weak: WeakRef = weakref(control)
	var begin := func():
		var target: Control = weak.get_ref()
		if target == null or not target.is_inside_tree(): return
		target.pivot_offset = target.size/2
		target.scale = Vector2.ONE*0.94
		var resting := target.position
		target.position += Vector2(0,target.size.y*0.035)
		var tween := target.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(target,"modulate:a",1.0,0.21)
		tween.tween_property(target,"scale",Vector2.ONE,0.21)
		tween.tween_property(target,"position",resting,0.21)
	control.get_tree().process_frame.connect(begin,CONNECT_ONE_SHOT)
