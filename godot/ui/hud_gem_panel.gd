extends RefCounted
## Equipped sockets and inventory presentation; commands route through the HUD.
## Reads the live HUD owner; no selection, snapshot or cache copies.
var hud: Control

func _init(owner: Control) -> void:
	hud = owner

func _gems(state: Dictionary,turret: Dictionary,q: Dictionary) -> void:
	var max_slots = int(hud.configuration_cache.derived(state,hud.app.run_domain.service).get("maxTurretLinkSlots",3))
	var socket_rows = VBoxContainer.new(); socket_rows.name = "EquippedSocketRows"; socket_rows.add_theme_constant_override("separation",6); hud.body.add_child(socket_rows)
	var sockets: HBoxContainer
	for i in range(int(turret.slotLimit)):
		if i % 3 == 0:
			sockets = HBoxContainer.new(); sockets.add_theme_constant_override("separation",0); socket_rows.add_child(sockets)
		else:
			var link = TextureRect.new(); link.texture = hud.AppTheme.texture("ui/components/gem_link_active.png"); link.custom_minimum_size = Vector2(12,12); link.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; link.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; sockets.add_child(link)
		var socket = hud._button(sockets,"",func(): hud.selected_slot = i; hud.selected_gem = ""; hud.refresh())
		socket.name = "EquippedSlot%d" % i; socket.custom_minimum_size = Vector2(54,54)
		for style in ["normal","hover","pressed","disabled","focus"]: socket.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		var file = "gem_socket_selected.png" if i == hud.selected_slot else "gem_socket_empty.png"
		socket.icon = hud.AppTheme.texture("ui/components/"+file); socket.expand_icon = true
		var gem = turret.equippedGemSlots[i]
		if gem != null:
			var icon = TextureRect.new(); icon.texture = hud.AppTheme.texture("gems/"+str(gem)+".png"); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; socket.add_child(icon); icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.offset_left = 9; icon.offset_right = -9; icon.offset_top = 9; icon.offset_bottom = -9
	var link_cost = int(q.get("link",0))
	var buy_caption = "슬롯 추가 · %d G" % link_cost if link_cost > 0 else ("최대 슬롯입니다" if int(turret.slotLimit) >= max_slots else "슬롯 추가 · 포탑 Lv.5 필요")
	var buy_slot = hud._button(hud.body,buy_caption,func(): hud._selected_command("link"))
	buy_slot.name = "BuyGemSlot"
	hud._track_purchase_button(buy_slot,"gold",link_cost,int(turret.slotLimit) >= max_slots or link_cost <= 0)
	if hud.selected_slot < 0: hud._label(hud.body,"장착할 소켓을 선택하세요.",11)
	elif hud.selected_slot < turret.equippedGemSlots.size() and turret.equippedGemSlots[hud.selected_slot] != null:
		var equipped = str(turret.equippedGemSlots[hud.selected_slot])
		var equipped_row = HBoxContainer.new(); hud.body.add_child(equipped_row)
		var equipped_text = VBoxContainer.new(); equipped_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; equipped_row.add_child(equipped_text)
		hud._label(equipped_text,_gem_name(equipped)+" · "+_gem_effect(equipped,turret),11)
		_gem_rule(equipped_text,equipped)
		hud._button(equipped_row,"해제",func(): hud._selected_command("removeGem",{"slot":hud.selected_slot}))
	_inventory_strip(hud.body,state,turret)
	if hud.selected_gem != "" and int(state.gemInventory.get(hud.selected_gem,0))>0:
		var selected_row = HBoxContainer.new(); hud.body.add_child(selected_row)
		var detail = VBoxContainer.new(); detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; selected_row.add_child(detail)
		hud._label(detail,_gem_name(hud.selected_gem)+" · "+_gem_effect(hud.selected_gem,turret),11)
		_gem_rule(detail,hud.selected_gem)
		var reason = _gem_block_reason(hud.selected_gem,turret)
		if not reason.is_empty(): hud._label(detail,reason,10).modulate = Color("ffa68a")
		var install = hud._button(selected_row,"장착",func(): hud._selected_command("equipGem",{"type":hud.selected_gem,"slot":hud.selected_slot}); hud.selected_gem = ""; hud.refresh())
		install.disabled = not reason.is_empty()

