extends SceneTree
## Real success path, deterministic response, and bounded result-list layout.
const Lobby = preload("res://ui/lobby.gd")
const Fixture = preload("res://verify_ui_confirmations.gd")
const Results = preload("res://ui/module_draw_results.gd")
const ModuleIcon = preload("res://ui/module_icon.gd")
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

func artwork_matrix() -> void:
	var paths := {}
	for part in ["core", "barrel", "frame"]:
		for grade in ["normal", "magic", "rare", "unique"]:
			var item := {"part":part, "grade":grade, "turretType":"arrow"}
			var icon = ModuleIcon.create(item, 64)
			root.add_child(icon)
			await settle()
			var art := icon.find_child("ModuleIconTexture", true, false) as TextureRect
			check(art != null and art.texture != null, "Every supported part/grade loads its final PNG")
			check(icon.find_child("ModulePartGlyph", true, false) == null, "Supported modules never use the placeholder glyph")
			check(icon.icon_path == "res://assets/app/turret_modules/icons/%s_%s.png" % [part, grade], "Part and grade select the exact artwork")
			check(art.modulate == Color.WHITE, "Grade artwork preserves its own material colors")
			var glow := art.get_node_or_null("ModuleUniqueBackglow") as TextureRect
			check((glow != null) == (grade == "unique"), "Only unique modules have a separate backlight")
			if glow != null:
				check(glow.texture != null and glow.texture.resource_path == ModuleIcon.BACKGLOW_PATH, "The separate glow PNG is packaged and loaded")
				check(glow.show_behind_parent and glow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Backlight stays behind the icon and cannot intercept input")
			var frame := icon.get_theme_stylebox("panel") as StyleBoxTexture
			check(frame != null and frame.modulate_color == ModuleIcon.PartGlyph.COLORS[grade], "The frame keeps its existing grade tint")
			paths[icon.icon_path] = true
			for extent in [32, 42, 64]:
				icon.set_extent(extent)
				icon.size = Vector2.ONE * extent
				await settle()
				check(icon.get_global_rect().encloses(art.get_global_rect()), "Artwork fits every equipment/result extent")
				check(art.get_global_rect().get_center().distance_to(icon.get_global_rect().get_center()) < 0.1, "Artwork stays centered after a resize")
			icon.free()
	check(paths.size() == 12, "All twelve part/grade images are distinct")
	check(ModuleIcon.asset_path({"part":"futurePart","grade":"normal"}).is_empty(), "Unknown parts cannot select another part's PNG")

func results(lobby, app, count: int) -> void:
	var items := []
	for i in count: items.append(module_item(i))
	app.services.response = {"ok":true,"body":{"economy":{},"drawnModules":items}}
	lobby._service("모듈 뽑기", {"count":count,"turretType":"cannon"})
	await settle()
	var modal_id: int = lobby.modal.get_instance_id()
	var confirm: Button = lobby.modal_body.find_children("*", "Button", true, false)[0]
	check(confirm.text == "%d개 뽑기" % count, "Draw preview retains its explicit confirmation")
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
		var art := icon.find_child("ModuleIconTexture", true, false) as TextureRect
		check(art != null and art.texture != null and art.modulate == Color.WHITE, "Results use final part/grade artwork without retinting")
		check(icon.icon_path == "res://assets/app/turret_modules/icons/%s_%s.png" % [icon.part, icon.grade], "Results select the correct part/grade PNG")
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
	await artwork_matrix()
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
