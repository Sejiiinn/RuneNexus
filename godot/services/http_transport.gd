extends Node
## One HTTPRequest per operation; auth serialization is owned by AccountSession.
const SaveJson = preload("res://app/save_json.gd")
var timeout_seconds: float = 20.0

static func supports_base_url(value: String) -> bool:
	var match_result = RegEx.create_from_string("^(https?)://([^/?#]+)(/[^?#]*)?$").search(value.strip_edges().trim_suffix("/"))
	if match_result == null or "@" in match_result.get_string(2): return false
	var authority: String = match_result.get_string(2)
	if match_result.get_string(1) == "https": return not authority.is_empty()
	return RegEx.create_from_string("^(localhost|127\\.0\\.0\\.1|\\[::1\\])(:[0-9]+)?$").search(authority) != null

func request(method: int, url: String, body: String = "", headers: Dictionary = {}) -> Dictionary:
	var client := HTTPRequest.new()
	client.timeout = timeout_seconds
	client.max_redirects = 0 # Never forward bearer tokens across redirects.
	add_child(client)
	var wire := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	for key in headers:
		if "\r" in str(key) or "\n" in str(key) or "\r" in str(headers[key]) or "\n" in str(headers[key]):
			client.queue_free()
			return failure("INVALID_HTTP_HEADER")
		wire.append(str(key) + ": " + str(headers[key]))
	var error := client.request(url, wire, method, body)
	if error != OK:
		client.queue_free()
		return failure("NETWORK_UNAVAILABLE", 0, true)
	var response: Array = await client.request_completed
	client.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS: return failure("NETWORK_UNAVAILABLE", 0, true)
	var status := int(response[1])
	var raw: String = response[3].get_string_from_utf8()
	var value: Variant = SaveJson.parse(raw) if not raw.is_empty() else {}
	var decoded: Dictionary = value if value is Dictionary else {}
	var result := {"ok": status >= 200 and status < 300, "status": status, "body": decoded, "raw": raw, "raw_body": raw, "code": str(decoded.get("code", "")), "retryable": status in [408, 429] or status >= 500, "headers": {}}
	for line in response[2]:
		var colon: int = line.find(":")
		if colon > 0: result.headers[line.substr(0, colon).to_lower()] = line.substr(colon + 1).strip_edges()
	result["retryAfter"] = maxi(0, str(result.headers.get("retry-after", "0")).to_int())
	if status == 426: result.code = "CLIENT_UPDATE_REQUIRED"
	return result

static func failure(code: String, status: int = 0, retryable: bool = false) -> Dictionary:
	return {"ok": false, "code": code, "status": status, "body": {}, "retryable": retryable, "retryAfter": 0}

static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

static func valid_uuid(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").search(value) != null
