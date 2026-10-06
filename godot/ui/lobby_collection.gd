extends RefCounted
## Original module equipment/inventory and period-based quest modal.
const A = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const Connector = preload("res://ui/module_connector.gd")
const B = preload("res://ui/battle_theme.gd")
const Q = preload("res://app/quest_progress.gd")
const PARTS := {"core":"코어", "barrel":"포신", "frame":"프레임"}
const GRADES := {"normal":"일반", "magic":"마법", "rare":"희귀", "unique":"유니크"}
const PartGlyph = preload("res://ui/module_part_glyph.gd")
const ModuleIcon = preload("res://ui/module_icon.gd")
const ButtonSkin = preload("res://ui/button_skin.gd")
const COLORS = PartGlyph.COLORS
const QUEST_NAMES := {"clearWaves":"웨이브 %d회 클리어", "killBosses":"보스 %d회 처치", "killEnemies":"몹 %d회 처치", "buyRunUpgrades":"런 강화 %d회"}
const QUEST_ICONS := {"clearWaves":"clear_waves", "killBosses":"kill_bosses", "killEnemies":"kill_enemies", "buyRunUpgrades":"buy_run_upgrades"}
const OPTIONS := {"damageIncrease": "피해", "attackRateIncrease": "공격속도", "criticalChanceBonus": "치명타 확률", "criticalDamageBonus": "치명타 피해", "rangeIncrease": "사거리", "levelUpCostDiscount": "레벨업 비용", "linkUpgradeCostDiscount": "링크 확장 비용", "buildCostDiscount": "설치 비용", "highLevelUpgradeCostDiscount": "고레벨 강화 비용", "gemEffectIncrease": "장착 젬 효과", "splashRadiusIncrease": "폭발 반경", "damageOverTimeIncrease": "지속피해", "burnDurationIncrease": "화상 지속시간", "slowDurationIncrease": "둔화 지속시간", "slowStrengthBonus": "둔화 강도", "lightningChainDamageIncrease": "연쇄 피해", "projectileSpeedIncrease": "투사체 속도", "splashSecondaryDamageBonus": "광역 보조 피해", "lightningChainRangeIncrease": "연쇄 거리", "aimSpeedIncrease": "조준속도"}
const MODULE_NAMES := {"arrow_core": "과열 연산 코어", "arrow_barrel": "경량 총열", "arrow_frame": "안정 프레임", "cannon_core": "폭심 제어 코어", "cannon_barrel": "중장 포신", "cannon_frame": "보강 포가", "magic_core": "점화 증폭 코어", "magic_barrel": "잔열 포신", "magic_frame": "방열 프레임", "frost_core": "냉기 순환 코어", "frost_barrel": "냉각 포신", "frost_frame": "냉매 프레임", "sniper_core": "정밀 조준 코어", "sniper_barrel": "정밀 포신", "sniper_frame": "고정 프레임", "lightning_core": "전류 증폭 코어", "lightning_barrel": "코일 포신", "lightning_frame": "절연 프레임"}

var lobby
var turret := "arrow"
var part_filter := ""
var selected_id := ""
var period := "daily"
var quest_notice := ""
var _claim_pending := false
var _claim_service: WeakRef
var _claim_binding: Variant
var _claim_token := 0
var module_notice := ""
var inventory_scroll: ScrollContainer
var inventory_positions := {}

func setup(owner) -> void:
	lobby = owner

func _clear(parent: Node) -> void:
	if parent.has_meta("quest_view"): parent.remove_meta("quest_view")
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _label(value: String, font_size: int = 12) -> Label:
	return A.label(value, font_size)

func _button(value: String, action: Callable, selected: bool = false) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 32
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	if selected:
		b.add_theme_stylebox_override("normal", B.box(Color("234759"), Color("8ee6ff"), 5))
	return b

func _frame(parent: Node, path: String, inset: int = 9) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := Frame.new(path,inset)
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	return column

