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
	func progression() -> Dictionary: return state
	func diamonds() -> int: return int(state.get("freeDiamonds",0)) + int(state.get("paidDiamonds",0))
	func display_title(id: String) -> String: return {"turretLevelUpOptimization":"포탑 강화 비용 최적화", "researchCostEfficiency":"연구 비용 효율"}.get(id, id)
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
	func refresh_modal_body(expected_modal: Control) -> VBoxContainer:
		if not is_instance_valid(expected_modal) or expected_modal != modal: return null
		for child in modal.get_children(): modal.remove_child(child); child.queue_free()
		return modal
	func apply_growth_change(command: Dictionary) -> void:
		commands.append(command)
		var result: Dictionary = app.run_domain.growth.execute(state, command)
		assert(result.ok)
		state = result.state
	func open_service(label: String, _context: Dictionary = {}) -> void: service = label
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
	_boss_training_card(host, ui)
	_damage_training_cards(host, ui)
	_poison_training_card(host, ui)
	assert(ui.TITLES.nexusHp == "넥서스 체력" and ui.TITLES.turretTargetPriority == "전술 명령")
	assert(ui.TITLES.linkMaintenance == "기초 연결 공학")
	assert(ui.upgrade_requirement("criticalDamage") == 4)
	assert(ui.upgrade_requirement("linkCostOptimization") == 9)
	assert(ui.effect_value("criticalDamage", 1) == "+1%p")
	assert(ui.effect_value("linkCostOptimization", 1) == "−1%")
	assert(ui.effect_value("emergencySale", 1) == "76%")
	for id in ["emergencySale", "turretTargetPriority"]:
		assert(ui.research_status(id) == "연구 가능", "Initial research is available in a fresh lobby: " + id)
	assert(ui.research_status("linkExpansionOne").begins_with("스테이지"))
	ui._details("researchEfficiency")
	assert(ui.RESEARCH_DESCRIPTIONS.researchEfficiency.contains("2배 빠르게"))
	assert(not _texts(host.modal).contains("해금 조건") and not _texts(host.modal).contains("기본 해금"),"Detail omits the unlock-condition row")
	assert(host.modal.get_meta("refresh",Callable()).is_valid(),"Detail opts into progression refresh")
	var old_modal := host.modal
	host.modal.get_meta("refresh").call()
	assert(host.modal == old_modal,"Progression refresh updates detail in the existing modal")
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
	assert(_texts(host.body).contains("중단"),"Slot exposes direct cancel")
	ui._details("researchEfficiency")
	var clock_before := _texts(host.modal)
	host.state.activeResearches[0].startedAtMillis = int(Time.get_unix_time_from_system()*1000)-int(host.state.activeResearches[0].durationMillis)+59000
	for child in host.modal.get_children():
		if child is Timer: child.timeout.emit()
	assert(_texts(host.modal).contains("즉시 완료 · 다이아 1"),"Open detail recomputes minute-boundary cost")
	assert(_texts(host.modal)!=clock_before,"Open detail updates remaining time")
	ui._instant_confirm("researchEfficiency")
	assert(host.service == "연구 즉시 완료","Instant completion opens the single service confirmation")
	host.close_modal()
	ui._submit("cancelResearch","researchEfficiency")
	host.clear()
	host.state.clearedStageNumbers = range(1,31)
	_status_tabs(host, ui)
	# The app never renders below 440 logical px; 760 covers fold/tablet widths.
	for width in [440, 760]:
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
	print("PASS growth pages: 440/760 layout, prerequisites, effects, detail-only selection, start/cancel confirmation")
	host.free()
	quit()

