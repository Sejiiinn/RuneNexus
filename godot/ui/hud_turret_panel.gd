extends RefCounted
## Turret stats, level preview, traits and target-priority presentation.
## Reads the live HUD owner; no selection, snapshot or cache copies.
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _turret(state: Dictionary,turret: Dictionary) -> void:
	var q: Dictionary = hud.app.run_domain.service.quotes(state,int(turret.id))
	var active_tab = "stats" if hud.app.selection_view.level_preview else hud.tab
	var panel = preload("res://ui/turret_action_panel.gd").new()
	hud.body.add_child(panel)
	panel.configure({
		"title":hud.TOWERS.get(turret.type,turret.type),"icon":"ui/hud/turrets_3d/"+turret.type+".png",
		"level":"Lv.%d%s" % [turret.level," → %d" % (int(turret.level)+1) if hud.app.selection_view.level_preview else ""],
		"upgrade_title":"강화 확정" if hud.app.selection_view.level_preview else "강화",
		"price":"최대 레벨" if int(q.level)<=0 else "%d G" % q.level,"maximum":int(q.level)<=0,
		"trait_count":int(turret.get("primaryTrait") != null)+int(turret.get("secondaryTrait") != null),
		"active_tab":active_tab,"upgrade_callback":_preview_level,
		"trait_callback":func(): _traits(turret,q),"sell_callback":func(): _sell_confirm(turret,q),
		"stats_callback":func(): hud.tab = "stats"; hud.refresh(),"gems_callback":func(): hud.tab = "gems"; hud.refresh(),
	})
	hud._track_purchase_button(panel.level_action,"gold",int(q.level),int(q.level)<=0)
	panel.level_action.tooltip_text = ("강화 확정" if hud.app.selection_view.level_preview else "다음 레벨 능력치 미리보기")+(" · %d G" % q.level if int(q.level)>0 else "")
	panel.trait_action.tooltip_text = "특성 확인 및 선택"
	panel.sell_action.tooltip_text = "판매 · +%d G · 금액 확인" % q.sell
	if active_tab == "gems": hud.gem_panel._gems(state,turret,q); return
	var damage_row = HBoxContainer.new(); hud.body.add_child(damage_row)
	hud._label(damage_row,"물리 · 경량화기" if turret.type == "arrow" else ("원소" if turret.type in ["magic","frost","lightning"] else "물리 · 중화기"),11)
	if hud.configuration_cache.derived(state,hud.app.run_domain.service).get("canSetTurretTargetPriority",false):
		var priority = hud._button(damage_row,"목표 · "+hud.PRIORITIES.get(turret.get("targetPriority","first"),"선두")+" ▾",_priority)
		priority.tooltip_text = "공격 목표 변경"
		priority.add_theme_font_size_override("font_size",11)
		priority.custom_minimum_size.y = 30
		hud._style_hud_button(priority,"quiet",false,Vector2(6,4))
	hud.damage_label = hud._label(damage_row,"",10); hud.damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.damage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var stats = hud._stats(state,turret)
	var next = {}; var future = turret.duplicate(true); future.level += 1
	if hud.app.selection_view.level_preview: next = hud._stats(state,future)
	var stat_scroll = ScrollContainer.new(); stat_scroll.name = "TurretStatsScroll"; stat_scroll.custom_minimum_size.y = 96; stat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; stat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; hud.body.add_child(stat_scroll)
	var grid = GridContainer.new(); grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",16); grid.add_theme_constant_override("v_separation",0); stat_scroll.add_child(grid)
	stats.dps = hud._dps(stats,turret.type)
	if not next.is_empty(): next.dps = hud._dps(next,turret.type)
	var specs = [["피해","damage"],["DPS","dps"],["공격 속도","attackRate"],["사거리","range"],["치명 확률","criticalChance"],["치명 피해","criticalDamageMultiplier"]]
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
	for spec in specs:
		var cell = VBoxContainer.new(); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation",0); grid.add_child(cell)
		var row = HBoxContainer.new(); row.custom_minimum_size.y = 30; row.add_theme_constant_override("separation",4); cell.add_child(row)
		var title = hud._label(row,spec[0],11); title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.modulate = Color("a6bcc8")
		var values = VBoxContainer.new(); values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		values.size_flags_vertical = Control.SIZE_SHRINK_CENTER; values.add_theme_constant_override("separation",0); row.add_child(values)
		var changed: bool = not next.is_empty() and not is_equal_approx(float(stats[spec[1]]),float(next[spec[1]]))
		var current = hud._label(values,_stat_value(stats,spec[1]),10 if changed else 13)
		current.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; current.autowrap_mode = TextServer.AUTOWRAP_OFF
		current.modulate = Color("91a6b2") if changed else Color("e8f8ff")
		if changed:
			var future_value = hud._label(values,"→ "+_stat_value(next,spec[1]),12)
			future_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; future_value.autowrap_mode = TextServer.AUTOWRAP_OFF
			future_value.modulate = Color("8ee6ff")
		cell.tooltip_text = spec[0]+" · "+_stat_value(stats,spec[1])+(" → "+_stat_value(next,spec[1]) if changed else "")
		cell.add_child(HSeparator.new())