func _image(path: String, extent: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = A.texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = extent
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _asset_button(value: String, action: Callable, path: String, selected: bool = false) -> Button:
	var b := _button(value, action, selected)
	_style_asset_button(b,path,selected)
	return b

func _style_asset_button(b: Button, path: String, selected: bool = false) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := Frame.new(path,7)
		if selected and state == "normal": box.modulate_color = Color("8ee6ff")
		if state == "disabled": box.modulate_color = Color("748089")
		if state == "pressed": box.modulate_color = Color("9fe7ff")
		b.add_theme_stylebox_override(state, box)

func _module_action(value: String, action: Callable, role: String, extent: Vector2) -> Button:
	var b := _button(value, action)
	b.custom_minimum_size = extent
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_override("font", A.font(900))
	b.add_theme_font_size_override("font_size", 10)
	for state in ButtonSkin.STATES:
		var style := ButtonSkin.appearance(role, state, false, Vector2(7, 4))
		# Keep the shipped bevel and filled metallic face; copper is local to module actions.
		if role == "danger" and state != "disabled" and style is StyleBoxTexture:
			style.modulate_color *= Color(1.2, 1.12, 0.84)
		b.add_theme_stylebox_override(state, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color("fff0db") if role == "danger" else ButtonSkin.font_color(role))
	b.add_theme_color_override("font_disabled_color", Color("7b909e"))
	return b

func _items() -> Array:
	return lobby._p().get("turretModules", {}).get("items", [])

func filtered_items() -> Array:
	return _items().filter(func(item): return item.get("turretType") == turret and (part_filter.is_empty() or item.get("part") == part_filter))

func select_turret(value: String) -> void:
	_remember_inventory()
	turret = value
	part_filter = ""
	selected_id = ""
	module_notice = ""
	modules()

func select_part(value: String) -> void:
	_remember_inventory()
	part_filter = value
	selected_id = ""
	modules()

func select_item(item: Dictionary, from_slot: bool = false) -> void:
	_remember_inventory()
	selected_id = str(item.id)
	if from_slot: part_filter = str(item.part)
	modules()

func _module_name(item: Dictionary) -> String:
	return str(MODULE_NAMES.get(str(item.get("turretType", "")) + "_" + str(item.get("part", "")), "모듈"))

func _module_service(action: String, context: Dictionary = {}) -> void:
	if lobby.has_method("_service"):
		lobby._service(action,context)
		return
	module_notice = action + "는 계정 서버 연결 후 이용할 수 있습니다."
	modules()

func _build_info() -> void:
	var modal: VBoxContainer = lobby.open_modal("모듈 구축 레벨")
	modal.add_child(_label("모듈 획득 누적으로 상위 등급 확률이 증가합니다."))
	var thresholds := [0, 100, 250, 500, 800]
	var rates := [[64, 26, 7, 3], [60, 28, 9, 3], [56, 30, 10, 4], [51, 33, 12, 4], [45, 35, 15, 5]]
	for i in range(5):
		var row := _frame(modal, "ui/components/row_frame.png")
		row.add_child(_label("Lv.%d · 누적 %d회" % [i + 1, thresholds[i]], 14))
		row.add_child(_label("일반 %d%% · 마법 %d%% · 희귀 %d%% · 유니크 %d%%" % rates[i]))

func _put(control: Control, parent: Control, rect: Rect2) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size

func _equipment(parent: Node) -> Control:
	var column := _frame(parent, "ui/components/panel_frame.png", 0)
	column.get_parent().name = "ModuleEquipmentPanel"
	var center := Control.new()
	center.custom_minimum_size.y = 246
	column.add_child(center)
	var area := Control.new()
	area.name = "ModuleEquipment"
	center.add_child(area)
	var heading := _label(lobby._title(turret), 14)
	_put(heading, area, Rect2(10, 9, 120, 22))
	var preview := Control.new()
	area.add_child(preview)
	var rim := _image("turret_modules/ui/turret_preview_frame.png", Vector2.ZERO)
	preview.add_child(rim)
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Preserve the fixed 3D camera/padding and reserve the existing caption band.
	var preview_content := MarginContainer.new()
	preview_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_content.add_theme_constant_override("margin_bottom",24)
	preview.add_child(preview_content)
	preview_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var symbol := _image("ui/hud/turrets_3d/%s.png" % turret, Vector2.ZERO)
	symbol.name = "ModuleTurretPreview"
	preview_content.add_child(symbol)
	preview.move_child(preview_content,0)
	var caption := _label(lobby._title(turret), 10)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -28
	caption.offset_bottom = -12
	caption.add_theme_color_override("font_color", Color("ecd17b"))
	var connector := Connector.new()
	connector.name = "ModuleConnector"
	area.add_child(connector)
	var slots: Array[Control] = []
	for part in PARTS:
		var equipped: Dictionary = {}
		for item in _items():
			if item.get("equipped", false) and item.get("turretType") == turret and item.get("part") == part: equipped = item
		var slot := _asset_button("", select_item.bind(equipped, true) if not equipped.is_empty() else select_part.bind(part), "ui/components/card_frame.png")
		slot.name = "ModuleSlot_" + part
		area.add_child(slot)
		var inset := MarginContainer.new()
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + side, 4)
		slot.add_child(inset)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var content := HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 4)
		inset.add_child(content)
		if not equipped.is_empty():
			var icon := ModuleIcon.create(equipped, 32)
			icon.name = "EquippedModuleIcon"
			icon.set_meta("module_id", str(equipped.id))
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			content.add_child(icon)
		var lines := VBoxContainer.new()
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lines.add_theme_constant_override("separation", 0)
		content.add_child(lines)
		var part_title := _label(PARTS[part] if equipped.is_empty() else "%s · %s" % [PARTS[part], GRADES.get(equipped.get("grade", "normal"), "일반")], 9)
		part_title.add_theme_color_override("font_color", Color("8ee6ff"))
		lines.add_child(part_title)
		lines.add_child(_label("장착 없음" if equipped.is_empty() else _module_name(equipped), 10))
		if equipped.is_empty():
			var note := _label("비어 있음", 9)
			note.add_theme_color_override("font_color", Color("8da9b9"))
			lines.add_child(note)
		else: part_title.add_theme_color_override("font_color", COLORS.get(equipped.get("grade", "normal"), Color.WHITE))
		slots.append(slot)
	var layout := func():
		# A minimum width would prevent this page from shrinking after a resize.
		area.size = Vector2(minf(center.size.x, 380), center.size.y)
		area.position.x = (center.size.x - area.size.x) / 2
		var compact := area.size.x < 360
		var socket_width := 116.0 if compact else 128.0
		var socket_right := 8.0 if compact else 10.0
		var diameter := 104.0 if compact else 118.0
		var left := 0.0 if compact else 20.0
		preview.position = Vector2(left, area.size.y / 2 - diameter / 2)
		preview.size = Vector2(diameter, diameter)
		var socket_left: float = area.size.x - socket_right - socket_width
		var slot_height := 54.0 if area.size.y < 220 else 66.0
		var slot_margin := 4.0 if area.size.y < 220 else 16.0
		var step := (area.size.y - slot_height - slot_margin * 2) / 2
		var centers := PackedFloat32Array()
		for i in range(slots.size()):
			slots[i].position = Vector2(socket_left, slot_margin + step * i)
			slots[i].size = Vector2(socket_width, slot_height)
			centers.append(slot_margin + step * i + slot_height / 2)
		connector.arrange(left + diameter, socket_left, centers)
	center.resized.connect(layout)
	layout.call()
	return center

