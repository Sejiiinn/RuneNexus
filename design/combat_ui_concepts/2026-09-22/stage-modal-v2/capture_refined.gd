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
	root.size = Vector2i(440,900)
	root.content_scale_size = Vector2i(440,760)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var app := FakeApp.new()
	app.catalog.load_catalog()
	app.run_domain.growth.load_catalog()
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	lobby.open_page("스테이지")
	await create_timer(1).timeout
	lobby.stages.details(1)
	await create_timer(0.4).timeout
	check(lobby)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("MODAL_OUT")+"/refined-440-stage1.png")
	lobby.free()
	quit()
