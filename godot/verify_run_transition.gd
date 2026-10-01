extends SceneTree
## Real app/session/combat/save paths; rendering is replaced by a minimal host.
const App = preload("res://app/app_lifecycle.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
class Host extends Node3D:
	var _native_combat = preload("res://combat/native_combat_runtime.gd").new()
	var _native_combat_base_frame: Dictionary = {}
	func _apply_frame(frame: Dictionary) -> void:
		if frame.get("reset", false): _native_combat.active = false
var failures: Array = []
var checks := 0
var directory := ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func create_app(slot: String, owner: String = "guest"):
	# Not added to the tree: retain every lifecycle method without booting UI/services.
	var app = App.new()
	app.scene = Host.new()
	app.checkpoint = Checkpoint.new(directory.path_join(slot), owner)
	app.checkpoint.allow_progression_only = true
	app.run_domain.now_millis = func(): return 1700000000000
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog(), slot + " catalog")
	check(app.retry_load(), slot + " startup")
	return app

func free_app(app) -> void:
	app.scene.free()
	app.free()

func same_schedule(left: Dictionary, right: Dictionary) -> bool:
	for key in ["id", "active", "completed"]:
		if left[key] != right[key]: return false
	if left.spawnQueue.size() != right.spawnQueue.size(): return false
	for i in range(left.spawnQueue.size()):
		if left.spawnQueue[i].enemyType != right.spawnQueue[i].enemyType: return false
		# v2 JSON delays roundtrip decimal values, not identical float bits.
		if not is_equal_approx(float(left.spawnQueue[i].delay), float(right.spawnQueue[i].delay)): return false
	return true

func start_pending_wave(app, label: String) -> void:
	check(app.start_stage(0), label + " start")
	# One completed round gives abandonment a nonzero progression reward. The
	# second round still uses the production catalog/bootstrap/spawn schedule.
	app.next_round = 1
	app.run_domain.state.roundIndex = 1
	app.run_domain.state.completedRounds = 1
	app.run_domain.state.pendingEconomyDiamonds = 5
	app.start_wave()
	check(app.run_domain.state.phase == "wave" and app.scene._native_combat.wave.active,
		label + " active wave")
	check(not app.scene._native_combat.wave.snapshot().spawnQueue.is_empty(), label + " pending spawn")

func successful_abandon() -> void:
	var app = create_app("success")
	start_pending_wave(app, "abandon")
	var identity: String = app.run_domain.state.economyRunId
	var quest_before: int = int(app.run_domain.state.progression.get("dailyQuestProgress", {}).get("clearWaves", 0))
	check(app.abandon_run(), "pending-wave abandon returns to stage menu")
	var runtime = app.scene._native_combat
	check(app.in_lobby and not app.save_failed and app.run_domain.state.phase == "failure",
		"abandon leaves a savable terminal session")
	check(not runtime.wave.active and runtime.wave.queue.is_empty() and not runtime.running,
		"durable abandon cancels live pending spawns")
	check(runtime.session.phase == "failure" and runtime.session.paused, "live terminal phase paused")
	check(runtime.events.is_empty() and int(app.run_domain.state.progression.get("dailyQuestProgress", {}).get("clearWaves", 0)) == quest_before,
		"cancellation does not invent wave completion")
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(saved.activeRun.phase == "failure" and saved.activeRun.spawnQueue.is_empty(), "terminal v2 has no pending spawns")
	var rewarded: Dictionary = app.run_domain.state.progression.duplicate(true)
	check(int(rewarded.lastRunRuneReward) > 0, "abandon applies completed-round rewards")
	var queue = app.checkpoint.rewards()
	check(queue.state.pendingRewards.size() == 1 and queue.state.pendingRewards[0].runId == identity and queue.state.pendingRewards[0].pendingDiamonds == 5,
		"durable abandoned reward retained")
	for repeat in range(3):
		check(app.prepare_run_transition() and app.persist_progression(), "repeat terminal save " + str(repeat))
	check(app.run_domain.state.progression == rewarded and queue.state.pendingRewards.size() == 1,
		"repeat terminal save does not duplicate rewards")
	check(app.start_stage(0), "new stage starts without app restart")
	check(app.run_domain.state.economyRunId != identity and app.run_domain.state.phase == "preparation" and not app.in_lobby and not app.save_failed,
		"new run playable after abandon")
	check(queue.state.pendingRewards.size() == 1, "replacement retains single abandoned reward")
	free_app(app)

