extends SceneTree
## Real success path, deterministic response, and bounded result-list layout.
const Lobby = preload("res://ui/lobby.gd")
const Fixture = preload("res://verify_ui_confirmations.gd")
const Results = preload("res://ui/module_draw_results.gd")
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	assert(condition, message)

func settle() -> void:
	for i in 8: await process_frame

func dimensions(lobby: Control, extent: Vector2i) -> void:
	root.content_scale_size = extent
	root.size = extent
	await settle()

func module_item(index: int) -> Dictionary:
	var part: String = ["frame", "core", "barrel", "frame", "core"][index]
	var options: Array
	if part == "frame":
		options = [{"type":"highLevelUpgradeCostDiscount","value":22 if index < 2 else 15}, {"type":"linkUpgradeCostDiscount","value":24 if index < 2 else 16}, {"type":"gemEffectIncrease","value":12 if index < 2 else 8}]
	elif part == "core":
		options = [{"type":"splashSecondaryDamageBonus","value":20 if index < 2 else 14}, {"type":"splashRadiusIncrease","value":22 if index < 2 else 14}, {"type":"damageIncrease","value":36 if index < 2 else 24}]
	else:
		options = [{"type":"criticalChanceBonus","value":11}, {"type":"criticalDamageBonus","value":38}, {"type":"rangeIncrease","value":11}]
	return {"id":"draw-%d" % index,"turretType":"cannon","part":part,"grade":"unique" if index < 2 else "rare","options":options}

func node(lobby, name: String) -> Node: return lobby.modal.find_child(name, true, false)

func results(lobby, app, count: int) -> void:
	var items := []
	for i in count: items.append(module_item(i))
	app.services.response = {"ok":true,"body":{"economy":{},"drawnModules":items}}
	lobby._service("모듈 뽑기", {"count":count,"turretType":"cannon"})
	await settle()
	var modal_id: int = lobby.modal.get_instance_id()
	var confirm: Button = lobby.modal_body.find_children("*", "Button", true, false)[0]
	check(confirm.text == "확인", "Draw preview retains its explicit confirmation")
	confirm.pressed.emit()
	check(app.services.calls.back().action == "draw_modules", "The existing server command receives the draw")
	check(app.services.calls.back().values == {"count":count,"turretType":"cannon","buyMissingTicketsWithDiamonds":false,"approvedDrawQuote":{"moduleTickets":count,"diamonds":0}}, "Internal draw request preserves the approved ticket and diamond quote")
	app.services.release_request.emit()
	await settle()
	check(lobby.modal.get_instance_id() == modal_id, "Success reuses the same modal shell")
	check(node(lobby,"ModuleDrawSummary").text == "모듈 %d개를 획득했습니다." % count, "Count is based on returned items")
	check(node(lobby,"ModuleDrawIconStrip").get_child_count() == count, "Every returned module is in the numbered strip")
	check(node(lobby,"ModuleDrawResultRows").get_child_count() == count * 2, "Every result has one detail row and separator")
	for i in count:
		var row := node(lobby,"ModuleResult%d" % (i + 1))
		check(row != null, "Result number matches its row")
		var icon = row.get_child(0)
		check(icon.part == module_item(i).part and icon.grade == module_item(i).grade, "The shared icon preserves part and grade")
		check(icon.find_child("ModulePartGlyph", true, false) != null, "Existing PartGlyph is used until icon assets are supplied")
		check(icon.icon_path == "res://assets/app/turret_modules/icons/%s.png" % icon.part, "Final PNG replacement has an explicit component path")
		check(row.find_child("ModuleDetails",true,false).get_child_count() == 4, "All three options remain readable for every module")
	var shell: Control = lobby.modal
	lobby._services._render()
	await settle()
	check(lobby.modal == shell and node(lobby,"ModuleDrawIconStrip").get_child_count() == count, "Refreshing the result reuses the shell without duplicated rows")
	check(lobby.modal_body.get_parent() == lobby.modal_frame.get_child(0), "Fixed results controls are outside the scroll")
	check(lobby.modal_scroll == node(lobby,"ModuleDrawResultList"), "Only the result list scrolls")
	check(lobby.modal_body.find_children("*", "Button", true, false).size() == 1, "The only result action is close")

