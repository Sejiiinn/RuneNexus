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
	func connected() -> bool: return true
	func needs_profile() -> bool: return false
	func request(method: String, path: String, _body: Dictionary = {}) -> Dictionary:
		requests.append(method + " " + path)
		await tree.process_frame
		if method == "GET":
			if path == "v1/mailbox": return {"ok": true, "body": {"mails": mails.slice(0, 2).duplicate(true), "nextCursor": "page2"}}
			if path == "v1/mailbox?cursor=page2": return {"ok": true, "body": {"mails": mails.slice(2, 3).duplicate(true), "nextCursor": null}}
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
	check(service.requests.size() == 1 and service.requests[0] == "GET v1/mailbox", "Opening fetches the first page once")
	check(find_node("MailCard0") != null and find_node("MailCard1") != null, "Metal cards render both mails")
	check(find_node("MailBody0") == null and find_node("MailBody1") == null, "Bodies start collapsed")
	check(find_node("ClaimMail0") != null and find_node("ClaimAllMail") != null, "Individual and bulk claim remain available")
	check(labels(lobby.modal).contains("무료 다이아 100") and labels(lobby.modal).contains("모듈권 3"), "Reward amounts remain visible when collapsed")
	check(find_node("MoreMail") != null, "Pagination is available")
	await capture("mailbox-440-collapsed")
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
	await capture("mailbox-440-expanded")
	find_node("MailTitle0").pressed.emit()
	await settle()
	check(find_node("MailBody0") == null, "Second title press collapses the body")
	find_node("MoreMail").pressed.emit()
	await settle()
	check(find_node("MailCard2") != null, "Next page appends a mail")
	find_node("MailTitle2").pressed.emit()
	await settle()
	check(find_node("MailCard2") != null and find_node("MailBody2") != null, "Reading a later page retains loaded pages")
	check(service.requests.count("GET v1/mailbox") == 1, "Read never resets pagination to page one")
	dimensions(Vector2i(320, 568))
	await settle()
	check(lobby.modal_frame.get_global_rect().end.x <= 320.1 and lobby.modal_frame.get_global_rect().end.y <= 568.1, "Narrow modal fits viewport")
	lobby._services.expanded_mail_id = ""
	lobby._services._render()
	await settle()
	await capture("mailbox-320-collapsed")
	find_node("MailTitle0").pressed.emit()
	await settle()
	await capture("mailbox-320-expanded")
	check(find_node("MailBody0") != null, "Narrow view can expand a mail")
	var scroll = lobby.modal_scroll
	await settle()
	scroll.scroll_vertical = 100000
	await settle()
	check(find_node("ClaimAllMail").get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "Narrow footer scrolls fully into view")
	check(find_node("ClaimMail2").get_global_rect().position.y >= scroll.get_global_rect().position.y, "Narrow last card claim is visible at bottom")
	check(find_node("ClaimAllMail").get_global_rect().end.x < 320, "Narrow footer stays within screen width")
	var old_scroll := int(scroll.scroll_vertical)
	find_node("MailTitle2").pressed.emit()
	await settle()
	print("SCROLL_BEFORE=", old_scroll, " AFTER=", lobby.modal_scroll.scroll_vertical, " BODY_RECT=", find_node("MailBody2").get_global_rect())
	check(lobby.modal_scroll.scroll_vertical > 0, "Expanding lower mail preserves scroll")
	var V = preload("res://ui/mailbox_view.gd")
	check(V._expires("2026-10-05T00:00:00Z") == "2026.10.05 09:00까지", "UTC displays local KST")
	check(V._expires("2026-10-05T09:00:00+09:00") == "2026.10.05 09:00까지", "Positive timezone offset preserves instant")
	check(V._expires("2026-10-04T20:00:00.123-04:00") == "2026.10.05 09:00까지", "Fractional negative timezone preserves instant")
	find_node("ClaimAllMail").pressed.emit()
	await settle()
	check(service.claims.size() == 1 and service.claims[0].action == "mail_claim_all", "Bulk claim action retains service contract")
	check(service.claims[0].values.ids.size() == 3, "Bulk claim passes loaded mail IDs")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