func _inventory_strip(parent: Node,state: Dictionary,turret: Dictionary = {}) -> void:
	var inv_scroll = ScrollContainer.new(); inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; parent.add_child(inv_scroll)
	var inventory = HBoxContainer.new(); inv_scroll.add_child(inventory)
	for type in state.gemInventory:
		if int(state.gemInventory[type]) <= 0: continue
		var b = hud._button(inventory,"%s ×%d" % [_gem_name(type),state.gemInventory[type]],func():
			if hud.selected_gem == type and not turret.is_empty() and _gem_block_reason(type,turret).is_empty(): hud._selected_command("equipGem",{"type":type,"slot":hud.selected_slot}); hud.selected_gem = ""
			else: hud.selected_gem = type
			hud.refresh())
		b.icon = hud.AppTheme.texture("gems/"+type+".png"); b.expand_icon = true; b.add_theme_constant_override("icon_max_width",30); b.toggle_mode = true; b.button_pressed = hud.selected_gem == type
		if not turret.is_empty():
			b.disabled = state.phase not in ["preparation","wave"]
			b.tooltip_text = _gem_block_reason(type,turret)
	if inventory.get_child_count() == 0: hud._label(parent,"보유 젬이 없습니다.",12)

func _inventory(state: Dictionary) -> void:
	var heading = HBoxContainer.new(); hud.body.add_child(heading); hud._label(heading,"젬 보관함",14); _purchase(heading,state)
	var owned = []
	for type in hud.app.run_domain.growth.data.gems:
		if int(state.gemInventory.get(type,0))>0: owned.append(type)
	if owned.is_empty():
		hud._label(hud.body,"보유한 젬이 없습니다. 5라운드 보상 또는 파편 구매로 젬을 획득하세요.",11)
		return
	hud._label(hud.body,"보유 젬",11)
	var wrap = HFlowContainer.new(); wrap.add_theme_constant_override("h_separation",6); wrap.add_theme_constant_override("v_separation",6); hud.body.add_child(wrap)
	for type in owned:
		var accent = Color(str(hud.rewards.GEM_COLORS.get(type,"69D7FF")))
		var panel = PanelContainer.new(); panel.add_theme_stylebox_override("panel",hud.BattleTheme.box(Color(accent,0.12),Color(accent,0.55),7)); wrap.add_child(panel)
		var card = VBoxContainer.new(); panel.add_child(card)
		var title = HBoxContainer.new(); card.add_child(title)
		hud._icon(title,"gems/"+type+".png",14)
		hud._label(title,"%s x%d" % [_gem_name(type),state.gemInventory[type]],11)
		var effect = hud._label(card,_gem_inventory_effect(type),10); effect.custom_minimum_size.x = 112
		_gem_rule(card,type)

func _purchase(parent: Node,state: Dictionary) -> void:
	var cost: int = hud.app.run_domain.growth.data.constants.gemChoicePurchaseCost
	var b = hud._button(parent,"젬 구매 · %d 조각" % cost,func(): hud._command({"kind":"purchaseGemChoice"}))
	hud._track_purchase_button(b,"gemShards",cost,state.phase not in ["preparation","wave"])

func _gem_name(type: String) -> String:
	return str(hud.labels.gems.get(type,{}).get("name",type))

func _gem_description(type: String) -> String:
	var gem: Dictionary = hud.labels.gems.get(type,{})
	return str(gem.get("description",""))

func _gem_rule(parent: Node,type: String) -> void:
	if hud.rewards.RULES.has(type):
		var note = hud._label(parent,"("+str(hud.rewards.RULES[type])+")",10)
		note.modulate = Color("939aa4"); note.custom_minimum_size.x = 200

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
	return {"lightWeapon":"경량화기 강화","damageOverTime":"지속피해 증가","multipleProjectiles":"투사체 +2\n피해 50% 감폭"}.get(type,_gem_description(type))
