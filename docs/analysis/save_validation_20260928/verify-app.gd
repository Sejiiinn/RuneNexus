extends SceneTree
const Adapter = preload("res://app/content_run_save.gd")
var failures: Array = []
var checks := 0
var out := "/Users/sejin/Documents/Codex/RuneNexus/docs/analysis/save_validation_20260928/"
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label); print("FAIL ",label)
func run():
	check(OS.get_user_data_dir().contains("RuneNexus-HUD-Incremental-Review"),"isolated test save")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(2.0).timeout
	var app = scene._standalone_session
	if app == null: check(false,"actual app initialized"); finish(); return
	app.progression_inputs.unlockedStageCount = 15
	check(app.start_stage(14),"stage15 starts")
	app.run_domain.state.gold = 20000
	app.run_domain.state.gemShards = 1000
	var map: Dictionary = app.catalog.stage(14).map
	var count := 0
	for index in map.tiles.size():
		if map.tiles[index] != "build": continue
		app.board_tap(Vector2i(index%int(map.columns),index/int(map.columns)))
		app.turret_type = "arrow" if count == 0 else "cannon"
		app.build_selected()
		count += 1
		if count == 2: break
	check(app.run_domain.state.turrets.size() == 2,"two turrets built and saved")
	var turret: Dictionary = app.run_domain.state.turrets[0]
	check(app.apply_run_command({"kind":"level","id":turret.id}),"level command persists")
	check(app.apply_run_command({"kind":"runUpgrade","type":"towerDamage"}),"run upgrade persists")
	app.start_wave()
	for attempt in range(100):
		if not scene._native_combat.enemies.is_empty(): break
		await create_timer(0.1).timeout
	check(app.pause_and_save(),"active combat pause and save")
	var saved: Dictionary = app.checkpoint.store.load_save()
	check(saved.activeRun.enemies.size() > 0,"live enemies captured")
	check(saved.activeRun.spawnQueue.size() > 0,"pending enemies captured")
	var before: Dictionary = saved.activeRun.duplicate(true)
	check(app.checkpoint.load_session(app) == OK,"saved combat restores")
	check(scene._native_combat.session.paused,"restored combat stays paused")
	check(app.run_domain.state.turrets.size() == 2 and app.run_domain.state.turrets[0].level == 2,"level and towers restored")
	check(app.run_domain.state.runUpgradeLevels.towerDamage == 1,"run upgrade restored")
	check(app.command(),"restored events acknowledged")
	var adapter = Adapter.new(app.catalog,app.run_domain.growth)
	var after: Dictionary = adapter.capture(app.run_domain.state,scene._native_combat.snapshot(),123)
	check(not after.is_empty(),"restored combat captures again")
	if not after.is_empty():
		for field in ["gold","gemShards","roundIndex","nexusHp","turrets","enemies","spawnQueue"]:
			check(after.activeRun[field] == before[field],"roundtrip exact "+field)
	# A rejected checkpoint must leave the last durable save intact.
	var durable := FileAccess.get_file_as_string(app.checkpoint.store.primary_path)
	app.run_domain.state.turrets[0].level = 999
	check(not app.persist_progression(),"invalid checkpoint rejected")
	check(app.save_failed and scene._native_combat.session.paused,"save failure pauses play")
	check(FileAccess.get_file_as_string(app.checkpoint.store.primary_path) == durable,"invalid save leaves durable file intact")
	app.run_domain.state.turrets[0].level = 2
	check(app.persist_progression() and not app.save_failed,"valid checkpoint retry recovers")
	finish()
func finish():
	var file := FileAccess.open(out+"app-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"user_data":OS.get_user_data_dir()},"\t"))
	print("SAVE_VALIDATION_APP checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
