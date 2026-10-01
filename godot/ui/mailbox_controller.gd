extends RefCounted
## Owns mailbox requests and view state; AppServices retains authoritative claims/outbox.
const T = preload("res://ui/app_theme.gd")
const MailboxView = preload("res://ui/mailbox_view.gd")
var lobby
var error_text: Callable
var open_account: Callable
var view_epoch := 0
var service_binding
var account_epoch: Variant
var data := {}
var pending := false
var notice := ""
var expanded_mail_id := ""
var read_pending_id := ""
var mail_scroll_y := 0
var mail_auto_armed := true
var mail_short_prefetched := false
var mail_short_gesture := false
var mail_auto_loading_cursor := ""
var mail_page_failed_cursor := ""
var mail_loaded_cursors := {}
var mail_last_auto_scroll_y := -1

func reset(epoch: int) -> void:
	view_epoch = epoch
	service_binding = _services()
	account_epoch = service_binding.get("epoch") if service_binding != null else null
	data = {}
	pending = false
	notice = ""
	expanded_mail_id = ""
	read_pending_id = ""
	mail_scroll_y = 0
	mail_auto_armed = true
	mail_short_prefetched = false
	mail_short_gesture = false
	mail_auto_loading_cursor = ""
	mail_page_failed_cursor = ""
	mail_loaded_cursors = {}
	mail_last_auto_scroll_y = -1

func _services(): return lobby.app.get("services")

func _connected() -> bool:
	return _services() != null and _services().connected()

func _active_view(captured: int) -> bool:
	return captured == view_epoch and is_instance_valid(lobby) and lobby.is_inside_tree() \
		and is_instance_valid(lobby.modal) and lobby.modal.is_inside_tree() and not lobby.modal.is_queued_for_deletion() \
		and lobby.modal.get_meta("service_view_epoch", -1) == captured and lobby.modal.get_meta("service_page", "") == "우편함" \
		and _services() == service_binding and (service_binding == null or service_binding.get("epoch") == account_epoch)

func _show_result(result: Dictionary) -> void:
	notice = "완료했습니다" if result.get("ok",false) else error_text.call(str(result.get("code","REQUEST_FAILED")))

func render(opening := false) -> void:
	if not _active_view(view_epoch): return
	var body: VBoxContainer = lobby.modal_body
	if not opening:
		for child in body.get_children():
			body.remove_child(child)
			child.queue_free()
	if _connected():
		if opening:
			var captured_refresh := view_epoch
			MailboxView.header(lobby, func():
				if _active_view(captured_refresh): fetch()
			, pending or _services().busy)
		else:
			var refresh := lobby.modal.find_child("RefreshMailbox", true, false) as Button
			if refresh != null: refresh.disabled = pending or _services().busy
		_mailbox(body)
	else:
		body.add_child(T.label("계정을 연결하면 이 기능을 사용할 수 있습니다.",12))
		var connect_button := T.button("계정 연결", open_account)
		connect_button.disabled = pending or (_services() != null and _services().busy)
		body.add_child(connect_button)
	if pending: body.add_child(T.label("처리 중…",12))
	if not notice.is_empty(): body.add_child(T.label(notice,12))
	if not is_instance_valid(lobby.modal_scroll): return
	var scroll_ref: WeakRef = weakref(lobby.modal_scroll)
	var captured := view_epoch
	if opening:
		lobby.modal_scroll.gui_input.connect(_mail_scroll_input.bind(scroll_ref, captured))
		MailboxView.observe_touch_scroll(lobby, _mail_scroll_input.bind(scroll_ref, captured))
		lobby.modal_scroll.get_v_scroll_bar().value_changed.connect(_mail_scroll_changed.bind(scroll_ref, captured))
	lobby.modal_scroll.get_tree().process_frame.connect(func():
		var scroll: ScrollContainer = scroll_ref.get_ref()
		if scroll != null and scroll.is_inside_tree() and _active_view(captured):
			scroll.scroll_vertical = mail_scroll_y
			_mail_maybe_auto_page(scroll_ref, captured)
	, CONNECT_ONE_SHOT)

