extends SceneTree
var app
var hud
var turret: Dictionary
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-24/trait-modal/implementation/"
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
func click(node: Control) -> void:
	assert(is_instance_valid(node))
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = node.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		root.push_input(event,true)
	await settle()
func shot(label: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(out+label+".png")
	print("CAPTURE ",label," modal=",hud.modal_panel.get_global_rect()," content=",hud.modal_body.size)
func open_traits() -> void:
	hud.refresh(); await settle()
	await click(hud.body.find_child("TurretTraitAction",true,false))
	assert(hud.modal_active())
func close_traits() -> void:
	hud.close_modal(); await settle()
func reset_trait(kind: String) -> void:
	turret = app.run_domain.state.turrets[0]
	turret.type = kind; turret.level = 7
	turret.primaryTrait = null; turret.secondaryTrait = null
	app.run_domain.state.gemShards = 1000
	app.refresh_selection()
func run() -> void:
	assert(OS.get_user_data_dir().contains("RuneNexus-TurretStats-Review"))
	root.content_scale_size = Vector2i(440,900); root.size = Vector2i(440,900)
	var scene = load("res://main.tscn").instantiate(); root.add_child(scene)
	await create_timer(1.5).timeout
	app = scene._standalone_session; app.autosave_interval = 100000.0; app.start_stage(0)
	hud = app.hud
	var map: Dictionary = app.catalog.stage(0).map
	var tile: int = map.tiles.find("build")
	app.board_tap(Vector2i(tile % int(map.columns),tile / int(map.columns)))
	app.build_selected(); app.run_domain.state.gold = 3000
	turret = app.run_domain.state.turrets[0]
	hud.main_tab = "turrets"; hud.tab = "stats"
	for kind in ["arrow","cannon","magic","frost","sniper","lightning"]:
		reset_trait(kind); await open_traits()
		var quote: Dictionary = app.run_domain.service.quotes(app.run_domain.state,int(turret.id))
		await click(hud.modal_body.find_child("TraitChoice_"+str(quote.primaryTraits[0]),true,false))
		await shot(kind+"-primary-440")
		await close_traits()
		assert(app.selected_run_command("primaryTrait",{"type":quote.primaryTraits[0]}))
		await open_traits()
		await click(hud.modal_body.find_child("TraitChoice_"+str(quote.secondaryTraits[0]),true,false))
		await shot(kind+"-secondary-440")
		await close_traits()
	reset_trait("arrow")
	root.content_scale_size = Vector2i(320,720); root.size = Vector2i(320,720)
	await open_traits()
	await click(hud.modal_body.find_child("TraitChoice_overheatMagazine",true,false))
	await shot("arrow-primary-320"); await close_traits()
	root.content_scale_size = Vector2i(440,480); root.size = Vector2i(440,480)
	await open_traits(); await shot("short-top")
	hud.modal_scroll.scroll_vertical = 10000; await shot("short-bottom"); await close_traits()
	root.content_scale_size = Vector2i(320,480); root.size = Vector2i(320,480)
	await open_traits(); await shot("short-320-top")
	hud.modal_scroll.scroll_vertical = 10000; await shot("short-320-bottom"); await close_traits()
	root.content_scale_size = Vector2i(440,900); root.size = Vector2i(440,900)
	turret.level = 2; await open_traits(); await shot("level-locked")
	await click(hud.modal_body.find_child("TraitTier2",true,false)); await shot("primary-required"); await close_traits()
	turret.level = 7; app.run_domain.state.gemShards = 0
	await open_traits(); await shot("shards-short"); await close_traits()
	app.run_domain.state.gemShards = 1000
	assert(app.selected_run_command("primaryTrait",{"type":"overheatMagazine"}))
	assert(app.selected_run_command("secondaryTrait",{"type":"suppressiveFire"}))
	await open_traits(); await shot("already-selected"); await close_traits()
	print("TRAIT_MODAL_CAPTURE_COMPLETE")
	quit()
