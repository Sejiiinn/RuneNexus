extends Control
## Home-only port of main_menu_lobby.dart. Other menu pages keep their own theme.
const ModalFrame = preload("res://ui/game_modal_frame.gd")
const Assets = preload("res://ui/app_theme.gd")
const Device = preload("res://app/device_preferences.gd")
const Quests = preload("res://app/quest_progress.gd")
const PRIMARY := Color("e8f8ff")
const SECONDARY := Color("b9d6e4")
var lobby
var canvas: Control
var background: TextureRect
var pedestal: TextureRect
var modal: Control
var modal_frame: Control
var modal_height := 0.0
var fonts: Dictionary = {}
var modal_scroll: ScrollContainer
var modal_content: VBoxContainer
var text_scale := 1.0
var _platform: Object
var _android_metrics: Object
var _typed_value: Object
var _font_sizes: Dictionary = {}
var _focus_refresh_pending := false

# Android's SP conversion includes its nonlinear large-text curves. This reads
# the actual device configuration, not a game-only accessibility preference.
func _refresh_text_scale() -> void:
	_platform = null
	_android_metrics = null
	_typed_value = null
	_font_sizes.clear()
	if OS.has_feature("android") and Engine.has_singleton("RuneNexusPlatform"):
		_platform = Engine.get_singleton("RuneNexusPlatform")
	text_scale = float(_font_size(14)) / 14.0

func _font_size(logical: int) -> int:
	if not _font_sizes.has(logical):
		var pixels := float(logical)
		if _platform != null:
			var converted := float(_platform.sp_to_logical(float(logical)))
			if is_finite(converted) and converted > 0:
				pixels = converted
		elif _android_metrics != null and _typed_value != null:
			# Java public fields are not exposed as GDScript properties on Android.
			# Convert one DP through the same API instead of reading metrics.density.
			var pixels_per_dp := float(_typed_value.applyDimension(1, 1.0, _android_metrics))
			var pixels_per_sp := float(_typed_value.applyDimension(2, float(logical), _android_metrics))
			if is_finite(pixels_per_dp) and pixels_per_dp > 0 and is_finite(pixels_per_sp) and pixels_per_sp > 0:
				pixels = pixels_per_sp / pixels_per_dp
		_font_sizes[logical] = maxi(1, roundi(pixels))
	return int(_font_sizes[logical])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(canvas):
		# Focus notifications traverse children; rebuilding here mutates a busy tree.
		if _focus_refresh_pending: return
		_focus_refresh_pending = true
		_refresh_after_focus.call_deferred()

func _refresh_after_focus() -> void:
	_focus_refresh_pending = false
	if not is_inside_tree() or not is_instance_valid(canvas): return
	var title := str(modal.get_meta("home_dialog_title", "")) if is_instance_valid(modal) else ""
	_layout()
	if title == "설정": open_settings()
	elif title == "이벤트": open_events()


func _ready() -> void:
	name = "Home"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A local theme deliberately isolates home from the interim metal-button theme.
	theme = Theme.new()
	theme.default_font = _font(700)
	theme.default_font_size = 12
	background = _image(self, "lobby_sanctuary_background.png", Rect2())
	background.stretch_mode = TextureRect.STRETCH_SCALE
	pedestal = _image(self, "lobby_rune_pedestal.png", Rect2())
	canvas = Control.new()
	canvas.name = "MenuCanvas"
	add_child(canvas)
	resized.connect(_layout)
	_layout()

func _font(weight: int) -> Font:
	if not fonts.has(weight):
		var font := FontVariation.new()
		font.base_font = load("res://assets/ui/NotoSansKR-VF.ttf") if ResourceLoader.exists("res://assets/ui/NotoSansKR-VF.ttf") else ThemeDB.fallback_font
		font.variation_opentype = {2003265652: float(weight)}
		fonts[weight] = font
	return fonts[weight]

