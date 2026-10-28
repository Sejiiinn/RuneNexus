extends SceneTree
const Lobby = preload("res://ui/lobby.gd")
class MailStatus extends RefCounted:
	signal changed
	var ready := false
	func has_unclaimed_mail() -> bool: return ready
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
	assert(lobby.page == "스테이지", "The stage map is the first screen")
	assert(lobby.home.find_child("ContinueRun",true,false) == null)
	assert(lobby.find_child("MenuBack",true,false) == null and lobby.find_child("StageHeaderLogo",true,false) == null, "No separate lobby to go back to")
	for id in ["Settings", "ChapterPrev", "ChapterNext", "StageStart", "Leaderboard", "Events", "Mailbox", "TabStage", "TabCore", "TabUpgrade", "TabResearch", "TabTurret"]:
		assert(lobby.home.find_child(id,true,false) != null, "Missing home action: " + id)
	# A tap on another stage socket selects it and the card's start button starts it.
	var map: Control = lobby.home.map
	assert(lobby.stages.selected == 1, "Opens on the first unlocked stage not cleared yet")
	_tap(map, map._centers[2] - Vector2(0, map.scroll))
	assert(lobby.stages.selected == 2 and lobby.home.card.stage == 2, "Tapping a socket selects that stage")
	var drag_from: Vector2 = map._centers[1] - Vector2(0, map.scroll)
	_press(map, drag_from, true)
	var motion := InputEventMouseMotion.new(); motion.position = drag_from - Vector2(0, 40); map._gui_input(motion)
	_press(map, drag_from - Vector2(0, 40), false)
	assert(lobby.stages.selected == 2, "A drag never selects the stage under the finger")
	lobby.home.find_child("StageStart",true,false).pressed.emit()
	assert(app.starts == [1], "Card start begins the selected stage")
	app.starts.clear()
	lobby.home.find_child("ChapterNext",true,false).pressed.emit()
	assert(lobby.stages.chapter == 2 and lobby.home.find_child("StageLocked",true,false) != null, "Next chapter shows its locked first stage")
	lobby.home.find_child("ChapterPrev",true,false).pressed.emit()
	assert(lobby.stages.chapter == 1)
	for id in ["QuestReadyDot", "MailboxReadyDot"]:
		var badge: Panel = lobby.home.canvas.get_node(id)
		assert(badge.size == Vector2(7, 7) and badge.get_theme_stylebox("panel").bg_color == Color("e53935"), "Both alerts retain 7px size with the same red circle")
		assert(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Alerts cannot block shortcut input")
		assert(badge.draw.get_connections().size() == 1, "Both alerts draw the shared white exclamation")
	assert(not lobby.home.canvas.get_node("MailboxReadyDot").visible, "Guest has no mailbox alert")
	var mail_status := MailStatus.new()
	app.services = mail_status
	lobby.refresh()
	var same_home: Control = lobby.home
	mail_status.ready = true; mail_status.changed.emit()
	assert(lobby.home == same_home and same_home.canvas.get_node("MailboxReadyDot").visible, "Mail status signal updates existing home badge")
	mail_status.ready = false; mail_status.changed.emit()
	assert(lobby.home == same_home and not same_home.canvas.get_node("MailboxReadyDot").visible, "Zero remaining mail hides badge without rebuilding home")
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
	assert(lobby.page == "스테이지" and is_instance_valid(lobby.modal))
	assert(not is_instance_valid(lobby.home.modal))
	lobby.go_back()
	assert(lobby.page == "스테이지")
	app.run_domain.state = {"stage":0,"roundIndex":2,"phase":"preparation"}
	lobby.refresh()
	await process_frame
	assert(lobby.home.find_child("ContinueRun",true,false) != null and lobby.stages.selected == 1, "An active run selects its stage with a continue action")
	lobby.home.find_child("ContinueRun",true,false).pressed.emit()
	assert(app.resumes == 1)
	for dimensions in [Vector2(320, 568), Vector2(440, 988)]:
		lobby.home.size = dimensions
		lobby.home._layout()
		var bounds := Rect2(lobby.home.global_position, dimensions)
		for id in ["Settings", "ContinueRun", "StageCard", "Mailbox", "TabCore", "TabTurret"]:
			assert(bounds.encloses(lobby.home.find_child(id,true,false).get_global_rect()), "Home action outside viewport: " + id)
		var selected_y: float = lobby.home.map._centers[lobby.stages.selected].y - lobby.home.map.scroll
		assert(selected_y > 56 and selected_y < lobby.home.card.position.y, "The selected stage shows between the header and the card")
	var enlarged := LargeTextHome.new()
	enlarged.lobby = lobby
	root.add_child(enlarged)
	enlarged.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	enlarged.size = Vector2(320,568)
	enlarged._layout()
	assert(enlarged._font_size(12) == 24 and enlarged._font_size(20) == 36, "SP conversion must preserve per-size nonlinear scaling")
	for id in ["Settings","ContinueRun","Mailbox","TabCore","TabTurret"]:
		assert(Rect2(enlarged.global_position,enlarged.size).encloses(enlarged.find_child(id,true,false).get_global_rect()), "Large-text action outside safe canvas: " + id)
	enlarged.free()
	app.run_domain.state = {}
	lobby.refresh()
	for page in ["강화", "연구", "코어", "포탑", "설정", "스테이지"]:
		lobby.open_page(page)
		await process_frame
		if page == "스테이지":
			assert(is_instance_valid(lobby.home))
			assert(not _has_scroll(lobby.home), "Home must stay fixed, not become a scrolling list")
		else:
			assert(lobby.safe.get_child_count() > 0)
			lobby.go_back()
			assert(lobby.page == "스테이지" and not app.quit_requested, "Back from a tab returns to the stage map")
			lobby.open_page(page)
	# Real logical sizes only: the 440x760 expand base never renders narrower than 440.
	for dimensions in [Vector2(440,760),Vector2(440,988),Vector2(760,1000)]:
		root.content_scale_size = Vector2i(dimensions)
		lobby.size = dimensions
		for page in ["스테이지","강화","연구","코어","포탑"]:
			lobby.open_page(page)
			await process_frame
			await process_frame
			if page != "스테이지": assert(lobby.body.get_combined_minimum_size().x <= dimensions.x, "Page too wide: " + page)
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
	assert(lobby.home.canvas.size.x <= 460.1 and lobby.home.find_child("MapBackdrop",true,false).visible, "Wide screens keep a map column over the dimmed backdrop")
	lobby.stages.select_chapter(3)
	lobby.open_page("강화")
	lobby.open_page("스테이지")
	assert(lobby.stages.chapter == 1, "Page reentry must reset chapter to current progress")
	lobby.request_stage_start(2)
	assert(app.starts.is_empty(), "Locked stage must not start")
	lobby.request_stage_start(0)
	assert(app.starts == [0])
	app.run_domain.state = {"stage":0,"roundIndex":2,"phase":"preparation"}
	lobby.request_stage_start(1)
	assert(is_instance_valid(lobby.modal) and app.starts.size() == 1)
	lobby.go_back()
	assert(app.starts.size() == 1, "Cancel keeps active run")
	lobby.request_stage_start(1)
	lobby.find_child("ConfirmNewRun",true,false).pressed.emit()
	assert(app.starts == [0,1])
	lobby.open_page("강화")
	_find_button(lobby.body,"레벨업 · 룬").pressed.emit()
	assert(app.commands.size() == 1)
	assert(app.progression_inputs.runes < 1000)
	lobby.open_page("코어")
	lobby._node_details("attackHaste")
	await process_frame
	lobby.open_page("스테이지")
	lobby.go_back()
	assert(app.quit_requested, "Back on the stage map leaves the app")
	print("LOBBY_SMOKE_OK pages=8 lock+purchase+core_dialog home=new+active+small+modal_back+events")
	lobby.queue_free()
	await process_frame
	quit()

func _press(control: Control, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = down
	control._gui_input(event)

func _tap(control: Control, at: Vector2) -> void:
	_press(control, at, true)
	_press(control, at, false)

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
