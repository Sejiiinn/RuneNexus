extends SceneTree
const Lobby = preload("res://ui/lobby.gd")

class FakeServices extends RefCounted:
	signal release_request
	var busy := false
	var updates := {"blocked": false}
	var calls: Array = []
	var response := {"ok": true, "body": {"economy": {}}}
	func connected() -> bool: return true
	func needs_profile() -> bool: return false
	func perform(action: String, values: Dictionary) -> Dictionary:
		calls.append({"action": action, "values": values.duplicate(true)})
		await release_request
		return response.duplicate(true)

class FakeApp extends RefCounted:
	var progression_inputs := {
		"runes": 1000, "unlockedStageCount": 2, "totalCorePoints": 5,
		"freeDiamonds": 1000, "paidDiamonds": 0,
		"researchLevels": {}, "researchSlotTwoUnlocked": false,
		"activeResearches": [], "turretModules": {"tickets": 0, "items": []}
	}
	var catalog = preload("res://content/content_catalog.gd").new()
	var run_domain = preload("res://session/run_session.gd").new()
	var checkpoint := {"message": "", "preferences": {}}
	var startup_blocked := false
	var services = FakeServices.new()
	func apply_growth_command(_command: Dictionary) -> bool: return true
	func persist_progression() -> bool: return true
	func resume_run() -> bool: return true
	func start_stage(_index: int) -> bool: return true
	func request_quit() -> void: pass

func _initialize() -> void: call_deferred("_verify")

func _verify() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations", true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(320, 568)
	root.size = Vector2i(320, 568)
	var app := FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	await process_frame
	lobby.size = Vector2(320, 568)
	await _research_checks(lobby, app)
	await _slot_checks(lobby, app)
	await _module_checks(lobby, app)
	print("PASS ui confirmations: preview, explicit confirm, single flight, stale state, module target/refund, 320x568")
	lobby.free()
	quit()

func _research_checks(lobby: Control, app: FakeApp) -> void:
	var now := int(Time.get_unix_time_from_system() * 1000)
	app.progression_inputs.activeResearches = [{"type": "researchEfficiency", "targetLevel": 1, "startedAtMillis": now, "durationMillis": 300000}]
	app.progression_inputs.freeDiamonds = 10
	lobby.growth._instant_confirm("researchEfficiency")
	await _settle(lobby)
	assert(app.services.calls.is_empty(), "Opening instant research preview must not spend")
	assert(_text(lobby.modal_body).contains("사용 다이아") and _labels(lobby.modal_body).any(func(label): return label.name == "DiamondAmount" and label.text == "5"), "Research preview shows current price")
	var confirm := _button(lobby.modal_body, "즉시 완료")
	assert(confirm != null and not confirm.disabled, "Research requires an explicit enabled action")
	_check_modal_bounds(lobby)
	confirm.pressed.emit()
	assert(app.services.calls.size() == 1, "One research confirmation sends one request")
	assert(app.services.calls[0] == {"action": "complete_research", "values": {"id": "researchEfficiency"}}, "Research request keeps selected ID")
	confirm.pressed.emit()
	assert(app.services.calls.size() == 1, "Pending research ignores a second press")
	app.services.release_request.emit()
	await process_frame
	app.services.calls.clear()
	app.progression_inputs.activeResearches[0].startedAtMillis = int(Time.get_unix_time_from_system() * 1000)
	app.progression_inputs.activeResearches[0].durationMillis = 300000
	lobby._service("연구 즉시 완료", {"id": "researchEfficiency"})
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "즉시 완료")
	assert(confirm != null and _labels(lobby.modal_body).any(func(label): return label.name == "DiamondAmount" and label.text == "5"))
	app.progression_inputs.activeResearches[0].durationMillis = 240000
	confirm.pressed.emit()
	assert(app.services.calls.is_empty(), "Changed research price cannot use the old confirmation")
	await _settle(lobby)
	assert(_labels(lobby.modal_body).any(func(label): return label.name == "DiamondAmount" and label.text == "4"), "Changed price is shown for a new review")
	confirm = _button(lobby.modal_body, "즉시 완료")
	assert(confirm != null and not confirm.disabled)
	confirm.pressed.emit()
	assert(app.services.calls.size() == 1 and app.services.calls[0] == {"action": "complete_research", "values": {"id": "researchEfficiency"}}, "Confirmed current quote sends one research request")
	app.services.release_request.emit()
	await process_frame
	app.services.calls.clear()
	app.progression_inputs.freeDiamonds = 0
	lobby._service("연구 즉시 완료", {"id": "researchEfficiency"})
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "즉시 완료")
	assert(confirm != null and confirm.disabled, "Insufficient diamonds block research confirmation")
	assert(app.services.calls.is_empty())
	app.progression_inputs.freeDiamonds = 10
	app.progression_inputs.activeResearches.clear()
	lobby._service("연구 즉시 완료", {"id": "researchEfficiency"})
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "즉시 완료")
	assert(confirm == null or confirm.disabled, "Finished or absent research cannot be completed twice")
	assert(app.services.calls.is_empty())
	app.progression_inputs.researchLevels.researchEfficiency = 1
	lobby._service("연구 즉시 완료", {"id": "researchEfficiency"})
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "즉시 완료")
	assert(confirm == null or confirm.disabled, "Completed research cannot be charged")
	assert(app.services.calls.is_empty())
	app.progression_inputs.researchLevels.clear()
	app.progression_inputs.activeResearches = [{"type": "researchEfficiency", "targetLevel": 1, "startedAtMillis": int(Time.get_unix_time_from_system() * 1000), "durationMillis": 300000}]
	lobby._service("연구 즉시 완료", {"id": "researchEfficiency"})
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "즉시 완료")
	assert(confirm != null and not confirm.disabled)
	app.progression_inputs.activeResearches.clear()
	confirm.pressed.emit()
	assert(app.services.calls.is_empty(), "Research completed while preview was open requires a fresh review")

