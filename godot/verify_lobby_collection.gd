extends SceneTree
const Collection = preload("res://ui/lobby_collection.gd")
const Growth = preload("res://app/growth_rules.gd")
const Quest = preload("res://app/quest_progress.gd")
class Host extends Control:
	var progression: Dictionary = {"turretModules":{"items":[], "tickets":2}, "clearedStageNumbers":[]}
	var body: VBoxContainer
	var helper
	var commands: Array = []
	var growth
	func _p() -> Dictionary: return progression
	func _title(value: String) -> String: return {"arrow":"기관총", "cannon":"대포", "magic":"화염", "frost":"냉각", "sniper":"저격", "lightning":"번개"}.get(value, value)
	func _change(command: Dictionary) -> void:
		commands.append(command)
		var request: Dictionary = command.duplicate()
		request.type = request.kind
		var result: Dictionary = growth.execute(progression, request)
		assert(result.ok)
		progression = result.state
		helper.modules()

func _initialize() -> void: call_deferred("_run")

func _texts(node: Node) -> String:
	var value := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): value += _texts(child)
	return value

func _find(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := _find(child, label)
		if found: return found
	return null

func _assert_empty_inventory(body: Control, width: int) -> void:
	var grid := body.find_child("ModuleInventoryGrid", true, false) as GridContainer
	assert(grid != null and grid.columns == (5 if width == 320 else 6))
	assert(grid.get_child_count() == grid.columns, "Empty inventory shows exactly one row")
	assert(not "획득한 " in _texts(body), "Empty inventory has no acquired-none message")
	assert(body.find_child("ModuleBulkDisassembleAction", true, false) == null)
	for cell in grid.get_children():
		assert(cell is PanelContainer and cell.get_child_count() == 0, "Empty cells have no item or action")
		assert(cell.get_theme_stylebox("panel") is StyleBoxTexture)
		assert(absf(cell.size.x - cell.size.y) < 1.1, "Empty inventory cells stay square")

func _assert_module_actions(body: Control, selected: Dictionary = {}) -> void:
	var detail := body.find_child("ModuleDetail", true, false) as Control
	var header := body.find_child("ModuleDetailHeader", true, false) as Control
	var title := body.find_child("ModuleDetailTitle", true, false) as Label
	var actions := body.find_child("ModuleDetailActions", true, false) as Control
	assert(detail.get_global_rect().encloses(header.get_global_rect()), "Header stays inside the original detail panel")
	assert(title.get_global_rect().end.x <= actions.get_global_rect().position.x, "Full title cannot overlap right-side actions")
	assert(title.get_line_count() <= 2, "Module title uses at most two lines")
	var first_effect := body.find_child("ModuleDetailEffect_0", true, false) as Control
	assert(first_effect.get_global_rect().position.y >= header.get_global_rect().end.y, "Effects remain below the detail header")
	assert(detail.size.y < 142, "Detail no longer reserves the removed lower action row")
	for i in range(3):
		var effect := body.find_child("ModuleDetailEffect_%d" % i, true, false) as Control
		assert(detail.get_global_rect().encloses(effect.get_global_rect()), "All three effect rows fit inside the compact detail panel")
	assert(actions.get_parent() == header, "Actions are inside the upper detail header")
	if selected.is_empty():
		assert(actions.get_child_count() == 0)
	else:
		var title_separator := " ·\n" if header.size.x < 320 else " · "
		assert(title.text == Collection.GRADES[selected.grade] + title_separator + Collection.MODULE_NAMES[selected.turretType + "_" + selected.part], "Compact title breaks at the grade/name boundary")
		var equip := body.find_child("ModuleEquipAction", true, false) as Button
		var disassemble := body.find_child("ModuleDisassembleAction", true, false) as Button
		assert(actions.get_child_count() == 2 and equip.get_parent() == actions and disassemble.get_parent() == actions)
		assert(equip.text == ("장착 해제" if selected.get("equipped", false) else "장착"))
		assert(disassemble.text == "분해 ·\n다이아 %d" % {"normal":2,"magic":5,"rare":20,"unique":50}[selected.grade])
		assert(disassemble.disabled == selected.get("equipped", false))
		assert(equip.get_theme_stylebox("normal") is StyleBoxTexture and disassemble.get_theme_stylebox("normal") is StyleBoxTexture, "Reuse the filled metallic PNG faces")
		assert(actions.get_global_rect().encloses(equip.get_global_rect()) and actions.get_global_rect().encloses(disassemble.get_global_rect()))
	var bulk := body.find_child("ModuleBulkDisassembleAction", true, false) as Button
	if bulk != null:
		var info := bulk.get_parent() as Control
		var count_label := body.find_child("ModuleInventoryCount", true, false) as Control
		assert(bulk.size.x >= 90 and bulk.size.x <= 110 and is_equal_approx(bulk.size.y, 32), "Bulk action remains compact")
		assert(is_equal_approx(bulk.get_global_rect().end.x, info.get_global_rect().end.x), "Bulk action is right aligned with inventory count")
		assert(count_label.get_global_rect().end.x <= bulk.get_global_rect().position.x)

func _run() -> void:
	var host := Host.new()
	host.theme = preload("res://ui/battle_theme.gd").create()
	root.add_child(host)
	host.body = VBoxContainer.new()
	host.add_child(host.body)
	host.growth = Growth.new()
	assert(host.growth.load_catalog())
	var helper := Collection.new()
	helper.setup(host)
	host.helper = helper
	helper.modules()
	for width in [320, 440]:
		host.size = Vector2(width, 900)
		host.body.size = Vector2(width - 24, 850)
		helper.modules()
		for i in range(6): await process_frame
		_assert_empty_inventory(host.body, width)
	var item := {"id":"test_a", "turretType":"arrow", "part":"core", "grade":"rare", "equipped":false, "options":[{"type":"damageIncrease", "value":12}]}
	var second: Dictionary = item.duplicate(true)
	second.id = "test_b"
	second.equipped = true
	host.progression.turretModules.items = [item, second, {"id":"test_c", "turretType":"cannon", "part":"barrel", "grade":"normal", "equipped":false, "options":[]}]
	helper.modules()
	assert(helper.filtered_items().size() == 2)
	helper.select_part("barrel")
	assert(helper.filtered_items().is_empty())
	for width in [320, 440]:
		host.size = Vector2(width, 900)
		host.body.size = Vector2(width - 24, 850)
		helper.modules()
		for i in range(6): await process_frame
		_assert_empty_inventory(host.body, width)
	helper.select_part("core")
	helper.select_item(item)
	assert("과열 연산 코어" in _texts(host.body))
	assert("피해 +12%" in _texts(host.body))
	_find(host.body, "장착").pressed.emit()
	assert(host.progression.turretModules.items[0].equipped)
	assert(not host.progression.turretModules.items[1].equipped)
	_find(host.body, "장착 해제").pressed.emit()
	assert(not host.progression.turretModules.items[0].equipped)
	var original: Dictionary = host.progression.duplicate(true)
	helper._module_service("모듈 뽑기")
	assert(host.progression == original)
	assert("계정 서버 연결" in _texts(host.body))
	for width in [320, 440]:
		host.size = Vector2(width, 1100)
		host.body.size = Vector2(width - 24, 1050)
		helper.modules()
		await process_frame
		await process_frame
		assert(host.body.get_combined_minimum_size().x <= width - 24)
		_assert_module_actions(host.body, host.progression.turretModules.items[0])
		var grid: GridContainer = host.body.find_child("ModuleInventoryGrid",true,false)
		assert(grid != null)
		assert(grid.columns == (5 if grid.size.x<324 else 6))
		assert(grid.get_child_count()%grid.columns==0,"Final inventory row filled with empty slots")
		assert(grid.columns == (5 if width==320 else 6),"Responsive 5/6 columns")
		for cell in grid.get_children(): assert(absf(cell.size.x-cell.size.y)<1.1,"Inventory cells stay square")
	# The module page reserves the same details/action band for 0/1/3 options.
	var saved_items: Array = host.progression.turretModules.items.duplicate(true)
	var three_options: Dictionary = item.duplicate(true)
	three_options.id = "three_options"
	three_options.options = [{"type":"highLevelUpgradeCostDiscount", "value":25}, {"type":"lightningChainRangeIncrease", "value":12}, {"type":"criticalDamageBonus", "value":40}]
	host.progression.turretModules.items.append(three_options)
	for part in ["core", "barrel", "frame"]:
		var equipped: Dictionary = item.duplicate(true)
		equipped.id = "equipped_" + part
		equipped.part = part
		equipped.equipped = true
		equipped.grade = {"core":"normal", "barrel":"magic", "frame":"unique"}[part]
		host.progression.turretModules.items.append(equipped)
	for i in range(100):
		var extra: Dictionary = item.duplicate(true)
		extra.id = "inventory_%d" % i
		host.progression.turretModules.items.append(extra)
	for width in [320, 440]:
		host.body.size = Vector2(width - 24, 620)
		helper.select_part("")
		for i in range(6): await process_frame
		_assert_module_actions(host.body)
		var stable := {}
		for name in ["ModulePageFrame", "ModuleEquipment", "ModuleDetail", "ModuleInventoryPanel", "ModuleInventoryScroll"]:
			stable[name] = (host.body.find_child(name, true, false) as Control).get_global_rect()
		for selected in [item, three_options]:
			helper.select_item(selected)
			for i in range(6): await process_frame
			_assert_module_actions(host.body, selected)
			for name in stable:
				assert((host.body.find_child(name, true, false) as Control).get_global_rect() == stable[name], "Selection must keep " + name + " fixed")
		var scroll := host.body.find_child("ModuleInventoryScroll", true, false) as ScrollContainer
		assert(not scroll.get_v_scroll_bar().visible and not scroll.get_h_scroll_bar().visible)
		assert(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page)
		scroll.scroll_vertical = 100
		helper.select_item(item)
		for i in range(6): await process_frame
		assert(helper.inventory_scroll.scroll_vertical == 100, "Selection keeps inventory position")
		for part in ["core", "barrel", "frame"]:
			var slot := host.body.find_child("ModuleSlot_" + part, true, false) as Control
			var icon := slot.find_child("EquippedModuleIcon", true, false)
			assert(icon != null and icon.get_meta("module_id") == "equipped_" + part)
			assert(icon.part == part and icon.grade == {"core":"normal", "barrel":"magic", "frame":"unique"}[part])
			assert(slot.get_global_rect().encloses(icon.get_global_rect()), "Equipped icon fits the slot")
			var art := icon.find_child("ModuleIconTexture", true, false) as TextureRect
			assert(art != null and art.texture != null and art.modulate == Color.WHITE, "Equipment preserves final grade artwork")
			assert(icon.icon_path == "res://assets/app/turret_modules/icons/%s_%s.png" % [part, icon.grade])
		var inventory_icon := host.body.find_child("Module_" + str(item.id), true, false) as Button
		var inventory_art := inventory_icon.find_child("ModuleIconTexture", true, false) as TextureRect
		assert(inventory_art != null and inventory_art.texture != null and inventory_art.modulate == Color.WHITE)
		assert(inventory_icon.find_child("ModuleIcon", true, false) == null, "Inventory uses its existing card frame without a duplicate icon frame")
		assert(inventory_art.get_global_rect().get_center().distance_to(inventory_icon.get_global_rect().get_center()) <= 1.0, "Inventory artwork stays centered within container pixel rounding")
		# All prices and the longer unequip caption must fit the same fixed header.
		for grade in ["normal", "magic", "rare", "unique"]:
			for equipped in [false, true]:
				var choice: Dictionary = three_options.duplicate(true)
				choice.id = "long_title_" + grade
				choice.turretType = "lightning"
				choice.grade = grade
				choice.equipped = equipped
				host.progression.clearedStageNumbers = [3, 6]
				host.progression.turretModules.items.append(choice)
				helper.select_turret("lightning")
				helper.select_item(choice)
				for i in range(6): await process_frame
				_assert_module_actions(host.body, choice)
				host.progression.turretModules.items.pop_back()
		helper.select_turret("arrow")
	host.progression.turretModules.items = saved_items
	helper.modules()
	for i in range(3): await process_frame
	assert(host.body.find_child("ModuleSlot_core", true, false).find_child("EquippedModuleIcon", true, false) == null, "Empty slot has no equipped icon")
	var quests := Quest.new()
	host.progression = quests.refresh(host.progression, 1800450000000)
	host.progression = quests.record(host.progression, "clearWaves", 30, 1800450000000)
	helper.quests(host.body)
	assert("웨이브 30회 클리어" in _texts(host.body))
	assert("30 / 30" in _texts(host.body))
	original = host.progression.duplicate(true)
	_find(host.body, "수령").pressed.emit()
	assert(host.progression == original)
	assert("계정 서버 연결" in _texts(host.body))
	helper.set_period("weekly", host.body)
	assert("웨이브 150회 클리어" in _texts(host.body))
	assert("30 / 150" in _texts(host.body))
	for width in [320, 440]:
		host.body.size = Vector2(width - 64, 1050)
		helper.quests(host.body)
		await process_frame
		await process_frame
		assert(host.body.get_combined_minimum_size().x <= width - 64)
		for row in host.body.get_children():
			if row is PanelContainer: assert(row.size.y < 110, "Quest row must not stack scalar captions vertically")
	host.progression.claimedWeeklyQuestRewards = ["clearWaves"]
	helper.quests(host.body)
	assert(_find(host.body, "수령 완료").disabled)
	host.progression.dailyQuestClockRollbackDetected = true
	helper.set_period("daily", host.body)
	assert(_find(host.body, "수령") == null)
	print("PASS lobby_collection: module filter/equip/unequip, service immutability, daily/weekly progress/claimed/clock guard, 320/440 widths, fixed module bounds, upper-right metallic actions/all grade refunds/compact bulk, inventory-only hidden-bar scroll position, equipped part/grade icons")
	host.queue_free()
	await process_frame
	quit()