func _insets() -> Vector4:
	if not OS.has_feature("mobile"): return Vector4.ZERO
	var area := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var ratio := size / Vector2(screen)
	if OS.has_feature("android"):
		# The --app Android host hides both system bars. Godot's safe-area
		# rect loses the cutout origin on the test device (142px top becomes bottom).
		# Derive the physical cutout edges directly for this fullscreen home.
		return _cutout_insets(DisplayServer.get_display_cutouts(), Vector2(screen)) * Vector4(ratio.x, ratio.y, ratio.x, ratio.y)
	return Vector4(area.position.x * ratio.x, area.position.y * ratio.y, (screen.x - area.end.x) * ratio.x, (screen.y - area.end.y) * ratio.y)

static func _cutout_insets(cutouts: Array, screen: Vector2) -> Vector4:
	var inset := Vector4.ZERO
	for value in cutouts:
		var rect := Rect2(value)
		var distance := [rect.position.y, screen.y - rect.end.y, rect.position.x, screen.x - rect.end.x]
		match distance.find(distance.min()):
			0: inset.y = maxf(inset.y, rect.end.y)
			1: inset.w = maxf(inset.w, screen.y - rect.position.y)
			2: inset.x = maxf(inset.x, rect.end.x)
			3: inset.z = maxf(inset.z, screen.x - rect.position.x)
	return inset

func _layout() -> void:
	if not is_instance_valid(canvas): return
	var scene_scale := maxf(size.x / 853.0, size.y / 1844.0)
	var scene_size := Vector2(853, 1844) * scene_scale
	background.position = Vector2((size.x - scene_size.x) / 2, 0)
	background.size = scene_size
	var device_size := scene_size.x * 0.49
	pedestal.position = Vector2((size.x - device_size) / 2, scene_size.y * 0.417 - device_size * 0.92)
	pedestal.size = Vector2.ONE * device_size
	_refresh_text_scale()
	var inset := _insets()
	var available := size - Vector2(inset.x + inset.z, inset.y + inset.w)
	var width := minf(available.x, 460)
	var height := maxf(available.y, width / 853 * 1844 * 0.5 + 400 + clampf(text_scale - 1, 0, 3) * 250 + inset.y + inset.w)
	var fit := minf(1, available.y / height)
	canvas.position = Vector2(inset.x, inset.y) + (available - Vector2(width, height) * fit) / 2
	canvas.size = Vector2(width, height)
	canvas.scale = Vector2.ONE * fit
	_build_canvas(width, height)
	_layout_modal()

