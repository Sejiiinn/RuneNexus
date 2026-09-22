extends SceneTree
## Run write and read in separate processes with the same isolated absolute root.
const Checkpoint = preload("res://session/session_checkpoint.gd")
const SaveJson = preload("res://app/save_json.gd")
var failures: Array = []
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["write", "read"] or not args[1].is_absolute_path():
		push_error("Expected write/read and an isolated absolute save directory")
		quit(1)
		return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = load("res://session/standalone.gd").new()
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	app.run_domain.now_millis = func(): return 1700000000000
	for phase in ["preparation", "wave", "reward", "failure", "naturalReward", "success"]:
		app.checkpoint = Checkpoint.new(args[1].path_join(phase))
		if args[0] == "write": write_phase(app, phase)
		else: read_phase(app, phase)
	if args[0] == "write": pending_settlement(app, args[1])
	else:
		rejected_loads(app, args[1])
		exit_boundaries(app, args[1])
	scene.queue_free()
	for i in range(3): await process_frame
	print("CONTENT_PROCESS_RESTART mode=", args[0], " checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func write_phase(app, phase: String) -> void:
	app.enter_stage(0)
	app.run_domain.state.gold = 10000
	app.run_domain.state.gemShards = 100
	app.run_domain.state.gemInventory = {"range":2}
	app.run_domain.state.pendingEconomyDiamonds = 17
	app.run_domain.state.progression.runes = 10000
	var family: String = app.run_domain.growth.data.module.families.arrow.core
	app.run_domain.state.progression.turretModules = {"items":[{"id":"restart-module","turretType":"arrow","part":"core","family":family,"grade":"normal","equipped":false,"options":[{"type":"damageIncrease","value":2}]}]}
	check(app.apply_growth_command({"type":"equipTurretModule","id":"restart-module"}), phase+" module equip")
	check(app.apply_growth_command({"kind":"permanentUpgrade","type":"fireTraining"}), phase+" growth purchase")
	var source: Dictionary = app.stage_source(0)
	var index: int = source.map.tiles.find("build")
	app.board_tap(Vector2i(index % int(source.map.columns), floori(float(index)/int(source.map.columns))))
	app.build_selected()
	check(app.selected_run_command("level"), phase+" level")
	check(app.selected_run_command("link"), phase+" link")
	check(app.selected_run_command("equipGem", {"type":"range","slot":1}), phase+" noncontiguous gem")
	check(app.apply_run_command({"kind":"runUpgrade","type":app.run_domain.growth.data.runUpgrades.keys()[0]}), phase+" upgrade")
	var runtime = app.scene._native_combat
	if phase in ["wave", "reward", "failure"]:
		app.start_wave()
		for i in range(210):
			runtime.advance_session(1.0/60.0)
			app.command()
		check(not runtime.enemies.is_empty() and not runtime.wave.queue.is_empty(), phase+" active enemies and queue")
	if phase == "reward": check(app.apply_run_command({"kind":"purchaseGemChoice"}), "purchase choice before restart")
	if phase == "failure":
		# Terminal-state fixture keeps real content enemy definitions and progress.
		runtime.defense.hp = 0
		runtime.defense.failed = true
		runtime.wave.cancel()
		app.run_domain.state.phase = "failure"
		app.command([], {"phase":"failure"})
	if phase in ["naturalReward", "success"]:
		var completed: int = int(app.run_domain.growth.data.rewardRounds[0]) if phase == "naturalReward" else source.waves.size()
		app.run_domain.state.roundIndex = completed-1
		app.run_domain.state.completedRounds = completed-1
		var result: Dictionary = app.run_domain.service.complete_wave(app.run_domain.state, int(source.waves[completed-1].round))
		check(result.ok, phase+" actual wave completion transaction")
		app.run_domain.state = result.state
		runtime.wave.id = int(source.waves[completed-1].round)
		app.command()
	check(app.checkpoint.save_session(app) == OK, phase+" write "+app.checkpoint.message)
	var saved = app.checkpoint.store.load_save()
	check(saved != null, phase+" persisted")
	if saved == null: return
	check(saved.activeRun.phase == ("reward" if phase == "naturalReward" else phase), phase+" saved phase")
	check(saved.activeRun.turrets[0].equippedGemSlots == [null,"range"], phase+" null slot order")
	var file := FileAccess.open(app.checkpoint.store.primary_path.get_base_dir().path_join("expected.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"save":saved,"stats":runtime.turrets.values()[0].stats}))
	file.close()

func read_phase(app, phase: String) -> void:
	var expected = SaveJson.parse(FileAccess.get_file_as_string(app.checkpoint.store.primary_path.get_base_dir().path_join("expected.json")))
	if not expected is Dictionary:
		check(false, phase+" prior process expectation missing")
		return
	check(app.checkpoint.load_session(app) == OK, phase+" load "+app.checkpoint.message)
	var runtime = app.scene._native_combat
	var run: Dictionary = expected.save.activeRun
	check(app.run_domain.state.phase == run.phase and runtime.session.phase == run.phase, phase+" restored phase")
	check(runtime.session.paused and runtime.clock == 0, phase+" restored paused")
	check(app.run_domain.state.gold == run.gold and app.run_domain.state.pendingEconomyDiamonds == 17, phase+" economy")
	check(app.run_domain.state.runUpgradeLevels == run.runUpgradeLevels and app.run_domain.state.gemInventory == run.gemInventory, phase+" inventory and upgrades")
	check(app.run_domain.state.progression.turretModules == expected.save.turretModules, phase+" modules")
	check(runtime.turrets.size() == 1, phase+" turret count")
	if runtime.turrets.is_empty(): return
	check(equivalent(runtime.turrets.values()[0].stats, expected.stats), phase+" derived stats")
	check(runtime.enemies.size() == run.enemies.size(), phase+" enemy count")
	check(equivalent(runtime.wave.snapshot().spawnQueue, run.spawnQueue), phase+" queue")
	for i in range(mini(runtime.enemies.size(), run.enemies.size())):
		var enemy: Dictionary = runtime.snapshot().enemies[i]
		check(is_equal_approx(enemy.hp, run.enemies[i].hp) and is_equal_approx(enemy.distanceTravelled * 48.0, run.enemies[i].distanceTravelled), phase+" enemy HP/progress")
	for repetition in range(3):
		app.command()
		check(app.checkpoint.save_session(app) == OK, phase+" repeated save")
		var again = app.checkpoint.store.load_save()
		check(equivalent(again.activeRun, run), phase+" exact active run roundtrip")
		check(again.progression == expected.save.progression and again.turretModules == expected.save.turretModules, phase+" growth roundtrip")
		check(app.checkpoint.load_session(app) == OK, phase+" repeated load")
	runtime = app.scene._native_combat
	if phase in ["naturalReward", "success"]:
		check(app.next_round == run.completedRounds, phase+" next round does not replay completed wave")
	if phase == "naturalReward":
		check(not app.run_domain.state.isPurchasedGemReward, "natural reward retained")
		check(app.apply_run_command({"kind":"chooseRewardShards"}), "natural reward resolves")
		check(app.run_domain.state.phase == "preparation", "natural reward returns to preparation")
	if phase == "reward":
		check(app.run_domain.state.rewardOptions == run.rewardOptions and app.run_domain.state.rewardReturnPhase == "wave", "reward context")
		var option: String = run.rewardOptions[0]
		var previous: int = app.run_domain.state.gemInventory.get(option, 0)
		check(app.apply_run_command({"kind":"chooseRewardGem","type":option}), "restored choice accepted")
		check(app.run_domain.state.gemInventory.get(option,0) == previous+1, "choice paid once")
		check(not app.apply_run_command({"kind":"chooseRewardGem","type":option}), "choice cannot pay twice")
	if phase in ["wave", "reward"]:
		app.toggle_pause()
		for i in range(480):
			runtime.advance_session(1.0/60.0)
			app.command()
		check(runtime.clock > 0 and runtime.turrets.values()[0].shotSequence > 0, phase+" actual shots continue after restart")
	if phase == "failure":
		var progression: Dictionary = app.run_domain.state.progression.duplicate(true)
		check(app.retry_stage(), "durably queued run can retry")
		check(app.checkpoint.rewards().state.pendingRewards.size() == 1, "retry preserves pending diamond reward")
		runtime = app.scene._native_combat
		check(runtime.defense.hp > 0 and not runtime.defense.failed and runtime.turrets.is_empty() and runtime.events.is_empty() and not runtime.wave.active, "retry starts clean combat")
		for key in ["lastRunRuneReward", "lastRunCorePointReward", "lastRunTurretModuleTicketReward"]: progression[key] = 0
		check(app.run_domain.state.progression == progression, "retry retains growth")
	if phase == "preparation":
		app.start_wave()
		check(runtime.wave.active and runtime.session.phase == "wave", "preparation starts actual wave")

func rejected_loads(app, directory: String) -> void:
	var valid = app.checkpoint.store.load_save()
	for kind in ["corrupt", "unsupported"]:
		app.checkpoint = Checkpoint.new(directory.path_join(kind))
		DirAccess.make_dir_recursive_absolute(app.checkpoint.store.primary_path.get_base_dir())
		var file := FileAccess.open(app.checkpoint.store.primary_path, FileAccess.WRITE)
		if kind == "corrupt": file.store_string("{broken checkpoint")
		else:
			var invalid: Dictionary = valid.duplicate(true)
			invalid.activeRun.mapSignature = "unsupported-map"
			file.store_string(JSON.stringify(invalid))
		file.close()
		var before: Dictionary = app.run_domain.state.duplicate(true)
		var epoch: int = app.epoch
		var snapshot: Dictionary = app.scene._native_combat.snapshot()
		check(app.checkpoint.load_session(app) != OK, kind+" rejected")
		check(app.epoch == epoch and app.run_domain.state == before and app.scene._native_combat.snapshot() == snapshot, kind+" rejection leaves scene/domain unchanged")

func pending_settlement(app, directory: String) -> void:
	app.checkpoint = Checkpoint.new(directory.path_join("pending-events"))
	app.enter_stage(0)
	var source: Dictionary = app.stage_source(0)
	var index: int = source.map.tiles.find("build")
	app.board_tap(Vector2i(index % int(source.map.columns), floori(float(index)/int(source.map.columns))))
	app.build_selected()
	app.start_wave()
	var runtime = app.scene._native_combat
	for i in range(1200):
		runtime.advance_session(1.0/60.0)
		if runtime.events.any(func(event): return event.kind == "kill"): break
		app.command()
	check(runtime.events.any(func(event): return event.kind == "kill"), "real unacknowledged kill before save")
	var before: int = app.run_domain.state.gold
	check(app.checkpoint.save_session(app) == OK, "save settles pending kill")
	var paid: int = app.run_domain.state.gold
	check(paid > before and runtime.events.is_empty(), "pending kill paid and ACKed")
	check(app.checkpoint.load_session(app) == OK, "pending-event checkpoint loads")
	app.command()
	check(app.run_domain.state.gold == paid, "reloaded pending kill is not paid twice")

func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a == b

func exit_boundaries(app, directory: String) -> void:
	app.enter_stage(0)
	var runtime = app.scene._native_combat
	var before: Dictionary = app.run_domain.state.duplicate(true)
	var original_epoch: int = runtime.epoch
	runtime.epoch -= 1
	runtime.events.append({"id":runtime.event_id+1,"kind":"coreDefeated"})
	app.run_domain.collect(runtime)
	check(app.run_domain.state == before, "old epoch event ignored")
	runtime.events.clear()
	runtime.epoch = original_epoch
	var blocker: String = directory.path_join("save-parent-file")
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("fixture")
	file.close()
	app.checkpoint = Checkpoint.new(blocker)
	app.exit_stage()
	check(app.scene._native_combat.active and app.run_domain.state == before, "failed exit save preserves active run")
	app.checkpoint = Checkpoint.new(directory.path_join("exit"))
	app.exit_stage()
	var saved = app.checkpoint.store.load_save()
	check(not app.scene._native_combat.active and saved != null and saved.activeRun.gold == before.gold, "exit checkpoints before reset")
