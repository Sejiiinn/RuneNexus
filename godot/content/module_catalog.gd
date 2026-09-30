extends RefCounted
## Immutable module rules share the process lifetime, independently of snapshot
## mapper instances. growth_content.json remains the only generated source.
const Json = preload("res://app/save_json.gd")
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Dictionary = Json.parse_record(FileAccess.get_file_as_string("res://content/growth_content.json"))
		if not parsed.ok or not parsed.value is Dictionary or not parsed.value.get("module") is Dictionary:
			return {}
		_rules = parsed.value.module
		_freeze(_rules)
	return _rules

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for nested in value.values(): _freeze(nested)
		value.make_read_only()
	elif value is Array:
		for nested in value: _freeze(nested)
		value.make_read_only()
