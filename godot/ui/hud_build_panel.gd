extends RefCounted
## Construction picker and run-upgrade presentation. Prices remain domain-owned.
## Reads the live HUD owner; no selection, snapshot or cache copies.
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _build(state: Dictionary) -> void:
	var tile = hud._selected_tile()
	if tile in ["core","spawn"]: hud.menu_panel._board_detail(tile,state); return
	var available: Array = hud.configuration_cache.derived(state,hud.app.run_domain.service).get("availableTurretTypes",[])
	if hud.app.turret_type not in available and not available.is_empty():
		hud.app.turret_type = available[0]
		hud.app.refresh_selection()
	var type = str(hud.app.turret_type)
	var cost: int = hud.app.run_domain.service.build_cost(state,type)
	if tile == "build":
		var heading = HBoxContainer.new(); hud.body.add_child(heading)
		hud._label(heading,hud.TOWERS.get(type,type)+" 포탑",14)
		var install = hud._button(heading,"설치 · %d 골드" % cost,func(): hud.app.build_selected(); hud.refresh())
		hud._track_purchase_button(install,"gold",cost,tile != "build")
		hud._label(hud.body,hud.DESCRIPTIONS.get(type,""),11)
		var definition: Dictionary = hud.app.catalog.data.turrets[type].configuration.statInput.definition
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
		var b = hud._button(row,"%s\n%d" % [hud.TOWERS[kind],hud.app.run_domain.service.build_cost(state,kind)],func():
			if hud.app.turret_type == kind and hud._selected_tile() == "build": hud.app.build_selected()
			else: hud.app.turret_type = kind; hud.app.refresh_selection()
			hud.refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.add_theme_font_size_override("font_size",10)
		b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0,78)
		# Explicit vertical content avoids Button icon/text width arbitration.
		for color_role in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: b.add_theme_color_override(color_role,Color.TRANSPARENT)
		var content = VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_theme_constant_override("separation",0); b.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); content.offset_top = 4; content.offset_bottom = -4; content.offset_left = 2; content.offset_right = -2
		var art = hud._icon(content,"ui/hud/turrets_3d/"+kind+".png",40); art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label = hud._label(content,hud.TOWERS[kind],10); name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; name_label.autowrap_mode = TextServer.AUTOWRAP_OFF; name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var price_label = hud._label(content,"%d G" % hud.app.run_domain.service.build_cost(state,kind),9); price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		for style in ["normal","hover","pressed","disabled","focus"]:
			b.add_theme_stylebox_override(style,hud.HudChrome.quiet(style,type == kind,Color("e7c66a"),Vector2(3,3)))
		b.toggle_mode = true; b.button_pressed = type == kind

func _upgrades(state: Dictionary) -> void:
	for type in hud.UPGRADES:
		var q: Dictionary = hud.app.run_domain.service.run_upgrade_quote(state,type)
		var values: Array = hud.app.run_domain.growth.data.runUpgrades[type].effects
		var current = float(values[mini(int(q.level),values.size()-1)])
		var next = float(values[mini(int(q.level)+1,values.size()-1)])
		var row = HBoxContainer.new(); hud.body.add_child(row)
		var effect = "+%.0f → +%.0f 골드" % [current,next] if type == "waveGold" else "+%.0f%% → +%.0f%%" % [current*100,next*100]
		hud._label(row,"%s  Lv.%d/%d\n%s" % [hud.UPGRADES[type],q.level,q.maxLevel,effect],12)
		var b = hud._button(row,"%d 골드" % q.cost if int(q.cost)>0 else "최대",func(): hud._command({"kind":"runUpgrade","type":type}))
		hud._track_purchase_button(b,"gold",int(q.cost),int(q.cost)<=0)