func failed_abandon(outbox_failure: bool) -> void:
	var label := "outbox" if outbox_failure else "checkpoint"
	var app = create_app(label)
	start_pending_wave(app, label)
	var queue = app.checkpoint.rewards()
	var before: Dictionary = app.run_domain.state.duplicate(true)
	var schedule: Dictionary = app.scene._native_combat.wave.snapshot()
	var epoch: int = app.epoch
	var failing_store = queue if outbox_failure else app.checkpoint.store
	failing_store._valid_slot = false
	check(not app.abandon_run(), label + " failure blocks abandon")
	check(app.save_failed and not app.in_lobby and app.epoch == epoch and app.run_domain.state == before,
		label + " failure preserves live run and progression")
	check(app.scene._native_combat.wave.snapshot() == schedule and app.scene._native_combat.session.paused,
		label + " failure preserves pending spawn schedule and pauses")
	check(queue.state.get("pendingRewards", []).is_empty(), label + " failure does not expose reward")
	check(not app.start_stage(0) and app.epoch == epoch and app.scene._native_combat.wave.snapshot() == schedule,
		label + " failure blocks replacement without clearing queue")
	failing_store._valid_slot = true
	free_app(app)
	app = create_app(label)
	queue = app.checkpoint.rewards()
	check(app.run_domain.state.phase == "wave", label + " failed transition restart restores wave")
	check(same_schedule(app.scene._native_combat.wave.snapshot(), schedule), label + " failed transition restart restores queue")
	check(app.run_domain.state.progression == before.progression, label + " failed transition restart restores progression")
	check(queue.state.pendingRewards.is_empty(), label + " failed transition restart has no premature reward")
	check(app.resume_run(), label + " failed transition restart resumes")
	check(app.abandon_run() and not app.save_failed, label + " recovered abandon succeeds")
	check(app.scene._native_combat.wave.queue.is_empty() and queue.state.pendingRewards.size() == 1,
		label + " recovery cancels and rewards exactly once")
	check(app.start_stage(0), label + " recovery permits reentry")
	check(queue.state.pendingRewards.size() == 1, label + " recovery retains one reward")
	free_app(app)

func save_and_resume() -> void:
	var app = create_app("resume")
	start_pending_wave(app, "resume")
	var identity: String = app.run_domain.state.economyRunId
	var schedule: Dictionary = app.scene._native_combat.wave.snapshot()
	check(app.open_stage_menu_destination(), "save and leave succeeds")
	check(not app.run_domain.is_finished() and app.scene._native_combat.wave.snapshot() == schedule,
		"save and leave preserves active spawn schedule")
	check(app.checkpoint.rewards().state.pendingRewards.is_empty(), "resumable leave awards nothing")
	check(app.resume_run() and not app.in_lobby and app.scene._native_combat.session.paused,
		"same-process continue opens existing battle paused")
	check(app.run_domain.state.economyRunId == identity and app.scene._native_combat.wave.snapshot() == schedule,
		"same-process continue retains run and pending spawns")
	check(app.open_stage_menu_destination(), "saved wave returns to menu before restart")
	free_app(app)
	app = create_app("resume")
	check(app.run_domain.state.economyRunId == identity and app.run_domain.state.phase == "wave" and app.in_lobby,
		"saved wave restored with same run identity")
	var restored: Dictionary = app.scene._native_combat.wave.snapshot()
	check(same_schedule(restored, schedule), "saved wave restores all pending spawns")
	check(app.resume_run() and not app.in_lobby and app.scene._native_combat.session.paused,
		"continue opens existing battle paused")
	check(app.checkpoint.rewards().state.pendingRewards.is_empty(), "continue does not finish or enqueue")
	free_app(app)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "--journal-crash":
		crash_child(args)
		return
	directory = OS.get_environment("TMPDIR").path_join("rune-run-transition-" + str(OS.get_process_id()))
	check(directory.is_absolute_path(), "isolated save root")
	successful_abandon()
	failed_abandon(false)
	failed_abandon(true)
	save_and_resume()
	crash_boundaries()
	journal_failures()
	journal_read_and_isolation()
	print("RUN_TRANSITION failures=", failures, " checks=", checks)
	quit(0 if failures.is_empty() else 1)

