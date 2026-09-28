extends RefCounted
## Turret stats, level preview, traits and target-priority presentation.
## Reads the live HUD owner; no selection, snapshot or cache copies.
const GemPalette = preload("res://ui/battle_rewards.gd")
const HudNumber = preload("res://ui/hud_number.gd")
const CATEGORY_NAMES := {"physical": "물리", "elemental": "원소", "light": "경량화기", "heavy": "중화기", "damageOverTime": "지속피해", "cooling": "냉각"}
const CATEGORY_GEMS := {"physical": "physicalDamage", "elemental": "elementalDamage", "light": "lightWeapon", "heavy": "heavyWeapon", "damageOverTime": "damageOverTime"}
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _action_spec(turret: Dictionary,q: Dictionary) -> Dictionary:
	return {
		"title":hud.TOWERS.get(turret.type,turret.type),"icon":"ui/hud/turrets_3d/"+turret.type+".png",
		"level":"%d→%d" % [turret.level,int(turret.level)+1] if hud.app.selection_view.level_preview else "Lv.%d" % turret.level,
		"upgrade_title":"강화 확정" if hud.app.selection_view.level_preview else "강화",
		"price":"최대 레벨" if int(q.level)<=0 else "%d G" % q.level,"maximum":int(q.level)<=0,
		"trait_count":int(turret.get("primaryTrait") != null)+int(turret.get("secondaryTrait") != null),
		"active_tab":"stats" if hud.app.selection_view.level_preview else hud.tab,"upgrade_callback":_preview_level,
		"trait_callback":_open_current_traits,"sell_callback":_open_current_sale,
		"stats_callback":func(): hud.tab = "stats"; hud.refresh(),"gems_callback":_show_gems,
	}

func _turret(state: Dictionary,turret: Dictionary) -> void:
	var q: Dictionary = hud.app.run_domain.service.quotes(state,int(turret.id))
	var panel = preload("res://ui/turret_action_panel.gd").new()
	hud.body.add_child(panel)
	panel.configure(_action_spec(turret,q))
	_update_actions(panel,turret,q)
	if not hud.app.selection_view.level_preview and hud.tab == "gems": hud.gem_panel._gems(state,turret,q); return
	var category_row := HBoxContainer.new(); category_row.name = "TurretCategoryAndTarget"; category_row.custom_minimum_size.y = 34
	category_row.add_theme_constant_override("separation",6); hud.body.add_child(category_row)
	var definition: Dictionary = hud.app.catalog.data.turrets[turret.type].configuration.statInput.definition
	_category_tag(category_row,str(definition.damageFamily))
	for tag in definition.get("attackTags",[]): _category_tag(category_row,str(tag))
	var category_spacer := Control.new(); category_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; category_row.add_child(category_spacer)
	var priority = hud._button(category_row,"",_priority)
	priority.name = "TurretTargetPriority"; priority.tooltip_text = "공격 목표 변경"
	priority.add_theme_font_size_override("font_size",11); priority.custom_minimum_size.y = 32
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		priority.add_theme_stylebox_override(state_name,hud.HudChrome.quiet(state_name,true,Color("65c9df"),Vector2(7,4)))
	var stat_scroll = ScrollContainer.new(); stat_scroll.name = "TurretStatsScroll"; stat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; stat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; hud.body.add_child(stat_scroll)
	var grid = GridContainer.new(); grid.name = "TurretStatsGrid"; grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",22); grid.add_theme_constant_override("v_separation",0); stat_scroll.add_child(grid)
	grid.minimum_size_changed.connect(_fit_stats.bind(stat_scroll,grid),CONNECT_DEFERRED)
	var total_line := HSeparator.new(); total_line.modulate = Color("70919d88"); hud.body.add_child(total_line)
	var total := HBoxContainer.new(); total.name = "TurretTotalDamage"; total.custom_minimum_size.y = 34
	total.add_theme_constant_override("separation",8); hud.body.add_child(total)
	hud._label(total,"누적 피해",12).modulate = Color("a6bcc8")
	hud.damage_label = hud._label(total,"0.0",12); hud.damage_label.name = "TurretTotalDamageValue"
	hud.damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hud.damage_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_update_turret(state,turret)

