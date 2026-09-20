extends RefCounted
## Godot JSON parses all number literals as doubles. Preserve signed int64 save
## counters/timestamps exactly; escaped strings and floating literals stay JSON.
static func parse_record(raw: String) -> Dictionary:
	var original := JSON.new()
	if original.parse(raw) != OK:
		return {"ok": false, "value": null, "error": original.get_error_message()}
	var prefix := "__rune_save_int__"
	while _contains_prefix(original.data, prefix): prefix += "_"
	var integers: Dictionary = {}
	var pieces := PackedStringArray()
	var pattern := RegEx.create_from_string("^-?(0|[1-9][0-9]*)$")
	var number_pattern := RegEx.create_from_string("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$")
	var index := 0
	var quoted := false
	while index < raw.length():
		var ch := raw[index]
		if quoted:
			if ch.unicode_at(0) < 32:
				return {"ok": false, "value": null, "error": "Unescaped control character"}
			pieces.append(ch)
			index += 1
			if ch == "\\" and index < raw.length():
				pieces.append(raw[index])
				index += 1
			elif ch == '"': quoted = false
			continue
		if ch == '"':
			quoted = true
			pieces.append(ch)
			index += 1
			continue
		if ch in ["-", "+", "."] or (ch >= "0" and ch <= "9"):
			var start := index
			while index < raw.length() and not raw[index] in [",", "]", "}", " ", "\t", "\n", "\r"]:
				index += 1
			var token := raw.substr(start, index - start)
			if number_pattern.search(token) == null:
				return {"ok": false, "value": null, "error": "Invalid JSON number"}
			if pattern.search(token) != null:
				var magnitude := token.trim_prefix("-")
				var limit := "9223372036854775808" if token.begins_with("-") else "9223372036854775807"
				if magnitude.length() > limit.length() or (magnitude.length() == limit.length() and magnitude > limit):
					return {"ok": false, "value": null, "error": "Integer exceeds signed int64"}
				var marker := prefix + str(integers.size())
				integers[marker] = token.to_int()
				pieces.append(JSON.stringify(marker))
			else:
				pieces.append(token)
			continue
		if ch == ",":
			var next := index + 1
			while next < raw.length() and raw[next] in [" ", "\t", "\n", "\r"]: next += 1
			if next < raw.length() and raw[next] in ["]", "}"]:
				return {"ok": false, "value": null, "error": "Trailing comma"}
		pieces.append(ch)
		index += 1
	var parser := JSON.new()
	if parser.parse("".join(pieces)) != OK:
		return {"ok": false, "value": null, "error": parser.get_error_message()}
	var restored: Variant = _restore(parser.data, integers)
	if not is_json_value(restored):
		return {"ok": false, "value": null, "error": "Non-finite or unsupported JSON value"}
	return {"ok": true, "value": restored, "error": ""}

# Match Dart JSON's refusal to silently replace NaN or stringify engine objects.
# A depth bound also rejects cyclic runtime containers before any file changes.
static func is_json_value(value: Variant, depth: int = 0) -> bool:
	if depth > 128: return false
	if value == null or value is bool or value is int or value is String: return true
	if value is float: return is_finite(value)
	if value is Array:
		for child in value:
			if not is_json_value(child, depth + 1): return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not is_json_value(value[key], depth + 1): return false
		return true
	return false

static func parse(raw: String) -> Variant:
	return parse_record(raw).value

static func _contains_prefix(value: Variant, prefix: String) -> bool:
	if value is String: return value.begins_with(prefix)
	if value is Array:
		for child in value:
			if _contains_prefix(child, prefix): return true
	elif value is Dictionary:
		for child in value.values():
			if _contains_prefix(child, prefix): return true
	return false

static func _restore(value: Variant, integers: Dictionary) -> Variant:
	if value is String: return integers.get(value, value)
	if value is Array:
		for index in range(value.size()): value[index] = _restore(value[index], integers)
	elif value is Dictionary:
		for key in value: value[key] = _restore(value[key], integers)
	return value
