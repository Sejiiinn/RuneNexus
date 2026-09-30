extends RefCounted
## Construction picker and run-upgrade presentation. Prices remain domain-owned.
## Reads the live HUD owner; no selection, snapshot or cache copies.
const HudNumber = preload("res://ui/hud_number.gd")
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _build(state: Dictionary) -> void:
	var tile = hud._selected_tile()
	if tile in ["core","spawn"]: hud.menu_panel._board_detail(tile,state); return
	var configuration: Dictionary = hud.configuration_cache.derived(state,hud.app.run_domain.service)
	var available: Array = configuration.get("availableTurretTypes",[])
	var costs := {}
	for kind in available:
		costs[kind] = hud.app.run_domain.service.build_cost_from_derived(str(kind),configuration)
	if hud.app.turret_type not in available and not available.is_empty():
		hud.app.turret_type = available[0]
		hud.app.refresh_selection()
	var type = str(hud.app.turret_type)
	var cost: int = costs[type] if costs.has(type) else hud.app.run_domain.service.build_cost_from_derived(type,configuration)
	if tile == "build":
		var heading = HBoxContainer.new(); hud.body.add_child(heading)
		hud._label(heading,hud.TOWERS.get(type,type)+" 포탑",14)
		var install = hud._button(heading,"설치 · %s 골드" % HudNumber.compact_price(cost),func(): hud.app.build_selected(); hud.refresh())
		hud._track_purchase_button(install,"gold",cost,tile != "build")
		install.tooltip_text = "설치 · %d 골드" % cost
		hud._label(hud.body,hud.DESCRIPTIONS.get(type,""),11)
		var definition: Dictionary = hud.app.catalog.turret_definition(type)
		hud._label(hud.body,("물리" if definition.damageFamily == "physical" else "원소")+" · "+str({"arrow":"경량화기","cannon":"중화기 · 폭발","magic":"지속 피해","frost":"감속","sniper":"중화기 · 조준","lightning":"연쇄"}.get(type,"")),10)
		var stats = hud._stats(state,{"type":type,"level":1,"equippedGemSlots":[],"primaryTrait":null,"secondaryTrait":null})
		hud._label(hud.body,"피해 %.1f     초당 %.2f회     사거리 %.0f" % [stats.damage,stats.attackRate,stats.range],11)
	var picker_scroll = ScrollContainer.new(); picker_scroll.name = "TurretPicker"
	picker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	picker_scroll.custom_minimum_size.y = 78; hud.body.add_child(picker_scroll)
	var row = HBoxContainer.new(); row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_theme_constant_override("separation",0); picker_scroll.add_child(row)
	for kind in hud.TOWERS:
		if kind not in available: continue
		if row.get_child_count() > 0: row.add_child(hud.HudChrome.divider())
		var b = hud._button(row,"%s\n%s" % [hud.TOWERS[kind],HudNumber.compact_price(costs[kind])],func():
			if hud.app.turret_type == kind and hud._selected_tile() == "build": hud.app.build_selected()
			else: hud.app.turret_type = kind; hud.app.refresh_selection()
			hud.refresh())
		b.tooltip_text = "%s · %d G" % [hud.TOWERS[kind],costs[kind]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.add_theme_font_size_override("font_size",10)
		b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0,78)
		# Explicit vertical content avoids Button icon/text width arbitration.
		for color_role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: b.add_theme_color_override(color_role,Color.TRANSPARENT)
		var content = VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_theme_constant_override("separation",0); b.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); content.offset_top = 4; content.offset_bottom = -4; content.offset_left = 2; content.offset_right = -2
		var art = hud._icon(content,"ui/hud/turrets_3d/"+kind+".png",40); art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label = hud._label(content,hud.TOWERS[kind],10); name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; name_label.autowrap_mode = TextServer.AUTOWRAP_OFF; name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var price_label = hud._label(content,HudNumber.compact_price(costs[kind])+" G",9); price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		for style in ["normal","hover","pressed","disabled","focus"]:
			b.add_theme_stylebox_override(style,hud.HudChrome.quiet(style,type == kind,Color("e7c66a"),Vector2(3,3)))
		b.toggle_mode = true; b.button_pressed = type == kind

