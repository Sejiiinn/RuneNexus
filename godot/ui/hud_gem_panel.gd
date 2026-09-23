extends RefCounted
## Equipped sockets and inventory presentation; commands route through the HUD.
## Reads the live HUD owner; no selection, snapshot or cache copies.
const Frame = preload("res://ui/lobby_frame.gd")
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _gems(state: Dictionary,turret: Dictionary,_q: Dictionary) -> void:
	var max_slots = int(hud.configuration_cache.derived(state,hud.app.run_domain.service).get("maxTurretLinkSlots",3))
	var sockets := HBoxContainer.new()
	sockets.name = "EquippedSocketRows"
	sockets.alignment = BoxContainer.ALIGNMENT_CENTER
	sockets.add_theme_constant_override("separation",0)
	hud.body.add_child(sockets)
	var buttons: Array[Button] = []
	for i in range(clampi(max_slots,3,6)):
		var locked := i >= int(turret.slotLimit)
		if i > 0:
			var join := MarginContainer.new()
			join.add_theme_constant_override("margin_bottom",18)
			sockets.add_child(join)
			var link := TextureRect.new()
			link.texture = hud.AppTheme.texture("ui/components/gem_link_locked.png" if locked else "ui/components/gem_link_active.png")
			link.custom_minimum_size = Vector2(12,8)
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			link.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			link.stretch_mode = TextureRect.STRETCH_SCALE
			join.add_child(link)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation",0)
		sockets.add_child(cell)
		var socket: Button = hud._button(cell,"",func():
			hud.selected_slot = -1 if locked and hud.selected_slot == i else i
			hud.selected_gem = ""
			hud.refresh())
		socket.name = "EquippedSlot%d" % i
		socket.set_meta("locked",locked)
		socket.custom_minimum_size = Vector2(36,36)
		buttons.append(socket)
		for style in ["normal","hover","pressed","disabled","focus"]:
			socket.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		var file := "gem_socket_locked.png" if locked else ("gem_socket_selected.png" if i == hud.selected_slot else "gem_socket_empty.png")
		socket.icon = hud.AppTheme.texture("ui/components/"+file)
		socket.expand_icon = true
		if locked and i == hud.selected_slot: socket.self_modulate = Color("ffe29a")
		var badge := PanelContainer.new()
		badge.name = "GemSlotPriceBadge%d" % i
		badge.custom_minimum_size.y = 18
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			var badge_style := Frame.new("ui/components/card_frame.png",1)
			badge_style.set_texture_margin_all(4)
			badge.add_theme_stylebox_override("panel",badge_style)
		else: badge.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		cell.add_child(badge)
		var tag: Label = hud._label(badge,"",10)
		tag.name = "GemSlotPrice%d" % i
		tag.custom_minimum_size.y = 16
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		if locked:
			var price := _slot_price(state,int(turret.id),i)
			tag.text = "%d G" % price if price > 0 else "—"
			tag.modulate = Color("f0d28a")
			continue
		var gem = turret.equippedGemSlots[i]
		if gem != null:
			var icon := TextureRect.new()
			icon.texture = hud.AppTheme.texture("gems/"+str(gem)+".png")
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			socket.add_child(icon)
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 7; icon.offset_right = -7; icon.offset_top = 7; icon.offset_bottom = -7
	var fit := func():
		var available := minf(sockets.size.x,hud.get_viewport_rect().size.x-32)
		var extent := clampf((available-12*(buttons.size()-1))/buttons.size(),36,54)
		for button in buttons: button.custom_minimum_size = Vector2(extent,extent)
	sockets.resized.connect(fit)
	var viewport: Viewport = hud.get_viewport()
	viewport.size_changed.connect(fit)
	sockets.tree_exiting.connect(func():
		if viewport.size_changed.is_connected(fit): viewport.size_changed.disconnect(fit))
	fit.call_deferred()
	# Fixed reservation keeps sockets and inventory stationary for every selection.
	var band := Control.new()
	band.name = "GemDetailBand"
	band.custom_minimum_size.y = 30
	band.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.body.add_child(band)
	band.gui_input.connect(func(event):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			hud.selected_slot = -1
			hud.refresh())
	if hud.selected_slot >= int(turret.slotLimit) and hud.selected_slot < buttons.size():
		_unlock_popover(band,buttons[hud.selected_slot],state,turret)
	else:
		var row := HBoxContainer.new()
		band.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chosen: String = hud.selected_gem
		var equipped := false
		if chosen.is_empty() and hud.selected_slot >= 0 and hud.selected_slot < turret.equippedGemSlots.size():
			var value = turret.equippedGemSlots[hud.selected_slot]
			if value != null: chosen = str(value); equipped = true
		if chosen.is_empty():
			hud._label(row,"장착할 소켓과 젬을 선택하세요.",11)
		else:
			hud._icon(row,"gems/"+chosen+".png",34)
			var detail := VBoxContainer.new()
			detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			detail.add_theme_constant_override("separation",0)
			row.add_child(detail)
			hud._label(detail,_gem_name(chosen)+" · "+_gem_effect(chosen,turret),12)
			var reason := "" if equipped else _gem_block_reason(chosen,turret)
			if reason.is_empty(): _gem_rule(detail,chosen,0)
			else: hud._label(detail,reason,10).modulate = Color("ffa68a")
			var action: Button = hud._button(row,"해제" if equipped else "장착",func():
				hud._selected_command("removeGem" if equipped else "equipGem",{"type":chosen,"slot":hud.selected_slot})
				hud.selected_gem = ""
				hud.refresh())
			action.disabled = not reason.is_empty()
			# Long equipped/selected descriptions may grow just enough to remain
			# readable; empty selection and unlock keep the compact fixed band.
			var detail_refs := [weakref(row),weakref(band)]
			var fit_detail := func():
				var live_row: HBoxContainer = detail_refs[0].get_ref()
				var live_band: Control = detail_refs[1].get_ref()
				if live_row == null or live_band == null: return
				live_band.custom_minimum_size.y = maxf(30,live_row.get_combined_minimum_size().y)
			row.minimum_size_changed.connect(fit_detail)
			row.resized.connect(fit_detail)
			fit_detail.call_deferred()
	_inventory_strip(hud.body,state,turret)

