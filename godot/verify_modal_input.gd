extends SceneTree
const ModalFrame = preload("res://ui/game_modal_frame.gd")
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")

var background_presses := 0
var content_presses := 0

func _initialize() -> void:
	call_deferred("run")

func click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 0
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func capture(name: String) -> void:
	var directory := OS.get_environment("MODAL_INPUT_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))

func check_shared_dismiss() -> void:
	assert(not ProjectSettings.get_setting("accessibility/disable_animations", false))
	root.size = Vector2i(440, 900)
	var scene := Control.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	var behind := Button.new()
	behind.name = "BehindModal"
	behind.position = Vector2(20, 100)
	behind.size = Vector2(400, 700)
	behind.pressed.connect(func(): background_presses += 1)
	scene.add_child(behind)
	var modal := Control.new()
	modal.name = "Modal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(modal)
	var barrier := ColorRect.new()
	barrier.color = Color(0, 0, 0, 0.8)
	barrier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(barrier)
	var panel := PanelContainer.new()
	panel.position = Vector2(100, 350)
	panel.size = Vector2(240, 200)
	modal.add_child(panel)
	var content := Button.new()
	content.name = "ModalContent"
	content.custom_minimum_size = Vector2(200, 100)
	content.pressed.connect(func(): content_presses += 1)
	panel.add_child(content)
	await process_frame
	click(content.get_global_rect().get_center())
	assert(content_presses == 1, "Modal content remains interactive")
	assert(background_presses == 0, "Modal content click reached background")
	click(Vector2(50, 200))
	assert(background_presses == 0, "Open modal leaked background input")
	ModalFrame.dismiss(modal)
	click(Vector2(50, 200))
	assert(background_presses == 0, "Fading modal leaked background input")
	await create_timer(0.3).timeout
	assert(not is_instance_valid(modal), "Dismissed modal remains after fade")
	click(Vector2(50, 200))
	assert(background_presses == 1, "Background remains blocked after dismissal")
	print("PASS modal input: content hit, open and fading barrier, background restored")
	scene.free()
	await process_frame

func run() -> void:
	root.content_scale_size = Vector2i(440, 900)
	await check_shared_dismiss()
	var app := Fixture.FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	await process_frame
	await process_frame
	var home = lobby.home
	for title in ["이벤트", "리더보드", "우편함"]:
		var shortcut_name: String = {"이벤트":"Events", "리더보드":"Leaderboard", "우편함":"Mailbox"}[title]
		click(home.canvas.get_node(shortcut_name).get_global_rect().get_center())
		await process_frame
		var current_modal: Control = home.modal if title == "이벤트" else lobby.modal
		assert(is_instance_valid(current_modal), title + " shortcut failed to open modal")
		await create_timer(0.3).timeout
		await capture(shortcut_name.to_lower())
		var close_name := "Close" if title == "이벤트" else "CloseModal"
		var close_button := current_modal.find_child(close_name, true, false) as Button
		assert(close_button != null, title + " close action missing")
		if title == "우편함":
			var outside := home.canvas.get_node("Events") as Button
			click(outside.get_global_rect().get_center())
		else:
			click(close_button.get_global_rect().get_center())
		assert(not is_instance_valid(home.modal if title == "이벤트" else lobby.modal), title + " close action failed")
		# The old, still fading overlay must intercept another home shortcut hit.
		var background_shortcut := home.canvas.get_node("Events" if title != "이벤트" else "Mailbox") as Button
		click(background_shortcut.get_global_rect().get_center())
		assert(not is_instance_valid(home.modal), title + " fade leaked to home event action")
		assert(not is_instance_valid(lobby.modal), title + " fade leaked to home service action")
		await create_timer(0.3).timeout
		click(background_shortcut.get_global_rect().get_center())
		assert(is_instance_valid(home.modal if title != "이벤트" else lobby.modal), title + " dismissal did not restore home input")
		if title == "이벤트": lobby.close_modal(true)
		else: home.close_modal()
		await create_timer(0.3).timeout
	print("PASS modal input: real Events/Leaderboard/Mailbox close and fade block background, input restored")
	lobby.free()
	quit()