func layout(lobby) -> void:
	var viewport := Rect2(Vector2.ZERO, lobby.size)
	check(viewport.encloses(lobby.modal_frame.get_global_rect()), "Result modal stays inside the viewport")
	check(lobby.modal_body.get_combined_minimum_size().x <= lobby.modal_frame.size.x - 32 + 1, "Result contents fit the modal width")
	for name in ["ModuleDrawIconStrip","ModuleDrawSummary","ModuleDrawClose","CloseModal"]:
		check(lobby.modal_frame.get_global_rect().encloses(node(lobby,name).get_global_rect()), "Fixed result control is fully visible: " + name)
	var list: ScrollContainer = node(lobby,"ModuleDrawResultList")
	var header_rect: Rect2 = node(lobby,"ModuleDrawIconStrip").get_global_rect()
	var close_rect: Rect2 = node(lobby,"ModuleDrawClose").get_global_rect()
	list.scroll_vertical = 100000
	await settle()
	check(header_rect == node(lobby,"ModuleDrawIconStrip").get_global_rect() and close_rect == node(lobby,"ModuleDrawClose").get_global_rect(), "Scrolling leaves the strip and close in place")
	check(list.get_v_scroll_bar().max_value <= list.size.y or list.get_global_rect().intersects(node(lobby,"ModuleDrawResultRows").get_child(-2).get_global_rect()), "The final row is reachable by scrolling")

func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations", true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var app := Fixture.FakeApp.new()
	app.progression_inputs.turretModules.tickets = 10
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog(), "Fixture catalogs load")
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	await dimensions(lobby, Vector2i(440,896))
	await results(lobby,app,5)
	await layout(lobby)
	check(node(lobby,"ModuleResult2").find_child("ModuleTitle",true,false).text == "유니크 · 폭심 제어 코어", "Core module uses its real name")
	check(Results.effect_text({"type":"highLevelUpgradeCostDiscount","value":22}) == "고레벨 강화 비용 −22%", "Discount semantics are retained")
	check(Results.effect_text({"type":"splashSecondaryDamageBonus","value":20}) == "광역 보조 피해 +20%p", "Percentage-point semantics are retained")
	check(Results.effect_text({"type":"futureOption","value":7}) == "futureOption +7%", "Unknown effects are visible")
	check(Results.module_name({"turretType":"futureTurret","part":"futurePart"}) == "futureTurret · futurePart", "Unknown identity is visible")
	await dimensions(lobby, Vector2i(320,568))
	await layout(lobby)
	await dimensions(lobby, Vector2i(320,360))
	await layout(lobby)
	check(lobby.modal_scroll.get_v_scroll_bar().max_value > lobby.modal_scroll.size.y, "Short-screen long results have internal scrolling")
	node(lobby,"ModuleDrawClose").pressed.emit()
	await settle()
	check(lobby.modal == null, "Fixed close dismisses the results")
	await dimensions(lobby, Vector2i(440,896))
	await results(lobby,app,1)
	await layout(lobby)
	check(lobby.modal_frame.size.y < 400, "A one-result modal keeps a natural height")
	lobby.close_modal()
	lobby._service("모듈 뽑기", {"count":1,"turretType":"cannon"})
	await settle()
	lobby.modal_body.find_child("DrawModulesConfirm",true,false).pressed.emit()
	lobby.close_modal()
	app.services.release_request.emit()
	await settle()
	check(lobby.modal == null, "A completed request never reopens a dismissed result modal")
	lobby.free()
	print("PASS module draw results: checks=%d" % checks)
	quit()