func _update_actions(panel: Control,turret: Dictionary,q: Dictionary) -> void:
	hud._track_purchase_button(panel.level_action,"gold",int(q.level),int(q.level)<=0)
	panel.level_action.tooltip_text = ("강화 확정" if hud.app.selection_view.level_preview else "다음 레벨 능력치 미리보기")+(" · %d G" % q.level if int(q.level)>0 else "")
	panel.trait_action.tooltip_text = "특성 확인 및 선택"
	panel.sell_action.tooltip_text = "판매 · +%d G · 금액 확인" % q.sell

func _update_turret(state: Dictionary,turret: Dictionary) -> void:
	var q: Dictionary = hud.app.run_domain.service.quotes(state,int(turret.id))
	var panel: Control = hud.body.get_node("TurretActionPanel")
	panel.update_values(_action_spec(turret,q)); _update_actions(panel,turret,q)
	var priority: Button = hud.body.find_child("TurretTargetPriority",true,false)
	priority.visible = hud.configuration_cache.derived(state,hud.app.run_domain.service).get("canSetTurretTargetPriority",false)
	priority.text = "공격 목표 · "+hud.PRIORITIES.get(turret.get("targetPriority","first"),"선두")+"  ▾"
	# Display-only fields belong to this presenter, not the shared raw stat cache.
	var stats = hud._stats(state,turret).duplicate()
	var next = {}; var future = turret.duplicate(true); future.level += 1
	if hud.app.selection_view.level_preview: next = hud._stats(state,future).duplicate()
	stats.dps = hud._dps(stats,turret.type)
	if not next.is_empty(): next.dps = hud._dps(next,turret.type)
	var specs = [["피해","damage"],["초당 피해","dps"],["공격 속도","attackRate"],["사거리","range"],["치명 확률","criticalChance"],["치명 피해","criticalDamageMultiplier"]]
	if float(stats.splashRadius) > 0 or turret.type == "magic": specs.append(["효과 범위","effectAreaMultiplier"])
	if float(stats.slowDuration) > 0:
		specs.append(["감속","slowMultiplier"]); specs.append(["감속 지속","slowDuration"])
	if turret.type in ["arrow","cannon"]: specs.append(["투사체","projectileCount"])
	if turret.type == "sniper": specs.append(["조준 시간","aimDuration"])
	if turret.type == "magic":
		stats.burnDuration = 2.0*float(stats.damageOverTimeDurationMultiplier)
		if not next.is_empty(): next.burnDuration = 2.0*float(next.damageOverTimeDurationMultiplier)
		specs.append(["화상 지속","burnDuration"])
	if int(stats.chainCount) > 0: specs.append(["연쇄","chainCount"])
	var grid: GridContainer = hud.body.find_child("TurretStatsGrid",true,false)
	var wanted := []
	for spec in specs:
		var cell_name := "Stat_"+str(spec[1]); wanted.append(cell_name)
		var cell: VBoxContainer = grid.get_node_or_null(cell_name)
		if cell == null: cell = _stat_cell(grid,spec)
		grid.move_child(cell,wanted.size()-1)
		var changed: bool = not next.is_empty() and not is_equal_approx(float(stats[spec[1]]),float(next[spec[1]]))
		var current: Label = cell.get_meta("current"); var future_value: Label = cell.get_meta("future")
		current.text = _stat_value(stats,spec[1]); current.modulate = Color("91a6b2") if changed else Color("e8f8ff")
		future_value.visible = changed
		future_value.text = "→ "+_stat_value(next,spec[1]) if changed else ""
		cell.tooltip_text = spec[0]+" · "+_stat_value(stats,spec[1],true)+(" → "+_stat_value(next,spec[1],true) if changed else "")
	for cell in grid.get_children():
		if str(cell.name) not in wanted: grid.remove_child(cell); cell.queue_free()
	_fit_stats(grid.get_parent(),grid)

