extends RefCounted
## Account mailbox presentation. The service owner retains the selected mail and requests.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const CYAN := Color("86e8ff")
const TEXT := Color("e8f8ff")
const MUTED := Color("bad8e6")
const UiWidgets = preload("res://ui/ui_widgets.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const RewardBox = preload("res://ui/reward_box.gd")
const BOX := 54.0
const CLAIM_ALL_LIMIT := 20
const DAY := 86400
const HOUR := 3600
const URGENT_LEFT := 3 * DAY

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

static func _status(value: String, size: int, color: Color, weight: int = 700) -> Label:
	var label := _label(value, size, color, weight)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

static func _rewards(mail: Dictionary) -> Array:
	var rewards: Array = []
	for reward in [[RewardBox.DIAMONDS, "freeDiamonds"], [RewardBox.MODULE_TICKETS, "moduleTickets"], [RewardBox.GEM_RESET_TICKETS, "gemResetTickets"]]:
		var amount := int(mail.get(reward[1], 0))
		if amount > 0: rewards.append({"kind":reward[0], "amount":amount})
	return rewards

## UTC seconds of a server timestamp, or -1 when it has no full date.
static func _unix(raw: String) -> int:
	if raw.length() < 19: return -1
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
	return unix - offset

static func _expires(value: Variant) -> String:
	var raw := str(value)
	if raw.length() < 16: return "만료 일시 없음"
	if raw.length() < 19: return raw
	var local_bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var local := Time.get_datetime_dict_from_unix_time(_unix(raw) + local_bias * 60)
	return "%04d.%02d.%02d %02d:%02d까지" % [local.year, local.month, local.day, local.hour, local.minute]

## The device clock only words the countdown; the server still decides expiry.
static func _left(value: Variant, now: int) -> Label:
	var unix := _unix(str(value))
	if unix < 0: return _status("", 11, MUTED)
	var left := unix - now
	var urgent := left <= URGENT_LEFT
	var text := "곧 만료"
	if left >= DAY: text = "%d일 남음" % ceili(left / float(DAY))
	elif left >= HOUR: text = "%d시간 남음" % ceili(left / float(HOUR))
	return _status(text, 11, Color("ffb45c") if urgent else Color("8fa9b7"), 800 if urgent else 600)

static func header(lobby, refresh: Callable, pending: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "MailboxHeader"
	row.add_theme_constant_override("separation", 5)
	var title := _label("우편함", 20, TEXT, 900)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var reload: Button = UiWidgets.plain_button("↻", refresh)
	reload.name = "RefreshMailbox"
	reload.tooltip_text = "새로고침"
	reload.custom_minimum_size = Vector2(34, 36)
	reload.add_theme_font_size_override("font_size", 28)
	reload.add_theme_color_override("font_color", CYAN)
	reload.disabled = pending
	reload.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	row.add_child(reload)
	var close: Button = UiWidgets.plain_button("×", lobby.close_modal)
	close.name = "CloseModal"
	close.tooltip_text = "닫기"
	close.custom_minimum_size = Vector2(34, 36)
	close.add_theme_font_size_override("font_size", 27)
	close.add_theme_color_override("font_color", Color("a7bdca"))
	row.add_child(close)
	lobby.set_modal_header(row)

static func build(lobby, body: VBoxContainer, data: Dictionary, expanded_id: String,
		pending: bool, toggle: Callable, claim: Callable, claim_all: Callable,
		failed_cursor: String, retry: Callable, notice: String = "") -> void:
	body.add_theme_constant_override("separation", 8)
	_line(body)
	lobby.set_modal_footer(null)
	var mails: Array = data.get("mails", [])
	if mails.is_empty():
		if not pending: body.add_child(_label("도착한 우편이 없습니다.", 13))
		return
	var claimable: Array = []
	var now := int(Time.get_unix_time_from_system())
	for index in mails.size():
		var mail: Variant = mails[index]
		if not mail is Dictionary: continue
		var id := str(mail.get("id", ""))
		var expanded := id == expanded_id
		var claimed := mail.get("claimedAt") != null
		var unread: bool = mail.get("readAt") == null
		var card := PanelContainer.new()
		card.name = "MailCard%d" % index
		card.add_theme_stylebox_override("panel", Frame.new("ui/components/card_frame.png", 9))
		body.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		card.add_child(content)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 4)
		content.add_child(heading)
		if unread:
			var dot := _status("●", 9, Color("f5cb61"), 900)
			dot.name = "MailUnread%d" % index
			heading.add_child(dot)
		var title: Button = UiWidgets.plain_button(str(mail.get("title", "우편")), toggle.bind(id))
		title.name = "MailTitle%d" % index
		title.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.custom_minimum_size.y = 26
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", TEXT if unread else Color("c3d6e0"))
		heading.add_child(title)
		heading.add_child(_left(mail.get("expiresAt", ""), now))
		var arrow: Button = UiWidgets.plain_button("⌃" if expanded else "⌄", toggle.bind(id))
		arrow.name = "MailToggle%d" % index
		arrow.tooltip_text = "본문 접기" if expanded else "본문 펼치기"
		arrow.custom_minimum_size = Vector2(24, 26)
		arrow.add_theme_font_size_override("font_size", 20)
		arrow.add_theme_color_override("font_color", MUTED)
		heading.add_child(arrow)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		content.add_child(row)
		var rewards := HBoxContainer.new()
		rewards.add_theme_constant_override("separation", 6)
		rewards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rewards)
		var granted := _rewards(mail)
		var names: Array = []
		for reward in granted:
			rewards.add_child(RewardBox.create(reward.kind, HudNumber.format_number(reward.amount), BOX, 11, 3))
			names.append("%s %s" % [reward.kind.name, HudNumber.exact_integer(reward.amount)])
		if granted.is_empty(): rewards.add_child(_status("보상 없음", 12, MUTED))
		if claimed:
			heading.modulate.a = 0.55
			rewards.modulate.a = 0.55
			row.add_child(_status("수령 완료", 12, Color("8da7b5")))
		else:
			claimable.append(id)
			var receive := T.button("받기", claim.bind(id), "secondary")
			receive.name = "ClaimMail%d" % index
			receive.custom_minimum_size = Vector2(84, 38)
			receive.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			receive.disabled = pending
			row.add_child(receive)
		if expanded:
			_line(content)
			if not names.is_empty(): content.add_child(_label(" · ".join(names), 12, CYAN, 800))
			var message := _label(str(mail.get("body", "")), 12)
			message.name = "MailBody%d" % index
			content.add_child(message)
			content.add_child(_label(_expires(mail.get("expiresAt", "")), 11))
	var list_end := VBoxContainer.new()
	list_end.name = "MailboxListEnd"
	list_end.add_theme_constant_override("separation", 5)
	body.add_child(list_end)
	var cursor: Variant = data.get("nextCursor")
	if cursor is String and not cursor.is_empty() and cursor == failed_cursor:
		list_end.add_child(_label("다음 우편을 불러오지 못했습니다.", 11))
		var retry_button := T.button("다시 시도", retry.bind(cursor), "secondary")
		retry_button.name = "RetryMailPage"
		retry_button.disabled = pending
		list_end.add_child(retry_button)
	var more: bool = cursor is String and not cursor.is_empty()
	lobby.set_modal_footer(_footer(claimable, more, pending, claim_all, notice))

