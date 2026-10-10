extends SceneTree
## Real app/checkpoint/account/economy path; HTTP is isolated and controllable.
const App = preload("res://app/app_lifecycle.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Services = preload("res://services/app_services.gd")
const Economy = preload("res://services/economy_service.gd")
const Account = preload("res://services/account_session.gd")
const Fixture = preload("res://verify_run_transition.gd")
const EconomyFixture = preload("res://verify_economy_service.gd")
const Id = preload("res://app/reward_settlement.gd")
const ACCOUNT := "00000000-0000-4000-8000-000000000001"
class Online extends Node:
	var app
	var requires_reload := false
	var state := {"rebase":null}
	var fail_sync := false
	var sync_calls := 0
	func sync_checkpoint() -> Dictionary:
		sync_calls += 1
		if fail_sync: return {"ok":false,"code":"SAVE_SYNC_REQUIRED"}
		return {"ok":true,"accountId":ACCOUNT,"sourceSaveRevision":8,"writerGeneration":2}
class Transport extends Node:
	signal release
	var app
	var sent: Array = []
	var hold := false
	var response: Dictionary = {}
	var snapshot: Dictionary = {}
	var durable := true
	func request(method: int, url: String, body := "", headers := {}) -> Dictionary:
		var saved = app.checkpoint.store.load_save()
		var box = app.checkpoint.rewards()
		if url.ends_with("/runs/settle"):
			var payload: Dictionary = JSON.parse_string(body)
			durable = durable and saved != null and box.state.inFlight != null and box.state.pendingRewards.any(func(r): return r.runId == payload.runId)
		sent.append({"method":method,"url":url,"body":body,"headers":headers.duplicate(true)})
		if method == HTTPClient.METHOD_GET: return {"ok":true,"status":200,"body":snapshot.duplicate(true)}
		if hold: await release
		return response.duplicate(true)
var directory := ""
var failures: Array = []
var checks := 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func make_app(name: String, owner := ACCOUNT):
	var app = App.new()
	app.scene = Fixture.Host.new()
	app.checkpoint = Checkpoint.new(directory.path_join(name), owner)
	app.checkpoint.allow_progression_only = true
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog() and app.retry_load(), name + " startup")
	return app
func attach(app):
	var service = Services.new()
	service.app = app
	service.online_ready = true
	service.profile = {"nickname":"fixture"}
	service._startup_pending = false
	root.add_child(service)
	service.set_process(false)
	service.account = Account.new()
	service.add_child(service.account)
	var transport = Transport.new()
	transport.app = app
	service.account.add_child(transport)
	service.account.configure("https://fixture.invalid", null, transport)
	service.account.credentials = {"accountId":ACCOUNT,"accessToken":"fixture-access","accessExpiresAt":"2099-01-01T00:00:00Z"}
	service.account.set_process(false)
	service.online = Online.new()
	service.online.app = app
	service.add_child(service.online)
	service.economy = Economy.new()
	service.add_child(service.economy)
	service.economy.configure(service.account, app.checkpoint.rewards(), {"sync":service.sync,"snapshot":service._apply_snapshot,"snapshot_current":service._snapshot_current,"receipt":service._apply_receipt,"effect":service._apply_effect})
	var fixture = EconomyFixture.new()
	transport.snapshot = fixture.snapshot()
	transport.response = {"ok":true,"status":200,"body":{"economy":fixture.snapshot(4)}}
	fixture.free()
	app.services = service
	return service
func finish(app, success := true) -> String:
	# The actual terminal checkpoint invokes the same durable-save hook as gameplay.
	var state: Dictionary = app.run_domain.state
	state.phase = "success" if success else "failure"
	state.completedRounds = 2
	state.pendingEconomyDiamonds = 15
	app.command([], {"phase":state.phase,"paused":true})
	check(app.persist_progression(), "terminal checkpoint saved")
	return state.economyRunId
