extends Node
## Inject authenticated context from account/save ownership. No login, bootstrap,
## credentials on disk, or guest-to-account adoption. All callbacks may be async.
const SaveJson = preload("res://app/save_json.gd")
const COMPATIBILITY_VERSION := 3
var outbox
var busy := false
var binding_generation := 0
var snapshot: Dictionary = {}

func _init(repository = null) -> void:
	outbox = repository
	if outbox != null and outbox.loaded:
		snapshot = outbox.state.get("lastServerSnapshot", {}).duplicate(true)

func invalidate_binding() -> void:
	binding_generation += 1

static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var h := bytes.hex_encode()
	return h.substr(0,8) + "-" + h.substr(8,4) + "-" + h.substr(12,4) + "-" + h.substr(16,4) + "-" + h.substr(20,12)

func settle_next(context: Dictionary, sync_save: Callable, apply_snapshot: Callable, transport: Callable = Callable()) -> Dictionary:
	if busy: return {"ok": false, "code": "BUSY"}
	busy = true
	var result: Dictionary = await _settle(context, sync_save, apply_snapshot, transport)
	busy = false
	return result

func _current(context: Dictionary, captured: Dictionary, generation: int) -> bool:
	return generation == binding_generation and context.get("accountId") == captured.get("accountId") and context.get("writerGeneration") == captured.get("writerGeneration") and context.get("sessionId") == captured.get("sessionId")

func _settle(context: Dictionary, sync_save: Callable, apply_snapshot: Callable, transport: Callable) -> Dictionary:
	if outbox == null or not outbox.loaded: return {"ok": false, "code": "OUTBOX_NOT_LOADED"}
	if not outbox.valid_state(outbox.state): return {"ok": false, "code": "INVALID_OUTBOX"}
	if outbox.owner == "guest" or not context.get("accountId") is String or context.accountId.to_lower() != outbox.owner: return {"ok": false, "code": "ACCOUNT_REQUIRED"}
	if not context.get("accessToken") is String or context.accessToken.is_empty() or not context.get("writerGeneration") is int or context.writerGeneration <= 0: return {"ok": false, "code": "AUTH_CONTEXT_REQUIRED"}
	if not apply_snapshot.is_valid(): return {"ok": false, "code": "SNAPSHOT_CALLBACK_REQUIRED"}
	var captured := context.duplicate(true)
	var generation := binding_generation
	var command: Variant = outbox.state.inFlight
	if command != null and command.kind != "run_settlement": return {"ok": false, "code": "OTHER_COMMAND_PENDING"}
	if command == null:
		if outbox.state.pendingRewards.is_empty(): return {"ok": true, "code": "EMPTY"}
		if not sync_save.is_valid(): return {"ok": false, "code": "SAVE_SYNC_REQUIRED"}
		var synced: Variant = await sync_save.call()
		if not _current(context, captured, generation): return {"ok": false, "code": "STALE_BINDING"}
		if not synced is Dictionary or synced.get("ok") != true or not synced.get("accountId") is String or synced.accountId.to_lower() != outbox.owner or synced.get("writerGeneration") != captured.writerGeneration or not synced.get("sourceSaveRevision") is int or synced.sourceSaveRevision <= 0: return {"ok": false, "code": "SAVE_SYNC_REQUIRED"}
		var reward: Dictionary = outbox.state.pendingRewards[0]
		var body := reward.duplicate(true)
		body.erase("createdAtMillis")
		body["firstClearModuleTickets"] = reward.get("firstClearModuleTickets", 0)
		body["writerGeneration"] = synced.writerGeneration
		body["sourceSaveRevision"] = synced.sourceSaveRevision
		body["clientCompatibilityVersion"] = COMPATIBILITY_VERSION
		command = {"kind": "run_settlement", "path": "v1/economy/runs/settle", "idempotencyKey": uuid(), "encodedBody": JSON.stringify(body, "", false, true), "createdAtMillis": int(Time.get_unix_time_from_system() * 1000)}
		var prepared: Dictionary = outbox.state.duplicate(true)
		prepared.inFlight = command
		if outbox.save_state(prepared) != OK: return {"ok": false, "code": "OUTBOX_WRITE_FAILED"}
	# Replay stored bytes before sync/rebinding: the server checks existing receipts first.
	if not _matches_pending(command): return {"ok": false, "code": "INVALID_COMMAND"}
	var response: Variant = await transport.call(captured, command.duplicate(true)) if transport.is_valid() else await _http(captured, command)
	if not _current(context, captured, generation): return {"ok": false, "code": "STALE_BINDING"}
	if not response is Dictionary: return {"ok": false, "code": "TRANSPORT_ERROR"}
	if not response.get("status", 0) is int: return {"ok": false, "code": "INVALID_RESPONSE"}
	var status: int = response.get("status", 0)
	var decoded: Variant = response.get("body", {})
	if decoded is String: decoded = SaveJson.parse(decoded)
	if not decoded is Dictionary: return {"ok": false, "code": "INVALID_RESPONSE"}
	if not decoded.get("code", "REQUEST_FAILED") is String: return {"ok": false, "code": "INVALID_RESPONSE"}
	var code: String = decoded.get("code", "REQUEST_FAILED")
	if status != 200:
		var body: Variant = SaveJson.parse(command.encodedBody)
		var legacy: bool = status == 426 and code == "CLIENT_UPDATE_REQUIRED" and body.get("clientCompatibilityVersion", 1) < COMPATIBILITY_VERSION
		if legacy or (status >= 400 and status < 500 and code in ["SAVE_WRITER_REPLACED", "SAVE_SYNC_REQUIRED"]):
			var rebound: Dictionary = outbox.state.duplicate(true)
			rebound.inFlight = null
			if outbox.save_state(rebound) != OK: return {"ok": false, "code": "OUTBOX_WRITE_FAILED"}
		return {"ok": false, "code": code, "status": status}
	var next: Variant = decoded.get("economy")
	if not valid_snapshot(next): return {"ok": false, "code": "INVALID_ECONOMY_RESPONSE"}
	# Receipt snapshots may predate a more recent economy refresh; never roll back.
	var should_apply: bool = snapshot.is_empty() or snapshot.authorityEpoch != next.authorityEpoch or snapshot.economyRevision <= next.economyRevision
	if should_apply:
		var applied: Variant = await apply_snapshot.call(next.duplicate(true))
		if not _current(context, captured, generation): return {"ok": false, "code": "STALE_BINDING"}
		if applied != true: return {"ok": false, "code": "SNAPSHOT_SAVE_FAILED"}
		snapshot = next.duplicate(true)
	if not _matches_pending(command): return {"ok": false, "code": "INVALID_COMMAND"}
	var run_id: String = SaveJson.parse(command.encodedBody).get("runId", "")
	var completed: Dictionary = outbox.state.duplicate(true)
	completed.inFlight = null
	completed.lastServerSnapshot = snapshot.duplicate(true)
	completed.pendingRewards = completed.pendingRewards.filter(func(reward): return reward.runId != run_id)
	if not completed.has("completedRunIds"): completed.completedRunIds = []
	if not run_id in completed.completedRunIds: completed.completedRunIds.append(run_id)
	if outbox.save_state(completed) != OK: return {"ok": false, "code": "OUTBOX_WRITE_FAILED"}
	return {"ok": true, "code": "SETTLED", "runId": run_id}

