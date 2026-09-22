extends SceneTree
## Frame migration contract: keep logical corners, padding, states and HUD roles.
const Chrome = preload("res://ui/hud_chrome.gd")
const Fixture = preload("res://verify_battle_hud.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var primary := Chrome.primary("normal")
	assert(primary is StyleBoxTexture)
	assert(primary.texture.get_size() == Vector2(300,56))
	assert(primary.texture_margin_left == 12 and primary.texture_margin_right == 12)
	assert(primary.texture_margin_top == 14 and primary.texture_margin_bottom == 14)
	assert(primary.content_margin_left == 12 and primary.content_margin_top == 0)
	assert(Chrome.primary("disabled").modulate_color == Color("627780"))
	assert(Chrome.primary("pressed").modulate_color == Color("9bc3cd"))
	var popup := Chrome.panel(10)
	assert(popup is StyleBoxTexture and popup.texture_margin_left == 14)
	assert(popup.content_margin_left == 10)
	var dock := Chrome.docked_panel(5)
	assert(dock is StyleBoxTexture and dock.texture_margin_top == 4)
	assert(dock.texture_margin_left == 0 and dock.texture_margin_right == 0 and dock.texture_margin_bottom == 0)
	assert(dock.content_margin_left == 5 and dock.texture.resource_path.ends_with("ui/hud/dock_panel.png"))
	assert(Chrome.quiet("normal") is StyleBoxFlat)
	var app := Fixture.App.new()
	assert(app.catalog.load_catalog() and app.run_domain.initialize(app.catalog,{},0,100))
	root.add_child(app)
	var hud := preload("res://ui/battle_hud.gd").new(); hud.app = app; app.hud = hud; root.add_child(hud)
	for width in [320,440]:
		root.content_scale_size = Vector2i(width,900); root.size = root.content_scale_size
		hud.main_tab = "turrets"; hud.body_key = ""; hud.refresh()
		await process_frame; await process_frame; await process_frame
		assert(hud.start.theme_type_variation == "HudPrimary")
		for state in ["normal","hover","pressed","disabled","focus"]:
			assert(hud.start.get_theme_stylebox(state) is StyleBoxTexture)
		assert(hud.auto_start_popup.theme_type_variation == "HudPopup")
		assert(hud.auto_start_popup.get_theme_stylebox("panel") is StyleBoxTexture)
		assert(hud.detail_panel.theme_type_variation == "HudDock")
		assert(hud.bottom.get_node("RunPanelTabs").theme_type_variation == "HudTabs")
		assert(hud.dock.get_global_rect().position.x == 0 and hud.dock.size.x == width)
		assert(hud.start.size == Vector2(76,36))
		assert(hud.top.get_node("ResourceHUD").theme_type_variation == "ResourceHUD")
	hud.queue_free(); app.queue_free(); await process_frame
	print("PASS native HUD frames: primary/popup/dock texture styles, fixed margins, states, edge attachment, 320/440 geometry")
	quit()
