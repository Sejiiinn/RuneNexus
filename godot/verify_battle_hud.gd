extends SceneTree
const HudNumber = preload("res://ui/hud_number.gd")
class QueryCatalog extends "res://content/content_catalog.gd":
	var stage_queries := 0
	var wave_queries := 0
	func stage(index: int) -> Dictionary:
		stage_queries += 1
		return super.stage(index)
	func wave_definition(si: int, wi: int) -> Dictionary:
		wave_queries += 1
		return super.wave_definition(si,wi)
## UI smoke with the actual catalog/command owner, no editor or persistent save.
class App extends Node:
	var catalog = QueryCatalog.new()
	var run_domain = preload("res://session/run_session.gd").new()
	var hud
	var selected := Vector2i(-1,-1)
	var stage := 0
	var stage_source_calls := 0
	var turret_type := "arrow"
	var selection_view := {"level_preview":false}
	func refresh_selection() -> void: pass
	func set_speed(value) -> void: scene._native_combat.session.speed = value
	func begin_modal_pause() -> bool:
		var running: bool = not scene._native_combat.session.paused
		scene._native_combat.session.paused = true
		return running
	func end_modal_pause(value: bool) -> void: scene._native_combat.session.paused = not value
	func abandon_run() -> bool: return true
	var auto_start_mode := "pauseEachRound"
	func set_auto_start_mode(value: String) -> void: auto_start_mode = value
	var checkpoint := {"message":""}
	var scene := {"_native_combat":{"defense":{"hp":100.0,"max_hp":100.0},"session":{"paused":false,"speed":1}},"options":{"camera":"angled"}}
	func stage_source(index: int) -> Dictionary:
		stage_source_calls += 1
		return catalog.stage(index)
	func stage_map(index: int) -> Dictionary:
		return catalog.stage_map(index)
	func apply_run_command(command: Dictionary) -> bool:
		var result: Dictionary = run_domain.apply(command)
		checkpoint.message = "" if result.ok else run_domain.error
		return result.ok
	func selected_run_command(kind: String, values: Dictionary = {}) -> bool:
		var command := {"kind":kind,"id":run_domain.selected_id(selected)}
		command.merge(values)
		return apply_run_command(command)
	func board_tap(tile: Vector2i) -> void:
		selected = tile
		if hud != null: hud.on_board_selection(); hud.refresh()
	func build_selected() -> void: apply_run_command({"kind":"build","x":selected.x,"y":selected.y,"type":turret_type})
	func show_lobby() -> void: pass
	func start_wave() -> void: run_domain.state.phase = "wave"
	func toggle_pause() -> void: scene._native_combat.session.paused = not scene._native_combat.session.paused
	func toggle_speed() -> void: scene._native_combat.session.speed = 4
	func toggle_camera() -> void: scene.options.camera = "drone"
	func retry_stage() -> void: run_domain.state.phase = "preparation"