func _stat_cell(grid: GridContainer,spec: Array) -> VBoxContainer:
	var cell := VBoxContainer.new(); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.name = "Stat_"+str(spec[1]); cell.add_theme_constant_override("separation",0); grid.add_child(cell)
	var row := HBoxContainer.new(); row.custom_minimum_size.y = 36; row.add_theme_constant_override("separation",4); cell.add_child(row)
	var title: Label = hud._label(row,spec[0],12); title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.modulate = Color("a6bcc8")
	var values := VBoxContainer.new(); values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.size_flags_vertical = Control.SIZE_SHRINK_CENTER; values.add_theme_constant_override("separation",0); row.add_child(values)
	var current: Label = hud._label(values,"",12)
	var future_value: Label = hud._label(values,"",12)
	for label in [current,future_value]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	future_value.modulate = Color("8ee6ff"); future_value.hide()
	cell.set_meta("current",current); cell.set_meta("future",future_value)
	var divider := HSeparator.new(); divider.modulate = Color("70919d66"); cell.add_child(divider)
	return cell

func _fit_stats(scroll: ScrollContainer,grid: GridContainer) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(grid): return
	# Preview labels briefly report a wrapped minimum before their width settles.
	# Keep the viewport tied to stat rows; excess content scrolls inside it.
	scroll.custom_minimum_size.y = minf(ceilf(float(grid.get_child_count())/2.0)*40.0,80.0)

func _current_turret() -> Dictionary:
	return hud.app.run_domain.service.turret(hud.app.run_domain.state,hud.app.run_domain.selected_id(hud.app.selected))

func _open_current_traits() -> void:
	var turret := _current_turret()
	if not turret.is_empty(): _traits(turret,hud.app.run_domain.service.quotes(hud.app.run_domain.state,int(turret.id)))

func _open_current_sale() -> void:
	var turret := _current_turret()
	if not turret.is_empty(): _sell_confirm(turret,hud.app.run_domain.service.quotes(hud.app.run_domain.state,int(turret.id)))

func _category_tag(parent: Node,key: String) -> void:
	if not CATEGORY_NAMES.has(key): return
	var color := Color(str(GemPalette.GEM_COLORS.get(CATEGORY_GEMS.get(key,""),"7FD8FF")))
	var chip := PanelContainer.new(); chip.name = "Category_"+key; chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new(); style.bg_color = Color(color,0.10); style.border_color = Color(color,0.75)
	style.set_border_width_all(1); style.set_corner_radius_all(3); style.content_margin_left = 7; style.content_margin_right = 7
	style.content_margin_top = 3; style.content_margin_bottom = 3; chip.add_theme_stylebox_override("panel",style)
	parent.add_child(chip)
	var label: Label = hud._label(chip,CATEGORY_NAMES[key],11); label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF; label.add_theme_color_override("font_color",color)

func _stat_value(stats: Dictionary,key: String,exact := false) -> String:
	# Only damage magnitudes use K/M. Keep other units and detailed tooltips exact.
	if key in ["damage","dps"] and not exact: return HudNumber.compact(float(stats[key]))
	if key == "slowMultiplier": return "%.0f%%" % ((1.0-float(stats[key]))*100)
	if key in ["criticalChance","criticalDamageMultiplier","effectAreaMultiplier"]: return "%.0f%%" % (float(stats[key])*100)
	if key == "range": return "%.2f칸" % (float(stats[key])/48.0)
	if key == "attackRate": return "%.2f회/초" % float(stats[key])
	if key in ["aimDuration","slowDuration","burnDuration"]: return "%.2f초" % float(stats[key])
	if key == "projectileCount": return "%d발" % int(stats[key])
	if key == "chainCount": return "%d회" % int(stats[key])
	return "%.1f" % float(stats[key])

