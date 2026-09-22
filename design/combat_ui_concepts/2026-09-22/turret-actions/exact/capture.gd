extends SceneTree
var app
var hud
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-22/turret-actions/exact/"
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	hud.refresh()
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	screenshot.save_png(out+name+".png")
	var bounds: Rect2 = hud.body.get_child(0).get_global_rect()
	screenshot.get_region(Rect2i(bounds.position,Vector2i(bounds.size.ceil()))).save_png(out+"panel-"+name+".png")
	if name == "after-440":
		for node in hud.body.get_child(0).find_children("*","Label",true,false):
			print("LABEL ",node.text," pos=",node.position," size=",node.size," global=",node.get_global_rect()," font=",node.get_theme_font_size("font_size"))
	print("CAPTURE ",name," panel=",hud.body.get_child(0).get_global_rect()," body=",hud.body.size," scroll=",hud.scroll.size," dock=",hud.dock.size)
func dismiss() -> void:
	hud.close_modal()
	await create_timer(0.25).timeout
func run() -> void:
	var scene = load("res://main.tscn").instantiate(); root.add_child(scene)
	await create_timer(2).timeout
	app = scene._standalone_session; hud = app.hud
	assert(OS.get_user_data_dir().contains("RuneNexus-HUD-review-v4"))
	root.content_scale_size = Vector2i(320,760)
	root.size = Vector2i(320,760)
	app.start_stage(0); hud = app.hud
	var map: Dictionary = app.catalog.stage(0).map
	var tile: int = map.tiles.find("build")
	app.board_tap(Vector2i(tile % int(map.columns),tile / int(map.columns)))
	app.build_selected()
	var state: Dictionary = app.run_domain.state
	state.gold = 3000; state.gemShards = 100
	var turret: Dictionary = state.turrets[0]
	turret.level = 7
	hud.refresh()
	hud.tab = "stats"; hud.main_tab = "turrets"; hud.body_key = ""
	await capture("after-320")
	hud._preview_level()
	await capture("after-preview-320")
	state.gold = 0; hud.refresh()
	await capture("disabled-320")
	state.gold = 3000; turret.level = 10; app.selection_view.level_preview = false; hud.body_key = ""
	await capture("max-level-320")
	root.content_scale_size = Vector2i(440,900); root.size = Vector2i(440,900)
	turret.level = 7; hud.body_key = ""
	await capture("after-440")
	turret.primaryTrait = "overheatMagazine"; hud.body_key = ""
	await capture("traits-one-440")
	turret.secondaryTrait = "suppressiveFire"; hud.body_key = ""
	await capture("traits-two-440")
	hud.tab = "gems"; hud.body_key = ""
	await capture("gems-440")
	quit()
