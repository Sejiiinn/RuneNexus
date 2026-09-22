extends SceneTree
const Lobby = preload("res://ui/lobby.gd")
class FakeApp extends RefCounted:
	var progression_inputs: Dictionary = {"runes":1000,"unlockedStageCount":2,"totalCorePoints":5}
	var catalog = preload("res://content/content_catalog.gd").new()
	var run_domain = preload("res://session/run_session.gd").new()
	var checkpoint = {"message":"", "preferences":{}}
	var startup_blocked := false
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


func _initialize() -> void: call_deferred("run")
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
func labels(node: Node) -> Array:
	var result: Array = [node] if node is Label else []
	for child in node.get_children(): result.append_array(labels(child))
	return result
func check(lobby: Control) -> void:
	var frame: Rect2 = lobby.modal_frame.get_global_rect()
	assert(Rect2(Vector2.ZERO,lobby.size).encloses(frame), "Modal outside viewport: %s %s"%[frame,lobby.size])
	assert(frame.get_center().distance_to(lobby.size/2)<1, "Animation overwrote centered layout")
	for label in labels(lobby.modal_frame):
		if label.text in ["기록 없음","잠김","클리어 보상","강화","연구","최초 클리어 보상","시작하기","시작 불가"]:
			assert(label.get_line_count()==1,"Vertical caption: "+label.text)
func run() -> void:
	assert(not ProjectSettings.get_setting("accessibility/disable_animations",false))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var app := FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	for width in [320,440]:
		root.size = Vector2i(width,900)
		root.content_scale_size = Vector2i(width,760)
		for stage in [1,8,11]:
			app.progression_inputs.unlockedStageCount = 11 if stage==11 else 2
			lobby.open_page("스테이지")
			lobby.stages.select_chapter(ceili(stage/5.0))
			await create_timer(1.0).timeout
			for target in lobby.stages.canvas.get_children():
				if target is Button and target.tooltip_text == "스테이지 %d 상세"%stage:
					click(target)
			assert(is_instance_valid(lobby.modal),"Actual stage-row click opens details")
			await create_timer(0.4).timeout
			check(lobby)
			for chip in lobby.modal_body.find_children("UnlockChip*","PanelContainer",true,false):
				var reward_label: Label = chip.find_child("RewardName",true,false)
				assert(reward_label.get_theme_font_size("font_size")==16,"Reward labels must not shrink")
				assert(reward_label.size.y >= reward_label.get_minimum_size().y,"Wrapped reward text fits")
			print("PASS modal width=",width," stage=",stage," rect=",lobby.modal_frame.get_global_rect())
			if not OS.get_environment("MODAL_OUT").is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("MODAL_OUT")+"/after-%d-stage%d.png"%[width,stage])
			var action := lobby.modal_body.find_child("StageAction",true,false) as Button
			assert(action.disabled == (stage==8))
			assert(lobby.modal_scroll.get_global_rect().encloses(action.get_global_rect()))
			var count: int = app.starts.size()
			click(action)
			assert(app.starts.size() == count+(0 if stage==8 else 1),"Actual start hit")
			if stage != 8:
				assert(not is_instance_valid(lobby.modal), "Start closes modal")
				await create_timer(0.3).timeout
				lobby.stages.details(stage)
				await create_timer(0.4).timeout
				check(lobby)
			click(lobby.modal_frame.find_child("CloseStageDetails",true,false))
			assert(not is_instance_valid(lobby.modal),"Actual close hit")
			await create_timer(0.3).timeout
	# A resize while the entrance tween is active must not restore its old location.
	lobby.stages.details(1)
	await create_timer(0.04).timeout
	root.size = Vector2i(440,1100)
	await create_timer(0.4).timeout
	check(lobby)
	# In a short logical viewport only body content scrolls; close remains fixed.
	root.content_scale_size = Vector2i(320,260)
	root.size = Vector2i(320,260)
	await create_timer(0.3).timeout
	check(lobby)
	assert(lobby.modal_scroll.get_v_scroll_bar().max_value > lobby.modal_scroll.size.y)
	lobby.modal_scroll.scroll_vertical = 10000
	await process_frame
	await process_frame
	var action := lobby.modal_body.find_child("StageAction",true,false) as Control
	assert(lobby.modal_scroll.get_global_rect().encloses(action.get_global_rect()),"Scrolled start reachable")
	var close := lobby.modal_frame.find_child("CloseStageDetails",true,false) as Control
	assert(Rect2(Vector2.ZERO,lobby.size).encloses(close.get_global_rect()),"Close stays visible during scroll")
	click(close)
	assert(not is_instance_valid(lobby.modal))
	print("PASS lobby_modal: animations ON, 320/440 physical900 logical760 expand, caption lines, actual stage/start/close hits, resize during tween, short viewport scroll")
	lobby.free()
	quit()