func _preview_level() -> void:
	var turret := _current_turret()
	if turret.is_empty(): return
	var q: Dictionary = hud.app.run_domain.service.quotes(hud.app.run_domain.state,int(turret.id))
	if int(q.level) <= 0 or int(hud.app.run_domain.state.gold) < int(q.level): return
	if hud.app.selection_view.level_preview:
		hud._selected_command("level")
		turret = _current_turret()
		if turret.is_empty() or int(hud.app.run_domain.service.quotes(hud.app.run_domain.state,int(turret.id)).level) <= 0:
			hud.app.selection_view.level_preview = false
			hud.app.refresh_selection(); hud.refresh()
	else:
		hud.tab = "stats"; hud.app.selection_view.level_preview = true; hud.app.refresh_selection(); hud.refresh()

func _show_gems() -> void:
	hud.tab = "gems"
	hud.app.selection_view.level_preview = false
	hud.app.refresh_selection(); hud.refresh()

func _sell_confirm(turret: Dictionary,q: Dictionary) -> void:
	var box = hud.open_modal("포탑 판매")
	var detail: Label = hud._label(box,"%s Lv.%d 포탑을 판매할까요?\n%s 골드를 돌려받고 장착 젬은 보관함으로 돌아갑니다." % [hud.TOWERS.get(turret.type,turret.type),turret.level,HudNumber.compact_price(q.sell)],13)
	detail.tooltip_text = "판매 환급 · %d 골드" % q.sell
	box.tooltip_text = detail.tooltip_text
	var confirm: Button = hud._button(box,"판매 · +%s 골드" % HudNumber.compact_price(q.sell),func(): _confirm_sale(int(turret.id),int(q.sell)))
	confirm.tooltip_text = "판매 환급 · %d 골드" % q.sell
	hud.Components.apply(confirm,"danger")
	hud._button(box,"취소",hud.close_modal)

func _confirm_sale(id: int,quoted_refund: int) -> void:
	var state: Dictionary = hud.app.run_domain.state
	var turret: Dictionary = hud.app.run_domain.service.turret(state,id)
	if turret.is_empty(): hud.close_modal(); return
	var quote: Dictionary = hud.app.run_domain.service.quotes(state,id)
	if int(quote.sell) != quoted_refund:
		_sell_confirm(turret,quote)
		return
	hud._command({"kind":"sell","id":id})
	if _current_turret().is_empty():
		hud.app.selection_view.level_preview = false
		hud.app.refresh_selection()
	hud.close_modal()

