extends SceneTree
## Turns the badge SVG into the atlas. ThorVG has no text support, so labels become Roboto glyph paths first.

func _initialize() -> void:
	var font := FontFile.new()
	font.load_dynamic_font(OS.get_environment("BADGE_FONT"))
	var heavy := FontVariation.new()
	heavy.base_font = font
	heavy.variation_opentype = {2003265652: 900.0}
	var svg := FileAccess.get_file_as_string(OS.get_environment("BADGE_SVG"))
	var marker := RegEx.create_from_string("<!--LABEL ([^|]+)\\|([^|]+)\\|([^|]+)\\|([^>]+)-->")
	for found in marker.search_all(svg):
		svg = svg.replace(found.get_string(), _label(heavy, found.get_string(1), found.get_string(2).to_float(), found.get_string(3).to_float(), found.get_string(4)))
	var image := Image.new()
	var error := image.load_svg_from_string(svg, 1.0)
	if error != OK:
		printerr("svg failed: %s" % error)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var frame_width := OS.get_environment("BADGE_FRAME_WIDTH").to_int()
	for index in OS.get_environment("BADGE_FRAMES").to_int():
		var used := image.get_region(Rect2i(index * frame_width, 0, frame_width, image.get_height())).get_used_rect()
		print("Lv.%d bounds %s" % [index + 1, used])
		if used.position.x < 8 or used.end.x > frame_width - 8 or used.position.y < 8 or used.end.y > image.get_height() - 8:
			printerr("frame %d touches the margin" % (index + 1))
			quit(1)
			return
	error = image.save_png(OS.get_environment("BADGE_OUT"))
	print("ATLAS OK" if error == OK else "save failed")
	quit(error)

## Measures at 16x so hinting stays out of the outline, then scales back to logical size.
func _label(font: Font, text: String, size: float, baseline: float, fill: String) -> String:
	var server := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var glyph_size := Vector2i(int(size * 16.0), 0)
	var ratio := 1.0 / 16.0
	var width := 0.0
	var glyphs := []
	for code in text.to_utf32_buffer().to_int32_array():
		var glyph := server.font_get_glyph_index(rid, glyph_size.x, code, 0)
		glyphs.append(glyph)
		width += server.font_get_glyph_advance(rid, glyph_size.x, glyph).x * ratio
	var pen := -width / 2.0
	var path := ""
	for glyph in glyphs:
		path += _outline(server, rid, glyph_size.x, glyph, pen, baseline, ratio)
		pen += server.font_get_glyph_advance(rid, glyph_size.x, glyph).x * ratio
	return '<path d="%s" fill="%s"/>' % [path, fill]

func _outline(server: TextServer, rid: RID, size: int, glyph: int, x: float, y: float, ratio: float) -> String:
	var data: Dictionary = server.font_get_glyph_contours(rid, size, glyph)
	if data.is_empty(): return ""
	var points: PackedVector3Array = data.points
	var path := ""
	var start := 0
	for end in data.contours:
		var loop := []
		for index in range(start, int(end) + 1):
			loop.append(points[index])
		start = int(end) + 1
		path += _contour(loop, x, y, ratio)
	return path

## TrueType contours: z 1 is on-curve, z 0 a quadratic control with implied midpoints.
func _contour(loop: Array, x: float, y: float, ratio: float) -> String:
	var first := 0
	while first < loop.size() and loop[first].z != 1.0:
		first += 1
	if first == loop.size(): return ""
	var size := loop.size()
	var at := func(p: Vector2) -> String: return "%.3f %.3f" % [x + p.x * ratio, y + p.y * ratio]
	var flat := func(p: Vector3) -> Vector2: return Vector2(p.x, p.y)
	var path: String = "M" + at.call(flat.call(loop[first]))
	var control = null
	for step in range(1, size + 1):
		var point: Vector3 = loop[(first + step) % size]
		var here: Vector2 = flat.call(point)
		if point.z == 1.0:
			path += ("Q%s %s" % [at.call(control), at.call(here)]) if control != null else ("L" + at.call(here))
			control = null
		else:
			if control != null:
				path += "Q%s %s" % [at.call(control), at.call((control + here) / 2.0)]
			control = here
	return path + "Z"
