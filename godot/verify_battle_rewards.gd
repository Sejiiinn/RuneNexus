extends SceneTree
const Fixture = preload("res://verify_battle_hud.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = Fixture.App.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.initialize(app.catalog,{},0,100))
	root.add_child(app)
	var hud = load("res://ui/battle_hud.gd").new()
	hud.app = app; app.hud = hud; root.add_child(hud)
	await process_frame
	var state: Dictionary = app.run_domain.state
	state.gold = 10000; state.gemShards = 100
	var map: Dictionary = app.catalog.stage(0).map
	var index: int = map.tiles.find("build")
	app.selected = Vector2i(index % int(map.columns),index / int(map.columns))
	app.build_selected()
	var bounds: Rect2 = hud.battlefield_rect()
	var empty_style: StyleBox = hud.overlay.get_theme_stylebox("panel")
	assert(app.apply_run_command({"kind":"purchaseGemChoice"}))
	app.run_domain.state.rewardOptions = ["attackSpeed","range","physicalDamage"]
	hud.refresh()
	assert(hud.overlay.visible and hud.blocks_board_input())
	var reward_style: StyleBox = hud.overlay.get_theme_stylebox("panel")
	hud.refresh()
	assert(hud.overlay.get_theme_stylebox("panel") == reward_style)
	hud.rewards.pending_gem = "attackSpeed"; hud.rewards.key = ""; hud.refresh()
	assert(hud.rewards.targeting() and not hud.blocks_board_input())
	assert(bounds == hud.battlefield_rect())
	hud.rewards.board_tap(app.selected)
	assert(app.run_domain.state.phase == "preparation")
	assert(app.run_domain.state.turrets[0].equippedGemSlots[0] == "attackSpeed")
	assert(not hud.overlay.visible and not hud.rewards.targeting())
	assert(hud.overlay.get_theme_stylebox("panel") == empty_style)
	assert(app.apply_run_command({"kind":"purchaseGemChoice"}))
	app.run_domain.state.rewardOptions = ["range","physicalDamage","attackSpeed"]
	hud.rewards.pending_gem = "range"; hud.rewards.key = ""; hud.refresh()
	hud.rewards.board_tap(app.selected)
	assert(hud.rewards.replacing() and hud.blocks_board_input())
	var replacement_style: StyleBox = hud.overlay.get_theme_stylebox("panel")
	assert(replacement_style != reward_style)
	hud.refresh()
	assert(hud.overlay.get_theme_stylebox("panel") == replacement_style)
	assert(hud.rewards.replacement_slot == -1)
	_assert_socket_assets(hud.overlay_body,1)
	var before_choice: Dictionary = app.run_domain.state.duplicate(true)
	assert(_confirm_button(hud.overlay_body).disabled)
	hud.rewards._confirm_replacement()
	assert(app.run_domain.state == before_choice)
	hud.rewards._select_replacement_slot(0)
	assert(hud.rewards.replacement_slot == 0)
	assert("gem_socket_selected.png" in _asset_names(hud.overlay_body))
	assert(not _confirm_button(hud.overlay_body).disabled)
	assert(app.run_domain.state == before_choice)
	assert(hud.close_back() and not hud.rewards.replacing() and hud.rewards.targeting())
	assert(hud.overlay.get_theme_stylebox("panel") == reward_style)
	assert(hud.rewards.replacement_id == -1 and hud.rewards.replacement_slot == -1)
	assert(hud.rewards.pending_gem == "range" and app.run_domain.state == before_choice)
	hud.rewards.board_tap(app.selected)
	assert(hud.rewards.replacing() and hud.rewards.replacement_slot == -1)
	assert(hud.overlay.get_theme_stylebox("panel") == replacement_style)
	assert(_confirm_button(hud.overlay_body).disabled)
	assert(hud.close_back() and hud.rewards.targeting())
	assert(hud.close_back() and not hud.rewards.targeting() and hud.overlay.visible)
	assert(app.run_domain.state.phase == "reward")
	hud.rewards._settle({"kind":"chooseRewardGem","type":"range"})
	assert(app.run_domain.state.gemInventory.range == 1)
	assert(app.run_domain.state.turrets[0].equippedGemSlots[0] == "attackSpeed")
	# Two occupied slots exercise changing the preview without settling the reward.
	app.run_domain.state.turrets[0].slotLimit = 2
	app.run_domain.state.turrets[0].equippedGemSlots = ["attackSpeed","physicalDamage"]
	app.run_domain.state.turrets[0].equippedGems = ["attackSpeed","physicalDamage"]
	assert(app.apply_run_command({"kind":"purchaseGemChoice"}))
	app.run_domain.state.rewardOptions = ["range","physicalDamage","attackSpeed"]
	hud.rewards.pending_gem = "range"; hud.rewards.key = ""; hud.refresh()
	hud.rewards.board_tap(app.selected)
	assert(hud.rewards.replacement_slot == -1)
	before_choice = app.run_domain.state.duplicate(true)
	hud.rewards._select_replacement_slot(0)
	assert(app.run_domain.state == before_choice)
	hud.rewards._select_replacement_slot(1)
	assert(hud.rewards.replacement_slot == 1 and app.run_domain.state == before_choice)
	assert(not _confirm_button(hud.overlay_body).disabled)
	hud.rewards._confirm_replacement()
	assert(app.run_domain.state.phase == "preparation")
	assert(app.run_domain.state.turrets[0].equippedGemSlots == ["attackSpeed","range"])
	assert(app.run_domain.state.gemInventory.get("physicalDamage",0) == int(before_choice.gemInventory.get("physicalDamage",0))+1)
	assert(app.run_domain.state.gemInventory.get("attackSpeed",0) == before_choice.gemInventory.get("attackSpeed",0))
	assert(app.run_domain.state.gemInventory.range == before_choice.gemInventory.range)
	assert(hud.rewards.pending_gem.is_empty() and hud.rewards.replacement_id == -1 and hud.rewards.replacement_slot == -1)
	var after_confirmation: Dictionary = app.run_domain.state.duplicate(true)
	hud.rewards._confirm_replacement()
	assert(app.run_domain.state == after_confirmation)
	assert(not hud.overlay.visible and bounds == hud.battlefield_rect())
	# Buying a slot equips the pending reward atomically without displacing either gem.
	assert(app.apply_run_command({"kind":"purchaseGemChoice"}))
	app.run_domain.state.rewardOptions = ["physicalDamage","range","attackSpeed"]
	hud.rewards.pending_gem = "physicalDamage"; hud.rewards.key = ""; hud.refresh()
	hud.rewards.board_tap(app.selected)
	_assert_socket_assets(hud.overlay_body,2)
	assert(_confirm_button(hud.overlay_body).disabled) # Third slot requires level 5.
	before_choice = app.run_domain.state.duplicate(true)
	hud.rewards._select_replacement_slot(2)
	assert(hud.rewards.replacement_slot == -1 and app.run_domain.state == before_choice)
	app.run_domain.state.turrets[0].level = 5
	app.run_domain.state.gold = 0
	hud.rewards.key = ""; hud.refresh()
	assert(_confirm_button(hud.overlay_body).disabled)
	before_choice = app.run_domain.state.duplicate(true)
	hud.rewards._select_replacement_slot(2)
	assert(hud.rewards.replacement_slot == -1 and app.run_domain.state == before_choice)
	app.run_domain.state.gold = 10000
	hud.rewards.key = ""; hud.refresh()
	assert(_confirm_button(hud.overlay_body).disabled)
	var slot_cost: int = app.run_domain.service.quotes(app.run_domain.state,int(app.run_domain.state.turrets[0].id)).link
	assert(slot_cost > 0)
	before_choice = app.run_domain.state.duplicate(true)
	hud.rewards._select_replacement_slot(2)
	assert(hud.rewards.replacement_slot == 2 and app.run_domain.state == before_choice)
	assert(_confirm_button(hud.overlay_body).text == "슬롯 추가 후 장착 · %d G" % slot_cost)
	assert(not _confirm_button(hud.overlay_body).disabled)
	hud.rewards._confirm_replacement()
	assert(app.run_domain.state.phase == "preparation")
	assert(app.run_domain.state.turrets[0].slotLimit == 3)
	assert(app.run_domain.state.turrets[0].equippedGemSlots == ["attackSpeed","range","physicalDamage"])
	assert(app.run_domain.state.gold == int(before_choice.gold)-slot_cost)
	assert(app.run_domain.state.gemInventory == before_choice.gemInventory)
	assert(hud.rewards.pending_gem.is_empty() and hud.rewards.replacement_id == -1 and hud.rewards.replacement_slot == -1)
	assert(not hud.overlay.visible and bounds == hud.battlefield_rect())
	# The direct action remains equivalent to the unified confirm branch.
	var unified_result: Dictionary = app.run_domain.state.duplicate(true)
	app.run_domain.state = before_choice.duplicate(true)
	hud.rewards.pending_gem = "physicalDamage"; hud.rewards.key = ""; hud.refresh()
	hud.rewards.board_tap(app.selected)
	hud.rewards._buy_replacement_slot()
	assert(app.run_domain.state == unified_result)
	# Six unlocked sockets are a display fixture; progression rules remain unchanged.
	app.run_domain.state.phase = "reward"
	app.run_domain.state.turrets[0].slotLimit = 6
	app.run_domain.state.turrets[0].equippedGemSlots = ["attackSpeed","physicalDamage","criticalChance","lightWeapon","damageAmplifier","multipleProjectiles"]
	hud.rewards.pending_gem = "range"; hud.rewards.replacement_id = int(app.run_domain.state.turrets[0].id)
	hud.rewards.replacement_slot = -1; hud.rewards.key = ""; hud.refresh()
	_assert_socket_assets(hud.overlay_body,6)
	assert(hud.overlay_body.find_child("ReplacementSockets",true,false).get_child_count() == 2)
	before_choice = app.run_domain.state.duplicate(true)
	hud.rewards._select_replacement_slot(5)
	assert(hud.rewards.replacement_slot == 5 and app.run_domain.state == before_choice)
	assert(not _confirm_button(hud.overlay_body).disabled)
	assert(_asset_names(hud.overlay_body).count("gem_socket_selected.png") == 1)
	for phase in ["success","failure"]:
		app.run_domain.state.phase = phase; hud.refresh()
		assert(hud.overlay.visible and hud.blocks_board_input())
		assert(bounds == hud.battlefield_rect())
	print("PASS battle rewards: target equip, preview-only replacement selection, confirmed slot/inventory, back/reset, store, results, stable camera")
	hud.queue_free(); app.queue_free(); await process_frame; quit()

func _confirm_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and (child.text in ["선택한 젬과 교체","장착할 슬롯을 선택하세요"] or child.text.begins_with("슬롯 추가 후 장착")): return child
		var found := _confirm_button(child)
		if found != null: return found
	return null

func _asset_names(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Button and node.icon != null: result.append(node.icon.resource_path.get_file())
	if node is TextureRect and node.texture != null: result.append(node.texture.resource_path.get_file())
	for child in node.get_children(): result.append_array(_asset_names(child))
	return result

func _assert_socket_assets(node: Node, occupied: int) -> void:
	var names := _asset_names(node)
	assert(names.count("gem_socket_empty.png") == occupied)
	assert(names.count("gem_socket_locked.png") == 0)
	assert(names.count("gem_link_active.png")+names.count("gem_link_locked.png") == occupied-int(ceil(occupied/3.0)))
	_assert_socket_targets(node)

func _assert_socket_targets(node: Node) -> void:
	if node is TextureRect and node.texture != null and node.texture.resource_path.get_file().begins_with("gem_socket_"):
		var target := node.get_parent() as Button
		assert(target != null and target.custom_minimum_size.x >= 52 and target.custom_minimum_size.y >= 52)
	for child in node.get_children(): _assert_socket_targets(child)
