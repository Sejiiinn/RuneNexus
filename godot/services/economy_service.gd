extends Node
## One durable account command at a time. Previously sent request bytes are immutable.
const Settlement = preload("res://app/reward_settlement.gd")
const Json = preload("res://app/save_json.gd")
const COMPATIBILITY := 3
signal changed
var account
var outbox
var callbacks: Dictionary = {}
var snapshot: Dictionary = {}
var busy := false
var generation := 0
var issue := ""

func configure(session, repository, handlers: Dictionary) -> void:
	generation += 1
	account = session
	outbox = repository
	callbacks = handlers
	snapshot = outbox.state.get("lastServerSnapshot", {}).duplicate(true)

func invalidate() -> void:
	generation += 1

func _failure(code: String) -> Dictionary:
	issue = code
	return {"ok": false, "code": code}

func _bound(token: int) -> bool:
	return token == generation and account != null and account.credentials.get("accountId", "").to_lower() == outbox.owner

func refresh() -> Dictionary:
	return await execute("refresh")

func execute(action: String, values: Dictionary = {}) -> Dictionary:
	if busy: return _failure("BUSY")
	if outbox == null or not outbox.loaded: return _failure("OUTBOX_READ_FAILED")
	if outbox.owner == "guest" or not _bound(generation): return _failure("ACCOUNT_REQUIRED")
	busy = true
	var token := generation
	var result: Dictionary = await _run(action, values, token)
	busy = false
	if not _bound(token): return _failure("STALE_BINDING")
	issue = "" if result.get("ok", false) else str(result.get("code", "REQUEST_FAILED"))
	changed.emit()
	return result

func _run(action: String, values: Dictionary, token: int) -> Dictionary:
	if outbox.state.inFlight != null:
		var recovered: Dictionary = await _send(outbox.state.inFlight.duplicate(true), token, true)
		if not recovered.get("ok", false): return recovered
	var loaded: Dictionary = await _load(token)
	if not loaded.get("ok", false): return loaded
	var effects: Dictionary = await _effects(token)
	if not effects.get("ok", false): return effects
	while not outbox.state.pendingRewards.is_empty():
		var synced: Dictionary = await _sync(token)
		if not synced.get("ok", false): return synced
		var reward: Dictionary = outbox.state.pendingRewards[0].duplicate(true)
		reward.erase("createdAtMillis")
		reward.merge(_save_fields(synced), true)
		var settled: Dictionary = await _prepare("run_settlement", "v1/economy/runs/settle", reward, token)
		if not settled.get("ok", false): return settled
	if action == "refresh": return {"ok": true, "body": snapshot}
	var sync: Dictionary = await _sync(token)
	if not sync.get("ok", false): return sync
	var body := {"expectedEconomyRevision":snapshot.economyRevision,"expectedCatalogVersion":snapshot.catalogVersion,"clientCompatibilityVersion":COMPATIBILITY}
	var kind := action
	var path := ""
	match action:
		"draw_modules":
			path = "v1/economy/turret-modules/draw"
			body.merge(_save_fields(sync))
			body.merge({"count":values.get("count",1),"turretType":values.get("turretType",""),"buyMissingTicketsWithDiamonds":values.get("buyMissingTicketsWithDiamonds",false)})
		"disassemble_modules":
			path = "v1/economy/turret-modules/disassemble"
			var ids: Array = values.get("ids", []).duplicate()
			ids.sort()
			body.moduleIds = ids
		"complete_research":
			path = "v1/economy/researches/" + str(values.get("id", "")).uri_encode() + "/complete"
			body.merge(_save_fields(sync))
		"unlock_research_slot_two":
			path = "v1/economy/research-slots/2/unlock"
			body.merge(_save_fields(sync))
		"claim_reward":
			kind = "weekly_reward" if values.get("period") == "weekly" else "daily_reward"
			path = "v1/economy/rewards/claim"
			body = {"period":values.get("period","daily"),"rewardType":values.get("rewardType","quest"),"clientCompatibilityVersion":COMPATIBILITY}
			if body.rewardType == "quest": body.questType = values.get("questType", "")
		"mail_claim":
			path = "v1/mailbox/" + str(values.get("id", "")).uri_encode() + "/claim"
			body = {"clientCompatibilityVersion":COMPATIBILITY}
		"mail_claim_all":
			path = "v1/mailbox/claim-all"
			body = {"clientCompatibilityVersion":COMPATIBILITY,"mailIds":values.get("ids",[])}
		_: return _failure("UNKNOWN_COMMAND")
	var result: Dictionary = await _prepare(kind, path, body, token)
	if result.get("ok",false):
		var applied: Dictionary = await _effects(token)
		if not applied.get("ok",false): return applied
	return result

