extends "res://verify_battle_hud.gd"
## Isolated UI contract regression using actual run transactions, never player saves.
var fixture
var panel

func run() -> void:
	root.content_scale_size = Vector2i(440,880)
	root.size = Vector2i(440,880)
	fixture = App.new()
	assert(fixture.catalog.load_catalog())
	assert(fixture.run_domain.initialize(fixture.catalog,{},0,100))
	root.add_child(fixture)
	panel = load("res://ui/battle_hud.gd").new()
	panel.app = fixture; fixture.hud = panel; root.add_child(panel)
	await settle()
	fixture.run_domain.state.gold = 100000
	var map: Dictionary = fixture.catalog.stage(0).map
	var index: int = map.tiles.find("build")
	fixture.selected = Vector2i(index % int(map.columns),index / int(map.columns))
	fixture.build_selected()
	panel.main_tab = "turrets"; panel.tab = "gems"; panel.refresh()
	await settle()
	if "--empty-only" in OS.get_cmdline_user_args():
		await check_empty_inventory()
		print("PASS responsive turret inventory: owned 0/1/6/14 at 320/440, fixed square cells filling row, noninteractive blanks, overflow scrolling; global empty help preserved")
		panel.queue_free(); fixture.queue_free(); await process_frame; quit(); return
	if "--unlock-only" in OS.get_cmdline_user_args():
		await check_popup_unlock()
		print("PASS unified unlock plate: one price/metal frame, no stem, stationary inventory, actual pointer purchase/outside dismissal, 3-6 slots at 320/440")
		panel.queue_free(); fixture.queue_free(); await process_frame; quit(); return
	if "--layout-only" in OS.get_cmdline_user_args():
		await check_changed_layout()
		print("PASS gem UI changed layout: dock/body viewport bounds, same six-socket nodes resized 440 to 320, 12x8 connectors, primary unlock, 34px inventory in 3/2 columns")
		panel.queue_free(); fixture.queue_free(); await process_frame; quit(); return
	if "--strip-only" in OS.get_cmdline_user_args():
		await check_responsive_strip()
		await check_gem_inventory_actions()
		print("PASS gem UI changed strip: responsive square tiles filling width, separate quantities, quick equip/remove/compatibility, 14 inventory images at 320/440")
		panel.queue_free(); fixture.queue_free(); await process_frame; quit(); return
	await check_popup_unlock()
	assert(int(turret().slotLimit) == 1)
	check_socket_count(3)
	assert(panel.body.find_child("BuyGemSlot",true,false) == null)
	assert(find_exact(panel.body,"+") == null)
	var gold: int = fixture.run_domain.state.gold
	click_slot(2)
	assert(named_button("UnlockGemSlot").disabled,"Later locked socket must not skip the next purchase")
	named_button("UnlockGemSlot").pressed.emit()
	assert(int(turret().slotLimit) == 1 and int(fixture.run_domain.state.gold) == gold)
	click_slot(1)
	assert(int(turret().slotLimit) == 1 and int(fixture.run_domain.state.gold) == gold)
	var unlock := named_button("UnlockGemSlot")
	assert(unlock.text == "해금" and not unlock.disabled)
	var price: int = fixture.run_domain.service.quotes(fixture.run_domain.state,int(turret().id)).link
	assert(price > 0 and all_text(panel.body).contains(str(price)))
	assert_clean_purchase_copy()
	named_button("EquippedSlot1").pressed.emit()
	assert(int(turret().slotLimit) == 1 and int(fixture.run_domain.state.gold) == gold)
	assert(panel.body.find_child("UnlockGemSlot",true,false) == null)
	# Wallet-only refresh must update eligibility without reconstructing the picker.
	click_slot(1)
	unlock = named_button("UnlockGemSlot")
	assert_wallet_refresh(fixture,panel,unlock,"gold",price)
	fixture.run_domain.state.gold = price-1; panel.refresh()
	assert(unlock.disabled)
	unlock.pressed.emit() # Programmatic stale/duplicate input must still be harmless.
	assert(int(turret().slotLimit) == 1 and int(fixture.run_domain.state.gold) == price-1)
	fixture.run_domain.state.gold = 100000; panel.refresh()
	click_slot(1)
	unlock = named_button("UnlockGemSlot")
	gold = fixture.run_domain.state.gold
	unlock.pressed.emit(); unlock.pressed.emit()
	assert(int(turret().slotLimit) == 2 and int(fixture.run_domain.state.gold) == gold-price)
	check_socket_count(3)
	assert_clean_purchase_copy()
	# Third purchase remains gated by the existing level-5 quote, never by UI invention.
	click_slot(2)
	assert(named_button("UnlockGemSlot").disabled)
	gold = fixture.run_domain.state.gold
	named_button("UnlockGemSlot").pressed.emit()
	assert(int(turret().slotLimit) == 2 and int(fixture.run_domain.state.gold) == gold)
	while int(turret().level) < 5: panel._selected_command("level")
	click_slot(2)
	price = fixture.run_domain.service.quotes(fixture.run_domain.state,int(turret().id)).link
	assert(not named_button("UnlockGemSlot").disabled and price > 0)
	gold = fixture.run_domain.state.gold
	named_button("UnlockGemSlot").pressed.emit()
	assert(int(turret().slotLimit) == 3 and int(fixture.run_domain.state.gold) == gold-price)
	check_socket_count(3)
	# Actual research unlock exposes the fourth capacity slot but does not buy it.
	fixture.run_domain.state.progression.researchLevels = {"linkExpansionOne":int(fixture.run_domain.growth.data.research.linkExpansionOne.maxLevel)}
	panel.refresh(); await settle()
	check_socket_count(4)
	assert(int(turret().slotLimit) == 3)
	# Future capacities are presentation-only fixtures: no new progression rule is added.
	for width in [440,320]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		panel.refresh(); await settle()
		for capacity in [3,4,5,6]:
			panel.configuration_cache.derived(fixture.run_domain.state,fixture.run_domain.service)["maxTurretLinkSlots"] = capacity
			panel.body_key = null; panel.refresh(); await settle()
			check_socket_count(capacity)
			check_inline_bounds(width)
	await check_gem_inventory_actions()
	print("PASS gem UI: real costs, cancel, funds, level gate, duplicate input, sequential purchases, research capacity, 3-6 inline at 320/440, equip/remove/compatibility, 14 inventory images")
	panel.queue_free(); fixture.queue_free(); await process_frame; quit()

