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


func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(440,900)
	root.content_scale_size = Vector2i(440,760)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var app = FakeApp.new()
	app.catalog.load_catalog()
	app.run_domain.growth.load_catalog()
	var lobby = Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	lobby.open_page("스테이지")
	for i in range(4): await process_frame
	await create_timer(1.0).timeout
	var target: Button
	for node in lobby.stages.canvas.get_children():
		if node is Button and node.tooltip_text == "스테이지 1 상세": target = node
	assert(target != null)
	var point = target.get_global_rect().get_center()
	for down in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	for delay in [0.01,0.1,0.3]:
		await create_timer(delay).timeout
		print("delay=",delay," lobby=",lobby.size," frame=",lobby.modal_frame.get_global_rect()," bodymin=",lobby.modal_body.get_combined_minimum_size())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("MODAL_OUT")+"/before.png")
	lobby.free()
	quit()