func _boss_training_card(host, ui) -> void:
	var original: Dictionary = host.state.duplicate(true)
	ui.category = "전투"
	ui.upgrades()
	assert(not _texts(host.body).contains("대형 표적 훈련"), "Boss training is hidden before its fixed stage gate")
	host.clear()
	ui.status = "잠김"
	ui.upgrades()
	var locked := _card_with_title(host.body, "대형 표적 훈련")
	assert(locked != null and _texts(locked).contains("2-9 클리어") and _buttons(locked).is_empty(), "Locked tab previews the boss training with its stage gate")
	assert(_texts(locked).contains("다음 +0.5%"), "Locked rows preview the first level effect")
	var order: Array = host.body.get_child(0).get_children().map(func(row): return row.get_meta("upgrade_id"))
	assert(order == ["criticalDamage", "physicalDamageTraining", "elementalDamageTraining", "poisonDamageTraining", "bossDamageTraining", "directDamageTraining", "splashDamageTraining", "damageOverTimeTraining"], "Locked rows follow their unlock stage: %s" % [order])
	ui.status = "해금"
	host.clear()
	host.state.clearedStageNumbers = [24]
	host.state.runes = 200
	ui.upgrades()
	assert(ui.upgrade_requirement("bossDamageTraining") == 24)
	assert(_texts(host.body).contains("대형 표적 훈련"))
	assert(ui.effect_value("bossDamageTraining", 1) == "+0.5%")
	assert(ui.effect_value("bossDamageTraining", 40) == "+20%")
	var card: Control = host.body.get_child(0).get_child(host.body.get_child(0).get_child_count()-1)
	assert(_texts(card).contains("다음 +0.5%") and _texts(card).contains("200"))
	var buttons: Array = _buttons(card)
	assert(buttons.size() == 1 and not buttons[0].disabled)
	buttons[0].pressed.emit()
	assert(host.state.bossDamageTrainingUpgradeLevel == 1 and host.state.runes == 0, "Boss training card purchases the correct upgrade")
	host.clear()
	ui.upgrades()
	card = host.body.get_child(0).get_child(host.body.get_child(0).get_child_count()-1)
	assert(_texts(card).contains("현재 +0.5%") and _texts(card).contains("다음 +1%") and _buttons(card)[0].disabled)
	host.state.bossDamageTrainingUpgradeLevel = 40
	host.state.runes = 100000
	host.clear()
	ui.upgrades()
	assert(_card_with_title(host.body, "대형 표적 훈련") == null, "Maxed upgrades leave the unlocked tab")
	host.clear()
	ui.status = "완료"
	ui.upgrades()
	card = _card_with_title(host.body, "대형 표적 훈련")
	assert(_texts(card).contains("현재 +20%") and _texts(card).contains("최대 레벨") and not _texts(card).contains("다음"))
	assert(_buttons(card).is_empty() and card.get_meta("level_text") == "Lv.40/40")
	ui.status = "해금"
	host.clear()
	host.state = original
	host.commands.clear()

# Poison damage training opens with the poison turret on the 2-8 first clear.
func _poison_training_card(host, ui) -> void:
	var original: Dictionary = host.state.duplicate(true)
	var title: String = ui.TITLES.poisonDamageTraining
	host.state.progressionVersion = 1
	host.state.clearedStageNumbers = [17, 22]
	host.state.runes = 10000
	ui.category = "전투"
	ui.upgrades()
	assert(not _texts(host.body).contains(title), "Poison training stays hidden before 2-8")
	assert(_texts(host.body).contains(ui.TITLES.elementalDamageTraining))
	host.clear()
	host.state.clearedStageNumbers.append(23)
	ui.upgrades()
	var card := _card_with_title(host.body, title)
	assert(card != null and ui.upgrade_requirement("poisonDamageTraining") == 23)
	assert(card.get_meta("level_text") == "Lv.0/50" and ui.effect_value("poisonDamageTraining", 50) == ui.effect_value("elementalDamageTraining", 50))
	var cost: int = host.app.run_domain.growth.data.permanentUpgrades.poisonDamageTraining.costs[0]
	_buttons(card)[0].pressed.emit()
	assert(host.state.poisonDamageTrainingUpgradeLevel == 1 and host.state.runes == 10000 - cost, "Poison training card purchases its own field")
	host.clear()
	host.state = original
	host.commands.clear()

