extends "res://ui/expanded_core_tree_drawing.gd"
## Approved v5 artwork and geometry. No inferred edges or radial relayout.
## Drawn in screen space: the background always covers the view, each rank up to 3
## grows a link toward unranked neighbours, and the point bar and sheets reuse the
## shipped frames (design/core_tree_concepts/ui-redesign-2026-10-13).
## This entry owns the overlay: point bar, menu, node sheets and skills. The
## layers below it (state -> drawing) may only call downward; GDScript rejects
## an upward call at parse time.

# ---- input ----
func select_at(owner, location: Vector2) -> void:
	close_menu()
	var world: Vector2 = (location-owner.offset)/owner.zoom
	if owner.zoom < DETAIL_ZOOM:
		animate_to(owner,destination(owner,owner.scale_at.bind(DETAIL_ZOOM/owner.zoom,location)),0.38)
		return
	if world.distance_to(owner.center()) <= 150:
		owner.skills()
		return
	var closest := ""
	var distance := INF
	for id in owner.node_ids():
		if not hit_rect(owner,id).has_point(location): continue
		var d: float = location.distance_to(owner.offset+owner.point(id)*owner.zoom)
		if d < distance:
			distance = d
			closest = id
	if not closest.is_empty():
		node_details(owner,closest)
		layout(owner)
		# Centre the selection in the area above its sheet. Selecting never purchases.
		var top := point_bar.position.y+point_bar.size.y if is_instance_valid(point_bar) else 0.0
		var spot := Vector2(owner.view.size.x/2,(top+visible_height(owner))/2)
		var target: Vector2 = owner.point(closest)
		animate_to(owner,destination(owner,func():
			owner.offset = spot-target*owner.zoom
			clamp_view(owner)))
	else:
		owner.selected = ""
		owner.selecting_skill = false
		owner._close_inline()
	layout(owner)
	owner.view.queue_redraw()

# ---- overlay controls ----
func _glyph_label(code: int, pixels: int, color: Color, owner) -> Label:
	var label := Label.new()
	label.text = String.chr(code)
	if owner.material_font: label.add_theme_font_override("font",owner.material_font)
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _plain(text: String, pixels: int, color: Color, weight := 700) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",AppTheme.font(weight))
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, variant: String, callback: Callable) -> Button:
	var b := AppTheme.button(text,callback,variant)
	b.custom_minimum_size = Vector2(44,44)
	b.add_theme_font_size_override("font_size",12)
	return b

func _frame(path: String, inset: int) -> StyleBox:
	return Frame.new(path,inset)

## The upgrade screen's level-up frame; rank down and level-up share it.
func _levelup_style(disabled := false) -> StyleBox:
	var frame := Frame.new("ui/components/upgrade_levelup_frame_v2.png",7)
	frame.source_center = Rect2(12,5,127,24)
	if disabled: frame.modulate_color = Color(0.62,0.66,0.7)
	return frame