func check_gem_inventory_actions() -> void:
	# Restore real derived state before actual equip/remove commands.
	panel.configuration_cache._derived = {}; panel.body_key = null
	fixture.run_domain.state.gemInventory = {"attackSpeed":1,"heavyWeapon":1}
	panel.selected_slot = 0; panel.selected_gem = ""; panel.refresh()
	var quick := named_button("GemInventory_attackSpeed")
	await settle()
	assert(absf(quick.size.x-quick.size.y)<0.5 and quick.size.x >= 44 and quick.size.x <= 52)
	assert(quick.tooltip_text.contains("가속"))
	assert(quick.text.is_empty())
	quick.pressed.emit()
	assert(turret().equippedGemSlots[0] == null)
	named_button("GemInventory_attackSpeed").pressed.emit()
	assert(turret().equippedGemSlots[0] == "attackSpeed")
	find_exact(panel.body,"해제").pressed.emit()
	assert(turret().equippedGemSlots[0] == null and int(fixture.run_domain.state.gemInventory.attackSpeed) == 1)
	panel.selected_gem = "heavyWeapon"; panel.refresh()
	assert(find_exact(panel.body,"장착").disabled)
	assert(not panel.gem_panel._gem_block_reason("heavyWeapon",turret()).is_empty())
	# Global inventory keeps all 14 original images, independent quantity labels, responsive columns.
	for type in fixture.run_domain.growth.data.gems: fixture.run_domain.state.gemInventory[type] = 2
	panel.main_tab = "gems"
	for width in [440,320]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		panel.refresh(); await settle()
		check_inventory(width)
