extends SceneTree
const GrowthUI = preload("res://ui/lobby_growth.gd")
const Rules = preload("res://app/growth_rules.gd")
class Host extends Control:
	var body: VBoxContainer
	var app: Dictionary
	var state := {"runes":10000, "clearedStageNumbers":[], "researchLevels":{}, "activeResearches":[]}
	var helper
	var modal: VBoxContainer
	var service := ""
	var commands: Array = []
	func _p() -> Dictionary: return state
	func diamonds() -> int: return int(state.get("freeDiamonds",0)) + int(state.get("paidDiamonds",0))
	func _title(id: String) -> String: return {"turretLevelUpOptimization":"포탑 강화 비용 최적화", "researchCostEfficiency":"연구 비용 효율"}.get(id, id)
	func refresh() -> void: pass
	func open_modal(_title: String) -> VBoxContainer:
		close_modal()
		modal = VBoxContainer.new()
		modal.size.x = size.x - 24
		add_child(modal)
		return modal
	func close_modal() -> void:
		if is_instance_valid(modal):
			remove_child(modal)
			modal.queue_free()
			modal = null
	func _change(command: Dictionary) -> void:
		commands.append(command)
		var result: Dictionary = app.run_domain.growth.execute(state, command)
		assert(result.ok)
		state = result.state
	func _service(label: String, _context: Dictionary = {}) -> void: service = label
	func clear() -> void:
		for child in body.get_children(): body.remove_child(child); child.queue_free()
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var host := Host.new()
	root.add_child(host)
	var growth := Rules.new()
	assert(growth.load_catalog())
	host.app = {"run_domain":{"growth":growth}}
	host.body = VBoxContainer.new()
	host.add_child(host.body)
	host.theme = preload("res://ui/app_theme.gd").create()
	var ui := GrowthUI.new()
	ui.setup(host)
	assert(ui.TITLES.nexusHp == "넥서스 체력" and ui.TITLES.turretTargetPriority == "전술 명령")
	assert(ui.TITLES.linkMaintenance == "기초 연결 공학")
	assert(ui.upgrade_requirement("criticalDamage") == 4)
	assert(ui.upgrade_requirement("linkCostOptimization") == 9)
	assert(ui.effect_value("criticalDamage", 1) == "+1%p")
	assert(ui.effect_value("linkCostOptimization", 1) == "−1%")
	assert(ui.effect_value("emergencySale", 1) == "76%")
	assert(ui.research_status("linkExpansionOne").begins_with("스테이지"))
	ui._details("researchEfficiency")
	assert(ui.RESEARCH_DESCRIPTIONS.researchEfficiency.contains("2배 빠르게"))
	assert(_texts(host.modal).contains("기본 해금"))
	assert(host.modal.get_meta("refresh",Callable()).is_valid(),"Detail opts into progression refresh")
	var old_modal := host.modal
	host.modal.get_meta("refresh").call()
	assert(host.modal != old_modal,"Progression refresh replaces stale detail")
	assert(_texts(host.modal).contains(ui.RESEARCH_DESCRIPTIONS.researchEfficiency))
	assert(host.commands.is_empty())
	ui._submit("startResearch", "researchEfficiency")
	assert(host.state.activeResearches.size() == 1)
	ui._cancel_confirm("researchEfficiency")
	assert(host.state.activeResearches.size() == 1)
	ui._details("researchEfficiency")
	assert(host.state.activeResearches.size() == 1)
	ui._submit("cancelResearch", "researchEfficiency")
	assert(host.state.activeResearches.is_empty())
	host.state.freeDiamonds = 80
	host.state.paidDiamonds = 20
	ui._submit("startResearch", "researchEfficiency")
	ui.research()
	assert(_texts(host.body).contains("즉시 완료"),"Slot exposes direct instant completion")
	assert(_texts(host.body).contains("×"),"Slot exposes direct cancel")
	ui._details("researchEfficiency")
	var clock_before := _texts(host.modal)
	host.state.activeResearches[0].startedAtMillis = int(Time.get_unix_time_from_system()*1000)-int(host.state.activeResearches[0].durationMillis)+59000
	for child in host.modal.get_children():
		if child is Timer: child.timeout.emit()
	assert(_texts(host.modal).contains("즉시 완료 · 다이아 1"),"Open detail recomputes minute-boundary cost")
	assert(_texts(host.modal)!=clock_before,"Open detail updates remaining time")
	ui._instant_confirm("researchEfficiency")
	assert(host.service.is_empty(),"Instant completion requires confirmation")
	host.close_modal()
	ui._submit("cancelResearch","researchEfficiency")
	host.clear()
	host.state.clearedStageNumbers = range(1,16)
	for width in [320, 440]:
		host.size = Vector2(width, 900)
		host.body.size = Vector2(width - 28, 900)
		for page in ["전투", "경제", "연구"]:
			host.clear()
			if page == "연구": ui.research()
			else: ui.category = page; ui.upgrades()
			await process_frame
			await process_frame
			if page != "연구":
				assert(host.body.get_child_count() == 1, "Upgrade tabs belong outside scrolling cards")
				assert(host.body.get_child(0).get_child(0).size.y < 300, "Card inline labels must not wrap vertically")
			else:
				assert(host.body.get_child_count() == 4, "Research slots and three framed groups")
			assert(host.body.get_combined_minimum_size().x <= width - 28, "%s overflow at %d: %s" % [page, width, host.body.get_combined_minimum_size()])
	print("PASS growth pages: 320/440 layout, prerequisites, effects, detail-only selection, start/cancel confirmation")
	host.free()
	quit()

func _texts(node: Node) -> String:
	var value: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): value += "\n"+_texts(child)
	return value
