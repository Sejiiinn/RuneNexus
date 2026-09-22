extends SceneTree
const Fixture = preload("res://verify_lobby.gd")
const T = preload("res://ui/app_theme.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app := Fixture.FakeApp.new()
	assert(app.catalog.load_catalog())
	assert(app.run_domain.growth.load_catalog())
	var lobby := preload("res://ui/lobby.gd").new()
	lobby.app = app
	root.add_child(lobby)
	lobby.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	lobby.size = Vector2(440,360)
	lobby.growth.category = "경제"
	lobby.open_page("강화")
	for i in range(5): await process_frame
	var scroll: ScrollContainer = lobby._page_scroll
	scroll.scroll_vertical = 200
	await process_frame
	var saved := scroll.scroll_vertical
	assert(saved > 0, "Fixture must overflow to exercise scroll preservation")
	var body: VBoxContainer = lobby.open_modal("유지할 상세")
	body.add_child(T.label("내용"))
	var modal = lobby.modal
	lobby.refresh()
	for i in range(5): await process_frame
	assert(lobby._page_scroll.scroll_vertical == saved, "Growth refresh preserves scroll position")
	assert(lobby.modal == modal and is_instance_valid(modal), "Passive refresh preserves open detail")
	lobby.open_page("연구")
	for i in range(3): await process_frame
	assert(lobby.modal == null, "Explicit navigation closes old detail")
	assert(lobby._page_scroll.scroll_vertical == 0, "New page starts at top")
	lobby.open_page("스테이지")
	lobby.size = Vector2(1100,700)
	for i in range(5): await process_frame
	assert(lobby.body.size.x <= 400.1, "Stage maximum width matches Flutter")
	lobby.open_service("우편함")
	assert(lobby.modal_body.get_child(1).text == "계정 연결")
	lobby.modal_body.get_child(1).pressed.emit()
	assert(lobby.modal_body.name == "ServiceBody")
	var button := T.button("확인",func(): pass,"confirm")
	assert(button.custom_minimum_size.y == 38)
	assert(button.get_theme_font("font") == T.font(900))
	button.free()
	lobby.queue_free()
	await process_frame
	print("PASS menu shell: preserved scroll/detail, explicit navigation reset, stage width, guest service routing, button roles")
	quit()
