extends Node
## Native authentication. Access tokens live only in memory; refresh intent is
## committed to Android encrypted storage before every network rotation/revocation.
const Http = preload("res://services/http_transport.gd")
const SaveJson = preload("res://app/save_json.gd")
signal changed
signal _idle
signal _refreshed
signal _logged_out
const ENDS_SESSION = ["REFRESH_TOKEN_INVALID", "REFRESH_TOKEN_REUSED", "REFRESH_RECOVERY_EXPIRED", "ACCOUNT_NOT_ACTIVE", "INVALID_AUTH_ACCOUNT"]
var credentials: Dictionary = {}
var api_base_url: String = ""
var issue_code: String = ""
var account_id_hint: String = ""
var platform: Object
var transport: Object
var _busy := false
var _refreshing := false
var _refresh_result: Dictionary = {}
var _logging_out := false
var _logout_in_progress := false
var _logout_result: Dictionary = {}
var _epoch := 0
var _retry_at: float = 0.0
var _failures := 0

func configure(base_url: String, native_platform: Object, http: Object = null) -> void:
	api_base_url = base_url.strip_edges().trim_suffix("/")
	platform = native_platform
	transport = http
	if transport == null:
		transport = Http.new()
		add_child(transport)
	set_process(true)

func _process(_delta: float) -> void:
	if credentials.is_empty() or _busy or _refreshing or _logging_out: return
	var now := Time.get_unix_time_from_system()
	if now >= _retry_at and now >= _expiry(credentials) - 60.0: refresh()

func context() -> Dictionary:
	return {"accountId": credentials.get("accountId", ""), "accessToken": credentials.get("accessToken", ""), "apiBaseUrl": api_base_url}

func restore() -> Dictionary:
	await _lock()
	var result := await _restore_locked()
	_unlock()
	return result

func refresh() -> Dictionary:
	if _refreshing:
		await _refreshed
		return _refresh_result.duplicate(true)
	if _logging_out: return Http.failure("AUTH_SESSION_UNAVAILABLE")
	if Time.get_unix_time_from_system() < _retry_at: return Http.failure("AUTH_RETRY_PENDING", 0, true)
	_refreshing = true
	await _lock()
	_refresh_result = await _restore_locked()
	if not _refresh_result.ok and not str(_refresh_result.get("code", "")) in ENDS_SESSION:
		_failures += 1
		_retry_at = Time.get_unix_time_from_system() + maxf(float(_refresh_result.get("retryAfter", 0)), float(1 << mini(_failures, 6)))
	else:
		_failures = 0
		_retry_at = 0
	_unlock()
	_refreshing = false
	_refreshed.emit()
	return _refresh_result.duplicate(true)

func sign_in(id_token: String) -> Dictionary:
	await _lock()
	var stored := _read()
	var result: Dictionary
	if not stored.ok:
		result = stored
	else:
		if stored.value.get("logoutPending", false):
			result = await _finish_logout(stored.value)
		else: result = {"ok": true}
		if result.ok:
			result = await _auth("google", {"idToken": id_token})
			if result.ok:
				result = _accept(result, "")
				if result.ok: _epoch += 1
	_unlock()
	return result

func sign_in_google(client_id: String) -> Dictionary:
	if platform == null or not platform.has_signal("google_sign_in_completed"): return Http.failure("GOOGLE_SIGN_IN_UNAVAILABLE")
	if not platform.sign_in_google(client_id): return Http.failure("GOOGLE_SIGN_IN_BUSY")
	var value: Variant = await Signal(platform, "google_sign_in_completed")
	var result: Variant = SaveJson.parse(str(value))
	if not result is Dictionary: return Http.failure("INVALID_PLATFORM_RESPONSE")
	if not result.get("ok", false): return Http.failure(str(result.get("error", "GOOGLE_SIGN_IN_FAILED")))
	return await sign_in(str(result.get("idToken", "")))

func logout() -> Dictionary:
	if _logout_in_progress:
		await _logged_out
		return _logout_result.duplicate(true)
	_logout_in_progress = true
	_logging_out = true
	await _lock()
	var stored := _read()
	var result := stored
	if stored.ok:
		var record: Dictionary = stored.value
		record["logoutPending"] = true
		result = _write(record)
		if result.ok:
			# Once intent is durable, no further authenticated work may continue,
			# even when revocation is offline. Next restore retries it first.
			var access: String = str(credentials.get("accessToken", "")) if record.get("pendingKey") == null else ""
			credentials.clear()
			account_id_hint = ""
			_epoch += 1
			changed.emit()
			result = await _finish_logout(record, access)
	_logging_out = false
	_logout_result = result
	_logout_in_progress = false
	_unlock()
	_logged_out.emit()
	return result

