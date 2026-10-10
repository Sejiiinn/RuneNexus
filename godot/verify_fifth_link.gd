extends SceneTree
## New progression permission, sequential purchase and canonical checkpoint contract.
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Codec = preload("res://app/save_codec.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Progression = preload("res://content/stage_progression.gd")
class EffectServices extends "res://services/app_services.gd":
	var sample: Dictionary = {}
	func _progression_for_update() -> Dictionary: return sample.duplicate(true)
	func _store_progression(value: Dictionary) -> bool: sample=value; return true

var failures: Array = []
var checks := 0
func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok: failures.append(name)
func _initialize() -> void:
	var growth := Growth.new(); var catalog := Catalog.new()
	check(growth.load_catalog() and catalog.load_catalog(),"catalog")
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.runes=100000; p.clearedStageNumbers=[20,29]; p.researchLevels={"linkExpansionOne":1}
	check(Progression.requirement("research","linkExpansionTwo")==30,"fixed ID30")
	check(Progression.unlock_items(30).any(func(item):return item[0]=="링크 확장 II"),"3-10 display")
	check(growth.max_link_slots(p)==4,"existing I has four")
	check(not growth.execute(p,{"kind":"startResearch","id":"linkExpansionTwo","nowMillis":1000}).ok,"pre-clear direct start rejected")
	p.grandfatherUnlocks=["research:linkExpansionTwo"]
	check(not growth.execute(p,{"kind":"startResearch","id":"linkExpansionTwo","nowMillis":1000}).ok,"no nonexistent grandfather right")
	p.clearedStageNumbers.append(30); p.researchLevels={}
	check(not growth.execute(p,{"kind":"startResearch","id":"linkExpansionTwo","nowMillis":1000}).ok,"I prerequisite")
	p.researchLevels={"linkExpansionTwo":1}
	check(growth.max_link_slots(p)==3,"II alone no rights")
	p.researchLevels={"linkExpansionOne":1}
	var quote: Dictionary = growth.research_quote(p,"linkExpansionTwo")
	check(quote.cost==45000 and quote.durationMillis==28800000,"45000 runes eight hours")
	var poor := p.duplicate(true); poor.runes=44999
	check(not growth.execute(poor,{"kind":"startResearch","id":"linkExpansionTwo","nowMillis":1000}).ok,"44999 runes insufficient")
	var started: Dictionary = growth.execute(p,{"kind":"startResearch","id":"linkExpansionTwo","nowMillis":1000})
	check(started.ok and started.state.runes==55000 and growth.max_link_slots(started.state)==4,"research starts without free slot")
	var cancelled: Dictionary = growth.execute(started.state,{"kind":"cancelResearch","id":"linkExpansionTwo","nowMillis":61000})
	check(cancelled.ok and cancelled.state.runes==100000 and cancelled.state.researchElapsedMillis.linkExpansionTwo==60000,"cancel retains time refunds")
	var resumed: Dictionary = growth.execute(cancelled.state,{"kind":"startResearch","id":"linkExpansionTwo","nowMillis":100000})
	check(resumed.ok and resumed.state.activeResearches[0].durationMillis==28740000,"research resumes")
	var completed: Dictionary = growth.execute(resumed.state,{"kind":"completeFinishedResearches","nowMillis":28840000})
	check(completed.ok and growth.max_link_slots(completed.state)==5,"elapsed completion opens permission")
	var discounted := p.duplicate(true); discounted.researchLevels.researchEfficiency=1; discounted.researchLevels.researchCostEfficiency=1
	var discounted_quote: Dictionary=growth.research_quote(discounted,"linkExpansionTwo")
	check(discounted_quote.cost==42857 and discounted_quote.durationMillis==27428571,"same research efficiencies")
	completed.state.clearedStageNumbers.append_array([3,7])
	var effects := EffectServices.new(); effects.app={"run_domain":{"growth":growth}}
	var effect := {"effectType":"complete_research","payload":{"researchType":"linkExpansionTwo","targetLevel":1}}
	effects.sample=p.duplicate(true); effects.sample.clearedStageNumbers=[20]
	check(not effects._apply_effect(effect),"unauthorized server effect no stage")
	effects.sample=p.duplicate(true); effects.sample.researchLevels={}
	check(not effects._apply_effect(effect),"unauthorized server effect no I")
	effects.sample=p.duplicate(true)
	check(effects._apply_effect(effect) and effects.sample.researchLevels.linkExpansionTwo==1,"authorized server effect")
	effects.free()
	var commands := Commands.new(catalog,growth)
	var adapter := Adapter.new(catalog,growth)
	for type in growth.data.turretRules:
		var state: Dictionary=commands.initial_state(completed.state,0); state.gold=100000
		var map: Dictionary=catalog.stage_map(0); var cell: int=map.tiles.find("build")
		var result: Dictionary=commands.apply(state,{"kind":"build","type":type,"x":cell%int(map.columns),"y":cell/int(map.columns)})
		check(result.ok,type+" build"); state=result.state
		var id: int=state.turrets[0].id
		while state.turrets[0].level<5: state=commands.apply(state,{"kind":"level","id":id}).state
		var costs: Array=growth.data.turretRules[type].linkUpgradeCosts
		for expected in costs:
			var before: int=state.gold
			check(commands.quotes(state,id).link==int(expected),type+" exact sequential cost")
			result=commands.apply(state,{"kind":"link","id":id}); check(result.ok,type+" sequential buy"); state=result.state
			check(state.gold==before-int(expected),type+" gold deducted")
		check(state.turrets[0].slotLimit==5 and not commands.apply(state,{"kind":"link","id":id}).ok,type+" sixth rejected")
		var gems: Array=["attackSpeed","range","physicalDamage","criticalChance","multipleProjectiles"] if type=="arrow" else growth.data.turretRules[type].compatibleGems.slice(0,5)
		for i in range(5):
			state.gemInventory[gems[i]]=1
			result=commands.apply(state,{"kind":"equipGem","id":id,"slot":i,"type":gems[i]})
			check(result.ok,type+" equip "+str(i)); state=result.state
		var emitted: Dictionary=commands.runtime_commands(state)[0].turret
		check(emitted.state.equippedGemSlots.size()==5,type+" runtime keeps all five")
		var expected: Dictionary=catalog.turret(type,{"tileSize":1.0,"statInput":{"level":5,"gems":gems}})
		check(Stats.shared_stats_at(emitted.statInput,5)==Stats.stats_at(expected,5),type+" five gems calculated")
		if type=="arrow":
			var four: Dictionary=emitted.statInput.duplicate(true);four.gems=gems.slice(0,4)
			var five_stats: Dictionary=Stats.shared_stats_at(emitted.statInput,5);var four_stats: Dictionary=Stats.shared_stats_at(four,5)
			check(five_stats.projectileCount==four_stats.projectileCount+2 and is_equal_approx(five_stats.damage,four_stats.damage*0.5),"fifth gem changes real projectile count and damage")
		var runtime := Runtime.new(); var bootstrap: Dictionary=catalog.bootstrap(0,{"defenseConfig":commands.derived(state).defenseConfig,"coreConfig":growth.core_config(state,0,0,catalog)})
		bootstrap.turrets=[emitted]; bootstrap.enemies=[]; bootstrap.wave={"id":1,"active":false,"spawnQueue":[]}
		runtime.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"session":{"phase":"preparation","paused":true}})
		runtime.process_command({"epoch":1,"sequence":1,"ackEvent":runtime.event_id})
		var saved: Dictionary=adapter.capture(state,runtime.snapshot(),20000)
		check(not saved.is_empty(),type+" checkpoint capture "+adapter.error)
		if saved.is_empty(): continue
		check(Codec.decode(saved).progression.researchLevels.linkExpansionTwo==1,type+" II codec")
		var restored: Dictionary=adapter.prepare(saved)
		check(not restored.is_empty(),type+" checkpoint resume "+adapter.error)
		if not restored.is_empty(): check(restored.state.turrets[0].equippedGemSlots==gems and restored.state.gold==state.gold,type+" five gems gold restored")
		var unauthorized := saved.duplicate(true); unauthorized.progression.researchLevels.erase("linkExpansionTwo")
		check(adapter.prepare(unauthorized).is_empty(),type+" five requires research on restore")
		var sixth := saved.duplicate(true); sixth.activeRun.turrets[0].slotLimit=6; sixth.activeRun.turrets[0].equippedGemSlots.append(null)
		check(adapter.prepare(sixth).is_empty(),type+" six restore rejected")
		var legacy := saved.duplicate(true); legacy.progression.researchLevels.erase("linkExpansionTwo"); legacy.activeRun.turrets[0].slotLimit=4; legacy.activeRun.turrets[0].equippedGemSlots.pop_back(); legacy.activeRun.turrets[0].equippedGems.pop_back()
		check(not adapter.prepare(legacy).is_empty(),type+" existing four preserved")
		var before_sell: int=state.gold; var refund: int=commands.quotes(state,id).sell
		result=commands.apply(state,{"kind":"sell","id":id})
		check(result.ok and result.state.gold==before_sell+refund and result.state.gemInventory.size()==5,type+" full investment refund all gems")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