func fetch() -> void:
	if pending or not _active_view(view_epoch) or not _connected() or _services().busy: return
	if is_instance_valid(lobby.modal_scroll): mail_scroll_y = lobby.modal_scroll.scroll_vertical
	mail_auto_armed = true
	mail_short_prefetched = false
	mail_short_gesture = false
	mail_page_failed_cursor = ""
	mail_loaded_cursors.clear()
	mail_last_auto_scroll_y = -1
	pending = true
	var captured := view_epoch
	render()
	var result: Dictionary = await _services().request("GET", "v1/mailbox")
	if not _active_view(captured): return
	pending = false
	if result.get("ok",false):
		data = result.body
		notice = ""
	else: _show_result(result)
	render()
	_read_expanded_if_needed()

func _mailbox(body: VBoxContainer) -> void:
	var captured := view_epoch
	MailboxView.build(lobby, body, data, expanded_mail_id, pending or _services().busy,
		func(id: String):
			if _active_view(captured): _toggle_mail(id),
		func(id: String):
			if _active_view(captured): _claim("mail_claim", {"id":id}),
		func(ids: Array):
			if _active_view(captured): _claim("mail_claim_all", {"ids":ids}),
		mail_page_failed_cursor, func(cursor: String):
			if _active_view(captured): _mail_retry_page(cursor))

func _toggle_mail(id: String) -> void:
	if not _active_view(view_epoch): return
	if is_instance_valid(lobby.modal_scroll): mail_scroll_y = lobby.modal_scroll.scroll_vertical
	expanded_mail_id = "" if expanded_mail_id == id else id
	if mail_auto_loading_cursor.is_empty(): render()
	else: _mail_refresh_body()
	_read_expanded_if_needed()

func _mail_scroll_changed(_value: float, scroll_ref: WeakRef, captured: int) -> void:
	var scroll: ScrollContainer = scroll_ref.get_ref()
	if scroll == null or scroll != lobby.modal_scroll or not _active_view(captured): return
	if pending or not mail_auto_loading_cursor.is_empty(): return
	if scroll.scroll_vertical > mail_last_auto_scroll_y + 2:
		mail_auto_armed = true
		_mail_maybe_auto_page(scroll_ref, captured)

func _mail_scroll_input(event: InputEvent, scroll_ref: WeakRef, captured: int) -> void:
	var scroll: ScrollContainer = scroll_ref.get_ref()
	if scroll == null or scroll != lobby.modal_scroll or not _active_view(captured): return
	if pending or not _connected() or _services().busy: return
	var toward_bottom: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN) or (event is InputEventScreenDrag and event.relative.y < 0) or (event is InputEventPanGesture and event.delta.y > 0)
	if not toward_bottom: return
	var bar := scroll.get_v_scroll_bar()
	if bar.max_value - bar.page <= 1:
		mail_short_gesture = true
		mail_auto_armed = true
		_mail_maybe_auto_page.call_deferred(scroll_ref, captured)

func _mail_maybe_auto_page(scroll_ref: WeakRef, captured: int) -> void:
	var scroll: ScrollContainer = scroll_ref.get_ref()
	if scroll == null or scroll != lobby.modal_scroll or not _active_view(captured): return
	if not mail_auto_armed or pending or not mail_auto_loading_cursor.is_empty() or not _connected() or _services().busy: return
	var cursor: Variant = data.get("nextCursor")
	if not cursor is String or cursor.is_empty() or mail_loaded_cursors.has(cursor) or cursor == mail_page_failed_cursor: return
	var mails: Array = data.get("mails", [])
	if mails.is_empty(): return
	var last_card := lobby.modal.find_child("MailCard%d" % (mails.size() - 1), true, false) as Control
	if last_card == null or last_card.get_global_rect().end.y > scroll.get_global_rect().end.y + 24: return
	var bar := scroll.get_v_scroll_bar()
	if bar.max_value - bar.page <= 1:
		if mail_short_prefetched and not mail_short_gesture: return
		mail_short_prefetched = true
	mail_short_gesture = false
	mail_auto_armed = false
	mail_last_auto_scroll_y = scroll.scroll_vertical
	_mail_load_next(cursor)

