extends RefCounted
## Original module equipment/inventory and period-based quest modal.
const A = preload("res://ui/app_theme.gd")
const Frame = preload("res://ui/lobby_frame.gd")
const Connector = preload("res://ui/module_connector.gd")
const B = preload("res://ui/battle_theme.gd")
const Q = preload("res://app/quest_progress.gd")
const PARTS := {"core":"코어", "barrel":"포신", "frame":"프레임"}
const GRADES := {"normal":"일반", "magic":"마법", "rare":"희귀", "unique":"유니크"}
const COLORS := {"normal":Color("bac6cd"), "magic":Color("77bbff"), "rare":Color("e7cb6c"), "unique":Color("c98fff")}
const QUEST_NAMES := {"clearWaves":"웨이브 %d회 클리어", "killBosses":"보스 %d회 처치", "killEnemies":"몹 %d회 처치", "buyRunUpgrades":"런 강화 %d회"}
const QUEST_ICONS := {"clearWaves":"clear_waves", "killBosses":"kill_bosses", "killEnemies":"kill_enemies", "buyRunUpgrades":"buy_run_upgrades"}
const OPTIONS := {"damageIncrease": "피해", "attackRateIncrease": "공격속도", "criticalChanceBonus": "치명타 확률", "criticalDamageBonus": "치명타 피해", "rangeIncrease": "사거리", "levelUpCostDiscount": "레벨업 비용", "linkUpgradeCostDiscount": "링크 확장 비용", "buildCostDiscount": "설치 비용", "highLevelUpgradeCostDiscount": "고레벨 강화 비용", "gemEffectIncrease": "장착 젬 효과", "splashRadiusIncrease": "폭발 반경", "damageOverTimeIncrease": "지속피해", "burnDurationIncrease": "화상 지속시간", "slowDurationIncrease": "둔화 지속시간", "slowStrengthBonus": "둔화 강도", "lightningChainDamageIncrease": "연쇄 피해", "projectileSpeedIncrease": "투사체 속도", "splashSecondaryDamageBonus": "광역 보조 피해", "lightningChainRangeIncrease": "연쇄 거리", "aimSpeedIncrease": "조준속도"}
const MODULE_NAMES := {"arrow_core": "과열 연산 코어", "arrow_barrel": "경량 총열", "arrow_frame": "안정 프레임", "cannon_core": "폭심 제어 코어", "cannon_barrel": "중장 포신", "cannon_frame": "보강 포가", "magic_core": "점화 증폭 코어", "magic_barrel": "잔열 포신", "magic_frame": "방열 프레임", "frost_core": "냉기 순환 코어", "frost_barrel": "냉각 포신", "frost_frame": "냉매 프레임", "sniper_core": "정밀 조준 코어", "sniper_barrel": "정밀 포신", "sniper_frame": "고정 프레임", "lightning_core": "전류 증폭 코어", "lightning_barrel": "코일 포신", "lightning_frame": "절연 프레임"}
class PartGlyph extends Control:
	var part := "core"
	var tint := Color("8ee6ff")
	func _draw() -> void:
		var c := size * 0.5
		var w := size.x
		draw_circle(c, w * 0.48, Color(tint, 0.14))
		match part:
			"core":
				draw_rect(Rect2(size * 0.18, size * 0.64), tint, false, 1.5)
				draw_rect(Rect2(size * 0.36, size * 0.28), tint)
				for x in [0.31, 0.50, 0.69]:
					draw_line(Vector2(w * x, w * 0.04), Vector2(w * x, w * 0.18), tint, 1.5)
					draw_line(Vector2(w * x, w * 0.82), Vector2(w * x, w * 0.96), tint, 1.5)
				for y in [0.34, 0.66]:
					draw_line(Vector2(w * 0.04, w * y), Vector2(w * 0.18, w * y), tint, 1.5)
					draw_line(Vector2(w * 0.82, w * y), Vector2(w * 0.96, w * y), tint, 1.5)
			"barrel":
				for x in [0.25, 0.55]: draw_rect(Rect2(w * x, w * 0.08, w * 0.20, w * 0.72), tint)
				draw_rect(Rect2(w * 0.18, w * 0.65, w * 0.64, w * 0.25), Color(tint, 0.58))
			"frame":
				draw_arc(c, w * 0.34, 0, TAU, 32, tint, 1.5, true)
				for angle in [PI / 4, PI * 3 / 4]:
					var delta := Vector2(cos(angle), sin(angle)) * w * 0.32
					draw_line(c - delta, c + delta, tint, 1.5)
				draw_circle(c, w * 0.08, tint)

