extends RefCounted
## Fixed-expectation comparison shared by the calculation fixture checks.
## Every expected field must exist; extra actual fields are newer outputs outside the fixture.
const TOLERANCE := 1e-10
var checks := 0
var failures: Array[String] = []

func matches(actual: Variant, expected: Variant, path: String) -> void:
	checks += 1
	if expected is Dictionary:
		if not actual is Dictionary:
			_fail(path, actual, expected)
			return
		for key in expected:
			if not actual.has(key):
				failures.append("%s/%s missing" % [path, key])
			else:
				matches(actual[key], expected[key], "%s/%s" % [path, key])
	elif expected is Array:
		if not actual is Array or actual.size() != expected.size():
			_fail(path, actual, expected)
			return
		for index in expected.size():
			matches(actual[index], expected[index], "%s[%d]" % [path, index])
	elif expected is float or expected is int:
		if not (actual is float or actual is int) or absf(float(actual) - float(expected)) > TOLERANCE * maxf(1.0, absf(float(expected))):
			_fail(path, actual, expected)
	elif typeof(actual) != typeof(expected) or actual != expected:
		_fail(path, actual, expected)

func _fail(path: String, actual: Variant, expected: Variant) -> void:
	failures.append("%s actual=%s expected=%s" % [path, JSON.stringify(actual), JSON.stringify(expected)])
