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
	var failures := _integer_boundaries()
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

# These binary64 neighbours straddle the int64 boundary. Keep expected values
# as integer literals: converting INT64_MAX to float would hide off-by-one loss.
func _integer_boundaries() -> int:
	var cases := [
		[9223372036854775807, 9223372036854775807],
		[-9223372036854775807 - 1, -9223372036854775807 - 1],
		[9223372036854774784.0, 9223372036854774784],
		[-9223372036854774784.0, -9223372036854774784],
		[9223372036854775808.0, 9223372036854775807],
		[-9223372036854775808.0, -9223372036854775807 - 1],
		[9223372036854777856.0, 9223372036854775807],
		[-9223372036854777856.0, -9223372036854775807 - 1],
		[1e20, 9223372036854775807], [-1e20, -9223372036854775807 - 1],
		[1e308, 9223372036854775807], [-1e308, -9223372036854775807 - 1],
		[7.9, 7], [-7.9, -7], [-0.0, 0],
	]
	var failures := 0
	for test in cases:
		var actual: Variant = Codec._int(test[0])
		if typeof(actual) != TYPE_INT or actual != test[1]:
			failures += 1
			print("SAVE_CODEC_INT_BOUNDARY_MISMATCH input=", test[0], " expected=", test[1], " actual=", actual)
	# Check the public decoder's signed, nonnegative, nullable, map/list and
	# field-specific clamping rules still compose with saturated conversion.
	var decoded: Dictionary = Codec.decode({"version":2, "savedAtMillis":-1e20,
		"preferences":{}, "progression":{"runes":1e20,"totalPlayTimeMillis":-1e20,
			"researchLevels":{"researchEfficiency":1e20},"weeklyAttendanceDayKeys":[-1e20,1e20]},
		"turretModules":{}, "activeRun":{"phase":"wave","gold":-1e20,"pendingEconomyDiamonds":1e20}})
	var expected := [-9223372036854775807 - 1,9223372036854775807,0,9223372036854775807,
		[9223372036854775807],-9223372036854775807 - 1,1000000]
	var actual := [decoded.savedAtMillis,decoded.progression.runes,decoded.progression.totalPlayTimeMillis,
		decoded.progression.researchLevels.researchEfficiency,decoded.progression.weeklyAttendanceDayKeys,
		decoded.activeRun.gold,decoded.activeRun.pendingEconomyDiamonds]
	if actual != expected or Codec._int(null,null) != null or Codec._int("123",17) != 17 or Codec._int(true,17) != 17:
		failures += 1
		print("SAVE_CODEC_INT_RULE_MISMATCH expected=", expected, " actual=", actual)
	print("SAVE_CODEC_INT_BOUNDARIES count=",cases.size()," failures=",failures)
	return failures

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
