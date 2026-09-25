extends SceneTree
## Real UI with isolated fixtures: focus traversal, resize and delayed text layout.
const LobbyFixture = preload("res://verify_lobby.gd")
const BattleFixture = preload("res://verify_battle_hud.gd")
const Lobby = preload("res://ui/lobby.gd")
const HUD = preload("res://ui/battle_hud.gd")
var captures := OS.get_environment("UI_LAYOUT_CAPTURE_DIR")

func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(8): await process_frame
func dimensions(width: int, height: int) -> void:
	root.size = Vector2i(width,height)
	root.content_scale_size = Vector2i(width,height)
	await settle()
func capture(label: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(label+".png"))
func find_text(node: Node, prefix: String) -> Label:
	if node is Label and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var result := find_text(child,prefix)
		if result != null: return result
	return null

func check_first_visible_frames(hud: Control, max_height: float) -> void:
	for i in range(8):
		await process_frame
		if hud.modal_panel.modulate.a > 0.001:
			assert(hud.modal_panel.size.y < max_height,"Entrance must not expose the initial overestimated height")

func run() -> void:
	await dimensions(440,900)
	var app := LobbyFixture.FakeApp.new()
	assert(app.catalog.load_catalog()); assert(app.run_domain.growth.load_catalog())
	app.progression_inputs = {"runes":10000,"clearedStageNumbers":[1,2,3,4,5,6],"unlockedStageCount":7,"researchLevels":{},"activeResearches":[],"turretModules":{"items":[],"tickets":0}}
	var lobby := Lobby.new(); lobby.app = app; root.add_child(lobby)
	await settle()
	for title in ["settings","events"]:
		if title == "settings": lobby.home.open_settings()
		else: lobby.home.open_events()
		await settle()
		for i in range(3):
			# Uses Godot's real child traversal lock, as an app focus notification does.
			lobby.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			await settle()
			assert(lobby.home.modal.is_inside_tree(),"Focus must not leave a detached dialog")
			assert(lobby.home.modal_content.get_child_count() >= (5 if title == "settings" else 3),"Focus must preserve complete contents")
		await capture("home-"+title)
		print("PASS focus ",title," modal=",lobby.home.modal_frame.size)
	lobby.home.close_modal()
	lobby.open_page("연구"); await settle()
	lobby.growth._details("researchEfficiency"); await settle()
	for width in [440,320,440]:
		await dimensions(width,900)
		lobby.refresh(); await settle()
		assert(lobby.modal_frame.size.x <= width-32+0.1)
		assert(lobby.modal_frame.size.y < 500,"Short research details must not fill the viewport")
	lobby.close_modal()
	app.progression_inputs.turretModules.items = [{"id":"a","turretType":"arrow","part":"core","grade":"rare","equipped":false,"options":[]}]
	for width in [320,440]:
		await dimensions(width,900)
		lobby.open_page("포탑"); await settle()
		var count := find_text(lobby,"보유 1개")
		assert(count != null and count.get_line_count() == 1)
		assert(count.get_parent().size.y <= 40,"Inventory info must not expand from vertical character wrapping")
		await capture("modules-"+str(width))
	print("PASS lobby repeated refresh, resize, module inventory row")
	lobby.free(); await settle()
	var battle := BattleFixture.App.new()
	assert(battle.catalog.load_catalog()); assert(battle.run_domain.initialize(battle.catalog,{},0,100))
	root.add_child(battle)
	var hud := HUD.new(); hud.app = battle; battle.hud = hud; root.add_child(hud)
	await settle()
	hud.menu_panel._stage_menu(); await check_first_visible_frames(hud,200)
	for resolution in [Vector2i(440,900),Vector2i(320,568),Vector2i(440,900)]:
		await dimensions(resolution.x,resolution.y)
		assert(hud.modal_panel.size.x <= resolution.x-36+0.1,"Open battle modal must follow viewport width")
		assert(Rect2(Vector2.ZERO,root.size).encloses(hud.modal_panel.get_global_rect()),"Battle modal remains inside viewport")
		await capture("battle-menu-"+str(resolution.x))
	await dimensions(320,568)
	hud.menu_panel._end_stage_confirm()
	await check_first_visible_frames(hud,360)
	await dimensions(440,900)
	var box: VBoxContainer = hud.open_modal("본문 갱신",360)
	var text: Label = hud._label(box,"여러 줄로 표시되는 긴 안내입니다. ".repeat(80),13)
	await settle()
	var tall: float = hud.modal_panel.size.y
	text.text = "짧은 안내입니다."
	await settle()
	assert(hud.modal_panel.size.y < tall-100,"A delayed content change must release the old height")
	assert(hud.modal_panel.size.y < 220,"Short text must not leave a full-height modal")
	await capture("battle-content-shrunk")
	print("PASS battle resize and delayed shrink ",tall," -> ",hud.modal_panel.size.y)
	hud.close_modal(); await create_timer(0.25).timeout
	hud.menu_panel._portal_details({"previewText":"포탈의 적 출현 정보입니다.","spawnQueue":[]})
	await settle()
	await dimensions(320,568)
	assert(hud.modal_panel.size.x <= 296.1)
	assert(hud.modal_panel.get_global_rect().end.y <= 568.1)
	await capture("battle-bottom-sheet")
	hud.close_modal(); await create_timer(0.25).timeout
	hud.free(); battle.free(); await settle()
	print("PASS UI_LAYOUT_STABILITY")
	quit()
