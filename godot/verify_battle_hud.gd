extends SceneTree
## UI smoke with the actual catalog/command owner, no editor or persistent save.
class App extends Node:
	var catalog = preload("res://content/content_catalog.gd").new()
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
	app.run_domain.state.gold = 10000
	app.run_domain.state.gemShards = 100
	var map: Dictionary = app.catalog.stage(0).map
	var index: int = map.tiles.find("build")
	app.selected = Vector2i(index % int(map.columns),index / int(map.columns))
	hud.refresh()
	hud.on_board_selection()
	hud.refresh()
	assert(app.stage_source_calls == 1)
	var install := find_button(hud.body,"설치 · ")
	assert_wallet_refresh(app,hud,install,"gold",app.run_domain.service.build_cost(app.run_domain.state,"arrow"))
	assert(app.stage_source_calls == 1)
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
	assert(hud.body.get_child(0).size.y <= 38)
	app.scene._native_combat.turrets = {str(app.run_domain.state.turrets[0].id): {"directDamageDealt":123.0,"splashDamageDealt":7.0}}
	hud.refresh()
	assert(hud.damage_label.text.ends_with("130.0"))
	assert(hud.status.autowrap_mode == TextServer.AUTOWRAP_OFF)
	assert(hud.wave_label.autowrap_mode == TextServer.AUTOWRAP_OFF)
	(hud.body.find_child("TurretLevelAction",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].level == 1)
	assert(app.selection_view.level_preview)
	assert(hud._stat_value({"range":96.0},"range") == "2.00칸")
	assert(hud._stat_value({"projectileCount":3},"projectileCount") == "3발")
	assert(hud._stat_value({"aimDuration":0.75},"aimDuration") == "0.75초")
	var stat_scroll = hud.body.find_child("TurretStatsScroll",true,false)
	assert(stat_scroll != null and stat_scroll.custom_minimum_size.y == 96)
	assert(stat_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	(hud.body.find_child("TurretLevelAction",true,false) as Button).pressed.emit()
	assert(app.run_domain.state.turrets[0].level == 2)
	hud._selected_command("level")
	(hud.body.find_child("TurretTraitAction",true,false) as Button).pressed.emit()
	for button in buttons(hud.modal_body):
		if button.text.begins_with("과열 탄창"):
			button.pressed.emit(); break
	assert(app.run_domain.state.turrets[0].primaryTrait == null)
	for button in buttons(hud.modal_body):
		if button.text.begins_with("✓ 과열 탄창"):
			button.pressed.emit(); break
	assert(app.run_domain.state.turrets[0].primaryTrait == "overheatMagazine")
	(hud.body.find_child("TurretSellAction",true,false) as Button).pressed.emit()
	assert(hud.modal_active() and app.scene._native_combat.session.paused)
	assert(hud.modal_panel.get_theme_stylebox("panel") is StyleBoxTexture)
	var sale := find_button(hud.modal_body,"판매 · ")
	assert(sale.get_theme_stylebox("normal") is StyleBoxTexture)
	assert(sale.get_theme_stylebox("disabled").texture.resource_path.ends_with("native/disabled.png"))
	assert(sale.get_theme_stylebox("normal").texture_margin_left == 11)
	hud.close_modal()
	assert(not app.scene._native_combat.session.paused)
	app.run_domain.state.progression["researchLevels"] = {"turretTargetPriority":1}
	hud._priority()
	for button in buttons(hud.modal_body):
		if button.text.begins_with("최대 체력"):
			button.pressed.emit(); break
	assert(app.run_domain.state.turrets[0].targetPriority == "strongest")
	assert(not app.scene._native_combat.session.paused)
	hud.tab = "gems"
	hud.refresh()
	var sockets := buttons(hud.body).filter(func(button): return str(button.name).begins_with("EquippedSlot"))
	var link_cost := int(app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).link)
	assert(sockets.size() == int(app.run_domain.state.turrets[0].slotLimit))
	var buy_slot := hud.body.find_child("BuyGemSlot",true,false) as Button
	assert(buy_slot != null)
	assert_wallet_refresh(app,hud,buy_slot,"gold",link_cost)
	app.run_domain.state.gemInventory = {"attackSpeed":1}
	hud.refresh()
	hud.selected_slot = 0; hud.refresh()
	for button in buttons(hud.body):
		if button.text.begins_with("가속 ×"):
			button.pressed.emit(); break
	assert(app.run_domain.state.turrets[0].equippedGemSlots[0] == null)
	for button in buttons(hud.body):
		if button.text.begins_with("가속 ×"):
			button.pressed.emit(); break
	assert(app.run_domain.state.turrets[0].equippedGemSlots[0] == "attackSpeed")
	hud._selected_command("removeGem",{"slot":0})
	assert(app.run_domain.state.gemInventory.attackSpeed == 1)
	hud._selected_command("link")
	assert(app.run_domain.state.turrets[0].slotLimit == 2)
	hud.main_tab = "upgrades"
	hud.refresh()
	var upgrade_cost := int(app.run_domain.service.run_upgrade_quote(app.run_domain.state,"towerDamage").cost)
	assert_wallet_refresh(app,hud,buttons(hud.body)[0],"gold",upgrade_cost)
	hud._command({"kind":"runUpgrade","type":"towerDamage"})
	assert(app.run_domain.state.runUpgradeLevels.towerDamage == 1)
	assert(buttons(hud.body)[0].text == "%d 골드" % app.run_domain.service.run_upgrade_quote(app.run_domain.state,"towerDamage").cost)
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
		assert(hud.body.get_child(0).size.y <= 38)
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
	hud.pause_button.pressed.emit()
	assert(app.scene._native_combat.session.paused)
	assert(hud.start.text == "▶ 재개" and not hud.start.disabled and not hud.pause_button.visible)
	hud.start.pressed.emit()
	assert(not app.scene._native_combat.session.paused)
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
		assert((hud.gold_label if currency == "gold" else hud.shard_label).text == str(balance))
	app.run_domain.state[currency] = saved
	hud.refresh()
