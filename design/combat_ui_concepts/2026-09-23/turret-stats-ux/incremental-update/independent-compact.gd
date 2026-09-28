extends SceneTree
const Fixture=preload("res://verify_battle_hud.gd")
const Numbers=preload("res://ui/hud_number.gd")
var checks:=0
var failures:=[]
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func settle():
	for i in range(8): await process_frame
func run():
	for pair in [[0.0,"0.0"],[999.9,"999.9"],[1000.0,"1K"],[1234.0,"1.23K"],[999990.0,"999.99K"],[999999.0,"1M"],[1000000.0,"1M"],[123456789.0,"123.46M"],[-1234.0,"-1.23K"]]:
		check(Numbers.compact(pair[0])==pair[1],"formatter "+str(pair))
	check(Numbers.compact(999.0,0)=="999","integer small wallet")
	root.size=Vector2i(320,900); root.content_scale_size=root.size
	var app=Fixture.App.new(); check(app.catalog.load_catalog(),"catalog"); check(app.run_domain.initialize(app.catalog,{},0,100),"run"); root.add_child(app)
	var map:Dictionary=app.catalog.stage(0).map; var i:int=map.tiles.find("build")
	app.selected=Vector2i(i%int(map.columns),i/int(map.columns)); app.run_domain.state.gold=10000000
	check(app.apply_run_command({"kind":"build","type":"arrow","x":app.selected.x,"y":app.selected.y}),"build")
	app.run_domain.growth.data.turretRules.arrow.levelUpCosts[0]=1000000
	app.run_domain.growth.data.runUpgrades.towerDamage.baseCost=1000000
	app.run_domain.state.gold=999999
	var hud=load("res://ui/battle_hud.gd").new(); hud.app=app; app.hud=hud; root.add_child(hud); hud.on_board_selection(); hud.refresh(); await settle()
	var b:Button=hud.body.find_child("TurretLevelAction",true,false); var price:Label=hud.body.find_child("TurretUpgradePrice",true,false)
	check(price.text.contains("1M"),"turret compact price")
	check(price.tooltip_text.contains("1000000"),"turret exact price tooltip")
	check(hud.gold_label.text=="1M" and hud.gold_label.tooltip_text=="999999","rounded wallet retains exact tooltip")
	check(b.disabled,"one gold short rejects despite equal compact display")
	var quote:Dictionary=app.run_domain.service.quotes(app.run_domain.state,app.run_domain.state.turrets[0].id)
	check(quote.level==1000000,"quote remains unrounded")
	app.run_domain.state.gold=1000000; hud.refresh(); await settle(); check(not b.disabled,"exact gold sufficient")
	var panel=hud.body.find_child("TurretActionPanel",true,false)
	b.pressed.emit(); await settle(); check(app.selection_view.level_preview,"preview")
	b.pressed.emit(); await settle()
	check(app.run_domain.state.gold==0 and app.run_domain.state.turrets[0].level==2,"exact turret deduction")
	check(hud.body.find_child("TurretActionPanel",true,false)==panel,"formatting preserves nodes")
	app.scene._native_combat.turrets={str(app.run_domain.state.turrets[0].id):{"directDamageDealt":123456789.0}}
	hud.refresh(); await settle()
	check(hud.damage_label.text=="123.46M" and hud.damage_label.tooltip_text.contains("123456789.0"),"damage compact exact tooltip")
	check(app.scene._native_combat.turrets[str(app.run_domain.state.turrets[0].id)].directDamageDealt==123456789.0,"damage raw unchanged")
	hud.main_tab="upgrades"; app.run_domain.state.gold=999999; hud.refresh(); await settle()
	var purchase:Button=hud.body.find_child("Upgrade_towerDamage",true,false).get_node("Purchase")
	var run_price:Label=purchase.find_child("PurchasePrice",true,false)
	check(run_price.text.contains("1M"),"run compact price")
	check(purchase.tooltip_text.contains("1000000") and run_price.tooltip_text.contains("1000000"),"run exact tooltip")
	check(purchase.disabled,"run one gold short")
	app.run_domain.state.gold=1000000; hud.refresh(); await settle(); check(not purchase.disabled,"run exact gold sufficient")
	purchase.pressed.emit(); await settle()
	check(app.run_domain.state.gold==0 and app.run_domain.state.runUpgradeLevels.towerDamage==1,"exact run deduction")
	hud.main_tab="turrets"; hud.refresh(); await settle()
	hud.body.find_child("TurretSellAction",true,false).pressed.emit(); await settle()
	var old_refund:int=app.run_domain.service.quotes(app.run_domain.state,app.run_domain.state.turrets[0].id).sell
	var sale:Button
	for candidate in hud.modal_body.find_children("*","Button",true,false):
		if candidate.text.begins_with("판매 ·"): sale=candidate
	check(sale!=null and sale.text.contains("K"),"sale compact amount")
	check(sale.tooltip_text.contains(str(old_refund)),"sale exact tooltip")
	app.run_domain.state.turrets[0].investedGold+=2
	sale.pressed.emit(); await settle()
	check(app.run_domain.state.turrets.size()==1,"changed quote requests fresh confirmation")
	for candidate in hud.modal_body.find_children("*","Button",true,false):
		if candidate.text.begins_with("판매 ·"): sale=candidate
	check(sale.tooltip_text.contains(str(old_refund+1)),"changed sale exact quote")
	sale.pressed.emit(); await settle()
	check(app.run_domain.state.turrets.is_empty() and app.run_domain.state.gold==old_refund+1,"exact sale refund")
	var result={"checks":checks,"failures":failures}
	var f=FileAccess.open("/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/turret-stats-ux/incremental-update/independent-compact-result.json",FileAccess.WRITE); f.store_string(JSON.stringify(result,"  ")); f.close()
	print("INDEPENDENT_COMPACT ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