func _stat_value(stats: Dictionary,key: String) -> String:
	if key == "slowMultiplier": return "%.0f%%" % ((1.0-float(stats[key]))*100)
	if key in ["criticalChance","criticalDamageMultiplier","effectAreaMultiplier"]: return "%.0f%%" % (float(stats[key])*100)
	if key == "range": return "%.2f칸" % (float(stats[key])/48.0)
	if key == "attackRate": return "%.2f회/초" % float(stats[key])
	if key in ["aimDuration","slowDuration","burnDuration"]: return "%.2f초" % float(stats[key])
	if key == "projectileCount": return "%d발" % int(stats[key])
	if key == "chainCount": return "%d회" % int(stats[key])
	return "%.1f" % float(stats[key])

func _preview_level() -> void:
	if hud.app.selection_view.level_preview:
		hud.app.selection_view.level_preview = false; hud._selected_command("level")
	else:
		hud.app.selection_view.level_preview = true; hud.app.refresh_selection(); hud.refresh()

func _sell_confirm(turret: Dictionary,q: Dictionary) -> void:
	var box = hud.open_modal("포탑 판매")
	hud._label(box,"%s Lv.%d 포탑을 판매할까요?\n%d 골드를 돌려받고 장착 젬은 보관함으로 돌아갑니다." % [hud.TOWERS.get(turret.type,turret.type),turret.level,q.sell],13)
	hud.Components.apply(hud._button(box,"판매 · +%d 골드" % q.sell,func(): hud._selected_command("sell"); hud.close_modal()),"danger")
	hud._button(box,"취소",hud.close_modal)

func _traits(turret: Dictionary,q: Dictionary,tier: int = 0) -> void:
	if tier == 0: tier = 2 if turret.get("primaryTrait") != null else 1
	var box = hud.open_modal(hud.TOWERS.get(turret.type,turret.type)+" 특성",390,false,true,Color("63e6a5"),"reward")
	var wallet = HBoxContainer.new(); box.add_child(wallet)
	hud._icon(wallet,"ui/hud/icons/shard.png",15)
	hud._label(wallet,"%d  ·  1차 %d / 2차 %d" % [hud.app.run_domain.state.gemShards,q.primaryTrait,q.secondaryTrait],11)
	var tabs = HBoxContainer.new(); tabs.add_theme_constant_override("separation",0); box.add_child(tabs)
	for value in [1,2]:
		var chosen_trait = turret.get("primaryTrait" if value == 1 else "secondaryTrait")
		var name: String = str(hud.labels.traitNames.get(chosen_trait,"무기 개조" if value == 1 else "전투 교리"))
		var button = hud._button(tabs,"%d차 · %s" % [value,name],func(): hud.trait_preview = ""; _traits(turret,q,value))
		button.toggle_mode = true; button.button_pressed = value == tier; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud._style_hud_button(button,"secondary",value == tier,Vector2(8,8),true)
		button.disabled = q.get("primaryTraits" if value == 1 else "secondaryTraits",[]).is_empty()
	var kind = "primaryTrait" if tier == 1 else "secondaryTrait"
	var required = 3 if tier == 1 else 7
	hud._label(box,"%d차 · %s" % [tier,"무기 개조" if tier == 1 else "전투 교리"],13)
	if turret.get(kind) != null:
		hud._label(box,str(hud.labels.traitNames.get(turret[kind],turret[kind]))+"\n"+str(hud.labels.traitDescriptions.get(turret[kind],"")),12)
	else:
		var blocked = ""
		if tier == 2 and turret.get("primaryTrait") == null: blocked = "2차 특성은 1차 특성을 먼저 선택해야 합니다."
		elif int(turret.level)<required: blocked = "%d차 특성은 Lv.%d부터 선택할 수 있습니다." % [tier,required]
		elif int(hud.app.run_domain.state.gemShards)<int(q[kind]): blocked = "젬 파편이 %d개 부족합니다." % (int(q[kind])-int(hud.app.run_domain.state.gemShards))
		if not blocked.is_empty(): hud._label(box,blocked,11).modulate = Color("ffa68a")
		if q[kind+"s"].is_empty(): hud._label(box,"선택 가능한 특성이 없습니다.",12)
		for value in q[kind+"s"]:
			var button = _option_button(box,("✓ " if hud.trait_preview == value else "")+str(hud.labels.traitNames.get(value,value)),str(hud.labels.traitDescriptions.get(value,"")),func():
				if hud.trait_preview == value: hud._selected_command(kind,{"type":value}); hud.close_modal()
				else: hud.trait_preview = value; _traits(turret,q,tier),hud.trait_preview == value)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.disabled = not blocked.is_empty()
	hud._label(box,"선택한 특성은 이번 런 동안 변경할 수 없습니다.",10)

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