func _damage_training_cards(host, ui) -> void:
	var original: Dictionary = host.state.duplicate(true)
	var ids := ["directDamageTraining", "splashDamageTraining", "damageOverTimeTraining"]
	host.state.progressionVersion = 1
	host.state.clearedStageNumbers = [15] # 3-5 is not the 3-6 fixed ID26 gate.
	host.state.runes = 10000
	ui.category = "전투"
	ui.upgrades()
	for id in ids:
		assert(not _texts(host.body).contains(ui.TITLES[id]), "Damage training stays hidden before 3-6: " + id)
	host.clear()
	host.state.clearedStageNumbers.append(26)
	for id in ids:
		ui.upgrades()
		var card := _card_with_title(host.body, ui.TITLES[id])
		assert(card != null and ui.upgrade_requirement(id) == 26)
		assert(card.get_meta("level_text") == "Lv.0/80" and _texts(card).contains("다음 +0.5%"))
		assert(ui.effect_value(id, 80) == "+40%")
		var before: int = host.state.runes
		var cost: int = host.app.run_domain.growth.data.permanentUpgrades[id].costs[0]
		_buttons(card)[0].pressed.emit()
		assert(host.state[id + "UpgradeLevel"] == 1 and host.state.runes == before - cost, "Damage training card purchases the right field: " + id)
		host.clear()
		host.state.runes = 0
		ui.upgrades()
		card = _card_with_title(host.body, ui.TITLES[id])
		assert(_texts(card).contains("현재 +0.5%") and _texts(card).contains("다음 +1%") and _buttons(card)[0].disabled)
		host.clear()
		host.state[id + "UpgradeLevel"] = 79
		host.state.runes = 100000
		ui.upgrades()
		card = _card_with_title(host.body, ui.TITLES[id])
		assert(card.get_meta("level_text") == "Lv.79/80" and _texts(card).contains("현재 +39.5%") and _texts(card).contains("다음 +40%"))
		cost = host.app.run_domain.growth.data.permanentUpgrades[id].costs[79]
		_buttons(card)[0].pressed.emit()
		assert(host.state[id + "UpgradeLevel"] == 80 and host.state.runes == 100000 - cost, "Last damage training purchase reaches80 with correct debit: " + id)
		host.clear()
		ui.status = "완료"
		ui.upgrades()
		card = _card_with_title(host.body, ui.TITLES[id])
		assert(card.get_meta("level_text") == "Lv.80/80" and _texts(card).contains("현재 +40%") and _texts(card).contains("최대 레벨") and not _texts(card).contains("다음"))
		assert(_buttons(card).is_empty())
		ui.status = "해금"
		host.clear()
	host.state = original
	host.commands.clear()

# Status tabs count the current category and switch the list without touching progress.
func _status_tabs(host, ui) -> void:
	var original: Dictionary = host.state.duplicate(true)
	host.state.clearedStageNumbers = [1, 4, 5]
	host.state.nexusHpUpgradeLevel = 30
	ui.category = "전투"
	var holder := VBoxContainer.new()
	host.add_child(holder)
	ui.upgrade_status_tabs(holder)
	var labels: Array = holder.find_children("UpgradeStatus_*", "Button", true, false).map(func(b): return b.text)
	assert(labels == ["해금  2", "잠김  7", "완료  1"], "Status tab counts: %s" % [labels])
	host.clear()
	ui.upgrades()
	var unlocked: Array = host.body.get_child(0).get_children().map(func(row): return row.get_meta("upgrade_id"))
	assert(unlocked == ["fireTraining", "criticalDamage"], "Unlocked tab keeps catalog order: %s" % [unlocked])
	holder.find_child("UpgradeStatus_완료", true, false).pressed.emit()
	assert(ui.status == "완료")
	host.clear()
	host.state.nexusHpUpgradeLevel = 0
	ui.upgrades()
	assert(host.body.get_child(0).get_child(0).name == "UpgradeEmpty", "An empty tab shows one empty row")
	ui.status = "해금"
	holder.queue_free()
	host.clear()
	host.state = original

func _card_with_title(body: Node, title: String) -> Control:
	for child in body.get_child(0).get_children():
		if _texts(child).contains(title): return child
	return null

func _buttons(node: Node) -> Array:
	var values: Array = [node] if node is Button else []
	for child in node.get_children(): values.append_array(_buttons(child))
	return values

func _texts(node: Node) -> String:
	var value: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): value += "\n"+_texts(child)
	return value