func check_empty_inventory() -> void:
	await check_responsive_strip()
	for width in [440,320]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		fixture.run_domain.state.gemInventory = {}
		panel.main_tab = "gems"; panel.refresh(); await settle()
		assert(panel.body.find_children("EmptyGemSlot*","PanelContainer",true,false).is_empty())
		assert(all_text(panel.body).contains("보유한 젬이 없습니다"))

func check_responsive_strip() -> void:
	panel.set_process(false)
	var types: Array = fixture.run_domain.growth.data.gems
	for width in [440,320]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		for owned in [0,1,6,14]:
			fixture.run_domain.state.gemInventory = {}
			for i in range(owned): fixture.run_domain.state.gemInventory[types[i]] = 2
			panel.main_tab = "turrets"; panel.tab = "gems"; panel.selected_slot = 0; panel.selected_gem = ""
			panel.refresh(); await settle(); await settle()
			check_container_bounds(width)
			var first: Control = panel.body.find_child("EmptyGemSlot*",true,false) if owned == 0 else panel.body.find_child("GemInventory_"+types[0],true,false)
			assert(first != null)
			var row: HBoxContainer = first.get_parent()
			var viewport: ScrollContainer = row.get_parent()
			var cells: Array[Node] = row.get_children().filter(func(node): return not str(node.name).begins_with("GemInventoryGap"))
			var expected := 8 if width == 440 else 6
			assert(cells.size() == maxi(expected,owned),"Unexpected filled inventory tile count")
			var blank_count := 0
			for cell in cells:
				assert(absf(cell.size.x-cell.size.y)<0.5 and cell.size.x >= 44 and cell.size.x <= 52,"Each inventory tile must remain a 44-52px square")
				assert(absf(cell.global_position.y-first.global_position.y)<0.5)
				if cell is PanelContainer:
					blank_count += 1
					assert(cell.mouse_filter == Control.MOUSE_FILTER_IGNORE and not cell is BaseButton)
				else:
					assert(cell is Button and all_text(cell).contains("×2"))
					var images := cell.find_children("*","TextureRect",true,false)
					assert(images.size() == 1 and is_equal_approx(minf(images[0].size.x,images[0].size.y),34),"Gem art must stay 34px")
			assert(blank_count == maxi(0,expected-owned))
			if owned <= expected:
				assert(absf(cells[-1].get_global_rect().end.x-viewport.get_global_rect().end.x)<1.1,"Filled row must reach right edge: width=%s owned=%s row=%s viewport=%s last=%s" % [width,owned,row.get_global_rect(),viewport.get_global_rect(),cells[-1].get_global_rect()])
				assert(viewport.scroll_horizontal == 0)
			else:
				assert(row.size.x > viewport.size.x)
				viewport.scroll_horizontal = 100000
				await settle()
				assert(viewport.scroll_horizontal > 0,"Many owned gems must be horizontally scrollable")
				assert(cells[-1].get_global_rect().end.x <= viewport.get_global_rect().end.x+1.1)
			print("Responsive strip %dpx / owned %d: %d cells, %d empty, %.2fpx square" % [width,owned,cells.size(),blank_count,first.size.x])