func _matches_pending(command: Dictionary) -> bool:
	if command.path != "v1/economy/runs/settle": return false
	var body: Variant = SaveJson.parse(command.encodedBody)
	if not body is Dictionary or not body.get("runId") is String: return false
	if not body.get("clientCompatibilityVersion", 1) is int or body.get("clientCompatibilityVersion", 1) < 1: return false
	for reward in outbox.state.pendingRewards:
		if reward.runId != body.runId: continue
		for key in ["stageNumber", "completedRounds", "success", "pendingDiamonds", "firstClearModuleTickets"]:
			if body.get(key, 0) != reward.get(key, 0): return false
		return true
	return false

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("authorityState") != "server_authoritative" or not value.get("authorityEpoch") is String or value.authorityEpoch.is_empty(): return false
	for key in ["authorityVersion", "catalogVersion", "economyRevision"]:
		if not value.get(key) is int or value[key] < (0 if key == "economyRevision" else 1): return false
	if not value.get("wallet") is Dictionary or not value.get("turretModules") is Dictionary or not value.get("entitlements") is Dictionary: return false
	for key in ["freeDiamonds", "paidDiamonds", "moduleTickets"]:
		if not value.wallet.get(key) is int or value.wallet[key] < 0: return false
	for key in ["drawCount", "ticketPurchaseCount"]:
		if not value.turretModules.get(key) is int or value.turretModules[key] < 0: return false
	if not value.turretModules.get("items") is Array or not value.get("pendingProgressionEffects") is Array or not value.entitlements.get("researchSlotTwoUnlocked") is bool or not value.get("serverTime") is String: return false
	if RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}T").search(value.serverTime) == null: return false
	for item in value.turretModules.items:
		if not item is Dictionary: return false
		for key in ["id", "turretType", "part", "family", "grade"]:
			if not item.get(key) is String or item[key].is_empty(): return false
		if not item.get("acquiredOrder") is int or item.acquiredOrder <= 0 or not item.get("options") is Array or item.options.is_empty(): return false
		for option in item.options:
			if not option is Dictionary or not option.get("type") is String or not option.get("value") is int or option.value <= 0: return false
	for effect in value.pendingProgressionEffects:
		if not effect is Dictionary or not effect.get("id") is String or not effect.get("effectType") is String or not effect.get("payload") is Dictionary: return false
	return true

func _http(context: Dictionary, command: Dictionary) -> Dictionary:
	var base: String = context.get("baseUrl", "").trim_suffix("/")
	var pattern := RegEx.create_from_string("^(https://[^/@?#]+|http://(localhost|127\\.0\\.0\\.1|\\[::1\\])(:[0-9]+)?)(/[^?#]*)?$")
	if pattern.search(base) == null: return {"status": 0, "body": {"code": "INVALID_API_URL"}}
	var request := HTTPRequest.new()
	request.timeout = 30.0
	request.max_redirects = 0 # Never forward the bearer token to a redirected host.
	add_child(request)
	var headers := PackedStringArray(["Authorization: Bearer " + context.accessToken, "Idempotency-Key: " + command.idempotencyKey, "Content-Type: application/json"])
	var error := request.request(base + "/" + command.path, headers, HTTPClient.METHOD_POST, command.encodedBody)
	if error != OK:
		request.queue_free()
		return {"status": 0, "body": {"code": "TRANSPORT_ERROR"}}
	var result: Array = await request.request_completed
	request.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS: return {"status": 0, "body": {"code": "TRANSPORT_ERROR"}}
	return {"status": result[1], "body": result[3].get_string_from_utf8()}
