extends SceneTree
## Two separate processes with an isolated root exercise real native events and v2.
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Json = preload("res://app/save_json.gd")
const ACCOUNT := "00000000-0000-4000-8000-000000000123"
const NOW := 1700000000000
var failures: Array = []
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["write", "read"] or not args[1].is_absolute_path():
		push_error("Expected write/read and isolated absolute root")
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
	app.run_domain.now_millis = func(): return NOW
	if args[0] == "write":
		write_events(app, args[1])
		write_terminal(app, args[1])
		await write_account(app, args[1])
	else:
		read_events(app, args[1])
		await read_terminal(app, args[1])
		failed_transition(app, args[1])
		await read_account(app, args[1])
	scene.queue_free()
	for i in range(3): await process_frame
	print("REWARD_QUEST_SESSION mode=", args[0], " checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func progress(app, period: String, kind: String) -> int:
	return int(app.run_domain.state.progression.get(period + "QuestProgress", {}).get(kind, 0))

func write_events(app, directory: String) -> void:
	app.checkpoint = Checkpoint.new(directory.path_join("events"))
	app.enter_stage(0)
	app.run_domain.state.gold = 10000
	var upgrade: String = app.run_domain.growth.data.runUpgrades.keys()[0]
	check(app.apply_run_command({"kind":"runUpgrade","type":upgrade}), "successful upgrade")
	app.run_domain.state.gold = 0
	check(not app.apply_run_command({"kind":"runUpgrade","type":upgrade}), "unaffordable upgrade rejected")
	app.run_domain.state.gold = 10000
	var source: Dictionary = app.stage_source(0)
	for index in range(source.map.tiles.size()):
		if source.map.tiles[index] != "build": continue
		app.board_tap(Vector2i(index % int(source.map.columns), floori(float(index)/int(source.map.columns))))
		app.build_selected()
	app.start_wave()
	var runtime = app.scene._native_combat
	var kills := 0
	var waves := 0
	for step in range(12000):
		# Keep production spawn, targeting, projectile, death, and wave event paths.
		for enemy in runtime.enemies.values():
			if float(enemy.hp) > 0: enemy.hp = minf(float(enemy.hp), 1.0)
		runtime.advance_session(1.0/60.0)
		for event in runtime.events:
			if event.kind == "kill": kills += 1
			if event.kind == "waveCompleted": waves += 1
		app.command()
		if waves > 0: break
	check(kills > 0 and waves == 1, "real native kills and completed wave")
	for period in ["daily", "weekly"]:
		check(progress(app, period, "killEnemies") == kills, period + " real kills exactly once")
		check(progress(app, period, "clearWaves") == 1, period + " real wave exactly once")
		check(progress(app, period, "buyRunUpgrades") == 1, period + " only successful upgrade")
	var before: Dictionary = app.run_domain.state.progression.duplicate(true)
	var gold_before: int = app.run_domain.state.gold
	runtime.enemies["999999"] = {"id":999999, "type":"normal", "isDebug":true, "diamondReward":50}
	runtime._emit({"kind":"kill", "enemyId":999999})
	check(app.command(), "debug kill event acknowledged")
	check(app.run_domain.state.progression == before and app.run_domain.state.gold == gold_before, "debug kills excluded from quests and rewards")
	for repeat in range(4): app.command()
	check(app.run_domain.state.progression == before, "repeated event polling is idempotent")
	check(app.checkpoint.save_session(app) == OK, "event checkpoint written")
	write_expected(directory.path_join("events.json"), {"progression":persisted_progression(app)})

func read_events(app, directory: String) -> void:
	app.checkpoint = Checkpoint.new(directory.path_join("events"))
	var expected: Dictionary = Json.parse(FileAccess.get_file_as_string(directory.path_join("events.json")))
	check(app.checkpoint.load_session(app) == OK, "event checkpoint restored in new process")
	for repeat in range(4): app.command()
	check(app.run_domain.state.progression == expected.progression, "restored repeated polling preserves quest counters")
	check(app.checkpoint.save_session(app) == OK, "restored events save")

func write_terminal(app, directory: String) -> void:
	app.checkpoint = Checkpoint.new(directory.path_join("terminal"))
	app.progression_inputs = {}
	app.enter_stage(10)
	var source: Dictionary = app.stage_source(10)
	app.run_domain.state.phase = "wave"
	app.run_domain.state.roundIndex = source.waves.size()-1
	app.run_domain.state.completedRounds = source.waves.size()-1
	app.run_domain.state.pendingEconomyDiamonds = 17
	var runtime = app.scene._native_combat
	runtime._emit({"kind":"waveCompleted", "waveId":int(source.waves[-1].round)})
	check(app.command(), "terminal native event accepted")
	var p: Dictionary = app.run_domain.state.progression
	check(app.run_domain.state.phase == "success", "terminal phase")
	check(int(p.runes) > 0 and int(p.lastRunRuneReward) > 0, "terminal rune reward")
	check(int(p.totalCorePoints) > 0 and int(p.lastRunCorePointReward) > 0, "terminal core point reward")
	check(11 in p.clearedStageNumbers and int(p.bestRoundsByStage.get("11", 0)) == source.waves.size() and int(p.unlockedStageCount) == 12, "clear best and unlock")
	check(int(p.lastRunTurretModuleTicketReward) > 0 and int(p.get("turretModules", {}).get("tickets", 0)) == 0, "stage11 tickets pending instead of locally spendable")
	var before: Dictionary = p.duplicate(true)
	for repeat in range(4): app.command()
	check(app.run_domain.state.progression == before, "terminal rewards once across repeated polls")
	check(app.prepare_run_transition(), "terminal durable save and enqueue")
	check(app.prepare_run_transition(), "repeated transition preparation")
	var outbox = app.checkpoint.rewards()
	check(outbox.state.pendingRewards.size() == 1, "single durable reward")
	check(outbox.state.pendingRewards[0].pendingDiamonds == 17 and outbox.state.pendingRewards[0].firstClearModuleTickets > 0, "diamonds and stage11 tickets queued")
	check(outbox.state.accountIdBinding == "guest" and outbox.state.inFlight == null, "guest queue not bound or dispatched")
	write_expected(directory.path_join("terminal.json"), {"progression":persisted_progression(app), "reward":outbox.state.pendingRewards[0]})

func read_terminal(app, directory: String) -> void:
	app.checkpoint = Checkpoint.new(directory.path_join("terminal"))
	var expected: Dictionary = Json.parse(FileAccess.get_file_as_string(directory.path_join("terminal.json")))
	check(app.checkpoint.load_session(app) == OK, "terminal checkpoint restored in new process")
	for repeat in range(4): app.command()
	check(app.run_domain.state.progression == expected.progression, "terminal v2 restart does not regrant rewards")
	check(app.prepare_run_transition(), "restored transition prepared")
	var outbox = app.checkpoint.rewards()
	check(outbox.state.pendingRewards == [expected.reward], "restored durable queue deduplicates")
	check(outbox.state.accountIdBinding == "guest" and outbox.state.inFlight == null, "restored guest queue remains local")
	var calls := [0]
	var transport := func(_context, _command):
		calls[0] += 1
		return {}
	var settlement: Dictionary = await app.settle_pending_rewards({"accountId":"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa", "accessToken":"test-only", "writerGeneration":1, "sessionId":"test"}, func(): return {"ok":true}, transport)
	check(not settlement.get("ok", false) and calls[0] == 0, "guest queue never calls remote even with account context")
	check(outbox.state.accountIdBinding == "guest" and outbox.state.pendingRewards == [expected.reward], "account context cannot adopt guest queue")
	check(app.retry_stage(), "pending guest reward permits safe retry")
	var after_retry: Dictionary = expected.progression.duplicate(true)
	for key in ["lastRunRuneReward", "lastRunCorePointReward", "lastRunTurretModuleTicketReward"]: after_retry[key] = 0
	check(app.run_domain.state.progression == after_retry, "retry retains progression and clears previous reward summary")
	check(outbox.state.pendingRewards == [expected.reward], "retry retains durable reward")

func failed_transition(app, directory: String) -> void:
	var blocker: String = directory.path_join("blocked-parent")
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	app.checkpoint = Checkpoint.new(blocker)
	app.run_domain.state.pendingEconomyDiamonds = 5
	var before: Dictionary = app.run_domain.state.duplicate(true)
	var epoch: int = app.epoch
	check(not app.retry_stage(), "disk failure blocks retry")
	check(app.epoch == epoch and app.run_domain.state == before and app.scene._native_combat.active, "disk failure preserves active run")
	app.enter_next()
	check(app.epoch == epoch and app.run_domain.state == before, "disk failure blocks Stage replacement")
	app.checkpoint = Checkpoint.new(directory.path_join("blocked-outbox"))
	var outbox = app.checkpoint.rewards()
	outbox.primary_path = blocker.path_join("queue.json")
	outbox.backup_path = blocker.path_join("queue.backup.json")
	check(not app.retry_stage(), "outbox disk failure blocks retry after checkpoint write")
	check(app.epoch == epoch and app.run_domain.state == before, "outbox disk failure preserves active run")

func write_expected(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func persisted_progression(app) -> Dictionary:
	var saved: Dictionary = app.checkpoint.store.load_save()
	var p: Dictionary = saved.progression.duplicate(true)
	p.turretModules = saved.turretModules.duplicate(true)
	return p

func write_account(app, directory: String) -> void:
	app.checkpoint = Checkpoint.new(directory.path_join("account"), ACCOUNT)
	app.progression_inputs = {}
	app.enter_stage(0)
	app.run_domain.state.pendingEconomyDiamonds = 12
	check(app.prepare_run_transition(), "account run durably queued")
	write_expected(directory.path_join("account-old.json"), app.checkpoint.store.load_save())
	var family: String = app.run_domain.growth.data.module.families.arrow.core
	var snapshot := {"authorityState":"server_authoritative", "authorityEpoch":"epoch", "authorityVersion":1, "catalogVersion":1, "economyRevision":3, "serverTime":"2026-09-21T00:00:00Z", "wallet":{"freeDiamonds":42,"paidDiamonds":7,"moduleTickets":3}, "turretModules":{"drawCount":1,"ticketPurchaseCount":0,"items":[{"id":"server-module", "turretType":"arrow", "part":"core", "family":family, "grade":"normal", "acquiredOrder":1, "options":[{"type":"damageIncrease","value":2}]}]}, "entitlements":{"researchSlotTwoUnlocked":true}, "pendingProgressionEffects":[], "claimedRewardKeys":[]}
	var calls := [0]
	var transport := func(_context, _command):
		calls[0] += 1
		return {"status":200,"body":{"economy":snapshot}}
	var context := {"accountId":ACCOUNT,"writerGeneration":2,"accessToken":"test-only","sessionId":"test"}
	var result: Dictionary = await app.settle_pending_rewards(context, func(): return {"ok":true,"accountId":ACCOUNT,"writerGeneration":2,"sourceSaveRevision":12}, transport)
	check(result.get("ok",false) and calls[0] == 1, "account settlement uses production snapshot mapper")
	check_account_progression(app, "account settlement")
	var queue = app.checkpoint.rewards()
	check(queue.state.pendingRewards.is_empty() and queue.state.inFlight == null, "account receipt atomically clears queue")
	write_expected(directory.path_join("account.json"), {"progression":persisted_progression(app)})

func read_account(app, directory: String) -> void:
	app.checkpoint = Checkpoint.new(directory.path_join("account"), ACCOUNT)
	check(app.checkpoint.load_session(app) == OK, "account v2 restored in new process")
	check_account_progression(app, "account restored")
	var expected: Dictionary = Json.parse(FileAccess.get_file_as_string(directory.path_join("account.json")))
	check(app.run_domain.state.progression == expected.progression, "account restart does not double grant")
	var old: Dictionary = Json.parse(FileAccess.get_file_as_string(directory.path_join("account-old.json")))
	check(app.checkpoint.store.save_save(old) == OK, "older account v2 fixture")
	check(app.checkpoint.load_session(app) == OK, "older account v2 reload")
	check_account_progression(app, "cached authoritative snapshot reapplied")
	var calls := [0]
	var transport := func(_context, _command):
		calls[0] += 1
		return {}
	await app.settle_pending_rewards({"accountId":ACCOUNT,"writerGeneration":2,"accessToken":"test-only","sessionId":"test"}, Callable(), transport)
	check(calls[0] == 0 and app.checkpoint.rewards().state.pendingRewards.is_empty(), "account tombstone prevents remote resettlement")

func check_account_progression(app, label: String) -> void:
	var p: Dictionary = app.run_domain.state.progression
	check(int(p.get("freeDiamonds",0)) == 42 and int(p.get("paidDiamonds",0)) == 7 and p.get("researchSlotTwoUnlocked",false), label + " wallet and entitlement")
	var inventory: Dictionary = p.get("turretModules", {})
	check(int(inventory.get("tickets",0)) == 3 and inventory.get("items",[]).size() == 1 and inventory.items[0].id == "server-module", label + " tickets and module inventory")
