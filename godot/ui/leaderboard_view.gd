extends RefCounted
## The leaderboard keeps its header and own rank outside the scrolling list.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/game_modal_frame.gd")
const GOLD := Color("ffd477")
const CYAN := Color("a9efff")
const TEXT := Color("e8f8ff")
const MUTED := Color("a7bdca")

static func _size(lobby, logical: int) -> int:
	return lobby.home._font_size(logical) if is_instance_valid(lobby.home) else logical

static func _label(lobby, value: String, logical: int, color: Color = TEXT, weight: int = 700) -> Label:
	var label := T.label(value, _size(lobby, logical))
	label.add_theme_font_override("font", T.font(weight))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func _line(parent: Control, strong := false) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("718c9c") if strong else Color("344c5a")
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)

static func _timestamp(value: Variant, seconds := false) -> String:
	var raw := str(value)
	if raw.length() < 19: return ""
	var date := raw.substr(0, 10).replace("-", ".")
	return "%s %s UTC" % [date, raw.substr(11, 8 if seconds else 5)]

static func _popup(lobby, title: String, message: String) -> void:
	var popup := PopupPanel.new()
	popup.name = "LeaderboardInfoPopup"
	popup.add_theme_stylebox_override("panel", Frame.create(Color("8fa8ba"), "standard", 12))
	lobby.modal.add_child(popup)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	popup.add_child(column)
	var heading := _label(lobby, title, 15, CYAN, 900)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(heading)
	var detail := RichTextLabel.new()
	detail.name = "LeaderboardPopupText"
	detail.text = message
	detail.fit_content = false
	detail.scroll_active = true
	var compact: bool = lobby.size.x <= 340 and _size(lobby, 14) >= 26
	detail.custom_minimum_size.y = 150 if compact else 70
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_override("normal_font", T.font(700))
	detail.add_theme_font_size_override("normal_font_size", _size(lobby, 11))
	detail.add_theme_color_override("default_color", TEXT)
	column.add_child(detail)
	var close: Button = lobby._plain_button("닫기", popup.hide)
	close.custom_minimum_size.y = 38
	close.add_theme_font_size_override("font_size", _size(lobby, 12))
	column.add_child(close)
	popup.popup_hide.connect(popup.queue_free)
	popup.popup_centered(Vector2i(mini(300, roundi(lobby.size.x) - 32), 290 if compact else 170))

static func _header(lobby) -> void:
	var header := HBoxContainer.new()
	header.name = "LeaderboardHeader"
	header.add_theme_constant_override("separation", 4)
	var trophy := TextureRect.new()
	trophy.texture = T.texture("lobby_leaderboard_icon.png")
	trophy.custom_minimum_size = Vector2(24, 24)
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(trophy)
	var title := _label(lobby, "리더보드", 22, CYAN, 900)
	title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	title.custom_minimum_size.x = 0
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	var close: Button = lobby._plain_button("×", lobby.close_modal)
	close.name = "CloseModal"
	close.custom_minimum_size = Vector2(38, 38)
	close.add_theme_font_size_override("font_size", 27)
	close.add_theme_color_override("font_color", MUTED)
	close.tooltip_text = "닫기"
	header.add_child(close)
	lobby.set_modal_header(header)

static func _record_row(lobby, parent: Control, entry: Dictionary, mine := false) -> void:
	var rank := int(entry.get("rank", 0))
	var compact: bool = lobby.size.x <= 340 and _size(lobby, 14) >= 26
	var row := PanelContainer.new()
	row.name = "LeaderboardRow%d" % rank if not mine else "LeaderboardMyRow"
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = "서버 확정 시각 보기"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("192c38") if mine else Color.TRANSPARENT
	frame.border_color = Color("4b8298") if mine else Color.TRANSPARENT
	frame.set_border_width_all(1 if mine else 0)
	frame.set_corner_radius_all(5 if mine else 0)
	frame.content_margin_left = 10 if mine else 4
	frame.content_margin_right = 8 if mine else 4
	frame.content_margin_top = 4 if compact else 8
	frame.content_margin_bottom = 4 if compact else 8
	row.add_theme_stylebox_override("panel", frame)
	parent.add_child(row)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2 if compact else 4)
	row.add_child(content)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 7)
	content.add_child(cells)
	var highlighted := mine or bool(entry.get("isMe", false))
	var rank_color := CYAN if highlighted else (GOLD if rank <= 3 else TEXT)
	var rank_label := _label(lobby, str(rank), 19 if mine else 17, rank_color, 900)
	rank_label.custom_minimum_size.x = maxf(30, T.font(900).get_string_size(str(rank), HORIZONTAL_ALIGNMENT_LEFT, -1, _size(lobby, 19 if mine else 17)).x + 4)
	rank_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rank_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rank_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cells.add_child(rank_label)
	var name := _label(lobby, str(entry.get("displayName", "")), 14, CYAN if highlighted else TEXT, 900)
	name.name = "DisplayName"
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cells.add_child(name)
	var progress := VBoxContainer.new()
	var progress_width := maxf(104, T.font(700).get_string_size("40 / 40 라운드", HORIZONTAL_ALIGNMENT_LEFT, -1, _size(lobby, 12)).x + 5)
	var inner_width := minf(680, lobby.size.x - 32) - 32
	var stacked := inner_width < progress_width + _size(lobby, 14) * 6 + 52
	progress.custom_minimum_size.x = 0 if stacked else progress_width
	progress.size_flags_horizontal = Control.SIZE_SHRINK_END
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_theme_constant_override("separation", 0)
	if stacked:
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(progress)
	else: cells.add_child(progress)
	for value in ["스테이지 %d" % int(entry.get("stageNumber", 0)), "%d / 40 라운드" % int(entry.get("completedRounds", 0))]:
		var value_label := _label(lobby, value, 12, Color("d5e9f2"), 700)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		progress.add_child(value_label)
	var achieved := _timestamp(entry.get("achievedAt", ""), true)
	var detail_text := "서버 확정 · " + achieved if not achieved.is_empty() else "서버 확정 시각 없음"
	var detail := _label(lobby, detail_text, 11, MUTED)
	detail.name = "AchievedAt"
	detail.visible = false
	content.add_child(detail)
	var toggle := func():
		if mine: _popup(lobby, "내 기록 확정 시각", detail_text)
		else: detail.visible = not detail.visible
	var pointer := {"pressed": false, "origin": Vector2.ZERO}
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer.pressed = true
				pointer.origin = event.position
			elif pointer.pressed:
				pointer.pressed = false
				if event.position.distance_to(pointer.origin) < 10: toggle.call()
		elif event is InputEventScreenTouch:
			if event.pressed:
				pointer.pressed = true
				pointer.origin = event.position
			elif pointer.pressed:
				pointer.pressed = false
				if event.position.distance_to(pointer.origin) < 10: toggle.call()
		elif event is InputEventMouseMotion and pointer.pressed and event.position.distance_to(pointer.origin) >= 10:
			pointer.pressed = false
		elif event is InputEventScreenDrag and pointer.pressed and event.position.distance_to(pointer.origin) >= 10:
			pointer.pressed = false
		elif event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE): toggle.call()
	)
	if not mine: _line(parent)