func request(method: Variant, path: String, body: String = "", headers: Dictionary = {}) -> Dictionary:
	if method is String: method = {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PUT": HTTPClient.METHOD_PUT, "DELETE": HTTPClient.METHOD_DELETE, "PATCH": HTTPClient.METHOD_PATCH}.get(method.to_upper(), -1)
	if int(method) < 0: return Http.failure("INVALID_HTTP_METHOD")
	path = "/" + path.trim_prefix("/")
	if credentials.is_empty() or _logging_out: return Http.failure("AUTH_SESSION_UNAVAILABLE")
	var epoch := _epoch
	var account: String = credentials.accountId
	if _expiry(credentials) <= Time.get_unix_time_from_system() + 60.0:
		var refreshed := await refresh()
		if not refreshed.ok: return refreshed
		if credentials.is_empty(): return Http.failure("AUTH_SESSION_UNAVAILABLE")
	if _epoch != epoch or credentials.get("accountId") != account: return Http.failure("AUTH_SESSION_CHANGED")
	var attempted: String = credentials.accessToken
	var result := await _authorized(method, path, body, headers, attempted)
	if _epoch != epoch or _logging_out: return Http.failure("AUTH_SESSION_CHANGED")
	if int(result.get("status", 0)) != 401: return result
	if credentials.get("accessToken", "") == attempted:
		var refreshed := await refresh()
		if not refreshed.ok: return refreshed
		if credentials.is_empty(): return Http.failure("AUTH_SESSION_UNAVAILABLE")
	if credentials.is_empty() or _epoch != epoch or credentials.accountId != account: return Http.failure("AUTH_SESSION_CHANGED")
	result = await _authorized(method, path, body, headers, credentials.accessToken)
	return Http.failure("AUTH_SESSION_CHANGED") if _epoch != epoch or _logging_out else result

func _authorized(method: int, path: String, body: String, headers: Dictionary, access: String) -> Dictionary:
	if not Http.supports_base_url(api_base_url) or not path.begins_with("/") or path.begins_with("//"): return Http.failure("INVALID_API_URL")
	var wire := headers.duplicate()
	wire["Authorization"] = "Bearer " + access
	return await transport.request(method, api_base_url + path, body, wire)

func _restore_locked() -> Dictionary:
	var stored := _read()
	if not stored.ok: return stored
	var record: Dictionary = stored.value
	account_id_hint = str(record.get("accountId", "")) if record.get("accountId") != null else ""
	if record.get("logoutPending", false):
		account_id_hint = ""
		credentials.clear()
		return await _finish_logout(record)
	if record.get("refreshToken") == null:
		credentials.clear()
		return {"ok": true, "authenticated": false}
	for attempt in range(2):
		if record.get("pendingKey") == null: record["pendingKey"] = Http.uuid()
		var committed := _write(record)
		if not committed.ok: return committed
		var result := await _auth("refresh", {"refreshToken": record.refreshToken}, {"Idempotency-Key": record.pendingKey})
		if result.ok:
			result = _accept(result, str(record.get("accountId", "")) if record.get("accountId") != null else "")
		if not result.ok:
			issue_code = str(result.get("code", "AUTH_REQUEST_FAILED"))
			if issue_code in ENDS_SESSION:
				var latest: Variant = result.get("rotatedRefreshToken", record.get("refreshToken"))
				record["refreshToken"] = latest
				record["logoutPending"] = true
				credentials.clear()
				account_id_hint = ""
				_epoch += 1
				if _write(record).ok: await _finish_logout(record)
				changed.emit()
			return result
		if _expiry(credentials) > Time.get_unix_time_from_system() + 60.0: return result
		record = {"accountId": credentials.accountId, "refreshToken": result.refreshToken, "pendingKey": null, "logoutPending": false}
	return Http.failure("INVALID_AUTH_EXPIRY", 0, true)

func _accept(result: Dictionary, account: String) -> Dictionary:
	var data: Dictionary = result.body
	var user: Variant = data.get("account")
	if not user is Dictionary or not Http.valid_uuid(user.get("id")) or not data.get("accessToken") is String or str(data.get("accessToken", "")).is_empty() or not data.get("refreshToken") is String or str(data.get("refreshToken", "")).is_empty() or not _valid_date(data.get("accessExpiresAt")):
		return Http.failure("INVALID_AUTH_RESPONSE")
	if data.get("refreshExpiresAt") != null and (not _valid_date(data.refreshExpiresAt) or Time.get_unix_time_from_datetime_string(data.refreshExpiresAt) <= Time.get_unix_time_from_datetime_string(data.accessExpiresAt)): return Http.failure("INVALID_AUTH_RESPONSE")
	if not account.is_empty() and user.id != account:
		var mismatch := Http.failure("INVALID_AUTH_ACCOUNT")
		mismatch["rotatedRefreshToken"] = data.refreshToken
		return mismatch
	var saved := _write({"accountId": user.id, "refreshToken": data.refreshToken, "pendingKey": null, "logoutPending": false})
	if not saved.ok: return saved
	account_id_hint = user.id
	credentials = {"accountId": user.id, "accessToken": data.accessToken, "accessExpiresAt": data.accessExpiresAt}
	issue_code = ""
	changed.emit()
	return {"ok": true, "authenticated": true, "credentials": credentials.duplicate(), "account": user.duplicate(true), "refreshToken": data.refreshToken}

func _auth(endpoint: String, body: Dictionary, headers: Dictionary = {}) -> Dictionary:
	if not Http.supports_base_url(api_base_url): return Http.failure("INVALID_API_URL")
	return await transport.request(HTTPClient.METHOD_POST, api_base_url + "/v1/auth/native/" + endpoint, JSON.stringify(body, "", false, true), headers)

func _finish_logout(record: Dictionary, access: String = "") -> Dictionary:
	var headers := {} if access.is_empty() else {"Authorization": "Bearer " + access}
	var result := await _auth("logout", {"refreshToken": record.get("refreshToken")}, headers)
	if int(result.get("status", 0)) != 204: return result
	var erased := _storage("session_delete")
	if not erased.ok: return erased
	return {"ok": true, "authenticated": false}

func _read() -> Dictionary:
	var stored := _storage("session_read")
	if not stored.ok:
		if stored.get("code") == "session_unreadable":
			var erased := _storage("session_delete")
			return {"ok": true, "value": {}} if erased.ok else erased
		return stored
	if stored.get("value") == null or str(stored.get("value", "")).is_empty(): return {"ok": true, "value": {}}
	var record: Variant = SaveJson.parse(str(stored.value))
	var valid: bool = record is Dictionary and record.get("version") == 1 and record.get("apiBaseUrl") == api_base_url and record.get("logoutPending") is bool
	if valid:
		for key in ["accountId", "refreshToken", "pendingKey"]:
			if record.get(key) != null and not record[key] is String: valid = false
	if valid: return {"ok": true, "value": record}
	var erased := _storage("session_delete")
	return {"ok": true, "value": {}} if erased.ok else erased

func _write(record: Dictionary) -> Dictionary:
	var value := record.duplicate(true)
	value["version"] = 1
	value["apiBaseUrl"] = api_base_url
	if not value.has("logoutPending"): value["logoutPending"] = false
	return _storage("session_write", JSON.stringify(value, "", false, true))

func _storage(method: String, value: String = "") -> Dictionary:
	if platform == null or not platform.has_method(method): return Http.failure("SECURE_STORAGE_UNAVAILABLE")
	var raw: Variant = platform.call(method, value) if method == "session_write" else platform.call(method)
	var result: Variant = SaveJson.parse(raw) if raw is String else raw
	if not result is Dictionary: return Http.failure("INVALID_PLATFORM_RESPONSE")
	if not result.get("ok", false): return Http.failure(str(result.get("error", result.get("code", "SECURE_STORAGE_FAILED"))))
	return result

func _lock() -> void:
	while _busy: await _idle
	_busy = true

func _unlock() -> void:
	_busy = false
	_idle.emit()

static func _valid_date(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$").search(value) != null

static func _expiry(value: Dictionary) -> float:
	return float(Time.get_unix_time_from_datetime_string(str(value.get("accessExpiresAt", "1970-01-01T00:00:00Z"))))
