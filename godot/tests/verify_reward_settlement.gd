extends SceneTree
const Outbox = preload("res://app/reward_outbox.gd")
const Settlement = preload("res://app/reward_settlement.gd")
const ACCOUNT := "00000000-0000-4000-8000-000000000001"
var failures: Array = []
var sent: Array = []
var response := {"status": 0, "body": {"code": "NETWORK_ERROR"}}
var apply_count := 0
var server := TCPServer.new()
var peer: StreamPeerTCP
var wire := PackedByteArray()
var wire_requests: Array = []
func pump_http() -> void:
	if peer == null and server.is_connection_available():
		peer = server.take_connection()
		wire = PackedByteArray()
	if peer == null: return
	peer.poll()
	if peer.get_available_bytes() > 0:
		wire.append_array(peer.get_data(peer.get_available_bytes())[1])
	var raw := wire.get_string_from_utf8()
	var boundary := raw.find("\r\n\r\n")
	if boundary < 0: return
	var length := 0
	for line in raw.substr(0, boundary).split("\r\n"):
		if line.to_lower().begins_with("content-length:"): length = int(line.split(":", true, 1)[1])
	if wire.size() < boundary + 4 + length: return
	wire_requests.append(raw)
	var payload := JSON.stringify(response.body)
	peer.put_data(("HTTP/1.1 %d Test\r\nLocation: http://127.0.0.1:1/must-not-follow\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [response.status, payload.to_utf8_buffer().size()] + payload).to_utf8_buffer())
	peer.disconnect_from_host()
	peer = null
var context := {"accountId": ACCOUNT, "writerGeneration": 2, "accessToken": "mock-only", "sessionId": "test"}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func sync() -> Dictionary: return {"ok": true, "accountId": ACCOUNT, "writerGeneration": 2, "sourceSaveRevision": 12}
func apply(_value: Dictionary) -> bool:
	apply_count += 1
	return true
func transport(_context: Dictionary, command: Dictionary) -> Dictionary:
	sent.append(command)
	return response
func run() -> void:
	var directory := OS.get_cache_dir().path_join("rune-reward-test-" + Settlement.uuid())
	var box = Outbox.new(directory, ACCOUNT)
	check(box.load_state() == OK, "new outbox")
	var reward := {"runId": Settlement.uuid(), "stageNumber": 1, "completedRounds": 2, "success": false, "pendingDiamonds": 42, "firstClearModuleTickets": 0, "createdAtMillis": 1}
	check(box.enqueue(reward) == OK and box.enqueue(reward) == OK and box.state.pendingRewards.size() == 1, "durable deduplication")
	var worker = Settlement.new(box)
	root.add_child(worker)
	var result: Dictionary = await worker.settle_next(context, sync, apply, transport)
	check(not result.ok and box.state.inFlight != null and apply_count == 0, "lost response retains exact command and no local credit")
	var recovered = Outbox.new(directory, ACCOUNT)
	check(recovered.load_state() == OK, "restart loads")
	worker.outbox = recovered
	response = {"status": 200, "body": {"economy": {"authorityState": "server_authoritative", "authorityEpoch": "epoch", "authorityVersion": 1, "catalogVersion": 1, "economyRevision": 3, "serverTime": "2026-09-21T00:00:00Z", "wallet": {"freeDiamonds": 42, "paidDiamonds": 0, "moduleTickets": 0}, "turretModules": {"drawCount": 0, "ticketPurchaseCount": 0, "items": []}, "entitlements": {"researchSlotTwoUnlocked": false}, "pendingProgressionEffects": [], "claimedRewardKeys": []}}}
	result = await worker.settle_next(context, Callable(), apply, transport)
	check(result.ok and sent[0] == sent[1] and apply_count == 1, "restart exact request replay without resync")
	check(recovered.state.pendingRewards.is_empty() and recovered.state.inFlight == null, "receipt clears atomically")
	check(recovered.enqueue(reward) == OK and recovered.state.pendingRewards.is_empty(), "terminal replay tombstone")
	var restarted = Outbox.new(directory, ACCOUNT)
	check(restarted.load_state() == OK, "settled cache reload")
	var restored = Settlement.new(restarted)
	check(restored.snapshot.economyRevision == 3, "authoritative revision survives restart")
	root.add_child(restored)
	var old_reward := reward.duplicate(true)
	old_reward.runId = Settlement.uuid()
	check(restarted.enqueue(old_reward) == OK, "older receipt fixture")
	response.body.economy.economyRevision = 2
	result = await restored.settle_next(context, sync, apply, transport)
	check(result.ok and apply_count == 1 and restarted.state.lastServerSnapshot.economyRevision == 3, "older receipt cannot roll back persisted snapshot")
	response.body.economy.economyRevision = 3
	restored.queue_free()
	reward.runId = Settlement.uuid()
	check(recovered.enqueue(reward) == OK, "second reward")
	response = {"status": 409, "body": {"code": "SAVE_WRITER_REPLACED"}}
	result = await worker.settle_next(context, sync, apply, transport)
	check(not result.ok and recovered.state.inFlight == null and recovered.state.pendingRewards.size() == 1, "rebind retains reward")
	response = {"status": 426, "body": {"code": "CLIENT_UPDATE_REQUIRED"}}
	result = await worker.settle_next(context, sync, apply, transport)
	check(not result.ok and recovered.state.inFlight != null, "current compatibility 426 preserves exact request")
	response = {"status": 401, "body": {"code": "UNAUTHORIZED"}}
	result = await worker.settle_next(context, sync, apply, transport)
	check(not result.ok and recovered.state.inFlight != null and recovered.state.pendingRewards.size() == 1, "401 retains reward and exact body")
	response = {"status": 426, "body": {"code": "CLIENT_UPDATE_REQUIRED"}}
	var changed: Dictionary = recovered.state.duplicate(true)
	var body: Dictionary = JSON.parse_string(changed.inFlight.encodedBody)
	body.clientCompatibilityVersion = 1
	changed.inFlight.encodedBody = JSON.stringify(body)
	check(recovered.save_state(changed) == OK, "legacy fixture")
	result = await worker.settle_next(context, sync, apply, transport)
	check(not result.ok and recovered.state.inFlight == null and recovered.state.pendingRewards.size() == 1, "legacy 426 retires body only")
	var sent_count := sent.size()
	result = await worker.settle_next(context, func(): return {"ok": false}, apply, transport)
	check(result.code == "SAVE_SYNC_REQUIRED" and sent.size() == sent_count, "sync prerequisite")
	var guest = Outbox.new(directory)
	check(guest.enqueue(reward) == OK, "guest local queue")
	worker.outbox = guest
	result = await worker.settle_next(context, sync, apply, transport)
	check(result.code == "ACCOUNT_REQUIRED" and sent.size() == sent_count, "guest never sends")
	worker.outbox = recovered
	result = await worker.settle_next(context, sync, apply, func(_ctx, _cmd):
		worker.invalidate_binding()
		return response)
	check(result.code == "STALE_BINDING" and recovered.state.inFlight != null, "stale completion cannot mutate queue")
	# Exercise real HTTPRequest against an isolated loopback socket.
	var port := 20000 + randi_range(0, 20000)
	while server.listen(port, "127.0.0.1") != OK: port += 1
	process_frame.connect(pump_http)
	response = {"status": 200, "body": {"economy": worker.snapshot.duplicate(true)}}
	context.baseUrl = "http://127.0.0.1:" + str(port)
	var exact: Dictionary = recovered.state.inFlight.duplicate(true)
	result = await worker.settle_next(context, sync, apply)
	check(result.ok and wire_requests.size() == 1, "real HTTP transport loopback")
	if not wire_requests.is_empty():
		var raw: String = wire_requests[0]
		check(raw.begins_with("POST /v1/economy/runs/settle HTTP/1.1") and "Authorization: Bearer mock-only" in raw and ("Idempotency-Key: " + exact.idempotencyKey) in raw, "HTTP route and authentication headers")
		check(raw.substr(raw.find("\r\n\r\n") + 4) == exact.encodedBody, "HTTP exact persisted bytes")
	reward.runId = Settlement.uuid()
	check(recovered.enqueue(reward) == OK, "redirect fixture")
	response = {"status": 302, "body": {"code": "REDIRECT"}}
	result = await worker.settle_next(context, sync, apply)
	check(not result.ok and wire_requests.size() == 2 and recovered.state.inFlight != null, "HTTP redirects disabled and request retained")
	var invalid: Dictionary = recovered.state.duplicate(true)
	var invalid_body: Dictionary = Outbox.SaveJson.parse(invalid.inFlight.encodedBody)
	invalid_body.runId = Settlement.uuid()
	invalid.inFlight.encodedBody = JSON.stringify(invalid_body)
	check(recovered.save_state(invalid) == OK, "mismatched body fixture")
	var before_invalid := sent.size()
	result = await worker.settle_next(context, sync, apply, transport)
	check(result.code == "INVALID_COMMAND" and sent.size() == before_invalid and recovered.state.inFlight != null, "mismatched run command never sent or removed")
	invalid.inFlight.kind = "bootstrap"
	check(recovered.save_state(invalid) == OK, "other command fixture")
	result = await worker.settle_next(context, sync, apply, transport)
	check(result.code == "OTHER_COMMAND_PENDING" and recovered.state.inFlight.kind == "bootstrap", "unrelated inflight command preserved")
	# Corrupt durable state must fail closed, never silently drop a queued reward.
	var corrupt = Outbox.new(directory.path_join("corrupt"), ACCOUNT)
	check(corrupt.enqueue(reward) == OK, "corrupt fixture seeded")
	var broken := FileAccess.open(corrupt.primary_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	var unreadable = Outbox.new(directory.path_join("corrupt"), ACCOUNT)
	check(unreadable.load_state() == ERR_FILE_CORRUPT, "corruption blocks initialization")
	check(unreadable.enqueue(reward) == ERR_FILE_CORRUPT and FileAccess.get_file_as_string(unreadable.primary_path) == "{broken", "corruption never overwritten")
	var mismatch: Dictionary = context.duplicate(true)
	mismatch.accountId = "00000000-0000-4000-8000-000000000002"
	result = await worker.settle_next(mismatch, sync, apply, transport)
	check(result.code == "ACCOUNT_REQUIRED", "account binding refuses cross-account send")
	server.stop()
	process_frame.disconnect(pump_http)
	print(JSON.stringify({"suite": "reward_settlement", "ok": failures.is_empty(), "failures": failures}))
	worker.queue_free()
	quit(0 if failures.is_empty() else 1)
