extends SceneTree
## Exercise the actual design preview's status and capture trace with native rows.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> void:
	var preview = load("res://previews/chapter1_expansion/preview.tscn").instantiate()
	root.add_child(preview)
	preview.set_process(false)
	# Enable trace recording without starting the screenshot capture coroutine.
	preview.capture_mode = true
	for stage in ["1-7", "1-10"]:
		preview.stage = stage
		preview._load_map()
		check(preview.ready_for_capture, stage + " initialized")
		check(not preview.status.text.is_empty(), stage + " status updated")
		preview._session({"paused": false})
		for step in range(1200):
			preview.runtime.advance_session(1.0 / 24.0)
			preview._present()
			if bool(preview.runtime.enemies["1"].arrived): break
		check(bool(preview.runtime.enemies["1"].arrived), stage + " arrived")
		check(preview.report.teleports.size() == preview.map.teleportPairs.size(), stage + " all teleports reported")
		check(preview.report.blocked_cell_violations.is_empty(), stage + " avoids blocked cells")
		check(preview.report.render_root_mismatches.is_empty(), stage + " render follows native position")
		check(preview.trace.size() > 1, stage + " capture trace recorded")
		if preview.trace.size() > 1:
			check(preview.trace[-1].time > preview.trace[0].time, stage + " trace advances")
			check(int(preview.trace[-1].serial) == preview.map.teleportPairs.size(), stage + " trace reaches final teleport")
		check(preview.status.text.contains("순간이동 %d/%d회" % [preview.map.teleportPairs.size(), preview.map.teleportPairs.size()]), stage + " status reaches final teleport")
	preview.free()
	print("CHAPTER_ONE_EXPANSION_PREVIEW failures=", failures)
	quit(0 if failures.is_empty() else 1)
