extends SceneTree
const Fixture = preload("res://verify_battle_hud.gd")
var app
var hud
var checks := 0
var failures := []
var out := "/Users/sejin/Documents/Codex/RuneNexus/design/combat_ui_concepts/2026-09-23/turret-stats-ux/incremental-update/"
class Core extends RefCounted:
	var skill := "guardianBeam"
	var config := {"normalMaxHp":10.0,"guardianMinNormalHpRate":0.1,"guardianBeamInterval":5.0,"guardianDpsRate":0.08}
	var activation_count := 2
	var direct_damage_dealt := 123.0
	func power_for_activation(_n): return 1.5
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); print("FAIL ",message)
func settle():
	for i in range(6): await process_frame
func named(name: String): return hud.body.find_child(name,true,false)
func labels(node: Node) -> Array:
	var result := []
	for label in node.find_children("*","Label",true,false): result.append(label.text)
	return result
func ids(node: Node) -> Array:
	var result := [node.get_instance_id()]
	for child in node.get_children(): result.append_array(ids(child))
	return result
func command(value: Dictionary):
	check(app.apply_run_command(value),"command "+str(value))
	hud.refresh(); await settle()
func expected_dps() -> float:
	var state: Dictionary = app.run_domain.state
	var derived: Dictionary = app.run_domain.service.derived(state)
	var total := 0.0
	for turret in state.turrets:
		var input: Dictionary = derived.turretStatInputs[turret.type].duplicate(true)
		input.merge({"level":turret.level,"primaryTrait":turret.primaryTrait,"secondaryTrait":turret.secondaryTrait,"gems":turret.equippedGemSlots.filter(func(g): return g != null)},true)
		var stat: Dictionary = app.catalog.turret_stats(turret.type,{"tileSize":48.0,"statInput":input})
		total += float(stat.damage)*float(stat.attackRate)*(int(stat.projectileCount) if turret.type in ["arrow","cannon"] else 1)
		if turret.type == "magic": total += float(stat.damage)*0.5*float(stat.damageOverTimeDamageMultiplier)
	return total
func power_check(label: String):
	check(is_equal_approx(hud.total_dps,expected_dps()),label+" uncached total dps")
	check(hud.resources.text=="전투력 %.1f"%expected_dps(),label+" total text")
func visible_fit(node: Node,label: String):
	for text in node.find_children("*","Label",true,false):
		if not text.is_visible_in_tree(): continue
		var w: float = text.get_theme_font("font").get_string_size(text.text,HORIZONTAL_ALIGNMENT_LEFT,-1,text.get_theme_font_size("font_size")).x
		check(w<=text.size.x+0.5,label+" fits "+str(text.name)+":"+text.text)