func _slot_price(state: Dictionary, turret_id: int, slot: int) -> int:
	# Quote a hypothetical opened count with the same production pricing rules.
	# Only the target turret is copied deeply; live state and derived data stay intact.
	var preview := state.duplicate()
	preview.turrets = state.turrets.duplicate()
	for index in range(preview.turrets.size()):
		if int(preview.turrets[index].id) != turret_id: continue
		var target: Dictionary = preview.turrets[index].duplicate(true)
		target.slotLimit = slot
		target.level = maxi(int(target.level),5 if slot >= 2 else 1)
		preview.turrets[index] = target
		return int(hud.app.run_domain.service.quotes(preview,turret_id).get("link",0))
	return 0

func _unlock_popover(band: Control, socket: Button, state: Dictionary, turret: Dictionary) -> void:
	var turret_id := int(turret.id)
	var opened := int(turret.slotLimit)
	var slot := int(hud.selected_slot)
	var price := int(hud.app.run_domain.service.quotes(state,turret_id).get("link",0))
	var reason := ""
	if slot != opened: reason = "앞 소켓부터 해금"
	elif price <= 0: reason = "포탑 Lv.5 필요"
	var popup := PanelContainer.new()
	popup.name = "GemSlotUnlock"
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var shell := StyleBoxTexture.new()
	shell.texture = hud.AppTheme.texture("ui/components/gem_unlock_plate.png")
	shell.set_texture_margin_all(0)
	shell.content_margin_left = 4
	shell.content_margin_right = 4
	shell.content_margin_top = 5
	shell.content_margin_bottom = 3
	popup.add_theme_stylebox_override("panel",shell)
	band.add_child(popup)
	var badge := socket.get_parent().get_node("GemSlotPriceBadge%d" % slot) as Control
	# Keep its layout reservation while the selected tag becomes one continuous plate.
	badge.modulate.a = 0
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",0)
	popup.add_child(content)
	var display_price := _slot_price(state,turret_id,slot)
	var tag: Label = hud._label(content,"%d G" % display_price if display_price > 0 else "—",10)
	tag.name = "GemSlotUnlockPrice"
	tag.custom_minimum_size.y = 16
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.modulate = Color("f0d28a")
	# Requirements sit below the unified plate, never widening it across other prices.
	var condition: Label = hud._label(band,reason,10)
	condition.name = "GemSlotCondition"
	condition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	condition.visible = not reason.is_empty()
	var confirm: Button = hud._button(content,"해금",func():
		if popup.get_meta("submitted",false): return
		popup.set_meta("submitted",true)
		var current: Dictionary = hud.app.run_domain.state
		var live: Dictionary = hud.app.run_domain.service.turret(current,turret_id)
		if live.is_empty() or int(live.slotLimit) != opened: return
		var fresh_price := int(hud.app.run_domain.service.quotes(current,turret_id).get("link",0))
		if slot != opened or fresh_price != price or fresh_price <= 0 or int(current.get("gold",0)) < fresh_price:
			popup.set_meta("submitted",false)
			return
		if hud.app.apply_run_command({"kind":"link","id":turret_id}):
			hud.selected_slot = opened
			hud.selected_gem = ""
		else: popup.set_meta("submitted",false)
		hud.refresh())
	confirm.name = "UnlockGemSlot"
	confirm.custom_minimum_size = Vector2(0,21)
	if reason.is_empty(): confirm.set_meta("gem_unlock_condition",condition)
	hud.Components.apply(confirm,"primary")
	# The approved image includes both faces and their shared beveled frame.
	# Native button text/input overlays it without introducing a second surface.
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		confirm.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
	hud._track_purchase_button(confirm,"gold",price,not reason.is_empty() or state.phase not in ["preparation","wave"])
	confirm.tooltip_text = reason if not reason.is_empty() else "필요 골드 · %d G" % price
	var references := [weakref(popup),weakref(badge),weakref(band),weakref(condition)]
	var align := func():
		var live_popup: PanelContainer = references[0].get_ref()
		var live_badge: Control = references[1].get_ref()
		var live_band: Control = references[2].get_ref()
		var live_condition: Label = references[3].get_ref()
		if live_popup == null or live_badge == null or live_band == null or live_condition == null: return
		live_popup.size = Vector2(54,45).max(live_popup.get_combined_minimum_size())
		var center := live_badge.get_global_rect().get_center().x-live_band.global_position.x
		live_popup.position = Vector2(clampf(center-live_popup.size.x*0.5,0,maxf(0,live_band.size.x-live_popup.size.x)),live_badge.global_position.y-live_band.global_position.y)
		var left_space := maxf(0,live_popup.position.x-4)
		var right_space := maxf(0,live_band.size.x-live_popup.position.x-live_popup.size.x-4)
		var on_right := right_space >= left_space
		live_condition.size = Vector2(minf(128,right_space if on_right else left_space),16)
		live_condition.position = Vector2(live_popup.position.x+live_popup.size.x+4 if on_right else maxf(0,live_popup.position.x-live_condition.size.x-4),0)
	band.resized.connect(align)
	popup.minimum_size_changed.connect(align)
	condition.minimum_size_changed.connect(align)
	badge.resized.connect(align)
	socket.resized.connect(align)
	# Containers may move the fixed band after their children have resized.
	# Realign after position changes as well, without a per-frame layout loop.
	var queue_align := func(): align.call_deferred()
	band.item_rect_changed.connect(queue_align)
	badge.item_rect_changed.connect(queue_align)
	socket.get_parent().sort_children.connect(queue_align)
	hud.get_tree().process_frame.connect(align,CONNECT_ONE_SHOT)
	align.call_deferred()

