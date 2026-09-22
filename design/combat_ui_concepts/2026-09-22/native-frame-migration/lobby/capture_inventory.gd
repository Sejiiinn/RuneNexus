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
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	var tag = OS.get_environment("FRAME_TAG")
	var out = OS.get_environment("FRAME_OUT")
	var app = FakeApp.new()
	app.catalog.load_catalog()
	app.run_domain.growth.load_catalog()
	app.progression_inputs = {"runes":10000,"diamonds":100,"clearedStageNumbers":range(1,16),"researchLevels":{},"activeResearches":[],"turretModules":{"tickets":2,"items":[{"id":"frame_test","turretType":"arrow","part":"core","grade":"rare","equipped":true,"options":[{"type":"damageIncrease","value":12}]}]}}
	var lobby = Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	for width in [320,440]:
		root.size = Vector2i(width,900)
		root.content_scale_size = Vector2i(width,900)
		for page in ["포탑"]:
			lobby.open_page(page)
			for i in range(4): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+tag+"-inventory-"+str(width)+"-"+page+".png")
	lobby.free()
	quit()
