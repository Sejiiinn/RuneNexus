extends SceneTree
## Run in the prepared/imported project. No production initialization work.
const Background = preload("res://environment/combat_space_background.gd")
const WEIGHTS := Vector3(0.2126, 0.7152, 0.0722)
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func luminance(image: Image, x: int, y: int) -> float:
	var color := image.get_pixel(clampi(x, 0, image.get_width() - 1), clampi(y, 0, image.get_height() - 1))
	return Vector3(color.r, color.g, color.b).dot(WEIGHTS)
func filtered(image: Image, position: Vector2) -> float:
	var cell := Vector2i(floor(position.x), floor(position.y))
	var part := position - Vector2(cell)
	return lerpf(lerpf(luminance(image, cell.x, cell.y), luminance(image, cell.x + 1, cell.y), part.x),
		lerpf(luminance(image, cell.x, cell.y + 1), luminance(image, cell.x + 1, cell.y + 1), part.x), part.y)
func mask_filtered(image: Image, position: Vector2) -> float:
	var cell := Vector2i(floor(position.x), floor(position.y))
	var part := position - Vector2(cell)
	return lerpf(lerpf(image.get_pixel(cell.x, cell.y).r, image.get_pixel(cell.x + 1, cell.y).r, part.x),
		lerpf(image.get_pixel(cell.x, cell.y + 1).r, image.get_pixel(cell.x + 1, cell.y + 1).r, part.x), part.y)
func run() -> void:
	check(not root.use_hdr_2d, "LDR canvas color contract")
	var texture: Texture2D = load(Background.SPACE_TEXTURE)
	var nearby: Texture2D = load(Background.NEARBY_TEXTURE)
	var source := texture.get_image()
	var mask := nearby.get_image()
	check(mask.get_format() == Image.FORMAT_RH, "single-channel half float")
	check(nearby.get_size() == texture.get_size() + Vector2(2, 2), "one texel halo")
	check(not source.has_mipmaps() and not mask.has_mipmaps(), "no mipmaps on either texture")
	check(not source.is_compressed(), "background remains lossless uncompressed GPU pixels")
	var random := RandomNumberGenerator.new()
	random.seed = 7001
	var worst := 0.0
	for index in 4096:
		var uv := Vector2(random.randf(), random.randf())
		if index < 256:
			var edges := [0.0, 0.25 / texture.get_width(), 0.5 / texture.get_width(), 1.0]
			uv = Vector2(edges[index % 4], float(index / 4) / 64.0)
			if index % 2 == 0: uv = Vector2(uv.y, uv.x)
		var position := uv * texture.get_size() - Vector2(0.5, 0.5)
		var old := 0.0
		for offset in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			old += filtered(source, position + offset) * 0.25
		var difference := absf(old - mask_filtered(mask, position + Vector2.ONE))
		worst = maxf(worst, difference)
	check(worst < 0.00025, "half float convolution bound including edge strips")
	print("COMBAT_SPACE_MASK checks=", checks, " max_luminance_error=", worst, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
