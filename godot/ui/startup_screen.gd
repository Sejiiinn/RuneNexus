extends Control
## Native port of AppStartupScreen/AppUpdateGate. No game or save dependencies.
const T = preload("res://ui/app_theme.gd")
var state: Dictionary = {}
var action: Callable
var continue_action: Callable
var text_scale_override := 0.0
var background: TextureRect
var outer: ScrollContainer
var column: VBoxContainer
var notes_scroll: ScrollContainer
var status_label: Label
var primary_button: Button
var continue_button: Button
var _flow: Control
var _track: Control
var _progress := -1.0
var _elapsed := 0.0

func _ready() -> void:
	name = "StartupScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black=ColorRect.new();black.color=Color("02070d");black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(black)
	background=TextureRect.new();background.texture=T.texture("main_menu_background.jpg");background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	var shade=TextureRect.new();shade.texture=_gradient([Color("02070d24"),Color("02070d00"),Color("02070d92"),Color("02070ded")],[0.0,0.36,0.72,1.0]);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	outer=ScrollContainer.new();outer.name="StartupOuterScroll";outer.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(outer)
	column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",0);outer.add_child(column)
	resized.connect(_layout)
	_layout()

func _font_size(value: int) -> int:
	if text_scale_override>0: return roundi(value*text_scale_override)
	if Engine.has_singleton("RuneNexusPlatform"):
		return maxi(1,roundi(Engine.get_singleton("RuneNexusPlatform").sp_to_logical(float(value))))
	return value

func present(value: Dictionary, primary: Callable = Callable(), secondary: Callable = Callable()) -> void:
	state=value.duplicate(true);action=primary;continue_action=secondary
	if is_instance_valid(column): _layout()

func _insets() -> Vector4:
	if not OS.has_feature("mobile"): return Vector4.ZERO
	var screen=Vector2(DisplayServer.screen_get_size())
	if screen.x<=0 or screen.y<=0: return Vector4.ZERO
	var ratio=size/screen
	var safe=DisplayServer.get_display_safe_area()
	var result=Vector4(safe.position.x,safe.position.y,screen.x-safe.end.x,screen.y-safe.end.y)
	if OS.has_feature("android"):
		result=Vector4.ZERO
		for value in DisplayServer.get_display_cutouts():
			var rect=Rect2(value)
			var edges=[rect.position.y,screen.y-rect.end.y,rect.position.x,screen.x-rect.end.x]
			match edges.find(edges.min()):
				0: result.y=maxf(result.y,rect.end.y)
				1: result.w=maxf(result.w,screen.y-rect.position.y)
				2: result.x=maxf(result.x,rect.end.x)
				3: result.z=maxf(result.z,screen.x-rect.position.x)
	return result*Vector4(ratio.x,ratio.y,ratio.x,ratio.y)

