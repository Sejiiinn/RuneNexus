extends Control
## Stage home: the chapter map is the first screen. Header switches chapters and shows
## the wallet; the card under the map starts the selected stage; shortcuts and the
## menu tabs sit at the bottom.
const Progression = preload("res://content/stage_progression.gd")
const ModalFrame = preload("res://ui/game_modal_frame.gd")
const Assets = preload("res://ui/app_theme.gd")
const Device = preload("res://app/device_preferences.gd")
const Quests = preload("res://app/quest_progress.gd")
const Numbers = preload("res://ui/hud_number.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const StageMap = preload("res://ui/stage_map_view.gd")
const StageCard = preload("res://ui/lobby_stage_card.gd")
const PRIMARY := Color("e8f8ff")
const SECONDARY := Color("b9d6e4")
const MAX_WIDTH := 460.0
var lobby
var canvas: Control
var backdrop: TextureRect
var map: Control
var card: Control
var footer: VBoxContainer
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
		_refresh_after_focus.call_deferred(weakref(modal) if is_instance_valid(modal) else null)

func _refresh_after_focus(modal_ref: WeakRef = null) -> void:
	_focus_refresh_pending = false
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(canvas): return
	_layout()
	if modal_ref == null or modal_ref.get_ref() != modal or not _dialog_active(): return
	var title := str(modal.get_meta("home_dialog_title", ""))
	if title == "설정": open_settings(true)
	elif title == "이벤트": open_events(true)


func _ready() -> void:
	name = "Home"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A local theme deliberately isolates home from the interim metal-button theme.
	theme = Theme.new()
	theme.default_font = _font(700)
	theme.default_font_size = 12
	var under := ColorRect.new()
	under.color = Color("03080c")
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(under)
	# Wider than the map column (desktop): the same painting, dimmed, fills the sides.
	backdrop = _image(self, "", Rect2())
	backdrop.name = "MapBackdrop"
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.32, 0.34, 0.4)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.name = "MenuCanvas"
	add_child(canvas)
	map = StageMap.new()
	map.stages = lobby.stages
	map.font_size = _font_size
	map.stage_pressed.connect(select_stage)
	canvas.add_child(map)
	footer = VBoxContainer.new()
	footer.name = "HomeFooter"
	add_child(footer)
	lobby._footer(footer)
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
	_refresh_text_scale()
	var inset := _insets()
	var available := size - Vector2(inset.x + inset.z, inset.y + inset.w)
	var width := minf(available.x, MAX_WIDTH)
	footer.position = Vector2(inset.x, size.y - inset.w - footer.get_combined_minimum_size().y)
	footer.size = Vector2(available.x, footer.get_combined_minimum_size().y)
	canvas.position = Vector2(inset.x + (available.x - width) / 2, inset.y)
	canvas.size = Vector2(width, footer.position.y - inset.y)
	map.position = Vector2.ZERO
	map.size = canvas.size
	refresh()
	_layout_modal()

