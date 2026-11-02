extends SceneTree
## 시안 전용(커밋 안 함): 실제 전투 캡처 위에 도전 조건 안내 배치안 A·B·C를 얹어 찍는다.
const T = preload("res://ui/app_theme.gd")
const GOLD := Color("e7c66a")
const WHITE := Color("e8f8ff")
const MUTED := Color("9fb3bf")
const FAIL := Color("ff7a52")
var base_dir := ""
var out_dir := ""

func _initialize() -> void: run.call_deferred()

func background(file: String) -> void:
	for child in root.get_children(): child.queue_free()
	await process_frame
	var image := Image.load_from_file(base_dir.path_join(file))
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.size = Vector2(440, 900)
	root.add_child(rect)

func label(parent: Node, text: String, size: int, color: Color, weight := 800) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", T.font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l

func icon(parent: Node, path: String, extent: int, tint := Color.WHITE) -> void:
	var r := TextureRect.new()
	r.texture = T.texture(path)
	r.custom_minimum_size = Vector2(extent, extent)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = tint
	parent.add_child(r)

## 로비 카드 조건 줄과 같은 재질: 어두운 반투명 바탕, 얇은 금색(실패는 주황) 테두리.
func plate(failed: bool, radius := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b141ce6") if not failed else Color("1c0f0ce8")
	box.border_color = Color(GOLD, 0.6) if not failed else Color(FAIL, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10; box.content_margin_right = 12
	box.content_margin_top = 6; box.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", box)
	return p

## 두 줄 안내: 아이콘 · 도전(또는 도전 실패) · 조건, 아래 작은 보조 문구.
func two_line(failed: bool, title: String, sub: String, title_size := 13, icon_size := 26) -> PanelContainer:
	var p := plate(failed)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	icon(row, "lobby_challenge_icon.png", icon_size, Color(1, 0.55, 0.45) if failed else Color.WHITE)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	label(top, "도전 실패" if failed else "도전", 11, FAIL if failed else GOLD, 900)
	label(top, title, title_size, WHITE)
	label(col, sub, 11, MUTED, 700)
	return p

func place_center(node: Control, y: float) -> void:
	root.add_child(node)
	await process_frame
	node.position = Vector2((440 - node.size.x) / 2.0, y)

func shot(name: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func run() -> void:
	base_dir = OS.get_environment("BASE_DIR")
	out_dir = OS.get_environment("CAPTURE_DIR")
	root.size = Vector2i(440, 900)
	root.content_scale_size = Vector2i(440, 900)
	# A: 상단 HUD 아래 가운데 띠(젬 소켓과 「고정」 사이).
	await background("stage-26-round-10-legal-board.png")
	await place_center(two_line(false, "코어 피해 없이 클리어", "적이 코어에 닿으면 실패"), 112)
	await shot("A_start")
	await background("stage-26-real-projectiles.png")
	await place_center(two_line(true, "적이 코어에 닿았습니다", "클리어 보상은 그대로 받습니다"), 112)
	await shot("A_fail")
	# B: 전장 가운데 큰 카드.
	await background("stage-26-round-10-legal-board.png")
	var card := two_line(false, "코어 피해 없이 클리어", "적이 코어에 닿으면 실패", 16, 40)
	await place_center(card, 380)
	await shot("B_start")
	await background("stage-26-real-projectiles.png")
	await place_center(two_line(true, "적이 코어에 닿았습니다", "클리어 보상은 그대로 받습니다", 16, 40), 380)
	await shot("B_fail")
	# C: 하단 조작줄 위 왼쪽 한 줄 알림.
	await background("stage-26-round-10-legal-board.png")
	var c_start := plate(false, 6)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); c_start.add_child(row)
	icon(row, "lobby_challenge_icon.png", 20)
	label(row, "도전", 11, GOLD, 900)
	label(row, "코어 피해 없이 클리어", 12, WHITE)
	root.add_child(c_start)
	await process_frame
	c_start.position = Vector2(10, 688)
	await shot("C_start")
	await background("stage-26-real-projectiles.png")
	var c_fail := plate(true, 6)
	var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 6); c_fail.add_child(row2)
	icon(row2, "lobby_challenge_icon.png", 20, Color(1, 0.55, 0.45))
	label(row2, "도전 실패", 11, FAIL, 900)
	label(row2, "적이 코어에 닿았습니다", 12, WHITE)
	root.add_child(c_fail)
	await process_frame
	c_fail.position = Vector2(10, 688)
	await shot("C_fail")
	quit()
