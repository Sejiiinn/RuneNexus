extends SceneTree
## Actual main/app path, isolated save directory; no production player data.
var app
var hud
var failures: Array = []
var checks := 0
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/turret-stats-ux/incremental-update/"

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label); print("FAIL ",label)
func settle():
	await create_timer(0.3).timeout
	for frame in range(3): await process_frame
func named(name: String) -> Node: return hud.body.find_child(name,true,false)
func ids() -> Dictionary:
	var result := {}
	for name in ["TurretActionPanel","TurretIdentityIcon","TurretLevelAction","TurretTraitAction","TurretStatsGrid","Stat_damage","TurretTotalDamageValue"]:
		var node := named(name)
		if node != null: result[name] = node.get_instance_id()
	return result
func click(button: Button):
	check(button != null and not button.disabled,"button enabled")
	if button == null or button.disabled: return
	var point := button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"button hit within viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	root.push_input(motion,true)
	for down in [true,false]:
		var input := InputEventMouseButton.new()
		input.position = point; input.global_position = point
		input.button_index = MOUSE_BUTTON_LEFT; input.pressed = down
		root.push_input(input,true)
		await process_frame
	await settle()
func capture(name: String):
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png") == OK,"capture "+name)
func bounds(label: String):
	var panel := named("TurretActionPanel") as Control
	if panel == null: return
	check(panel.scale == Vector2.ONE,label+" scale preserved")
	var actions: Array = [named("TurretTraitAction"),named("TurretLevelAction"),named("TurretSellAction")]
	for i in range(actions.size()):
		check(actions[i].get_global_rect().end.x <= root.size.x+1,label+" action fits")
		if i > 0:
			check(actions[i-1].get_global_rect().end.x <= actions[i].global_position.x+1,label+" actions disjoint")
	for row in named("TurretStatsGrid").get_children():
		check(row.get_global_rect().end.x <= root.size.x+1,label+" stats width")
	check(hud.damage_label.text != "",label+" damage summary")