func _inventory_strip(parent: Node,state: Dictionary,turret: Dictionary = {}) -> void:
	var inv_scroll = ScrollContainer.new(); inv_scroll.name = "GemInventoryStrip"; inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; parent.add_child(inv_scroll)
	var inventory = HBoxContainer.new(); inventory.name = "GemInventoryTiles"; inventory.add_theme_constant_override("separation",0); inv_scroll.add_child(inventory)
	var cells: Array[Control] = []
	var blanks: Array[Control] = []
	var gaps: Array[Control] = []
	for type in state.gemInventory:
		if int(state.gemInventory[type]) <= 0: continue
		var b = hud._button(inventory,"",func():
			if not turret.is_empty() and hud.selected_slot >= int(turret.slotLimit): hud.selected_slot = -1
			if hud.selected_gem == type and not turret.is_empty() and _gem_block_reason(type,turret).is_empty(): hud._selected_command("equipGem",{"type":type,"slot":hud.selected_slot}); hud.selected_gem = ""
			else: hud.selected_gem = type
			hud.refresh())
		b.name = "GemInventory_"+str(type)
		b.custom_minimum_size = Vector2(48,48)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cells.append(b)
		b.toggle_mode = true
		b.button_pressed = hud.selected_gem == type
		for state_name in ["normal","hover","pressed","disabled","focus"]:
			var frame := Frame.new("ui/components/card_frame.png",2)
			if hud.selected_gem == type: frame.modulate_color = Color("ffe29a")
			elif state_name == "hover": frame.modulate_color = Color("a6f4ff")
			b.add_theme_stylebox_override(state_name,frame)
		var icon := TextureRect.new()
		icon.texture = hud.AppTheme.texture("gems/"+type+".png")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		icon.name = "GemInventoryIcon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		icon.offset_left = -17; icon.offset_right = 17; icon.offset_top = 3; icon.offset_bottom = 37
		var count: Label = hud._label(b,"×%d" % state.gemInventory[type],10)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		count.offset_left = 3; count.offset_right = -4; count.offset_top = -15; count.offset_bottom = -1
		b.tooltip_text = "%s ×%d" % [_gem_name(type),state.gemInventory[type]]

		if not turret.is_empty():
			b.disabled = state.phase not in ["preparation","wave"]
			var reason := _gem_block_reason(type,turret)
			if not reason.is_empty(): b.tooltip_text += " · "+reason
	var fit := func():
		var available := floori(inv_scroll.size.x)
		if available <= 0 or is_equal_approx(float(inv_scroll.get_meta("fitted_width",-1.0)),available): return
		inv_scroll.set_meta("fitted_width",available)
		# A complete page ends at the viewport edge; surplus owned gems keep scrolling.
		var columns := maxi(1,roundi((available+4.0)/52.0))
		var extent := floori((available-4.0*(columns-1))/columns)
		var remainder := available-columns*extent-4*(columns-1)
		var missing := maxi(0,columns-cells.size())
		while blanks.size() > missing:
			var blank: Control = blanks.pop_back()
			inventory.remove_child(blank)
			blank.queue_free()
		while blanks.size() < missing:
			_empty_inventory_slot(inventory,Vector2(extent,extent),blanks.size())
			blanks.append(inventory.get_child(inventory.get_child_count()-1))
		for gap in gaps:
			inventory.remove_child(gap)
			gap.queue_free()
		gaps.clear()
		var ordered: Array[Control] = cells+blanks
		for index in range(ordered.size()):
			var cell := ordered[index]
			cell.custom_minimum_size = Vector2(extent,extent)
			inventory.move_child(cell,inventory.get_child_count()-1)
			if index == ordered.size()-1: continue
			# Integer spacers distribute subpixel remainder evenly without HBox
			# rounding every fractional tile up and clipping the final square.
			var within_page := index % columns
			var extra := 0
			if within_page < columns-1:
				extra = roundi(float((within_page+1)*remainder)/(columns-1))-roundi(float(within_page*remainder)/(columns-1))
			var gap := Control.new()
			gap.name = "GemInventoryGap%d" % index
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gap.custom_minimum_size.x = 4+extra
			inventory.add_child(gap)
			gaps.append(gap)
		inv_scroll.set_meta("page_columns",columns)
		inv_scroll.set_meta("cell_extent",extent)
	inv_scroll.resized.connect(fit)
	fit.call_deferred()