func _inventory_key() -> String:
	return turret + ":" + part_filter

func _remember_inventory() -> void:
	if is_instance_valid(inventory_scroll): inventory_positions[str(inventory_scroll.get_meta("inventory_key", _inventory_key()))] = inventory_scroll.scroll_vertical

func modules() -> void:
	_remember_inventory()
	inventory_scroll = null
	_clear(lobby.body)
	# The viewport bounds never depend on the selected item's text or list size.
	var viewport := Control.new()
	viewport.name = "ModulePage"
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby.body.add_child(viewport)
	var parent := _frame(viewport, "ui/components/panel_frame.png", 8)
	var shell: Control = parent.get_parent()
	shell.name = "ModulePageFrame"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_theme_constant_override("separation", 4)
	var draw := _frame(parent, "ui/components/panel_frame.png", 10)
	var draw_count := int(lobby._p().get("turretModules", {}).get("drawCount", 0))
	var tickets := int(lobby._p().get("turretModules", {}).get("tickets", 0))
	var build_level := 1
	for threshold in [100, 250, 500, 800]:
		if draw_count >= threshold: build_level += 1
	var actions := HBoxContainer.new()
	draw.add_child(actions)
	var build := _asset_button("모듈 구축 Lv.%d  ›" % build_level, _build_info, "ui/components/button_frame.png")
	build.size_flags_stretch_ratio = 2.6
	build.add_theme_font_size_override("font_size", 10)
	actions.add_child(build)
	for count in [1, 5]:
		var missing := maxi(0, count - tickets)
		var b := _asset_button("%d회\n%s %d" % [count, "다이아" if missing > 0 else "모듈권", missing * 40 if missing > 0 else count], _module_service.bind("모듈 뽑기",{"count":count,"turretType":turret}), "ui/components/button_frame.png")
		b.add_theme_font_size_override("font_size", 10)
		actions.add_child(b)
	if not module_notice.is_empty(): draw.add_child(_label(module_notice))
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 6)
	parent.add_child(selector)
	var types := ["arrow", "cannon", "magic", "frost"]
	var cleared: Array = lobby._p().get("clearedStageNumbers", [])
	if 3 in cleared: types.append("sniper")
	if 6 in cleared: types.append("lightning")
	if not turret in types: turret = "arrow"
	for type in types:
		var token := _asset_button("", select_turret.bind(type), "ui/components/card_frame.png")
		token.name = "TurretSelect_"+type
		token.custom_minimum_size = Vector2(0, 54)
		if type == turret:
			var style := Frame.new("ui/components/card_frame.png",7)
			style.modulate_color = Color("ecd17b")
			token.add_theme_stylebox_override("normal", style)
		selector.add_child(token)
		var icon_margin := MarginContainer.new()
		icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_margin.add_theme_constant_override("margin_top",5)
		icon_margin.add_theme_constant_override("margin_bottom",22)
		token.add_child(icon_margin)
		icon_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_margin.add_child(icon_center)
		var socket := _image("ui/components/icon_socket.png", Vector2(27,27))
		icon_center.add_child(socket)
		var icon := _image("ui/hud/turrets_3d/%s.png" % type, Vector2(27,27))
		icon.name = "TurretIcon_"+type
		icon_center.add_child(icon)
		var label := _label(lobby._title(type), 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		token.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -19
		label.offset_bottom = -3
		label.add_theme_color_override("font_color", Color("ecd17b") if turret == type else Color("8da9b9"))
	var equipment := _equipment(parent)
	var detail_box := Control.new()
	detail_box.name = "ModuleDetail"
	# Header (42), three effects (18 each), gaps (6), and panel padding (12).
	# Reserve the same compact height for every selection without the old action row.
	detail_box.custom_minimum_size.y = 114
	parent.add_child(detail_box)
	var detail := _frame(detail_box, "ui/components/row_frame_locked.png", 6)
	detail.add_theme_constant_override("separation", 2)
	(detail.get_parent() as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var selected: Dictionary = {}
	for item in filtered_items():
		if str(item.id) == selected_id: selected = item
	var detail_header := HBoxContainer.new()
	detail_header.name = "ModuleDetailHeader"
	detail_header.custom_minimum_size.y = 42
	detail_header.add_theme_constant_override("separation", 6)
	detail.add_child(detail_header)
	var title := _label("선택한 모듈 없음" if selected.is_empty() else "%s · %s" % [GRADES.get(selected.get("grade", "normal"), "일반"), _module_name(selected)], 14)
	title.name = "ModuleDetailTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title.custom_minimum_size.y = 22
	if not selected.is_empty(): title.add_theme_color_override("font_color", COLORS.get(selected.get("grade", "normal"), Color.WHITE))
	detail_header.add_child(title)
	var controls := HBoxContainer.new()
	controls.name = "ModuleDetailActions"
	controls.custom_minimum_size = Vector2(152, 36)
	controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	controls.add_theme_constant_override("separation", 4)
	detail_header.add_child(controls)
	if selected.is_empty():
		controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		var equipped: bool = selected.get("equipped", false)
		var equip := _module_action("장착 해제" if equipped else "장착", lobby._change.bind({"kind":"unequipTurretModule" if equipped else "equipTurretModule", "id":selected.id}), "primary", Vector2(68, 36))
		equip.name = "ModuleEquipAction"
		controls.add_child(equip)
		var disassemble := _module_action("분해 ·\n다이아 %d" % {"normal":2,"magic":5,"rare":20,"unique":50}.get(selected.get("grade", "normal"), 2), _module_service.bind("모듈 분해",{"id":selected.id}), "danger", Vector2(80, 36))
		disassemble.name = "ModuleDisassembleAction"
		disassemble.disabled = equipped
		controls.add_child(disassemble)
	var fit_title := func():
		var compact := detail_header.size.x < 320
		title.add_theme_font_size_override("font_size", 12 if compact else 14)
		if not selected.is_empty():
			title.text = "%s ·%s%s" % [GRADES.get(selected.get("grade", "normal"), "일반"), "\n" if compact else " ", _module_name(selected)]
	detail_header.resized.connect(fit_title)
	fit_title.call()
	var option_count := 3
	for item in _items():
		if item.get("turretType") == turret: option_count = maxi(option_count, item.get("options", []).size())
	for i in range(option_count):
		var text := ""
		if selected.is_empty():
			if i == 0: text = "%s · %s · 보유 모듈 %d개" % [lobby._title(turret), PARTS.get(part_filter, "전체"), filtered_items().size()]
			if i == 1: text = "장착 효과: 비어 있음"
		elif i < selected.get("options", []).size():
			var option: Dictionary = selected.options[i]
			var type := str(option.get("type", ""))
			text = "%s %s%d%%%s" % [OPTIONS.get(type, "추가 효과"), "−" if type.ends_with("Discount") else "+", int(option.get("value", 0)), "p" if type.ends_with("Bonus") else ""]
		var effect := _label(text, 11)
		effect.name = "ModuleDetailEffect_%d" % i
		effect.custom_minimum_size.y = 18
		detail.add_child(effect)
	detail_box.custom_minimum_size.y += (option_count - 3) * 20
	parent.add_child(_label(lobby._title(turret) + " 모듈 인벤토리", 14))
	var filters := HBoxContainer.new()
	parent.add_child(filters)
	filters.add_child(_asset_button("전체", select_part.bind(""), "ui/components/button_frame.png", part_filter.is_empty()))
	for part in PARTS: filters.add_child(_asset_button(PARTS[part], select_part.bind(part), "ui/components/button_frame.png", part_filter == part))
	var inventory := _frame(parent, "ui/components/panel_frame.png", 6)
	var inventory_panel: Control = inventory.get_parent()
	inventory_panel.name = "ModuleInventoryPanel"
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var items := filtered_items()
	if not items.is_empty():
		var info := HBoxContainer.new()
		info.name = "ModuleInventoryInfo"
		inventory.add_child(info)
		var count_label := _label("보유 %d개" % items.size())
		count_label.name = "ModuleInventoryCount"
		count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_child(count_label)
		var bulk := _module_action("일괄 분해", _module_service.bind("모듈 일괄 분해",{"turretType":turret,"part":part_filter,"ids":items.map(func(item):return item.id)}), "danger", Vector2(96, 32))
		bulk.name = "ModuleBulkDisassembleAction"
		info.add_child(bulk)
	var grid := GridContainer.new()
	grid.name = "ModuleInventoryGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.name = "ModuleInventoryScroll"
	inventory_scroll.scroll_deadzone = 10
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Give the reclaimed lower action band to the inventory, not the turret preview.
	inventory_scroll.custom_minimum_size.y = 72
	inventory.add_child(inventory_scroll)
	inventory_scroll.add_child(grid)
	var scroll_ref: WeakRef = weakref(inventory_scroll)
	var key: String = _inventory_key()
	inventory_scroll.set_meta("inventory_key", key)
	var restore := func():
		var scroll: ScrollContainer = scroll_ref.get_ref()
		if scroll != null: scroll.scroll_vertical = int(inventory_positions.get(key, 0))
	restore.call_deferred()
	lobby.get_tree().process_frame.connect(restore, CONNECT_ONE_SHOT)
	var rebuild := func(): _layout_inventory(grid,items)
	grid.resized.connect(rebuild)
	rebuild.call_deferred()
	var fit := func():
		if not is_instance_valid(viewport): return
		var other_height := 16.0 + parent.get_theme_constant("separation") * (parent.get_child_count() - 1)
		for child: Control in parent.get_children():
			if child != equipment.get_parent().get_parent(): other_height += child.get_combined_minimum_size().y
		equipment.custom_minimum_size.y = clampf(viewport.size.y - other_height, 174, 246)
	viewport.resized.connect(fit)
	fit.call_deferred()

func _layout_inventory(grid: GridContainer, items: Array) -> void:
	if not is_instance_valid(grid): return
	var columns := 5 if grid.size.x < 324 else 6
	var count := maxi(1, ceili(float(items.size())/columns))*columns
	if grid.columns != columns or grid.get_child_count() != count:
		_clear(grid)
		grid.columns = columns
		for i in range(count):
			if i >= items.size():
				var blank := PanelContainer.new()
				blank.add_theme_stylebox_override("panel",Frame.new("ui/components/card_frame.png",0))
				blank.modulate.a = 0.45
				grid.add_child(blank)
				continue
			var item: Dictionary = items[i]
			var b := _asset_button("",select_item.bind(item),"ui/components/card_frame.png")
			b.name = "Module_"+str(item.id)
			b.mouse_filter = Control.MOUSE_FILTER_PASS
			b.tooltip_text = "%s · %s · %s" % [GRADES.get(item.get("grade","normal"),"일반"),_module_name(item),PARTS.get(item.get("part","core"),"코어")]
			grid.add_child(b)
			var color: Color = COLORS.get(item.get("grade","normal"),Color.WHITE)
			if selected_id==str(item.id) or item.get("equipped",false):
				var selected := Panel.new()
				selected.mouse_filter=Control.MOUSE_FILTER_IGNORE
				selected.add_theme_stylebox_override("panel",B.box(Color("33d8ff16"),Color("33d8ff") if selected_id==str(item.id) else color,7))
				b.add_child(selected); selected.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var glyph_center := CenterContainer.new()
			glyph_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(glyph_center)
			glyph_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var glyph := PartGlyph.new()
			glyph.name = "ModulePartGlyph"
			glyph.part = str(item.part)
			glyph.tint = color
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glyph.custom_minimum_size = Vector2(28,28)
			glyph_center.add_child(glyph)
			var tag := _label({"core":"코","barrel":"포","frame":"프"}.get(item.part,""),8)
			tag.add_theme_color_override("font_color",color); tag.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.add_child(tag); tag.position=Vector2(3,3)
			if item.get("equipped",false):
				var mark:=_label("E",8); mark.mouse_filter=Control.MOUSE_FILTER_IGNORE; mark.add_theme_color_override("font_color",Color("33d8ff"))
				b.add_child(mark); mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); mark.offset_left=-14; mark.offset_top=3
			var dots:=_label("● ".repeat(item.get("options",[]).size()).strip_edges(),6)
			dots.mouse_filter=Control.MOUSE_FILTER_IGNORE; dots.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			dots.add_theme_color_override("font_color",color)
			b.add_child(dots); dots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); dots.offset_top=-13; dots.offset_bottom=-4
	var extent := maxf(1,(grid.size.x-6*(columns-1))/columns)
	for cell: Control in grid.get_children():
		cell.custom_minimum_size=Vector2(0,extent)
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func set_period(value: String, parent: VBoxContainer) -> void:
	period = value
	quest_notice = ""
	quests(parent)