func _initialize() -> void: call_deferred("run")
func run() -> void:
	for case in [[0,0,"0"],[0,1,"0.0"],[999,0,"999"],[999,1,"999.0"],[1000,1,"1,000.0"],[1250,1,"1,250.0"],[9999,0,"9,999"],[10000,0,"10K"],[12500,1,"12.5K"],[1000000,1,"1M"],[999990,1,"1M"],[999999,1,"1M"],[-1250,1,"-1,250.0"],[-999999,1,"-1M"]]:
		assert(HudNumber.compact(float(case[0]),int(case[1])) == case[2],"Compact boundary: "+str(case))
	for case in [[999,"999"],[1000,"1,000"],[1250,"1,250"],[9999,"9,999"],[10000,"10K"],[12500,"12.5K"],[123456789,"123.5M"],[999499,"999.5K"],[999500,"999.5K"],[1000000,"1M"],[-999500,"-999.5K"]]:
		assert(HudNumber.compact_price(float(case[0])) == case[1],"Compact price boundary: "+str(case))
	root.content_scale_size = Vector2i(440,880)
	root.size = Vector2i(440,880)
	var app := App.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.initialize(app.catalog,{},0,100))
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.app = app
	app.hud = hud
	root.add_child(hud)
	await process_frame
	var resource_panel: PanelContainer = hud.top.get_node("ResourceHUD")
	assert(resource_panel.theme_type_variation == "ResourceHUD")
	var resource_style: StyleBoxTexture = resource_panel.get_theme_stylebox("panel")
	assert(resource_style.texture.resource_path.ends_with("ui/hud/resource_panel.png"))
	assert(resource_style.texture_margin_left == 14 and resource_style.texture_margin_top == 14)
	assert(resource_style.content_margin_left == 8 and resource_style.content_margin_top == 8)
	# Disable periodic refresh so layout must position the camera itself.
	hud.set_process(false)
	# Currency and HP thresholds use the same display policy at both phone widths.
	for width in [320,440]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		for sample in [[1250,"1,250"],[9999,"9,999"],[10000,"10K"],[12500,"12.5K"],[999950,"1M"]]:
			app.run_domain.state.gold = sample[0]; app.run_domain.state.gemShards = sample[0]
			app.scene._native_combat.defense.hp = float(sample[0]); app.scene._native_combat.defense.max_hp = float(sample[0])
			var before: Dictionary = app.run_domain.state.duplicate(true)
			hud.refresh()
			for frame in range(4): await process_frame
			assert(hud.gold_label.text == sample[1] and hud.shard_label.text == sample[1])
			assert(hud.gold_label.tooltip_text == str(sample[0]))
			assert(hud.status.text == "♡ %s/%s" % [sample[1],sample[1]])
			assert(app.run_domain.state == before,"Numeric refresh must not alter gameplay values")
			assert_label_fits(hud.gold_label); assert_label_fits(hud.shard_label); assert_label_fits(hud.status)
			assert(resource_panel.get_global_rect().end.x <= width+0.1,"Resource HUD must fit grouped amounts")
			assert(hud.status.get_global_rect().end.x <= hud.wave_label.get_global_rect().position.x)
			assert(hud.wave_label.get_global_rect().end.x <= hud.home.get_global_rect().position.x)
			assert(hud.camera_button.get_global_rect().position.y >= hud.top.get_global_rect().end.y+5.9,"Camera follows first/resize layout before the next refresh poll")
	hud.set_process(true)
	app.scene._native_combat.defense.hp = 100.0; app.scene._native_combat.defense.max_hp = 100.0
	app.run_domain.state.gold = 10000
	app.run_domain.state.gemShards = 100
	var map: Dictionary = app.catalog.stage_map(0)
	var index: int = map.tiles.find("build")
	app.selected = Vector2i(index % int(map.columns),index / int(map.columns))
	hud.refresh()
	hud.on_board_selection()
	hud.refresh()
	assert(app.stage_source_calls == 0 and app.catalog.stage_queries == 0 and app.catalog.wave_queries == 0)
	var install := find_button(hud.body,"설치 · ")
	assert_wallet_refresh(app,hud,install,"gold",app.run_domain.service.build_cost(app.run_domain.state,"arrow"))
	assert(app.stage_source_calls == 0 and app.catalog.stage_queries == 0 and app.catalog.wave_queries == 0)
	var initial_bounds: Rect2 = hud.battlefield_rect()
	# Re-tapping the selected type installs; the explicit button shares the command.
	var build_buttons := buttons(hud.body)
	for button in build_buttons:
		if button.text.begins_with("기관총\n"): button.pressed.emit(); break
	assert(app.run_domain.state.turrets.size() == 1)
	hud.refresh()
	await process_frame; await process_frame
	var level_button := hud.body.find_child("TurretLevelAction",true,false) as Button
	assert_wallet_refresh(app,hud,level_button,"gold",int(app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).level))
	assert(hud.top.size.y <= 100)
	assert(hud.body.get_child(0).size.y <= 94)
	for width in [320,440]:
		root.content_scale_size.x = width; root.size.x = width
		await process_frame; await process_frame; await process_frame
		var panel: Control = hud.body.find_child("TurretActionPanel",true,false)
		var actions: PanelContainer = panel.find_child("TurretActions",true,false)
		var upgrade := actions.find_child("TurretLevelAction",true,false) as Button
		var traits := actions.find_child("TurretTraitAction",true,false) as Button
		var sell := actions.find_child("TurretSellAction",true,false) as Button
		assert(upgrade.get_theme_stylebox("normal") is StyleBoxTexture)
		assert(upgrade.get_theme_stylebox("normal").texture_margin_left == 9)
		assert(actions.get_theme_stylebox("panel") is StyleBoxTexture)
		assert(upgrade.size.x > sell.size.x and traits.size.x > sell.size.x)
		assert(traits.get_global_rect().position.x < upgrade.get_global_rect().position.x)
		assert(upgrade.get_global_rect().position.x < sell.get_global_rect().position.x)
		assert(sell.get_global_rect().end.x <= width)
		assert(is_equal_approx(upgrade.position.y,traits.position.y))
		assert(absf(upgrade.size.x/traits.size.x-570.0/585.0) < 0.06)
		for control in [panel]+panel.find_children("*","Control",true,false): assert(control.scale == Vector2.ONE)
		var turret_art: AtlasTexture = panel.find_child("TurretIdentityIcon",true,false).texture
		assert(turret_art.atlas.resource_path.ends_with("turrets_3d/arrow.png"))
		assert(turret_art.region == Rect2(turret_art.atlas.get_image().get_used_rect()))
		for label in panel.find_children("*","Label",true,false):
			assert(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x <= label.size.x+0.1)
		assert(hud.scroll.size.y >= hud.body.get_combined_minimum_size().y)
		var category: HBoxContainer = hud.body.get_node("TurretCategoryAndDamage")
		assert(category.get_child(category.get_child_count()-1) == hud.damage_label.get_parent())
		assert(category.get_global_rect().encloses(hud.damage_label.get_global_rect()) and hud.damage_label.get_line_count() == 1)
		assert(hud.body.find_child("TurretDamageSummary",true,false) == null)
		assert(not (hud.body.find_child("TurretTargetPriority",true,false) as Button).visible,"Target action remains research gated")
	app.scene._native_combat.turrets = {str(app.run_domain.state.turrets[0].id): {"directDamageDealt":123.0,"splashDamageDealt":7.0}}
	hud.refresh()
	assert(hud.damage_label.text.ends_with("130.0"))
	assert(hud.status.autowrap_mode == TextServer.AUTOWRAP_OFF)
	assert(hud.wave_label.autowrap_mode == TextServer.AUTOWRAP_OFF)
	var turret_nodes := node_identities(hud.body)
	(hud.body.find_child("TurretLevelAction",true,false) as Button).pressed.emit()
	assert(node_identities(hud.body) == turret_nodes,"Preview must keep every existing node")
	assert(app.run_domain.state.turrets[0].level == 1)
	assert(app.selection_view.level_preview)
	assert(hud.turret_panel._stat_value({"range":96.0},"range") == "2.00칸")
	assert(hud.turret_panel._stat_value({"projectileCount":3},"projectileCount") == "3발")
	assert(hud.turret_panel._stat_value({"aimDuration":0.75},"aimDuration") == "0.75초")
	var stat_scroll = hud.body.find_child("TurretStatsScroll",true,false)
	assert(stat_scroll != null and is_equal_approx(stat_scroll.custom_minimum_size.y,128))
	assert(stat_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	(hud.body.find_child("TurretLevelAction",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].level == 2)
	assert(app.selection_view.level_preview,"Successful confirmation must retain preview for the next level")
	var next_quote: Dictionary = app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id))
	assert(level_button.tooltip_text == "강화 확정 · %d G" % int(next_quote.level))
	var continuous_gold: int = app.run_domain.state.gold
	level_button.pressed.emit()
	assert(app.run_domain.state.turrets[0].level == 3)
	assert(int(app.run_domain.state.gold) == continuous_gold-int(next_quote.level))
	assert(app.selection_view.level_preview)
	var after_continuous: int = app.run_domain.state.gold
	app.run_domain.state.gold = 0; hud.refresh()
	assert(level_button.disabled)
	level_button.pressed.emit()
	assert(app.run_domain.state.turrets[0].level == 3 and int(app.run_domain.state.gold) == 0)
	assert(app.selection_view.level_preview,"Insufficient funds preserve the next-level comparison")
	app.run_domain.state.gold = after_continuous; hud.refresh()
	assert(node_identities(hud.body) == turret_nodes,"Level confirmation must retain action, icons and stat rows")
	assert_wallet_refresh(app,hud,level_button,"gold",int(app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).level))
	hud._selected_command("level")
	(hud.body.find_child("TurretTraitAction",true,false) as Button).pressed.emit()
	(hud.modal_body.find_child("TraitChoice_overheatMagazine",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].primaryTrait == null)
	(hud.modal_body.find_child("TraitChoice_overheatMagazine",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].primaryTrait == null)
	(hud.modal_body.find_child("TraitConfirm",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].primaryTrait == "overheatMagazine")
	(hud.body.find_child("TurretSellAction",true,false) as Button).pressed.emit()
	assert(hud.modal_active() and app.scene._native_combat.session.paused)
	assert(hud.modal_panel.get_theme_stylebox("panel") is StyleBoxTexture)
	var sale := find_button(hud.modal_body,"판매 · ")
	assert(sale.text == "판매 · +%s 골드" % HudNumber.compact_price(app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).sell))
	assert(sale.get_theme_stylebox("normal") is StyleBoxTexture)
	assert(sale.get_theme_stylebox("disabled").texture.resource_path.ends_with("native/disabled.png"))
	assert(sale.get_theme_stylebox("normal").texture_margin_left == 11)
	hud.close_modal()
	assert(not app.scene._native_combat.session.paused)
	app.run_domain.state.progression["researchLevels"] = {"turretTargetPriority":1}
	hud.refresh()
	for width in [320,440]:
		root.content_scale_size.x = width; root.size.x = width; hud.refresh()
		for frame in range(8): await process_frame
		var priority: Button = hud.body.find_child("TurretTargetPriority",true,false)
		var gems: Button = hud.body.find_child("TurretGemsTab",true,false)
		assert(priority.visible and priority.text.is_empty() and priority.icon.resource_path.ends_with("growth_combat_swords.png"))
		assert(priority.tooltip_text == "공격 목표: 선두")
		assert(priority.get_parent() == gems.get_parent() and priority.get_global_rect().position.x >= gems.get_global_rect().end.x)
		assert(priority.size == Vector2(32,32) and priority.get_global_rect().end.x <= width)
		assert(absf(priority.get_global_rect().end.x-hud.body.get_global_rect().end.x) <= 1.0,"Target icon aligns with the right edge of the selected panel")
		assert(absf(priority.get_global_rect().get_center().y-gems.get_global_rect().get_center().y) <= 1.0,"Tab-row controls share a center after pixel rounding")
		var expanded_stats: ScrollContainer = hud.body.find_child("TurretStatsScroll",true,false)
		assert(is_equal_approx(expanded_stats.size.y,117 if width == 320 else 124),"Reclaim summary space after compensating for the target touch area")
		assert(is_equal_approx(hud.dock.size.y,335 if width == 320 else 361),"Preserve the previous selected-turret dock height")
	hud.turret_panel._priority()
	assert(hud.target_priority_popup.visible and not hud.modal_active())
	assert(not app.scene._native_combat.session.paused,"The target list does not pause combat")
	assert(hud.blocks_board_input(),"An open target list must not let clicks reach the board")
	assert(hud.target_priority_popup.item_count == hud.PRIORITIES.size())
	for option in hud.PRIORITIES.size():
		assert(hud.target_priority_popup.get_item_text(option) == hud.PRIORITIES.values()[option],"List contains only goal names")
	assert(hud.target_priority_popup.is_item_checked(0))
	var target_frame: StyleBoxTexture = hud.target_priority_popup.get_theme_stylebox("panel")
	assert(target_frame.texture.resource_path.ends_with("ui/hud/target_priority/frame.png"))
	assert(target_frame.texture_margin_top == 94 and target_frame.texture_margin_bottom == 18,"Keep the side runes in an unstretched slice")
	var selected_goal: Button = hud.target_priority_popup.get_node("TargetPriorityRows/TargetChoice_first")
	assert(selected_goal.icon.resource_path.ends_with("radio_checked.png"))
	assert(selected_goal.get_theme_stylebox("normal").bg_color == Color("0a202c"),"Current goal stays highlighted independently of focus or hover")
	hud.target_priority_popup.id_pressed.emit(2)
	assert(app.run_domain.state.turrets[0].targetPriority == "strongest")
	assert((hud.body.find_child("TurretTargetPriority",true,false) as Button).tooltip_text == "공격 목표: 최대 체력")
	hud.turret_panel._priority()
	assert(hud.target_priority_popup.is_item_checked(2),"Current priority remains marked in the option list")
	assert(not selected_goal.button_pressed and selected_goal.get_theme_stylebox("normal").bg_color == Color.TRANSPARENT)
	assert((hud.target_priority_popup.get_node("TargetPriorityRows/TargetChoice_strongest") as Button).get_theme_stylebox("normal").bg_color == Color("0a202c"))
	hud.close_back()
	assert(not hud.target_priority_popup.visible and hud.main_tab == "turrets")
	assert(not app.scene._native_combat.session.paused)
	hud.turret_panel._show_gems()
	assert((hud.body.find_child("TurretTargetPriority",true,false) as Button).visible,"Target action remains available beside the gem tab")
	var sockets := buttons(hud.body).filter(func(button): return str(button.name).begins_with("EquippedSlot"))
	var link_cost := int(app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).link)
	assert(sockets.size() == int(hud.configuration_cache.derived(app.run_domain.state,app.run_domain.service).get("maxTurretLinkSlots",3)))
	assert(hud.body.find_child("BuyGemSlot",true,false) == null)
	(hud.body.find_child("EquippedSlot1",true,false) as Button).pressed.emit()
	var buy_slot := hud.body.find_child("UnlockGemSlot",true,false) as Button
	assert(buy_slot != null)
	assert_wallet_refresh(app,hud,buy_slot,"gold",link_cost)
	app.run_domain.state.gemInventory = {"attackSpeed":1}
	hud.refresh()
	hud.selected_slot = 0; hud.refresh()
	(hud.body.find_child("GemInventory_attackSpeed",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].equippedGemSlots[0] == null)
	(hud.body.find_child("GemInventory_attackSpeed",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].equippedGemSlots[0] == "attackSpeed")
	hud._selected_command("removeGem",{"slot":0})
	assert(app.run_domain.state.gemInventory.attackSpeed == 1)
	hud._selected_command("link")
	assert(app.run_domain.state.turrets[0].slotLimit == 2)
	hud.main_tab = "upgrades"
	hud.refresh()
	var upgrade_cost := int(app.run_domain.service.run_upgrade_quote(app.run_domain.state,"towerDamage").cost)
	assert_wallet_refresh(app,hud,buttons(hud.body)[0],"gold",upgrade_cost)
	var upgrade_nodes := node_identities(hud.body)
	hud._command({"kind":"runUpgrade","type":"towerDamage"})
	assert(node_identities(hud.body) == upgrade_nodes,"Run upgrade must retain all three rows, icons and buttons")
	assert(app.run_domain.state.runUpgradeLevels.towerDamage == 1)
	var updated_purchase: Button = buttons(hud.body)[0]
	var updated_price: Label = updated_purchase.find_child("PurchasePrice",true,false)
	assert(updated_price != null and updated_price.text == HudNumber.compact_price(app.run_domain.service.run_upgrade_quote(app.run_domain.state,"towerDamage").cost))
	# Reuse the same purchase callback through rising costs and the maximum.
	var saved_gold: int = app.run_domain.state.gold
	app.run_domain.state.gold = 10000000
	while int(app.run_domain.service.run_upgrade_quote(app.run_domain.state,"towerDamage").cost) > 0:
		updated_purchase.pressed.emit()
		assert(node_identities(hud.body) == upgrade_nodes)
	assert(updated_purchase.disabled)
	assert((updated_purchase.find_child("PurchaseAction",true,false) as Label).text == "최대")
	assert(not updated_purchase.find_child("PurchasePriceRow",true,false).visible)
	app.run_domain.state.gold = saved_gold
	hud.main_tab = "gems"; hud.refresh()
	assert_wallet_refresh(app,hud,find_button(hud.body,"젬 구매 · "),"gemShards",int(app.run_domain.growth.data.constants.gemChoicePurchaseCost))
	hud._command({"kind":"purchaseGemChoice"})
	assert(hud.overlay.visible)
	hud._command({"kind":"chooseRewardGem","type":app.run_domain.state.rewardOptions[0]})
	assert(not hud.overlay.visible)
	app.run_domain.state.phase = "success"
	hud.refresh()
	assert(hud.overlay.visible)
	app.run_domain.state.phase = "failure"
	hud.refresh()
	assert(initial_bounds == hud.battlefield_rect())
	root.content_scale_size = Vector2i(390,844)
	root.size = Vector2i(390,844)
	await process_frame
	hud.refresh()
	print("Layout sizes ", hud.size, " dock ",hud.dock.size)
	assert(hud.dock.size.x <= hud.size.x)
	app.run_domain.state.phase = "preparation"
	hud.main_tab = "turrets"
	for tile in ["core","spawn"]:
		var tile_index: int = map.tiles.find(tile)
		app.selected = Vector2i(tile_index % int(map.columns),tile_index / int(map.columns))
		hud.refresh()
	app.selected = Vector2i(-1,-1); hud.main_tab = "turrets"
	for width in [320,390,440]:
		root.content_scale_size = Vector2i(width,844); root.size = Vector2i(width,844); hud.body_key = ""; hud.refresh(); await process_frame; await process_frame
		assert(hud.dock.size.x <= hud.size.x)
		assert(hud.body.get_combined_minimum_size().x <= hud.scroll.size.x+1)
		assert(hud.top.size.y <= 100)
		assert(hud.top.size.x <= hud.size.x-15,"Resource HUD must stay within its screen margins")
		assert(hud.enemy_caption.get_line_count() == 1 and hud.reward_caption.get_line_count() == 1)
		app.selected = Vector2i(index % int(map.columns),index / int(map.columns)); hud.tab = "stats"; hud.body_key = ""; hud.refresh(); await process_frame; await process_frame
		assert(hud.body.get_child(0).size.y <= 96,"Keep the action panel compact with the 32px target touch area")
		app.selected = Vector2i(-1,-1)
	# Late-wave enemy counts and larger wallets must not wrap the +N marker.
	root.content_scale_size = Vector2i(320,844); root.size = Vector2i(320,844)
	var old_round: int = app.run_domain.state.completedRounds
	app.run_domain.state.completedRounds = 9
	hud.refresh(); await process_frame; await process_frame
	assert(hud.top.size.y <= 100 and hud.top.size.x <= 304)
	for child in hud.enemy_intel.get_children():
		if child is Label: assert(child.get_line_count() == 1)
	app.run_domain.state.completedRounds = old_round
	hud.refresh()
	# Opening the mode menu must not cycle or persist a different mode.
	hud.auto_start.pressed.emit()
	assert(app.auto_start_mode == "pauseEachRound")
	assert(hud.auto_start_popup.item_count == 3)
	assert(hud.auto_start_popup.is_item_checked(0))
	assert(hud.blocks_board_input())
	hud.close_back()
	assert(not hud.auto_start_popup.visible)
	assert(app.auto_start_mode == "pauseEachRound")
	hud.auto_start_popup.id_pressed.emit(2)
	hud.auto_start_popup.hide()
	assert(app.auto_start_mode == "fullAuto")
	assert(hud.auto_start.text == "자동 ▾")
	# A picker alone must shrink back after a larger turret detail was displayed.
	app.selected = Vector2i(-1,-1); hud.main_tab = "turrets"; hud.refresh()
	await process_frame; await process_frame; await process_frame
	assert(hud.dock.size.y <= 210,"Picker must not retain the previous detail panel height")
	assert(hud.detail_panel.get_theme_stylebox("panel").texture != null)
	assert(is_equal_approx(hud.dock.get_global_rect().end.y,root.size.y))
	assert(is_equal_approx(hud.dock.position.x,0) and is_equal_approx(hud.dock.size.x,root.size.x))
	assert(hud.battlefield_rect().end.y <= hud.dock.position.y,"Resting dock must not cover the framed battlefield")
	var actions: Control = hud.bottom.get_node("ActionMargin/BattleActions")
	assert(actions.get_child_count() == 5,"Speed group, spacer, pause, auto mode, main action")
	assert(hud.speed_buttons[1].size.x == 32)
	assert(hud.speed_buttons[1].button_pressed)
	hud.speed_buttons[2].pressed.emit()
	assert(app.scene._native_combat.session.speed == 2)
	assert(not hud.speed_buttons[1].button_pressed and hud.speed_buttons[2].button_pressed)
	var selected_style = hud.main_buttons.turrets.get_theme_stylebox("normal")
	var idle_style = hud.main_buttons.gems.get_theme_stylebox("normal")
	assert(selected_style.border_color != idle_style.border_color)
	assert(hud.resources.text.begins_with("전투력 "))
	assert(hud.reward_caption.text == "예상 보상")
	assert(hud.start.text == "▶ 시작" and not hud.start.disabled and not hud.pause_button.visible)
	hud.start.pressed.emit()
	assert(app.run_domain.state.phase == "wave")
	assert(hud.start.text == "진행 중" and hud.start.disabled and hud.pause_button.visible)
	assert(not hud.pause_indicator.visible)
	hud.pause_button.pressed.emit()
	assert(app.scene._native_combat.session.paused)
	assert(hud.start.text == "▶ 재개" and not hud.start.disabled and not hud.pause_button.visible)
	assert(hud.pause_indicator.visible and hud.pause_indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(not hud.blocks_board_input(), "Manual pause keeps the battlefield interactive")
	var paused_build := Vector2i(-1,-1)
	for tile_index in range(map.tiles.size()):
		var tile := Vector2i(tile_index % int(map.columns),tile_index / int(map.columns))
		if map.tiles[tile_index] == "build" and app.run_domain.selected_id(tile) < 0:
			paused_build = tile; break
	assert(paused_build.x >= 0)
	var paused_state: Dictionary = app.run_domain.state.duplicate(true)
	var paused_count: int = app.run_domain.state.turrets.size()
	app.board_tap(paused_build)
	var paused_install := find_button(hud.body,"설치 · ")
	assert(paused_install != null and not paused_install.disabled, "Paused wave exposes the existing install action")
	paused_install.pressed.emit()
	assert(app.run_domain.state.turrets.size() == paused_count+1 and app.run_domain.selected_id(paused_build) >= 0, "Install action builds during a paused wave")
	assert(app.scene._native_combat.session.paused and app.run_domain.state.phase == "wave", "Installing preserves paused wave")
	app.run_domain.state = paused_state
	app.board_tap(Vector2i(-1,-1))
	hud.main_tab = "turrets"; hud.refresh()
	var bright_alpha: float = hud.pause_indicator.modulate.a
	for frame in range(30): await process_frame
	assert(hud.pause_indicator.modulate.a < bright_alpha - 0.05,"Pause indicator must keep blinking while combat is paused")
	assert(hud.pause_indicator.get_global_rect().get_center().distance_to(hud.get_global_rect().get_center()) < 1.0)
	hud.open_modal("확인")
	assert(not hud.pause_indicator.visible,"Modal owns the center while open")
	hud.close_modal()
	assert(hud.pause_indicator.visible)
	hud.start.pressed.emit()
	assert(not app.scene._native_combat.session.paused)
	assert(not hud.pause_indicator.visible)
	hud.camera_button.pressed.emit()
	assert(app.scene.options.camera == "drone" and hud.camera_button.text == "드론 ↔")
	# Locked models are absent; stage clears reveal them in the same picker.
	var picker: Node = hud.body.get_node("TurretPicker")
	assert(buttons(picker).size() == 4)
	assert(picker.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	await process_frame; await process_frame; await process_frame
	picker.scroll_horizontal = 1000
	await process_frame; await process_frame
	assert(picker.scroll_horizontal == 0,"All six turret choices must fit without scrolling")
	for choice in buttons(picker):
		assert(choice.get_global_rect().end.x <= picker.get_global_rect().end.x+1)
		assert(choice.size.x >= 44,"Six-way picker needs usable narrow-screen targets")
	assert(not picker.get_h_scroll_bar().visible)
	assert(not hud.scroll.get_v_scroll_bar().visible)
	assert(not buttons(picker).any(func(b): return b.text.begins_with("저격") or b.text.begins_with("라이트닝")))
	app.turret_type = "sniper"
	hud.refresh()
	assert(app.turret_type == "arrow","Hidden locked choice must not remain selected")
	app.run_domain.state.progression.clearedStageNumbers = [3]
	hud.refresh()
	await process_frame; await process_frame; await process_frame
	picker = hud.body.get_node("TurretPicker")
	assert(buttons(picker).size() == 5 and find_button(picker,"저격") != null)
	assert(not buttons(picker).any(func(b): return b.text.begins_with("라이트닝")))
	app.run_domain.state.progression.clearedStageNumbers = [3,6]
	hud.refresh()
	await process_frame; await process_frame; await process_frame
	picker = hud.body.get_node("TurretPicker")
	assert(buttons(picker).size() == 6 and find_button(picker,"라이트닝") != null)
	for choice in buttons(picker):
		assert(not choice.disabled)
		assert(choice.get_global_rect().end.x <= picker.get_global_rect().end.x+1)
		assert(choice.size.x >= 44)
	for button in buttons(picker):
		var icon: TextureRect = button.get_child(0).get_child(0)
		assert(icon.texture != null and icon.texture.resource_path.contains("turrets_3d/"))
	hud._select_main("turrets")
	await process_frame; await process_frame; await process_frame
	assert(hud.dock.size.y <= 84,"Closed details must reclaim battlefield space")
	# Long existing names and dynamic amounts must fit through native label sizing.
	var dense_panel := preload("res://ui/turret_action_panel.gd").new()
	root.add_child(dense_panel); dense_panel.size = Vector2(304,0)
	dense_panel.configure({"title":"라이트닝","icon":"ui/hud/turrets_3d/lightning.png","level":"Lv.7 → 8",
		"upgrade_title":"강화 확정","price":"123456 G","maximum":false,"trait_count":2,"active_tab":"stats",
		"upgrade_callback":func(): pass,"trait_callback":func(): pass,"sell_callback":func(): pass,
		"stats_callback":func(): pass,"gems_callback":func(): pass})
	await process_frame; await process_frame; await process_frame
	for label in dense_panel.find_children("*","Label",true,false):
		assert_label_fits(label)
	var dense_price := dense_panel.find_child("TurretUpgradePrice",true,false) as Label
	assert(dense_price.text.trim_suffix(" G") == "123.5K", "Use the same compact format for prices")
	assert(dense_price.get_theme_font_size("font_size") >= 8, "Do not solve narrow prices with unreadable font shrink")
	assert(dense_price.tooltip_text == "123456 G")
	var dense_nodes := node_identities(dense_panel)
	for width in [304,424]:
		dense_panel.size.x = width
		for price in ["602 G","1250 G","9999 G","10000 G","12500 G","123456 G","123456789 G"]:
			dense_panel.update_values({"level":"9→10","upgrade_title":"강화 확정","price":price,"maximum":false,"trait_count":2})
			for frame in range(8): await process_frame
			assert(node_identities(dense_panel) == dense_nodes)
			assert(dense_price.text.trim_suffix(" G") == HudNumber.compact_price(price.trim_suffix(" G").to_int()))
			assert(dense_price.tooltip_text == price)
			assert(dense_price.get_line_count() == 1,"Keep price and unit together")
			assert(dense_price.get_theme_font_size("font_size") >= 8)
			assert_label_fits(dense_price)
			var safe_padding := 6 if dense_price.get_line_count() > 1 else 0
			assert(dense_price.get_global_rect().end.y <= dense_panel.level_action.get_global_rect().end.y-safe_padding+0.1)
			assert(dense_panel.size.x <= width+0.1)
	dense_panel.queue_free()
	# Keep the live action and values through every remaining turret level.
	app.run_domain.state.phase = "preparation"; app.run_domain.state.gold = 10000000
	app.selected = Vector2i(index % int(map.columns),index / int(map.columns))
	hud.main_tab = "turrets"; hud.tab = "stats"; hud.refresh()
	var max_level_button: Button = hud.body.find_child("TurretLevelAction",true,false)
	var level_nodes := node_identities(hud.body)
	if not app.selection_view.level_preview:
		var initial_level: int = app.run_domain.state.turrets[0].level
		max_level_button.pressed.emit()
		assert(app.selection_view.level_preview and int(app.run_domain.state.turrets[0].level) == initial_level)
	while int(app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).level) > 0:
		var before_level: int = app.run_domain.state.turrets[0].level
		var before_gold: int = app.run_domain.state.gold
		var cost: int = app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).level
		max_level_button.pressed.emit()
		assert(int(app.run_domain.state.turrets[0].level) == before_level+1)
		assert(int(app.run_domain.state.gold) == before_gold-cost)
		var next_cost: int = app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).level
		assert(app.selection_view.level_preview == (next_cost > 0))
		assert(node_identities(hud.body) == level_nodes)
	assert(not app.selection_view.level_preview,"Maximum level ends the comparison without predicting an invalid next level")
	assert(max_level_button.disabled)
	# Display abbreviation must not feed the combat-power/core arithmetic.
	var exact_total := 0.0
	var derived: Dictionary = app.run_domain.service.derived(app.run_domain.state)
	for turret in app.run_domain.state.turrets:
		var input: Dictionary = derived.turretStatInputs[turret.type].duplicate(true)
		input.merge({"level":turret.level,"primaryTrait":turret.primaryTrait,"secondaryTrait":turret.secondaryTrait,"gems":turret.equippedGemSlots.filter(func(g): return g != null)},true)
		var stats: Dictionary = app.catalog.turret_stats(turret.type,{"tileSize":48.0,"statInput":input})
		exact_total += float(stats.damage)*float(stats.attackRate)*float(stats.projectileCount if turret.type in ["arrow","cannon"] else 1)
		if turret.type == "magic": exact_total += float(stats.damage)*0.5*float(stats.damageOverTimeDamageMultiplier)
	assert(is_equal_approx(hud.total_dps,exact_total))
	assert(hud.resources.text == "전투력 "+HudNumber.compact(exact_total))
	assert(hud.resources.tooltip_text == "전투력 %.1f" % exact_total)
	assert(not hud._stats(app.run_domain.state,app.run_domain.state.turrets[0]).has("dps"),"HUD decorations must not mutate cached raw stats")
	app.run_domain.state.gold = 10000000; hud.refresh()
	assert(hud.gold_label.text == "10M" and hud.gold_label.tooltip_text == "10000000")
	assert(hud.turret_panel._stat_value({"damage":1234567.89},"damage") == "1.2M")
	assert(hud.turret_panel._stat_value({"damage":1234567.89},"damage",true) == "1234567.9")
	app.scene._native_combat.turrets[str(app.run_domain.state.turrets[0].id)].directDamageDealt = 1234560.0
	hud.refresh()
	assert(hud.damage_label.text == "1.2M" and hud.damage_label.tooltip_text == "누적 피해 1234567.0")
	assert((hud.body.find_child("TurretUpgradePrice",true,false) as Label).text == "최대 레벨")
	assert(hud.turret_panel._stat_value({"damage":1250.25},"damage") == "1,250.3")
	assert(hud.turret_panel._stat_value({"attackRate":1.25},"attackRate") == "1.25회/초")
	assert(hud.build_panel._upgrade_value("waveGold",12500) == "+12.5K G")
	assert(hud.build_panel._upgrade_value("towerDamage",0.25) == "+25%")
	# Narrow purchase controls keep the 9,999 boundary legible and charges exact.
	for width in [320,440]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		for cost in [9999,10000,12500]:
			app.run_domain.growth.data.runUpgrades.towerDamage.baseCost = cost
			app.run_domain.state.runUpgradeLevels.towerDamage = 0
			app.run_domain.state.gold = cost-1
			hud.main_tab = "upgrades"; hud.body_key = ""; hud.refresh()
			for frame in range(5): await process_frame
			var purchase: Button = hud.body.get_node("RunUpgradeRows/Upgrade_towerDamage/Purchase")
			var price: Label = purchase.find_child("PurchasePrice",true,false)
			assert(purchase.disabled and price.text == HudNumber.compact_price(cost))
			assert(price.tooltip_text == "%d G" % cost and price.get_line_count() == 1)
			assert_label_fits(price)
			app.run_domain.state.gold = cost; hud.refresh()
			assert(not purchase.disabled and app.run_domain.state.gold == cost)
	# 999999 and 1000000 both display 1M, but affordability/charges stay exact.
	app.run_domain.growth.data.runUpgrades.towerDamage.baseCost = 1000000
	app.run_domain.state.runUpgradeLevels.towerDamage = 0
	app.run_domain.state.gold = 999999; hud.main_tab = "upgrades"; hud.body_key = ""; hud.refresh()
	var exact_purchase: Button = hud.body.get_node("RunUpgradeRows/Upgrade_towerDamage/Purchase")
	assert(int(app.run_domain.service.run_upgrade_quote(app.run_domain.state,"towerDamage").cost) == 1000000)
	assert(hud.gold_label.text == "1M" and exact_purchase.disabled)
	assert((exact_purchase.find_child("PurchasePrice",true,false) as Label).text == "1M")
	assert(exact_purchase.tooltip_text.contains("1000000"))
	for frame in range(3): await process_frame
	assert((exact_purchase.find_child("PurchasePrice",true,false) as Label).get_line_count() == 1)
	exact_purchase.pressed.emit()
	assert(app.run_domain.state.gold == 999999 and app.run_domain.state.runUpgradeLevels.towerDamage == 0)
	app.run_domain.state.gold = 1000000; hud.refresh()
	assert(hud.gold_label.text == "1M" and not exact_purchase.disabled)
	exact_purchase.pressed.emit()
	assert(app.run_domain.state.gold == 0 and app.run_domain.state.runUpgradeLevels.towerDamage == 1)
	# Refund captions may round up; transaction and exact tooltip never do.
	app.run_domain.state.turrets[0].investedGold = ceili(999999.0*100.0/float(derived.turretRefundPercent))
	hud.main_tab = "turrets"; hud.refresh()
	(hud.body.find_child("TurretSellAction",true,false) as Button).pressed.emit()
	var exact_sale := find_button(hud.modal_body,"판매 · ")
	assert(exact_sale.text == "판매 · +1M 골드")
	assert(exact_sale.tooltip_text == "판매 환급 · 999999 골드")
	exact_sale.pressed.emit()
	assert(app.run_domain.state.gold == 999999 and app.run_domain.state.turrets.is_empty())
	print("PASS battle HUD: build, level, trait, slots, equip/remove, run upgrade, reward, results, narrow viewport")
	hud.queue_free()
	app.queue_free()
	await process_frame
	quit()

func buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button: found.append(child)
		found.append_array(buttons(child))
	return found

func find_button(node: Node,prefix: String) -> Button:
	for button in buttons(node):
		if button.text.begins_with(prefix): return button
	assert(false,"Missing button: "+prefix)
	return null

func assert_wallet_refresh(app: App,hud,button: Button,currency: String,cost: int) -> void:
	assert(cost > 0 and button != null)
	var saved := int(app.run_domain.state[currency])
	var first_child: Node = hud.body.get_child(0)
	var caption := button.text
	for balance in [cost-1,cost,cost+1,0]:
		app.run_domain.state[currency] = balance
		hud.refresh()
		assert(hud.body.get_child(0) == first_child,"Wallet changes must retain the existing controls")
		assert(button.text == caption)
		assert(button.disabled == (balance < cost))
		assert((hud.gold_label if currency == "gold" else hud.shard_label).text == HudNumber.compact(float(balance),0))
	app.run_domain.state[currency] = saved
	hud.refresh()

func node_identities(node: Node) -> Array:
	var result := [node.get_instance_id()]
	for child in node.get_children(): result.append_array(node_identities(child))
	return result

func assert_label_fits(label: Label) -> void:
	for index in range(label.text.length()):
		var bounds := label.get_character_bounds(index)
		assert(bounds.end.x <= label.size.x+0.1 and bounds.end.y <= label.size.y+0.1,"Overflow: "+label.text)
	assert(label.get_visible_line_count() == label.get_line_count(),"Clipped text: "+label.text)
