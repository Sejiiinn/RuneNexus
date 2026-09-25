extends RefCounted
## Turret stats, level preview, traits and target-priority presentation.
## Reads the live HUD owner; no selection, snapshot or cache copies.
const GemPalette = preload("res://ui/battle_rewards.gd")
const CATEGORY_NAMES := {"physical": "물리", "elemental": "원소", "light": "경량화기", "heavy": "중화기", "damageOverTime": "지속피해", "cooling": "냉각"}
const CATEGORY_GEMS := {"physical": "physicalDamage", "elemental": "elementalDamage", "light": "lightWeapon", "heavy": "heavyWeapon", "damageOverTime": "damageOverTime"}
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
		"level":"%d→%d" % [turret.level,int(turret.level)+1] if hud.app.selection_view.level_preview else "Lv.%d" % turret.level,
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
	var category_row := HBoxContainer.new(); category_row.name = "TurretCategoryAndTarget"; category_row.custom_minimum_size.y = 34
	category_row.add_theme_constant_override("separation",6); hud.body.add_child(category_row)
	var definition: Dictionary = hud.app.catalog.data.turrets[turret.type].configuration.statInput.definition
	_category_tag(category_row,str(definition.damageFamily))
	for tag in definition.get("attackTags",[]): _category_tag(category_row,str(tag))
	var category_spacer := Control.new(); category_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; category_row.add_child(category_spacer)
	if hud.configuration_cache.derived(state,hud.app.run_domain.service).get("canSetTurretTargetPriority",false):
		var priority = hud._button(category_row,"공격 목표 · "+hud.PRIORITIES.get(turret.get("targetPriority","first"),"선두")+"  ▾",_priority)
		priority.name = "TurretTargetPriority"
		priority.tooltip_text = "공격 목표 변경"
		priority.add_theme_font_size_override("font_size",11)
		priority.custom_minimum_size.y = 32
		for state_name in ["normal","hover","pressed","disabled","focus"]:
			var style: StyleBoxFlat = hud.HudChrome.quiet(state_name,true,Color("65c9df"),Vector2(7,4))
			priority.add_theme_stylebox_override(state_name,style)
	var stats = hud._stats(state,turret)
	var next = {}; var future = turret.duplicate(true); future.level += 1
	if hud.app.selection_view.level_preview: next = hud._stats(state,future)
	var stat_scroll = ScrollContainer.new(); stat_scroll.name = "TurretStatsScroll"; stat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; stat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; hud.body.add_child(stat_scroll)
	var grid = GridContainer.new(); grid.name = "TurretStatsGrid"; grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",22); grid.add_theme_constant_override("v_separation",0); stat_scroll.add_child(grid)
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
	for spec in specs:
		var cell = VBoxContainer.new(); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.name = "Stat_"+str(spec[1]); cell.add_theme_constant_override("separation",0); grid.add_child(cell)
		var row = HBoxContainer.new(); row.custom_minimum_size.y = 36; row.add_theme_constant_override("separation",4); cell.add_child(row)
		var title = hud._label(row,spec[0],12); title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.modulate = Color("a6bcc8")
		var values = VBoxContainer.new(); values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		values.size_flags_vertical = Control.SIZE_SHRINK_CENTER; values.add_theme_constant_override("separation",0); row.add_child(values)
		var changed: bool = not next.is_empty() and not is_equal_approx(float(stats[spec[1]]),float(next[spec[1]]))
		var current = hud._label(values,_stat_value(stats,spec[1]),12)
		current.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; current.autowrap_mode = TextServer.AUTOWRAP_OFF
		current.modulate = Color("91a6b2") if changed else Color("e8f8ff")
		if changed:
			var future_value = hud._label(values,"→ "+_stat_value(next,spec[1]),12)
			future_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; future_value.autowrap_mode = TextServer.AUTOWRAP_OFF
			future_value.modulate = Color("8ee6ff")
		cell.tooltip_text = spec[0]+" · "+_stat_value(stats,spec[1])+(" → "+_stat_value(next,spec[1]) if changed else "")
		var divider := HSeparator.new(); divider.modulate = Color("70919d66"); cell.add_child(divider)
	# GridContainer's minimum is stale until its first layout pass. Every pair
	# occupies one 36 px value row plus its separator and breathing room.
	stat_scroll.custom_minimum_size.y = minf(ceilf(float(specs.size())/2.0)*40.0,260.0)
	var total_line := HSeparator.new(); total_line.modulate = Color("70919d88"); hud.body.add_child(total_line)
	var total := HBoxContainer.new(); total.name = "TurretTotalDamage"; total.custom_minimum_size.y = 34
	total.add_theme_constant_override("separation",8); hud.body.add_child(total)
	hud._label(total,"누적 피해",12).modulate = Color("a6bcc8")
	hud.damage_label = hud._label(total,"0.0",12); hud.damage_label.name = "TurretTotalDamageValue"
	hud.damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hud.damage_label.autowrap_mode = TextServer.AUTOWRAP_OFF

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
	var box: VBoxContainer = hud.open_modal(hud.TOWERS.get(turret.type,turret.type)+" 특성",410,false,true,Color("63e6a5"),"reward")
	box.add_theme_constant_override("separation",10)
	var wallet := HBoxContainer.new(); wallet.name = "TraitWallet"; wallet.custom_minimum_size.y = 28
	wallet.add_theme_constant_override("separation",7); box.add_child(wallet)
	hud._icon(wallet,"ui/hud/icons/shard.png",22)
	var wallet_title: Label = hud._label(wallet,"보유 파편",12)
	wallet_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wallet_title.custom_minimum_size.x = 55; wallet_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet_title.modulate = Color("b7d5e3")
	var wallet_amount: Label = hud._label(wallet,"%d" % int(hud.app.run_domain.state.gemShards),15)
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
			_traits(turret,q,tier))
	if not blocked.is_empty():
		var reason: Label = hud._label(box,blocked,11); reason.name = "TraitBlockedReason"
		reason.modulate = Color("ffa68a")
	var confirm: Button = hud._button(box,"",func(): _confirm_trait(turret,kind))
	confirm.name = "TraitConfirm"; confirm.custom_minimum_size.y = 52
	confirm.disabled = not blocked.is_empty() or hud.trait_preview not in options
	hud.Components.apply(confirm,"primary")
	var confirm_center := CenterContainer.new(); confirm_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.add_child(confirm_center); confirm_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var confirm_row := HBoxContainer.new(); confirm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var confirm_cost: Label = hud._label(confirm_row,"%d" % cost,16)
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
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("123549ef") if selected else Color("0b2030e8")
		style.border_color = Color("42e4f3") if selected else Color("355a6b")
		if state_name == "hover" and not locked: style.bg_color = Color("1a3d50")
		style.set_border_width_all(2 if selected else 1); style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state_name,style)
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
	var ring := StyleBoxFlat.new(); ring.bg_color = Color("092131")
	ring.border_color = Color("42e4f3") if selected else Color("a3c2d5")
	ring.set_border_width_all(2); ring.set_corner_radius_all(12); ring.set_content_margin_all(4)
	radio.add_theme_stylebox_override("panel",ring); row.add_child(radio)
	if selected:
		var center := CenterContainer.new(); center.mouse_filter = Control.MOUSE_FILTER_IGNORE; radio.add_child(center)
		var dot := PanelContainer.new(); dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(10,10); center.add_child(dot)
		var fill := StyleBoxFlat.new(); fill.bg_color = Color("42e4f3"); fill.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel",fill)
	if locked and not selected: content.modulate.a = 0.52
	# A Button does not inherit the minimum of its decorative children. Bridge
	# the native container minimum without estimating text lines or frame timing.
	var fit := _fit_trait_row.bind(button,content,126.0 if compact else 110.0)
	content.minimum_size_changed.connect(fit,CONNECT_DEFERRED)
	button.resized.connect(fit,CONNECT_DEFERRED)
	fit.call_deferred()

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
	hud._selected_command(kind,{"type":selected})
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
