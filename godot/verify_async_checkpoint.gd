extends "res://verify_run_transition.gd"
## Real Thread + repository regression. Semaphores make pending writes
## deterministic without timing the filesystem or touching installed-app data.
const Worker = preload("res://app/checkpoint_worker.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
class Gate extends RefCounted:
	var entered := Semaphore.new()
	var release := Semaphore.new()
	var calls := 0
	var blocking := true
	func stop() -> void:
		calls += 1
		if not blocking: return
		entered.post()
		release.wait()
class Reader extends RefCounted:
	var entered := Semaphore.new()
	var thread := Thread.new()
	var store
	var saved: Dictionary = {}
	func _init(repository) -> void: store = repository
	func read() -> void:
		entered.post()
		saved = store.load_save()

func request_for(app, generation: int = 7) -> Dictionary:
	var request: Dictionary = app.checkpoint.capture_state(app, app.run_domain.state)
	request.generation = generation
	return request

func worker_for(app, target: String, gate = null):
	return Worker.new(app.catalog._data.duplicate(true), app.run_domain.growth.data.duplicate(true),
		target, "guest", Callable() if gate == null else gate.stop)

func capture_ownership() -> void:
	var app = create_app("capture")
	check(await app.start_stage(0), "capture stage")
	app.checkpoint.preferences.selectedStageNumber = 1
	var request := request_for(app)
	var before := var_to_str(request)
	app.run_domain.state.gold += 17
	app.run_domain.state.progression.dailyQuestProgress["clearWaves"] = 93
	app.checkpoint.preferences.selectedStageNumber = 2
	app.scene.combat_runtime.session.speed = 4.0
	check(var_to_str(request) == before, "capture detaches domain/preferences/runtime nested data")
	check(app.checkpoint.commit_capture(request, app.catalog, app.run_domain.growth) == OK,
		"owned capture commits synchronously")
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(saved.activeRun.gold == request.state.gold and saved.preferences.selectedStageNumber == 1,
		"synchronous durable commit uses captured values")
	free_app(app)

func worker_ordering() -> void:
	var app = create_app("worker-source")
	check(await app.start_stage(0), "worker stage")
	var path := directory.path_join("worker")
	var main_store = Store.new(path, Slot.guest())
	var gate := Gate.new()
	var worker = worker_for(app, path, gate)
	var first := request_for(app)
	first.state.gold = 101
	var accepted: Dictionary = worker.submit(first)
	check(accepted.error == OK and accepted.sequence == 1, "request accepted")
	gate.entered.wait()
	check(worker.pending_count() == 1 and worker.take_completions().is_empty(),
		"acceptance precedes durable completion")
	var second := request_for(app)
	second.state.gold = 202
	check(worker.submit(second).sequence == 2, "later request accepted while IO pending")
	check(worker.pending_count() == 2, "both requests retained in FIFO")
	var unrelated = Store.new(directory.path_join("other-slot"), Slot.guest())
	check(unrelated.load_save() == null and unrelated.last_error == OK,
		"different slot remains independently readable")
	var reader := Reader.new(Store.new(path, Slot.guest()))
	check(reader.thread.start(reader.read) == OK, "same-slot reader thread starts")
	reader.entered.wait()
	gate.release.post()
	gate.entered.wait()
	gate.release.post()
	var completed: Array = worker.flush()
	reader.thread.wait_to_finish()
	check(completed.size() == 2, "flush returns every completion")
	if completed.size() == 2:
		check(completed[0].sequence == 1 and completed[1].sequence == 2,
			"completion sequence FIFO")
		check(completed[0].error == OK and completed[1].error == OK and completed[1].durable,
			"worker conversion validation and atomic IO succeed")
		check(completed[1].generation == 7, "completion retains generation")
	check(reader.saved.get("activeRun", {}).get("gold") == 202,
		"separate repository cannot read before accepted writes")
	check(main_store._validation_memo == worker._store._validation_memo and main_store._validation_memo.matches(FileAccess.get_file_as_string(main_store.primary_path)),
		"real worker shares successfully validated bytes with the main repository")
	check(worker.pending_count() == 0 and worker.shutdown().is_empty(), "shutdown joins drained worker")
	check(worker.submit(second).error != OK, "closed worker rejects further requests")
	free_app(app)

func worker_coalescing() -> void:
	var app = create_app("coalesce-source")
	check(await app.start_stage(0), "coalesce stage")
	var path := directory.path_join("coalesce")
	var gate := Gate.new()
	var worker = worker_for(app, path, gate)
	var first := request_for(app)
	first.state.gold = 100
	check(worker.submit(first).error == OK, "coalesce first request accepted")
	gate.entered.wait()
	gate.blocking = false
	for gold in [200, 300, 400]:
		var queued := request_for(app)
		queued.state.gold = gold
		check(worker.submit(queued).error == OK, "queued request accepted " + str(gold))
	gate.release.post()
	var completed: Array = worker.flush()
	check(completed.map(func(v): return v.sequence) == [1, 2, 3, 4], "every coalesced request completes once in order")
	check(completed.all(func(v): return v.error == OK and v.durable), "coalesced requests report the covering write")
	check(gate.calls == 2, "queued snapshots are converted and written once")
	check(Store.new(path, Slot.guest()).load_save().activeRun.gold == 400, "latest queued snapshot is persisted")
	check(worker.submit(request_for(app)).error == OK and worker.flush().size() == 1, "skipped tickets are released")
	worker.shutdown()
	free_app(app)

func worker_failure() -> void:
	var app = create_app("failure-source")
	check(await app.start_stage(0), "failure stage")
	var path := directory.path_join("invalid-directory")
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "failure fixture")
	file.store_string("directory blocked")
	file.close()
	var worker = worker_for(app, path)
	check(worker.submit(request_for(app)).error == OK, "IO failure remains distinct from acceptance")
	var completed: Array = worker.flush()
	check(completed.size() == 1 and completed[0].error != OK and not completed[0].durable,
		"actual write failure reported with no durable success")
	worker.shutdown()
	var invalid := request_for(app)
	invalid.state = {}
	worker = worker_for(app, directory.path_join("validation"))
	check(worker.submit(invalid).error == OK, "validation runs on worker")
	completed = worker.flush()
	check(completed.size() == 1 and completed[0].error != OK, "invalid capture fails")
	check(worker.submit(request_for(app)).error == OK, "failure releases slot ticket")
	completed = worker.flush()
	check(completed.size() == 1 and completed[0].error == OK, "later valid request drains after failure")
	worker.shutdown()
	free_app(app)

