extends SceneTree
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var app = load("res://session/standalone.gd").new()
	scene._standalone_session = app
	scene.add_child(app)
	app.set_process(false)
	var runtime = scene._native_combat
	check(not app.run_domain.state.is_empty(), "native application domain initialized")
	if app.run_domain.state.is_empty():
		push_error(app.run_domain.error)
		quit(1)
		return
	var initial: int = app.run_domain.state.gold
	var source: Dictionary = app.stage_source(0)
	var index: int = source.map.tiles.find("build")
	var tile := Vector2i(index % int(source.map.columns), floori(float(index)/int(source.map.columns)))
	app.board_tap(tile)
	var cost: int = app.run_domain.service.build_cost(app.run_domain.state,"arrow")
	app.build_selected()
	check(app.run_domain.state.gold == initial-cost and runtime.turrets.size()==1, "build spends actual gold and creates native turret")
	app.build_selected()
	check(app.run_domain.state.gold == initial-cost and runtime.turrets.size()==1, "occupied tile rejected without charge")
	var id: int = app.run_domain.selected_id(tile)
	var saved_gold: int = app.run_domain.state.gold
	app.run_domain.state.gold = 0
	check(not app.selected_run_command("level") and runtime.turrets[str(id)].statInput.level == 1, "insufficient upgrade rejected")
	app.run_domain.state.gold = saved_gold
	# Explicit existing-run fixture budget for subsequent operations; no save/API.
	app.run_domain.state.gold = 10000
	app.run_domain.state.gemShards = 100
	app.run_domain.state.gemInventory = {"range":2}
	var level_cost: int = app.run_domain.service.quotes(app.run_domain.state,id).level
	runtime.turrets[str(id)].cooldown = 0.37
	check(app.selected_run_command("level"), "upgrade accepted")
	check(app.run_domain.state.gold == 10000-level_cost and runtime.turrets[str(id)].statInput.level==2, "upgrade price and level applied")
	check(is_equal_approx(runtime.turrets[str(id)].cooldown,0.37), "upgrade preserves live cooldown")
	check(app.selected_run_command("equipGem",{"type":"range","slot":0}), "inventory gem equipped")
	check(app.run_domain.state.gemInventory.range == 1 and "range" in runtime.turrets[str(id)].statInput.gems, "gem inventory and actual stats changed")
	check(app.selected_run_command("removeGem",{"slot":0}), "gem removed")
	check(app.run_domain.state.gemInventory.range == 2 and runtime.turrets[str(id)].statInput.gems.is_empty(), "removed gem returned")
	while int(runtime.turrets[str(id)].statInput.level) < 3: app.selected_run_command("level")
	var trait_name: String = app.run_domain.service.quotes(app.run_domain.state,id).primaryTraits[0]
	runtime.turrets[str(id)].overheatStacks = 7
	runtime.turrets[str(id)].recent = {"42":1.0}
	runtime.turrets[str(id)].cleanup = 2.0
	check(app.selected_run_command("primaryTrait",{"type":trait_name}), "primary trait purchased")
	check(runtime.turrets[str(id)].overheatStacks==0 and runtime.turrets[str(id)].recent.is_empty() and runtime.turrets[str(id)].cleanup==0.0, "trait resets only its native transient state")
	var upgrade_type: String = app.run_domain.growth.data.runUpgrades.keys()[0]
	check(app.apply_run_command({"kind":"runUpgrade","type":upgrade_type}), "run upgrade transaction")
	check(not app.run_domain.state.runUpgradeLevels.is_empty(), "run upgrade state persists")
	app.run_domain.state.progression.runes = 10000 # Isolated existing-profile fixture.
	var damage_before: float = runtime.turrets[str(id)].stats.damage
	check(app.apply_growth_command({"kind":"permanentUpgrade","type":"fireTraining"}), "ordinary growth purchase connected")
	check(runtime.turrets[str(id)].stats.damage > damage_before and app.run_domain.state.progression.runes < 10000, "ordinary growth spends runes and updates actual turret")
	app.start_wave()
	check(runtime.core.configured and runtime.core.skill == "guardianBeam", "selected default core connected")
	check(app.apply_run_command({"kind":"purchaseGemChoice"}), "buy gem choice during wave")
	var clock_before: float = runtime.clock
	runtime.advance_session(0.5)
	check(runtime.session.phase == "reward" and runtime.clock == clock_before, "reward selection pauses actual combat")
	var option: String = app.run_domain.state.rewardOptions[0]
	check(app.apply_run_command({"kind":"chooseRewardGem","type":option}), "reward selection accepted")
	check(runtime.session.phase == "wave", "purchased choice resumes interrupted wave")
	for i in range(480):
		runtime.advance_session(1.0/60.0)
		app._process(0)
	check(runtime.turrets[str(id)].shotSequence>0, "migrated paid tower attacks")
	var gold_after: int = app.run_domain.state.gold
	app.command()
	app.command()
	check(app.run_domain.state.gold==gold_after, "repeated event polling never double-pays")
	check(runtime.events.is_empty(), "events ACKed after application")
	scene._apply_frame(scene._native_combat_base_frame)
	app._process(0)
	if DisplayServer.get_name() != "headless":
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../captures/run-commands-combat.png"))
	var refund: int = app.run_domain.service.quotes(app.run_domain.state,id).sell
	check(app.selected_run_command("sell"), "sell in combat accepted")
	check(runtime.turrets.is_empty() and app.run_domain.state.gold==gold_after+refund, "sell removes turret and returns actual invested refund")
	check(app.checkpoint.save_session(app)==ERR_UNAVAILABLE, "unmigrated full save stays rejected")
	app.exit_stage()
	scene.queue_free()
	for i in range(3): await process_frame
	print("RUN_SESSION failures=",failures)
	quit(0 if failures.is_empty() else 1)