func _claim(parent: VBoxContainer, target: Dictionary = {}) -> void:
	if _claim_pending and _pending_claim_current(): return
	if lobby.get("app") == null:
		quest_notice = "보상 수령은 계정 서버 연결 후 이용할 수 있습니다."
		quests(parent)
		return
	if lobby.app.get("services") == null or not lobby.app.services.connected():
		lobby._service("계정 및 저장")
		return
	var service = lobby.app.services
	_claim_pending = true
	_claim_service = weakref(service)
	_claim_binding = service.get("epoch")
	_claim_token += 1
	var token := _claim_token
	var binding: Variant = _claim_binding
	quest_notice = "보상을 확인하고 있습니다…"
	quests(parent)
	var request := target.duplicate(true)
	request.period = period
	var requested_period := period
	var view: WeakRef = weakref(parent)
	var result: Dictionary = await service.perform("claim_reward",request)
	if token != _claim_token: return
	_claim_pending = false
	# A dismissed dialog or a new account must never receive the old UI result.
	var current: VBoxContainer = view.get_ref()
	if lobby.app.services != service or service.get("epoch") != binding: return
	var modal = lobby.get("modal")
	if not is_instance_valid(modal) or not modal.get_meta("quest_dialog",false): return
	var visible_parent: VBoxContainer = lobby.get("modal_body")
	if not is_instance_valid(current) or not current.is_inside_tree() or visible_parent != current:
		quest_notice = ""
		quests(visible_parent)
		return
	if period != requested_period:
		quest_notice = ""
		quests(current)
		return
	quest_notice = "보상을 수령했습니다" if result.get("ok",false) else "수령하지 못했습니다. 계정 및 저장에서 동기화 상태를 확인해 주세요."
	quests(current)

