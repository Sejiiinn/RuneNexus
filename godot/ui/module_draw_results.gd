extends RefCounted
## The summary/numbered strip and close action stay outside the result list.
const T = preload("res://ui/app_theme.gd")
const CollectionUI = preload("res://ui/lobby_collection.gd")
const ModuleIcon = preload("res://ui/module_icon.gd")
const TEXT := Color("add4ee")

class ResultNumber extends CenterContainer:
	var tint := Color.WHITE
	func _draw() -> void:
		var rect := Rect2(Vector2.ONE * 1.5, size - Vector2.ONE * 3)
		var cut := minf(size.x, size.y) * 0.25
		var points := PackedVector2Array([
			Vector2(rect.position.x + cut, rect.position.y), Vector2(rect.end.x - cut, rect.position.y),
			Vector2(rect.end.x, rect.position.y + cut), Vector2(rect.end.x, rect.end.y - cut),
			Vector2(rect.end.x - cut, rect.end.y), Vector2(rect.position.x + cut, rect.end.y),
			Vector2(rect.position.x, rect.end.y - cut), Vector2(rect.position.x, rect.position.y + cut),
			Vector2(rect.position.x + cut, rect.position.y),
		])
		draw_colored_polygon(points, Color("07111b"))
		draw_polyline(points, tint, 1.2, true)

static func _label(value: String, pixels: int, color: Color = TEXT) -> Label:
	var label := T.label(value, pixels)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func module_name(item: Dictionary) -> String:
	var turret := str(item.get("turretType", ""))
	var part := str(item.get("part", ""))
	return str(CollectionUI.MODULE_NAMES.get(turret + "_" + part, "%s · %s" % [turret if not turret.is_empty() else "알 수 없는 포탑", CollectionUI.PARTS.get(part, part if not part.is_empty() else "알 수 없는 부품")]))

static func effect_text(option: Dictionary) -> String:
	var type := str(option.get("type", ""))
	return "%s %s%d%%%s" % [CollectionUI.OPTIONS.get(type, type if not type.is_empty() else "추가 효과"), "−" if type.ends_with("Discount") else "+", int(option.get("value", 0)), "p" if type.ends_with("Bonus") else ""]

static func _number(index: int, tint: Color, extent := 26) -> Control:
	var badge := ResultNumber.new()
	badge.name = "ResultNumber"
	badge.tint = tint
	badge.custom_minimum_size = Vector2(extent, extent)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := _label(str(index), 13, tint)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(value)
	return badge

static func _line(parent: Control) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("344c5a")
	style.thickness = 1
	line.add_theme_stylebox_override("separator", style)
	parent.add_child(line)

static func _inner_width(lobby) -> float:
	var inset: Vector4 = lobby._insets()
	return minf(480, lobby.size.x - inset.x - inset.z - 32) - 32

static func _row(rows: VBoxContainer, item: Dictionary, index: int, icon_extent: int) -> void:
	var row := HBoxContainer.new()
	row.name = "ModuleResult%d" % index
	row.add_theme_constant_override("separation", 8)
	rows.add_child(row)
	var grade := str(item.get("grade", ""))
	var tint: Color = CollectionUI.COLORS.get(grade, TEXT)
	var icon := ModuleIcon.create(item, icon_extent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(_number(index, tint))
	var details := VBoxContainer.new()
	details.name = "ModuleDetails"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 1)
	row.add_child(details)
	var title := _label("%s · %s" % [CollectionUI.GRADES.get(grade, grade if not grade.is_empty() else "알 수 없는 등급"), module_name(item)], 14, tint)
	title.name = "ModuleTitle"
	title.add_theme_font_override("font", T.font(900))
	details.add_child(title)
	var options: Array = item.get("options", [])
	for option in options:
		var effect := _label(effect_text(option) if option is Dictionary else str(option), 13)
		effect.name = "ModuleEffect"
		details.add_child(effect)
	if options.is_empty(): details.add_child(_label("효과 정보 없음", 13))
	_line(rows)

static func build(lobby, body: VBoxContainer, items: Array) -> void:
	# Reuse the existing shell even when a completed request refreshes its view.
	if body.get_parent() is ScrollContainer:
		var outer: ScrollContainer = body.get_parent()
		outer.remove_child(body)
		var column: VBoxContainer = lobby.modal_frame.get_child(0)
		column.remove_child(outer)
		outer.queue_free()
		column.add_child(body)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	lobby.modal.set_meta("max_width", 480)
	var summary := _label("모듈 %d개를 획득했습니다." % items.size(), 16)
	summary.name = "ModuleDrawSummary"
	body.add_child(summary)
	var strip := HBoxContainer.new()
	strip.name = "ModuleDrawIconStrip"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 6)
	body.add_child(strip)
	var width := _inner_width(lobby)
	var icon_extent := clampi(floori((width - 24) / 5.0), 30, 64)
	for i in items.size():
		var item: Dictionary = items[i] if items[i] is Dictionary else {"part": str(items[i])}
		var tile := VBoxContainer.new()
		tile.name = "ModuleDrawTile%d" % (i + 1)
		tile.add_theme_constant_override("separation", 3)
		strip.add_child(tile)
		tile.add_child(ModuleIcon.create(item, icon_extent))
		tile.add_child(_number(i + 1, CollectionUI.COLORS.get(str(item.get("grade", "")), TEXT), 24))
	var strip_ref: WeakRef = weakref(strip)
	var resize_strip := func():
		var current_strip: HBoxContainer = strip_ref.get_ref()
		if current_strip == null: return
		var inner_width := _inner_width(lobby)
		var extent := clampi(floori((inner_width - 24) / 5.0), 30, 64)
		for tile in current_strip.get_children(): tile.get_child(0).set_extent(extent)
	lobby.resized.connect(resize_strip)
	strip.tree_exiting.connect(func():
		if lobby.resized.is_connected(resize_strip): lobby.resized.disconnect(resize_strip)
	, CONNECT_ONE_SHOT)
	_line(body)
	var list := ScrollContainer.new()
	list.name = "ModuleDrawResultList"
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 24
	body.add_child(list)
	lobby.modal_scroll = list
	var rows := VBoxContainer.new()
	rows.name = "ModuleDrawResultRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 7)
	list.add_child(rows)
	for i in items.size():
		var item: Dictionary = items[i] if items[i] is Dictionary else {"part": str(items[i])}
		_row(rows, item, i + 1, 42 if width >= 320 else 32)
	if items.is_empty(): rows.add_child(_label("획득 결과 정보가 없습니다.", 13))
	lobby.modal.set_meta("content_height_source", rows)
	rows.minimum_size_changed.connect(func(): lobby._layout_modal.call_deferred())
	var close := T.button("닫기", lobby.close_modal, "secondary")
	close.name = "ModuleDrawClose"
	close.custom_minimum_size.y = 40
	close.add_theme_font_size_override("font_size", 15)
	body.add_child(close)
	lobby._layout_modal.call_deferred()
