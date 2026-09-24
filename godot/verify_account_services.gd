extends SceneTree
const Auth = preload("res://services/account_session.gd")
const Online = preload("res://services/online_save.gd")
const Http = preload("res://services/http_transport.gd")
const Codec = preload("res://app/save_codec.gd")
const SaveJson = preload("res://app/save_json.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const ACCOUNT = "12345678-1234-4234-8234-123456789abc"
var failures: Array[String] = []
var sandbox: String

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
	func request(method, path, body = "", headers = {}):
		calls.append({"method": method, "path": path, "body": body, "headers": headers.duplicate(true)})
		await tree.process_frame
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
	return online

func _run():
	await _auth_tests()
	await _save_tests()
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
	check(not first.ok and account.account_id_hint == ACCOUNT, "Offline restore retains account-only hint")
	check(SaveJson.parse(secure.value).pendingKey == "persisted-key", "Failed refresh preserves pending key")
	var restored: Dictionary = await account.restore()
	check(restored.ok and account.credentials.accountId == ACCOUNT, "Native session restores")
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
	remote.responses = [response(0, {}, "NETWORK_UNAVAILABLE", true)]
	var failed: Dictionary = await online.sync(payload(101))
	check(not failed.ok and online.state.inFlight != null, "Ambiguous upload remains durable")
	online.state.inFlight.encodedRequestBody = "  " + online.state.inFlight.encodedRequestBody + "  "
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

func _hash_tests():
	var fixture_path := OS.get_environment("RUNE_ACCOUNT_HASH_FIXTURE")
	if fixture_path.is_empty(): return
	var fixtures: Variant = SaveJson.parse(FileAccess.get_file_as_string(fixture_path))
	var payloads: Variant = SaveJson.parse(FileAccess.get_file_as_string(OS.get_environment("RUNE_ACCOUNT_CODEC_FIXTURE")))
	for fixture in fixtures:
		var normalized: Variant = Codec.decode(payloads[fixture.index].decoded)
		check(Hash.hash_payload(normalized) == fixture.hash, "Existing Dart payload hash: " + str(fixture.index))