static func _claimable_text(count: int, more: bool) -> String:
	if count <= 0: return "불러온 우편은 모두 받았습니다" if more else "받을 우편 없음"
	return ("받을 우편 %d건 이상" if more else "받을 우편 %d건") % count

## The list scrolls away from any notice left under it, so notices stay here.
static func _footer(claimable: Array, more: bool, pending: bool, claim_all: Callable, notice: String) -> Control:
	var footer := MarginContainer.new()
	footer.name = "MailboxFooter"
	footer.add_theme_constant_override("margin_left", 8)
	footer.add_theme_constant_override("margin_top", 4)
	var row := HBoxContainer.new()
	footer.add_child(row)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(summary)
	var count := claimable.size()
	summary.add_child(_label(_claimable_text(count, more), 14, TEXT, 800))
	if count > CLAIM_ALL_LIMIT or (more and count == CLAIM_ALL_LIMIT):
		summary.add_child(_label("한 번에 %d건씩 받습니다" % CLAIM_ALL_LIMIT, 11))
	if not notice.is_empty():
		var message := _label(notice, 11)
		message.name = "MailboxNotice"
		summary.add_child(message)
	var all_button := T.button("모두 받기", claim_all.bind(claimable.slice(0, CLAIM_ALL_LIMIT)), "primary")
	all_button.name = "ClaimAllMail"
	all_button.custom_minimum_size = Vector2(150, 48)
	all_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	all_button.add_theme_font_size_override("font_size", 16)
	all_button.disabled = pending or claimable.is_empty()
	row.add_child(all_button)
	return footer

static func paging_loading(lobby, loading: bool) -> void:
	if not is_instance_valid(lobby.modal): return
	var list_end := lobby.modal.find_child("MailboxListEnd", true, false) as VBoxContainer
	if list_end == null: return
	var indicator := list_end.find_child("MailboxPageLoading", false, false)
	if loading and indicator == null:
		var label := _label("다음 우편 불러오는 중…", 11)
		label.name = "MailboxPageLoading"
		list_end.add_child(label)
	elif not loading and indicator != null:
		indicator.queue_free()
	for node in lobby.modal.find_children("ClaimMail*", "Button", true, false): node.disabled = loading
	var all_button := lobby.modal.find_child("ClaimAllMail", true, false) as Button
	if all_button != null: all_button.disabled = loading
	var refresh := lobby.modal.find_child("RefreshMailbox", true, false) as Button
	if refresh != null: refresh.disabled = loading