func _slot_checks(lobby: Control, app: FakeApp) -> void:
	var cost := int(app.run_domain.growth.data.constants.researchSlotTwoUnlockCost)
	app.progression_inputs.freeDiamonds = cost
	lobby.growth._slot_confirm()
	await _settle(lobby)
	assert(app.services.calls.is_empty(), "Opening slot preview must not spend")
	assert(_text(lobby.modal_body).contains("%d" % cost), "Slot preview shows purchase cost")
	var confirm := _button(lobby.modal_body, "해금")
	assert(confirm != null and not confirm.disabled, "Slot purchase requires explicit confirmation")
	_check_modal_bounds(lobby)
	app.services.response = {"ok": false, "code": "ECONOMY_REVISION_CONFLICT", "body": {}}
	confirm.pressed.emit()
	assert(app.services.calls.size() == 1)
	assert(app.services.calls[0] == {"action": "unlock_research_slot_two", "values": {}}, "Slot request has no unrelated payload")
	confirm.pressed.emit()
	assert(app.services.calls.size() == 1, "Pending slot purchase ignores a second press")
	app.services.release_request.emit()
	await process_frame
	assert(_text(lobby.modal_body).contains("갱신"), "Failed purchase explains why it can be retried")
	confirm = _button(lobby.modal_body, "해금")
	assert(confirm != null and not confirm.disabled, "Failed purchase enables retry")
	app.services.response = {"ok": true, "body": {"economy": {}}}
	confirm.pressed.emit()
	assert(app.services.calls.size() == 2, "Retry sends exactly one new request")
	app.services.release_request.emit()
	await process_frame
	app.services.calls.clear()
	app.progression_inputs.freeDiamonds = cost - 1
	lobby._service("연구 슬롯 구매")
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "해금")
	assert(confirm != null and confirm.disabled, "Insufficient diamonds block slot purchase")
	app.progression_inputs.freeDiamonds = cost
	app.progression_inputs.researchSlotTwoUnlocked = true
	lobby._service("연구 슬롯 구매")
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "해금")
	assert(confirm == null or confirm.disabled, "Unlocked slot cannot be purchased twice")
	assert(app.services.calls.is_empty())
	app.progression_inputs.researchSlotTwoUnlocked = false
	lobby._service("연구 슬롯 구매")
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "해금")
	assert(confirm != null and not confirm.disabled)
	app.progression_inputs.researchSlotTwoUnlocked = true
	confirm.pressed.emit()
	assert(app.services.calls.is_empty(), "Slot unlocked while preview was open cannot be charged")
	app.progression_inputs.researchSlotTwoUnlocked = false