## Rebuilds everything over the map; the map keeps its background and effects.
func refresh() -> void:
	if not is_instance_valid(canvas) or canvas.size.x <= 0: return
	lobby.stages.ensure_selection()
	var services = lobby.app.get("services")
	if services is Object and services.has_signal("changed") and not services.changed.is_connected(refresh_quest_indicator):
		services.changed.connect(refresh_quest_indicator)
	for child in canvas.get_children():
		if child == map: continue
		canvas.remove_child(child)
		child.queue_free()
	var w := canvas.size.x
	var h := canvas.size.y
	var blocked: bool = lobby.app.get("startup_blocked") == true
	backdrop.texture = Assets.texture("stage_map/chapter%d_map.jpg" % lobby.stages.chapter)
	backdrop.visible = size.x > w + 1
	# Bottom stack: shortcut strip over the tabs, the stage card over the strip.
	var detail_h := 15.0 * _font_size(12) / 12.0
	var strip_h := maxf(38, 14 + detail_h)
	var strip_y := h - 8 - strip_h
	var card_y := strip_y - 10 - StageCard.HEIGHT
	var title_h := 26.0 * _font_size(20) / 20.0
	var subtitle_h := 16.0 * _font_size(11) / 11.0
	var header_h := maxf(62, 12 + title_h + subtitle_h + 6)
	map.arrange(lobby.stages.chapter, header_h + 63, card_y - 58)
	map.refresh_nodes()
	_shade(Rect2(0, 0, w, header_h + 34), 0.92, 0.0)
	_shade(Rect2(0, card_y - 94, w, h - card_y + 94), 0.0, 0.95)
	_header(w, title_h, subtitle_h)
	card = StageCard.new()
	card.stages = lobby.stages
	card.font_size = _font_size
	card.position = Vector2(12, card_y)
	card.size = Vector2(w - 24, StageCard.HEIGHT)
	canvas.add_child(card)
	card.show_stage(lobby.stages.selected)
	_shortcuts(Rect2(12, strip_y, w - 24, strip_h))
	if blocked:
		var waiting_for_update: bool = services != null and services.updates != null and services.updates.blocked
		var status := "업데이트 확인을 완료하면 저장을 불러옵니다." if waiting_for_update else "저장을 불러오지 못했습니다. 기존 저장은 보존됩니다."
		_surface(canvas, Rect2(16, card_y - 108, w - 32, 98), "panel")
		_label(canvas, status, Rect2(28, card_y - 100, w - 56, 32), 12, 700, SECONDARY, true).name = "StartupStatus"
		if waiting_for_update:
			_stage_button(canvas, "RetryUpdate", "업데이트 확인", Rect2(40, card_y - 64, w - 80, 46), false, func(): lobby.open_service("업데이트"))
		else:
			_stage_button(canvas, "RetryLoad", "다시 불러오기", Rect2(40, card_y - 64, w - 80, 46), false, func(): lobby.app.retry_load())
	elif not lobby.message.is_empty():
		var note := _label(canvas, lobby.message, Rect2(16, card_y - 52, w - 32, 44), 12, 700, PRIMARY, true)
		note.name = "HomeMessage"
		note.add_theme_constant_override("outline_size", 5)
		note.add_theme_color_override("font_outline_color", Color("03080ce6"))

func select_stage(id: int) -> void:
	if id == lobby.stages.selected: return
	lobby.stages.selected = id
	map.refresh_nodes()
	card.show_stage(id)

func select_chapter(value: int) -> void:
	lobby.stages.select_chapter(value)
	refresh()

func _shade(rect: Rect2, top_alpha: float, bottom_alpha: float) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.03, 0.05, top_alpha))
	g.set_color(1, Color(0.01, 0.03, 0.05, bottom_alpha))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var t := TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = rect.position
	t.size = rect.size
	canvas.add_child(t)

func _header(w: float, title_h: float, subtitle_h: float) -> void:
	var chapter: int = lobby.stages.chapter
	var title: String = lobby.stages.CHAPTERS[chapter - 1]
	var wallet_w := maxf(88, 34 + _font(800).get_string_size(Numbers.compact_integer(maxi(lobby.diamonds(), int(lobby.progression().get("runes", 0)))), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(11)).x + 10)
	# The title gives way to the wallet; the next-chapter arrow always stays tappable.
	var title_w := minf(_font(900).get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(20)).x + 4, w - 54 - wallet_w - 34 - 34)
	_chapter_arrow("ChapterPrev", "‹", Rect2(4, 6, 30, title_h + 10), chapter - 1)
	var heading := _label(canvas, title, Rect2(34, 12, title_w, title_h), 20, 900, PRIMARY)
	heading.name = "ChapterTitle"
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.clip_text = true
	heading.size.x = title_w
	_chapter_arrow("ChapterNext", "›", Rect2(34 + title_w, 6, 30, title_h + 10), chapter + 1)
	var range_text := "챕터 %d · %d-1 – %d-10" % [chapter, chapter, chapter]
	var range_w := minf(_font(700).get_string_size(range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(11)).x + 4, w - 54 - wallet_w - 39)
	var subtitle := _label(canvas, range_text, Rect2(35, 12 + title_h + 2, range_w, subtitle_h), 11, 700, SECONDARY)
	subtitle.name = "ChapterRange"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.clip_text = true
	subtitle.size.x = maxf(0, range_w)
	# Wallet on the resource frame, settings at the corner.
	var row_h := maxf(18, 15.0 * _font_size(11) / 11.0)
	var wallet := Panel.new()
	wallet.name = "HomeWallet"
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_theme_stylebox_override("panel", Frame.new("ui/hud/resource_panel.png", 0))
	wallet.position = Vector2(w - 54 - wallet_w, 12)
	wallet.size = Vector2(wallet_w, maxf(42, row_h * 2 + 6))
	canvas.add_child(wallet)
	var rows := [["res://assets/ui/diamond_currency.png", lobby.diamonds(), "Diamonds"], ["ui/hud/icons/rune.png", int(lobby.progression().get("runes", 0)), "Runes"]]
	for i in 2:
		var y := (wallet.size.y - row_h * 2) / 2 + row_h * i
		_image(wallet, rows[i][0], Rect2(6, y + (row_h - 13) / 2, 13, 13))
		var value := _label(wallet, Numbers.compact_integer(rows[i][1]), Rect2(22, y, wallet_w - 28, row_h), 11, 800, PRIMARY)
		value.name = rows[i][2]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
	var settings := _button(canvas, "Settings", Rect2(w - 50, 11, 40, 40), open_settings)
	settings.tooltip_text = "설정"
	_image(settings, "lobby_settings_icon.png", Rect2(2, 2, 36, 36))