static func build(lobby, body: VBoxContainer, data: Dictionary, pending: bool, notice: String, refresh: Callable, account: Callable, connected: bool) -> void:
	_header(lobby)
	var compact: bool = lobby.size.x <= 340 and _size(lobby, 14) >= 26
	body.add_theme_constant_override("separation", 2 if compact else 5)
	var top := HBoxContainer.new()
	top.name = "LeaderboardTop"
	body.add_child(top)
	top.add_child(_label(lobby, "전체 순위 · TOP 100", 14, MUTED))
	var reload: Button = lobby._plain_button("↻", refresh)
	reload.name = "RefreshLeaderboard"
	reload.custom_minimum_size = Vector2(36, 36)
	reload.add_theme_font_size_override("font_size", 26)
	reload.add_theme_color_override("font_color", CYAN)
	reload.tooltip_text = "새로고침"
	reload.disabled = pending or not connected
	top.add_child(reload)
	_line(body, true)
	var as_of := _timestamp(data.get("asOf", ""))
	var help := "동일 기록은 먼저 달성한 순 · 서버 확정 시각 기준"
	if compact:
		var guide: Button = lobby._plain_button("순위 안내", func(): _popup(lobby, "순위 안내", (as_of + " 기준\n" if not as_of.is_empty() else "") + help))
		guide.name = "LeaderboardGuide"
		guide.custom_minimum_size.y = 38
		guide.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		guide.add_theme_font_size_override("font_size", _size(lobby, 11))
		body.add_child(guide)
	else:
		if not as_of.is_empty(): body.add_child(_label(lobby, as_of + " 기준", 11, MUTED))
		body.add_child(_label(lobby, help, 11, Color("c5dae6")))
	if not notice.is_empty() and not compact: body.add_child(_label(lobby, notice, 11, Color("ffd477")))
	var list := ScrollContainer.new()
	list.name = "LeaderboardList"
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(list)
	var rows := VBoxContainer.new()
	rows.name = "LeaderboardRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	list.add_child(rows)
	if not notice.is_empty() and compact: rows.add_child(_label(lobby, notice, 11, Color("ffd477")))
	if not connected:
		rows.add_child(_label(lobby, "계정을 연결하면 리더보드를 이용할 수 있습니다.", 12))
		var link := T.button("계정 연결", account)
		rows.add_child(link)
	else:
		var entries: Array = data.get("entries", [])
		for item in entries:
			if item is Dictionary: _record_row(lobby, rows, item)
		if entries.is_empty():
			var state := "불러오는 중…" if pending else ("순위를 불러오지 못했습니다. 새로고침을 눌러 다시 시도해 주세요." if not notice.is_empty() else "아직 등록된 기록이 없습니다.")
			rows.add_child(_label(lobby, state, 12))
	_line(body, true)
	var footer := PanelContainer.new()
	footer.name = "LeaderboardFooter"
	var footer_frame := StyleBoxFlat.new()
	footer_frame.bg_color = Color("0b1822")
	footer_frame.content_margin_left = 0
	footer_frame.content_margin_right = 0
	footer_frame.content_margin_top = 2
	footer_frame.content_margin_bottom = 0
	footer.add_theme_stylebox_override("panel", footer_frame)
	body.add_child(footer)
	var own := VBoxContainer.new()
	own.add_theme_constant_override("separation", 2 if compact else 4)
	footer.add_child(own)
	own.add_child(_label(lobby, "내 순위", 13, CYAN, 900))
	var my_entry: Variant = data.get("myEntry")
	if my_entry is Dictionary: _record_row(lobby, own, my_entry, true)
	else: own.add_child(_label(lobby, "전투 기록을 동기화하면 순위에 등록됩니다.", 11, MUTED))
