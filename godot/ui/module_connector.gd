extends Control
## Reuse the original metalwork without stretching its joints or pipe thickness.
const Art = preload("res://ui/app_theme.gd")
const ART_SCALE := 0.22
const SOURCE := "turret_modules/ui/turret_connector_assembly.png"
var terminal: TextureRect
var joints: Array[TextureRect] = []
var branches: Array[NinePatchRect] = []
var risers: Array[NinePatchRect] = []
var feed: NinePatchRect

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed = _pipe(Rect2(106, 357, 163, 79), Vector4(20, 0, 20, 0))
	for i in range(2):
		risers.append(_pipe(Rect2(280, 96, 64, 257), Vector4(0, 24, 0, 24)))
	for i in range(3):
		branches.append(_pipe(Rect2(359, 26, 93, 57), Vector4(22, 0, 16, 0)))
	terminal = _joint(Rect2(4, 339, 112, 116))
	for region in [Rect2(258, 5, 113, 105), Rect2(256, 337, 116, 120), Rect2(258, 690, 113, 105)]:
		joints.append(_joint(region))

func _texture(region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = Art.texture(SOURCE)
	result.region = region
	result.filter_clip = true
	return result

func _joint(region: Rect2) -> TextureRect:
	var piece := TextureRect.new()
	piece.texture = _texture(region)
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	piece.size = region.size * ART_SCALE
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(piece)
	return piece

func _pipe(region: Rect2, margins: Vector4) -> NinePatchRect:
	var piece := NinePatchRect.new()
	piece.texture = _texture(region)
	piece.patch_margin_left = int(margins.x)
	piece.patch_margin_top = int(margins.y)
	piece.patch_margin_right = int(margins.z)
	piece.patch_margin_bottom = int(margins.w)
	# Keep source-pixel margins; transform every pipe by the same uniform scale.
	piece.scale = Vector2.ONE * ART_SCALE
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(piece)
	return piece

func arrange(preview_right: float, socket_left: float, centers: PackedFloat32Array) -> void:
	var terminal_center := Vector2(preview_right - 6, centers[1])
	# Preserve the original assembly's balance: a longer feed and visible branches.
	var trunk_x := lerpf(terminal_center.x, socket_left, 0.64)
	terminal.position = terminal_center - terminal.size / 2
	for i in range(3):
		var center := Vector2(trunk_x, centers[i])
		joints[i].position = center - joints[i].size / 2
		_horizontal(branches[i], trunk_x + 7, socket_left + 5, centers[i])
		if i < 2:
			var pipe := risers[i]
			pipe.position = Vector2(trunk_x - 32 * ART_SCALE, centers[i] + 8)
			pipe.size = Vector2(64, (centers[i + 1] - centers[i] - 16) / ART_SCALE)
	_horizontal(feed, terminal_center.x + 8, trunk_x - 8, centers[1])

func _horizontal(pipe: NinePatchRect, from: float, to: float, y: float) -> void:
	var height := pipe.texture.get_height()
	pipe.position = Vector2(from, y - height * ART_SCALE / 2)
	pipe.size = Vector2(maxf(to - from, 1) / ART_SCALE, height)