func _build_canvas(w: float, h: float) -> void:
	for child in canvas.get_children():
		canvas.remove_child(child)
		child.queue_free()
	var active: bool = lobby._has_run()
	var blocked: bool = lobby.app.get("startup_blocked") == true
	var settings_width := maxf(84, 52 + _font(700).get_string_size("설정",HORIZONTAL_ALIGNMENT_LEFT,-1,_font_size(12)).x)
	var settings_height := maxf(40, _font_size(12) * 1.25 + 12)
	var settings := _shortcut(canvas, "Settings", "설정", "lobby_settings_icon.png", Rect2(w - 16 - settings_width, 6, settings_width, settings_height), true, open_settings, 28)
	settings.tooltip_text = "설정"
	_image(canvas, "rune_nexus_logo_serif.png", Rect2((w - 208) / 2, 6 + settings_height, 208, 52))
	var top := 6 + maxf(160, w / 853 * 1844 * 0.5 - 6)
	var title_h := 21.0 * _font_size(20) / 20.0
	var detail_h := 15.0 * _font_size(12) / 12.0
	var action_h := maxf(48, 20 + detail_h)
	var panel_h: float = 79.4 + title_h - 21 + detail_h - 15 + (18 + action_h if active else 0)
	_surface(canvas, Rect2(44, top, w - 88, panel_h), "panel")
	var title := "스테이지 %d" % (int(lobby.app.run_domain.state.get("stage", 0)) + 1) if active else "전투 준비"
	_label(canvas, title, Rect2(62, top + 18, w - 124, title_h), 20, 900, PRIMARY, true)
	var detail := "도전할 스테이지를 선택하세요"
	if active:
		var state: Dictionary = lobby.app.run_domain.state
		var stage: Dictionary = lobby.app.catalog.stage(int(state.stage))
		detail = "%d / %d 라운드" % [mini(int(state.get("roundIndex", 0)) + 1, stage.waves.size()), stage.waves.size()]
	_label(canvas, detail, Rect2(62, top + 26 + title_h, w - 124, detail_h), 12, 700, SECONDARY, true)
	if active:
		_stage_button(canvas, "ContinueRun", "이어서 진행", Rect2(62, top + panel_h - 18 - action_h, w - 124, action_h), false, func():
			if not lobby.app.resume_run(): lobby._failure()
		).disabled = blocked
	# Bottom content is anchored within the same fitted canvas, never a ScrollContainer.
	var bottom_lines := 1
	for value in ["넥서스 코어","영구 강화","연구","포탑 모듈"]:
		bottom_lines = maxi(bottom_lines,ceili(_font(700).get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,_font_size(12)).x / maxf(1,(w-40)/4-6)))
	var bottom_h := 78.4 + detail_h * bottom_lines - 15
	var bottom_y := h - 12 - bottom_h
	var stage_height := maxf(56, 20 + detail_h)
	var stage_y := bottom_y - 14 - stage_height
	var third := (w - 32) / 3
	var shortcut_lines := ceili(_font(700).get_string_size("리더보드",HORIZONTAL_ALIGNMENT_LEFT,-1,_font_size(12)).x / maxf(1,third-48))
	var shortcut_height := maxf(40, 16 + detail_h * shortcut_lines)
	var shortcuts_y := stage_y - 8 - shortcut_height
	var strip := Panel.new()
	strip.position = Vector2(16, shortcuts_y)
	strip.size = Vector2(w - 32, shortcut_height)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("101a24ad")
	box.border_color = Color("7e929f40")
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	strip.add_theme_stylebox_override("panel", box)
	canvas.add_child(strip)
	_shortcut(canvas, "Leaderboard", "리더보드", "lobby_leaderboard_icon.png", Rect2(16, shortcuts_y, third, shortcut_height), true, open_service.bind("리더보드"))
	_shortcut(canvas, "Events", "이벤트", "lobby_event_icon.png", Rect2(16 + third, shortcuts_y, third, shortcut_height), true, open_events)
	_shortcut(canvas, "Mailbox", "우편함", "lobby_mailbox_icon.png", Rect2(16 + third * 2, shortcuts_y, third, shortcut_height), true, open_service.bind("우편함"))
	for i in [1, 2]:
		var line := ColorRect.new()
		line.color = Color("7e929f40")
		line.position = Vector2(16 + third * i, shortcuts_y + 10)
		line.size = Vector2(1, 20)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(line)
	if _claimable():
		var dot := Panel.new()
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = Color("8ee6ff")
		dot_style.set_corner_radius_all(4)
		dot.add_theme_stylebox_override("panel", dot_style)
		dot.position = Vector2(16 + third + 28, shortcuts_y + 8)
		dot.size = Vector2(7, 7)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(dot)
	_stage_button(canvas, "StageSelect", "스테이지 선택", Rect2(44, stage_y, w - 88, stage_height), true, lobby.open_page.bind("스테이지"), "stage_rewards/reward_stage.png").disabled = blocked
	_surface(canvas, Rect2(16, bottom_y, w - 32, bottom_h), "panel")
	var entries := [["Core", "넥서스 코어", "core", "코어"], ["Upgrades", "영구 강화", "upgrade", "강화"], ["Research", "연구", "research", "연구"], ["Modules", "포탑 모듈", "turret", "포탑"]]
	for i in range(4):
		var e: Array = entries[i]
		_shortcut(canvas, e[0], e[1], "stage_rewards/reward_%s.png" % e[2], Rect2(20 + (w - 40) / 4 * i, bottom_y + 6, (w - 40) / 4, bottom_h - 12), false, lobby.open_page.bind(e[3]))
	if blocked:
		var services = lobby.app.get("services")
		var waiting_for_update: bool = services != null and services.updates != null and services.updates.blocked
		var status := "업데이트 확인을 완료하면 저장을 불러옵니다." if waiting_for_update else "저장을 불러오지 못했습니다. 기존 저장은 보존됩니다."
		_label(canvas, status, Rect2(44, top + panel_h + 6, w - 88, 32), 12, 700, SECONDARY, true).name = "StartupStatus"
		if waiting_for_update:
			_stage_button(canvas, "RetryUpdate", "업데이트 확인", Rect2(62, top + panel_h + 40, w - 124, 48), false, func(): lobby._service("업데이트"))
		else:
			_stage_button(canvas, "RetryLoad", "다시 불러오기", Rect2(62, top + panel_h + 40, w - 124, 48), false, func(): lobby.app.retry_load())
	elif not lobby.message.is_empty():
		_label(canvas, lobby.message, Rect2(44, top + panel_h + 8, w - 88, 45), 12, 700, SECONDARY, true)