func _sync(token: int) -> Dictionary:
	var result: Dictionary = await callbacks.sync.call()
	if not _bound(token): return _failure("STALE_BINDING")
	if not result.get("ok",false) or result.get("accountId", "").to_lower() != outbox.owner or int(result.get("sourceSaveRevision",0)) <= 0 or int(result.get("writerGeneration",0)) <= 0:
		return _failure(str(result.get("code", "SAVE_SYNC_REQUIRED")))
	return result

func _save_fields(sync: Dictionary) -> Dictionary:
	return {"sourceSaveRevision":sync.sourceSaveRevision,"writerGeneration":sync.writerGeneration,"clientCompatibilityVersion":COMPATIBILITY}

func _load(token: int) -> Dictionary:
	var result: Dictionary = await account.request("GET", "v1/economy")
	if not _bound(token): return _failure("STALE_BINDING")
	if result.get("code") == "ECONOMY_NOT_BOOTSTRAPPED" or result.get("body",{}).get("code") == "ECONOMY_NOT_BOOTSTRAPPED":
		var synced: Dictionary = await _sync(token)
		if not synced.get("ok",false): return synced
		return await _prepare("bootstrap","v1/economy/bootstrap",{"expectedSaveRevision":synced.sourceSaveRevision,"writerGeneration":synced.writerGeneration,"clientCompatibilityVersion":COMPATIBILITY},token)
	if not result.get("ok",false): return result
	return await _apply(result.get("body",{}), token)

func _apply(value: Dictionary, token: int) -> Dictionary:
	if not Settlement.valid_snapshot(value): return _failure("INVALID_ECONOMY_RESPONSE")
	if not snapshot.is_empty() and snapshot.authorityEpoch == value.authorityEpoch and snapshot.economyRevision > value.economyRevision: return {"ok":true}
	var applied: bool = await callbacks.snapshot.call(value)
	if not _bound(token): return _failure("STALE_BINDING")
	if not applied: return _failure("SNAPSHOT_SAVE_FAILED")
	var next: Dictionary = outbox.state.duplicate(true)
	next.lastServerSnapshot = value.duplicate(true)
	if outbox.save_state(next) != OK: return _failure("OUTBOX_WRITE_FAILED")
	snapshot = value.duplicate(true)
	return {"ok":true}

func _prepare(kind: String, path: String, body: Dictionary, token: int) -> Dictionary:
	if not _bound(token): return _failure("STALE_BINDING")
	if outbox.state.inFlight != null: return _failure("COMMAND_PENDING")
	var command := {"kind":kind,"path":path,"idempotencyKey":Settlement.uuid(),"encodedBody":JSON.stringify(body,"",false,true),"createdAtMillis":int(Time.get_unix_time_from_system()*1000)}
	if not _allowed(command): return _failure("INVALID_COMMAND")
	var next: Dictionary = outbox.state.duplicate(true)
	next.inFlight = command
	if outbox.save_state(next) != OK: return _failure("OUTBOX_WRITE_FAILED")
	return await _send(command, token)

func _allowed(command: Dictionary) -> bool:
	var exact := {"bootstrap":"v1/economy/bootstrap","run_settlement":"v1/economy/runs/settle","draw_modules":"v1/economy/turret-modules/draw","disassemble_modules":"v1/economy/turret-modules/disassemble","unlock_research_slot_two":"v1/economy/research-slots/2/unlock","daily_reward":"v1/economy/rewards/claim","weekly_reward":"v1/economy/rewards/claim","mail_claim_all":"v1/mailbox/claim-all"}
	if exact.has(command.kind): return command.path == exact[command.kind]
	var patterns := {"complete_research":"^v1/economy/researches/[A-Za-z][A-Za-z0-9]*/complete$","ack_progression_effect":"^v1/economy/progression-effects/[0-9a-fA-F-]{36}/ack$","mail_claim":"^v1/mailbox/[0-9a-fA-F-]{36}/claim$"}
	return patterns.has(command.kind) and RegEx.create_from_string(patterns[command.kind]).search(command.path) != null

