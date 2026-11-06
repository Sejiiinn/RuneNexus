extends RefCounted
## Item box of a reward: a plate tinted by its kind with the icon filling it and
## the amount in the corner. Shared by the claim result and the mail list.
const T = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const DIAMONDS := {"icon":"res://assets/ui/diamond_currency.png", "name":"무료 다이아", "tint":Color("8ee6ff")}
const MODULE_TICKETS := {"icon":"stage_rewards/reward_module_ticket.png", "name":"모듈권", "tint":Color("f5cb61")}
const GEM_RESET_TICKETS := {"icon":"ui/hud/icons/gem_reset_ticket.png", "name":"젬 리셋권", "tint":Color("c9a6ff")}

static func create(kind: Dictionary, amount: String, extent: float, font_size: int, outline: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "RewardBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	var plate := Frame.new("ui/components/segment_selected_neutral.png", 4)
	plate.source_center = Rect2(6, 6, 52, 20)
	plate.modulate_color = Color(0.5, 0.62, 0.72, 0.9)
	box.add_theme_stylebox_override("panel", plate)
	box.custom_minimum_size = Vector2.ONE * extent
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(layer)
	var inner := extent - 8.0
	var glow := TextureRect.new()
	glow.texture = _glow(kind.tint)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2.ONE * inner
	layer.add_child(glow)
	var icon := TextureRect.new()
	icon.name = "RewardIcon"
	icon.texture = T.texture(kind.icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2.ONE * inner * 0.86
	icon.position = (Vector2.ONE * inner - icon.size) / 2
	layer.add_child(icon)
	var corner := extent * 0.02
	var label := T.label(amount, font_size)
	label.name = "RewardAmount"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", T.font(800))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color("02070d"))
	# The label's minimum height can exceed this, so place it from the wanted height.
	var height := ceilf(font_size * 1.5)
	label.size = Vector2(inner - corner * 2, height)
	label.position = Vector2(0, inner - height - corner)
	layer.add_child(label)
	return box

static func _glow(color: Color) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(color, 0.5), Color(color, 0.0)])
	texture.gradient = gradient
	return texture