func lifecycle_requests() -> void:
	var app = create_app("lifecycle")
	check(await app.start_stage(0), "lifecycle stage")
	var gate := Gate.new()
	app.checkpoint.enable_worker(app, gate.stop)
	app.run_domain.state.gold = 500
	check(app.request_checkpoint(), "lifecycle accepts ordinary request")
	gate.entered.wait()
	app.run_domain.state.gold = 600
	check(app.request_checkpoint(), "second ordinary request does not wait for first IO")
	check(not app.save_failed and app.checkpoint.last_durable_sequence == 0,
		"pending acceptance is not durable success or failure")
	gate.release.post()
	gate.entered.wait()
	gate.release.post()
	check(app.pause_and_save(), "background boundary drains then durably saves")
	check(app.checkpoint.pending_count() == 0 and app.checkpoint.store.load_save().activeRun.gold == 600,
		"background boundary preserves latest state")
	check(app.scene.combat_runtime.session.paused, "background boundary pauses runtime")
	check(app.checkpoint.shutdown() == OK, "lifecycle shutdown drains")
	free_app(app)

func lifecycle_failure() -> void:
	var app = create_app("lifecycle-failure")
	check(await app.start_stage(0), "failure lifecycle stage")
	app.checkpoint.enable_worker(app)
	var blocked: String = app.checkpoint.store.primary_path + ".tmp"
	check(DirAccess.make_dir_absolute(blocked) == OK, "block real atomic save temporary path")
	app.run_domain.state.gold += 50
	check(app.request_checkpoint(), "failed write initially accepted")
	while app.checkpoint.pending_count() > 0: await process_frame
	app._poll_checkpoint_completions()
	check(app.save_failed and app.scene.combat_runtime.session.paused,
		"main completion poll exposes failure and pauses simulation")
	check(app.checkpoint.flush_pending() != OK, "durable barrier retains earlier error")
	check(DirAccess.remove_absolute(blocked) == OK, "repair atomic temporary path")
	check(app.checkpoint.request_session(app) == OK, "later valid request accepted")
	while app.checkpoint.pending_count() > 0: await process_frame
	app._poll_checkpoint_completions()
	check(app.save_failed and app.checkpoint.flush_pending() != OK,
		"later async success cannot conceal earlier failure")
	check(app.persist_progression() and not app.save_failed and app.checkpoint.flush_pending() == OK,
		"explicit durable retry clears failure after saving current state")
	check(app.checkpoint.store.load_save().activeRun.gold == app.run_domain.state.gold,
		"retry persisted latest gold")
	app.checkpoint.shutdown()
	free_app(app)