var lobby
var turret := "arrow"
var part_filter := ""
var selected_id := ""
var period := "daily"
var quest_notice := ""
var module_notice := ""

func setup(owner) -> void:
	lobby = owner

func _clear(parent: Node) -> void:
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
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := Frame.new(path,7)
		if selected and state == "normal": box.modulate_color = Color("8ee6ff")
		if state == "disabled": box.modulate_color = Color("748089")
		if state == "pressed": box.modulate_color = Color("9fe7ff")
		b.add_theme_stylebox_override(state, box)
	return b

func _items() -> Array:
	return lobby._p().get("turretModules", {}).get("items", [])

func filtered_items() -> Array:
	return _items().filter(func(item): return item.get("turretType") == turret and (part_filter.is_empty() or item.get("part") == part_filter))

func select_turret(value: String) -> void:
	turret = value
	part_filter = ""
	selected_id = ""
	module_notice = ""
	modules()

func select_part(value: String) -> void:
	part_filter = value
	selected_id = ""
	modules()

func select_item(item: Dictionary, from_slot: bool = false) -> void:
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

func _equipment(parent: Node) -> void:
	var column := _frame(parent, "ui/components/panel_frame.png", 0)
	var center := Control.new()
	center.custom_minimum_size.y = 246
	column.add_child(center)
	var area := Control.new()
	area.name = "ModuleEquipment"
	area.custom_minimum_size.y = 246
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
		var lines := VBoxContainer.new()
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(lines)
		lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lines.offset_left = 7
		lines.offset_right = -7
		lines.offset_top = 6
		lines.add_theme_constant_override("separation", 1)
		var part_title := _label(PARTS[part], 11)
		part_title.add_theme_color_override("font_color", Color("8ee6ff"))
		lines.add_child(part_title)
		lines.add_child(_label("장착 없음" if equipped.is_empty() else _module_name(equipped), 11))
		var note := _label("비어 있음" if equipped.is_empty() else GRADES.get(equipped.get("grade", "normal"), "일반"), 10)
		note.add_theme_color_override("font_color", Color("8da9b9"))
		lines.add_child(note)
		slots.append(slot)
	var layout := func():
		# A minimum width would prevent this page from shrinking after a resize.
		area.size = Vector2(minf(center.size.x, 380), 246)
		area.position.x = (center.size.x - area.size.x) / 2
		var compact := area.size.x < 360
		var socket_width := 116.0 if compact else 128.0
		var socket_right := 8.0 if compact else 10.0
		var diameter := 104.0 if compact else 118.0
		var left := 0.0 if compact else 20.0
		preview.position = Vector2(left, 123 - diameter / 2)
		preview.size = Vector2(diameter, diameter)
		var socket_left: float = area.size.x - socket_right - socket_width
		for i in range(slots.size()):
			slots[i].position = Vector2(socket_left, 16 + 74 * i)
			slots[i].size = Vector2(socket_width, 66)
		connector.arrange(left + diameter, socket_left, PackedFloat32Array([49, 123, 197]))
	center.resized.connect(layout)
	layout.call()

