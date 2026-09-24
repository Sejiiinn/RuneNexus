extends Node
## Account-bound v2 save coordinator. No payload is uploaded before writer and
## revision reconciliation; ambiguous mutations always retain exact request bytes.
const Http = preload("res://services/http_transport.gd")
const Durable = preload("res://services/durable_record.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const Codec = preload("res://app/save_codec.gd")
const SaveJson = preload("res://app/save_json.gd")
const PayloadHash = preload("res://services/save_payload_hash.gd")
signal changed
signal _idle
const COMPATIBILITY := 3
var session: Object
var state: Dictionary = {}
var requires_reload := false
var account_id: String = ""
var root_path: String = ""
var client_build: String = "godot-native"
var callbacks: Dictionary = {}
var store: RefCounted
var _record: RefCounted
var _busy := false
var _quiesced := false
var _reconcile := true
var _initialized := false
var _disabled := false

func configure(account_session: Object, directory: String, build_name: String, hooks: Dictionary = {}) -> void:
	session = account_session
	root_path = directory
	client_build = build_name
	callbacks = hooks
	account_id = str(session.credentials.get("accountId", "")).to_lower()
	if not Http.valid_uuid(account_id): return
	store = Store.new(directory, Slot.account(account_id))
	var folder := directory.path_join("saves/accounts/" + account_id)
	_record = Durable.new(folder.path_join("outbox.json"), _valid_state, folder.path_join("outbox.backup.json"))

func _process(_delta: float) -> void:
	if _disabled or not _initialized or _busy or state.is_empty(): return
	if state.get("syncState") == "retryWaiting" and _retry_time() <= Time.get_unix_time_from_system(): sync()

func context() -> Dictionary:
	return {"accountId": account_id, "sourceSaveRevision": int(state.get("baseRevision", 0)), "writerGeneration": state.get("writerGeneration"), "requiresGameReload": requires_reload}

func bootstrap(guest_payload: Dictionary = {}, interactive: bool = true) -> Dictionary:
	await _lock()
	var result := await _bootstrap_locked(guest_payload, interactive)
	_unlock()
	return result

func _bootstrap_locked(guest_payload: Dictionary, interactive: bool) -> Dictionary:
	if _record == null or not _bound(): return Http.failure("ACCOUNT_SESSION_MISMATCH")
	var loaded: Dictionary = _record.load_record()
	if not loaded.ok: return _block(str(loaded.get("code", "OUTBOX_CORRUPT")))
	var source := "existingOutbox"
	if loaded.value != null:
		state = loaded.value
		for key in ["clientInstanceId", "writerGeneration", "writerClaim", "basePayloadHash", "inFlight", "rebase", "nextRetryAt", "lastSyncedAt", "issueCode", "conflictRevision"]:
			if not state.has(key): state[key] = null
		if state.rebase != null and not state.rebase.has("sourcePayloadHash"): state.rebase["sourcePayloadHash"] = null
		if state.get("apiBaseUrl", session.api_base_url) != session.api_base_url: return _block("ACCOUNT_API_MISMATCH")
		state["apiBaseUrl"] = session.api_base_url
	else:
		var remote := await _load_remote()
		if not remote.ok: return remote
		var local: Variant = _load_local()
		if _local_error(): return Http.failure("LOCAL_SAVE_READ_FAILED")
		state = _initial()
		if store.preserve_current_as_backup() != OK: return _block("LOCAL_BACKUP_FAILED")
		if interactive and not guest_payload.is_empty():
			var guest = Store.new(root_path, Slot.guest())
			if guest.preserve_current_as_backup() != OK: return _block("LOCAL_BACKUP_FAILED")
		if remote.get("snapshot") != null:
			var snapshot: Dictionary = remote.snapshot
			if _save_local(snapshot.data) != OK: return _block("LOCAL_REBASE_APPLY_FAILED")
			state.baseRevision = snapshot.revision
			state.basePayloadHash = _hash(snapshot.data)
			state.lastSyncedAt = snapshot.serverSavedAt
			source = "remoteAccount"
		elif interactive and not guest_payload.is_empty():
			if _save_local(guest_payload) != OK: return _block("LOCAL_SAVE_FAILED")
			source = "guestProgress"
		else: source = "localAccountRecovery" if local != null else "newAccount"
	if state.get("clientInstanceId") == null: state.clientInstanceId = Http.uuid()
	if state.syncState == "sending" or state.syncState == "conflict": state.syncState = "idle"
	if state.syncState == "blocked" and state.get("issueCode") in ["NICKNAME_REQUIRED", "AUTH_SESSION_UNAVAILABLE", "ACCESS_TOKEN_INVALID"]:
		state.syncState = "idle"
		state.issueCode = null
	if state.syncState == "rebasing" and state.rebase == null: return _block("SAVE_REBASE_JOURNAL_MISSING")
	var local: Variant = _load_local()
	if _local_error(): return _block("LOCAL_SAVE_READ_FAILED")
	if local == null and state.dirty and state.inFlight == null: return _block("LOCAL_SAVE_NOT_FOUND")
	if local != null:
		var represented: Variant = state.inFlight.payloadHash if state.inFlight != null else state.basePayloadHash
		if _hash(local) != represented:
			state.localGeneration += 1
			state.dirty = true
	# A persisted writer is not authority for a new process. Resolve an
	# ambiguous update first; otherwise claim a fresh generation now.
	if state.inFlight == null and state.syncState != "suspended": state.writerGeneration = null
	if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
	_initialized = true
	if state.syncState == "suspended":
		var reclaimed := await _claim_writer()
		if not reclaimed.ok: return reclaimed
		state.inFlight = null
		state.dirty = _load_local() != null
		if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
	var result := await _sync_locked()
	result["source"] = source
	return result

func sync(payload: Dictionary = {}) -> Dictionary:
	await _lock()
	var result: Dictionary
	if not _initialized or not _bound() or _disabled: result = Http.failure("ACCOUNT_SESSION_MISMATCH")
	elif not payload.is_empty() and (requires_reload or state.get("syncState") in ["rebasing", "blocked", "suspended"]): result = Http.failure(str(state.get("issueCode", "SAVE_RELOAD_REQUIRED")))
	else:
		result = {"ok": true}
		if not payload.is_empty():
			if _save_local(payload) != OK: result = _block("LOCAL_SAVE_FAILED")
			else:
				state.localGeneration += 1
				state.dirty = _hash(payload) != (state.inFlight.payloadHash if state.inFlight != null else state.basePayloadHash)
				if not _commit(): result = Http.failure("OUTBOX_WRITE_FAILED")
		if result.ok: result = await _sync_locked()
	_unlock()
	return result

func foreground() -> Dictionary:
	await _lock()
	var result := Http.failure("ACCOUNT_SESSION_MISMATCH")
	if _initialized and _bound() and not _disabled:
		if state.syncState == "blocked" or (state.syncState == "retryWaiting" and _retry_time() > Time.get_unix_time_from_system()):
			_unlock()
			return Http.failure(str(state.issueCode), 0, state.syncState == "retryWaiting")
		if state.rebase != null:
			result = await _sync_locked()
			_unlock()
			return result
		# Resolve ambiguous mutation before replacing writer authority.
		if state.get("inFlight") != null and state.syncState != "suspended":
			result = await _send_entry()
			if not result.ok:
				_unlock()
				return result
		if state.syncState == "blocked": result = Http.failure(str(state.issueCode))
		else:
			var suspended: bool = state.syncState == "suspended"
			result = await _claim_writer()
			if result.ok:
				if suspended:
					state.inFlight = null
					state.dirty = _load_local() != null
					if not _commit(): result = Http.failure("OUTBOX_WRITE_FAILED")
				_reconcile = true
				if result.ok: result = await _sync_locked()
	_unlock()
	return result

func acknowledge_reload() -> void:
	requires_reload = false
	_resume()
	changed.emit()

func dispose() -> void:
	_disabled = true
	set_process(false)

func _sync_locked() -> Dictionary:
	if not _bound() or _disabled: return Http.failure("ACCOUNT_SESSION_MISMATCH")
	if state.syncState == "blocked": return Http.failure(str(state.issueCode))
	if state.syncState == "retryWaiting" and _retry_time() > Time.get_unix_time_from_system(): return Http.failure(str(state.issueCode), 0, true)
	if state.rebase != null:
		var rebased := await _resume_rebase()
		if not rebased.ok: return rebased
	if state.syncState == "suspended": return Http.failure(str(state.issueCode))
	if state.inFlight != null:
		var sent := await _send_entry()
		if not sent.ok: return sent
		# Always reclaim after recovering a request from a previous process.
		if _reconcile: state.writerGeneration = null
	if state.writerClaim != null or state.writerGeneration == null:
		var claimed := await _claim_writer()
		if not claimed.ok: return claimed
	if _reconcile:
		var reconciled := await _reconcile_remote()
		if not reconciled.ok: return reconciled
	if requires_reload: return _success()
	if state.dirty:
		var local: Variant = _load_local()
		if local == null or _local_error(): return _block("LOCAL_SAVE_NOT_FOUND")
		var entry := {"idempotencyKey": Http.uuid(), "writerGeneration": state.writerGeneration, "expectedRevision": state.baseRevision, "encodedRequestBody": JSON.stringify({"expectedRevision": state.baseRevision, "clientCompatibilityVersion": COMPATIBILITY, "data": local}, "", false, true), "payloadHash": _hash(local), "localGeneration": state.localGeneration}
		state.inFlight = entry
		state.dirty = false
		state.syncState = "sending"
		if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
		var sent := await _send_entry()
		if not sent.ok: return sent
	state.syncState = "idle"
	state.issueCode = null
	state.nextRetryAt = null
	if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
	_resume()
	return _success()

func _claim_writer() -> Dictionary:
	if state.writerClaim == null:
		state.writerClaim = {"idempotencyKey": Http.uuid(), "encodedRequestBody": JSON.stringify({"clientInstanceId": state.clientInstanceId, "saveSchemaVersion": 2, "clientCompatibilityVersion": COMPATIBILITY, "clientBuild": client_build}, "", false, true)}
		if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
	var claim: Dictionary = state.writerClaim
	var result: Dictionary = await session.request("POST", "/v1/save/writer", claim.encodedRequestBody, {"Idempotency-Key": claim.idempotencyKey})
	if not _bound(): return Http.failure("ACCOUNT_SESSION_MISMATCH")
	if not result.ok: return await _handle_error(result)
	var body: Dictionary = result.body
	if not _integer(body.get("writerGeneration"), 1) or not _date(body.get("claimedAt")): return _block("INVALID_SAVE_RESPONSE")
	state.writerGeneration = body.writerGeneration
	state.writerClaim = null
	state.syncState = "idle"
	state.issueCode = null
	state.retryCount = 0
	state.nextRetryAt = null
	return _success() if _commit() else Http.failure("OUTBOX_WRITE_FAILED")

func _send_entry() -> Dictionary:
	var entry: Dictionary = state.inFlight
	var result: Dictionary = await session.request("PUT", "/v1/save", entry.encodedRequestBody, {"Idempotency-Key": entry.idempotencyKey, "Rune-Nexus-Save-Writer": str(entry.writerGeneration)})
	if not _bound(): return Http.failure("ACCOUNT_SESSION_MISMATCH")
	if not result.ok:
		var code := str(result.get("code", "SAVE_REQUEST_FAILED"))
		if int(result.get("status", 0)) == 426:
			var body: Dictionary = SaveJson.parse(entry.encodedRequestBody)
			if int(body.clientCompatibilityVersion) < COMPATIBILITY:
				# Definitively rejected old request; retain local data, then create a
				# new current-contract request only after re-claim/reconciliation.
				if _load_local() == null and _save_local(Codec.decode(body.data)) != OK: return _block("LOCAL_SAVE_FAILED")
				state.inFlight = null
				state.writerGeneration = null
				state.writerClaim = null
				state.dirty = true
				state.syncState = "idle"
				_reconcile = true
				if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
				return await _sync_locked()
		if code == "SAVE_REVISION_CONFLICT" and int(result.get("status", 0)) == 409:
			var remote := await _load_remote()
			if not remote.ok: return await _handle_error(remote)
			if remote.snapshot == null or int(remote.snapshot.revision) <= int(state.baseRevision): return _block("SAVE_CONFLICT_STATE_INVALID")
			return await _begin_rebase(remote.snapshot)
		if code in ["SAVE_WRITER_REPLACED", "SAVE_WRITER_REQUIRED"]:
			if not await _quiesce(): return _block("LOCAL_SAVE_QUIESCE_FAILED")
			state.writerGeneration = null
			state.syncState = "suspended"
			state.issueCode = code
			if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
			if code == "SAVE_WRITER_REPLACED": await _reconcile_remote()
			return Http.failure(code)
		return await _handle_error(result)
	var body: Dictionary = result.body
	if not _integer(body.get("revision"), 0) or body.revision != entry.expectedRevision + 1 or not _date(body.get("serverSavedAt")): return _block("INVALID_SAVE_RESPONSE")
	state.baseRevision = body.revision
	state.basePayloadHash = entry.payloadHash
	state.lastSyncedAt = body.serverSavedAt
	state.inFlight = null
	state.syncState = "idle"
	state.retryCount = 0
	state.nextRetryAt = null
	state.issueCode = null
	return _success() if _commit() else Http.failure("OUTBOX_WRITE_FAILED")

func _load_remote(conditional: bool = false) -> Dictionary:
	var headers := {"If-None-Match": '"rn-save-%d"' % int(state.baseRevision)} if conditional else {}
	var result: Dictionary = await session.request("GET", "/v1/save", "", headers)
	if not _bound(): return Http.failure("ACCOUNT_SESSION_MISMATCH")
	if int(result.get("status", 0)) == 304: return {"ok": true, "notModified": true, "snapshot": null}
	if int(result.get("status", 0)) == 404 and result.get("code") == "SAVE_NOT_FOUND": return {"ok": true, "snapshot": null}
	if not result.ok: return result
	var body: Dictionary = result.body
	if not _integer(body.get("revision"), 0) or not _date(body.get("serverSavedAt")) or not Codec.is_canonical_v2(body.get("data")): return Http.failure("INVALID_SAVE_RESPONSE")
	return {"ok": true, "snapshot": {"revision": body.revision, "serverSavedAt": body.serverSavedAt, "data": Codec.decode(body.data)}}

func _reconcile_remote() -> Dictionary:
	var remote := await _load_remote(state.basePayloadHash != null)
	if not remote.ok: return await _handle_error(remote)
	var snapshot: Variant = remote.get("snapshot")
	if not remote.get("notModified", false):
		if snapshot == null and state.baseRevision > 0: return _block("REMOTE_SAVE_MISSING")
		if snapshot != null:
			if snapshot.revision < state.baseRevision: return _block("REMOTE_REVISION_REGRESSION")
			if snapshot.revision > state.baseRevision: return await _begin_rebase(snapshot)
			if state.basePayloadHash != null and state.basePayloadHash != _hash(snapshot.data): return _block("REMOTE_PAYLOAD_HASH_MISMATCH")
		state.basePayloadHash = _hash(snapshot.data) if snapshot != null else null
	var local: Variant = _load_local()
	if _local_error(): return _block("LOCAL_SAVE_READ_FAILED")
	state.dirty = local != null and _hash(local) != state.basePayloadHash
	_reconcile = false
	return _success() if _commit() else Http.failure("OUTBOX_WRITE_FAILED")

func _begin_rebase(remote: Dictionary) -> Dictionary:
	var local: Variant = _load_local()
	if _local_error(): return _block("LOCAL_SAVE_READ_FAILED")
	state.rebase = {"targetRevision": remote.revision, "targetPayloadHash": _hash(remote.data), "targetServerSavedAt": remote.serverSavedAt, "sourcePayloadHash": _hash(local) if local != null else null, "stage": "prepared"}
	state.syncState = "rebasing"
	state.conflictRevision = remote.revision
	if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
	return await _resume_rebase()

func _resume_rebase() -> Dictionary:
	if not await _quiesce(): return _block("LOCAL_SAVE_QUIESCE_FAILED")
	while state.rebase != null:
		var journal: Dictionary = state.rebase
		var local: Variant = _load_local()
		if _local_error(): return _block("LOCAL_SAVE_READ_FAILED")
		if journal.stage == "payloadApplied" and local != null and _hash(local) == journal.targetPayloadHash: return _finish_rebase(journal)
		var remote := await _load_remote()
		if not remote.ok: return await _handle_error(remote)
		if remote.snapshot == null or remote.snapshot.revision < journal.targetRevision: return _block("REMOTE_REBASE_TARGET_UNAVAILABLE")
		var snapshot: Dictionary = remote.snapshot
		var remote_hash := _hash(snapshot.data)
		if snapshot.revision == journal.targetRevision and remote_hash != journal.targetPayloadHash: return _block("REMOTE_PAYLOAD_HASH_MISMATCH")
		if snapshot.revision > journal.targetRevision:
			journal.targetRevision = snapshot.revision
			journal.targetPayloadHash = remote_hash
			journal.targetServerSavedAt = snapshot.serverSavedAt
			journal.stage = "prepared"
		var local_hash: Variant = _hash(local) if local != null else null
		if journal.stage == "prepared" or local_hash != journal.sourcePayloadHash:
			journal.sourcePayloadHash = local_hash
			journal.stage = "prepared"
			state.rebase = journal
			if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
			if local != null:
				var envelope := {"version": 1, "rebaseId": "%s:%s:%s:%s" % [account_id, journal.targetRevision, journal.targetPayloadHash, local_hash], "accountId": account_id, "baseRevision": state.baseRevision, "targetRevision": journal.targetRevision, "localPayloadHash": local_hash, "createdAt": _now_iso(), "data": local}
				var error: Variant = callbacks.backup.call(envelope) if callbacks.has("backup") else store.preserve_conflict_backup(envelope)
				if error != OK: return _block("LOCAL_CONFLICT_BACKUP_FAILED")
			journal.stage = "backupPreserved"
			state.rebase = journal
			if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
			continue
		if _save_local(snapshot.data) != OK: return _block("LOCAL_REBASE_APPLY_FAILED")
		requires_reload = true
		journal.stage = "payloadApplied"
		state.rebase = journal
		if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
	return _success()

func _finish_rebase(journal: Dictionary) -> Dictionary:
	requires_reload = true
	state.baseRevision = journal.targetRevision
	state.basePayloadHash = journal.targetPayloadHash
	state.lastSyncedAt = journal.targetServerSavedAt
	state.rebase = null
	state.inFlight = null
	state.dirty = false
	state.retryCount = 0
	state.nextRetryAt = null
	state.conflictRevision = null
	state.syncState = "suspended" if state.issueCode in ["SAVE_WRITER_REPLACED", "SAVE_WRITER_REQUIRED"] else "idle"
	if state.syncState == "idle": state.issueCode = null
	_reconcile = false
	return _success() if _commit() else Http.failure("OUTBOX_WRITE_FAILED")

func _handle_error(result: Dictionary) -> Dictionary:
	if int(result.get("status", 0)) == 426:
		if not await _quiesce(): return _block("LOCAL_SAVE_QUIESCE_FAILED")
		return _block("CLIENT_UPDATE_REQUIRED")
	if result.get("retryable", false):
		state.retryCount += 1
		var delay := maxf(float(result.get("retryAfter", 0)), minf(60.0, pow(2.0, mini(state.retryCount - 1, 6))))
		state.nextRetryAt = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system() + delay)) + "Z"
		state.syncState = "retryWaiting"
		state.issueCode = str(result.get("code", "NETWORK_UNAVAILABLE"))
		if not _commit(): return Http.failure("OUTBOX_WRITE_FAILED")
		return result
	return _block(str(result.get("code", "SAVE_REQUEST_FAILED")))

