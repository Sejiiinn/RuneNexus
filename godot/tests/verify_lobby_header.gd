extends SceneTree
const Lobby = preload("res://ui/lobby.gd")
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


func _initialize() -> void: call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	var app := FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	var lobby := Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	for width in [320,440]:
		root.size = Vector2i(width,900)
		root.content_scale_size = Vector2i(width,900)
		for long_balance in [false,true]:
			app.progression_inputs.freeDiamonds = 123456789012345678 if long_balance else 1280
			app.progression_inputs.runes = 987654321012345678 if long_balance else 10000
			app.progression_inputs.turretModules = {"tickets":123456789012345678 if long_balance else 2,"items":[]}
			for page in ["스테이지","코어","강화","연구","포탑"]:
				lobby.open_page(page)
				for i in range(5): await process_frame
				var header := lobby.find_child("MenuHeader",true,false) as Control
				var back := lobby.find_child("MenuBack",true,false) as Button
				var wallet := lobby.find_child("MenuResources",true,false) as Control
				var heading := lobby.find_child("MenuHeading",true,false) as Control
				var bounds := Rect2(Vector2.ZERO,Vector2(width,900))
				assert(bounds.encloses(header.get_global_rect()),"Header overflow: %s %d long=%s"%[page,width,long_balance])
				assert(not wallet.get_global_rect().intersects(heading.get_global_rect()),"Wallet and title overlap")
				assert(back.size.y >=26 and back.size.y <=28 and back.size.x >=40,"Compact back dimensions")
				assert(back.global_position.y >= heading.get_global_rect().end.y + 2,"Back belongs below the title")
				assert(is_equal_approx(back.global_position.x,heading.global_position.x),"Back aligns to the left title group")
				assert(not wallet.get_global_rect().intersects(back.get_global_rect()),"Wallet and back overlap")
				var title := lobby.find_child("MenuTitle",true,false) as Label
				if title: assert(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,"Title is left aligned")
				for row in wallet.get_child(0).get_children():
					var label := row.get_child(1) as Label
					assert(label.size.x+0.1 >= label.get_minimum_size().x,"Balance clipped")
				if not OS.get_environment("HEADER_OUT").is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OS.get_environment("HEADER_OUT")+"/%d-%s-%s.png"%[width,page,"long" if long_balance else "normal"])
				if page == "스테이지":
					await click(lobby.find_child("StageQuests",true,false))
					assert(is_instance_valid(lobby.modal))
					lobby.close_modal()
					await process_frame
				await click(lobby.find_child("MenuBack",true,false))
				assert(lobby.page == "로비" and is_instance_valid(lobby.home),"Back navigates to home")
				lobby.open_page(page)
				lobby.find_child("TabResearch",true,false).pressed.emit()
				assert(lobby.page == "연구", "Footer page transition")
	print("PASS lobby_header: 320/440, five pages, 18-digit balances, left title / compact back below, bounds/no overlap, pointer back and stage quests")
	lobby.free()
	quit()

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