func modules() -> void:
	_clear(lobby.body)
	var parent := _frame(lobby.body, "ui/components/panel_frame.png", 10)
	parent.add_theme_constant_override("separation", 8)
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
	_equipment(parent)
	var detail := _frame(parent, "ui/components/row_frame_locked.png")
	var selected: Dictionary = {}
	for item in filtered_items():
		if str(item.id) == selected_id: selected = item
	if selected.is_empty():
		detail.add_child(_label("선택한 모듈 없음", 14))
		detail.add_child(_label("%s · %s · 보유 모듈 %d개" % [lobby._title(turret), PARTS.get(part_filter, "전체"), filtered_items().size()], 10))
		var effect := _label("장착 효과: 비어 있음", 12)
		effect.add_theme_color_override("font_color", Color("f5cb61"))
		detail.add_child(effect)
	else:
		var title := _label("%s · %s" % [GRADES.get(selected.get("grade", "normal"), "일반"), _module_name(selected)], 14)
		title.add_theme_color_override("font_color", COLORS.get(selected.get("grade", "normal"), Color.WHITE))
		detail.add_child(title)
		for option in selected.get("options", []):
			var type := str(option.get("type", ""))
			detail.add_child(_label("%s %s%d%%%s" % [OPTIONS.get(type, "추가 효과"), "−" if type.ends_with("Discount") else "+", int(option.get("value", 0)), "p" if type.ends_with("Bonus") else ""]))
		var controls := HBoxContainer.new()
		detail.add_child(controls)
		var equipped: bool = selected.get("equipped", false)
		controls.add_child(_button("장착 해제" if equipped else "장착", lobby._change.bind({"kind":"unequipTurretModule" if equipped else "equipTurretModule", "id":selected.id})))
		var disassemble := _button("분해 · 다이아 %d" % {"normal":2,"magic":5,"rare":20,"unique":50}.get(selected.get("grade", "normal"), 2), _module_service.bind("모듈 분해",{"id":selected.id}))
		disassemble.disabled = equipped
		controls.add_child(disassemble)
	parent.add_child(_label(lobby._title(turret) + " 모듈 인벤토리", 14))
	var filters := HBoxContainer.new()
	parent.add_child(filters)
	filters.add_child(_asset_button("전체", select_part.bind(""), "ui/components/button_frame.png", part_filter.is_empty()))
	for part in PARTS: filters.add_child(_asset_button(PARTS[part], select_part.bind(part), "ui/components/button_frame.png", part_filter == part))
	var inventory := _frame(parent, "ui/components/panel_frame.png")
	var items := filtered_items()
	if items.is_empty():
		var empty := _label("획득한 %s %s 없음" % [lobby._title(turret), PARTS.get(part_filter, "모듈")])
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.y = 26
		inventory.add_child(empty)
	else:
		var info := HBoxContainer.new()
		inventory.add_child(info)
		var count_label := _label("보유 %d개" % items.size())
		count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		info.add_child(count_label)
		info.add_child(_button("일괄 분해", _module_service.bind("모듈 일괄 분해",{"turretType":turret,"part":part_filter,"ids":items.map(func(item):return item.id)})))
		var grid := GridContainer.new()
		grid.name = "ModuleInventoryGrid"
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation",6)
		grid.add_theme_constant_override("v_separation",6)
		inventory.add_child(grid)
		var rebuild := func(): _layout_inventory(grid,items)
		grid.resized.connect(rebuild)
		rebuild.call_deferred()

func _layout_inventory(grid: GridContainer, items: Array) -> void:
	if not is_instance_valid(grid): return
	var columns := 5 if grid.size.x < 324 else 6
	var count := ceili(float(items.size())/columns)*columns
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
	if lobby.get("app") == null:
		quest_notice = "보상 수령은 계정 서버 연결 후 이용할 수 있습니다."
		quests(parent)
		return
	if lobby.app.get("services") == null or not lobby.app.services.connected():
		lobby._service("계정 및 저장")
		return
	quest_notice = "보상을 확인하고 있습니다…"
	var request := target.duplicate(true)
	request.period = period
	var result: Dictionary = await lobby.app.services.perform("claim_reward",request)
	quest_notice = "보상을 수령했습니다" if result.get("ok",false) else "수령하지 못했습니다. 계정 및 저장에서 동기화 상태를 확인해 주세요."
	if is_instance_valid(parent): quests(parent)