func settle_posts(transport) -> Array:
	return transport.sent.filter(func(item): return item.url.ends_with("/runs/settle"))
func frames(count := 3):
	for i in range(count): await process_frame
func free_app(app):
	app.services.free()
	app.scene.free()
	app.free()
func run():
	directory = OS.get_cache_dir().path_join("godot-result-settlement-" + Id.uuid())
	var app = make_app("online")
	check(await app.start_stage(0), "online starts")
	var service = attach(app)
	var http = service.account.transport
	http.hold = true
	var run_id := finish(app)
	await frames()
	var posts := settle_posts(http)
	check(posts.size() == 1 and service.sync_elapsed == 0.0, "clear immediately reaches account settlement transport without periodic sync")
	check(service.run_settlement_state(run_id).status == "requesting" and service.economy.busy, "result observes request in flight")
	check(not service.blocks_play(), "background settlement does not gate navigation")
	check(posts[0].headers.Authorization == "Bearer fixture-access" and posts[0].headers.has("Idempotency-Key") and http.durable, "authenticated HTTP only after durable terminal/outbox/inFlight writes")
	var body: Dictionary = JSON.parse_string(posts[0].body)
	check(body.runId == run_id and body.success and body.pendingDiamonds == 15 and body.sourceSaveRevision == 8 and body.writerGeneration == 2 and body.clientCompatibilityVersion == 6, "production save-writer/run settlement contract")
	service.request_run_settlement(true)
	check(app.open_stage_menu_destination() and app.in_lobby, "result exit allowed during request")
	await frames()
	check(settle_posts(http).size() == 1, "in-flight refresh/save/navigation does not duplicate command")
	http.release.emit()
	await frames()
	check(service.run_settlement_state(run_id).status == "completed" and app.checkpoint.rewards().state.pendingRewards.is_empty(), "successful response becomes durable completed state")
	check(app.progression_inputs.freeDiamonds == 42, "wallet comes from authoritative response, never local pending arithmetic")
	check(app.persist_progression(), "repeat terminal save after settlement")
	await frames()
	check(settle_posts(http).size() == 1, "completed run cannot be re-enqueued by later terminal save")
	free_app(app)
	# Lost response survives restart with exact immutable request and key.
	app = make_app("retry")
	check(await app.start_stage(0), "retry starts")
	service = attach(app); http = service.account.transport
	http.response = {"ok":false,"status":0,"code":"NETWORK_UNAVAILABLE","body":{}}
	run_id = finish(app, false)
	await frames()
	posts = settle_posts(http)
	var lost: Dictionary = posts[0].duplicate(true)
	check(service.run_settlement_state(run_id).status == "retry" and app.checkpoint.rewards().state.pendingRewards.size() == 1, "failure result keeps reward and reports retry")
	service.request_run_settlement()
	await frames()
	check(settle_posts(http).size() == 1, "failed request does not retry each frame")
	free_app(app)
	app = make_app("retry")
	service = attach(app); http = service.account.transport
	service.request_run_settlement(true)
	await frames()
	posts = settle_posts(http)
	check(posts.size() == 1 and posts[0].body == lost.body and posts[0].headers["Idempotency-Key"] == lost.headers["Idempotency-Key"], "restart retries exact persisted bytes/key")
	check(service.run_settlement_state(run_id).status == "completed", "offline restart reward recovers once")
	free_app(app)
	# Writer failures are retryable, and a permanent server denial is diagnosed.
	app = make_app("writer")
	check(await app.start_stage(0), "writer starts")
	service = attach(app); http = service.account.transport
	service.online.fail_sync = true
	run_id = finish(app)
	await frames()
	check(settle_posts(http).is_empty() and service.run_settlement_state(run_id).code == "SAVE_SYNC_REQUIRED", "failed writer sync never submits settlement")
	service.online.fail_sync = false
	http.response = {"ok":false,"status":422,"code":"INVALID_RUN_REWARD","body":{"code":"INVALID_RUN_REWARD"}}
	service.request_run_settlement(true)
	await frames()
	check(service.run_settlement_state(run_id).status == "rejected" and app.checkpoint.rewards().state.get("rejectedRunCodes",{}).get(run_id) == "INVALID_RUN_REWARD", "permanent denial is durable and never displayed as completed")
	free_app(app)
	app = make_app("writer")
	service = attach(app)
	check(service.run_settlement_state(run_id).status == "rejected", "server denial survives restart")
	free_app(app)
	# A late success cannot cross a slot transition or retire the old request.
	app = make_app("stale")
	check(await app.start_stage(0), "stale starts")
	service = attach(app); http = service.account.transport
	http.hold = true
	run_id = finish(app)
	await frames()
	var old_box = app.checkpoint.rewards()
	service.epoch += 1
	service.economy.invalidate()
	service.account.credentials.clear()
	check(service._load_slot("guest"), "late response switches to isolated guest slot")
	var guest_before: Dictionary = app.progression_inputs.duplicate(true)
	http.release.emit()
	await frames()
	check(app.progression_inputs == guest_before and old_box.state.inFlight != null and old_box.state.pendingRewards.size() == 1, "late success neither applies guest wallet nor clears old account reward")
	free_app(app)
	# Lost local receipt persistence retries the successful server command exactly.
	app = make_app("receipt-write")
	check(await app.start_stage(0), "receipt write starts")
	service = attach(app); http = service.account.transport
	http.hold = true
	run_id = finish(app)
	await frames()
	lost = settle_posts(http)[0].duplicate(true)
	app.checkpoint.store._valid_slot = false
	http.release.emit()
	await frames()
	check(service.run_settlement_state(run_id).status == "retry" and service.run_settlement_state(run_id).code == "SNAPSHOT_SAVE_FAILED" and app.checkpoint.rewards().state.inFlight != null, "failed snapshot persistence retains unpaid local acknowledgement")
	app.checkpoint.store._valid_slot = true
	http.hold = false
	service.request_run_settlement(true)
	await frames()
	posts = settle_posts(http)
	check(posts.size() == 2 and posts[1].body == lost.body and posts[1].headers["Idempotency-Key"] == lost.headers["Idempotency-Key"] and service.run_settlement_state(run_id).status == "completed", "receipt retry preserves exact successful server command and completes locally")
	service.account.credentials.clear()
	check(service.run_settlement_state(run_id).status == "completed", "durable completion stays complete while account is offline")
	free_app(app)
	# Local write failure, guest and account binding never submit rewards.
	app = make_app("save-failure")
	check(await app.start_stage(0), "save failure starts")
	service = attach(app); http = service.account.transport
	app.checkpoint.rewards()._valid_slot = false
	app.run_domain.state.phase = "success"
	check(not app.persist_progression(), "outbox failure rejects terminal persistence")
	service.request_run_settlement(true)
	await frames()
	check(http.sent.is_empty() and service.run_settlement_state(app.run_domain.state.economyRunId).status == "save_failed", "failed durable write prevents all settlement requests")
	app.checkpoint.rewards()._valid_slot = true
	free_app(app)
	app = make_app("guest", "guest")
	check(await app.start_stage(0), "guest starts")
	service = attach(app); http = service.account.transport
	run_id = finish(app)
	service.request_run_settlement(true)
	await frames()
	check(http.sent.is_empty() and service.run_settlement_state(run_id).status == "guest", "guest outbox never leaks to account transport")
	free_app(app)
	print("RESULT_SETTLEMENT checks=",checks," failures=",failures.size()," ",failures)
	_remove(directory)
	quit(0 if failures.is_empty() else 1)
func _remove(path: String):
	for file in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	for child in DirAccess.get_directories_at(path): _remove(path.path_join(child))
	DirAccess.remove_absolute(path)