class FaultJournal extends "res://app/run_transition_journal.gd":
	var fail_decision := ""
	var fail_cleanup := false
	func _install_temporary(path: String) -> Error:
		var pending: Dictionary = SaveJson.parse(FileAccess.get_file_as_string(path))
		if pending.status == fail_decision: return _fail(ERR_FILE_CANT_WRITE, "Injected decision write failure")
		return super._install_temporary(path)
	func remove_record() -> Error:
		if fail_cleanup: return _fail(ERR_FILE_CANT_WRITE, "Injected journal cleanup failure")
		return super.remove_record()

func transition_record(app) -> Dictionary:
	var previous: Dictionary = app.run_domain.state.duplicate(true)
	var snapshot: Dictionary = app.scene._native_combat.snapshot()
	var adapter = Checkpoint.ContentSave.new(app.catalog, app.run_domain.growth)
	var before: Dictionary = adapter.capture(previous, snapshot, 1700000000000, app.checkpoint.preferences)
	app.run_domain.finish(false)
	app.run_domain.state.phase = "failure"
	snapshot.session.phase = "failure"
	snapshot.wave.spawnQueue = []
	var after: Dictionary = adapter.capture(app.run_domain.state, snapshot, 1700000000000, app.checkpoint.preferences)
	app.run_domain.state = previous
	var queue = app.checkpoint.rewards()
	var next: Dictionary = queue.state.duplicate(true)
	next.pendingRewards.append(app.checkpoint._saved_reward(after))
	return {"version":1,"owner":app.checkpoint.owner,"status":"prepared","beforeSave":before,
		"afterSave":after,"beforeOutbox":queue.state.duplicate(true),"afterOutbox":next}

func put(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "", false, true))
	file.flush()
	file.close()

func same_save(left: Variant, right: Dictionary) -> bool:
	if not left is Dictionary: return false
	# Canonical JSON preserves doubles to decimal precision; compare wave delays
	# approximately as the production continuation tests do above.
	var a: Dictionary = left.duplicate(true)
	var b: Dictionary = right.duplicate(true)
	if a.activeRun is Dictionary and b.activeRun is Dictionary:
		if a.activeRun.spawnQueue.size() != b.activeRun.spawnQueue.size(): return false
		for i in range(a.activeRun.spawnQueue.size()):
			if not is_equal_approx(a.activeRun.spawnQueue[i].delay, b.activeRun.spawnQueue[i].delay): return false
			a.activeRun.spawnQueue[i].delay = b.activeRun.spawnQueue[i].delay
	return a == b

func crash_child(args: PackedStringArray) -> void:
	var base: String = args[1]
	var point: String = args[2]
	var owner: String = args[3]
	var record: Dictionary = Checkpoint.Store.SaveJson.parse(FileAccess.get_file_as_string(base.path_join("fixture.json")))
	var store = Checkpoint.Store.new(base, Checkpoint.Slot.guest() if owner == "guest" else Checkpoint.Slot.account(owner))
	var queue = Checkpoint.RewardOutbox.new(base, owner)
	store.transition_recovery_enabled = false
	queue.transition_recovery_enabled = false
	var journal = Checkpoint.TransitionJournal.new(base, owner)
	if point == "prepared-temp":
		put(journal.primary_path + ".tmp", record)
		quit(0)
		return
	if journal.write_record(record) != OK:
		quit(20)
		return
	match point:
		"prepared": pass
		"checkpoint-backup": put(store.backup_path, record.beforeSave)
		"checkpoint-temp": put(store.primary_path + ".tmp", record.afterSave)
		"checkpoint-first-partial":
			var file := FileAccess.open(store.primary_path + ".tmp", FileAccess.WRITE)
			file.store_string("{partial")
			file.close()
		"checkpoint-displaced":
			put(store.primary_path + ".tmp", record.afterSave)
			DirAccess.rename_absolute(store.primary_path, store.primary_path + ".replace")
		_:
			if store.save_save(record.afterSave) != OK:
				quit(21)
				return
			queue.load_state()
			match point:
				"checkpoint": pass
				"outbox-backup": put(queue.backup_path, record.beforeOutbox)
				"outbox-temp": put(queue.primary_path + ".tmp", record.afterOutbox)
				"outbox-first-partial":
					for path in [queue.primary_path, queue.backup_path]:
						DirAccess.remove_absolute(path)
					var file := FileAccess.open(queue.primary_path + ".tmp", FileAccess.WRITE)
					file.store_string("{partial")
					file.close()
				"outbox-displaced":
					put(queue.primary_path + ".tmp", record.afterOutbox)
					DirAccess.rename_absolute(queue.primary_path, queue.primary_path + ".replace")
				_:
					if queue.save_state(record.afterOutbox) != OK:
						quit(22)
						return
					if point != "outbox":
						var committed: Dictionary = record.duplicate(true)
						committed.status = "committed"
						if point == "commit-temp": put(journal.primary_path + ".tmp", committed)
						else:
							if journal.write_record(committed) != OK:
								quit(23)
								return
							if point == "commit-displaced": put(journal.primary_path + ".replace", record)
							if point == "cleanup": journal.remove_record()
	quit(0)