func _inventory(state: Dictionary) -> void:
	var heading = HBoxContainer.new(); hud.body.add_child(heading); hud._label(heading,"젬 보관함",14); _purchase(heading,state)
	var owned = []
	for type in hud.app.run_domain.growth.data.gems:
		if int(state.gemInventory.get(type,0))>0: owned.append(type)
	if owned.is_empty():
		hud._label(hud.body,"보유한 젬이 없습니다. 5라운드 보상 또는 파편 구매로 젬을 획득하세요.",11)
		return
	var grid := GridContainer.new()
	grid.name = "GemInventoryGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	hud.body.add_child(grid)
	var fit := func(): grid.columns = 3 if hud.get_viewport_rect().size.x >= 400 else 2
	grid.resized.connect(fit)
	fit.call()
	for type in owned:
		var panel := PanelContainer.new()
		panel.name = "GemCard_"+str(type)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",Frame.new("ui/components/card_frame.png",6))
		grid.add_child(panel)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation",3)
		panel.add_child(card)
		var art := HBoxContainer.new()
		card.add_child(art)
		var balance := Control.new(); balance.custom_minimum_size.x = 22; art.add_child(balance)
		var icon: TextureRect = hud._icon(art,"gems/"+type+".png",34)
		icon.name = "GemIcon"
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count: Label = hud._label(art,"×%d" % state.gemInventory[type],12)
		count.name = "GemQuantity"
		count.custom_minimum_size.x = 22
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var title: Label = hud._label(card,_gem_name(type),13)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var effect: Label = hud._label(card,_gem_inventory_effect(type),12)
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_gem_rule(card,type,0)

