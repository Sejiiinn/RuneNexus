extends SceneTree
## Isolated mailbox fixture: no account, save, or server request is touched.
const RewardPopup = preload("res://ui/reward_popup.gd")
const Fixture = preload("res://tests/verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
const MailboxView = preload("res://ui/mailbox_view.gd")

class Service extends RefCounted:
	var tree: SceneTree
	var epoch := 0
	var busy := false
	var updates := {"blocked": false}
	var mails: Array = []
	var requests: Array = []
	var claims: Array = []
	var hold_read := false
	var hold_fetch := false
	var hold_claim := false
	var fail_claim := false
	var receipt := {}
	var hold_page := false
	var fail_page := false
	var repeat_cursor := false
	var one_by_one := false
	var page_size := 2
	var offline := false
	func connected() -> bool: return not offline
	func needs_profile() -> bool: return false
	func request(method: String, path: String, _body: Dictionary = {}) -> Dictionary:
		requests.append(method + " " + path)
		await tree.process_frame
		if method == "GET":
			if path == "v1/mailbox":
				while hold_fetch: await tree.process_frame
				return {"ok": true, "body": {"mails": mails.slice(0, page_size).duplicate(true), "nextCursor": "page2" if mails.size() > page_size else null}}
			if path == "v1/mailbox?cursor=page2":
				while hold_page: await tree.process_frame
				if fail_page: return {"ok": false, "code": "REQUEST_FAILED"}
				if one_by_one: return {"ok": true, "body": {"mails": mails.slice(page_size, page_size + 1).duplicate(true), "nextCursor": "page3"}}
				return {"ok": true, "body": {"mails": mails.slice(page_size, mails.size()).duplicate(true), "nextCursor": "page2" if repeat_cursor else null}}
			if path == "v1/mailbox?cursor=page3": return {"ok": true, "body": {"mails": mails.slice(page_size + 1, mails.size()).duplicate(true), "nextCursor": null}}
		if method == "POST" and path.ends_with("/read"):
			while hold_read: await tree.process_frame
			var id := path.trim_prefix("v1/mailbox/").trim_suffix("/read")
			for mail in mails:
				if mail.id == id: mail.readAt = "2026-09-27T12:00:00Z"
			return {"ok": true, "body": {"read": true}}
		return {"ok": false, "code": "BAD_FIXTURE_PATH"}
	func perform(action: String, values: Dictionary) -> Dictionary:
		claims.append({"action": action, "values": values.duplicate(true)})
		for mail in mails:
			if mail.id == str(values.get("id", "")) or mail.id in values.get("ids", []):
				mail.claimedAt = "2026-09-27T12:00:00Z"
		await tree.process_frame
		while hold_claim: await tree.process_frame
		if fail_claim: return {"ok": false, "code": "NETWORK_ERROR"}
		return {"ok": true, "body": receipt.duplicate()}

var failures: Array[String] = []
var checks := 0
var lobby
var service: Service
var capture_dir := OS.get_environment("MAILBOX_CAPTURE_DIR")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for i in range(12): await process_frame

func popup_text(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): result += popup_text(child)
	return result

func tap() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	return event

func verify_claim_feedback() -> void:
	service.mails[0].claimedAt = null
	service.receipt = {"grantedDiamonds":1200, "grantedModuleTickets":5, "grantedGemResetTickets":3}
	lobby.open_service("우편함")
	await settle()
	service.hold_claim = true
	find_node("ClaimMail0").pressed.emit()
	await settle()
	var overlay: Control = lobby.modal.get_node_or_null("ClaimOverlay")
	check(overlay != null and overlay._active and lobby.modal.get_child(-1) == overlay, "Pending mail claim blocks the dialog with the server spinner")
	check(find_node("ClaimAllMail").disabled, "Pending mail claim locks bulk claim")
	var fetches := service.requests.count("GET v1/mailbox")
	service.hold_claim = false
	await settle()
	check(not overlay._active, "Mail claim and its refetch release the spinner")
	check(service.requests.count("GET v1/mailbox") == fetches + 1, "Mail claim still refetches behind the result")
	var popup: Control = lobby.modal.get_node_or_null("RewardPopup")
	check(popup != null and lobby.modal.get_child(-1) == popup, "Claimed mail opens the result over the dialog")
	check(popup != null and popup.find_child("RewardItems", true, false).get_child_count() == 3, "Each granted kind has one item box")
	check(popup != null and "1,200" in popup_text(popup) and "모듈권" in popup_text(popup) and "젬 리셋권" in popup_text(popup), "Item boxes show the granted kinds and amounts")
	popup._gui_input(tap())
	await settle()
	check(is_instance_valid(popup) and not popup._closing, "The claiming tap cannot dismiss its own result")
	await create_timer(0.35).timeout
	popup._gui_input(tap())
	await create_timer(0.2).timeout
	check(not is_instance_valid(popup) and is_instance_valid(lobby.modal), "A tap closes only the result")
	# One kind keeps the same screen with a single box; back closes it first.
	service.mails[0].claimedAt = null
	service.receipt = {"grantedDiamonds":50}
	find_node("RefreshMailbox").pressed.emit()
	await settle()
	find_node("ClaimMail0").pressed.emit()
	await settle()
	popup = lobby.modal.get_node_or_null("RewardPopup")
	check(popup != null and popup.find_child("RewardItems", true, false).get_child_count() == 1, "A single kind shows one item box")
	lobby.go_back()
	await create_timer(0.2).timeout
	check(not is_instance_valid(popup) and is_instance_valid(lobby.modal), "Back closes the result before the mailbox")
	# A failed claim or an empty receipt shows no result.
	service.mails[0].claimedAt = null
	service.fail_claim = true
	find_node("RefreshMailbox").pressed.emit()
	await settle()
	find_node("ClaimMail0").pressed.emit()
	await settle()
	check(lobby.modal.get_node_or_null("RewardPopup") == null, "A failed claim shows no result")
	service.fail_claim = false
	service.mails[0].claimedAt = null
	service.receipt = {}
	find_node("RefreshMailbox").pressed.emit()
	await settle()
	find_node("ClaimMail0").pressed.emit()
	await settle()
	check(lobby.modal.get_node_or_null("RewardPopup") == null, "A recovered claim without a receipt shows no result")
	# Every box lands from the front, not only the first: layout must not reset it.
	ProjectSettings.set_setting("accessibility/disable_animations", false)
	var entering: Control = RewardPopup.present(lobby.modal, RewardPopup.from_receipt({"grantedDiamonds":1, "grantedModuleTickets":1, "grantedGemResetTickets":1}))
	await process_frame
	await process_frame
	var boxes: Array = entering.find_children("RewardBox", "", true, false)
	check(boxes.size() == 3 and boxes.all(func(box: Control) -> bool: return is_equal_approx(box.scale.x, RewardPopup.POP_FROM)), "Every box still waits in front after layout")
	await create_timer(1.0).timeout
	check(boxes.all(func(box: Control) -> bool: return is_equal_approx(box.scale.x, 1.0) and is_equal_approx(box.get_parent().get_parent().modulate.a, 1.0)), "Every box settles fully shown at its size")
	ProjectSettings.set_setting("accessibility/disable_animations", true)
	entering.close()
	await process_frame

func verify_list_states() -> void:
	var saved_mails: Array = service.mails
	var saved_page: int = service.page_size
	var now := int(Time.get_unix_time_from_system())
	var soon := mail("a", "임박", "본문 하나", 100000000, 99999)
	soon.expiresAt = Time.get_datetime_string_from_unix_time(now + 20 * 3600) + "Z"
	var relaxed := mail("b", "여유", "본문 둘", 1200, 0)
	relaxed.expiresAt = Time.get_datetime_string_from_unix_time(now + 12 * 86400 - 3600) + "Z"
	relaxed.readAt = "2026-09-27T12:00:00Z"
	var ending := mail("c", "마감", "본문 셋", 0, 0, 1)
	ending.expiresAt = Time.get_datetime_string_from_unix_time(now + 600) + "Z"
	var claimed := mail("d", "완료", "본문 넷", 5, 0)
	claimed.claimedAt = "2026-09-27T12:00:00Z"
	dimensions(Vector2i(440, 900))
	service.page_size = 30
	service.mails = [soon]
	lobby.open_service("우편함")
	await settle()
	var short_height: float = lobby.modal_frame.size.y
	lobby._services.mailbox.render()
	await settle()
	check(is_equal_approx(lobby.modal_frame.size.y, short_height), "A short list opens at its final height")
	service.mails = [soon, relaxed, ending, claimed]
	lobby.open_service("우편함")
	await settle()
	check(find_node("MailUnread0") != null and find_node("MailUnread1") == null, "Only unread mails carry the unread mark")
	check(labels(find_node("MailCard0")).contains("20시간 남음") and labels(find_node("MailCard1")).contains("12일 남음") and labels(find_node("MailCard2")).contains("곧 만료"), "Rows word the time left")
	check(labels(find_node("MailCard0")).contains("100M") and labels(find_node("MailCard0")).contains("100K"), "Boxes shorten large amounts")
	check(text_color(find_node("MailCard0"), "20시간 남음") == Color("ffb45c") and text_color(find_node("MailCard1"), "12일 남음") != Color("ffb45c"), "Only near expiry is emphasized")
	check(MailboxView._unix("2026-10-05T09:00:00+09:00") == MailboxView._unix("2026-10-05T00:00:00Z"), "Time left reads the server offset")
	var box: Control = find_node("MailCard0").find_child("RewardBox", true, false)
	var amount: Control = box.find_child("RewardAmount", true, false)
	check(box.size == Vector2.ONE * MailboxView.BOX and amount.position.y > box.size.y / 2, "Boxes keep their size with the amount in the corner")
	check(find_node("MailCard3").find_child("RewardBox", true, false).get_parent().modulate.a < 1.0 and is_equal_approx(box.get_parent().modulate.a, 1.0), "Only claimed rewards are dimmed")
	check(find_node("ClaimAllMail").size == Vector2(150, 48), "Bulk claim stays a short thick button")
	check(not labels(find_node("MailCard0")).contains("무료 다이아"), "Collapsed rows leave reward names to the expanded mail")
	check(find_node("ClaimMail3") == null and labels(find_node("MailCard3")).contains("수령 완료"), "Claimed row replaces its button")
	check(labels(find_node("MailboxFooter")).contains("받을 우편 3건") and find_node("ClaimAllMail").text == "모두 받기" and not find_node("ClaimAllMail").disabled, "Footer counts the claimable mails")
	check(not labels(find_node("MailboxFooter")).contains("한 번에"), "The bulk limit stays hidden within the limit")
	find_node("MailTitle0").pressed.emit()
	await settle()
	var opened := labels(find_node("MailCard0"))
	check(opened.contains("무료 다이아 100,000,000") and opened.contains("모듈권 99,999") and opened.contains("까지"), "Expanded mail shows reward names, exact amounts and the date")
	for item in service.mails: item.claimedAt = "2026-09-27T12:00:00Z"
	find_node("RefreshMailbox").pressed.emit()
	await settle()
	check(labels(find_node("MailboxFooter")).contains("받을 우편 없음") and find_node("ClaimAllMail").disabled, "Footer stays with nothing to claim")
	# Server pages hold 20 mails, so one long scroll must still reach the next page.
	service.page_size = 20
	service.mails = []
	for i in range(25): service.mails.append(mail("many-%d" % i, "우편 %d" % i, "본문", 1, 0))
	lobby.open_service("우편함")
	await settle()
	check(labels(find_node("MailboxFooter")).contains("받을 우편 20건 이상") and labels(find_node("MailboxFooter")).contains("한 번에 20건씩"), "Footer does not count unloaded pages as all mails")
	service.hold_page = true
	lobby.modal_scroll.scroll_vertical = 10000
	await settle()
	check(service.requests.count("GET v1/mailbox?cursor=page2") > 0 and find_node("ClaimAllMail").disabled, "One long scroll loads the next page and locks bulk claim")
	service.hold_page = false
	await settle()
	check(find_node("MailCard24") != null and labels(find_node("MailboxFooter")).contains("받을 우편 25건") and not labels(find_node("MailboxFooter")).contains("이상"), "Footer counts every loaded mail")
	check(labels(find_node("MailboxFooter")).contains("한 번에 20건씩"), "Footer explains the bulk limit past it")
	service.fail_claim = true
	lobby.modal_scroll.scroll_vertical = 0
	find_node("ClaimAllMail").pressed.emit()
	await settle()
	var notice: Control = find_node("MailboxNotice")
	check(notice != null and lobby.modal_frame.get_global_rect().encloses(notice.get_global_rect()), "A failed claim is told in the pinned footer")
	check(find_node("ClaimAllMail").size == Vector2(150, 48), "A footer notice leaves the button size")
	service.fail_claim = false
	find_node("ClaimAllMail").pressed.emit()
	await settle()
	check(service.claims.back().values.ids.size() == 20, "Bulk claim stops at the limit")
	for i in range(20): service.mails[i].claimedAt = "2026-09-27T12:00:00Z"
	lobby.open_service("우편함")
	await settle()
	check(labels(find_node("MailboxFooter")).contains("불러온 우편은 모두 받았습니다") and not labels(find_node("MailboxFooter")).contains("받을 우편 없음"), "Claimed first page does not claim the mailbox is empty")
	service.offline = true
	lobby._services.mailbox.render()
	await settle()
	check(find_node("MailboxFooter") == null, "A disconnected view drops the footer")
	service.offline = false
	service.mails = []
	find_node("RefreshMailbox").pressed.emit()
	await settle()
	check(find_node("MailboxFooter") == null and labels(lobby.modal).contains("도착한 우편이 없습니다."), "An empty mailbox has no footer")
	service.mails = saved_mails
	service.page_size = saved_page

func text_color(node: Node, text: String) -> Color:
	for label in node.find_children("*", "Label", true, false):
		if label.text == text: return label.get_theme_color("font_color")
	return Color.TRANSPARENT

func find_node(name: String) -> Node:
	return lobby.modal.find_child(name, true, false) if is_instance_valid(lobby.modal) else null

func modal_ids() -> Array:
	return [lobby.modal.get_instance_id(), lobby.modal_frame.get_instance_id(),
		lobby.modal_visual.get_instance_id(), lobby.modal_scroll.get_instance_id(), lobby.modal_body.get_instance_id()]

func labels(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree(): return ""
	var result: String = (node.text + "\n") if node is Label or node is Button else ""
	for child in node.get_children(): result += labels(child)
	return result

func dimensions(value: Vector2i) -> void:
	root.size = value
	root.content_scale_size = value
	lobby.set_deferred("size", Vector2(value))

func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func wheel_down() -> void:
	var event := InputEventMouseButton.new()
	event.position = lobby.modal_scroll.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame

func touch_swipe_up() -> void:
	var point: Vector2 = lobby.modal_scroll.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = point
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point - Vector2(0, 50)
	drag.relative = Vector2(0, -50)
	Input.parse_input_event(drag)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = drag.position
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func mail(id: String, title: String, body: String, diamonds: int, tickets: int, gem_tickets: int = 0) -> Dictionary:
	return {"id": id, "title": title, "body": body, "freeDiamonds": diamonds,
		"moduleTickets": tickets, "gemResetTickets": gem_tickets, "expiresAt": "2026-10-05T00:00:00Z", "readAt": null, "claimedAt": null}

func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations", true)
	var app := Fixture.FakeApp.new()
	app.catalog.load_catalog()
	app.run_domain.growth.load_catalog()
	service = Service.new()
	service.tree = self
	service.mails = [
		mail("mail-1", "업데이트 기념 선물", "모험가 여러분께 감사드립니다.\n무료 다이아와 모듈권을 받아 주세요.", 100, 3),
		mail("mail-2", "모험 지원 보상", "모험을 계속해 주세요.", 0, 0, 7),
		mail("mail-3", "새로운 지역 탐험을 축하드립니다", "새 지역의 보상을 확인해 주세요.", 100000000, 99999),
	]
	app.services = service
	lobby = Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	dimensions(Vector2i(440, 900))
	await settle()
	if int(Time.get_time_zone_from_system().get("bias", 0)) == 540:
		check(MailboxView._expires("2026-10-05T00:00:00Z") == "2026.10.05 09:00까지", "UTC expiry is converted to Korea local time")
	lobby.open_service("우편함")
	var opened_ids := modal_ids()
	await settle()
	check(modal_ids() == opened_ids, "Initial response retains the modal, frame, visual, scroll, and body")
	check(service.requests.count("GET v1/mailbox") == 1, "Opening fetches the first page once")
	check(service.requests.count("GET v1/mailbox?cursor=page2") == 1, "Short first page auto-loads one continuation")
	check(find_node("MailCard2") != null and find_node("MoreMail") == null, "Continued page appears without a more button")
	check(find_node("MailBody0") == null and find_node("MailBody1") == null, "Bodies start collapsed")
	check(find_node("ClaimMail0") != null and find_node("ClaimAllMail") != null, "Individual and bulk claim remain available")
	var first_mail: Node = find_node("MailCard0")
	check(first_mail.find_children("RewardAmount", "", true, false).size() == 2 and labels(first_mail).contains("100") and labels(first_mail).contains("3"), "Reward amounts remain visible when collapsed")
	var gem_mail: Node = find_node("MailCard1")
	check(gem_mail.find_child("RewardAmount", true, false).text == "7" and not labels(gem_mail).contains("보상 없음"), "Ticket-only mail displays gem reset quantity instead of no reward")
	var gem_ticket_icons := 0
	for icon in gem_mail.find_children("*", "TextureRect", true, false):
		if icon.texture != null and icon.texture.resource_path.ends_with("ui/hud/icons/gem_reset_ticket.png"): gem_ticket_icons += 1
	check(gem_ticket_icons == 1, "Ticket-only mail reuses the approved gem reset ticket icon")
	await capture("mailbox-auto-440-collapsed")
	service.hold_read = true
	find_node("MailTitle0").pressed.emit()
	await settle()
	check(find_node("MailBody0") != null and find_node("MailBody1") == null, "Selection opens one body")
	check(service.requests.count("POST v1/mailbox/mail-1/read") == 1, "Opening an unread mail calls read once")
	find_node("MailTitle1").pressed.emit()
	await settle()
	check(find_node("MailBody0") == null and find_node("MailBody1") != null, "Switching selection keeps one body open during delayed read")
	service.hold_read = false
	await settle()
	check(find_node("MailBody1") != null and find_node("MailBody0") == null, "Delayed first read does not replace new selection")
	check(service.requests.count("POST v1/mailbox/mail-1/read") == 1 and service.requests.count("POST v1/mailbox/mail-2/read") == 1, "Delayed reads do not duplicate")
	check(modal_ids() == opened_ids, "Read and selection updates retain the existing modal shell")
	check(lobby.modal.find_children("MailboxTouchScrollObserver", "Node", true, false).size() == 1, "Rerenders retain a single touch scroll observer")
	find_node("MailTitle0").pressed.emit()
	await settle()
	await capture("mailbox-auto-440-expanded")
	find_node("MailTitle0").pressed.emit()
	await settle()
	check(find_node("MailBody0") == null, "Second title press collapses the body")
	check(find_node("MailCard2") != null, "Reading a mail preserves auto-loaded pages")
	check(service.requests.count("GET v1/mailbox?cursor=page2") == 1, "Read does not duplicate the next page")
	ProjectSettings.set_setting("accessibility/disable_animations", false)
	find_node("RefreshMailbox").pressed.emit()
	check(modal_ids() == opened_ids and is_equal_approx(lobby.modal_visual.modulate.a, 1.0), "Refresh keeps the visible modal without restarting entrance animation")
	await settle()
	check(modal_ids() == opened_ids, "Refresh response keeps the same modal shell")
	await capture("mailbox-refresh-440-stable")
	ProjectSettings.set_setting("accessibility/disable_animations", true)

	service.fail_page = true
	lobby.open_service("우편함")
	await settle()
	var failed_count := service.requests.count("GET v1/mailbox?cursor=page2")
	check(find_node("RetryMailPage") != null and failed_count == 3, "Failed continuation exposes retry")
	await settle()
	check(service.requests.count("GET v1/mailbox?cursor=page2") == failed_count, "Failure does not auto-retry forever")
	service.fail_page = false
	find_node("RetryMailPage").pressed.emit()
	await settle()
	check(find_node("MailCard2") != null and find_node("RetryMailPage") == null, "Explicit retry appends the page")
	check(service.requests.count("GET v1/mailbox?cursor=page2") == failed_count + 1, "Retry makes exactly one request")
	check(not find_node("RefreshMailbox").disabled, "Refresh becomes available after auto loading")
	service.repeat_cursor = true
	lobby.open_service("우편함")
	await settle()
	check(lobby._services.mailbox.data.get("nextCursor") == null, "Repeated server cursor stops pagination")
	var repeated_count := service.requests.count("GET v1/mailbox?cursor=page2")
	await settle()
	check(service.requests.count("GET v1/mailbox?cursor=page2") == repeated_count, "Repeated cursor never loops")
	service.repeat_cursor = false

	dimensions(Vector2i(440, 568))
	service.page_size = 6
	for i in range(4, 9): service.mails.append(mail("mail-%d" % i, "추가 보상 우편 %d" % i, "추가 본문 %d" % i, i * 10, 0))
	lobby.open_service("우편함")
	await settle()
	check(lobby.modal_frame.get_global_rect().end.x <= 440.1 and lobby.modal_frame.get_global_rect().end.y <= 568.1, "Narrow modal fits viewport")
	var scroll_page_count := service.requests.count("GET v1/mailbox?cursor=page2")
	check(find_node("MailCard5") != null and find_node("MailCard6") == null, "Scrollable first page waits for bottom")
	check(find_node("MoreMail") == null, "Normal page has no more button")
	service.busy = true
	lobby.modal_scroll.scroll_vertical = 10000
	await settle()
	check(service.requests.count("GET v1/mailbox?cursor=page2") == scroll_page_count, "Busy service blocks continuation")
	service.busy = false
	lobby.modal_scroll.scroll_vertical = 0
	await settle()
	gem_mail = find_node("MailCard1")
	check(gem_mail.find_child("RewardAmount", true, false).text == "7" and not labels(gem_mail).contains("보상 없음"), "Ticket-only reward survives narrow layout and refresh")
	check(gem_mail.find_child("RewardBox", true, false).get_global_rect().end.x <= gem_mail.get_global_rect().end.x, "Gem ticket box fits the narrow reward row")
	await capture("mailbox-auto-440-before-scroll")
	service.hold_page = true
	for i in range(25): await wheel_down()
	await settle()
	var before_append: int = lobby.modal_scroll.scroll_vertical
	check(before_append > 0, "Actual wheel input scrolls narrow mailbox")
	check(service.requests.count("GET v1/mailbox?cursor=page2") == scroll_page_count + 1, "Reaching final mail loads next page once")
	check(find_node("MailboxPageLoading") != null, "Existing list remains visible while the page loads")
	service.hold_page = false
	await settle()
	check(find_node("MailCard7") != null and lobby.modal_scroll.scroll_vertical >= before_append - 1, "Auto append preserves cards and scroll")
	check(service.requests.count("GET v1/mailbox?cursor=page2") == scroll_page_count + 1, "Repeated bottom signals do not duplicate fetch")
	lobby.modal_scroll.scroll_vertical = 10000
	await settle()
	await capture("mailbox-auto-440-after-scroll")
	var pinned: Control = find_node("MailboxFooter")
	check(pinned != null and not lobby.modal_scroll.is_ancestor_of(pinned) and lobby.modal_frame.get_global_rect().encloses(pinned.get_global_rect()), "Bulk claim stays pinned outside the scrolled list")
	find_node("MailTitle7").pressed.emit()
	await settle()
	check(find_node("MailBody7") != null, "Last-page mail can expand")
	await capture("mailbox-auto-440-last-expanded")
	find_node("ClaimAllMail").pressed.emit()
	var claim_ids := modal_ids()
	await settle()
	check(modal_ids() == claim_ids, "Claim and its refetch retain the existing modal shell")
	check(service.claims.size() == 1 and service.claims[0].action == "mail_claim_all", "Bulk claim action retains service contract")
	check(service.claims[0].values.ids.size() == 8, "Bulk claim passes loaded mail IDs")

	service.hold_fetch = true
	find_node("RefreshMailbox").pressed.emit()
	lobby.close_modal()
	service.hold_fetch = false
	await settle()
	check(not is_instance_valid(lobby.modal), "Late refresh response cannot reopen a dismissed mailbox")
	service.mails[0].claimedAt = null
	lobby.open_service("우편함")
	await settle()
	service.hold_claim = true
	find_node("ClaimMail0").pressed.emit()
	var fetches_before_claim := service.requests.count("GET v1/mailbox")
	lobby.open_modal("다른 대화상자")
	var replacement_id: int = lobby.modal.get_instance_id()
	service.hold_claim = false
	await settle()
	check(lobby.modal.get_instance_id() == replacement_id and service.requests.count("GET v1/mailbox") == fetches_before_claim, "Late claim cannot replace another modal or start a mailbox refetch")
	check(lobby.modal.get_node_or_null("RewardPopup") == null, "Late claim leaves no result over another modal")
	await verify_claim_feedback()
	await verify_list_states()

	service.page_size = 2
	service.mails = service.mails.slice(0, 3)
	service.hold_page = true
	lobby.open_service("우편함")
	await settle()
	check(not lobby._services.mailbox.mail_auto_loading_cursor.is_empty(), "Short page continuation is in flight")
	lobby.close_modal()
	service.hold_page = false
	lobby.open_service("우편함")
	await settle()
	check(lobby._services.mailbox.data.get("mails", []).size() == 3, "Late response from closed view cannot duplicate reentered list")

	# Claims stay server-authoritative and preserve the expanded mail after refetch.
	service.mails[0].claimedAt = null
	lobby.open_service("우편함")
	await settle()
	find_node("MailTitle0").pressed.emit()
	await settle()
	find_node("ClaimMail0").pressed.emit()
	await settle()
	check(service.claims.back().action == "mail_claim" and service.claims.back().values == {"id": "mail-1"}, "Single claim uses the authoritative perform contract")
	check(find_node("MailBody0") != null and find_node("ClaimMail0") == null, "Single claim refetch preserves expansion and shows server claimed state")
	await capture("mailbox-440-after-single-claim")

	service.mails[1].claimedAt = null
	find_node("RefreshMailbox").pressed.emit()
	await settle()
	var old_claim: Callable = find_node("ClaimMail1").pressed.get_connections()[0].callable
	lobby.open_service("우편함")
	await settle()
	var claims_before_old_button := service.claims.size()
	old_claim.call()
	await settle()
	check(service.claims.size() == claims_before_old_button, "A previous view claim callback cannot submit mail IDs after reopening")
	find_node("MailTitle0").pressed.emit()
	await settle()

	# A read started in a dismissed view must not change a reopened selection.
	service.mails[0].readAt = null
	service.mails[1].readAt = null
	service.hold_read = true
	find_node("MailTitle0").pressed.emit()
	find_node("MailTitle0").pressed.emit()
	await settle()
	lobby.close_modal()
	lobby.open_service("우편함")
	await settle()
	find_node("MailTitle1").pressed.emit()
	await settle()
	service.hold_read = false
	await settle()
	check(find_node("MailBody1") != null and find_node("MailBody0") == null, "Late read from a closed view preserves the reopened selection")
	check(lobby._services.mailbox.read_pending_id.is_empty() and not lobby._services.mailbox.pending, "Old read completion does not retain request state in the reopened controller")

	# Even a successful response is stale after an account binding changes.
	service.hold_fetch = true
	lobby.open_service("우편함")
	await settle()
	service.epoch += 1
	service.hold_fetch = false
	await settle()
	check(lobby._services.mailbox.data.is_empty() and find_node("MailCard0") == null, "Account epoch change discards the old successful mailbox fetch")
	lobby.open_service("우편함")
	await settle()
	service.mails[0].claimedAt = null
	find_node("RefreshMailbox").pressed.emit()
	await settle()
	var account_claim: Callable = find_node("ClaimMail0").pressed.get_connections()[0].callable
	var account_refresh: Callable = find_node("RefreshMailbox").pressed.get_connections()[0].callable
	var claims_before_stale_account := service.claims.size()
	var requests_before_stale_account := service.requests.size()
	service.epoch += 1
	account_claim.call()
	account_refresh.call()
	find_node("MailTitle0").pressed.emit()
	await settle()
	check(service.claims.size() == claims_before_stale_account and service.requests.size() == requests_before_stale_account, "Old account callbacks cannot start read, claim, or fetch requests")
	check(find_node("MailBody0") == null, "Old account title callback cannot change expansion")
	lobby.open_service("우편함")
	await settle()
	service.hold_claim = true
	find_node("ClaimMail0").pressed.emit()
	var fetches_before_epoch_change := service.requests.count("GET v1/mailbox")
	service.epoch += 1
	service.hold_claim = false
	await settle()
	check(service.requests.count("GET v1/mailbox") == fetches_before_epoch_change, "Stale account claim completion cannot refetch the new account mailbox")

	# Replacing the service object also invalidates in-flight mailbox requests.
	service.hold_fetch = true
	lobby.open_service("우편함")
	await settle()
	var previous_service := service
	service = Service.new()
	service.tree = self
	service.mails = [mail("new-account", "새 계정 우편", "새 본문", 30, 0)]
	app.services = service
	lobby.open_service("우편함")
	await settle()
	previous_service.hold_fetch = false
	await settle()
	check(lobby._services.mailbox.data.mails.size() == 1 and lobby._services.mailbox.data.mails[0].id == "new-account", "Old service response cannot replace the new account mailbox")

	service.page_size = 1
	service.one_by_one = true
	service.mails = [mail("short-1", "짧은 첫 페이지", "본문", 10, 0), mail("short-2", "짧은 두 번째 페이지", "본문", 20, 0), mail("short-3", "마지막 페이지", "본문", 30, 0)]
	dimensions(Vector2i(440, 900))
	lobby.open_service("우편함")
	await settle()
	check(lobby._services.mailbox.data.get("mails", []).size() == 2 and service.requests.count("GET v1/mailbox?cursor=page3") == 0, "Short pages do not preload the entire mailbox")
	await wheel_down()
	await settle()
	check(lobby._services.mailbox.data.get("mails", []).size() == 3 and service.requests.count("GET v1/mailbox?cursor=page3") == 1, "A downward gesture continues even without a scrollbar")
	lobby.open_service("우편함")
	await settle()
	await touch_swipe_up()
	await settle()
	check(lobby._services.mailbox.data.get("mails", []).size() == 3 and service.requests.count("GET v1/mailbox?cursor=page3") == 2, "A touch swipe continues short pages without a scrollbar")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