func crash_boundaries() -> void:
	var app = create_app("crash-input")
	start_pending_wave(app, "crash-input")
	var record: Dictionary = transition_record(app)
	free_app(app)
	var points := ["prepared-temp", "prepared", "checkpoint-backup", "checkpoint-temp", "checkpoint-first-partial", "checkpoint-displaced", "checkpoint", "outbox-backup", "outbox-temp", "outbox-displaced", "outbox-first-partial", "outbox", "commit-temp", "commit", "commit-displaced", "cleanup"]
	for owner in ["guest", "11111111-1111-4111-8111-111111111111"]:
		for point in points:
			var base: String = directory.path_join(owner + "-" + point)
			var fixture: Dictionary = record.duplicate(true)
			fixture.owner = owner
			fixture.beforeOutbox.accountIdBinding = owner
			fixture.afterOutbox.accountIdBinding = owner
			put(base.path_join("fixture.json"), fixture)
			var store = Checkpoint.Store.new(base, Checkpoint.Slot.guest() if owner == "guest" else Checkpoint.Slot.account(owner))
			var queue = Checkpoint.RewardOutbox.new(base, owner)
			# Deliberately retain no initial v2 file at prepared boundaries.
			if point not in ["prepared-temp", "prepared", "checkpoint-first-partial"]: check(store.save_save(fixture.beforeSave) == OK, point + " seed checkpoint")
			check(queue.load_state() == OK and queue.save_state(fixture.beforeOutbox) == OK, point + " seed outbox")
			var output: Array = []
			var result := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://verify_run_transition.gd", "--", "--journal-crash", base, point, owner], output, true)
			check(result == 0, owner + " " + point + " child writes boundary: " + str(output))
			var committed: bool = point in ["commit", "commit-displaced", "cleanup"]
			if point == "checkpoint-first-partial":
				app = create_app(owner + "-" + point, owner)
				check(app.run_domain.state.phase == "wave" and not app.startup_blocked, owner + " startup recovers partial first checkpoint")
				free_app(app)
			# Outbox-first recovery exercises its inherited guard; store-first is
			# exercised by the failure/restart lifecycle cases above.
			queue = Checkpoint.RewardOutbox.new(base, owner)
			check(queue.load_state() == OK, owner + " " + point + " queue recovery")
			var saved: Variant = store.load_save()
			check(same_save(saved, fixture.afterSave) if committed else same_save(saved, fixture.beforeSave), owner + " " + point + " durable decision")
			check(queue.state == fixture.afterOutbox if committed else queue.state == fixture.beforeOutbox, owner + " " + point + " matching queue decision")
			var journal = Checkpoint.TransitionJournal.new(base, owner)
			check(not FileAccess.file_exists(journal.primary_path), point + " recovered cleanup")
			if not committed:
				put(store.primary_path, {"invalid":true})
				check(same_save(store.load_save(), fixture.beforeSave), point + " rollback backup cannot restore abandoned terminal")
			else:
				var reward: Dictionary = fixture.afterOutbox.pendingRewards[0]
				check(queue.enqueue(reward) == OK and queue.state.pendingRewards.size() == 1, point + " reward exact once")
				var completed: Dictionary = queue.state.duplicate(true)
				completed.completedRunIds = [reward.runId]
				completed.pendingRewards = []
				check(queue.save_state(completed) == OK and queue.enqueue(reward) == OK and queue.state.pendingRewards.is_empty(), point + " claimed marker prevents reenqueue")

