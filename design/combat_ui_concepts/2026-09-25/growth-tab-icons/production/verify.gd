extends SceneTree
const Fixture = preload("res://verify_lobby.gd")
var lobby
var app
var output := OS.get_environment("GROWTH_ICON_OUT")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = Fixture.FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	app.progression_inputs = {"runes":100000, "clearedStageNumbers":range(1,16), "researchLevels":{}, "activeResearches":[]}
	lobby = load("res://ui/lobby.gd").new()
	lobby.app = app
	root.add_child(lobby)
	root.title = "RuneNexus · 강화 탭 아이콘 확인 (테스트 저장)"
	if OS.get_environment("GROWTH_ICON_PREVIEW") == "1":
		root.size = Vector2i(440, 900)
		root.content_scale_size = root.size
		lobby.growth.category = "전투"
		lobby.open_page("강화")
		return
	for width in [440, 320]:
		root.size = Vector2i(width, 900)
		root.content_scale_size = root.size
		lobby.growth.category = "전투"
		lobby.open_page("강화")
		await _settle()
		await _check_and_capture(width, "combat")
		await _click_tab("경제")
		assert(lobby.growth.category == "경제", "Economy tab click did not change category")
		await _check_and_capture(width, "economy")
		await _click_tab("전투")
		assert(lobby.growth.category == "전투", "Combat tab click did not change category")
		assert(_find_tab(lobby, "전투") != null)
	print("PASS growth tab icons: 440/320 combat/economy rendering and pointer input")
	lobby.free()
	quit()

func _settle() -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

func _find_tab(node: Node, title: String) -> Button:
	if node is Button and node.tooltip_text == title:
		return node
	for child in node.get_children():
		var result := _find_tab(child, title)
		if result != null:
			return result
	return null

func _click_tab(title: String) -> void:
	var tab := _find_tab(lobby, title)
	assert(tab != null and not tab.disabled, "Missing active tab button: " + title)
	var point := tab.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _settle()

func _check_and_capture(width: int, tag: String) -> void:
	var combat := _find_tab(lobby, "전투")
	var economy := _find_tab(lobby, "경제")
	assert(combat != null and economy != null, "Both tabs must be visible")
	for button in [combat, economy]:
		var icon: TextureRect = button.get_child(0).get_child(0)
		assert(icon.texture != null, "Tab icon texture is missing: " + button.tooltip_text)
		assert(icon.custom_minimum_size == Vector2(28, 28), "Tab icon size differs: " + button.tooltip_text)
	assert(lobby.growth.category == ("전투" if tag == "combat" else "경제"))
	root.get_texture().get_image().save_png(output + "/" + str(width) + "-" + tag + ".png")