func run():
	check(OS.get_user_data_dir().contains("RuneNexus-HUD-Incremental-Review"),"isolated save")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(2.0).timeout
	app = scene._standalone_session
	if app == null:
		check(false,"actual app initialized"); finish(); return
	hud = app.hud
	root.content_scale_size = Vector2i(440,900); root.size = Vector2i(440,900)
	app.progression_inputs.unlockedStageCount = 15
	app.progression_inputs.researchLevels.turretTargetPriority = 1
	check(app.start_stage(14),"stage15 starts")
	if app.run_domain.state.is_empty(): finish(); return
	app.run_domain.state.gold = 20000
	app.run_domain.state.gemShards = 1000
	var map: Dictionary = app.catalog.stage(14).map
	var placed := 0
	for index in map.tiles.size():
		if map.tiles[index] != "build": continue
		app.board_tap(Vector2i(index%int(map.columns),index/int(map.columns)))
		app.turret_type = "arrow" if placed == 0 else "cannon"
		app.build_selected()
		placed += 1
		if placed == 2: break
	var turret: Dictionary = app.run_domain.state.turrets[0]
	app.board_tap(Vector2i(turret.x,turret.y))
	hud.main_tab = "turrets"; hud.tab = "stats"; hud.refresh()
	await settle()
	var baseline := ids()
	var before_dps: float = hud.total_dps
	await capture("stage15-440-before")
	if "--baseline-only" in OS.get_cmdline_user_args(): finish(); return
	await click(named("TurretLevelAction"))
	check(app.selection_view.level_preview,"preview clicked")
	check(ids() == baseline,"preview keeps panel nodes")
	await click(named("TurretLevelAction"))
	check(app.run_domain.state.turrets[0].level == 2,"level confirmed")
	check(ids() == baseline,"confirmed keeps panel nodes")
	check(hud.total_dps > before_dps,"total battle power updated")
	bounds("440 confirmed")
	await capture("stage15-440-confirmed")
	root.content_scale_size = Vector2i(320,900); root.size = Vector2i(320,900)
	hud.refresh(); await settle()
	baseline = ids()
	await click(named("TurretLevelAction"))
	check(ids() == baseline,"320 preview keeps panel nodes")
	bounds("320 preview")
	await capture("stage15-320-preview")
	await click(named("TurretLevelAction"))
	check(app.run_domain.state.turrets[0].level == 3,"320 level confirmed")
	check(ids() == baseline,"320 confirmed keeps panel nodes")
	await click(named("TurretTraitAction"))
	var choice := hud.modal_body.find_child("TraitChoice_overheatMagazine",true,false) as Button
	check(choice != null and not choice.disabled,"fresh trait unlock at level3")
	hud.close_modal(); await settle()
	hud.main_tab = "upgrades"; hud.refresh(); await settle()
	var rows := named("RunUpgradeRows")
	var row_ids := {}
	for row in rows.get_children(): row_ids[str(row.name)] = row.get_instance_id()
	var purchase := rows.get_node("Upgrade_towerDamage").find_child("Purchase",true,false) as Button
	var purchase_id := purchase.get_instance_id()
	before_dps = hud.total_dps
	print("PURCHASE before ",purchase.get_global_rect()," phase=",app.run_domain.state.phase," gold=",app.run_domain.state.gold," paused=",app.scene._native_combat.session)
	await capture("stage15-320-run-before")
	await click(purchase)
	print("PURCHASE after ",app.run_domain.state.runUpgradeLevels," message=",app.checkpoint.message)
	check(app.run_domain.state.runUpgradeLevels.get("towerDamage",0) == 1,"run upgrade clicked")
	check(named("RunUpgradeRows") == rows,"run rows root retained")
	check(purchase.get_instance_id() == purchase_id and is_instance_valid(purchase),"purchase button retained")
	for row in rows.get_children(): check(row_ids.get(str(row.name)) == row.get_instance_id(),"run row retained")
	check(hud.total_dps > before_dps,"run upgrade total power updated")
	await capture("stage15-320-run-upgrades")
	# Structural tabs still switch normally; only value changes keep the body.
	hud.main_tab = "turrets"; hud.tab = "stats"; hud.refresh(); await settle()
	await click(named("TurretGemsTab"))
	check(named("EquippedSocketRows") != null,"gem structure opens")
	await click(named("TurretStatsTab"))
	check(named("TurretStatsGrid") != null,"stats structure restored")
	# Synthetic large values test layout only; normal gameplay costs are smaller.
	var state: Dictionary = app.run_domain.state
	state.gold = 999999999
	state.gemShards = 1250
	state.turrets[0].level = 4
	app.run_domain.growth.data.turretRules.arrow.levelUpCosts[3] = 123456789
	app.run_domain.growth.data.runUpgrades.towerDamage.effectPerLevel = 1000000.0
	state.runUpgradeLevels.towerDamage = 2
	app.command(app.run_domain.service.runtime_commands(state))
	hud.refresh(); await settle()
	check(hud.gold_label.text == "1000M" and state.gold == 999999999,"compact wallet preserves exact balance")
	check(hud.gold_label.tooltip_text.contains("999999999"),"wallet exact tooltip")
	check(hud.shard_label.text == "1.25K","compact shard wallet")
	check(hud.resources.text.contains("M"),"compact total power")
	check(hud.total_dps > 1000000.0,"raw total power preserved")
	for width in [320,440]:
		root.content_scale_size = Vector2i(width,900); root.size = Vector2i(width,900)
		hud.refresh(); await settle()
		var price := named("TurretUpgradePrice") as Label
		check(price.text.replace(" G","") == "123M","compact price "+str(width))
		check(price.get_line_count() == 1,"compact price single line "+str(width))
		check(price.tooltip_text.contains("123456789"),"price exact tooltip "+str(width))
		check(price.get_global_rect().end.x <= root.size.x+1,"long price width "+str(width))
		check(price.size.y+1 >= price.get_minimum_size().y,"long price height "+str(width))
		check(named("TurretLevelAction").get_global_rect().grow(-2).encloses(price.get_global_rect()),"long price within button "+str(width))
		bounds("long "+str(width))
		await capture("stage15-"+str(width)+"-large-values")
	root.content_scale_size = Vector2i(320,900); root.size = Vector2i(320,900)
	app.run_domain.growth.data.runUpgrades.towerDamage.baseCost = 123456789
	state.runUpgradeLevels.towerDamage = 0
	hud.main_tab = "upgrades"; hud.refresh(); await settle()
	var large_button := named("RunUpgradeRows").get_node("Upgrade_towerDamage").get_node("Purchase") as Button
	var large_price := large_button.find_child("PurchasePrice",true,false) as Label
	check(large_price.text.replace(" G", "") == "123M","compact run price")
	check(large_price.get_line_count() == 1,"compact run price single line")
	check(large_price.tooltip_text.contains("123456789"),"run price exact tooltip")
	check(large_button.get_global_rect().encloses(large_price.get_global_rect()),"large run price within button")
	await capture("stage15-320-large-run-price")
	finish()
func finish():
	var file := FileAccess.open(out+"app-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"user_data":OS.get_user_data_dir()},"\t"))
	print("INCREMENTAL_APP checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
