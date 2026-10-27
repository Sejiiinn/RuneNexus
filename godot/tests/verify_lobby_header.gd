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
				var bounds := Rect2(Vector2.ZERO,Vector2(width,900))
				if page == "스테이지":
					# The stage map header: chapter switcher and wallet, no back button; settings sit in the bottom strip.
					var wallet_box := lobby.find_child("HomeWallet",true,false) as Control
					var parts := ["ChapterPrev","ChapterTitle","ChapterNext","ChapterRange"].map(func(id): return lobby.find_child(id,true,false) as Control)
					for part in parts + [wallet_box]:
						assert(bounds.encloses(part.get_global_rect()),"Stage header overflow: %s %d long=%s"%[part.name,width,long_balance])
						if part != wallet_box: assert(not wallet_box.get_global_rect().intersects(part.get_global_rect()),"Wallet overlaps %s"%part.name)
					var strip := (lobby.find_child("ShortcutStrip",true,false) as Control).get_global_rect()
					for id in ["Leaderboard","Events","Mailbox","Settings"]:
						var cell := lobby.find_child(id,true,false) as Control
						assert(strip.grow(0.5).encloses(cell.get_global_rect()),"Shortcut outside the strip: %s %d"%[id,width])
						for label in cell.find_children("*","Label",true,false):
							assert(label.size.x+0.1 >= label.get_minimum_size().x,"Shortcut label clipped: %s %d"%[id,width])
					for id in ["Diamonds","Runes"]:
						var balance := wallet_box.find_child(id,true,false) as Label
						assert(balance.size.x+0.1 >= balance.get_minimum_size().x,"Balance clipped")
					assert(lobby.find_child("MenuBack",true,false) == null and lobby.find_child("StageQuests",true,false) == null,"No back button or stage quest icon")
				else:
					var header := lobby.find_child("MenuHeader",true,false) as Control
					var wallet := lobby.find_child("MenuResources",true,false) as Control
					var heading := lobby.find_child("MenuHeading",true,false) as Control
					assert(bounds.encloses(header.get_global_rect()),"Header overflow: %s %d long=%s"%[page,width,long_balance])
					assert(not wallet.get_global_rect().intersects(heading.get_global_rect()),"Wallet and title overlap")
					assert(lobby.find_child("MenuBack",true,false) == null,"Tabs return through the stage tab, not a back button")
					var title := lobby.find_child("MenuTitle",true,false) as Label
					if title: assert(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,"Title is left aligned")
					for row in wallet.get_child(0).get_children():
						var label := row.get_child(1) as Label
						assert(label.size.x+0.1 >= label.get_minimum_size().x,"Balance clipped")
				if not OS.get_environment("HEADER_OUT").is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OS.get_environment("HEADER_OUT")+"/%d-%s-%s.png"%[width,page,"long" if long_balance else "normal"])
				if page != "스테이지":
					await click(lobby.find_child("TabStage",true,false))
					assert(lobby.page == "스테이지" and is_instance_valid(lobby.home),"Stage tab returns to the map")
				lobby.open_page(page)
				lobby.find_child("TabResearch",true,false).pressed.emit()
				assert(lobby.page == "연구", "Footer page transition")
	print("PASS lobby_header: 320/440, five pages, 18-digit balances, stage map header and tab headers, bounds/no overlap, pointer stage tab return")
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