func _block(code: String) -> Dictionary:
	if not state.is_empty():
		state.syncState = "blocked"
		state.issueCode = code
		state.nextRetryAt = null
		_commit()
	return Http.failure(code)

func _commit() -> bool:
	if _record == null or _record.save_record(state) != OK:
		_disabled = true
		return false
	changed.emit()
	return true

func _load_local() -> Variant:
	return callbacks.load.call() if callbacks.has("load") else store.load_save()

func _save_local(payload: Dictionary) -> int:
	return int(callbacks.save.call(payload)) if callbacks.has("save") else store.save_save(payload)

func _local_error() -> bool:
	return not callbacks.has("load") and store.last_error != OK

func _quiesce() -> bool:
	if _quiesced: return true
	if callbacks.has("quiesce"):
		var result: Variant = await callbacks.quiesce.call()
		if (result is bool and not result) or (result is int and result != OK): return false
	_quiesced = true
	return true

func _resume() -> void:
	if _quiesced and not requires_reload and state.get("syncState") == "idle" and state.get("writerGeneration") != null:
		_quiesced = false
		if callbacks.has("resume"): callbacks.resume.call()

func _bound() -> bool:
	return not _disabled and session != null and session.credentials.get("accountId", "").to_lower() == account_id

func _success() -> Dictionary:
	var result := context()
	result["ok"] = true
	return result