func journal_failures() -> void:
	for decision in ["prepared", "committed", "cleanup"]:
		var app = create_app("fault-" + decision)
		start_pending_wave(app, "fault-" + decision)
		var record: Dictionary = transition_record(app)
		var queue = app.checkpoint.rewards()
		var journal = FaultJournal.new(app.checkpoint.base_directory, "guest")
		journal.fail_decision = decision
		journal.fail_cleanup = decision == "cleanup"
		var error: Error = journal.persist(app.checkpoint.store, queue, record.beforeSave, record.afterSave, app.checkpoint._saved_reward(record.afterSave))
		check(error == OK if decision == "cleanup" else error != OK, decision + " return matches durable decision")
		var base: String = app.checkpoint.base_directory
		free_app(app)
		var store = Checkpoint.Store.new(base)
		var saved: Variant = store.load_save()
		queue = Checkpoint.RewardOutbox.new(base)
		check(queue.load_state() == OK, decision + " failure queue recovered")
		check(same_save(saved, record.afterSave) if decision == "cleanup" else same_save(saved, record.beforeSave), decision + " failure restart save")
		check(queue.state == record.afterOutbox if decision == "cleanup" else queue.state == record.beforeOutbox, decision + " failure restart queue")

class FailedRead extends RefCounted:
	func get_length() -> int: return 1
	func get_buffer(_length: int) -> PackedByteArray: return "{".to_utf8_buffer()
	func get_error() -> Error: return ERR_FILE_CANT_READ
	func close() -> void: pass

class ReadFaultJournal extends "res://app/run_transition_journal.gd":
	func _open_read(path: String):
		return FailedRead.new() if path == primary_path else super._open_read(path)

func journal_read_and_isolation() -> void:
	var app = create_app("journal-errors")
	start_pending_wave(app, "journal-errors")
	var record: Dictionary = transition_record(app)
	var base: String = app.checkpoint.base_directory
	var store = app.checkpoint.store
	var queue = app.checkpoint.rewards()
	check(store.save_save(record.beforeSave) == OK, "journal error seed")
	var journal = Checkpoint.TransitionJournal.new(base, "guest")
	var file := FileAccess.open(journal.primary_path + ".tmp", FileAccess.WRITE)
	file.store_string("{partial")
	file.close()
	check(same_save(store.load_save(), record.beforeSave) and not FileAccess.file_exists(journal.primary_path + ".tmp"), "uninstalled partial journal safely discarded")
	check(journal.write_record(record) == OK, "journal read error seed")
	var original: String = FileAccess.get_file_as_string(journal.primary_path)
	var save_raw: String = FileAccess.get_file_as_string(store.primary_path)
	var fault = ReadFaultJournal.new(base, "guest")
	check(fault.recover_transaction(store, queue) == ERR_FILE_CANT_READ, "journal read IO error blocks recovery")
	check(FileAccess.get_file_as_string(journal.primary_path) == original and FileAccess.get_file_as_string(store.primary_path) == save_raw, "journal read IO preserves source bytes")
	check(journal.remove_record() == OK, "journal read error fixture cleanup")
	var account := "11111111-1111-4111-8111-111111111111"
	var account_store = Checkpoint.Store.new(base, Checkpoint.Slot.account(account))
	var account_queue = Checkpoint.RewardOutbox.new(base, account)
	var account_journal = Checkpoint.TransitionJournal.new(base, account)
	# A foreign binding must not be accepted even when both snapshots are valid.
	put(account_journal.primary_path, record)
	check(account_store.load_save() == null and account_store.last_error == ERR_FILE_CORRUPT, "foreign journal blocks account checkpoint")
	check(account_queue.load_state() == ERR_FILE_CORRUPT and not account_queue.loaded, "foreign journal blocks account rewards")
	check(account_store.save_save(record.afterSave) == ERR_FILE_CORRUPT and not FileAccess.file_exists(account_store.primary_path), "foreign journal cannot write account checkpoint")
	check(same_save(store.load_save(), record.beforeSave), "account journal never affects guest slot")
	put(journal.primary_path, {"version":1,"invalid":true})
	check(store.load_save() == null and store.last_error == ERR_FILE_CORRUPT, "installed invalid journal blocks checkpoint")
	check(queue.load_state() == ERR_FILE_CORRUPT and not queue.loaded, "installed invalid journal blocks queue")
	check(FileAccess.get_file_as_string(store.primary_path) == save_raw, "invalid installed journal preserves checkpoint")
	free_app(app)
