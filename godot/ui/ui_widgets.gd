extends RefCounted
## Stateless widget factories shared by the battle HUD and lobby pages.
## Each adds the created control to `parent` and returns it, except
## plain_button, whose placement is left to the caller.
const AppTheme = preload("res://ui/app_theme.gd")
const BattleTheme = preload("res://ui/battle_theme.gd")
const Components = preload("res://ui/combat_component_theme.gd")
const HudChrome = preload("res://ui/hud_chrome.gd")

static func label(parent: Node, text: String, font_size: int) -> Label:
	var node := AppTheme.label(text,font_size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := AppTheme.button(text,callback)
	Components.apply(node)
	node.custom_minimum_size.y = 32
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(node)
	return node

## Borderless lobby text button; the caller adds it to a parent.
static func plain_button(value: String, callback: Callable) -> Button:
	var b := AppTheme.button(value, callback)
	b.custom_minimum_size.y = 36
	for state in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return b

static func icon(parent: Node,path: String,extent: float) -> TextureRect:
	var node := TextureRect.new(); node.texture = AppTheme.texture(path); node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; node.custom_minimum_size = Vector2.ONE*extent; parent.add_child(node); return node

static func material_icon(parent: Node,codepoint: int,extent: int) -> Label:
	var node := Label.new(); node.text = char(codepoint); node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font",load("res://assets/ui/MaterialIcons-Regular.otf")); node.add_theme_font_size_override("font_size",extent)
	parent.add_child(node)
	return node

static func stat_pill(parent: Node,title: String,value: String,color := Color("e8f8ff")) -> void:
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel",BattleTheme.box(Color(color,0.12),Color(color,0.55),7)); parent.add_child(panel)
	var caption := label(panel,(title+" "+value).strip_edges(),11); caption.modulate = color
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

static func style_hud_button(target: Button, role: String, selected: bool, padding: Vector2, tab_button := false) -> void:
	target.set_meta("hud_role",role)
	if role == "primary": target.theme_type_variation = "HudPrimary"
	for state in ["normal","hover","pressed","disabled","focus"]:
		if role == "primary": target.remove_theme_stylebox_override(state)
		else: target.add_theme_stylebox_override(state,HudChrome.quiet(state,selected,Color("65c9df"),padding))
	var foreground := Color("b7c8d8") if tab_button and not selected else Color("e8f8ff")
	for color_role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","icon_normal_color","icon_hover_color","icon_pressed_color"]:
		target.add_theme_color_override(color_role,foreground)

## Removes and frees every child of `parent` (deferred free).
static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