func research_completion() -> void:
	var app = create_app("research")
	check(await app.start_stage(0), "research stage")
	var gate := Gate.new()
	app.checkpoint.enable_worker(app, gate.stop)
	var now := int(Time.get_unix_time_from_system() * 1000)
	var pending := {"type":"researchCostEfficiency", "targetLevel":1,
		"startedAtMillis":now, "durationMillis":3600000, "initialElapsedMillis":0}
	app.run_domain.state.progression.activeResearches = [pending]
	check(app._due_research_millis(app.run_domain.state.progression) < 0, "unfinished research is not due")
	var finished := pending.duplicate()
	finished.startedAtMillis = now - 2000
	finished.durationMillis = 1000
	# A replaced list is detected without waiting for the previous deadline.
	app.run_domain.state.progression.activeResearches = [finished]
	check(app._due_research_millis(app.run_domain.state.progression) >= 0, "replaced list recomputes deadline")
	check(app._due_research_millis(app.run_domain.state.progression) < 0, "unreplaced due list waits before retry")
	app.run_domain.state.progression.activeResearches = [finished.duplicate()]
	check(app.checkpoint.persist_state(app, app.run_domain.state) == OK, "active research saved")
	app._process(0.0)
	gate.entered.wait()
	check(app.checkpoint.last_durable_sequence == 0 and app.checkpoint.pending_count() == 1,
		"completion is handed to the background worker")
	check(int(app.run_domain.state.progression.researchLevels.get("researchCostEfficiency", 0)) == 1
		and app.run_domain.state.progression.activeResearches.is_empty()
		and int(app.progression_inputs.researchLevels.get("researchCostEfficiency", 0)) == 1,
		"finished research applies before durable completion")
	gate.release.post()
	check(app.checkpoint.flush_pending() == OK and not app.save_failed, "background research save succeeds")
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(int(saved.progression.researchLevels.get("researchCostEfficiency", 0)) == 1
		and saved.progression.activeResearches.is_empty(), "saved progression includes finished research")
	check(app.checkpoint.shutdown() == OK, "research shutdown drains")
	free_app(app)

func run() -> void:
	directory = OS.get_environment("TMPDIR").path_join("rune-async-checkpoint-" + str(OS.get_process_id()))
	check(directory.is_absolute_path(), "isolated async save root")
	await capture_ownership()
	await worker_ordering()
	await worker_coalescing()
	await worker_failure()
	await lifecycle_requests()
	await lifecycle_failure()
	await research_completion()
	print("ASYNC_CHECKPOINT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
