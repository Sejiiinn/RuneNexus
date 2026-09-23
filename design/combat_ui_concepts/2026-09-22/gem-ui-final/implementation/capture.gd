extends SceneTree
var app
var hud
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/gem-ui-final/implementation/"
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	hud.refresh()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+label+".png")
	print("CAPTURE ",label," body=",hud.body.size," scroll=",hud.scroll.size," dock=",hud.dock.get_global_rect())
func click(node: Control) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = node.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await create_timer(0.15).timeout
func run() -> void:
	assert(OS.get_user_data_dir().contains("RuneNexus-modal-v2-review"))
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.5).timeout
	app = scene._standalone_session
	app.autosave_interval = 100000.0
	app.start_stage(0)
	hud = app.hud
	var map: Dictionary = app.catalog.stage(0).map
	var tile: int = map.tiles.find("build")
	app.board_tap(Vector2i(tile % int(map.columns),tile / int(map.columns)))
	app.build_selected()
	var state: Dictionary = app.run_domain.state
	state.gold = 3000
	state.gemShards = 100
	state.gemInventory = {"attackSpeed":3,"range":2,"physicalDamage":1,"elementalDamage":2,"criticalChance":1,"armorPiercing":1}
	var turret: Dictionary = state.turrets[0]
	turret.level = 7
	app.selected_run_command("equipGem",{"slot":0,"type":"attackSpeed"})
	hud.main_tab = "turrets"; hud.tab = "gems"; hud.selected_slot = 0
	root.content_scale_size = Vector2i(440,900); root.size = Vector2i(440,900)
	await capture("initial-440")
	await click(hud.body.find_child("EquippedSlot1",true,false))
	await capture("unlock-440")
	assert(hud.body.size.y <= hud.scroll.size.y+0.5,"Unlock must fit without vertical scrolling")
	assert(hud.body.find_child("GemInventory_attackSpeed",true,false) != null)
	var before: int = state.gold
	var price: int = app.run_domain.service.quotes(state,int(turret.id)).link
	await click(hud.body.find_child("UnlockGemSlot",true,false))
	assert(int(app.run_domain.state.turrets[0].slotLimit) == 2)
	assert(int(app.run_domain.state.gold) == before-price)
	await capture("opened-440")
	root.content_scale_size = Vector2i(320,760); root.size = Vector2i(320,760)
	await create_timer(0.3).timeout
	await click(hud.body.find_child("EquippedSlot2",true,false))
	await capture("unlock-320")
	for width in [320,440]:
		root.content_scale_size = Vector2i(width,760 if width == 320 else 900); root.size = root.content_scale_size
		hud.main_tab = "gems"; hud.body_key = null; hud.scroll.scroll_vertical = 0
		await capture("inventory-"+str(width))
		hud.main_tab = "turrets"; hud.tab = "gems"; hud.selected_slot = 0
		hud.configuration_cache.derived(app.run_domain.state,app.run_domain.service)["maxTurretLinkSlots"] = 6
		hud.body_key = null; hud.scroll.scroll_vertical = 0
		await capture("six-"+str(width))
	app.run_domain.state.gemInventory = {}
	for width in [320,440]:
		root.content_scale_size = Vector2i(width,760 if width == 320 else 900); root.size = root.content_scale_size
		hud.main_tab = "gems"; hud.body_key = null; hud.scroll.scroll_vertical = 0
		await capture("empty-inventory-"+str(width))
		hud.main_tab = "turrets"; hud.tab = "gems"; hud.selected_slot = 1; hud.body_key = null
		await capture("empty-strip-"+str(width))
	print("PASS actual AppLifecycle purchase input, isolated savedata, six-capacity UI fixture")
	quit()