func _pending_claim_current() -> bool:
	if lobby.get("app") == null or lobby.app.get("services") == null or _claim_service == null: return false
	return _claim_service.get_ref() == lobby.app.services and _claim_binding == lobby.app.services.get("epoch")

func quests(parent: VBoxContainer) -> void:
	var existing: Dictionary = parent.get_meta("quest_view",{})
	if existing.get("period") == period and is_instance_valid(existing.get("notice")):
		_refresh_quests(existing)
		return
	_clear(parent)
	var tabs := HBoxContainer.new()
	parent.add_child(tabs)
	for value in ["daily", "weekly"]:
		tabs.add_child(_asset_button("일일" if value == "daily" else "주간", set_period.bind(value, parent), "quests/ui/tab_selected.png" if period == value else "quests/ui/tab_idle.png"))
	var notice := _label(quest_notice)
	notice.visible = not quest_notice.is_empty()
	parent.add_child(notice)
	var p: Dictionary = lobby._p()
	var weekly := period == "weekly"
	var targets: Dictionary = Q.WEEKLY if weekly else Q.DAILY
	var progress: Dictionary = p.get(period + "QuestProgress", {})
	var claimed: Array = p.get("claimedWeeklyQuestRewards" if weekly else "claimedDailyQuestRewards", [])
	var complete := Q.completed_count(p, period)
	var blocked: bool = p.get("dailyQuestClockRollbackDetected", false)
	var clock_notice := _label("기기 시간이 변경되어 보상 수령이 잠겼습니다.")
	clock_notice.visible = blocked
	parent.add_child(clock_notice)
	var rows := {}
	rows.all_complete = _quest_row(parent, "오늘 진행" if not weekly else "이번 주 진행", mini(complete, Q.ALL_COMPLETE_REQUIRED), Q.ALL_COMPLETE_REQUIRED, 100 if weekly else 40, bool(p.get(period + "QuestAllCompleteClaimed", false)), complete >= Q.ALL_COMPLETE_REQUIRED and not blocked, "quests/clear_waves.png", 4 if weekly else 1, true, {"rewardType":"all_complete"})
	var days := Q.attendance_progress(p, period)
	rows.attendance = _quest_row(parent, "주간 출석" if weekly else "오늘 출석", mini(days, 5 if weekly else 1), 5 if weekly else 1, 40 if weekly else 20, bool(p.get(period + "AttendanceRewardClaimed", false)), days >= (5 if weekly else 1) and not blocked, "quests/attendance.png",0,false,{"rewardType":"attendance"})
	for id in targets:
		var amount := int(progress.get(id, 0))
		rows[id] = _quest_row(parent, QUEST_NAMES[id] % targets[id], mini(amount, int(targets[id])), targets[id], 40 if weekly else 20, id in claimed, amount >= int(targets[id]) and not blocked, "quests/%s.png" % QUEST_ICONS[id],0,false,{"rewardType":"quest","questType":id})
	var view := {"period":period,"notice":notice,"clock_notice":clock_notice,"rows":rows}
	parent.set_meta("quest_view",view)
	_refresh_quests(view)