func check_popup_unlock() -> void:
	panel.set_process(false)
	var initial: Dictionary = fixture.run_domain.state.duplicate(true)
	for width in [440,320]:
		for capacity in [3,4,5,6]:
			fixture.run_domain.state = initial.duplicate(true)
			fixture.run_domain.state.gemInventory = {"attackSpeed":2,"heavyWeapon":1}
			if capacity >= 4:
				fixture.run_domain.state.progression.researchLevels = {"linkExpansionOne":int(fixture.run_domain.growth.data.research.linkExpansionOne.maxLevel)}
			root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
			panel.main_tab = "turrets"; panel.tab = "gems"; panel.selected_slot = -1; panel.selected_gem = ""
			panel.configuration_cache.sync(fixture.run_domain.state,fixture.run_domain.growth.data)
			panel.configuration_cache.derived(fixture.run_domain.state,fixture.run_domain.service)["maxTurretLinkSlots"] = capacity
			panel.body_key = null; panel.refresh(); await settle(); await settle()
			check_socket_count(capacity); check_inline_bounds(width)
			var body_height: float = panel.body.size.y
			var inventory_position: Vector2 = named_button("GemInventory_attackSpeed").global_position
			var unmodified: Dictionary = fixture.run_domain.state.duplicate(true)
			for slot in range(1,capacity):
				var predicted: Dictionary = fixture.run_domain.state.duplicate(true)
				predicted.turrets[0].slotLimit = slot
				predicted.turrets[0].level = maxi(5,int(predicted.turrets[0].level))
				var price: int = fixture.run_domain.service.quotes(predicted,int(turret().id)).link
				var tag: Label = panel.body.find_child("GemSlotPrice%d" % slot,true,false)
				assert(tag != null and tag.text == ("%d G" % price if price > 0 else "—"))
				assert(tag.get_theme_font_size("font_size") == 10)
				assert(tag.get_parent() is PanelContainer and tag.get_parent().get_theme_stylebox("panel") is StyleBoxTexture)
				assert(tag.get_global_rect().position.y >= named_button("EquippedSlot%d" % slot).get_global_rect().end.y-0.5)
				click_slot(slot); await settle(); await settle()
				var popup: Control = panel.body.find_child("GemSlotUnlock",true,false)
				assert(popup != null)
				assert(buttons(popup).size() == 1 and named_button("UnlockGemSlot").text == "해금")
				var selected_price: Label = popup.find_child("GemSlotUnlockPrice",true,false)
				assert(selected_price != null and selected_price.text == ("%d G" % price if price > 0 else "—"))
				assert(popup.find_children("GemSlotUnlockPrice","Label",true,false).size() == 1)
				var hidden_badge: Control = panel.body.find_child("GemSlotPriceBadge%d" % slot,true,false)
				assert(is_zero_approx(hidden_badge.modulate.a))
				assert(absf(popup.global_position.y-hidden_badge.global_position.y)<0.5,"Unified plate starts at original tag: width=%s capacity=%s slot=%s plate=%s badge=%s" % [width,capacity,slot,popup.get_global_rect(),hidden_badge.get_global_rect()])
				assert(named_button("UnlockGemSlot").get_theme_stylebox("normal") is StyleBoxEmpty,"Native action must not redraw the approved plate face")
				var plate_style: StyleBoxTexture = popup.get_theme_stylebox("panel")
				assert(plate_style.texture.resource_path.ends_with("gem_unlock_plate.png"))
				assert(popup.size.distance_to(Vector2(54,45))<0.5,"Approved plate proportions require 54x45px")
				for other in range(1,capacity):
					if other != slot: assert(is_equal_approx(panel.body.find_child("GemSlotPriceBadge%d" % other,true,false).modulate.a,1))
				assert(popup.global_position.x >= 0 and popup.get_global_rect().end.x <= width)
				assert(popup.global_position.y >= named_button("EquippedSlot%d" % slot).get_global_rect().end.y)
				var reserved: Control = panel.body.find_child("GemDetailBand",true,false)
				assert(popup.get_global_rect().end.y <= reserved.get_global_rect().end.y+0.5,"Popup must remain above inventory within fixed reserved height")
				assert(reserved.size.y <= 40,"Basic selection must not restore the oversized empty reservation")
				var gap: float = named_button("GemInventory_attackSpeed").global_position.y-popup.get_global_rect().end.y
				assert(gap >= 4 and gap <= 18,"Unified plate to inventory gap should match compact reference: %s" % gap)
				var condition: Control = panel.body.find_child("GemSlotCondition",true,false)
				if condition != null and condition.visible:
					assert(condition.get_global_rect().end.y <= named_button("GemInventory_attackSpeed").global_position.y)
					assert(not condition.get_global_rect().intersects(popup.get_global_rect()),"Requirement text must not overlap plate")
				assert(reserved.find_child("GemSlotUnlockStem",true,false) == null)
				assert(absf(panel.body.size.y-body_height)<0.5)
				assert(named_button("GemInventory_attackSpeed").global_position.distance_to(inventory_position)<0.5)
				assert(panel.body.size.y <= panel.scroll.size.y+0.5,"Socket popup must not require scrolling")
				named_button("EquippedSlot%d" % slot).pressed.emit(); await settle()
				assert(panel.body.find_child("GemSlotUnlock",true,false) == null,"Same socket must close popup")
				assert(named_button("GemInventory_attackSpeed").global_position.distance_to(inventory_position)<0.5)
			assert(fixture.run_domain.state == unmodified,"Preview prices and selection must not mutate live gameplay")
			click_slot(1); await settle()
			var band: Control = panel.body.find_child("GemDetailBand",true,false)
			var outside := InputEventMouseButton.new()
			outside.button_index = MOUSE_BUTTON_LEFT; outside.pressed = true
			outside.position = band.global_position+Vector2(2,band.size.y-2)
			root.push_input(outside); outside.pressed = false; root.push_input(outside)
			await settle()
			assert(panel.body.find_child("GemSlotUnlock",true,false) == null,"Outside click must dismiss popup")
			# Exercise actual routed input on the raised price area and the action face.
			click_slot(1); await settle()
			var price_area: Control = panel.body.find_child("GemSlotUnlockPrice",true,false)
			var gold_before: int = fixture.run_domain.state.gold
			await pointer_click(price_area.get_global_rect().get_center())
			assert(int(turret().slotLimit) == 1 and int(fixture.run_domain.state.gold) == gold_before)
			assert(panel.body.find_child("GemSlotUnlock",true,false) != null,"Price tap must keep the unified plate open")
			var actual_cost: int = fixture.run_domain.service.quotes(fixture.run_domain.state,int(turret().id)).link
			await pointer_click(named_button("UnlockGemSlot").get_global_rect().get_center())
			assert(int(turret().slotLimit) == 2 and int(fixture.run_domain.state.gold) == gold_before-actual_cost,"Actual input must activate the unlock face")
	fixture.run_domain.state = initial
	panel.configuration_cache._derived = {}; panel.body_key = null
	panel.selected_slot = -1; panel.selected_gem = ""; panel.refresh(); await settle()
	await check_detail_text_bounds()