func _layout() -> void:
	if not is_instance_valid(column): return
	if background.texture!=null:
		var dimensions=background.texture.get_size()
		var scale_factor=maxf(size.x/dimensions.x,size.y/dimensions.y)
		background.size=dimensions*scale_factor;background.position=Vector2((size.x-background.size.x)/2,0)
	var inset=_insets()
	outer.offset_left=inset.x;outer.offset_top=inset.y;outer.offset_right=-inset.z;outer.offset_bottom=-inset.w
	var available=size-Vector2(inset.x+inset.z,inset.y+inset.w)
	for child in column.get_children(): column.remove_child(child);child.queue_free()
	notes_scroll=null;primary_button=null;continue_button=null;_flow=null;_track=null
	var bounded=state.get("details",false)
	var scale_factor=float(_font_size(13))/13.0
	var height=maxf(available.y,520.0*scale_factor) if bounded else available.y
	column.custom_minimum_size.y=height
	var width=maxf(1,minf(420,available.x-56))
	var top=12.0 if bounded else clampf(available.y*0.09,24,72)
	_space(column,top)
	var logo_width=minf(240 if bounded else 310,available.x-56)
	_image(column,"rune_nexus_logo_serif.png",Vector2(logo_width,logo_width*80/355))
	_space(column,18)
	var separator=TextureRect.new();separator.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;separator.texture=_gradient([Color("e7c66a00"),Color("e7c66a99"),Color("e7c66a00")],[0.0,0.5,1.0],false);separator.custom_minimum_size=Vector2(96,1);separator.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;column.add_child(separator)
	_space(column,12 if bounded else 24,not bounded)
	var core=clampf(available.y*0.10,48,100) if bounded else clampf(available.y*0.30,100,230)
	_image(column,"core_passive_tree/nexus_core.png",Vector2.ONE*core)
	_space(column,8 if bounded else 24,not bounded)
	var center=HBoxContainer.new();center.add_theme_constant_override("separation",0);center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;center.size_flags_vertical=Control.SIZE_EXPAND_FILL if bounded else Control.SIZE_FILL;column.add_child(center)
	var left=Control.new();left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;center.add_child(left)
	var details=VBoxContainer.new();details.name="StartupDetails";details.custom_minimum_size.x=width;details.size_flags_vertical=Control.SIZE_EXPAND_FILL if bounded else Control.SIZE_FILL;details.add_theme_constant_override("separation",0);center.add_child(details)
	var right=Control.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;center.add_child(right)
	status_label=_label(details,str(state.get("status","게임 준비 중")),14,Color("e8f8ff"));status_label.name="StartupStatus"
	if state.get("busy",true):
		_space(details,18);_progress_bar(details,float(state.get("progress",-1)))
	if bounded:
		_space(details,20)
		if state.get("required",false) and not state.get("version","").is_empty():
			_label(details,"게임을 시작하려면 업데이트를 완료해 주세요.",13);_space(details,12)
		if not state.get("version","").is_empty():
			_label(details,str(state.version),13,Color("50cadd"))
		if not state.get("transfer","").is_empty(): _label(details,str(state.transfer),13)
		if not state.get("notes","").is_empty():
			_space(details,16);_notes(details,str(state.notes),width)
		if not state.get("error","").is_empty():
			_space(details,16);_label(details,str(state.error),13,Color("ffb869"))
		if not state.get("message","").is_empty():
			_space(details,16);_label(details,str(state.message),13)
		_space(details,24)
		primary_button=_button(details,str(state.get("action","다시 시도")),action,true)
		primary_button.name="StartupAction";primary_button.disabled=state.get("busy",false)
		if state.get("can_continue",false):
			_space(details,10);continue_button=_button(details,"현재 버전으로 계속",continue_action,false)
			continue_button.name="StartupContinue";continue_button.disabled=state.get("busy",false)
	_space(column,16 if bounded else 54)

static func _gradient(colors: Array, offsets: Array, vertical:=true) -> GradientTexture2D:
	var gradient=Gradient.new();gradient.colors=PackedColorArray(colors);gradient.offsets=PackedFloat32Array(offsets)
	var texture=GradientTexture2D.new();texture.gradient=gradient;texture.fill_from=Vector2.ZERO;texture.fill_to=Vector2(0,1) if vertical else Vector2(1,0);return texture

func _space(parent: Node, height: float, expand:=false) -> void:
	var spacer=Control.new();spacer.custom_minimum_size.y=height;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if expand: spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _image(parent: Node, path: String, dimensions: Vector2) -> void:
	var picture=TextureRect.new();picture.texture=T.texture(path);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size=dimensions;picture.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(picture)

func _label(parent: Node, value: String, points: int, color:=Color("b9d6e4")) -> Label:
	var label=T.label(value,_font_size(points));label.add_theme_font_override("font",T.font(600));label.add_theme_color_override("font_color",color);label.add_theme_constant_override("line_spacing",roundi(_font_size(points)*0.35));label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;parent.add_child(label);return label

