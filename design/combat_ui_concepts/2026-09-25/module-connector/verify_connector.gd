extends SceneTree
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
const OUT = "/Users/sejin/Documents/RuneNexus/design/combat_ui_concepts/2026-09-25/module-connector/"
func _initialize(): call_deferred("run")
func settle():
	for i in range(6): await process_frame
func click(control: Control):
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await settle()
func run():
	var app = Fixture.FakeApp.new()
	assert(app.catalog.load_catalog()); assert(app.run_domain.growth.load_catalog())
	app.progression_inputs.clearedStageNumbers = [1,2,3,4,5,6]
	var items = []
	for type in ["arrow", "cannon", "magic", "frost", "sniper", "lightning"]:
		for part in ["core", "barrel", "frame"]:
			items.append({"id":type+part,"turretType":type,"part":part,"grade":"rare","equipped":true,"options":[]})
	app.progression_inputs.turretModules = {"items":items,"tickets":2}
	var lobby = Lobby.new(); lobby.app = app; lobby.page = "포탑"
	root.add_child(lobby)
	for width in [320, 440, 900, 320]:
		root.size = Vector2i(width,900); root.content_scale_size = Vector2i(width,900)
		await settle()
		var area = lobby.find_child("ModuleEquipment",true,false)
		var connector = lobby.find_child("ModuleConnector",true,false)
		print("width=",width," area=",area.size," pos=",area.global_position," feed=",connector.feed.size*connector.feed.scale)
		assert(area.size.x <= minf(width - 44, 380) + 0.1)
		assert(absf(area.get_global_rect().get_center().x-area.get_parent().get_global_rect().get_center().x)<0.6)
		for i in range(3):
			var slot = lobby.find_child("ModuleSlot_"+["core","barrel","frame"][i],true,false)
			assert(absf(slot.get_global_rect().get_center().y-connector.joints[i].get_global_rect().get_center().y)<0.6)
			assert(connector.joints[i].size.is_equal_approx(connector.joints[i].texture.get_size()*connector.ART_SCALE))
			assert(connector.branches[i].size.x >= connector.branches[i].patch_margin_left+connector.branches[i].patch_margin_right)
		var slot_left: float = lobby.find_child("ModuleSlot_core",true,false).position.x
		var terminal_x: float = connector.terminal.position.x + connector.terminal.size.x / 2
		var trunk_x: float = connector.joints[1].position.x + connector.joints[1].size.x / 2
		print("balance=", (trunk_x-terminal_x)/(slot_left-terminal_x), " branch=", connector.branches[1].size*connector.branches[1].scale)
		assert(is_equal_approx((trunk_x-terminal_x)/(slot_left-terminal_x),0.64))
		assert(connector.feed.size.x >= connector.feed.patch_margin_left+connector.feed.patch_margin_right)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"balanced-%d.png"%width)
		await click(lobby.find_child("ModuleSlot_core",true,false))
		assert(lobby.collection.selected_id=="arrowcore")
		assert(lobby.collection.part_filter=="core")
		for type in ["cannon","magic","frost","sniper","lightning","arrow"]:
			await click(lobby.find_child("TurretSelect_"+type,true,false))
			assert(lobby.collection.turret==type)
			assert(lobby.find_child("ModuleTurretPreview",true,false).texture.resource_path.ends_with(type+".png"))
		print("PASS width=",width," fixed joints, pipe caps, slot alignment, max width, equipment and six turret clicks")
	app.progression_inputs.turretModules.items = []
	root.size = Vector2i(440,900); root.content_scale_size = Vector2i(440,900)
	lobby.refresh()
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"balanced-empty-440.png")
	await click(lobby.find_child("ModuleSlot_barrel",true,false))
	assert(lobby.collection.part_filter=="barrel" and lobby.collection.selected_id.is_empty())
	print("PASS MODULE_CONNECTOR: resize down without refresh, empty slot filter")
	quit()
