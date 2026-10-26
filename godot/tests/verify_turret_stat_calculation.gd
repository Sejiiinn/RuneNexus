extends SceneTree
## Fixed pre-migration turret stat outputs (282) and critical-chance boundaries (36).
## See test/fixtures/turret_stat_calculation.provenance.md for the capture contract.
const Calculation = preload("res://combat/turret_stat_calculation.gd")
const Compare = preload("res://tests/verify_support_fixture_compare.gd")

func _initialize() -> void:
	var compare := Compare.new()
	var cases := 0
	for path in ["turret_stat_calculation.json", "turret_stat_critical_boundaries.json"]:
		var fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/" + path))
		if not fixtures is Array or fixtures.is_empty():
			compare.failures.append(path + " missing")
			continue
		cases += fixtures.size()
		for fixture: Dictionary in fixtures:
			var actual := Calculation.resolve(fixture.input)
			compare.matches(actual, fixture.expected, fixture.name)
			# Frozen migration fixtures predate piercing. Explicitly verify the new
			# default rather than changing captured expectations or silently skipping it.
			if not fixture.expected.has("pierceCount"):
				compare.matches(actual.get("pierceCount", -1), 0, fixture.name + "/pierceCount extension")
			if not fixture.expected.snapshot.has("pierceCount"):
				compare.matches(actual.snapshot.get("pierceCount", -1), 0, fixture.name + "/snapshot/pierceCount extension")
	print(JSON.stringify({"cases": cases, "checks": compare.checks, "failures": compare.failures}))
	quit(0 if compare.failures.is_empty() else 1)