func _empty_inventory_slot(parent: Node, minimum: Vector2, index: int) -> void:
	var slot := PanelContainer.new()
	slot.name = "EmptyGemSlot%d" % index
	slot.custom_minimum_size = minimum
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Frame.new("ui/components/card_frame.png",4)
	frame.modulate_color = Color("77929d")
	slot.add_theme_stylebox_override("panel",frame)
	parent.add_child(slot)

func _purchase(parent: Node,state: Dictionary) -> void:
	var cost: int = hud.app.run_domain.growth.data.constants.gemChoicePurchaseCost
	var b = hud._button(parent,"젬 구매 · %d 조각" % cost,func(): hud._command({"kind":"purchaseGemChoice"}))
	hud._track_purchase_button(b,"gemShards",cost,state.phase not in ["preparation","wave"])

func _gem_name(type: String) -> String:
	return str(hud.labels.gems.get(type,{}).get("name",type))

func _gem_description(type: String) -> String:
	var gem: Dictionary = hud.labels.gems.get(type,{})
	return str(gem.get("description",""))

func _gem_rule(parent: Node,type: String,minimum_width: float = 200) -> void:
	if hud.rewards.RULES.has(type):
		var note = hud._label(parent,"("+str(hud.rewards.RULES[type])+")",10)
		note.modulate = Color("939aa4"); note.custom_minimum_size.x = minimum_width

func _gem_block_reason(type: String,turret: Dictionary) -> String:
	if type in turret.equippedGemSlots: return "이미 이 포탑에 장착됨"
	if hud.selected_slot<0 or hud.selected_slot>=int(turret.slotLimit): return "링크 홈을 선택하세요"
	if type not in hud.app.run_domain.growth.data.turretRules[turret.type].compatibleGems:
		return {"multipleProjectiles":"투사체 공격 포탑에만 장착 가능","chain":"투사체 공격 또는 기본 연쇄 포탑에만 장착 가능","heavyWeapon":"중화기 포탑에만 장착 가능","aimSpeed":"조준 속도 적용 포탑에만 장착 가능"}.get(type,"이 포탑에는 장착할 수 없습니다")
	return ""

func _gem_effect(type: String,turret: Dictionary) -> String:
	var definition: Dictionary = hud.app.catalog.data.turrets[turret.type].configuration.statInput.definition
	var tags: Array = definition.get("attackTags",[])
	if type == "physicalDamage" and definition.damageFamily != "physical": return "현재 적용되는 물리 피해 없음"
	if type == "elementalDamage" and definition.damageFamily != "elemental": return "현재 적용되는 원소 피해 없음"
	if type == "lightWeapon" and "light" not in tags: return "현재 적용되는 경량화기 피해 없음"
	if type == "damageOverTime" and "damageOverTime" not in tags: return "현재 적용되는 지속피해 없음"
	if type == "aimSpeed" and (not definition.instantHit or float(definition.aimDuration)<=0): return "현재 적용되는 조준 속도 없음"
	return {"attackSpeed":"공격 속도 40% 증폭","range":"사거리 20% 증폭","physicalDamage":"물리 피해 40% 증폭","elementalDamage":"원소 피해 40% 증폭","lightWeapon":"경량화기 피해 20% 증폭, 초당 발사 20% 증폭","heavyWeapon":"피해 30% 증폭, 효과 범위 20% 증가 (중화기 전용)","damageOverTime":"지속피해 30% 증가, 지속시간 30% 증가","explosion":"범위 피해 부여, 효과 범위 25% 증가","chain":"연쇄 횟수 +2","multipleProjectiles":"투사체 +2 · 피해 50% 감폭","criticalChance":"치명 확률 +30%p","aimSpeed":"조준 속도 75% 증폭","damageAmplifier":"타격 피해 25% 증폭","armorPiercing":"방어구 감쇄 무시"}.get(type,_gem_description(type))

func _gem_inventory_effect(type: String) -> String:
	return {"attackSpeed":"공속 40% 증폭","range":"사거리 20% 증폭","physicalDamage":"물리 40% 증폭","elementalDamage":"원소 40% 증폭","lightWeapon":"경량화기 강화","damageOverTime":"지속피해 증가","multipleProjectiles":"투사체 +2\n피해 50% 감폭"}.get(type,_gem_description(type))
