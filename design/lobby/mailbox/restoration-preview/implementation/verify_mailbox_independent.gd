extends SceneTree
## Isolated mailbox fixture: no account, save, or server request is touched.
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")

class Service extends RefCounted:
	var tree: SceneTree
	var busy := false
	var updates := {"blocked": false}
	var mails: Array = []
	var requests: Array = []
	var claims: Array = []
	var hold_read := false
	var fail_read := false
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
			if fail_read: return {"ok":false, "code":"REQUEST_FAILED"}
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
	await capture("mailbox-440-expanded")
	find_node("MailTitle1").pressed.emit()
	await settle()
	check(find_node("MailBody0") == null and find_node("MailBody1") != null, "Switching selection keeps one body open during delayed read")
	service.hold_read = false
	await settle()
	check(find_node("MailBody1") != null and find_node("MailBody0") == null, "Delayed first read does not replace new selection")
	check(service.requests.count("POST v1/mailbox/mail-1/read") == 1 and service.requests.count("POST v1/mailbox/mail-2/read") == 1, "Delayed reads do not duplicate")
	find_node("MailTitle1").pressed.emit()
	await settle()
	check(find_node("MailBody1") == null, "Second title press collapses the body")
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
	find_node("MailTitle2").pressed.emit()
	await settle()
	await capture("mailbox-320-expanded")
	check(find_node("MailBody2") != null, "Narrow view can expand a mail")
	find_node("ClaimAllMail").pressed.emit()
	await settle()
	check(service.claims.size() == 1 and service.claims[0].action == "mail_claim_all", "Bulk claim action retains service contract")
	check(service.claims[0].values.ids.size() == 3, "Bulk claim passes loaded mail IDs")

	service.busy = true
	lobby._services._render()
	await settle()
	check(find_node("ClaimAllMail").disabled and find_node("RefreshMailbox").disabled, "Busy disables shared actions")
	service.busy = false
	service.mails[0].readAt = null
	service.fail_read = true
	lobby.open_service("우편함")
	await settle()
	find_node("MailTitle0").pressed.emit()
	await settle()
	check(lobby._services.data.mails[0].readAt == null, "Failed read never falsely marks read")
	check(not lobby._services.pending and not lobby._services.notice.is_empty(), "Failed read releases pending and reports failure")
	check(find_node("MailBody0") != null, "Failed read retains selected body")
	service.fail_read = false
	service.hold_read = true
	find_node("MailTitle0").pressed.emit()
	find_node("MailTitle0").pressed.emit()
	await settle()
	lobby.close_modal()
	service.hold_read = false
	await settle()
	check(not is_instance_valid(lobby.modal), "Late read cannot reopen dismissed modal")
	lobby.open_service("우편함")
	await settle()
	check(find_node("MailBody0") == null, "Reopened mailbox starts collapsed after late response")
	service.mails[0].claimedAt = null
	lobby._services._fetch()
	await settle()
	find_node("ClaimMail0").pressed.emit()
	await settle()
	check(service.claims[-1].action == "mail_claim" and service.claims[-1].values.id == "mail-1", "Individual claim preserves action and ID")
	check(find_node("ClaimMail0") == null and labels(lobby.modal).contains("수령 완료"), "Claim response refreshes claimed state")
	var many: Array = []
	for i in 25: many.append(mail("bulk-%d" % i, "대량 우편", "본문", 1, 1))
	lobby._services.data = {"mails":many}
	lobby._services._render()
	await settle()
	find_node("ClaimAllMail").pressed.emit()
	await settle()
	check(service.claims[-1].values.ids.size() == 20, "Bulk claim is capped at 20 loaded IDs")
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(1 if not failures.is_empty() else 0)
