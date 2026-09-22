extends SceneTree
const RewardSnapshot = preload("res://app/reward_snapshot.gd")
const Json = preload("res://app/save_json.gd")
func _initialize() -> void:
	var fixture: Dictionary = Json.parse_record(FileAccess.get_file_as_string("res://../test/fixtures/reward_snapshot_cases.json")).value
	var rules := RewardSnapshot.new()
	for test in fixture.cases:
		var actual := rules.apply_authoritative(test.before, test.snapshot)
		if actual != test.after:
			printerr("snapshot mismatch: ", rules.error)
			for key in test.after:
				if actual.get(key) != test.after[key]: printerr(key, " expected=", test.after[key], " actual=", actual.get(key))
			quit(1)
			return
	var bad: Dictionary = fixture.cases[0].snapshot.duplicate(true)
	bad.turretModules.items[0].grade = "unknown"
	assert(rules.apply_authoritative(fixture.cases[0].before, bad).is_empty())
	assert(not rules.error.is_empty())
	print("authoritative snapshot Dart parity PASS: %d cases + malformed rejection" % fixture.cases.size())
	quit(0)