func _button(parent: Node, text: String, callback: Callable, primary: bool) -> Button:
	var button=Button.new();button.text=text;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.custom_minimum_size.y=52;button.add_theme_font_override("font",T.font(700));button.add_theme_font_size_override("font_size",_font_size(14));button.add_theme_color_override("font_color",Color("bff4ff") if primary else Color("b9d6e4"));button.add_theme_color_override("font_disabled_color",Color("4d606e"))
	var fill=TextureRect.new();fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;fill.texture=_gradient([Color("245567cc"),Color("102530e6"),Color("183f4ecc")] if primary else [Color("111c25cc"),Color("050b11ee")],[0.0,0.5,1.0] if primary else [0.0,1.0]);fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fill.offset_left=8;fill.offset_top=8;fill.offset_right=-8;fill.offset_bottom=-8;fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;fill.show_behind_parent=true;button.add_child(fill)
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var box=StyleBoxTexture.new();box.texture=T.texture("ui/components/button_frame.png");box.set_texture_margin_all(18);box.content_margin_left=22;box.content_margin_right=22;box.content_margin_top=17;box.content_margin_bottom=17
		if state_name=="disabled": box.modulate_color.a=0.45
		button.add_theme_stylebox_override(state_name,box)
	if callback.is_valid(): button.pressed.connect(callback)
	parent.add_child(button);return button

static func note_entries(notes: String) -> Array[String]:
	var expression=RegEx.create_from_string("\\r\\n?|\\n|(?<=[.!?])\\s+")
	var normalized=expression.sub(notes,"\n",true)
	var entries: Array[String]=[]
	var bullet=RegEx.create_from_string("^[-*•]\\s+")
	for line in normalized.split("\n"):
		var value=bullet.sub(line.strip_edges(),"")
		if not value.is_empty(): entries.append(value)
	return entries

func _notes(parent: Node, notes: String, width: float) -> void:
	var panel=PanelContainer.new();panel.name="ReleaseNotes";panel.custom_minimum_size.y=110;panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var box=StyleBoxFlat.new();box.bg_color=Color("08151ed9");box.border_color=Color("50cadd3d");box.set_border_width_all(1);box.set_corner_radius_all(8);box.content_margin_left=14;box.content_margin_right=6;box.content_margin_top=12;box.content_margin_bottom=12;panel.add_theme_stylebox_override("panel",box);parent.add_child(panel)
	var content=VBoxContainer.new();content.add_theme_constant_override("separation",10);panel.add_child(content)
	var heading=_label(content,"업데이트 내용",13,Color("e8f8ff"));heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;heading.add_theme_font_override("font",T.font(700))
	notes_scroll=ScrollContainer.new();notes_scroll.name="ReleaseNotesScroll";notes_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;notes_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS;notes_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;notes_scroll.custom_minimum_size.y=48;content.add_child(notes_scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",10);notes_scroll.add_child(list)
	for entry in note_entries(notes):
		var line=HBoxContainer.new();line.add_theme_constant_override("separation",8);list.add_child(line)
		var bullet=_label(line,"•",13,Color("50cadd"));bullet.custom_minimum_size.x=_font_size(13);bullet.autowrap_mode=TextServer.AUTOWRAP_OFF;bullet.vertical_alignment=VERTICAL_ALIGNMENT_TOP
		var label=_label(line,entry,13);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.custom_minimum_size.x=maxf(1,width-64)

func _progress_bar(parent: Node, value: float) -> void:
	_progress=value
	var frame=PanelContainer.new();frame.name="StartupProgress";frame.custom_minimum_size.y=24
	var box=StyleBoxTexture.new();box.texture=T.texture("ui/components/button_frame.png");box.set_texture_margin_all(16);box.set_content_margin_all(8);frame.add_theme_stylebox_override("panel",box);parent.add_child(frame)
	_track=ColorRect.new();_track.color=Color("061219");_track.custom_minimum_size.y=8;_track.clip_contents=true;frame.add_child(_track)
	_flow=TextureRect.new();_flow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_flow.texture=_gradient([Color("bff4ff"),Color("50cadd"),Color("146781")],[0.0,0.5,1.0]);_flow.mouse_filter=Control.MOUSE_FILTER_IGNORE;_track.add_child(_flow)

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(_track) or not is_instance_valid(_flow): return
	_elapsed=fposmod(_elapsed+delta,1.8)
	var reduced=ProjectSettings.get_setting("accessibility/disable_animations",false)
	var ratio=clampf(_progress,0,1) if _progress>=0 else (1.0 if reduced else 0.38)
	_flow.size=Vector2(_track.size.x*ratio,8)
	_flow.position=Vector2(0 if _progress>=0 or reduced else _track.size.x*(1.38*_elapsed/1.8-0.38),0)
	_flow.modulate=Color("183a46") if reduced and _progress<0 else Color.WHITE
