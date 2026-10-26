extends SceneTree
const Auth = preload("res://services/account_session.gd")
const Online = preload("res://services/online_save.gd")
const Http = preload("res://services/http_transport.gd")
const Codec = preload("res://app/save_codec.gd")
const SaveJson = preload("res://app/save_json.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Durable = preload("res://services/durable_record.gd")
const LocalStore = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const ACCOUNT = "12345678-1234-4234-8234-123456789abc"
var failures: Array[String] = []
var sandbox: String
class CountingStore extends LocalStore:
	var loads := 0
	func load_save() -> Variant:
		loads += 1
		return super.load_save()
class CountingRecord extends Durable:
	var writes := 0
	func _write(candidate: String, raw: String) -> Error:
		writes += 1
		return super._write(candidate, raw)

class SecureFixture extends RefCounted:
	var value: Variant = null
	var fail_write := false
	func session_read(): return {"ok": true, "value": value}
	func session_write(raw):
		if fail_write: return {"ok": false, "error": "FIXTURE_WRITE_FAILED"}
		value = raw
		return {"ok": true}
	func session_delete(): value = null; return {"ok": true}

class WireFixture extends RefCounted:
	var responses: Array = []
	var calls: Array = []
	var tree: SceneTree
	func request(method, url, body = "", headers = {}):
		calls.append({"method": method, "url": url, "body": body, "headers": headers.duplicate(true)})
		await tree.process_frame
		if responses.is_empty(): return {"ok": false, "code": "NO_FIXTURE", "status": 500, "body": {}}
		return responses.pop_front()

class SessionFixture extends RefCounted:
	var credentials := {"accountId": ACCOUNT}
	var api_base_url := "http://127.0.0.1:19763"
	var responses: Array = []
	var calls: Array = []
	var tree: SceneTree
	var request_hook: Callable
	func request(method, path, body = "", headers = {}):
		calls.append({"method": method, "path": path, "body": body, "headers": headers.duplicate(true)})
		await tree.process_frame
		if request_hook.is_valid(): request_hook.call(method, path)
		if responses.is_empty(): return {"ok": false, "code": "NO_FIXTURE", "status": 500, "body": {}}
		return responses.pop_front()

func _initialize():
	sandbox = OS.get_environment("RUNE_ACCOUNT_TEST_ROOT")
	if sandbox.is_empty():
		push_error("RUNE_ACCOUNT_TEST_ROOT must name an isolated directory")
		quit(2)
		return
	_run.call_deferred()

func check(value: bool, label: String):
	if not value: failures.append(label); push_error(label)

func response(status: int, body: Dictionary = {}, code: String = "", retryable: bool = false) -> Dictionary:
	return {"ok": status >= 200 and status < 300, "status": status, "body": body, "code": code, "retryable": retryable}

func auth_response(token: String = "fixture-access", account: String = ACCOUNT) -> Dictionary:
	return response(200, {"account": {"id": account}, "accessToken": token, "refreshToken": "fixture-refresh-rotated", "accessExpiresAt": "2099-01-01T00:00:00Z"})

func payload(stamp: int) -> Dictionary:
	return Codec.decode({"version": 2, "savedAtMillis": stamp, "preferences": {}, "progression": {}, "turretModules": {}, "activeRun": null})

func make_online(label: String, remote: SessionFixture):
	var online = Online.new()
	root.add_child(online)
	online.configure(remote, sandbox.path_join(label), "fixture")
	online._record = CountingRecord.new(online._record.path, online._valid_state, online._record.backup_path)
	return online

func _run():
	await _auth_tests()
	await _save_tests()
	await _checkpoint_sync_tests()
	await _legacy_writer_claim_tests()
	await _boss_damage_training_tests()
	_hash_tests()
	var local_url := OS.get_environment("RUNE_ACCOUNT_HTTP_FIXTURE")
	if not local_url.is_empty():
		var http = Http.new()
		root.add_child(http)
		var result: Dictionary = await http.request(HTTPClient.METHOD_POST, local_url + "/echo", '{ "exact" : 42 }', {"Idempotency-Key": "fixture-key"})
		check(result.ok and result.body.get("received") == '{ "exact" : 42 }' and result.body.get("key") == "fixture-key", "Real HTTPRequest sends exact body and headers")
		http.queue_free()
	if failures.is_empty(): print("PASS: account auth, durable outbox, bootstrap, rebase, hash and HTTP fixtures")
	else: print("FAIL: ", failures)
	quit(0 if failures.is_empty() else 1)

func _auth_tests():
	var secure := SecureFixture.new()
	secure.value = JSON.stringify({"version": 1, "apiBaseUrl": "http://127.0.0.1:19763", "accountId": ACCOUNT, "refreshToken": "fixture-refresh", "pendingKey": "persisted-key", "logoutPending": false})
	var wire := WireFixture.new()
	wire.tree = self
	wire.responses = [response(0, {}, "NETWORK_UNAVAILABLE", true), auth_response()]
	var account = Auth.new()
	root.add_child(account)
	account.configure("http://127.0.0.1:19763", secure, wire)
	var first: Dictionary = await account.restore()
	check(not first.ok and account.account_id_hint == ACCOUNT and not account.authenticated(), "Offline restore retains account-only hint without play authority")
	check(SaveJson.parse(secure.value).pendingKey == "persisted-key", "Failed refresh preserves pending key")
	var restored: Dictionary = await account.restore()
	check(restored.ok and account.credentials.accountId == ACCOUNT and account.authenticated(), "Native session restores server-confirmed authority")
	check(wire.calls[0].body == wire.calls[1].body and wire.calls[0].headers == wire.calls[1].headers, "Refresh loss retries exact token/key")
	check(SaveJson.parse(secure.value).pendingKey == null, "Successful rotation clears pending key")
	wire.responses = [response(401, {}, "ACCESS_TOKEN_INVALID"), auth_response("new-access"), response(200, {"value": 1})]
	var resource: Dictionary = await account.request("GET", "v1/test")
	check(resource.ok and wire.calls[-1].headers.Authorization == "Bearer new-access", "401 rotates once and retries")
	wire.responses = [auth_response("concurrent-access")]
	var before := wire.calls.size()
	account.refresh()
	var concurrent: Dictionary = await account.refresh()
	check(concurrent.ok and wire.calls.size() == before + 1, "Concurrent refresh is single flight")
	var retained: Dictionary = account.credentials.duplicate(true)
	wire.responses = [response(0, {}, "NETWORK_UNAVAILABLE", true)]
	var lost: Dictionary = await account.refresh()
	check(not lost.ok and not account.authenticated() and account.credentials == retained, "Transient timer refresh failure blocks auth while preserving cached credentials")
	var pending: Dictionary = SaveJson.parse(secure.value)
	check(pending.refreshToken == "fixture-refresh-rotated" and pending.pendingKey != null and not pending.logoutPending, "Network auth failure keeps secure refresh intent and never requests logout")
	check(account.context().accessToken.is_empty() and account.context().accountId.is_empty(), "Failed auth cannot publish a usable account context")
	wire.responses = [auth_response("recovered-access")]
	account.restore()
	check(not account.authenticated(), "In-flight server reauthentication locks play authority")
	while account.authentication_pending(): await process_frame
	check(account.authenticated(), "Successful server retry restores authority")
	var expires: String = account.credentials.accessExpiresAt
	account.credentials.accessExpiresAt = "2020-01-01T00:00:00Z"
	check(not account.authenticated(), "Expired cached access never grants play authority")
	account.credentials.accessExpiresAt = expires
	wire.responses = [response(503, {}, "SERVICE_UNAVAILABLE", true)]
	var unavailable: Dictionary = await account.request("GET", "v1/economy")
	check(not unavailable.ok and not account.authenticated() and not SaveJson.parse(secure.value).logoutPending, "Ordinary account API outage blocks offline play without signing out")
	wire.responses = [auth_response("request-recovered-access")]
	check((await account.restore()).ok and account.authenticated(), "Account API outage recovers through server reauthentication")
	wire.responses = [response(0, {}, "NETWORK_UNAVAILABLE", true), response(204)]
	var logged_out: Dictionary = await account.logout()
	check(not logged_out.ok and account.credentials.is_empty(), "Offline logout disallows authenticated work")
	check(SaveJson.parse(secure.value).logoutPending, "Offline logout preserves intent")
	var finished: Dictionary = await account.restore()
	check(finished.ok and not finished.authenticated and secure.value == null, "Restore completes pending logout first")
	secure.fail_write = true
	wire.responses = [auth_response()]
	var denied: Dictionary = await account.sign_in("fixture-id-token")
	check(not denied.ok and account.credentials.is_empty(), "Storage failure never publishes session")
	secure.fail_write = false
	secure.value = JSON.stringify({"version": 1, "apiBaseUrl": "https://different.invalid", "accountId": ACCOUNT, "refreshToken": "private", "pendingKey": null, "logoutPending": false})
	var mismatched: Dictionary = await account.restore()
	check(mismatched.ok and not mismatched.authenticated and secure.value == null, "API binding prevents token reuse")
	secure.value = JSON.stringify({"version": 1, "apiBaseUrl": "http://127.0.0.1:19763", "accountId": ACCOUNT, "refreshToken": "expired-refresh", "pendingKey": null, "logoutPending": false})
	wire.responses = [response(401, {}, "REFRESH_TOKEN_INVALID"), response(0, {}, "NETWORK_UNAVAILABLE", true)]
	var ended: Dictionary = await account.restore()
	check(not ended.ok and ended.code == "REFRESH_TOKEN_INVALID" and account.credentials.is_empty() and account.account_id_hint.is_empty(), "Definitive refresh error clears account authority")
	check(SaveJson.parse(secure.value).logoutPending, "Failed revoke after invalid refresh remains logoutPending")
	secure.value = JSON.stringify({"version": 1, "apiBaseUrl": "http://127.0.0.1:19763", "accountId": ACCOUNT, "refreshToken": "fixture-refresh", "pendingKey": "old-expired-key", "logoutPending": false})
	var old_response := auth_response("old-access")
	old_response.body.accessExpiresAt = "2020-01-01T00:00:00Z"
	wire.responses = [old_response, auth_response("fresh-access")]
	var renewed: Dictionary = await account.restore()
	check(renewed.ok and account.credentials.accessToken == "fresh-access" and wire.calls[-2].headers["Idempotency-Key"] != wire.calls[-1].headers["Idempotency-Key"], "Expired recovered access rotates with new durable key")
	account.queue_free()
	await process_frame

func _save_tests():
	var remote := SessionFixture.new()
	remote.tree = self
	remote.responses = [response(200, {"revision": 4, "serverSavedAt": "2026-01-01T00:00:00Z", "data": payload(100)}), response(200, {"writerGeneration": 7, "claimedAt": "2026-01-01T00:00:00Z"}), response(304)]
	var online = make_online("remote-first", remote)
	var boot: Dictionary = await online.bootstrap(payload(5), true)
	check(boot.ok and boot.source == "remoteAccount" and online.store.load_save().savedAtMillis == 100, "Remote save takes precedence over guest")
	check(remote.calls.size() == 3 and remote.calls[2].headers.has("If-None-Match"), "Bootstrap reconciles with conditional revision")
	var local_generation: int = online.state.localGeneration
	var record_writes: int = online._record.writes
	var calls_count := remote.calls.size()
	var identical: Dictionary = await online.sync(payload(100))
	check(identical.ok and online.state.localGeneration == local_generation and online._record.writes == record_writes and remote.calls.size() == calls_count, "Clean identical payload preserves generation and skips durable writes and HTTP")
	remote.responses = [response(0, {}, "NETWORK_UNAVAILABLE", true)]
	var failed: Dictionary = await online.sync(payload(101))
	check(not failed.ok and online.state.inFlight != null, "Ambiguous upload remains durable")
	var journal: Dictionary = online.state.inFlight.duplicate(true)
	local_generation = online.state.localGeneration
	record_writes = online._record.writes
	await online.sync(payload(101))
	check(online.state.localGeneration == local_generation and online._record.writes == record_writes and online.state.inFlight == journal, "Repeated ambiguous payload preserves exact dirty journal without new writes")
	await online.sync(payload(102))
	check(online.state.dirty and online.state.inFlight == journal and online.store.load_save() == payload(102), "New local progress while request is pending retains request bytes and dirty state")
	local_generation = online.state.localGeneration
	record_writes = online._record.writes
	await online.sync(payload(102))
	check(online.state.dirty and online.state.localGeneration == local_generation and online._record.writes == record_writes, "Identical dirty payload preserves pending progress")
	await online.sync(payload(101))
	check(not online.state.dirty and online.state.inFlight == journal and online.store.load_save() == payload(101), "Requested payload is restored when actual local save differs from journal")
	# A persisted generation-ten upload must still replay byte for byte after
	# this client adds optional training fields and moves to generation twelve.
	var old_body: Dictionary = SaveJson.parse(online.state.inFlight.encodedRequestBody)
	old_body.clientCompatibilityVersion = 10
	online.state.inFlight.encodedRequestBody = "  " + JSON.stringify(old_body, "", false, true) + "  "
	online._commit()
	var exact: String = online.state.inFlight.encodedRequestBody
	var key: String = online.state.inFlight.idempotencyKey
	online.dispose()
	online.queue_free()
	await process_frame
	remote.responses = [response(200, {"revision": 5, "serverSavedAt": "2026-01-01T00:00:01Z"}), response(200, {"writerGeneration": 8, "claimedAt": "2026-01-01T00:00:01Z"}), response(304)]
	var resumed = make_online("remote-first", remote)
	# Force retry deadline to be due, preserving all request bytes.
	var record = resumed._record.load_record().value
	record.nextRetryAt = "2020-01-01T00:00:00Z"
	resumed._record.save_record(record)
	var offset := remote.calls.size()
	var recovered: Dictionary = await resumed.bootstrap({}, false)
	check(recovered.ok and remote.calls[offset].method == "PUT" and remote.calls[offset].body == exact and remote.calls[offset].headers["Idempotency-Key"] == key, "Restart replays exact mutation before claim/load")
	check(resumed.state.inFlight == null and resumed.state.baseRevision == 5, "Recovered ack advances exactly one revision")
	remote.responses = [response(200, {"writerGeneration": 9, "claimedAt": "2026-01-01T00:00:02Z"}), response(200, {"revision": 6, "serverSavedAt": "2026-01-01T00:00:02Z", "data": payload(200)}), response(200, {"revision": 6, "serverSavedAt": "2026-01-01T00:00:02Z", "data": payload(200)}), response(200, {"revision": 6, "serverSavedAt": "2026-01-01T00:00:02Z", "data": payload(200)})]
	var rebased: Dictionary = await resumed.foreground()
	check(rebased.ok and resumed.requires_reload and resumed.store.load_save().savedAtMillis == 200, "New remote revision rebases and requests runtime reload")
	check(FileAccess.file_exists(resumed.store.conflict_path) and resumed.state.rebase == null, "Rebase preserves conflict backup and clears journal")
	resumed.acknowledge_reload()
	remote.responses = [response(426, {}, "CLIENT_UPDATE_REQUIRED")]
	var blocked: Dictionary = await resumed.sync(payload(201))
	check(not blocked.ok and resumed.state.issueCode == "CLIENT_UPDATE_REQUIRED" and resumed.state.inFlight != null, "426 blocks preserving exact current request")
	var calls_before := remote.calls.size()
	var still_blocked: Dictionary = await resumed.foreground()
	check(not still_blocked.ok and remote.calls.size() == calls_before, "Foreground cannot bypass 426 block")
	resumed.dispose()
	resumed.queue_free()
	await process_frame
	var missing := SessionFixture.new()
	missing.tree = self
	missing.responses = [response(404, {}, "SAVE_NOT_FOUND"), response(200, {"writerGeneration": 1, "claimedAt": "2026-01-01T00:00:00Z"}), response(404, {}, "SAVE_NOT_FOUND")]
	var fresh = make_online("restore-no-guest", missing)
	var restored: Dictionary = await fresh.bootstrap(payload(33), false)
	check(restored.ok and restored.source == "newAccount" and fresh.store.load_save() == null, "Automatic restore never adopts guest progress")
	fresh.dispose()
	fresh.queue_free()

func _checkpoint_sync_tests():
	var remote := SessionFixture.new()
	remote.tree = self
	remote.responses = [response(200, {"revision":4,"serverSavedAt":"2026-01-01T00:00:00Z","data":payload(100)}), response(200, {"writerGeneration":7,"claimedAt":"2026-01-01T00:00:00Z"}), response(304)]
	var online = make_online("checkpoint-sync", remote)
	check((await online.bootstrap({}, false)).ok, "Checkpoint fixture bootstraps")
	var counted := CountingStore.new(online.root_path, Slot.account(ACCOUNT))
	online.store = counted
	var before_calls := remote.calls.size()
	check((await online.sync_checkpoint()).ok and counted.loads == 1 and remote.calls.size() == before_calls, "Clean durable checkpoint loads once without upload")
	check(counted.save_save(payload(101)) == OK, "Changed checkpoint persists before sync")
	counted.loads = 0
	remote.responses = [response(200, {"revision":5,"serverSavedAt":"2026-01-01T00:00:01Z"})]
	check((await online.sync_checkpoint()).ok and counted.loads == 1, "Dirty checkpoint reuses its read before network wait")
	check(SaveJson.parse(remote.calls[-1].body).data == payload(101) and online.state.basePayloadHash == Hash.hash_payload(payload(101)), "Checkpoint request and journal represent durable data")
	# Authority acquisition yields. A newer external checkpoint written during
	# that wait must replace the snapshot read at the start of this operation.
	counted.save_save(payload(102))
	counted.loads = 0
	online.state.writerGeneration = null
	remote.request_hook = func(method, path):
		if method == "POST" and path == "/v1/save/writer":
			counted.save_save(payload(103))
			remote.request_hook = Callable()
	remote.responses = [response(200, {"writerGeneration":8,"claimedAt":"2026-01-01T00:00:02Z"}), response(200, {"revision":6,"serverSavedAt":"2026-01-01T00:00:02Z"})]
	check((await online.sync_checkpoint()).ok and counted.loads == 2, "Checkpoint is reread after authority wait")
	check(SaveJson.parse(remote.calls[-1].body).data == payload(103) and online.state.basePayloadHash == Hash.hash_payload(payload(103)), "Post-wait upload includes concurrently replaced checkpoint")
	counted.clear()
	var journal: Dictionary = online.state.duplicate(true)
	before_calls = remote.calls.size()
	var missing: Dictionary = await online.sync_checkpoint()
	check(not missing.ok and missing.code == "LOCAL_SAVE_FAILED" and online.state == journal and remote.calls.size() == before_calls, "Missing checkpoint cannot mutate journal or send HTTP")
	online.dispose()
	online.queue_free()
	await process_frame

func _hash_tests():
	var fixture_path := OS.get_environment("RUNE_ACCOUNT_HASH_FIXTURE")
	if fixture_path.is_empty(): return
	var fixtures: Variant = SaveJson.parse(FileAccess.get_file_as_string(fixture_path))
	var payloads: Variant = SaveJson.parse(FileAccess.get_file_as_string(OS.get_environment("RUNE_ACCOUNT_CODEC_FIXTURE")))
	for fixture in fixtures:
		# Hash archived normalized payloads directly: exact old receipts remain
		# stable even when newer codecs reject synthetic unsupported revisions.
		var normalized: Variant = payloads[fixture.index].decoded
		check(Hash.hash_payload(normalized) == fixture.hash, "Existing Dart payload hash: " + str(fixture.index))

	var run: Dictionary = Codec.decode({"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":{"phase":"wave","enemies":[{"type":"normal","burnInstances":[{"remaining":3.0,"damagePerSecond":5.0}]}]}})
	var baseline: String = Hash.hash_payload(run)
	for field in ["damageOverTimeIncreaseMultiplier", "poisonDamageOverTimeIncreaseMultiplier"]:
		var candidate: Dictionary = run.duplicate(true)
		var record: Dictionary = candidate.activeRun.enemies[0].burnInstances[0] if field == "damageOverTimeIncreaseMultiplier" else candidate.activeRun.enemies[0]
		record[field] = 1.0
		check(Hash.hash_payload(Codec.decode(candidate)) == baseline, "Neutral DoT metadata preserves old hash: " + field)
		record[field] = 1.5
		var changed: String = Hash.hash_payload(Codec.decode(candidate))
		check(changed != baseline, "DoT metadata participates in hash: " + field)
		record[field] = 2.0
		check(Hash.hash_payload(Codec.decode(candidate)) != changed, "DoT coefficient changes hash: " + field)

func _legacy_writer_claim_tests():
	var remote := SessionFixture.new()
	remote.tree = self
	remote.responses = [response(200, {"revision":4,"serverSavedAt":"2026-01-01T00:00:00Z","data":payload(100)}), response(200, {"writerGeneration":7,"claimedAt":"2026-01-01T00:00:00Z"}), response(304)]
	var online = make_online("old-writer-claim", remote)
	check((await online.bootstrap({}, false)).ok,"Old writer fixture bootstraps")
	var old_raw := JSON.stringify({"clientInstanceId":online.state.clientInstanceId,"saveSchemaVersion":2,"clientCompatibilityVersion":8,"clientBuild":"old-build"})
	online.state.writerClaim = {"idempotencyKey":"52345678-1234-4234-8234-123456789abc","encodedRequestBody":old_raw}
	online.state.writerGeneration = null
	check(online._commit(),"Old writer claim remains durable")
	remote.responses = [response(426, {}, "CLIENT_UPDATE_REQUIRED"), response(200, {"writerGeneration":8,"claimedAt":"2026-01-01T00:00:01Z"})]
	var result: Dictionary = await online._claim_writer()
	check(result.ok and remote.calls[-2].body == old_raw and remote.calls[-2].headers["Idempotency-Key"] == "52345678-1234-4234-8234-123456789abc","Upgraded client resolves old writer request exactly first")
	check(SaveJson.parse(remote.calls[-1].body).clientCompatibilityVersion == Online.COMPATIBILITY and remote.calls[-1].headers["Idempotency-Key"] != "52345678-1234-4234-8234-123456789abc","Definitive legacy426 creates fresh current writer claim")
	check(online.store.load_save() == payload(100) and remote.credentials.accountId == ACCOUNT,"Writer upgrade keeps local progress and account binding")
	online.dispose()
	online.queue_free()
	await process_frame

func _boss_damage_training_tests():
	var legacy := payload(300)
	var legacy_hash := Hash.hash_payload(legacy)
	check(not legacy.progression.has("bossDamageTrainingUpgradeLevel") and Hash.hash_payload(Codec.decode(legacy)) == legacy_hash, "Absent training keeps legacy payload hash through decoding")
	for field in ["directDamageTrainingUpgradeLevel", "splashDamageTrainingUpgradeLevel", "damageOverTimeTrainingUpgradeLevel"]:
		check(not Codec.decode(legacy).progression.has(field), "Absent new training remains absent: " + field)
		var single: Dictionary = legacy.duplicate(true)
		single.progression[field] = 1
		check(Hash.hash_payload(single) != legacy_hash, "New training participates in hash: " + field)
		var maximum: Dictionary = single.duplicate(true)
		maximum.progression[field] = 60
		check(Hash.hash_payload(maximum) != Hash.hash_payload(single), "New training level changes hash: " + field)
		check(Codec.decode(maximum) == maximum, "New training survives typed decoding: " + field)
	var trained: Dictionary = legacy.duplicate(true)
	trained.progression.bossDamageTrainingUpgradeLevel = 1
	trained.progression.directDamageTrainingUpgradeLevel = 1
	trained.progression.splashDamageTrainingUpgradeLevel = 60
	trained.progression.damageOverTimeTrainingUpgradeLevel = 30
	check(Hash.hash_payload(trained) != legacy_hash, "Training level participates in payload hash")
	var trained_max: Dictionary = trained.duplicate(true)
	trained_max.progression.bossDamageTrainingUpgradeLevel = 40
	check(Hash.hash_payload(trained_max) != Hash.hash_payload(trained), "Distinct training levels have distinct payload hashes")
	var remote := SessionFixture.new()
	remote.tree = self
	remote.responses = [response(200, {"revision":4,"serverSavedAt":"2026-01-01T00:00:00Z","data":legacy}), response(200, {"writerGeneration":7,"claimedAt":"2026-01-01T00:00:00Z"}), response(304)]
	var online = make_online("boss-damage-training", remote)
	check((await online.bootstrap({}, false)).ok, "Training fixture bootstraps an old account")
	# Resume a journal written by a reader which did not know the new key.
	var target := payload(301)
	online.state.rebase = {"targetRevision":5,"targetPayloadHash":Hash.hash_payload(target),"targetServerSavedAt":"2026-01-01T00:00:01Z","sourcePayloadHash":legacy_hash,"stage":"prepared"}
	check(online._commit(), "Legacy rebase journal stays valid")
	var persisted: Dictionary = online._record.load_record()
	check(persisted.ok and persisted.value.rebase.targetPayloadHash == Hash.hash_payload(target), "Legacy rebase journal reload preserves its target hash")
	online.state = persisted.value
	remote.responses = [response(200, {"revision":5,"serverSavedAt":"2026-01-01T00:00:01Z","data":target}), response(200, {"revision":5,"serverSavedAt":"2026-01-01T00:00:01Z","data":target})]
	var rebased: Dictionary = await online._resume_rebase()
	check(rebased.ok and online.state.rebase == null and online.store.load_save() == target, "Legacy rebase target hash survives optional training introduction")
	online.acknowledge_reload()
	trained.savedAtMillis = 301
	remote.responses = [response(200, {"revision":6,"serverSavedAt":"2026-01-01T00:00:02Z"})]
	var saved: Dictionary = await online.sync(trained)
	check(saved.ok and online.store.load_save().progression.bossDamageTrainingUpgradeLevel == 1, "Purchased training persists in account save")
	var request: Dictionary = SaveJson.parse(remote.calls[-1].body)
	check(request.clientCompatibilityVersion == Online.COMPATIBILITY and request.data.progression.bossDamageTrainingUpgradeLevel == 1, "Training upload uses the current generation")
	check(request.data.progression.directDamageTrainingUpgradeLevel == 1 and request.data.progression.splashDamageTrainingUpgradeLevel == 60 and request.data.progression.damageOverTimeTrainingUpgradeLevel == 30, "Generation twelve uploads all training fields")
	online.dispose()
	online.queue_free()
	await process_frame
