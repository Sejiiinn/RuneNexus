extends RefCounted
## Account mailbox presentation. The service owner retains the selected mail and requests.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const CYAN := Color("86e8ff")
const TEXT := Color("e8f8ff")
const MUTED := Color("bad8e6")

class TouchScrollObserver extends Node:
	var scroll_ref: WeakRef
	var observe: Callable
	var touches := {}
	func _input(event: InputEvent) -> void:
		var scroll: ScrollContainer = scroll_ref.get_ref()
		if scroll == null or not scroll.is_visible_in_tree(): return
		if event is InputEventScreenTouch:
			if event.pressed and scroll.get_global_rect().has_point(event.position): touches[event.index] = true
			else: touches.erase(event.index)
		elif event is InputEventScreenDrag and touches.has(event.index): observe.call(event)

static func observe_touch_scroll(lobby, callback: Callable) -> void:
	var observer := TouchScrollObserver.new()
	observer.name = "MailboxTouchScrollObserver"
	observer.scroll_ref = weakref(lobby.modal_scroll)
	observer.observe = callback
	lobby.modal.add_child(observer)

static func _label(value: String, size: int, color: Color = MUTED, weight: int = 700) -> Label:
	var label := T.label(value, size)
	label.add_theme_font_override("font", T.font(weight))
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func _line(parent: Node) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("466b7d")
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)

static func _icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = T.texture(path)
	icon.custom_minimum_size = Vector2(23, 23)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

