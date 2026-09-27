extends SceneTree
## Isolated mailbox fixture: no account, save, or server request is touched.
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
const MailboxView = preload("res://ui/mailbox_view.gd")

class Service extends RefCounted:
	var tree: SceneTree
	var busy := false
	var updates := {"blocked": false}
	var mails: Array = []
	var requests: Array = []
	var claims: Array = []
	var hold_read := false
	var hold_page := false
	var fail_page := false
	var repeat_cursor := false
	var one_by_one := false
	var page_size := 2
	func connected() -> bool: return true
	func needs_profile() -> bool: return false
	func request(method: String, path: String, _body: Dictionary = {}) -> Dictionary:
		requests.append(method + " " + path)
		await tree.process_frame
		if method == "GET":
			if path == "v1/mailbox": return {"ok": true, "body": {"mails": mails.slice(0, page_size).duplicate(true), "nextCursor": "page2" if mails.size() > page_size else null}}
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
		return {"ok": true, "body": {}}

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

func find_node(name: String) -> Node:
	return lobby.modal.find_child(name, true, false) if is_instance_valid(lobby.modal) else null

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

func mail(id: String, title: String, body: String, diamonds: int, tickets: int) -> Dictionary:
	return {"id": id, "title": title, "body": body, "freeDiamonds": diamonds,
		"moduleTickets": tickets, "expiresAt": "2026-10-05T00:00:00Z", "readAt": null, "claimedAt": null}

func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations", true)
	var app := Fixture.FakeApp.new()
	app.catalog.load_catalog()
	app.run_domain.growth.load_catalog()
	service = Service.new()
	service.tree = self
	service.mails = [
		mail("mail-1", "업데이트 기념 선물", "모험가 여러분께 감사드립니다.\n무료 다이아와 모듈권을 받아 주세요.", 100, 3),
		mail("mail-2", "모험 지원 보상", "모험을 계속해 주세요.", 50, 0),
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
	await settle()
	check(service.requests.count("GET v1/mailbox") == 1, "Opening fetches the first page once")
	check(service.requests.count("GET v1/mailbox?cursor=page2") == 1, "Short first page auto-loads one continuation")
	check(find_node("MailCard2") != null and find_node("MoreMail") == null, "Continued page appears without a more button")
	check(find_node("MailBody0") == null and find_node("MailBody1") == null, "Bodies start collapsed")
	check(find_node("ClaimMail0") != null and find_node("ClaimAllMail") != null, "Individual and bulk claim remain available")
	check(labels(lobby.modal).contains("무료 다이아 100") and labels(lobby.modal).contains("모듈권 3"), "Reward amounts remain visible when collapsed")
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
	find_node("MailTitle0").pressed.emit()
	await settle()
	await capture("mailbox-auto-440-expanded")
	find_node("MailTitle0").pressed.emit()
	await settle()
	check(find_node("MailBody0") == null, "Second title press collapses the body")
	check(find_node("MailCard2") != null, "Reading a mail preserves auto-loaded pages")
	check(service.requests.count("GET v1/mailbox?cursor=page2") == 1, "Read does not duplicate the next page")

	service.fail_page = true
	lobby.open_service("우편함")
	await settle()
	var failed_count := service.requests.count("GET v1/mailbox?cursor=page2")
	check(find_node("RetryMailPage") != null and failed_count == 2, "Failed continuation exposes retry")
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
	check(lobby._services.data.get("nextCursor") == null, "Repeated server cursor stops pagination")
	var repeated_count := service.requests.count("GET v1/mailbox?cursor=page2")
	await settle()
	check(service.requests.count("GET v1/mailbox?cursor=page2") == repeated_count, "Repeated cursor never loops")
	service.repeat_cursor = false

	dimensions(Vector2i(320, 568))
	service.page_size = 6
	for i in range(4, 9): service.mails.append(mail("mail-%d" % i, "추가 보상 우편 %d" % i, "추가 본문 %d" % i, i * 10, 0))
	lobby.open_service("우편함")
	await settle()
	check(lobby.modal_frame.get_global_rect().end.x <= 320.1 and lobby.modal_frame.get_global_rect().end.y <= 568.1, "Narrow modal fits viewport")
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
	await capture("mailbox-auto-320-before-scroll")
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
	await capture("mailbox-auto-320-after-scroll")
	check(find_node("MailboxFooter") != null and lobby.modal_scroll.get_global_rect().intersects(find_node("MailboxFooter").get_global_rect()), "Bulk claim remains reachable after append")
	find_node("MailTitle7").pressed.emit()
	await settle()
	check(find_node("MailBody7") != null, "Last-page mail can expand")
	await capture("mailbox-auto-320-last-expanded")
	find_node("ClaimAllMail").pressed.emit()
	await settle()
	check(service.claims.size() == 1 and service.claims[0].action == "mail_claim_all", "Bulk claim action retains service contract")
	check(service.claims[0].values.ids.size() == 8, "Bulk claim passes loaded mail IDs")

	service.page_size = 2
	service.mails = service.mails.slice(0, 3)
	service.hold_page = true
	lobby.open_service("우편함")
	await settle()
	check(not lobby._services.mail_auto_loading_cursor.is_empty(), "Short page continuation is in flight")
	lobby.close_modal()
	service.hold_page = false
	lobby.open_service("우편함")
	await settle()
	check(lobby._services.data.get("mails", []).size() == 3, "Late response from closed view cannot duplicate reentered list")

	service.page_size = 1
	service.one_by_one = true
	service.mails = [mail("short-1", "짧은 첫 페이지", "본문", 10, 0), mail("short-2", "짧은 두 번째 페이지", "본문", 20, 0), mail("short-3", "마지막 페이지", "본문", 30, 0)]
	dimensions(Vector2i(440, 900))
	lobby.open_service("우편함")
	await settle()
	check(lobby._services.data.get("mails", []).size() == 2 and service.requests.count("GET v1/mailbox?cursor=page3") == 0, "Short pages do not preload the entire mailbox")
	await wheel_down()
	await settle()
	check(lobby._services.data.get("mails", []).size() == 3 and service.requests.count("GET v1/mailbox?cursor=page3") == 1, "A downward gesture continues even without a scrollbar")
	lobby.open_service("우편함")
	await settle()
	await touch_swipe_up()
	await settle()
	check(lobby._services.data.get("mails", []).size() == 3 and service.requests.count("GET v1/mailbox?cursor=page3") == 2, "A touch swipe continues short pages without a scrollbar")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