func _claimable() -> bool:
	var p: Dictionary = lobby._p()
	for period in ["daily", "weekly"]:
		if p.get("dailyQuestClockRollbackDetected", false): continue
		if period == "daily" and not p.get("dailyAttendanceRewardClaimed", false): return true
		if period == "weekly" and p.get("weeklyAttendanceDayKeys", []).size() >= 5 and not p.get("weeklyAttendanceRewardClaimed", false): return true
		var targets: Dictionary = Quests.DAILY if period == "daily" else Quests.WEEKLY
		var completed := 0
		for key in targets:
			if int(p.get(period + "QuestProgress", {}).get(key, 0)) >= int(targets[key]):
				completed += 1
				if key not in p.get("claimed" + period.capitalize() + "QuestRewards", []): return true
		if completed == targets.size() and not p.get(period + "QuestAllCompleteClaimed", false): return true
	return false

func _image(parent: Control, asset: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = Assets.texture(asset)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _label(parent: Control, value: String, rect: Rect2, font_size: int = 12, weight: int = 700, color: Color = SECONDARY, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", _font(weight))
	label.add_theme_font_size_override("font_size", _font_size(font_size))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if weight == 900:
		label.add_theme_color_override("font_shadow_color", Color("02070d"))
		label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _button(parent: Control, id: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.position = rect.position
	button.size = rect.size
	for state in ["normal", "disabled", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["hover", "pressed"]:
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color(0.56, 0.9, 1, 0.06 if state == "hover" else 0.13)
		highlight.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, highlight)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _shortcut(parent: Control, id: String, text: String, asset: String, rect: Rect2, horizontal: bool, action: Callable, icon_size: float = 0) -> Button:
	var button := _button(parent, id, rect, action)
	button.tooltip_text = text
	var icon := icon_size if icon_size > 0 else (24.0 if horizontal else 38.0)
	_image(button, asset, Rect2(8 if horizontal else (rect.size.x - icon) / 2, (rect.size.y - icon) / 2 if horizontal else 5, icon, icon))
	_label(button, text, Rect2(icon + 16 if horizontal else 3, 0 if horizontal else 47, rect.size.x - icon - 24 if horizontal else rect.size.x - 6, rect.size.y if horizontal else maxf(15, rect.size.y - 51.4)), 12, 700, SECONDARY if id == "Settings" else PRIMARY, not horizontal)
	return button

func _surface(parent: Control, rect: Rect2, kind: String) -> void:
	var image := NinePatchRect.new()
	var asset := "ui/components/panel_frame.png" if kind == "panel" else "lobby_%s_button.png" % kind
	var density := 4.0 if kind == "panel" else 3.0
	var edge := Vector4(14, 14, 14, 14) if kind == "panel" else (Vector4(12, 14, 12, 14) if kind == "primary" else Vector4(10, 11, 10, 11))
	image.texture = Assets.texture(asset)
	image.position = rect.position
	image.size = rect.size * density
	image.scale = Vector2.ONE / density
	for side in range(4): image.set_patch_margin(side, int(edge[side] * density))
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func _stage_button(parent: Control, id: String, text: String, rect: Rect2, primary: bool, action: Callable, icon: String = "") -> Button:
	_surface(parent, rect, "primary" if primary else "secondary")
	var button := _button(parent, id, rect, action)
	button.tooltip_text = text
	if icon.is_empty():
		_label(button, text, Rect2(Vector2.ZERO, rect.size), 12, 900, PRIMARY, true)
	else:
		var text_width := _font(900).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(12)).x
		var start := (rect.size.x - text_width - 35) / 2
		_image(button, icon, Rect2(start, (rect.size.y - 25) / 2, 25, 25))
		_label(button, text, Rect2(start + 35, 0, text_width + 2, rect.size.y), 12, 900, PRIMARY, true)
	return button

func close_modal() -> bool:
	if not is_instance_valid(modal): return false
	ModalFrame.dismiss(modal)
	modal = null
	modal_frame = null
	return true

func _dialog(title: String, _height: float) -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.name = "HomeModal"
	modal.set_meta("home_dialog_title",title)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var barrier := ColorRect.new()
	barrier.color = Color("02070dd9")
	barrier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	barrier.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: close_modal()
	)
	modal.add_child(barrier)
	modal_frame = Control.new()
	modal_frame.name = "ModalFrame"
	modal_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(modal_frame)
	var frame_ref: WeakRef = weakref(modal_frame)
	modal_frame.draw.connect(func(): _draw_modal(frame_ref.get_ref()))
	modal_scroll = ScrollContainer.new()
	modal_scroll.name = "ModalScroll"
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_frame.add_child(modal_scroll)
	modal_content = VBoxContainer.new()
	modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_theme_constant_override("separation", 16)
	modal_scroll.add_child(modal_content)
	var header := HBoxContainer.new()
	modal_content.add_child(header)
	var heading := _modal_label(title, 20, 900)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := Button.new()
	close.name = "Close"
	close.text = "×"
	close.custom_minimum_size = Vector2(32,32)
	for state in ["normal", "disabled"]: close.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color("8ee6ff18") if state == "hover" else Color("8ee6ff30")
		highlight.set_corner_radius_all(4)
		if state == "focus":
			highlight.bg_color = Color.TRANSPARENT
			highlight.border_color = Color("b5f2ff")
			highlight.set_border_width_all(1)
		close.add_theme_stylebox_override(state, highlight)
	close.pressed.connect(close_modal)
	header.add_child(close)
	modal_content.minimum_size_changed.connect(_layout_modal)
	_layout_modal()
	_layout_modal.call_deferred()
	Assets.animate_modal(modal_frame)
	return modal_content

func _modal_label(value: String, pixels := 12, weight := 700) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_override("font", _font(weight))
	result.add_theme_font_size_override("font_size", _font_size(pixels))
	result.add_theme_color_override("font_color", PRIMARY if weight == 900 else SECONDARY)
	return result

func _modal_button(parent: Control, id: String, value: String, callback: Callable) -> void:
	var holder := Control.new()
	holder.custom_minimum_size.y = maxf(48, _font_size(12) * 1.25 + 20)
	parent.add_child(holder)
	var button := _stage_button(holder, id, value, Rect2(0,0,modal_frame.size.x - 36,holder.custom_minimum_size.y), false, callback)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := button.get_child(0) as Label
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface := holder.get_child(0) as NinePatchRect
	var surface_ref: WeakRef = weakref(surface)
	var holder_ref: WeakRef = weakref(holder)
	holder.resized.connect(func():
		var current_surface = surface_ref.get_ref()
		var current_holder = holder_ref.get_ref()
		if current_surface != null and current_holder != null: current_surface.size = current_holder.size * 3
	)

func _layout_modal() -> void:
	if not is_instance_valid(modal_frame): return
	var inset := _insets()
	var available := size - Vector2(inset.x + inset.z, inset.y + inset.w)
	var width := minf(360, available.x - 48)
	modal_scroll.position = Vector2(18,18)
	modal_scroll.size.x = width - 36
	modal_content.size.x = width - 36
	modal_height = modal_content.get_combined_minimum_size().y + 36
	var height := minf(modal_height, available.y * 0.85)
	modal_frame.size = Vector2(width, height)
	modal_frame.scale = Vector2.ONE
	modal_scroll.size.y = maxf(0, height - 36)
	modal_frame.position = Vector2(inset.x, inset.y) + (available - modal_frame.size) / 2
	modal_frame.queue_redraw()

static func _draw_modal(frame: Control) -> void:
	if not is_instance_valid(frame): return
	if not frame.has_meta("frame_style"): frame.set_meta("frame_style",ModalFrame.create(Color("8fa8ba")))
	var style: StyleBox = frame.get_meta("frame_style")
	style.draw(frame.get_canvas_item(),Rect2(Vector2.ZERO,frame.size))

func open_events() -> void:
	var frame := _dialog("이벤트", 172)
	frame.add_child(_modal_label("출석과 일일·주간 퀘스트 보상을 확인하세요."))
	_modal_button(frame, "Quests", "출석 · 퀘스트", func(): lobby.open_page("퀘스트"))

func open_service(service: String) -> void:
	close_modal()
	lobby.open_service(service)

func open_settings() -> void:
	var frame := _dialog("설정", 362)
	_choices(frame, "MSAA · 테두리 부드럽게", "끄면 물체의 가장자리가 거칠어질 수 있습니다.", "msaa", [0, 2], ["끄기", "2배"], 2)
	frame.add_child(HSeparator.new())
	_choices(frame, "그림자 품질", "낮추면 그림자가 흐릿해지고, 끄면 사라집니다.", "shadow", [0, 512, 1024, 2048], ["끄기", "낮음", "중간", "높음"], 2048)
	_modal_button(frame, "Account", "계정 및 저장", open_service.bind("계정 및 저장"))

func _choices(frame: Control, title: String, description: String, key: String, values: Array, labels: Array, fallback: int) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	frame.add_child(section)
	section.add_child(_modal_label(title, 12, 900))
	section.add_child(_modal_label(description))
	var choices := HFlowContainer.new()
	choices.add_theme_constant_override("h_separation", 2)
	section.add_child(choices)
	var group := ButtonGroup.new()
	for i in range(values.size()):
		var radio := Button.new()
		radio.name = "%s_%s" % [key, values[i]]
		radio.text = labels[i]
		radio.custom_minimum_size = Vector2(maxf(74, _font(700).get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(12)).x + 34), maxf(28, _font_size(12) * 1.25 + 8))
		radio.add_theme_font_override("font", _font(700))
		radio.add_theme_font_size_override("font_size", _font_size(12))
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var style := StyleBoxEmpty.new()
			style.content_margin_left = 26
			radio.add_theme_stylebox_override(state, style)
		radio.toggle_mode = true
		radio.button_group = group
		radio.button_pressed = Device.read().get(key, fallback) == values[i]
		choices.add_child(radio)
		radio.draw.connect(func():
			var color := Color("8ee6ff") if radio.button_pressed else SECONDARY
			var center := Vector2(10, radio.size.y / 2)
			radio.draw_arc(center, 7, 0, TAU, 32, color, 1.7, true)
			if radio.button_pressed: radio.draw_circle(center, 3.5, color)
		)
		radio.pressed.connect(func():
			var settings: Dictionary = Device.read()
			settings[key] = values[i]
			if Device.write(settings):
				Device.apply(lobby.app.scene.options)
				lobby.app.scene._apply_options()
				open_settings()
			else:
				var error_frame := _dialog("저장 실패", 172)
				error_frame.add_child(_modal_label("설정을 저장하지 못했습니다. 다시 시도해 주세요."))
				_modal_button(error_frame, "RetrySettings", "설정으로 돌아가기", open_settings)
		)