func run():
	root.size=Vector2i(440,900); root.content_scale_size=root.size
	app=Fixture.App.new(); check(app.catalog.load_catalog(),"catalog")
	check(app.run_domain.initialize(app.catalog,{},0,100),"initialize"); root.add_child(app)
	hud=load("res://ui/battle_hud.gd").new(); hud.app=app; app.hud=hud; root.add_child(hud); await settle()
	var map: Dictionary=app.catalog.stage(0).map
	var spots:=[]
	for i in map.tiles.size():
		if map.tiles[i]=="build": spots.append(Vector2i(i%int(map.columns),i/int(map.columns)))
	app.run_domain.state.gold=99999999; app.run_domain.state.gemShards=1000
	await command({"kind":"build","type":"arrow","x":spots[0].x,"y":spots[0].y})
	await command({"kind":"build","type":"arrow","x":spots[1].x,"y":spots[1].y})
	app.selected=spots[0]; hud.on_board_selection(); hud.refresh(); await settle()
	var id: int=app.run_domain.state.turrets[0].id
	for width in [440,320]:
		root.size=Vector2i(width,900); root.content_scale_size=root.size; hud.refresh(); await settle()
		var before:=ids(hud.body)
		var level: int=app.run_domain.state.turrets[0].level
		named("TurretLevelAction").pressed.emit(); await settle()
		check(app.selection_view.level_preview,"preview enters")
		check(ids(hud.body)==before,"preview nodes retained "+str(width))
		check(app.run_domain.state.turrets[0].level==level,"preview is nonmutating")
		named("TurretLevelAction").pressed.emit(); await settle()
		check(app.run_domain.state.turrets[0].level==level+1,"confirm levels")
		check(ids(hud.body)==before,"confirm nodes retained "+str(width))
		var q: Dictionary=app.run_domain.service.quotes(app.run_domain.state,id)
		check(named("TurretUpgradePrice").text=="%d G"%q.level,"fresh quote")
		app.run_domain.state.gold=int(q.level)-1; hud.refresh(); await settle()
		check(named("TurretLevelAction").disabled,"wallet disables")
		check(ids(hud.body)==before,"wallet nodes retained")
		app.run_domain.state.gold=99999999; hud.refresh(); await settle()
		check(not named("TurretLevelAction").disabled,"wallet enables")
		visible_fit(named("TurretActionPanel"),str(width)+" action")
		power_check("confirmed "+str(width))
	# Sale and trait callbacks must resolve the new dictionary after transactions.
	named("TurretSellAction").pressed.emit(); await settle()
	var sale: Dictionary=app.run_domain.service.quotes(app.run_domain.state,id)
	check("판매 · +%d 골드"%sale.sell in hud.modal_body.find_children("*","Button",true,false).map(func(b): return b.text),"sale callback current invested gold")
	hud.close_modal(); named("TurretTraitAction").pressed.emit(); await settle()
	check(hud.modal_body.find_child("TraitBlockedReason",true,false)==null,"level 3 trait freshly unlocked")
	hud.close_modal()
	await command({"kind":"primaryTrait","id":id,"type":"overheatMagazine"})
	power_check("trait")
	# All three run rows keep identity across independent purchases and max state.
	hud.main_tab="upgrades"; hud.refresh(); await settle()
	var row_ids:=ids(hud.body)
	for kind in ["towerDamage","killGold","waveGold"]:
		await command({"kind":"runUpgrade","type":kind})
		check(ids(hud.body)==row_ids,"run nodes retained "+kind)
		var row=named("Upgrade_"+kind)
		var quote: Dictionary=app.run_domain.service.run_upgrade_quote(app.run_domain.state,kind)
		check(row.find_child("PurchasePrice",true,false).text=="%d G"%quote.cost,"run cost fresh "+kind)
		check(row.find_child("UpgradeLevel",true,false).text=="Lv.%d/%d"%[quote.level,quote.maxLevel],"run level fresh "+kind)
		power_check("run "+kind)
	app.run_domain.state.runUpgradeLevels.towerDamage=int(app.run_domain.service.run_upgrade_quote(app.run_domain.state,"towerDamage").maxLevel)
	hud.refresh(); await settle()
	check(ids(hud.body)==row_ids,"run maximum nodes retained")
	check(named("Upgrade_towerDamage").find_child("Purchase",true,false).disabled,"max purchase disabled")
	check(named("Upgrade_towerDamage").find_child("PurchaseAction",true,false).text=="최대","max label")
	power_check("max run")
	hud.main_tab="turrets"; hud.refresh(); await settle()
	var max_ids:=ids(hud.body)
	app.run_domain.state.turrets[0].level=10; hud.refresh(); await settle()
	check(ids(hud.body)==max_ids,"turret maximum nodes retained")
	check(named("TurretLevelAction").disabled,"turret maximum disabled")
	check(named("TurretUpgradePrice").text=="최대 레벨","turret maximum price")
	app.run_domain.state.progression["researchLevels"]={"turretTargetPriority":1}
	hud.refresh(); await settle()
	check(ids(hud.body)==max_ids,"research unlock nodes retained")
	check(named("TurretTargetPriority").visible,"research unlock visible")
	await command({"kind":"targetPriority","id":id,"type":"strongest"})
	check(named("TurretTargetPriority").text.contains("최대 체력"),"target priority fresh")
	power_check("turret max and research")
	# Core headline and guardian damage derive from current whole-board total.
	app.scene._native_combat.core=Core.new()
	var core_index: int=map.tiles.find("core")
	app.selected=Vector2i(core_index%int(map.columns),core_index/int(map.columns)); hud.main_tab="turrets"; hud.refresh(); await settle()
	var core_ids:=ids(hud.body)
	app.scene._native_combat.defense.hp=42.4; app.scene._native_combat.defense.max_hp=123.3
	hud.refresh(); await settle()
	check(hud.core_label.text=="체력 43 / 124","core health fresh")
	check(hud.core_metric.text.contains("광선 피해 %.1f"%(maxf(1.0,expected_dps()*0.4)*1.5)),"core beam damage fresh")
	check(ids(hud.body)==core_ids,"core health nodes retained")
	var result={"checks":checks,"failures":failures,"source":"independent direct state/command checks; headless"}
	var file=FileAccess.open(out+"independent-result.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	print("INDEPENDENT ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