func _chapter_arrow(id: String, glyph: String, rect: Rect2, target: int) -> void:
	var enabled: bool = target >= 1 and target <= lobby.stages.CHAPTERS.size()
	var button := _button(canvas, id, rect, select_chapter.bind(target))
	button.disabled = not enabled
	button.tooltip_text = "이전 챕터" if glyph == "‹" else "다음 챕터"
	var label := _label(button, glyph, Rect2(Vector2.ZERO, rect.size), 26, 700, Color(PRIMARY, 0.85 if enabled else 0.3), true)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF

func _shortcuts(rect: Rect2) -> void:
	var strip := Panel.new()
	strip.name = "ShortcutStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dock := StyleBoxTexture.new()
	dock.texture = Assets.texture("ui/hud/dock_panel.png")
	dock.set_texture_margin_all(2)
	strip.add_theme_stylebox_override("panel", dock)
	strip.position = rect.position
	strip.size = rect.size
	canvas.add_child(strip)
	var third := rect.size.x / 3
	_shortcut(canvas, "Leaderboard", "리더보드", "lobby_leaderboard_icon.png", Rect2(rect.position.x, rect.position.y, third, rect.size.y), true, open_service.bind("리더보드"))
	_shortcut(canvas, "Events", "이벤트", "lobby_event_icon.png", Rect2(rect.position.x + third, rect.position.y, third, rect.size.y), true, open_events)
	_shortcut(canvas, "Mailbox", "우편함", "lobby_mailbox_icon.png", Rect2(rect.position.x + third * 2, rect.position.y, third, rect.size.y), true, open_service.bind("우편함"))
	for i in [1, 2]:
		var line := ColorRect.new()
		line.color = Color("7e929f40")
		line.position = Vector2(rect.position.x + third * i, rect.position.y + 9)
		line.size = Vector2(1, rect.size.y - 18)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(line)
	# Keep both indicators so receipt updates do not rebuild home.
	_alert_badge("QuestReadyDot", Vector2(rect.position.x + third + 26, rect.position.y + 6), _claimable())
	_alert_badge("MailboxReadyDot", Vector2(rect.position.x + third * 2 + 26, rect.position.y + 6), _mail_claimable())

func _alert_badge(id: String, at: Vector2, ready: bool) -> void:
	var dot := Panel.new()
	dot.name = id
	dot.visible = ready
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e53935")
	style.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", style)
	dot.position = at
	dot.size = Vector2(7, 7)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(dot)
	# Fixed-size strokes keep the white exclamation inside the original 7px circle.
	dot.draw.connect(func():
		dot.draw_rect(Rect2(3, 1, 1, 3), Color.WHITE)
		dot.draw_rect(Rect2(3, 5, 1, 1), Color.WHITE))

func refresh_quest_indicator() -> void:
	var dot := canvas.get_node_or_null("QuestReadyDot")
	if dot != null: dot.visible = _claimable()
	var mail_dot := canvas.get_node_or_null("MailboxReadyDot")
	if mail_dot != null: mail_dot.visible = _mail_claimable()

func _mail_claimable() -> bool:
	var services = lobby.app.get("services")
	return services is Object and services.has_method("has_unclaimed_mail") and services.has_unclaimed_mail()

