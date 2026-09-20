extends SceneTree
const SaveJson = preload("res://app/save_json.gd")
const Codec = preload("res://app/save_codec.gd")

func _initialize() -> void:
	var inputs: Variant = SaveJson.parse(FileAccess.get_file_as_string("res://fixtures/godot_save_codec_inputs.json"))
	var expected: Variant = SaveJson.parse(FileAccess.get_file_as_string("res://fixtures/godot_save_codec_expected.json"))
	if not inputs is Array or not expected is Array or inputs.size() != expected.size():
		push_error("Missing save codec fixtures")
		quit(1)
		return
	var failures := 0
	for i in inputs.size():
		var actual: Variant = Codec.decode(inputs[i])
		if Codec.is_canonical_v2(inputs[i]) != expected[i].canonical or not _equal(actual, expected[i].decoded):
			failures += 1
			print("SAVE_CODEC_MISMATCH ", i, " expected=", JSON.stringify(expected[i].decoded), " actual=", JSON.stringify(actual))
		for path in expected[i].numericTypes:
			var value: Variant = actual
			for part in path.split("/", false):
				value = value[int(part)] if value is Array else value.get(part)
			var wanted: int = TYPE_INT if expected[i].numericTypes[path] == "int" else TYPE_FLOAT
			if typeof(value) != wanted:
				failures += 1
				print("SAVE_CODEC_TYPE_MISMATCH ", i, " ", path)
		if actual != null and not _equal(Codec.decode(actual), actual):
			failures += 1
			print("SAVE_CODEC_NON_IDEMPOTENT ", i)
	print("SAVE_CODEC_FIXTURES count=", inputs.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)

# Godot JSON parses every number as float; compare values recursively without
# equating booleans/strings to numbers or losing array order and null slots.
func _equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _equal(a[i], b[i]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return a == b
	return typeof(a) == typeof(b) and a == b