func build_overlay(owner) -> void:
	point_bar = PanelContainer.new()
	point_bar.name = "CorePointOverlay"
	var bar_style := _frame("ui/components/panel_frame.png",8)
	bar_style.content_margin_left = 14
	bar_style.content_margin_right = 8
	point_bar.add_theme_stylebox_override("panel",bar_style)
	point_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	point_bar.offset_left = 8
	point_bar.offset_right = -8
	point_bar.offset_top = 8
	point_bar.custom_minimum_size.y = 56
	owner.view.add_child(point_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	point_bar.add_child(row)
	row.add_child(_glyph_label(HUB_GLYPH,22,Color("7fd8e6"),owner))
	var numbers := VBoxContainer.new()
	numbers.add_theme_constant_override("separation",-2)
	numbers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(numbers)
	numbers.add_child(_plain("남은 코어 포인트",10,MUTED))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation",4)
	numbers.add_child(values)
	remaining_label = _plain("",21,Color("e8f8ff"),900)
	remaining_label.name = "CoreRemainingPoints"
	values.add_child(remaining_label)
	earned_label = _plain("",12,MUTED)
	earned_label.size_flags_vertical = Control.SIZE_SHRINK_END
	values.add_child(earned_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	draft_chip = _plain("",12,PLANNED,800)
	draft_chip.name = "CoreDraftDelta"
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(PLANNED,0.08)
	chip_style.border_color = Color(PLANNED,0.6)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(12)
	chip_style.content_margin_left = 9
	chip_style.content_margin_right = 9
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	draft_chip.add_theme_stylebox_override("normal",chip_style)
	draft_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(draft_chip)
	owner.cancel_button = _button("되돌리기","secondary",owner.cancel)
	owner.cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(owner.cancel_button)
	owner.apply_button = _button("적용","primary",owner.apply)
	owner.apply_button.name = "CoreApplyDraft"
	owner.apply_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(owner.apply_button)
	menu_button = _button("","secondary",func(): menu.visible = not menu.visible; layout(owner))
	menu_button.name = "CorePointMenuButton"
	menu_button.tooltip_text = "더보기"
	menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dots := Dots.new()
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(dots)
	dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(menu_button)
	menu = PanelContainer.new()
	menu.name = "CorePointMenu"
	menu.add_theme_stylebox_override("panel",_frame("ui/components/panel_frame.png",10))
	menu.visible = false
	owner.view.add_child(menu)
	owner.reset_button = _button("전체 초기화","danger",func(): close_menu(); owner.confirm_reset())
	owner.reset_button.custom_minimum_size.x = 150
	menu.add_child(owner.reset_button)
	# One grouped camera control; hidden while a sheet is open (pinch still works).
	var group := PanelContainer.new()
	group.name = "CoreZoomControls"
	group.add_theme_stylebox_override("panel",_frame("ui/components/button_frame.png",2))
	owner.view.add_child(group)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",0)
	group.add_child(buttons)
	var entries := [["−",1.0/1.4,40.0],["전체",0.0,46.0],["+",1.4,40.0]]
	for index in entries.size():
		var entry: Array = entries[index]
		if index > 0:
			var divider := ColorRect.new()
			divider.color = Color(0.63,0.75,0.78,0.22)
			divider.custom_minimum_size = Vector2(1,0)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			buttons.add_child(divider)
		var factor: float = entry[1]
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(float(entry[2]),40)
		button.add_theme_font_override("font",AppTheme.font(800))
		button.add_theme_font_size_override("font_size",12 if factor == 0 else 17)
		button.add_theme_color_override("font_color",Color("cfe0e6"))
		for state in ["normal","hover","pressed","focus","disabled"]:
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color(0.72,1,0.92,0.12) if state == "pressed" else Color.TRANSPARENT
			button.add_theme_stylebox_override(state,flat)
		button.pressed.connect(func():
			if factor == 0: animate_to(owner,destination(owner,fit.bind(owner)),0.42)
			else: animate_to(owner,destination(owner,owner.scale_at.bind(factor,owner.view.size*0.5))))
		buttons.add_child(button)
	owner.zoom_controls = group

func close_menu() -> void:
	if is_instance_valid(menu): menu.visible = false

func update_overlay(owner) -> void:
	if not is_instance_valid(point_bar): return
	var drafting: bool = owner.changed()
	var delta: int = owner.spent(owner.lobby.core_draft)-owner.spent(owner.actual())
	remaining_label.text = str(owner.total()-owner.spent(owner.actual()))
	earned_label.text = "· 획득 %d" % owner.total()
	draft_chip.text = ("−%dP 예정" % delta) if delta >= 0 else ("+%dP 반환" % -delta)
	draft_chip.visible = drafting
	owner.cancel_button.visible = drafting
	owner.apply_button.visible = drafting
	menu_button.visible = not drafting
	if drafting: close_menu()
	owner.apply_button.disabled = owner.allocating or not owner.valid(owner.lobby.core_draft)
	owner.cancel_button.disabled = owner.allocating
	owner.reset_button.disabled = owner.allocating or owner.spent(owner.actual()) <= 0
	owner.view.set_process(true)

func layout(owner) -> void:
	if not is_instance_valid(owner.view): return
	var view_size: Vector2 = owner.view.size
	if view_size.x <= 0 or view_size.y <= 0: return
	if is_instance_valid(owner.inline_panel):
		var width := maxf(1,view_size.x-16)
		var frame: StyleBox = owner.inline_panel.get_theme_stylebox("panel")
		var content: float = owner.inline_body.get_combined_minimum_size().y+frame.get_minimum_size().y
		var height := clampf(content,minf(144,view_size.y),maxf(144,view_size.y*0.55))
		owner.inline_panel.custom_minimum_size = Vector2.ZERO
		owner.inline_panel.size = Vector2(width,height)
		owner.inline_panel.position = Vector2(8,view_size.y-height-8)
	if is_instance_valid(owner.zoom_controls):
		owner.zoom_controls.visible = not is_instance_valid(owner.inline_panel)
		owner.zoom_controls.size = owner.zoom_controls.get_combined_minimum_size()
		owner.zoom_controls.position = view_size-owner.zoom_controls.size-Vector2(8,8)
	if is_instance_valid(menu) and is_instance_valid(point_bar):
		menu.size = menu.get_combined_minimum_size()
		menu.position = Vector2(view_size.x-menu.size.x-12,point_bar.position.y+point_bar.size.y+4)
	# Opening or closing a sheet changes the covered height; ease back inside it.
	if camera.is_empty():
		var target := destination(owner,clamp_view.bind(owner))
		if Vector2(target[1]) != owner.offset: animate_to(owner,target,0.26)

# ---- sheets ----
func open_sheet(owner) -> VBoxContainer:
	# A replacement is one layout change. Clamping the briefly absent sheet
	# would start a camera move toward a full-view boundary and keep it running.
	owner._close_inline(false)
	var panel := PanelContainer.new()
	panel.name = "CoreInlineDetails"
	var style := _frame("ui/components/panel_frame.png",12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel",style)
	owner.view.add_child(panel)
	owner.inline_panel = panel
	owner.inline_scroll = ScrollContainer.new()
	owner.inline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	owner.inline_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(owner.inline_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner.inline_scroll.add_child(body)
	owner.inline_body = body
	body.minimum_size_changed.connect(func(): layout(owner),CONNECT_DEFERRED)
	return body

func _close_button(owner) -> Button:
	var close := CloseButton.new()
	close.name = "CloseCoreDetails"
	close.custom_minimum_size = Vector2(34,34)
	close.pressed.connect(func():
		owner.selected = ""
		owner.selecting_skill = false
		owner._close_inline()
		owner.view.queue_redraw())
	return close

func _foot() -> Label:
	var foot := _plain("변경은 다음 스테이지부터 적용됩니다.",10,MUTED,600)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return foot

func effect_text(d: Dictionary, rank: int) -> String:
	var by_rank: Array = d.get("displayEffectsByRank",[])
	if rank < by_rank.size(): return str(by_rank[rank])
	# Source lists are rank totals, never accumulated across earlier ranks.
	var result := PackedStringArray()
	for raw in d.get("displayEffects",[]):
		var line := str(raw)
		var split := line.split(": ",true,1)
		if split.size()==2 and split[1].contains(" / "):
			var values := split[1].split(" / ")
			line = split[0]+": "+values[clampi(rank-1,0,values.size()-1)]
		result.append(line)
	return "\n".join(result) if not result.is_empty() else str(d.get("effectSummary",""))

func _effect_rows(owner, body: VBoxContainer, d: Dictionary, id: String, rank: int) -> void:
	var maximum := int(d.maxRank)
	var first := true
	for raw in d.get("displayEffects",[]):
		var split := str(raw).split(": ",true,1)
		var values := split[1].split(" / ") if split.size() == 2 else PackedStringArray()
		var box := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1,1,1,0.035)
		style.border_color = Color("22394a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		box.add_theme_stylebox_override("panel",style)
		body.add_child(box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",0)
		box.add_child(column)
		if values.size() != maximum or maximum == 1:
			# Sentences without per-rank values (keystones, extra HP) read whole.
			var whole := _plain(effect_text(d,maxi(1,rank)) if first else str(raw),12,Color("c7d5d8"))
			whole.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if first: whole.name = "CoreCurrentEffect"
			column.add_child(whole)
		else:
			column.add_child(_plain(split[0],12,Color("c7d5d8")))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation",10)
			column.add_child(line)
			var applied := applied_rank(owner,id)
			var current := _plain(values[rank-1] if rank > 0 else "—",22,(Color("f3e6c4") if rank == applied else PLANNED) if rank > 0 else MUTED,900)
			if first: current.name = "CoreCurrentEffect"
			line.add_child(current)
			if rank < maximum:
				var arrow := _plain("→",18,MUTED,700)
				line.add_child(arrow)
				var next := _plain(values[rank],22,GOLD,900)
				if first: next.name = "CoreNextEffect"
				line.add_child(next)
		first = false

func node_details(owner, id: String) -> void:
	owner.selecting_skill = false
	owner.selected = id
	var d: Dictionary = owner.data().nodes[id]
	var rank := int(owner.lobby.core_draft.get(id,0))
	var maximum := int(d.maxRank)
	var body := open_sheet(owner)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",10)
	body.add_child(head)
	var art := NodeArt.new()
	art.tree = self
	art.core = owner
	art.id = id
	art.custom_minimum_size = Vector2(56,56)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(art)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_constant_override("separation",2)
	head.add_child(title)
	var name_label := _plain(owner.node_name(id),18,Color("f3e6c4"),900)
	name_label.name = "CoreNodeName"
	title.add_child(name_label)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation",5)
	title.add_child(tags)
	var category := _plain(str(d.get("category","")),11,Color("1c0f08"),800)
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(str(visuals[id].color))
	tag.set_corner_radius_all(4)
	tag.content_margin_left = 6
	tag.content_margin_right = 6
	category.add_theme_stylebox_override("normal",tag)
	tags.add_child(category)
	head.add_child(_close_button(owner))
	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation",8)
	body.add_child(rank_row)
	var bar := RankBar.new()
	bar.name = "CoreRankBar"
	bar.applied = applied_rank(owner,id)
	bar.rank = rank
	bar.maximum = maximum
	bar.custom_minimum_size = Vector2(0,28)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_row.add_child(bar)
	var count := _plain("%d/%d" % [rank,maximum],15,Color("e8f8ff"),900)
	count.custom_minimum_size.x = 38
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_row.add_child(count)
	_effect_rows(owner,body,d,id,rank)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation",8)
	body.add_child(acts)
	var minus := Button.new()
	minus.name = "CoreRefundRank"
	minus.text = "−"
	minus.tooltip_text = "등급 내리기"
	minus.custom_minimum_size = Vector2(64,46)
	minus.disabled = owner.allocating or rank <= 0 or not owner.valid(owner.candidate(id,-1))
	minus.pressed.connect(owner.change_rank.bind(id,-1))
	_style_levelup(minus,18)
	acts.add_child(minus)
	var plus := Button.new()
	plus.name = "CorePurchaseRank"
	plus.text = "최대 등급" if rank >= maximum else "강화"
	plus.custom_minimum_size = Vector2(0,46)
	plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plus.disabled = owner.allocating or rank >= maximum or not owner.valid(owner.candidate(id,1))
	plus.pressed.connect(owner.change_rank.bind(id,1))
	_style_levelup(plus,14)
	acts.add_child(plus)
	if rank < maximum: _cost_chip(owner,plus,int(d.rankCosts[rank]))
	body.add_child(_foot())
	layout(owner)
	owner.view.queue_redraw()

func _style_levelup(button: Button, pixels: int) -> void:
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		var style := _levelup_style(state == "disabled")
		if state == "hover": style.modulate_color = Color(1.12,1.12,1.12)
		elif state in ["pressed","hover_pressed"]: style.modulate_color = Color(0.82,0.9,0.94)
		button.add_theme_stylebox_override(state,style)
	button.add_theme_font_override("font",AppTheme.font(900))
	button.add_theme_font_size_override("font_size",pixels)
	button.add_theme_color_override("font_color",Color("e8fbff"))
	button.add_theme_color_override("font_hover_color",Color("e8fbff"))
	button.add_theme_color_override("font_pressed_color",Color("e8fbff"))
	button.add_theme_color_override("font_disabled_color",Color("6d7f8f"))

## Same rune-cost chip as the upgrade screen, carrying the core point glyph.
func _cost_chip(owner, button: Button, cost: int) -> void:
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_right = -8
	var chip := PanelContainer.new()
	chip.name = "CoreRankCost"
	var frame := Frame.new("ui/components/upgrade_rune_cost_frame_v2.png",9)
	frame.source_center = Rect2(10,6,60,15)
	frame.content_margin_top = 4
	frame.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel",frame)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if button.disabled: chip.modulate.a = 0.5
	holder.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(_glyph_label(HUB_GLYPH,15,Color("7fd8e6"),owner))
	row.add_child(_plain(str(cost),13,Color("b9d6e4"),800))

func skills(owner) -> void:
	owner.selecting_skill = true
	owner.selected = ""
	var body := open_sheet(owner)
	var head := HBoxContainer.new()
	body.add_child(head)
	var title := _plain("코어 스킬",18,Color("f3e6c4"),900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_close_button(owner))
	var current := str(owner.lobby.progression().get("coreCombatSkill",""))
	for id in ["guardianBeam","riftMark"]:
		var unlocked: bool = Progression.has_unlock(owner.lobby.progression(),"core",id)
		var row := PanelContainer.new()
		row.name = "CoreSkill_"+id
		row.add_theme_stylebox_override("panel",Frame.new("ui/components/row_frame.png" if unlocked else "ui/components/row_frame_locked.png",10))
		body.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",10)
		row.add_child(line)
		var socket := TextureRect.new()
		socket.texture = owner.tex("ui/components/icon_socket.png")
		socket.custom_minimum_size = Vector2(52,52)
		socket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		socket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(socket)
		var icon := TextureRect.new()
		icon.texture = owner.tex("core_abilities/%s.png" % ("guardian_beam" if id == "guardianBeam" else "rift_mark"))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not unlocked: icon.modulate = LOCKED_TINT
		socket.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 9
		icon.offset_top = 9
		icon.offset_right = -9
		icon.offset_bottom = -9
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation",2)
		line.add_child(text)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation",6)
		text.add_child(name_row)
		name_row.add_child(_plain(owner.lobby.display_title(id),14,Color("f3e6c4"),900))
		if current == id:
			var badge := _plain("장착 중",10,Color("1c1406"),800)
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = GOLD
			badge_style.set_corner_radius_all(4)
			badge_style.content_margin_left = 5
			badge_style.content_margin_right = 5
			badge.add_theme_stylebox_override("normal",badge_style)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			name_row.add_child(badge)
		var description := _plain(SKILL_TEXT[id] if unlocked else SKILL_LOCKED_TEXT,11,Color("b9d6e4"),600)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(description)
		var equip := _button("해제" if current == id else ("장착" if unlocked else "잠김"),"secondary" if current == id or not unlocked else "primary",func():
			owner.lobby.apply_growth_change({"kind":"unequipCoreCombatSkill" if current == id else "equipCoreCombatSkill","id":id})
			owner.skills())
		equip.custom_minimum_size.x = 72
		equip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		equip.disabled = not unlocked
		line.add_child(equip)
	body.add_child(_foot())
	layout(owner)
	owner.view.queue_redraw()