func _traits(turret: Dictionary,q: Dictionary,tier: int = 0) -> void:
	turret = hud.app.run_domain.service.turret(hud.app.run_domain.state,int(turret.id))
	if turret.is_empty(): hud.close_modal(); return
	q = hud.app.run_domain.service.quotes(hud.app.run_domain.state,int(turret.id))
	if tier == 0: tier = 2 if turret.get("primaryTrait") != null else 1
	var box: VBoxContainer = hud.open_modal(hud.TOWERS.get(turret.type,turret.type)+" 특성",410,false,true,Color("63e6a5"),"reward")
	box.add_theme_constant_override("separation",10)
	var wallet := HBoxContainer.new(); wallet.name = "TraitWallet"; wallet.custom_minimum_size.y = 28
	wallet.add_theme_constant_override("separation",7); box.add_child(wallet)
	hud._icon(wallet,"ui/hud/icons/shard.png",22)
	var wallet_title: Label = hud._label(wallet,"보유 파편",12)
	wallet_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wallet_title.custom_minimum_size.x = 55; wallet_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet_title.modulate = Color("b7d5e3")
	var wallet_amount: Label = hud._label(wallet,HudNumber.compact(int(hud.app.run_domain.state.gemShards),0),15)
	wallet.tooltip_text = "%d 파편" % int(hud.app.run_domain.state.gemShards)
	wallet_amount.name = "TraitWalletAmount"; wallet_amount.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wallet_amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet_amount.add_theme_font_override("font",hud.AppTheme.font(900))
	var tabs := HBoxContainer.new(); tabs.name = "TraitTierTabs"
	tabs.add_theme_constant_override("separation",2); box.add_child(tabs)
	for value in [1,2]:
		var caption := "1차 · 무기 개조" if value == 1 else "2차 · 전투 교리"
		if value == 2 and turret.get("primaryTrait") == null: caption += "\n1차 선택 후"
		var button: Button = hud._button(tabs,caption,func(): hud.trait_preview = ""; _traits(turret,q,value))
		button.name = "TraitTier%d" % value; button.custom_minimum_size.y = 43
		button.toggle_mode = true; button.button_pressed = value == tier; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud._style_hud_button(button,"secondary",value == tier,Vector2(6,5),true)
		if value == 2 and turret.get("primaryTrait") == null: button.modulate = Color("b5c4d2")
	var kind := "primaryTrait" if tier == 1 else "secondaryTrait"
	var chosen: Variant = turret.get(kind)
	var required := 3 if tier == 1 else 7
	var cost := int(q[kind])
	var blocked := ""
	if chosen != null: blocked = "이번 런에서 이미 선택한 특성입니다."
	elif tier == 2 and turret.get("primaryTrait") == null: blocked = "2차 특성은 1차 특성을 먼저 선택해야 합니다."
	elif int(turret.level) < required: blocked = "%d차 특성은 Lv.%d부터 선택할 수 있습니다." % [tier,required]
	elif int(hud.app.run_domain.state.gemShards) < cost: blocked = "젬 파편이 %d개 부족합니다." % (cost-int(hud.app.run_domain.state.gemShards))
	var options: Array = q.get(kind+"s",[])
	if options.is_empty(): hud._label(box,"선택 가능한 특성이 없습니다.",12)
	for value in options:
		_trait_row(box,str(value),str(hud.labels.traitNames.get(value,value)),str(hud.labels.traitDescriptions.get(value,"")),hud.trait_preview == value or chosen == value,not blocked.is_empty(),func():
			if not blocked.is_empty(): return
			hud.trait_preview = str(value)
			_update_trait_selection())
	if not blocked.is_empty():
		var reason: Label = hud._label(box,blocked,11); reason.name = "TraitBlockedReason"
		reason.modulate = Color("ffa68a")
	var confirm: Button = hud._button(box,"",func(): _confirm_trait(turret,kind))
	confirm.name = "TraitConfirm"; confirm.custom_minimum_size.y = 52
	confirm.disabled = not blocked.is_empty() or hud.trait_preview not in options
	hud.Components.apply(confirm,"primary")
	var confirm_center := CenterContainer.new(); confirm_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.add_child(confirm_center); confirm_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var confirm_row := HBoxContainer.new(); confirm_row.name = "TraitConfirmContent"; confirm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_row.add_theme_constant_override("separation",8); confirm_center.add_child(confirm_row)
	var confirm_title: Label = hud._label(confirm_row,"선택 확정",16)
	confirm_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	confirm_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	confirm_title.add_theme_font_override("font",hud.AppTheme.font(900))
	var confirm_icon := TextureRect.new(); confirm_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_icon.texture = hud.AppTheme.texture("ui/hud/icons/shard.png")
	confirm_icon.custom_minimum_size = Vector2(22,22)
	confirm_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	confirm_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	confirm_row.add_child(confirm_icon)
	var confirm_cost: Label = hud._label(confirm_row,HudNumber.compact_price(cost),16)
	confirm.tooltip_text = "선택 확정 · %d 파편" % cost
	confirm_cost.name = "TraitConfirmCost"; confirm_cost.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	confirm_cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	confirm_cost.add_theme_font_override("font",hud.AppTheme.font(900))
	if confirm.disabled: confirm_row.modulate = Color("8d9da9")
	var notice: Label = hud._label(box,"선택한 특성은 이번 런 동안 변경할 수 없습니다.",11)
	notice.name = "TraitPermanentNotice"; notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.modulate = Color("abc9d8")
	var bottom_pad := Control.new(); bottom_pad.name = "TraitBottomPad"
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_pad.custom_minimum_size.y = 14; box.add_child(bottom_pad)

