extends SceneTree
const QuestProgress = preload("res://app/quest_progress.gd")
const Json = preload("res://app/save_json.gd")

func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://../test/fixtures/quest_progress_cases.json")
	var fixture: Dictionary = Json.parse_record(FileAccess.get_file_as_string(path)).value
	var rules := QuestProgress.new()
	var errors: Array = []
	verify_attendance_completion(rules, errors)
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
	print("quest attendance completion PASS")
	quit(0)

func verify_attendance_completion(rules, errors: Array) -> void:
	var now := 1800450000000
	for period in ["daily", "weekly"]:
		var weekly: bool = period == "weekly"
		var targets: Dictionary = QuestProgress.WEEKLY if weekly else QuestProgress.DAILY
		var base: Dictionary = rules.refresh({}, now)
		var first_day := int(base.weeklyQuestWeekKey) * 7 - 3
		base.weeklyAttendanceDayKeys = [first_day, first_day + 1, first_day + 2, first_day + 3, first_day + 4]
		var receipt := {"period":period, "rewardType":"all_complete", "rewardDiamonds":100 if weekly else 40, "rewardModuleTickets":4 if weekly else 1}
		receipt["weekKey" if weekly else "dayKey"] = base["weeklyQuestWeekKey" if weekly else "dailyQuestDayKey"]
		for missing in targets:
			var p: Dictionary = base.duplicate(true)
			p[period + "QuestProgress"] = targets.duplicate()
			p[period + "QuestProgress"][missing] = int(targets[missing]) - 1
			if QuestProgress.completed_count(p, period) != 4 or not rules.apply_receipt(p, receipt).ok:
				errors.append(period + " attendance plus any three gameplay goals qualifies: " + missing)
			p[period + "AttendanceRewardClaimed"] = true
			p["claimedWeeklyQuestRewards" if weekly else "claimedDailyQuestRewards"] = targets.keys()
			if QuestProgress.completed_count(p, period) != 4 or not rules.apply_receipt(p, receipt).ok:
				errors.append(period + " individual claims do not change eligibility")
			var accepted: Dictionary = rules.apply_receipt(p, receipt).progression
			if rules.apply_receipt(accepted, receipt).ok: errors.append(period + " duplicate summary receipt accepted")
		var two: Dictionary = base.duplicate(true)
		two[period + "QuestProgress"] = {"clearWaves":targets.clearWaves,"killEnemies":targets.killEnemies}
		if QuestProgress.completed_count(two, period) != 3 or rules.apply_receipt(two, receipt).ok:
			errors.append(period + " attendance plus two must wait")
		var all: Dictionary = base.duplicate(true)
		all[period + "QuestProgress"] = targets.duplicate()
		if QuestProgress.completed_count(all, period) != 5 or not rules.apply_receipt(all, receipt).ok:
			errors.append(period + " all five still qualify")
		all.dailyQuestClockRollbackDetected = true
		if rules.apply_receipt(all, receipt).ok: errors.append(period + " clock rollback guard lost")
		if weekly:
			for days in [[first_day,first_day+1,first_day+2,first_day+3], [first_day,first_day,first_day,first_day,first_day], [first_day-7,first_day-6,first_day-5,first_day-4,first_day-3]]:
				var p: Dictionary = base.duplicate(true)
				p.weeklyAttendanceDayKeys = days
				p.weeklyQuestProgress = targets.duplicate()
				p.weeklyQuestProgress.buyRunUpgrades = 0
				if rules.apply_receipt(p, receipt).ok: errors.append("weekly incomplete/duplicate/old attendance qualifies")
				p.weeklyQuestProgress.buyRunUpgrades = targets.buyRunUpgrades
				if not rules.apply_receipt(p, receipt).ok: errors.append("four gameplay goals without attendance rejected")
