extends SceneTree
const Lobby = preload("res://ui/lobby.gd")
class FontMetrics extends RefCounted:
	pass # Java fields must not be read as GDScript properties.
class FontConversion extends RefCounted:
	func applyDimension(unit: int, points: float, _metrics: Object) -> float:
		if unit == 1: return points * 3.0
		return points * 3.0 * (2.0 if points <= 14 else 1.8)
class LargeTextHome extends "res://ui/lobby_home.gd":
	func _refresh_text_scale() -> void:
		_font_sizes.clear()
		_android_metrics = FontMetrics.new()
		_typed_value = FontConversion.new()
		text_scale = float(_font_size(14))/14.0
class FakeApp extends RefCounted:
	var progression_inputs: Dictionary = {"runes":1000,"unlockedStageCount":2,"totalCorePoints":5}
	var catalog = preload("res://content/content_catalog.gd").new()
	var run_domain = preload("res://session/run_session.gd").new()
	var checkpoint = {"message":"", "preferences":{}}
	var startup_blocked := false
	var services: Variant = null
	var commands: Array = []
	var quit_requested := false
	var starts: Array = []
	var resumes := 0
	func apply_growth_command(command: Dictionary) -> bool:
		commands.append(command)
		var result: Dictionary = run_domain.growth.execute(progression_inputs, command)
		if result.ok: progression_inputs = result.state
		return result.ok
	func persist_progression() -> bool: return true
	func resume_run() -> bool:
		resumes += 1
		return true
	func start_stage(index: int) -> bool:
		starts.append(index)
		return true
	func request_quit() -> void: quit_requested = true

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	var home_script = preload("res://ui/lobby_home.gd")
	assert(home_script._cutout_insets([], Vector2(1080, 2424)) == Vector4.ZERO)
	assert(home_script._cutout_insets([Rect2(450, 0, 180, 90)], Vector2(1080, 2424)) == Vector4(0, 90, 0, 0))
	assert(home_script._cutout_insets([Rect2(500, 12, 80, 80)], Vector2(1080, 2424)) == Vector4(0, 92, 0, 0))
	assert(home_script._cutout_insets([Rect2(0, 400, 90, 180)], Vector2(2424, 1080)) == Vector4(90, 0, 0, 0))
	var app := FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	await process_frame
	assert(not lobby.home.canvas.has_node("ContinueRun"))
	for id in ["Settings", "StageSelect", "Leaderboard", "Events", "Mailbox", "Core", "Upgrades", "Research", "Modules"]:
		assert(lobby.home.canvas.has_node(id), "Missing home action: " + id)
	app.startup_blocked = true
	app.services = {"updates":{"blocked":true}}
	lobby.home._layout()
	assert(lobby.home.canvas.get_node("StartupStatus").text == "업데이트 확인을 완료하면 저장을 불러옵니다.", "Unopened save during update gate is not a load failure")
	assert(lobby.home.canvas.has_node("RetryUpdate") and not lobby.home.canvas.has_node("RetryLoad"), "Update gate offers its own recovery action")
	app.services.updates.blocked = false
	lobby.home._layout()
	assert(lobby.home.canvas.get_node("StartupStatus").text == "저장을 불러오지 못했습니다. 기존 저장은 보존됩니다.", "Actual blocked load keeps preservation warning")
	assert(lobby.home.canvas.has_node("RetryLoad") and not lobby.home.canvas.has_node("RetryUpdate"))
	app.services = null
	app.startup_blocked = false
	lobby.home._layout()
	lobby.home.open_settings()
	assert(is_instance_valid(lobby.home.modal))
	await process_frame
	await process_frame
	assert(lobby.home.modal_scroll is ScrollContainer)
	assert(lobby.home.modal_frame.scale == Vector2.ONE)
	lobby.home.size = Vector2(320,220)
	lobby.home._layout_modal()
	assert(lobby.home.modal_frame.scale == Vector2.ONE, "Short home modal must scroll rather than shrink touch targets")
	assert(lobby.home.modal_frame.size.y <= 220*0.85+1)
	assert(lobby.home.modal_content.get_combined_minimum_size().y > lobby.home.modal_scroll.size.y)
	lobby.go_back()
	assert(not is_instance_valid(lobby.home.modal))
	assert(not app.quit_requested, "Back must close a home modal before quitting")
	lobby.home.open_events()
	lobby.home.modal_frame.find_child("Quests",true,false).pressed.emit()
	assert(lobby.page == "로비" and is_instance_valid(lobby.modal))
	assert(not is_instance_valid(lobby.home.modal))
	lobby.go_back()
	assert(lobby.page == "로비")
	app.run_domain.state = {"stage":0,"roundIndex":2,"phase":"preparation"}
	lobby.refresh()
	await process_frame
	assert(lobby.home.canvas.has_node("ContinueRun"))
	for dimensions in [Vector2(320, 568), Vector2(440, 988)]:
		lobby.home.size = dimensions
		lobby.home._layout()
		var bounds := Rect2(lobby.home.global_position, dimensions)
		for id in ["Settings", "StageSelect", "ContinueRun", "Core", "Modules"]:
			assert(bounds.encloses(lobby.home.canvas.get_node(id).get_global_rect()), "Home action outside viewport: " + id)
	var enlarged := LargeTextHome.new()
	enlarged.lobby = lobby
	root.add_child(enlarged)
	enlarged.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	enlarged.size = Vector2(320,568)
	enlarged._layout()
	assert(enlarged._font_size(12) == 24 and enlarged._font_size(20) == 36, "SP conversion must preserve per-size nonlinear scaling")
	assert(enlarged.canvas.size.y >= 320.0/853*1844*0.5+650)
	for id in ["Settings","StageSelect","ContinueRun","Core","Modules"]:
		assert(Rect2(enlarged.global_position,enlarged.size).encloses(enlarged.canvas.get_node(id).get_global_rect()), "Large-text action outside safe canvas: " + id)
	enlarged.free()
	app.run_domain.state = {}
	lobby.refresh()
	for page in ["스테이지", "강화", "연구", "코어", "포탑", "설정", "로비"]:
		lobby.open_page(page)
		await process_frame
		if page == "로비":
			assert(is_instance_valid(lobby.home))
			assert(not _has_scroll(lobby.home), "Home must stay fixed, not become a scrolling list")
		else:
			assert(lobby.safe.get_child_count() > 0)
	for dimensions in [Vector2(320,568),Vector2(440,988)]:
		root.content_scale_size = Vector2i(dimensions)
		lobby.size = dimensions
		for page in ["스테이지","강화","연구","코어","포탑"]:
			lobby.open_page(page)
			await process_frame
			await process_frame
			assert(lobby.body.get_combined_minimum_size().x <= dimensions.x, "Page too wide: " + page)
			var bounds := Rect2(Vector2.ZERO,dimensions)
			var tabs := lobby.find_child("MenuTabs",true,false) as Control
			assert(bounds.encloses(tabs.get_global_rect()), "Tabs outside viewport: " + page)
		lobby.open_quests()
		await process_frame
		await process_frame
		assert(Rect2(Vector2.ZERO,dimensions).encloses(lobby.modal_frame.get_global_rect()), "Quest modal outside viewport")
		lobby.go_back()
	lobby.size = Vector2(1000,800)
	lobby.open_page("스테이지")
	await process_frame
	await process_frame
	assert(lobby.stages.canvas.size.x <= 400.1, "Wide stage must retain Flutter's 400 maximum width")
	lobby.stages.select_chapter(3)
	lobby.open_page("강화")
	lobby.open_page("스테이지")
	assert(lobby.stages.chapter == 1, "Page reentry must reset chapter to current progress")
	lobby._start(2)
	assert(app.starts.is_empty(), "Locked stage must not start")
	lobby._start(0)
	assert(app.starts == [0])
	app.run_domain.state = {"stage":0,"roundIndex":2,"phase":"preparation"}
	lobby._start(1)
	assert(is_instance_valid(lobby.modal) and app.starts.size() == 1)
	lobby.go_back()
	assert(app.starts.size() == 1, "Cancel keeps active run")
	lobby._start(1)
	lobby.find_child("ConfirmNewRun",true,false).pressed.emit()
	assert(app.starts == [0,1])
	lobby.open_page("강화")
	_find_button(lobby.body,"레벨업 · 룬").pressed.emit()
	assert(app.commands.size() == 1)
	assert(app.progression_inputs.runes < 1000)
	lobby.open_page("코어")
	lobby._node_details("attackHaste")
	await process_frame
	lobby.open_page("로비")
	print("LOBBY_SMOKE_OK pages=8 lock+purchase+core_dialog home=new+active+small+modal_back+events")
	lobby.queue_free()
	await process_frame
	quit()

func _has_scroll(node: Node) -> bool:
	if node is ScrollContainer: return true
	for child in node.get_children():
		if _has_scroll(child): return true
	return false

func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and (node.text.begins_with(prefix) or node.tooltip_text.begins_with(prefix)): return node
	for child in node.get_children():
		var found := _find_button(child,prefix)
		if found: return found
	return null