func _refresh_quests(view: Dictionary) -> void:
	var p: Dictionary = lobby._p()
	var weekly := period == "weekly"
	var targets: Dictionary = Q.WEEKLY if weekly else Q.DAILY
	var progress: Dictionary = p.get(period + "QuestProgress",{})
	var claimed: Array = p.get("claimedWeeklyQuestRewards" if weekly else "claimedDailyQuestRewards",[])
	var blocked: bool = p.get("dailyQuestClockRollbackDetected",false)
	var busy := false
	if lobby.get("app") != null and lobby.app.get("services") != null and _claim_service != null:
		var same_account := _pending_claim_current()
		busy = _claim_pending and same_account
		if not same_account: quest_notice = ""
	view.notice.text = quest_notice
	view.notice.visible = not quest_notice.is_empty()
	view.clock_notice.visible = blocked
	var complete := Q.completed_count(p, period)
	for id in targets:
		var amount := int(progress.get(id,0))
		_update_quest_row(view.rows[id],mini(amount,int(targets[id])),int(targets[id]),id in claimed,amount >= int(targets[id]) and not blocked and not busy)
	_update_quest_row(view.rows.all_complete,mini(complete,Q.ALL_COMPLETE_REQUIRED),Q.ALL_COMPLETE_REQUIRED,bool(p.get(period+"QuestAllCompleteClaimed",false)),complete >= Q.ALL_COMPLETE_REQUIRED and not blocked and not busy)
	var days := Q.attendance_progress(p, period)
	_update_quest_row(view.rows.attendance,mini(days,5 if weekly else 1),5 if weekly else 1,bool(p.get(period+"AttendanceRewardClaimed",false)),days >= (5 if weekly else 1) and not blocked and not busy)

