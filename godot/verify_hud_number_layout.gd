extends SceneTree
## Real socket UI and fonts with controlled quotes isolate amount-width regressions.
const ThemeSource = preload("res://ui/app_theme.gd")
const Components = preload("res://ui/combat_component_theme.gd")
class Cache extends RefCounted:
	func derived(_s,_v): return {"maxTurretLinkSlots":6}
class Host extends Control:
	const AppTheme = ThemeSource
	var configuration_cache := Cache.new()
	var app := {"run_domain":{"service":null}}
	var body: VBoxContainer
	var selected_slot := -1
	var selected_gem := ""
	func refresh(): pass
	func _button(parent: Node, text: String, callback: Callable) -> Button:
		var button := AppTheme.button(text,callback)
		Components.apply(button)
		button.custom_minimum_size.y = 32
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parent.add_child(button)
		return button
	func _label(parent: Node, text: String, font_size: int) -> Label:
		var label := AppTheme.label(text,font_size)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(label)
		return label
class Gems extends "res://ui/hud_gem_panel.gd":
	var test_price := 9999
	var mixed := false
	func _slot_price(_state: Dictionary,_id: int,_slot: int) -> int: return [999,1250,9999,10000,123456,123456789][_slot] if mixed else test_price
	func _inventory_strip(_a:Node,_b:Dictionary,_c:Dictionary={}) -> void: pass
var failures := []
var checks := 0
func check(ok: bool, msg: String):
	checks += 1
	if not ok: failures.append(msg); printerr(msg)
func _initialize(): call_deferred("run")
func run():
	for width in [320,360,440,320]:
		root.size = Vector2i(width,900)
		root.content_scale_size = Vector2i(width,900)
		for price in [1250,9999,12500,123456,999949,123456789,-1]:
			var host:=Host.new();root.add_child(host);host.size=Vector2(width,900)
			host.body=VBoxContainer.new();host.body.size=Vector2(width-32,450);host.body.position.x=16;host.add_child(host.body)
			var gems:=Gems.new(host);gems.test_price=price;gems.mixed=price<0
			gems._gems({},{"id":1,"slotLimit":1,"equippedGemSlots":[null]}, {})
			for _frame in range(10):await process_frame
			var sockets:Control=host.body.get_node("EquippedSocketRows")
			var result="%dpx price=%d body=%.1f sockets=%.1f end=%.1f" % [width,price,host.body.size.x,sockets.size.x,sockets.get_global_rect().end.x]
			check(sockets.get_global_rect().end.x<=width-16+0.1,result+" row overflow")
			for slot in range(1,6):
				var label:Label=sockets.find_child("GemSlotPrice%d" % slot,true,false)
				var raw:int=gems._slot_price({},1,slot)
				var tag:String=result+" slot="+str(slot)+" text="+label.text
				check(label.text.trim_suffix(" G")==preload("res://ui/hud_number.gd").compact_price(raw),tag+" amount mismatch")
				check(label.tooltip_text=="%d G" % raw,tag+" tooltip mismatch")
				check(label.get_theme_font_size("font_size")>=8,tag+" unreadable font")
				check(label.get_line_count()==1,tag+" wrapped")
				check(label.get_visible_line_count()==label.get_line_count(),tag+" clipped")
				for i in range(label.text.length()):
					var bounds:=label.get_character_bounds(i)
					check(bounds.end.x<=label.size.x+0.1 and bounds.end.y<=label.size.y+0.1,tag+" character overflow "+str(i))
			host.free()
	print("HUD_NUMBER_LAYOUT checks=%d failures=%d %s" % [checks,failures.size(),JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