func _upgrades(state: Dictionary) -> void:
	var compact := hud.get_viewport_rect().size.x < 380
	var rows := VBoxContainer.new()
	rows.name = "RunUpgradeRows"
	rows.add_theme_constant_override("separation",0)
	hud.body.add_child(rows)
	var icons := {"towerDamage":"tower_damage","killGold":"kill_gold","waveGold":"wave_gold"}
	var descriptions := {"towerDamage":"모든 포탑 피해","killGold":"적 처치 골드","waveGold":"웨이브 종료 골드"}
	for type in hud.UPGRADES:
		if rows.get_child_count() > 0:
			var divider := HSeparator.new()
			var line := StyleBoxLine.new()
			line.color = Color("52708088"); line.thickness = 1
			divider.add_theme_stylebox_override("separator",line)
			divider.add_theme_constant_override("separation",5)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rows.add_child(divider)
		var q: Dictionary = hud.app.run_domain.service.run_upgrade_quote(state,type)
		var values: Array = hud.app.run_domain.growth.data.runUpgrades[type].effects
		var current = float(values[mini(int(q.level),values.size()-1)])
		var next = float(values[mini(int(q.level)+1,values.size()-1)])
		var at_max := int(q.level) >= int(q.maxLevel)
		var row := HBoxContainer.new()
		row.name = "Upgrade_"+str(type)
		row.custom_minimum_size.y = 60
		row.add_theme_constant_override("separation",7 if compact else 10)
		rows.add_child(row)
		var icon_slot := CenterContainer.new()
		icon_slot.name = "UpgradeIcon"
		icon_slot.custom_minimum_size.x = 60 if compact else 90
		icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_slot)
		var icon: TextureRect = hud._icon(icon_slot,"upgrades/"+str(icons[type])+".png",54 if compact else 62)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_constant_override("separation",1)
		row.add_child(info)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation",5 if compact else 10)
		info.add_child(heading)
		var title := _upgrade_label(heading,str(hud.UPGRADES[type]),12 if compact else 14,"UpgradeName")
		title.add_theme_font_override("font",hud.AppTheme.font(900))
		var level := _upgrade_label(heading,"Lv.%d/%d" % [q.level,q.maxLevel],10 if compact else 11,"UpgradeLevel")
		level.add_theme_color_override("font_color",Color("9ab8c8"))
		level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_upgrade_label(info,str(descriptions[type]),10 if compact else 11,"UpgradeDescription").add_theme_color_override("font_color",Color("9ab8c8"))
		var effects := HBoxContainer.new()
		effects.add_theme_constant_override("separation",8 if compact else 12)
		info.add_child(effects)
		_upgrade_label(effects,_upgrade_value(type,current),12 if compact else 13,"UpgradeCurrent")
		var arrow := _upgrade_label(effects,"→",12,"UpgradeArrow")
		arrow.add_theme_color_override("font_color",Color("8ba9ba")); arrow.visible = not at_max
		var next_label := _upgrade_label(effects,_upgrade_value(type,next),12 if compact else 13,"UpgradeNext")
		next_label.add_theme_color_override("font_color",Color("43e2ed")); next_label.visible = not at_max
		var b: Button = hud._button(row,"",func(): hud._command({"kind":"runUpgrade","type":type}))
		b.name = "Purchase"
		b.custom_minimum_size = Vector2(84 if compact else 118,54)
		for button_state in ["normal","hover","pressed","disabled","focus"]:
			b.add_theme_stylebox_override(button_state,hud.HudChrome.primary(button_state))
		b.tooltip_text = str(hud.UPGRADES[type])+" · "+("최대 레벨" if at_max else "%d 골드로 구매" % q.cost)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation",1)
		b.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 5; content.offset_right = -5
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		var action := _upgrade_label(content,"최대" if at_max else "구매",12 if compact else 13,"PurchaseAction")
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var price := HBoxContainer.new(); price.name = "PurchasePriceRow"
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price.alignment = BoxContainer.ALIGNMENT_CENTER; price.visible = not at_max
		price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		price.add_theme_constant_override("separation",4)
		content.add_child(price)
		var coin: TextureRect = hud._icon(price,"ui/hud/icons/gold.png",16 if compact else 18)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var price_label := _upgrade_label(price,HudNumber.compact_price(q.cost),12 if compact else 14,"PurchasePrice")
		price_label.add_theme_color_override("font_color",Color("f1ce67"))
		price_label.tooltip_text = "%d G" % q.cost
		price_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Decorative Button children do not propagate their minimum height.
		var fit := func():
			if not is_instance_valid(b): return
			var text_width := price_label.get_theme_font("font").get_string_size(price_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,price_label.get_theme_font_size("font_size")).x
			price.custom_minimum_size.x = minf(maxf(1,b.size.x-10),text_width+coin.custom_minimum_size.x+4)
			b.custom_minimum_size.y = maxf(54,content.get_combined_minimum_size().y+8)
		content.minimum_size_changed.connect(fit,CONNECT_DEFERRED)
		b.resized.connect(fit,CONNECT_DEFERRED)
		fit.call_deferred()
		b.set_meta("action_content",content)
		hud._track_purchase_button(b,"gold",int(q.cost),at_max)

func _update_upgrades(state: Dictionary) -> void:
	var rows: VBoxContainer = hud.body.get_node("RunUpgradeRows")
	for type in hud.UPGRADES:
		var row: HBoxContainer = rows.get_node("Upgrade_"+str(type))
		var q: Dictionary = hud.app.run_domain.service.run_upgrade_quote(state,type)
		var values: Array = hud.app.run_domain.growth.data.runUpgrades[type].effects
		var at_max := int(q.level) >= int(q.maxLevel)
		(row.find_child("UpgradeLevel",true,false) as Label).text = "Lv.%d/%d" % [q.level,q.maxLevel]
		(row.find_child("UpgradeCurrent",true,false) as Label).text = _upgrade_value(type,float(values[mini(int(q.level),values.size()-1)]))
		(row.find_child("UpgradeNext",true,false) as Label).text = _upgrade_value(type,float(values[mini(int(q.level)+1,values.size()-1)]))
		row.find_child("UpgradeNext",true,false).visible = not at_max
		row.find_child("UpgradeArrow",true,false).visible = not at_max
		var b: Button = row.get_node("Purchase")
		(b.find_child("PurchaseAction",true,false) as Label).text = "최대" if at_max else "구매"
		(b.find_child("PurchasePrice",true,false) as Label).text = HudNumber.compact_price(q.cost)
		(b.find_child("PurchasePrice",true,false) as Label).tooltip_text = "%d G" % q.cost
		b.find_child("PurchasePriceRow",true,false).visible = not at_max
		b.tooltip_text = str(hud.UPGRADES[type])+" · "+("최대 레벨" if at_max else "%d 골드로 구매" % q.cost)
		hud._track_purchase_button(b,"gold",int(q.cost),at_max)

func _upgrade_label(parent: Node,text: String,size: int,node_name: String) -> Label:
	var label: Label = hud._label(parent,text,size)
	label.name = node_name
	label.add_theme_color_override("font_color",Color("e8f8ff"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label

func _upgrade_value(type: String,value: float) -> String:
	return "+%.0f G" % value if type == "waveGold" else "+%.0f%%" % (value*100)
