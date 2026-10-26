extends SceneTree
## Fixed pre-migration damage/status expectations for attack_calculation.gd.
## Numbers match within absolute/relative 1e-10; effect order, fields and flags exactly.
const Calculation = preload("res://combat/attack_calculation.gd")
const Compare = preload("res://tests/verify_support_fixture_compare.gd")

func _initialize() -> void:
	var fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/combat_calculation.json"))
	var compare := Compare.new()
	if not fixtures is Array or fixtures.is_empty():
		compare.failures.append("combat_calculation.json missing")
	else:
		for fixture: Dictionary in fixtures:
			compare.matches(Calculation.resolve(fixture.input), fixture.expected, fixture.name)
	print(JSON.stringify({"cases": fixtures.size() if fixtures is Array else 0, "checks": compare.checks, "failures": compare.failures}))
	quit(0 if compare.failures.is_empty() else 1)