func quests(parent: VBoxContainer) -> void:
	_clear(parent)
	var tabs := HBoxContainer.new()
	parent.add_child(tabs)
	for value in ["daily", "weekly"]:
		tabs.add_child(_asset_button("일일" if value == "daily" else "주간", set_period.bind(value, parent), "quests/ui/tab_selected.png" if period == value else "quests/ui/tab_idle.png"))
	if not quest_notice.is_empty(): parent.add_child(_label(quest_notice))
	var p: Dictionary = lobby._p()
	var weekly := period == "weekly"
	var targets: Dictionary = Q.WEEKLY if weekly else Q.DAILY
	var progress: Dictionary = p.get(period + "QuestProgress", {})
	var claimed: Array = p.get("claimedWeeklyQuestRewards" if weekly else "claimedDailyQuestRewards", [])
	var complete := 0
	for id in targets:
		if int(progress.get(id, 0)) >= int(targets[id]): complete += 1
	var blocked: bool = p.get("dailyQuestClockRollbackDetected", false)
	if blocked: parent.add_child(_label("기기 시간이 변경되어 보상 수령이 잠겼습니다."))
	_quest_row(parent, "오늘 진행" if not weekly else "이번 주 진행", complete, targets.size(), 100 if weekly else 40, bool(p.get(period + "QuestAllCompleteClaimed", false)), complete == targets.size() and not blocked, "quests/clear_waves.png", 4 if weekly else 1, true, {"rewardType":"all_complete"})
	var days: int = p.get("weeklyAttendanceDayKeys", []).size() if weekly else 1
	_quest_row(parent, "주간 출석" if weekly else "오늘 출석", mini(days, 5) if weekly else 1, 5 if weekly else 1, 40 if weekly else 20, bool(p.get(period + "AttendanceRewardClaimed", false)), (days >= 5 if weekly else true) and not blocked, "quests/attendance.png",0,false,{"rewardType":"attendance"})
	for id in targets:
		var amount := int(progress.get(id, 0))
		_quest_row(parent, QUEST_NAMES[id] % targets[id], mini(amount, int(targets[id])), targets[id], 40 if weekly else 20, id in claimed, amount >= int(targets[id]) and not blocked, "quests/%s.png" % QUEST_ICONS[id],0,false,{"rewardType":"quest","questType":id})

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

func _quest_row(parent: VBoxContainer, title: String, count: int, target: int, reward: int, claimed: bool, can_claim: bool, icon: String, tickets: int = 0, summary: bool = false, claim_target: Dictionary = {}) -> void:
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
	if summary:
		var refresh := _inline("매일 05:00 갱신" if period == "daily" else "월요일 05:00 갱신", 9)
		refresh.add_theme_color_override("font_color", Color("8da9b9"))
		title_line.add_child(refresh)
		var rewards := HBoxContainer.new()
		description.add_child(rewards)
		rewards.add_child(_inline("%d / %d 완료" % [count, target], 10))
		_reward_line(rewards, reward, tickets)
	else:
		_reward_line(title_line, reward)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 4
		bar.max_value = target
		bar.value = count
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", B.box(Color("152633"), Color("152633"), 0))
		bar.add_theme_stylebox_override("fill", B.box(Color("8ee6ff"), Color("8ee6ff"), 0))
		description.add_child(bar)
		var progress := _label("%d / %d%s" % [count, target, "일 · 매일 05:00 갱신" if title == "오늘 출석" else ""], 10)
		progress.add_theme_color_override("font_color", Color("8da9b9"))
		description.add_child(progress)
	var button := _asset_button("수령 완료" if claimed else ("수령" if can_claim else ("대기" if summary else "진행중")), _claim.bind(parent,claim_target), "quests/ui/action_claim.png" if can_claim and not claimed else "quests/ui/action_idle.png")
	button.disabled = claimed or not can_claim
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(60, 30)
	button.add_theme_font_size_override("font_size", 11)
	row.add_child(button)