func _retire(command: Dictionary, completed_run := false) -> bool:
	if outbox.state.inFlight == null or outbox.state.inFlight.idempotencyKey != command.idempotencyKey: return false
	var next: Dictionary = outbox.state.duplicate(true)
	next.inFlight = null
	if completed_run:
		var id: String = Json.parse(command.encodedBody).get("runId", "")
		next.pendingRewards = next.pendingRewards.filter(func(reward): return reward.runId != id)
		if not next.has("completedRunIds"): next.completedRunIds = []
		if not id in next.completedRunIds: next.completedRunIds.append(id)
	return outbox.save_state(next) == OK

func _send(command: Dictionary, token: int, recovering := false) -> Dictionary:
	if not _allowed(command): return _failure("INVALID_COMMAND")
	var result: Dictionary = await account.request("POST",command.path,command.encodedBody,{"Idempotency-Key":command.idempotencyKey})
	if not _bound(token): return _failure("STALE_BINDING")
	var data: Dictionary = result.get("body", {})
	var reward: bool = command.kind in ["daily_reward","weekly_reward"]
	if reward and result.get("status") == 409 and data.get("code") == "REWARD_ALREADY_CLAIMED":
		data = data.get("reward",{})
		result.ok = true
	if not result.get("ok",false):
		var status := int(result.get("status",0))
		var code: String = str(result.get("code",data.get("code","REQUEST_FAILED")))
		var legacy: bool = status == 426 and code == "CLIENT_UPDATE_REQUIRED" and int(Json.parse(command.encodedBody).get("clientCompatibilityVersion",1)) < COMPATIBILITY
		var rebind: bool = command.kind == "run_settlement" and code in ["SAVE_WRITER_REPLACED","SAVE_SYNC_REQUIRED"]
		if legacy or rebind or (status >= 400 and status < 500 and status not in [401,408,426,429]):
			if not _retire(command, command.kind == "run_settlement" and not legacy and not rebind): return _failure("OUTBOX_WRITE_FAILED")
			if recovering and (legacy or rebind or code == "MAIL_UNAVAILABLE"): return {"ok":true}
		return result
	if reward:
		var body: Dictionary = Json.parse(command.encodedBody)
		if not data.get("weekKey") is int or data.weekKey < 0: return _failure("INVALID_REWARD_RECEIPT")
		if body.get("period") == "weekly" and (data.get("rewardType") != body.get("rewardType") or data.get("questType") != body.get("questType") or int(data.get("diamonds",0)) <= 0 or int(data.get("moduleTickets",-1)) < 0): return _failure("INVALID_REWARD_RECEIPT")
		body["weekKey" if body.get("period") == "weekly" else "dayKey"] = data.weekKey
		body.rewardDiamonds = data.get("diamonds",0)
		body.rewardModuleTickets = data.get("moduleTickets",0)
		var applied: bool = await callbacks.receipt.call(body)
		if not _bound(token): return _failure("STALE_BINDING")
		if not applied: return _failure("RECEIPT_SAVE_FAILED")
		var latest: Dictionary = await _load(token)
		if not latest.get("ok",false): return latest
	else:
		var applied: Dictionary = await _apply(data.get("economy",{}),token)
		if not applied.get("ok",false): return applied
	if not _retire(command, command.kind == "run_settlement"): return _failure("OUTBOX_WRITE_FAILED")
	return {"ok":true,"body":data}

func _effects(token: int) -> Dictionary:
	for effect in snapshot.get("pendingProgressionEffects",[]).duplicate(true):
		var applied: bool = await callbacks.effect.call(effect)
		if not _bound(token): return _failure("STALE_BINDING")
		if not applied: return _failure("PROGRESSION_EFFECT_FAILED")
		var synced: Dictionary = await _sync(token)
		if not synced.get("ok",false): return synced
		var result: Dictionary = await _prepare("ack_progression_effect","v1/economy/progression-effects/"+str(effect.id)+"/ack",{"appliedSaveRevision":synced.sourceSaveRevision,"writerGeneration":synced.writerGeneration,"clientCompatibilityVersion":COMPATIBILITY},token)
		if not result.get("ok",false): return result
	return {"ok":true}