func check_detail_text_bounds() -> void:
	for width in [440,320]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		for type in fixture.run_domain.growth.data.gems:
			fixture.run_domain.state.gemInventory[type] = 2
			panel.selected_slot = 0; panel.selected_gem = type; panel.refresh(); await settle(); await settle()
			var band: Control = panel.body.find_child("GemDetailBand",true,false)
			var strip: Control = panel.body.find_child("GemInventoryStrip",true,false)
			for node in descendants(band):
				if node is Label and node.visible:
					assert(node.get_global_rect().end.y <= strip.global_position.y+0.5,"Long gem detail must not overlap inventory")
			check_container_bounds(width)
	panel.selected_slot = -1; panel.selected_gem = ""; panel.refresh(); await settle()

func check_changed_layout() -> void:
	panel.set_process(false)
	fixture.run_domain.state.gemInventory = {"attackSpeed":2,"heavyWeapon":2}
	panel.configuration_cache.sync(fixture.run_domain.state,fixture.run_domain.growth.data)
	panel.configuration_cache.derived(fixture.run_domain.state,fixture.run_domain.service)["maxTurretLinkSlots"] = 6
	panel.selected_slot = 0; panel.selected_gem = "heavyWeapon"
	panel.body_key = null; panel.refresh(); await settle()
	check_socket_count(6); check_inline_bounds(440)
	var same_socket := named_button("EquippedSlot5")
	root.content_scale_size = Vector2i(320,880); root.size = Vector2i(320,880)
	await settle(); await settle()
	assert(named_button("EquippedSlot5") == same_socket,"Resize must exercise the same existing six-slot row")
	check_inline_bounds(320)
	var row: Node = panel.body.find_child("EquippedSocketRows",true,false)
	var connectors := 0
	for child in descendants(row):
		if child is TextureRect:
			assert(child.size == Vector2(12,8) and child.stretch_mode == TextureRect.STRETCH_SCALE)
			connectors += 1
	assert(connectors == 5)
	click_slot(1); await settle()
	check_inline_bounds(320)
	assert(named_button("UnlockGemSlot").get_theme_stylebox("normal") is StyleBoxEmpty)
	for type in fixture.run_domain.growth.data.gems: fixture.run_domain.state.gemInventory[type] = 2
	panel.main_tab = "gems"
	for width in [440,320]:
		root.content_scale_size = Vector2i(width,880); root.size = Vector2i(width,880)
		panel.refresh(); await settle()
		check_container_bounds(width); check_inventory(width)
		assert(not all_text(panel.body).contains("보유 젬"),"Redundant owned-gem heading must stay removed")