func _module_checks(lobby: Control, app: FakeApp) -> void:
	var items: Array = [
		_module("normal-a", "normal", false),
		_module("rare-equipped", "rare", true),
		_module("unique-c", "unique", false)
	]
	app.progression_inputs.turretModules.items = items
	lobby._service("모듈 일괄 분해", {"ids": ["normal-a", "rare-equipped", "unique-c", "normal-a", "missing"]})
	await _settle(lobby)
	assert(app.services.calls.is_empty(), "Opening disassembly preview must not mutate inventory")
	var preview := _text(lobby.modal_body)
	assert(preview.contains("일반 1") and preview.contains("유니크 1") and preview.contains("2개"), "Preview shows actual eligible grades and count")
	assert(preview.contains("52"), "Preview sums only eligible module refunds")
	assert(not preview.contains("missing"), "Unknown ID does not appear in the preview")
	assert(not preview.contains("희귀"), "Equipped module is excluded from preview")
	assert(lobby.modal_body.find_child("ModulePreview_normal-a", true, false) != null)
	assert(lobby.modal_body.find_child("ModulePreview_unique-c", true, false) != null)
	assert(lobby.modal_body.find_child("ModulePreview_rare-equipped", true, false) == null)
	_check_modal_bounds(lobby)
	var confirm := _button(lobby.modal_body, "분해")
	assert(confirm != null and not confirm.disabled, "Disassembly has an explicit enabled action")
	# An inventory change after preview must force another review of the affected IDs.
	items[0].equipped = true
	confirm.pressed.emit()
	assert(app.services.calls.is_empty(), "A stale preview cannot disassemble newly equipped modules")
	await _settle(lobby)
	preview = _text(lobby.modal_body)
	assert(preview.contains("1개") and preview.contains("50"), "Refreshed preview reflects changed equipment")
	confirm = _button(lobby.modal_body, "분해")
	assert(confirm != null and not confirm.disabled)
	confirm.pressed.emit()
	assert(app.services.calls.size() == 1)
	assert(app.services.calls[0].action == "disassemble_modules" and app.services.calls[0].values.get("ids") == ["unique-c"], "Only the re-confirmed target is sent once")
	confirm.pressed.emit()
	assert(app.services.calls.size() == 1, "Pending disassembly ignores a second press")
	app.services.release_request.emit()
	await process_frame
	app.services.calls.clear()
	lobby._service("모듈 분해", {"id": "missing"})
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "분해")
	assert(confirm == null or confirm.disabled, "Missing module ID cannot be submitted")
	assert(app.services.calls.is_empty())
	lobby._service("모듈 일괄 분해", {"ids": ["normal-a", "rare-equipped"]})
	await _settle(lobby)
	confirm = _button(lobby.modal_body, "분해")
	assert(confirm == null or confirm.disabled, "Equipped-only selection cannot be submitted")
	var many: Array = []
	var ids: Array = []
	for i in 30:
		var id := "module-%02d" % i
		ids.append(id)
		many.append(_module(id, "magic", false))
	app.progression_inputs.turretModules.items = many
	lobby._service("모듈 일괄 분해", {"ids": ids})
	await _settle(lobby)
	assert(_text(lobby.modal_body).contains("30개"), "Large preview keeps its actual target count")
	assert(app.services.calls.is_empty())
	_check_modal_bounds(lobby)
	var preview_scroll := lobby.modal_body.find_child("ModuleDisassemblyPreview", true, false) as ScrollContainer
	assert(preview_scroll != null, "Large disassembly has a dedicated bounded preview")
	assert(lobby.modal_body.get_combined_minimum_size().x <= lobby.modal_scroll.size.x + 1, "Many-module preview fits 320 px width")
	for id in ids:
		assert(preview_scroll.find_child("ModulePreview_" + id, true, false) != null, "Every chosen module appears exactly in the review: " + id)
	assert(preview_scroll.get_v_scroll_bar().max_value > preview_scroll.size.y, "Many-module preview scrolls vertically")
	assert(lobby.modal_scroll.get_global_rect().encloses(_button(lobby.modal_body, "분해").get_global_rect()), "Confirm remains visible below bounded preview")
	preview_scroll.scroll_vertical = 100000
	await process_frame
	await process_frame
	confirm = _button(lobby.modal_body, "분해")
	assert(confirm != null and lobby.modal_scroll.get_global_rect().encloses(confirm.get_global_rect()), "Confirm remains reachable after preview scrolling")

func _module(id: String, grade: String, equipped: bool) -> Dictionary:
	return {"id": id, "grade": grade, "equipped": equipped, "turretType": "arrow", "part": "core", "options": []}

func _settle(lobby: Control) -> void:
	await process_frame
	await process_frame
	lobby._layout_modal()
	await process_frame

func _button(node: Node, word: String) -> Button:
	if node is Button and word in node.text and not ("취소" in node.text): return node
	for child in node.get_children():
		var found := _button(child, word)
		if found != null: return found
	return null

func _text(node: Node) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): result += "\n" + _text(child)
	return result

func _check_modal_bounds(lobby: Control) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(320, 568))
	assert(viewport.encloses(lobby.modal_frame.get_global_rect()), "Service modal stays inside 320x568")
	for button in _buttons(lobby.modal_body):
		assert(button.size.y >= 44, "Service action remains at least 44 px high: " + button.text)
		if button.name in ["CompleteResearchConfirm","UnlockResearchSlotConfirm"]:
			assert(button.icon != null and button.icon.resource_path == "res://assets/ui/diamond_currency.png", "Purchase button uses the wallet diamond asset")
	for label in _labels(lobby.modal_body):
		if label.name == "DiamondAmount":
			var icon: TextureRect = label.get_parent().get_child(0)
			assert(icon.texture != null and icon.texture.resource_path == "res://assets/ui/diamond_currency.png", "Diamond amount uses the wallet diamond asset")
			assert(label.get_line_count() == 1, "Diamond amount stays on one line: " + label.text)

func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(_buttons(child))
	return result

func _labels(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	if node is Label: result.append(node)
	for child in node.get_children(): result.append_array(_labels(child))
	return result
