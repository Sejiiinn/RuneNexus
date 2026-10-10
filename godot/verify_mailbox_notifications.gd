extends SceneTree
## Real AppServices/account lifecycle with an in-memory transport; no live API.
const Fixture = preload("res://verify_app_services.gd")
const Services = preload("res://services/app_services.gd")
const Auth = preload("res://services/account_session.gd")
const Economy = preload("res://services/economy_service.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const ACCOUNT_A := Fixture.ACCOUNT_A
const ACCOUNT_B := Fixture.ACCOUNT_B

class Server extends Fixture.FixtureServer:
	var counts := {ACCOUNT_A: 24, ACCOUNT_B: 2}
	var summaries: Array = []
	var held: Array = []
	var hold_next := false
	var fail_summary := false
	var invalid_summary := false
	func request(method, url, raw := "", headers := {}) -> Dictionary:
		var path: String = url.trim_prefix("http://127.0.0.1:19764")
		if path == "/v1/mailbox/summary":
			calls.append({"method":method,"path":path})
			var index := summaries.size()
			var value: Variant = "invalid" if invalid_summary else counts.get(active, 0)
			var result := reply(503, {}, "NETWORK_UNAVAILABLE") if fail_summary else reply(200, {"unclaimedCount":value})
			summaries.append({"owner":active,"result":result})
			if hold_next: held.append(index); hold_next = false
			await tree.process_frame
			while index in held: await tree.process_frame
			return result
		if path == "/v1/mailbox" or path.ends_with("/read"):
			await tree.process_frame
			return reply(200, {"read":true} if path.ends_with("/read") else {"mails":[],"nextCursor":null})
		if path.begins_with("/v1/mailbox/") and (path.ends_with("/claim") or path.ends_with("/claim-all")):
			await tree.process_frame
			counts[active] = 0 if path.ends_with("/claim-all") else maxi(0, int(counts[active]) - 1)
			economy_revision += 1
			return reply(200, {"economy":economy_snapshot()})
		return await super.request(method, url, raw, headers)

var failures: Array[String] = []
var checks := 0
var app
var service
var platform
var server: Server
var folder := ""

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func frames(count := 4) -> void:
	for i in count: await process_frame
func make_service():
	var coordinator = Services.new()
	coordinator.app = app
	coordinator.root_path = folder
	coordinator.platform = platform
	coordinator.config = {"googleClientId":"fixture-client"}
	root.add_child(coordinator)
	coordinator.set_process(false)
	coordinator.account = Auth.new()
	coordinator.add_child(coordinator.account)
	coordinator.account.configure("http://127.0.0.1:19764", platform, server)
	coordinator.economy = Economy.new()
	coordinator.add_child(coordinator.economy)
	app.services = coordinator
	return coordinator
func dispose_service(coordinator) -> void:
	if coordinator.online != null: coordinator.online.dispose()
	coordinator.queue_free()

func run() -> void:
	folder = OS.get_environment("RUNE_APP_TEST_ROOT").path_join("mailbox-notifications")
	if not folder.is_absolute_path(): quit(2); return
	app = Fixture.AppStub.new()
	app.run_domain.growth.load_catalog()
	app.checkpoint = Checkpoint.new(folder)
	app.retry_load()
	platform = Fixture.Platform.new(); root.add_child(platform)
	server = Server.new(); server.tree = self
	service = make_service()
	service.refresh_mailbox_summary()
	check(server.summaries.is_empty(), "Guest startup sends no mailbox request")
	var result: Dictionary = await service.login()
	check(result.ok and server.summaries.is_empty(), "Nickname gate waits before mailbox query")
	result = await service.request("PUT", "v1/account/nickname", {"nickname":"우편검증"})
	await frames()
	check(result.ok and server.summaries.size() == 1 and service.mailbox_unclaimed_count == 24, "Profile completion queries summary once, including mail beyond page 20")
	check(service.has_unclaimed_mail(), "First successful login publishes the mail badge")
	var saved_command: Dictionary = app.checkpoint.rewards().state.duplicate(true)
	saved_command.inFlight = {"kind":"mail_claim_all","path":"v1/mailbox/claim-all","idempotencyKey":"00000000-0000-4000-8000-000000000099","encodedBody":'{"clientCompatibilityVersion":5,"mailIds":["00000000-0000-4000-8000-000000000005"]}',"createdAtMillis":1}
	check(app.checkpoint.rewards().save_state(saved_command) == OK, "Pending mail receipt is durably stored for cold recovery")
	# A new app restores secure credentials and checks mail without opening a modal.
	dispose_service(service); await frames()
	service = make_service()
	server.counts[ACCOUNT_A] = 3
	server.hold_next = true
	await service._initialize()
	check(service.online_ready and not service.busy and service._mailbox_pending, "Cold restore starts nonblocking mailbox check after account bootstrap")
	var startup_request := server.summaries.size() - 1
	var count := server.summaries.size()
	for i in 5: service.refresh_mailbox_summary()
	check(server.summaries.size() == count, "Repeated refreshes coalesce while the summary is pending")
	server.held.erase(startup_request); await frames()
	check(service.mailbox_unclaimed_count == 0 and not service.has_unclaimed_mail() and app.checkpoint.rewards().state.inFlight == null, "Cold-start summary reflects recovered mail claim instead of its stale pre-claim count")
	server.counts[ACCOUNT_A] = 3
	service.refresh_mailbox_summary(); await frames()
	check(service.mailbox_unclaimed_count == 3 and service.has_unclaimed_mail(), "New mail updates badge without opening mailbox")
	# Network and malformed responses preserve known state and retry at a cadence.
	server.fail_summary = true
	service.refresh_mailbox_summary(); await frames()
	count = server.summaries.size()
	for i in 10: service._process(0)
	check(server.summaries.size() == count and service.has_unclaimed_mail(), "Failure retains badge and avoids per-frame retries")
	server.fail_summary = false; server.invalid_summary = true
	service.refresh_mailbox_summary(); await frames()
	check(service.mailbox_unclaimed_count == 3, "Malformed count cannot clear the last known badge")
	server.invalid_summary = false; server.counts[ACCOUNT_A] = 4
	service._mailbox_refresh_at = 0
	service._process(0); await frames()
	check(service.mailbox_unclaimed_count == 4, "Scheduled retry recovers new mail after initial failure")
	server.counts[ACCOUNT_A] = 5
	result = await service.retry(); await frames()
	check(result.ok and service.mailbox_unclaimed_count == 5, "Foreground/retry refreshes mailbox status")
	# Reading does not claim; the server's count remains authoritative.
	count = server.summaries.size()
	result = await service.request("POST", "v1/mailbox/test/read"); await frames()
	check(result.ok and server.summaries.size() == count + 1 and service.mailbox_unclaimed_count == 5, "Read refreshes summary but retains unclaimed-mail badge")
	result = await service.perform("mail_claim", {"id":"00000000-0000-4000-8000-000000000005"}); await frames()
	check(result.ok and service.mailbox_unclaimed_count == 4, "Single receipt refreshes global mail badge outside modal lifetime")
	# A response captured before claim-all must not restore its stale count.
	server.hold_next = true
	service.refresh_mailbox_summary()
	var old_request := server.summaries.size() - 1
	count = server.summaries.size()
	result = await service.perform("mail_claim_all", {"ids":["00000000-0000-4000-8000-000000000005"]})
	service.refresh_mailbox_summary(true)
	service.refresh_mailbox_summary(true)
	check(result.ok and server.summaries.size() == count and service._mailbox_refresh_queued, "Claims queue one newer summary behind an older in-flight request")
	server.held.erase(old_request); await frames(8)
	check(server.summaries.size() == count + 1 and service.mailbox_unclaimed_count == 0 and not service.has_unclaimed_mail(), "Claim-all discards stale response and clears badge from authoritative summary")
	server.counts[ACCOUNT_A] = 7
	service.refresh_mailbox_summary(); await frames()
	check(service.mailbox_unclaimed_count == 7, "Manual mailbox refresh checks global status")
	# A late account-A summary must neither overwrite B nor clear B's request guard.
	server.hold_next = true; service.refresh_mailbox_summary()
	old_request = server.summaries.size() - 1
	result = await service.logout()
	check(result.ok and service.mailbox_unclaimed_count == 0 and not service.has_unclaimed_mail(), "Logout immediately clears mailbox state")
	platform.selected = "b"; server.active = ACCOUNT_B
	server.save = null; server.revision = 0; server.economy_revision = 0
	server.hold_next = true
	result = await service.login()
	var new_request := server.summaries.size() - 1
	check(result.ok and service._mailbox_pending and new_request > old_request, "New account can query while old account's request is held")
	server.held.erase(old_request); await frames()
	check(service._mailbox_pending and service.mailbox_unclaimed_count == 0, "Old account response cannot clear new pending guard or publish old count")
	server.held.erase(new_request); await frames()
	check(service.mailbox_unclaimed_count == 2 and service.has_unclaimed_mail(), "New account result publishes only its own count")
	server.hold_next = true; service.refresh_mailbox_summary()
	old_request = server.summaries.size() - 1
	service.account.credentials.clear(); service.account.account_id_hint = ""
	service._account_changed(); await frames()
	check(app.checkpoint.owner == "guest" and not service.has_unclaimed_mail() and service.mailbox_unclaimed_count == 0, "Definitive session expiry clears mail status")
	server.held.erase(old_request); await frames()
	check(not service._mailbox_pending and service.mailbox_unclaimed_count == 0, "Expired session result stays isolated")
	print("MAILBOX_NOTIFICATIONS checks=", checks, " failures=", failures)
	dispose_service(service); platform.queue_free(); await frames()
	quit(0 if failures.is_empty() else 1)