func pointer_click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.position = position; event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.position = position; event.pressed = false
	root.push_input(event)
	await settle()

func settle() -> void:
	await process_frame; await process_frame; await process_frame

func turret() -> Dictionary:
	return fixture.run_domain.state.turrets[0]

func named_button(value: String) -> Button:
	var result := panel.body.find_child(value,true,false) as Button
	assert(result != null,"Missing button: "+value)
	return result

func click_slot(index: int) -> void:
	if panel.selected_slot == index and panel.body.find_child("GemSlotUnlock",true,false) != null: return
	named_button("EquippedSlot%d" % index).pressed.emit()

func sockets() -> Array[Button]:
	return buttons(panel.body).filter(func(button): return str(button.name).begins_with("EquippedSlot"))

func check_socket_count(count: int) -> void:
	assert(sockets().size() == count,"Expected %d capacity sockets, got %d" % [count,sockets().size()])
	for index in range(sockets().size()):
		var socket := sockets()[index]
		assert(bool(socket.get_meta("locked",false)) == (index >= int(turret().slotLimit)))

func check_inline_bounds(width: int) -> void:
	check_container_bounds(width)
	var previous := Rect2()
	for socket in sockets():
		var bounds := socket.get_global_rect()
		assert(bounds.position.x >= -0.5 and bounds.end.x <= width+0.5,"Socket outside viewport")
		if previous.size != Vector2.ZERO:
			assert(absf(bounds.position.y-previous.position.y)<1,"Sockets must remain on one row")
			assert(bounds.position.x >= previous.end.x-0.5,"Sockets overlap")
		previous = bounds

func check_container_bounds(width: int) -> void:
	for control in [panel.dock,panel.body,panel.detail_panel,panel.scroll]:
		var bounds: Rect2 = control.get_global_rect()
		assert(bounds.position.x >= -0.5 and bounds.end.x <= width+0.5,"%s outside %dpx viewport: %s" % [control.name,width,bounds])

func find_exact(node: Node,value: String) -> Button:
	for button in buttons(node):
		if button.text == value: return button
	return null

func all_text(node: Node) -> String:
	var value := str(node.text)+"\n" if node is Label or node is Button else ""
	for child in node.get_children(): value += all_text(child)
	return value

func assert_clean_purchase_copy() -> void:
	var copy := all_text(panel.body)
	for forbidden in ["슬롯 추가","구매 후","보유 골드","해금 완료","구매 완료","개 →"]:
		assert(not copy.contains(forbidden),"Unexpected purchase copy: "+forbidden)

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child); result.append_array(descendants(child))
	return result

func check_inventory(width: int) -> void:
	var images: Array[TextureRect] = []
	for node in descendants(panel.body):
		if node is TextureRect and node.texture != null and node.texture.resource_path.contains("/gems/"):
			images.append(node)
	assert(images.size() == 14,"Inventory must retain all 14 common gem images")
	assert(panel.body.find_children("GemQuantity","Label",true,false).size() == 14,"Quantities must be separate from gem names")
	var first_y: float = images[0].global_position.y
	var first_row := 0
	for icon in images:
		assert(is_equal_approx(minf(icon.size.x,icon.size.y),34),"Rendered square gem image must be 34px")
		if absf(icon.global_position.y-first_y)<1: first_row += 1
		assert(icon.get_global_rect().position.x >= 0 and icon.get_global_rect().end.x <= width)
	assert(first_row == (3 if width == 440 else 2),"Wrong responsive inventory column count")
