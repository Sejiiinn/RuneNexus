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
	assert("획득한 기관총 모듈 없음" in _texts(host.body))
	var item := {"id":"test_a", "turretType":"arrow", "part":"core", "grade":"rare", "equipped":false, "options":[{"type":"damageIncrease", "value":12}]}
	var second: Dictionary = item.duplicate(true)
	second.id = "test_b"
	second.equipped = true
	host.progression.turretModules.items = [item, second, {"id":"test_c", "turretType":"cannon", "part":"barrel", "grade":"normal", "equipped":false, "options":[]}]
	helper.modules()
	assert(helper.filtered_items().size() == 2)
	helper.select_part("barrel")
	assert(helper.filtered_items().is_empty())
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
		var grid: GridContainer = host.body.find_child("ModuleInventoryGrid",true,false)
		assert(grid != null)
		assert(grid.columns == (5 if grid.size.x<324 else 6))
		assert(grid.get_child_count()%grid.columns==0,"Final inventory row filled with empty slots")
		assert(grid.columns == (5 if width==320 else 6),"Responsive 5/6 columns")
		for cell in grid.get_children(): assert(absf(cell.size.x-cell.size.y)<1.1,"Inventory cells stay square")
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
	print("PASS lobby_collection: module filter/equip/unequip, service immutability, daily/weekly progress/claimed/clock guard, 320/440 widths")
	host.queue_free()
	await process_frame
	quit()
