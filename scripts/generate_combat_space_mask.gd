extends SceneTree
## Offline only. Run from the repository root:
## godot --headless --script scripts/generate_combat_space_mask.gd
## LDR canvas colors are intentionally used without sRGB-to-linear conversion.
const SOURCE := "assets/images/backgrounds/combat_space_nebula.png"
const OUTPUT := "assets/images/backgrounds/combat_space_nearby.res"
const WEIGHTS := Vector3(0.2126, 0.7152, 0.0722)

func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	assert(source != null and not source.is_empty(), "Missing background source")
	var width := source.get_width()
	var height := source.get_height()
	var luma := PackedFloat32Array()
	luma.resize(width * height)
	for y in height:
		for x in width:
			var color := source.get_pixel(x, y)
			assert(color.a == 1.0, "Background must remain opaque")
			luma[y * width + x] = Vector3(color.r, color.g, color.b).dot(WEIGHTS)
	# A one-texel halo also preserves bilinear sampling at the original edges.
	# Clamp every shifted source lookup, not the already convolved field.
	var mask := Image.create(width + 2, height + 2, false, Image.FORMAT_RH)
	for y in range(-1, height + 1):
		for x in range(-1, width + 1):
			var nearby := 0.0
			for offset in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
				nearby += luma[clampi(y + offset.y, 0, height - 1) * width + clampi(x + offset.x, 0, width - 1)]
			mask.set_pixel(x + 1, y + 1, Color(nearby * 0.25, 0.0, 0.0, 1.0))
	var texture := ImageTexture.create_from_image(mask)
	var error := ResourceSaver.save(texture, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Unable to save background luminance field: %s" % error)
		quit(1)
		return
	var metadata := {
		"source_sha256": FileAccess.get_sha256(SOURCE),
		"mask_sha256": FileAccess.get_sha256(OUTPUT),
		"generator_sha256": FileAccess.get_sha256("scripts/generate_combat_space_mask.gd"),
		"source_size": [width, height], "mask_size": [width + 2, height + 2],
		"format": "RH", "offset_texels": 3, "halo_texels": 1,
		"color_space": "LDR canvas (sRGB values)", "mipmaps": false,
	}
	var manifest := FileAccess.open(OUTPUT.get_basename() + ".json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(metadata, "\t") + "\n")
	print("COMBAT_SPACE_MASK_GENERATED ", metadata)
	quit()
