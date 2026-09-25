extends SceneTree
## Runs the real lobby/service UI with isolated, deterministic server responses.
const Fixture = preload("res://verify_lobby.gd")
const Lobby = preload("res://ui/lobby.gd")
class Service extends RefCounted:
	var tree: SceneTree
	var busy := false
	var online := true
	var updates := {"blocked":false}
	var reply := {}
	var requests := 0
	func connected() -> bool: return online
	func needs_profile() -> bool: return false
	func request(_verb: String, path: String) -> Dictionary:
		assert(path == "v1/leaderboards/progression")
		requests += 1
		await tree.process_frame
		return reply.duplicate(true)

var failures: Array[String] = []
var checks := 0
var lobby
var service: Service
var capture_dir := OS.get_environment("LEADERBOARD_CAPTURE_DIR")
var own_name := "루나#4821"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for i in range(12): await process_frame

func labels(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree(): return ""
	var result: String = node.text + "\n" if node is Label or node is RichTextLabel else ""
	for child in node.get_children(): result += labels(child)
	return result

func find_node(id: String) -> Node: return lobby.modal.find_child(id,true,false)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func touch_drag(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = point
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	for i in range(1,6):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = point-Vector2(0,i*12)
		drag.relative = Vector2(0,-12)
		Input.parse_input_event(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = point-Vector2(0,60)
	release.pressed = false
	Input.parse_input_event(release)
	await settle()

func touch_tap(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func record(rank_value: int, nickname: String, mine := false) -> Dictionary:
	return {"rank":rank_value,"displayName":nickname,"stageNumber":12,"completedRounds":20,
		"achievedAt":"2026-09-07T09:30:00Z","isMe":mine}

func response() -> Dictionary:
	var entries := []
	for i in range(1,31):
		entries.append(record(i,"별빛수호자#1042" if i == 1 else "룬기사%d#1001" % i,i == 5))
	return {"ok":true,"body":{"entries":entries,"myEntry":record(128,"루나#4821",true),"asOf":"2026-09-08T09:30:00Z"}}

func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))

func check_popup(name: String, expected: String) -> void:
	var popup := find_node("LeaderboardInfoPopup") as PopupPanel
	check(popup != null and popup.visible,"Information popup opens")
	if popup == null: return
	check(labels(popup).contains(expected),"Information popup retains requested server data")
	check(popup.size.x <= 320 and popup.size.y <= 568,"Large text popup fits the small viewport")
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		popup.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
	var buttons := popup.find_children("*","Button",true,false)
	check(not buttons.is_empty(),"Information popup has a close action")
	if not buttons.is_empty(): buttons[0].pressed.emit()
	await settle()
	check(not is_instance_valid(popup),"Closing information returns to the same leaderboard")

func dimensions(value: Vector2i) -> void:
	root.size = value
	root.content_scale_size = value
	lobby.set_deferred("size",Vector2(value))

func check_fixed_list() -> void:
	var list = find_node("LeaderboardList")
	var footer = find_node("LeaderboardFooter")
	check(list is ScrollContainer,"Ranking list scrolls independently")
	check(footer != null,"My rank footer exists")
	if list == null or footer == null: return
	var rect: Rect2 = footer.get_global_rect()
	list.scroll_vertical = 600
	await settle()
	check(list.scroll_vertical > 0,"Populated list can scroll")
	check(list.size.y >= 64,"Ranking list retains usable viewport height")
	check(rect.is_equal_approx(footer.get_global_rect()),"My rank stays fixed while rankings scroll")
	check(lobby.modal_frame.get_global_rect().encloses(rect),"My rank fits within modal")
	check(not list.is_ancestor_of(footer),"My rank is outside the ranking scroll")
	check(labels(footer).contains("128") and labels(footer).contains(own_name),"Out-of-top-100 own rank remains visible")
	check(labels(footer).contains("스테이지") and labels(footer).contains("라운드"),"Own rank retains full progression")
	list.scroll_vertical = 0
	await settle()

func run() -> void:
	ProjectSettings.set_setting("accessibility/disable_animations",true)
	Input.set_emulate_touch_from_mouse(true)
	var app := Fixture.FakeApp.new()
	app.catalog.load_catalog()
	app.run_domain.growth.load_catalog()
	service = Service.new()
	service.tree = self
	service.reply = response()
	app.services = service
	lobby = Lobby.new()
	lobby.app = app
	root.add_child(lobby)
	dimensions(Vector2i(440,900))
	await settle()
	lobby.open_service("리더보드")
	check(not labels(lobby.modal).contains("별빛수호자"),"Initial loading never shows fabricated rankings")
	await settle()
	check(service.requests == 1,"Opening leaderboard fetches once")
	check(labels(lobby.modal).contains("TOP 100"),"Board scope remains visible")
	check(labels(lobby.modal).contains("서버 확정"),"Tie ordering is explained")
	check(absf(lobby.modal_frame.size.y-900*0.84) <= 2,"Portrait board uses 84 percent of safe height")
	await check_fixed_list()
	await capture("leaderboard-440")
	var refresh := find_node("RefreshLeaderboard") as Control
	check(refresh != null,"Refresh action is present")
	if refresh != null:
		var previous := service.requests
		await click(refresh)
		check(service.requests == previous+1,"Refresh input performs exactly one request")
	var first := find_node("LeaderboardRow1") as Control
	check(first != null,"Top ranking row is present")
	if first != null:
		await touch_drag(first)
		var detail: Control = first.find_child("AchievedAt",true,false)
		check(detail != null and not detail.visible,"Dragging a row does not open confirmation detail")
		check(find_node("LeaderboardList").scroll_vertical > 0,"Touch drag scrolls the ranking list")
		find_node("LeaderboardList").scroll_vertical = 0
		await settle()
		await touch_tap(first)
		check(detail.visible,"Touch tap opens confirmation detail once")
		await touch_tap(first)
		check(not detail.visible,"Second touch tap closes confirmation detail once")
		var previous_text := labels(lobby.modal)
		await click(first)
		check(labels(lobby.modal) != previous_text,"Selecting a row reveals server confirmation detail")
		await capture("leaderboard-record-detail")
	dimensions(Vector2i(320,568))
	service.reply.body.entries[0].displayName = "아주긴별빛수호자이름#1042"
	await lobby._services._fetch()
	await settle()
	check(lobby.modal_frame.get_global_rect().end.x <= 320.1,"Narrow modal fits horizontally")
	check(lobby.modal_frame.get_global_rect().end.y <= 568.1,"Narrow modal fits vertically")
	check(labels(lobby.modal).contains("아주긴별빛수호자이름#1042"),"Long names and tags are retained")
	await check_fixed_list()
	await capture("leaderboard-320")
	for pixels in range(1,65): lobby.home._font_sizes[pixels] = pixels*2
	own_name = "별빛수호자기사단#4821"
	service.reply.body.myEntry.displayName = own_name
	await lobby._services._fetch()
	await settle()
	check(lobby.modal_frame.get_global_rect().end.x <= 320.1,"Large text modal fits horizontally")
	check(lobby.modal_frame.get_global_rect().end.y <= 568.1,"Large text modal fits vertically")
	check(find_node("LeaderboardHeader").get_global_rect().position.y >= 0,"Large text header stays on screen")
	var display_name: Label = find_node("LeaderboardMyRow").find_child("DisplayName",true,false)
	check(display_name.get_theme_font_size("font_size") == 28,"Large text exercises actual doubled fonts")
	await check_fixed_list()
	await capture("leaderboard-320-large-text")
	var guide := find_node("LeaderboardGuide") as Control
	check(guide != null,"Large text keeps ranking guidance accessible")
	if guide != null:
		await click(guide)
		await check_popup("leaderboard-large-text-guide","서버 확정 시각 기준")
	await click(find_node("LeaderboardMyRow"))
	await check_popup("leaderboard-large-text-my-record","2026.09.07")
	check(find_node("LeaderboardList").size.y >= 64,"Own record detail does not consume list space")
	service.reply = {"ok":false,"code":"REQUEST_FAILED"}
	await lobby._services._fetch()
	await settle()
	await check_fixed_list()
	check(labels(lobby.modal).contains("아주긴별빛수호자이름#1042"),"Large text refresh error retains cached rankings")
	await capture("leaderboard-large-text-refresh-error")
	lobby.home._font_sizes.clear()
	dimensions(Vector2i(440,900))
	service.reply = {"ok":false,"code":"REQUEST_FAILED"}
	await lobby._services._fetch()
	await settle()
	check(labels(lobby.modal).contains("아주긴별빛수호자이름#1042"),"Refresh error retains last successful rankings")
	await capture("leaderboard-refresh-error")
	lobby.open_service("리더보드")
	await settle()
	check(not labels(lobby.modal).contains("아주긴별빛수호자이름#1042"),"Fresh failed request does not leak stale entries")
	check(find_node("RefreshLeaderboard") != null,"Initial error offers retry")
	service.reply = {"ok":true,"body":{"entries":[],"myEntry":null,"asOf":"2026-09-08T09:30:00Z"}}
	await lobby._services._fetch()
	await settle()
	check(labels(lobby.modal).contains("기록"),"Empty board communicates missing records")
	await capture("leaderboard-empty")
	service.online = false
	lobby.open_service("리더보드")
	await settle()
	check(not labels(lobby.modal).contains(own_name),"Disconnected board does not expose previous account")
	check(labels(lobby.modal).contains("계정"),"Guest is guided to account connection")
	lobby.close_modal()
	await settle()
	check(not is_instance_valid(lobby.modal),"Close returns to lobby")
	app.services = null
	var normal: VBoxContainer = lobby.open_modal("일반 모달")
	normal.add_child(preload("res://ui/app_theme.gd").label("짧은 내용"))
	await settle()
	check(lobby.modal_frame.size.y < 300,"Generic modal keeps content-sized layout")
	lobby.free()
	await process_frame
	print("LEADERBOARD_UI checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
