extends SceneTree
const Fixture = preload("res://verify_lobby.gd")
var lobby
var app
var out := OS.get_environment("COST_OUT")
var tag := OS.get_environment("COST_TAG")

func _initialize(): call_deferred("run")

func run():
	app = Fixture.FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	app.progression_inputs = {"runes":10000000,"clearedStageNumbers":range(1,16),"researchLevels":{},"activeResearches":[]}
	lobby = load("res://ui/lobby.gd").new()
	lobby.app = app
	root.add_child(lobby)
	if OS.get_environment("COST_PREVIEW") == "1":
		root.title = "RuneNexus · 강화 프레임 확인 (테스트 저장)"
		root.size = Vector2i(440,900)
		root.content_scale_size = root.size
		app.progression_inputs.runes = 100000
		lobby.open_page("강화")
		return
	for width in [320,440]:
		root.size = Vector2i(width,900)
		root.content_scale_size = root.size
		for category in ["전투","경제"]:
			lobby.growth.category = category
			lobby.open_page("강화")
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+tag+"-"+str(width)+"-"+category+".png")
			dump_costs(lobby.body)
		var definition: Dictionary = app.run_domain.growth.data.permanentUpgrades.fireTraining
		for state in ["long", "disabled", "maximum"]:
			app.progression_inputs[definition.field] = int(definition.maxLevel) if state == "maximum" else int(definition.maxLevel) - 1
			app.progression_inputs.runes = 0 if state == "disabled" else 10000000
			lobby.growth.category = "전투"
			lobby.refresh()
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+tag+"-"+str(width)+"-"+state+".png")
			dump_costs(lobby.body)
			var box = lobby.body.get_child(0).get_child(1).get_child(0)
			var button: Button = box.get_child(box.get_child_count()-1)
			var commands_before: int = app.commands.size()
			var point = button.get_global_rect().get_center() if state == "maximum" else button.get_child(0).get_child(0).get_child(1).get_global_rect().get_center()
			for down in [true,false]:
				var event := InputEventMouseButton.new()
				event.position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = down
				root.push_input(event,true)
				await process_frame
			assert(app.commands.size() == commands_before + (1 if state == "long" else 0), "Rune box input / disabled protection")
			if state == "long": assert(app.progression_inputs[definition.field] == int(definition.maxLevel))
			if state == "maximum": assert(button.text == "최대 레벨" and button.disabled)
		app.progression_inputs[definition.field] = 0
		app.progression_inputs.runes = 10000000
	print("PASS cost layout: 320/440, combat/economy, 65620, insufficient/maximum, rune-box purchase input")
	lobby.free()
	quit()

func dump_costs(node: Node):
	if node is Button and node.tooltip_text.begins_with("레벨업"):
		var content = node.get_child(0).get_child(0)
		var chip = content.get_child(1)
		print(node.tooltip_text, " button=",node.get_global_rect(), " chip=",chip.get_global_rect(), " label=",content.get_child(0).get_global_rect(), " min=",chip.get_combined_minimum_size())
		assert(node.get_global_rect().encloses(chip.get_global_rect()), "Cost box stays in button")
		assert(not content.get_child(0).get_global_rect().intersects(chip.get_global_rect()), "Caption and cost do not overlap")
		assert(chip.get_global_rect().grow_individual(-9,-7,-9,-7).encloses(chip.get_child(0).get_global_rect()), "Currency stays inside the complete gold frame")
	for child in node.get_children(): dump_costs(child)