func _fit_trait_row(button: Button,content: MarginContainer,minimum_height: float) -> void:
	if not is_instance_valid(button) or not is_instance_valid(content) or button.size.x <= 0: return
	var height := maxf(minimum_height,content.get_combined_minimum_size().y)
	if not is_equal_approx(button.custom_minimum_size.y,height): button.custom_minimum_size.y = height

func _trait_row(parent: Node,id: String,title: String,description: String,selected: bool,locked: bool,on_select: Callable) -> void:
	var compact := hud.get_viewport_rect().size.x < 360
	var button: Button = hud._button(parent,"",on_select)
	button.name = "TraitChoice_"+id; button.custom_minimum_size.y = 126 if compact else 110
	button.disabled = locked; button.toggle_mode = true; button.button_pressed = selected
	var content := MarginContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left",9); content.add_theme_constant_override("margin_right",9)
	content.add_theme_constant_override("margin_top",8); content.add_theme_constant_override("margin_bottom",8)
	button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",8); content.add_child(row)
	var socket := PanelContainer.new(); socket.name = "TraitSocket"; socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket.custom_minimum_size = Vector2(48 if compact else 56,48 if compact else 56)
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(socket)
	var socket_style := StyleBoxFlat.new(); socket_style.bg_color = Color("09131e")
	socket_style.border_color = Color("8498a2"); socket_style.set_border_width_all(2)
	socket_style.set_corner_radius_all(30); socket_style.set_content_margin_all(2)
	socket.add_theme_stylebox_override("panel",socket_style)
	var icon := TextureRect.new(); icon.name = "TraitIcon"; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = hud.AppTheme.texture("ui/traits/"+id+".png")
	icon.custom_minimum_size = Vector2(44 if compact else 52,44 if compact else 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	socket.add_child(icon)
	var words := VBoxContainer.new(); words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL; words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation",3); row.add_child(words)
	var heading: Label = hud._label(words,title,13 if compact else 14)
	heading.name = "TraitName"; heading.add_theme_font_override("font",hud.AppTheme.font(800))
	heading.add_theme_color_override("font_color",Color("f4dfaa") if selected else Color("e8f8ff"))
	var detail: Label = hud._label(words,description.replace(", ","\n"),12)
	detail.name = "TraitDescription"; detail.modulate = Color("b6d0df")
	var radio := PanelContainer.new(); radio.name = "TraitRadio"; radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio.custom_minimum_size = Vector2(22,22); radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(radio)
	var center := CenterContainer.new(); center.mouse_filter = Control.MOUSE_FILTER_IGNORE; radio.add_child(center)
	var dot := PanelContainer.new(); dot.name = "TraitSelectedDot"; dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(10,10); center.add_child(dot)
	var fill := StyleBoxFlat.new(); fill.bg_color = Color("42e4f3"); fill.set_corner_radius_all(5)
	dot.add_theme_stylebox_override("panel",fill)
	_set_trait_selected(button,selected)
	if locked and not selected: content.modulate.a = 0.52
	# A Button does not inherit the minimum of its decorative children. Bridge
	# the native container minimum without estimating text lines or frame timing.
	var fit := _fit_trait_row.bind(button,content,126.0 if compact else 110.0)
	content.minimum_size_changed.connect(fit,CONNECT_DEFERRED)
	button.resized.connect(fit,CONNECT_DEFERRED)
	fit.call_deferred()

func _set_trait_selected(button: Button,selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("123549ef") if selected else Color("0b2030e8")
		style.border_color = Color("42e4f3") if selected else Color("355a6b")
		if state_name == "hover" and not button.disabled: style.bg_color = Color("1a3d50")
		style.set_border_width_all(2 if selected else 1); style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state_name,style)
	(button.find_child("TraitName",true,false) as Label).add_theme_color_override("font_color",Color("f4dfaa") if selected else Color("e8f8ff"))
	var ring := StyleBoxFlat.new(); ring.bg_color = Color("092131")
	ring.border_color = Color("42e4f3") if selected else Color("a3c2d5")
	ring.set_border_width_all(2); ring.set_corner_radius_all(12); ring.set_content_margin_all(4)
	(button.find_child("TraitRadio",true,false) as PanelContainer).add_theme_stylebox_override("panel",ring)
	button.find_child("TraitSelectedDot",true,false).visible = selected

func _update_trait_selection() -> void:
	# Selection changes only presentation. Preserve the open frame, scroll and
	# focused row instead of replaying the modal entrance and deferred layout.
	for child in hud.modal_body.get_children():
		if child is Button and str(child.name).begins_with("TraitChoice_"):
			_set_trait_selected(child,str(child.name).trim_prefix("TraitChoice_") == hud.trait_preview)
	var confirm: Button = hud.modal_body.find_child("TraitConfirm",true,false)
	confirm.disabled = false
	confirm.find_child("TraitConfirmContent",true,false).modulate = Color.WHITE

func _confirm_trait(turret: Dictionary,kind: String) -> void:
	var selected := str(hud.trait_preview)
	var state: Dictionary = hud.app.run_domain.state
	var current: Dictionary = hud.app.run_domain.service.turret(state,int(turret.id))
	if current.is_empty() or current.get(kind) != null: return
	if kind == "secondaryTrait" and current.get("primaryTrait") == null: return
	if int(current.level) < (3 if kind == "primaryTrait" else 7): return
	var quote: Dictionary = hud.app.run_domain.service.quotes(state,int(turret.id))
	if selected not in quote.get(kind+"s",[]) or int(state.gemShards) < int(quote[kind]): return
	var confirm: Button = hud.modal_body.find_child("TraitConfirm",true,false)
	if confirm != null: confirm.disabled = true
	hud._command({"kind":kind,"id":int(turret.id),"type":selected})
	hud.close_modal()

func _option_button(parent: Node,title: String,description: String,callback: Callable,selected = false) -> Button:
	var button = hud._button(parent,title+"\n"+description,callback)
	hud.Components.apply(button,"selected" if selected else "secondary")
	for role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		button.add_theme_color_override(role,Color.TRANSPARENT)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var content = VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",5); button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16; content.offset_right = -16; content.offset_top = 12; content.offset_bottom = -12
	var heading = hud._label(content,title,14); heading.add_theme_font_override("font",hud.AppTheme.font(800))
	heading.modulate = Color("ffe19a") if selected else Color.WHITE
	var detail = hud._label(content,description.replace(", ","\n"),12); detail.add_theme_font_override("font",hud.AppTheme.font(500)); detail.modulate = Color("b2c5d0")
	var fit = func(): button.custom_minimum_size.y = maxf(72,content.get_combined_minimum_size().y+24)
	content.minimum_size_changed.connect(fit); button.resized.connect(fit); fit.call_deferred()
	button.draw.connect(func(): content.modulate.a = 0.48 if button.disabled else 1.0)
	return button

func _priority() -> void:
	var box = hud.open_modal("공격 목표")
	var turret: Dictionary = hud.app.run_domain.service.turret(hud.app.run_domain.state,hud.app.run_domain.selected_id(hud.app.selected))
	for value in hud.PRIORITIES:
		var b = _option_button(box,hud.PRIORITIES[value],hud.PRIORITY_HELP[value],func(): hud._selected_command("targetPriority",{"type":value}); hud.close_modal(),str(turret.get("targetPriority","first")) == value)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._button(box,"취소",hud.close_modal)