func _claimable() -> bool:
	var p: Dictionary = lobby.progression()
	for period in ["daily", "weekly"]:
		if p.get("dailyQuestClockRollbackDetected", false): continue
		if period == "daily" and not p.get("dailyAttendanceRewardClaimed", false): return true
		if period == "weekly" and Quests.attendance_progress(p,period) >= 5 and not p.get("weeklyAttendanceRewardClaimed", false): return true
		var targets: Dictionary = Quests.DAILY if period == "daily" else Quests.WEEKLY
		for key in targets:
			if int(p.get(period + "QuestProgress", {}).get(key, 0)) >= int(targets[key]):
				if key not in p.get("claimed" + period.capitalize() + "QuestRewards", []): return true
		if Quests.completed_count(p,period) >= Quests.ALL_COMPLETE_REQUIRED and not p.get(period + "QuestAllCompleteClaimed", false): return true
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

func _dialog_active(title := "") -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(modal) \
		and modal.is_inside_tree() and not modal.is_queued_for_deletion() \
		and (title.is_empty() or modal.get_meta("home_dialog_title", "") == title)

func _dialog(title: String, _height: float, refresh := false) -> VBoxContainer:
	if refresh:
		if not _dialog_active(title): return null
		var scroll_y := modal_scroll.scroll_vertical
		var current_ref: WeakRef = weakref(modal)
		var scroll_ref: WeakRef = weakref(modal_scroll)
		for child in modal_content.get_children():
			modal_content.remove_child(child)
			child.queue_free()
		get_tree().process_frame.connect(func():
			if _dialog_active(title) and current_ref.get_ref() == modal and scroll_ref.get_ref() == modal_scroll:
				modal_scroll.scroll_vertical = scroll_y
		, CONNECT_ONE_SHOT)
	else:
		_create_dialog(title)
	_dialog_header(title)
	_layout_modal()
	_layout_modal.call_deferred()
	if not refresh: Assets.animate_modal(modal_frame)
	return modal_content

func _create_dialog(title: String) -> void:
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
	modal_content.minimum_size_changed.connect(_layout_modal)

func _dialog_header(title: String) -> void:
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

func open_events(refresh := false) -> void:
	var frame := _dialog("이벤트", 172, refresh)
	if frame == null: return
	frame.add_child(_modal_label("출석과 일일·주간 퀘스트 보상을 확인하세요."))
	_modal_button(frame, "Quests", "출석 · 퀘스트", func(): lobby.open_page("퀘스트"))

func open_service(service: String) -> void:
	close_modal()
	lobby.open_service(service)

func open_settings(refresh := false) -> void:
	var frame := _dialog("설정", 362, refresh)
	if frame == null: return
	_choices(frame, "MSAA · 테두리 부드럽게", "끄면 물체의 가장자리가 거칠어질 수 있습니다.", "msaa", [0, 2], ["끄기", "2배"], 2)
	frame.add_child(HSeparator.new())
	_choices(frame, "그림자 품질", "낮추면 그림자가 흐릿해지고, 끄면 사라집니다.", "shadow", [0, 512, 1024, 2048], ["끄기", "낮음", "중간", "높음"], 2048)
	frame.add_child(HSeparator.new())
	_choices(frame, "3D 렌더 해상도", "낮추면 가벼워지지만 전장이 흐려집니다.", "render_scale", [50, 75, 100], ["50%", "75%", "100%"], 100)
	frame.add_child(HSeparator.new())
	_choices(frame, "프레임 제한", "30은 발열이 줄지만 움직임이 덜 부드럽습니다.", "fps", [30, 60], ["30", "60"], 60)
	_modal_button(frame, "Account", "계정 및 저장", open_service.bind("계정 및 저장"))

func _choices(frame: Control, title: String, description: String, key: String, values: Array, labels: Array, fallback: int) -> void:
	var dialog_ref: WeakRef = weakref(modal)
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
			if not _dialog_active("설정") or dialog_ref.get_ref() != modal or not radio.is_inside_tree() or radio.is_queued_for_deletion(): return
			var settings: Dictionary = Device.read()
			if settings.get(key, fallback) == values[i]: return
			settings[key] = values[i]
			if Device.write(settings):
				Device.apply(lobby.app.scene.options)
				lobby.app.scene.apply_options()
			else:
				var error_frame := _dialog("저장 실패", 172)
				error_frame.add_child(_modal_label("설정을 저장하지 못했습니다. 다시 시도해 주세요."))
				_modal_button(error_frame, "RetrySettings", "설정으로 돌아가기", open_settings)
		)