static func _reward(parent: Node, path: String, label_text: String) -> void:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	parent.add_child(group)
	group.add_child(_icon(path))
	var label := _label(label_text, 12, MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_child(label)

static func _expires(value: Variant) -> String:
	var raw := str(value)
	if raw.length() < 16: return "만료 일시 없음"
	if raw.length() < 19: return raw
	var unix := Time.get_unix_time_from_datetime_string(raw.substr(0, 19))
	var offset := 0
	if raw.length() >= 25 and raw.substr(19, 1) in ["+", "-"]:
		var sign := 1 if raw.substr(19, 1) == "+" else -1
		offset = sign * (int(raw.substr(20, 2)) * 3600 + int(raw.substr(23, 2)) * 60)
	elif raw.length() >= 25 and raw.substr(19, 1) == ".":
		var zone_start := raw.find("+")
		if zone_start < 0: zone_start = raw.find("-", 19)
		if zone_start >= 0 and raw.length() >= zone_start + 6:
			var sign := 1 if raw.substr(zone_start, 1) == "+" else -1
			offset = sign * (int(raw.substr(zone_start + 1, 2)) * 3600 + int(raw.substr(zone_start + 4, 2)) * 60)
	var local_bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var local := Time.get_datetime_dict_from_unix_time(unix - offset + local_bias * 60)
	return "%04d.%02d.%02d %02d:%02d까지" % [local.year, local.month, local.day, local.hour, local.minute]

static func header(lobby, refresh: Callable, pending: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "MailboxHeader"
	row.add_theme_constant_override("separation", 5)
	var title := _label("우편함", 20, TEXT, 900)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var reload: Button = lobby._plain_button("↻", refresh)
	reload.name = "RefreshMailbox"
	reload.tooltip_text = "새로고침"
	reload.custom_minimum_size = Vector2(34, 36)
	reload.add_theme_font_size_override("font_size", 28)
	reload.add_theme_color_override("font_color", CYAN)
	reload.disabled = pending
	reload.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	row.add_child(reload)
	var close: Button = lobby._plain_button("×", lobby.close_modal)
	close.name = "CloseModal"
	close.tooltip_text = "닫기"
	close.custom_minimum_size = Vector2(34, 36)
	close.add_theme_font_size_override("font_size", 27)
	close.add_theme_color_override("font_color", Color("a7bdca"))
	row.add_child(close)
	lobby.set_modal_header(row)

static func build(lobby, body: VBoxContainer, data: Dictionary, expanded_id: String,
		pending: bool, toggle: Callable, claim: Callable, claim_all: Callable,
		failed_cursor: String, retry: Callable) -> void:
	body.add_theme_constant_override("separation", 8)
	_line(body)
	var mails: Array = data.get("mails", [])
	if mails.is_empty():
		if not pending: body.add_child(_label("도착한 우편이 없습니다.", 13))
		return
	var claimable: Array = []
	for index in mails.size():
		var mail: Variant = mails[index]
		if not mail is Dictionary: continue
		var id := str(mail.get("id", ""))
		var expanded := id == expanded_id
		var claimed := mail.get("claimedAt") != null
		var card := PanelContainer.new()
		card.name = "MailCard%d" % index
		card.add_theme_stylebox_override("panel", Frame.new("ui/components/card_frame.png", 9))
		body.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		card.add_child(content)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 0)
		content.add_child(heading)
		var title: Button = lobby._plain_button(str(mail.get("title", "우편")), toggle.bind(id))
		title.name = "MailTitle%d" % index
		title.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.custom_minimum_size.y = 32
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", TEXT)
		heading.add_child(title)
		var arrow: Button = lobby._plain_button("⌃" if expanded else "⌄", toggle.bind(id))
		arrow.name = "MailToggle%d" % index
		arrow.tooltip_text = "본문 접기" if expanded else "본문 펼치기"
		arrow.custom_minimum_size = Vector2(26, 32)
		arrow.add_theme_font_size_override("font_size", 22)
		arrow.add_theme_color_override("font_color", MUTED)
		heading.add_child(arrow)
		content.add_child(_label("%s · %s" % ["읽음" if mail.get("readAt") != null else "안 읽음", "수령" if claimed else "미수령"], 11, CYAN, 800))
		var rewards := HFlowContainer.new()
		rewards.add_theme_constant_override("separation", 10)
		content.add_child(rewards)
		var diamonds := int(mail.get("freeDiamonds", 0))
		var tickets := int(mail.get("moduleTickets", 0))
		if diamonds > 0: _reward(rewards, "res://assets/ui/diamond_currency.png", "무료 다이아 %d" % diamonds)
		if tickets > 0: _reward(rewards, "stage_rewards/reward_module_ticket.png", "모듈권 %d" % tickets)
		if diamonds <= 0 and tickets <= 0: content.add_child(_label("보상 없음", 12))
		content.add_child(_label(_expires(mail.get("expiresAt", "")), 11))
		if expanded:
			_line(content)
			var message := _label(str(mail.get("body", "")), 12)
			message.name = "MailBody%d" % index
			content.add_child(message)
		if claimed:
			content.add_child(_label("수령 완료", 12, Color("8da7b5")))
		else:
			claimable.append(id)
			var receive := T.button("받기", claim.bind(id), "secondary")
			receive.name = "ClaimMail%d" % index
			receive.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			receive.custom_minimum_size.y = 34
			receive.disabled = pending
			content.add_child(receive)
	var footer := VBoxContainer.new()
	footer.name = "MailboxFooter"
	footer.add_theme_constant_override("separation", 5)
	body.add_child(footer)
	footer.add_child(_label("불러온 우편 중 최대 20건을 받습니다.", 11))
	var all_button := T.button("모두 받기 · %d건" % mini(claimable.size(), 20), claim_all.bind(claimable.slice(0, 20)), "primary")
	all_button.name = "ClaimAllMail"
	all_button.custom_minimum_size.y = 36
	all_button.disabled = pending or claimable.is_empty()
	footer.add_child(all_button)
	var cursor: Variant = data.get("nextCursor")
	if cursor is String and not cursor.is_empty() and cursor == failed_cursor:
		footer.add_child(_label("다음 우편을 불러오지 못했습니다.", 11))
		var retry_button := T.button("다시 시도", retry.bind(cursor), "secondary")
		retry_button.name = "RetryMailPage"
		retry_button.disabled = pending
		footer.add_child(retry_button)

static func paging_loading(lobby, loading: bool) -> void:
	if not is_instance_valid(lobby.modal): return
	var footer := lobby.modal.find_child("MailboxFooter", true, false) as VBoxContainer
	if footer == null: return
	var indicator := footer.find_child("MailboxPageLoading", false, false)
	if loading and indicator == null:
		var label := _label("다음 우편 불러오는 중…", 11)
		label.name = "MailboxPageLoading"
		footer.add_child(label)
	elif not loading and indicator != null:
		indicator.queue_free()
	for node in lobby.modal.find_children("ClaimMail*", "Button", true, false): node.disabled = loading
	var all_button := lobby.modal.find_child("ClaimAllMail", true, false) as Button
	if all_button != null: all_button.disabled = loading
	var refresh := lobby.modal.find_child("RefreshMailbox", true, false) as Button
	if refresh != null: refresh.disabled = loading
