extends SceneTree
const Fixture = preload("res://verify_battle_hud.gd")
class App extends Fixture.App:
	var allow_destination := true
	var destination_count := 0
	var abandon_count := 0
	func open_stage_menu_destination() -> bool:
		if not allow_destination: return false
		destination_count += 1
		return true
	func abandon_run() -> bool:
		if not allow_destination: return false
		abandon_count += 1
		return true

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var frame = preload("res://ui/game_modal_frame.gd")
	for extent in [Vector2(1,1),Vector2(10,100),Vector2(390,200)]:
		assert(not Geometry2D.triangulate_polygon(frame.outline(Rect2(Vector2.ZERO,extent),14)).is_empty())
	root.size = Vector2i(390,844); root.content_scale_size = root.size
	var app := App.new(); root.add_child(app)
	assert(app.catalog.load_catalog()); assert(app.run_domain.initialize(app.catalog,{},0,100))
	var hud = preload("res://ui/battle_hud.gd").new(); hud.app = app; app.hud = hud; root.add_child(hud)
	await process_frame
	assert(not hud.menu_panel._has_stage_progress())
	app.run_domain.state.runUpgradeLevels = {"test":0}; assert(hud.menu_panel._has_stage_progress()); app.run_domain.state.runUpgradeLevels = {}
	app.scene._native_combat.enemies = {1:{}}; assert(hud.menu_panel._has_stage_progress()); app.scene._native_combat.enemies = {}
	app.scene._native_combat.wave = preload("res://combat/native_wave_state.gd").new()
	app.scene._native_combat.wave.queue = [{}]; assert(hud.menu_panel._has_stage_progress()); app.scene._native_combat.wave.queue = []
	hud.menu_panel._stage_menu()
	assert(hud.modal.color.is_equal_approx(Color("02070dd9")))
	var end := button(hud.modal_body,"스테이지 종료"); assert(end.disabled); assert(end.size_flags_stretch_ratio == 5)
	assert(button(hud.modal_body,"저장하고 나가기").size_flags_stretch_ratio == 6)
	assert(app.scene._native_combat.session.paused)
	hud.close_modal(); assert(not app.scene._native_combat.session.paused)
	app.run_domain.state.completedRounds = 2
	var before: Dictionary = app.run_domain.state.duplicate(true)
	hud.menu_panel._stage_menu(); hud.menu_panel._end_stage_confirm()
	assert(app.run_domain.state == before,"Reward preview must not mutate the run/progression")
	assert(hud.modal_panel.theme_type_variation == "CombatModal")
	assert(hud.modal_panel.get_theme_stylebox("panel") is StyleBoxTexture)
	assert(button(hud.modal_body,"종료").theme_type_variation == "CombatDanger")
	button(hud.modal_body,"계속 진행").pressed.emit(); assert(not hud.modal_active()); assert(not app.scene._native_combat.session.paused)
	hud.menu_panel._stage_menu(); app.allow_destination = false
	button(hud.modal_body,"저장하고 나가기").pressed.emit(); assert(hud.modal_active()); assert(app.scene._native_combat.session.paused)
	app.allow_destination = true; button(hud.modal_body,"저장하고 나가기").pressed.emit(); assert(not hud.modal_active()); assert(app.destination_count == 1)
	assert(app.scene._native_combat.session.paused,"Leaving battle must not accidentally resume")
	hud.menu_panel._end_stage_confirm(); button(hud.modal_body,"종료").pressed.emit(); assert(app.abandon_count == 1); assert(not hud.modal_active())
	app.run_domain.state.completedRounds = 0
	hud.menu_panel._portal_details(app.catalog.stage(0).waves[0]); await process_frame; await process_frame
	assert(hud.modal_bottom_sheet)
	assert(hud.modal_panel.custom_minimum_size.x == 366)
	var content := all_text(hud.modal_body)
	for expected in ["포탈 1 · 1/", "체력", "속도", "넥서스 피해", "보상"]: assert(expected in content,expected)
	hud.close_modal()
	assert(hud.rewards._record_text({"lastRunWasNewBestRound":true,"lastRunPreviousBestRound":0,"completedRounds":3},{},3) == "3R 첫 기록")
	assert(hud.rewards._record_text({}, {"clearedStageNumbers":[1]},3) == "클리어")
	assert(hud.rewards._record_text({"lastRunWasNewBestRound":true,"lastRunPreviousBestRound":2,"completedRounds":3},{},3) == "2R → 3R")
	await create_timer(0.25).timeout
	print("PASS battle menu parity: progress, frame, reward purity, cancel resume, failure retention, stage destination, portal details")
	hud.queue_free(); app.queue_free(); await process_frame; quit()
func button(node: Node,value: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == value: return child
		var found := button(child,value)
		if found != null: return found
	return null
func all_text(node: Node) -> String:
	var result := ""
	for child in node.get_children():
		if child is Label or child is Button: result += child.text+"\n"
		result += all_text(child)
	return result