func _mail_load_next(cursor: String, retry := false) -> void:
	if pending or not _active_view(view_epoch) or not _connected() or _services().busy or cursor != data.get("nextCursor") or mail_loaded_cursors.has(cursor): return
	if cursor == mail_page_failed_cursor and not retry: return
	mail_page_failed_cursor = ""
	mail_auto_loading_cursor = cursor
	mail_scroll_y = lobby.modal_scroll.scroll_vertical
	pending = true
	MailboxView.paging_loading(lobby, true)
	var captured := view_epoch
	var result: Dictionary = await _services().request("GET", "v1/mailbox?cursor=" + cursor.uri_encode())
	if not _active_view(captured): return
	pending = false
	mail_auto_loading_cursor = ""
	if result.get("ok", false):
		mail_loaded_cursors[cursor] = true
		data.mails.append_array(result.body.get("mails", []))
		var next: Variant = result.body.get("nextCursor")
		data.nextCursor = null if next == cursor else next
		notice = ""
	else:
		mail_page_failed_cursor = cursor
	_mail_refresh_body()
	_read_expanded_if_needed()

func _mail_retry_page(cursor: String) -> void:
	if cursor == mail_page_failed_cursor: _mail_load_next(cursor, true)

func _mail_refresh_body() -> void:
	if not _active_view(view_epoch) or not is_instance_valid(lobby.modal_body) or not is_instance_valid(lobby.modal_scroll): return
	var body: VBoxContainer = lobby.modal_body
	mail_scroll_y = lobby.modal_scroll.scroll_vertical
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_mailbox(body)
	if not mail_auto_loading_cursor.is_empty(): MailboxView.paging_loading(lobby, true)
	else:
		var refresh := lobby.modal.find_child("RefreshMailbox", true, false) as Button
		if refresh != null: refresh.disabled = pending or _services().busy
	lobby._layout_modal.call_deferred()
	var scroll_ref: WeakRef = weakref(lobby.modal_scroll)
	var captured := view_epoch
	lobby.modal_scroll.get_tree().process_frame.connect(func():
		var scroll: ScrollContainer = scroll_ref.get_ref()
		if scroll != null and scroll.is_inside_tree() and _active_view(captured): scroll.scroll_vertical = mail_scroll_y
	, CONNECT_ONE_SHOT)

func _read_expanded_if_needed() -> void:
	if pending or not _active_view(view_epoch) or not read_pending_id.is_empty() or expanded_mail_id.is_empty(): return
	for mail in data.get("mails", []):
		if mail is Dictionary and str(mail.get("id", "")) == expanded_mail_id and mail.get("readAt") == null:
			_mark_read(expanded_mail_id)
			return

func _mark_read(id: String) -> void:
	if pending or not _active_view(view_epoch) or not read_pending_id.is_empty() or not _connected(): return
	read_pending_id = id
	var captured := view_epoch
	pending = true
	render()
	var result: Dictionary = await _services().request("POST","v1/mailbox/"+id.uri_encode()+"/read")
	if not _active_view(captured): return
	read_pending_id = ""
	pending = false
	if result.get("ok",false):
		# The read endpoint returns only {read:true}; keep loaded pages and selection.
		for index in data.get("mails", []).size():
			if data.mails[index] is Dictionary and str(data.mails[index].get("id", "")) == id:
				data.mails[index].readAt = Time.get_datetime_string_from_system(true)
				break
		render()
		_read_expanded_if_needed()
	else:
		_show_result(result)
		render()

func _claim(action: String, values: Dictionary) -> void:
	if pending or not _active_view(view_epoch) or not _connected() or _services().busy: return
	if is_instance_valid(lobby.modal_scroll): mail_scroll_y = lobby.modal_scroll.scroll_vertical
	pending = true
	var captured := view_epoch
	render()
	var result: Dictionary = await _services().perform(action, values.duplicate(true))
	if not _active_view(captured): return
	pending = false
	_show_result(result)
	if result.get("ok", false):
		data = result.get("body", {})
		fetch()
		return
	render()