func _update_quest_row(view: Dictionary, count: int, target: int, claimed: bool, can_claim: bool) -> void:
	view.count.text = "%d / %d 완료" % [count,target] if view.summary else "%d / %d%s" % [count,target,"일 · 매일 05:00 갱신" if view.title == "오늘 출석" else ""]
	if view.bar != null: view.bar.value = count
	view.button.text = "수령 완료" if claimed else ("수령" if can_claim else ("대기" if view.summary else "진행중"))
	view.button.disabled = claimed or not can_claim
	var path := "quests/ui/action_claim.png" if can_claim and not claimed else "quests/ui/action_idle.png"
	if view.path != path:
		_style_asset_button(view.button,path)
		view.path = path

func _inline(value: String, font_size: int = 12) -> Label:
	var label := _label(value,font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func _reward_line(parent: Node, reward: int, tickets: int = 0) -> void:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var amount := _inline("+%d" % reward, 12)
	amount.add_theme_color_override("font_color", Color("8ee6ff"))
	line.add_child(amount)
	line.add_child(_image("res://assets/ui/diamond_currency.png", Vector2(13, 13)))
	if tickets > 0:
		line.add_child(_image("stage_rewards/reward_module_ticket.png", Vector2(15, 18)))
		var ticket := _inline("모듈권 +%d" % tickets, 11)
		ticket.add_theme_color_override("font_color", Color("f5cb61"))
		line.add_child(ticket)

func _quest_row(parent: VBoxContainer, title: String, count: int, target: int, reward: int, claimed: bool, can_claim: bool, icon: String, tickets: int = 0, summary: bool = false, claim_target: Dictionary = {}) -> Dictionary:
	var card := _frame(parent, "quests/ui/summary_frame.png" if summary else "quests/ui/quest_row_frame.png", 9)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	card.add_child(row)
	if not summary:
		var socket := Control.new()
		socket.custom_minimum_size = Vector2(30, 35)
		socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(socket)
		var frame := _image("quests/ui/icon_socket.png", Vector2.ZERO)
		_put(frame, socket, Rect2(0, 2, 30, 30))
		var symbol := _image(icon, Vector2.ZERO)
		_put(symbol, socket, Rect2(5, 7, 20, 20))
	var description := VBoxContainer.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_constant_override("separation", 3)
	row.add_child(description)
	var title_line := HBoxContainer.new()
	description.add_child(title_line)
	var name := _label(title, 12)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_line.add_child(name)
	var count_label: Label
	var bar: ProgressBar
	if summary:
		var refresh := _inline("매일 05:00 갱신" if period == "daily" else "월요일 05:00 갱신", 9)
		refresh.add_theme_color_override("font_color", Color("8da9b9"))
		title_line.add_child(refresh)
		var rewards := HBoxContainer.new()
		description.add_child(rewards)
		count_label = _inline("%d / %d 완료" % [count, target],10)
		rewards.add_child(count_label)
		_reward_line(rewards, reward, tickets)
	else:
		_reward_line(title_line, reward)
		bar = ProgressBar.new()
		bar.custom_minimum_size.y = 4
		bar.max_value = target
		bar.value = count
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", B.box(Color("152633"), Color("152633"), 0))
		bar.add_theme_stylebox_override("fill", B.box(Color("8ee6ff"), Color("8ee6ff"), 0))
		description.add_child(bar)
		var progress := _label("%d / %d%s" % [count, target, "일 · 매일 05:00 갱신" if title == "오늘 출석" else ""], 10)
		count_label = progress
		progress.add_theme_color_override("font_color", Color("8da9b9"))
		description.add_child(progress)
	var button := _asset_button("수령 완료" if claimed else ("수령" if can_claim else ("대기" if summary else "진행중")), _claim.bind(parent,claim_target), "quests/ui/action_claim.png" if can_claim and not claimed else "quests/ui/action_idle.png")
	button.disabled = claimed or not can_claim
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(60, 30)
	button.add_theme_font_size_override("font_size", 11)
	row.add_child(button)
	return {"count":count_label,"bar":bar,"button":button,"summary":summary,"title":title,"path":"quests/ui/action_claim.png" if can_claim and not claimed else "quests/ui/action_idle.png"}
