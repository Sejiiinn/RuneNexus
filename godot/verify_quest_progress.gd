extends SceneTree
const QuestProgress = preload("res://app/quest_progress.gd")
const Json = preload("res://app/save_json.gd")

func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://../test/fixtures/quest_progress_cases.json")
	var fixture: Dictionary = Json.parse_record(FileAccess.get_file_as_string(path)).value
	var rules := QuestProgress.new()
	var errors: Array = []
	for test in fixture.cases:
		var action: Dictionary = test.action
		var actual: Dictionary
		match action.kind:
			"refresh": actual = rules.refresh(test.before, int(action.now))
			"record": actual = rules.record(test.before, action.type, int(action.amount), int(action.now))
			"playTime": actual = rules.record_play_time(test.before, float(action.seconds))
			"finish": actual = rules.finish(test.before, action.event)
			"receipt": actual = rules.apply_receipt(test.before, action.receipt).progression
		for key in test.after:
			if actual.get(key) != test.after[key]:
				errors.append("%s: %s expected=%s actual=%s" % [test.name, key, str(test.after[key]), str(actual.get(key))])
	if not errors.is_empty():
		for error in errors: printerr(error)
		quit(1)
		return
	print("quest progression Dart parity PASS: %d cases" % fixture.cases.size())
	quit(0)
