extends VBoxContainer
## Native container layout for the approved 06-v2 action strip.
const Art = preload("res://ui/app_theme.gd")
const ROOT := "ui/hud/turret_actions/"
static var _skin: Theme
static var _turret_icons := {}
var level_action: Button
var trait_action: Button
var sell_action: Button
var _ratio := 1.0
var _price_row: HBoxContainer
var _price_label: Label
var _price_icon: TextureRect
var _price_gap: Control
var _price_text := ""

func configure(spec: Dictionary) -> void:
	name = "TurretActionPanel"
	theme = _theme()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_meta("design_separation",-10.0)
	var header := PanelContainer.new(); header.name = "TurretActions"
	header.theme_type_variation = "TurretHeader"; add_child(header); _minimum(header,Vector2(0,298))
	var header_margin := _margin(header,70,0,60,0)
	var row := _hbox(header_margin)
	var identity := _hbox(row); _expand(identity,397)
	var turret_icon := _image(identity,spec.icon,136,132,true)
	turret_icon.name = "TurretIdentityIcon"
	_space(identity,26)
	var identity_text := _vbox(identity); identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(identity_text,spec.title,60,82,Color("e8f8ff"))
	_text(identity_text,spec.level,60,80,Color("e7c66a"))
	_image(row,ROOT+"ref_identity_divider.png",8,207); _space(row,26)
	trait_action = _action(row,"TurretTraitAction","traits",585,225,spec.trait_callback)
	var trait_content := _margin(trait_action,80,0,59,0,true)
	var trait_row := _hbox(trait_content)
	_image(trait_row,"ui/hud/icons/traits.png",137,134); _space(trait_row,29)
	_image(trait_row,ROOT+"ref_trait_divider.png",8,183); _space(trait_row,32)
	var trait_text := _vbox(trait_row); trait_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(trait_text,"특성",60,85,Color("e8f8ff"))
	_text(trait_text,"%d/2 선택" % spec.trait_count,50,75,Color("bba5ed"))
	_space(row,31)
	level_action = _action(row,"TurretLevelAction","upgrade",570,225,spec.upgrade_callback)
	var upgrade_content := _margin(level_action,74,0,40,0,true)
	var upgrade_row := _hbox(upgrade_content)
	_image(upgrade_row,ROOT+"ref_upgrade.png",106,123); _space(upgrade_row,44)
	_image(upgrade_row,ROOT+"ref_divider.png",7,183); _space(upgrade_row,33)
	var upgrade_text := _vbox(upgrade_row); upgrade_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text(upgrade_text,spec.upgrade_title,60,85,Color("e8f8ff"))
	_price_row = _hbox(upgrade_text); _minimum(_price_row,Vector2(0,75))
	if not spec.maximum:
		_price_icon = _image(_price_row,"ui/hud/icons/gold.png",69,68)
		_price_gap = _space(_price_row,7)
	_price_text = spec.price
	_price_label = _text(_price_row,_price_text,50,75,Color("e7c66a"))
	_price_label.name = "TurretUpgradePrice"
	_price_row.resized.connect(_fit_price)
	_space(row,30); _image(row,ROOT+"ref_identity_divider.png",8,207); _space(row,42)
	sell_action = _action(row,"TurretSellAction","sell",145,167,spec.sell_callback)
	var sale_content := _margin(sell_action,20,14,20,0,true)
	var sale := _vbox(sale_content)
	_image(sale,ROOT+"ref_sell.png",93,70).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sale_title := _text(sale,"판매",40,60,Color("b9d6e4")); sale_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tab_margin := _margin(self,217,0,224,0)
	var tabs := _hbox(tab_margin); _space(tabs,0)
	for entry in [["stats","스탯",754],["gems","젬 링크",766]]:
		if entry[0] == "gems": _space(tabs,11)
		var selected: bool = spec.active_tab == entry[0]
		var button := _action(tabs,"TurretStatsTab" if entry[0] == "stats" else "TurretGemsTab","tab_active" if selected else "tab_idle",entry[2],130,spec.stats_callback if entry[0] == "stats" else spec.gems_callback)
		button.toggle_mode = true; button.button_pressed = selected
		var content := _margin(button,0,12,0,12,true)
		var title := _text(content,entry[1],60,106,Color("e8f8ff") if selected else Color("b9d6e4"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(_fit)
	_fit()

static func _theme() -> Theme:
	if _skin != null: return _skin
	_skin = Theme.new()
	for kind in ["header","upgrade","traits","sell","tab_active","tab_idle"]:
		var variation: String = "Turret"+kind.to_pascal_case()
		var base := "PanelContainer" if kind == "header" else "Button"
		_skin.set_type_variation(variation,base)
		for state in (["panel"] if kind == "header" else ["normal","hover","pressed","disabled","focus"]):
			var style := StyleBoxTexture.new()
			style.texture = Art.texture(ROOT+"native/"+kind+".png")
			style.set_texture_margin_all(5 if kind == "header" else (4 if kind == "sell" else 9))
			# Frame corners and inner content margins are independent.
			style.set_content_margin_all(0)
			if state == "disabled": style.modulate_color = Color("65777b")
			elif state == "pressed": style.modulate_color = Color("8ca7b2")
			elif state in ["hover","focus"]: style.modulate_color = Color("c9edff")
			_skin.set_stylebox(state,variation,style)
	return _skin

func _action(parent: Node,node_name: String,kind: String,width: float,height: float,callback: Callable) -> Button:
	var button := Button.new(); button.name = node_name
	button.theme_type_variation = "Turret"+kind.to_pascal_case()
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_expand(button,width); _minimum(button,Vector2(0,height))
	button.pressed.connect(callback); parent.add_child(button)
	return button

func _margin(parent: Node,left: float,top: float,right: float,bottom: float,action_content := false) -> MarginContainer:
	var margin := MarginContainer.new(); margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_meta("design_margins",Vector4(left,top,right,bottom)); parent.add_child(margin)
	if action_content:
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		parent.set_meta("action_content",margin)
	return margin

func _hbox(parent: Node) -> HBoxContainer:
	var box := HBoxContainer.new(); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation",0); parent.add_child(box); return box

func _vbox(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new(); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation",0); box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(box); return box

func _image(parent: Node,path: String,width: float,height: float,crop_transparent := false) -> TextureRect:
	var image := TextureRect.new(); image.texture = _turret_icon(path) if crop_transparent else Art.texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE; image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_minimum(image,Vector2(width,height)); parent.add_child(image); return image

static func _turret_icon(path: String) -> Texture2D:
	if _turret_icons.has(path): return _turret_icons[path]
	var source := Art.texture(path)
	if source == null: return null
	# Reuse the approved 3D render; crop only its transparent padding, once per kind.
	var used := source.get_image().get_used_rect()
	if used.has_area():
		var atlas := AtlasTexture.new(); atlas.atlas = source; atlas.region = used
		atlas.filter_clip = true; _turret_icons[path] = atlas
	else: _turret_icons[path] = source
	return _turret_icons[path]

func _text(parent: Node,value: String,font_size: int,height: float,color: Color) -> Label:
	var label := Art.label(value,font_size); label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color",color)
	label.set_meta("design_font",font_size); _minimum(label,Vector2(0,height))
	parent.add_child(label); label.resized.connect(_fit_label.bind(label)); return label

func _space(parent: Node,width: float) -> Control:
	var space := Control.new(); space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimum(space,Vector2(width,0)); parent.add_child(space); return space

func _minimum(control: Control,value: Vector2) -> void: control.set_meta("design_minimum",value)
func _expand(control: Control,ratio: float) -> void:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL; control.size_flags_stretch_ratio = ratio

func _fit() -> void:
	_ratio = maxf(size.x,1.0)/1972.0
	for node in [self]+find_children("*","Control",true,false):
		if node.has_meta("design_minimum"): node.custom_minimum_size = node.get_meta("design_minimum")*_ratio
		if node.has_meta("design_font"):
			node.add_theme_font_size_override("font_size",maxi(1,roundi(float(node.get_meta("design_font"))*_ratio)))
			_fit_label(node)
		if node.has_meta("design_margins"):
			var margins: Vector4 = node.get_meta("design_margins")*_ratio
			for pair in [["left",margins.x],["top",margins.y],["right",margins.z],["bottom",margins.w]]: node.add_theme_constant_override("margin_"+pair[0],roundi(pair[1]))
		if node.has_meta("design_separation"): node.add_theme_constant_override("separation",roundi(float(node.get_meta("design_separation"))*_ratio))

func _fit_label(label: Label) -> void:
	if label == _price_label and _price_icon != null:
		_fit_price(); return
	if label.size.x <= 0: return
	var desired := maxi(1,roundi(float(label.get_meta("design_font"))*_ratio))
	var text_width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,desired).x
	var fitted := desired if text_width <= label.size.x else maxi(1,floori(desired*label.size.x/text_width))
	label.add_theme_font_size_override("font_size",fitted)

func _fit_price() -> void:
	if _price_label == null or _price_icon == null or _price_row.size.x <= 0: return
	var desired := maxi(8,roundi(50.0*_ratio))
	var font := _price_label.get_theme_font("font")
	var full_width := font.get_string_size(_price_text,HORIZONTAL_ALIGNMENT_LEFT,-1,desired).x
	var compact := full_width > _price_row.size.x-ceilf(69.0*_ratio)-ceilf(7.0*_ratio)
	# The gold icon already identifies the currency. When space is tight, keep
	# every digit at the normal readable price size and reduce only redundant art.
	_price_label.text = _price_text.trim_suffix(" G") if compact else _price_text
	_price_icon.custom_minimum_size = Vector2(42,42)*_ratio if compact else Vector2(69,68)*_ratio
	_price_gap.custom_minimum_size.x = 0.0 if compact else 7.0*_ratio
	_price_label.add_theme_font_size_override("font_size",desired)
	_price_label.tooltip_text = _price_text
