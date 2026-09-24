extends Node
## Manifest and native APK installer retain the existing update.json contract.
const Json = preload("res://app/save_json.gd")
signal changed
var platform
var manifest_url := ""
var installed: Dictionary = {}
var release: Dictionary = {}
var busy := false
var blocked := true
var server_required := false
var downloaded := false
var message := "업데이트 정보를 확인하고 있습니다"

func setup(native_platform, url: String) -> void:
	platform = native_platform
	manifest_url = url
	blocked = platform != null and not url.is_empty()

func require_update() -> void:
	server_required = true
	blocked = true
	changed.emit()
	if not busy: check()

func required() -> bool:
	return server_required or int(installed.get("versionCode",0)) < int(release.get("minimumSupportedVersionCode",0))

func skip() -> void:
	if busy or release.is_empty() or required(): return
	blocked = false
	changed.emit()

static func valid_url(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^https://[^/@?#]+(/[^#]*)?$").search(value) != null

static func valid_hash(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[0-9a-fA-F]{64}$").search(value) != null

static func valid_manifest(value: Dictionary) -> bool:
	if value.get("schemaVersion") != 1 or not value.get("versionCode") is int or value.versionCode <= 0 or value.versionCode > 2100000000: return false
	if not value.get("versionName") is String or value.versionName.strip_edges().is_empty() or not value.get("packageName") is String or not value.get("notes") is String: return false
	if not valid_url(value.get("apkUrl")) or not valid_hash(value.get("sha256")): return false
	if not value.get("sizeBytes") is int or value.sizeBytes <= 0 or value.sizeBytes > 512*1024*1024: return false
	var minimum: Variant = value.get("minimumSupportedVersionCode",0)
	return minimum is int and minimum >= 0 and minimum <= value.versionCode

func check() -> Dictionary:
	if busy: return {"ok":false,"code":"BUSY"}
	if platform == null or manifest_url.is_empty():
		blocked = server_required
		return {"ok":not blocked}
	busy = true
	blocked = true
	message = "업데이트 정보를 확인하고 있습니다"
	changed.emit()
	var result: Dictionary = await _check()
	busy = false
	if not result.get("ok",false): message = "업데이트 정보를 확인하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요."
	changed.emit()
	return result

func _check() -> Dictionary:
	if not platform.query_installed_version(): return {"ok":false}
	var native: Variant = Json.parse(await platform.installed_version_ready)
	if not native is Dictionary or not native.get("ok",false) or not native.get("value") is Dictionary: return {"ok":false}
	installed = native.value
	var response: Dictionary = await _manifest()
	if not response.get("ok",false): return response
	var next: Dictionary = response.body
	if not valid_manifest(next) or next.packageName != installed.get("packageName"): return {"ok":false}
	if release.get("versionCode") != next.versionCode or release.get("sha256") != next.sha256: downloaded = false
	release = next if next.versionCode > int(installed.get("versionCode",0)) else {}
	blocked = not release.is_empty() or server_required
	message = "새 버전이 준비되었습니다" if not release.is_empty() else ("서버에서 새 버전을 요구합니다. 잠시 후 다시 확인해 주세요." if server_required else "최신 버전입니다")
	return {"ok":true}

static func _is_redirect(response: Array) -> bool:
	# With automatic redirects disabled, Godot reports the limit result while
	# retaining the HTTP status and Location header for manual HTTPS validation.
	return response[0] in [HTTPRequest.RESULT_SUCCESS, HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED] and response[1] in [301,302,303,307,308]

func _manifest() -> Dictionary:
	var target := manifest_url
	for redirect in range(6):
		if not valid_url(target): return {"ok":false}
		var request := HTTPRequest.new()
		request.timeout = 15
		request.max_redirects = 0
		request.body_size_limit = 65536
		add_child(request)
		if request.request(target,PackedStringArray(["Cache-Control: no-cache"])) != OK:
			request.queue_free()
			return {"ok":false}
		var response: Array = await request.request_completed
		request.queue_free()
		if _is_redirect(response):
			var location := ""
			for header in response[2]:
				if header.to_lower().begins_with("location:"): location = header.substr(9).strip_edges()
			if location.begins_with("/") and not location.begins_with("//"):
				var match_url = RegEx.create_from_string("^https://[^/]+").search(target)
				location = match_url.get_string()+location
			target = location
			continue
		if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200: return {"ok":false}
		var value: Variant = Json.parse(response[3].get_string_from_utf8())
		return {"ok":value is Dictionary,"body":value if value is Dictionary else {}}
	return {"ok":false}

func _patch() -> Dictionary:
	var chosen := {}
	var patches: Variant = release.get("patches",[])
	if not patches is Array or patches.size() > 3: return chosen
	for patch in patches:
		if not patch is Dictionary or patch.get("format") != "rune-apk-delta-v1": continue
		if patch.get("fromVersionCode") != installed.get("versionCode") or str(patch.get("fromSha256","")).to_lower() != str(installed.get("apkSha256","")).to_lower(): continue
		if not valid_hash(patch.get("sha256")) or not valid_url(patch.get("url")) or not patch.get("sizeBytes") is int or patch.sizeBytes <= 0 or patch.sizeBytes >= release.sizeBytes: continue
		if chosen.is_empty() or patch.sizeBytes < chosen.sizeBytes: chosen = patch
	return chosen

func update() -> Dictionary:
	if busy: return {"ok":false}
	if release.is_empty(): return await check()
	busy = true
	changed.emit()
	var result: Dictionary = {"ok":true}
	if not downloaded:
		message = "업데이트를 다운로드하고 있습니다"
		changed.emit()
		var patch := _patch()
		result = {"ok":false}
		if not patch.is_empty() and platform.download_patch(patch.url,patch.sha256,patch.sizeBytes,release.versionCode,patch.fromSha256,release.sha256,release.sizeBytes):
			var reply: Array = await platform.update_completed
			var parsed: Variant = Json.parse(reply[1])
			if parsed is Dictionary: result = parsed
		if not result.get("ok",false):
			if platform.download_update(release.apkUrl,release.sha256,release.sizeBytes,release.versionCode):
				var reply: Array = await platform.update_completed
				var parsed: Variant = Json.parse(reply[1])
				result = parsed if parsed is Dictionary else {"ok":false}
		downloaded = result.get("ok",false)
	if downloaded:
		if platform.install_update(release.versionCode):
			var reply: Array = await platform.update_completed
			var parsed: Variant = Json.parse(reply[1])
			result = parsed if parsed is Dictionary else {"ok":false}
			message = "설치 권한을 허용한 뒤 업데이트하기를 다시 눌러 주세요" if result.get("value") == "permissionRequired" else "설치를 완료해 주세요"
		else: result = {"ok":false}
	if not result.get("ok",false):
		downloaded = false
		message = "업데이트하지 못했습니다. 다시 시도해 주세요."
	busy = false
	changed.emit()
	return result