func _initial() -> Dictionary:
	return {"version": 1, "apiBaseUrl": session.api_base_url, "accountIdBinding": account_id, "clientInstanceId": null, "writerGeneration": null, "writerClaim": null, "baseRevision": 0, "basePayloadHash": null, "localGeneration": 0, "dirty": false, "inFlight": null, "rebase": null, "syncState": "idle", "retryCount": 0, "nextRetryAt": null, "lastSyncedAt": null, "issueCode": null, "conflictRevision": null}

func _valid_state(value: Dictionary) -> bool:
	if value.get("version") != 1 or value.get("accountIdBinding") != account_id: return false
	if not _integer(value.get("baseRevision"), 0) or not _integer(value.get("localGeneration"), 0) or not _integer(value.get("retryCount"), 0) or not value.get("dirty") is bool: return false
	if not value.get("syncState") in ["idle", "sending", "retryWaiting", "rebasing", "suspended", "conflict", "blocked"]: return false
	if value.get("basePayloadHash") != null and not _valid_hash(value.basePayloadHash): return false
	if value.get("clientInstanceId") != null and not Http.valid_uuid(value.clientInstanceId): return false
	if value.get("writerGeneration") != null and not _integer(value.writerGeneration, 1): return false
	for key in ["nextRetryAt", "lastSyncedAt"]:
		if value.get(key) != null and not _date(value[key]): return false
	if value.get("issueCode") != null and not value.issueCode is String: return false
	if value.get("conflictRevision") != null and not _integer(value.conflictRevision, 0): return false
	for key in ["inFlight", "writerClaim"]:
		var entry: Variant = value.get(key)
		if entry == null: continue
		if not entry is Dictionary or not Http.valid_uuid(entry.get("idempotencyKey")) or not entry.get("encodedRequestBody") is String: return false
		var body: Variant = SaveJson.parse(entry.encodedRequestBody)
		if not body is Dictionary or not _integer(body.get("clientCompatibilityVersion"), 1) or body.clientCompatibilityVersion > COMPATIBILITY: return false
		if key == "writerClaim":
			if not Http.valid_uuid(body.get("clientInstanceId")) or not _integer(body.get("saveSchemaVersion"), 1) or not body.get("clientBuild") is String or body.clientBuild.strip_edges().is_empty(): return false
			if body.clientCompatibilityVersion == COMPATIBILITY and body.saveSchemaVersion != 2: return false
		else:
			if not _integer(entry.get("writerGeneration"), 1) or not _integer(entry.get("expectedRevision"), 0) or not _integer(entry.get("localGeneration"), 0) or not _valid_hash(entry.get("payloadHash")): return false
			if entry.expectedRevision != value.baseRevision or entry.localGeneration > value.localGeneration or body.get("expectedRevision") != entry.expectedRevision: return false
			if Codec.decode(body.get("data")) == null: return false
			if body.clientCompatibilityVersion == COMPATIBILITY and not Codec.is_canonical_v2(body.data): return false
	var journal: Variant = value.get("rebase")
	if journal != null:
		if not journal is Dictionary or not _integer(journal.get("targetRevision"), 0) or not _valid_hash(journal.get("targetPayloadHash")) or not _date(journal.get("targetServerSavedAt")) or not journal.get("stage") in ["prepared", "backupPreserved", "payloadApplied"]: return false
		if journal.get("sourcePayloadHash") != null and not _valid_hash(journal.sourcePayloadHash): return false
	return true

func _lock() -> void:
	while _busy: await _idle
	_busy = true

func _unlock() -> void:
	_busy = false
	_idle.emit()

func _retry_time() -> float:
	return 0.0 if state.get("nextRetryAt") == null else float(Time.get_unix_time_from_datetime_string(state.nextRetryAt))

static func _hash(payload: Dictionary) -> String:
	return PayloadHash.hash_payload(payload)

static func _integer(value: Variant, minimum: int) -> bool:
	return value is int and value >= minimum

static func _valid_hash(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[0-9a-f]{64}$").search(value) != null

static func _date(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$").search(value) != null

static func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"
