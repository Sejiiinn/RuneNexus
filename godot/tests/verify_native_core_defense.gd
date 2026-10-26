extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Defense = preload("res://combat/native_core_defense_state.gd")
const Core = preload("res://combat/native_core_skill_state.gd")
var checks: int = 0
var failures: Array = []
func _initialize() -> void:
	_rules()
	_runtime()
	if failures.is_empty():
		print("PASS native core defense: ",checks," exact checks; multiplicative mitigation, final-defense boss exception, emergency eligibility, recovery, restore, lethal arrival ordering, duplicate ACK, native chain visual endpoints")
		quit(0)
	else:
		for item in failures: push_error(item)
		quit(1)
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
func near(value: float, expected: float, message: String) -> void:
	check(absf(value-expected)<0.000000001,message+" actual="+str(value)+" expected="+str(expected))
func _enemy(id: int = 1, damage: float = 10.0, boss: bool = false) -> Dictionary:
	return {"id":id,"type":"boss" if boss else "normal","hp":100.0,"maxHp":100.0,"armor":0.0,"maxArmor":0.0,"shield":0.0,"maxShield":0.0,"coreDamage":damage,"x":0.0,"y":0.0,"speed":10.0,"path":[[0,0],[1,0]]}
func _skill():
	var c = Core.new()
	c.configure({"runSkill":"guardianBeam","guardianBeamInterval":5.0,"cooldownRecoveryMultiplier":1.0})
	return c
func _rules() -> void:
	var d = Defense.new()
	var c = _skill()
	d.configure({"maxHp":100.0,"impactDispersionRate":0.15,"threatWeakeningRate":0.25,"emergencyRecoveryRate":0.35},{"hp":100.0})
	var e := _enemy()
	e.hp = 0.0
	var hit: Dictionary = d.arrive(e,false,c.emergency_charge)
	near(hit.damage,6.375,"damage rule 10*.85*.75 without intermediate rounding")
	near(d.hp,93.625,"fractional core HP preserved")
	near(d.round_hp_lost,6.375,"round lost counts actual durability loss")
	near(c.cooldown,3.25,"emergency deducts full interval*.35")
	check(d.emergency_charge_used_this_round,"eligible emergency marks round usage")
	d.arrive(e,false,c.emergency_charge)
	near(c.cooldown,3.25,"emergency consumes at most once per round")
	var mixed := _enemy()
	mixed.maxHp = 60.0
	mixed.maxShield = 20.0
	mixed.maxArmor = 20.0
	mixed.hp = 40.0
	mixed.shield = 5.0
	mixed.armor = 5.0
	near(d.arrive(mixed,false,c.emergency_charge).damage,7.4375,"threat weakening uses all three durability layers")
	# Final defense: bosses do not consume it, prevention never counts as lost HP.
	d.configure({"maxHp":100.0,"hasFinalDefense":true,"emergencyRecoveryRate":0.35},{"hp":100.0})
	c.reset_cycle()
	d.arrive(_enemy(1,10,true),true,c.emergency_charge)
	near(d.hp,90.0,"boss bypasses final defense")
	check(not d.final_defense_used_this_round,"boss does not consume final-defense opportunity")
	var loss_before: float = d.round_hp_lost
	hit = d.arrive(_enemy(2),false,c.emergency_charge)
	check(hit.prevented and d.final_defense_used_this_round,"first nonboss consumes final defense")
	near(d.hp,90.0,"prevented hit has no HP loss")
	near(d.round_hp_lost,loss_before,"prevented hit excluded from damage restoration")
	d.arrive(_enemy(3),false,c.emergency_charge)
	near(d.hp,80.0,"second nonboss hits core normally")
	d.configure({"maxHp":100.0,"hasFinalDefense":true,"emergencyRecoveryRate":0.35},{"hp":100.0})
	c.reset_cycle()
	d.arrive(_enemy(),false,c.emergency_charge)
	check(not d.emergency_charge_used_this_round,"prevented hit cannot consume emergency")
	near(c.cooldown,5.0,"prevented hit leaves skill cooldown unchanged")
	# Ineligible emergency hits keep the opportunity for a later actual loss.
	d.configure({"maxHp":100.0,"emergencyRecoveryRate":0.35},{"hp":100.0})
	c.cooldown = 0.0
	d.arrive(_enemy(),false,c.emergency_charge)
	check(not d.emergency_charge_used_this_round,"ready skill does not consume emergency")
	c.cooldown = 5.0
	c.guardian_beam_active_remaining = 0.4
	d.arrive(_enemy(2),false,c.emergency_charge)
	check(not d.emergency_charge_used_this_round,"active beam does not consume emergency")
	c.guardian_beam_active_remaining = 0
	d.arrive(_enemy(3),false,c.emergency_charge)
	check(d.emergency_charge_used_this_round,"later eligible hit consumes preserved emergency")
	# Debug arrivals skip loss and all round opportunities.
	var debug := _enemy()
	debug.isDebug = true
	d.configure({"maxHp":100.0,"hasFinalDefense":true},{"hp":100.0})
	d.arrive(debug,false,c.emergency_charge)
	check(d.hp==100.0 and not d.final_defense_used_this_round,"debug arrival does not affect core defense")
	# Round recovery sums two separate quantities then clamps, without revival.
	d.configure({"maxHp":100.0,"roundRecoveryRate":0.1,"damageRestorationRate":0.25},{"hp":70.0,"roundHpLost":20.0,"finalDefenseUsedThisRound":true,"emergencyChargeUsedThisRound":true})
	near(d.recover_round(),15.0,"round recovery combines maxHP and round damage restoration")
	near(d.hp,85.0,"round recovery resulting hp")
	check(d.round_hp_lost==0 and not d.final_defense_used_this_round and not d.emergency_charge_used_this_round,"round end resets all round flags")
	d.restore({"hp":98.5,"roundHpLost":20.0})
	near(d.recover_round(),1.5,"recovery cannot exceed maximum HP")
	d.restore({"hp":0,"roundHpLost":100})
	near(d.recover_round(),0.0,"lethal core cannot be revived by round recovery")
	check(d.failed and d.hp==0,"failed flag preserved after attempted recovery")
	# Snapshot restoration preserves fractions and used flags, including old saves.
	d.restore({"hp":31.125,"roundHpLost":7.75,"finalDefenseUsedThisRound":true,"emergencyChargeUsedThisRound":true})
	var restored = Defense.new()
	restored.configure(d.config,d.snapshot())
	check(restored.snapshot()==d.snapshot(),"defense absolute snapshot roundtrips exactly")
	restored.restore({"hp":500})
	near(restored.hp,100.0,"restore HP clamps to current maximum")
	check(restored.round_hp_lost==0 and not restored.final_defense_used_this_round,"legacy absent flags default safely")
	restored.configure({"maxHp":80})
	near(restored.hp,80.0,"maxHP config change clamps existing HP without resetting it")

func _runtime() -> void:
	var r = Runtime.new()
	var enemy := _enemy(1,10)
	var second := _enemy(2,10)
	var bootstrap := {"enemies":[enemy,second],"turrets":[],"coreConfig":{"runSkill":"guardianBeam","normalMaxHp":1000,"emergencyRecoveryRate":0.35},"defense":{"config":{"maxHp":15.0,"emergencyRecoveryRate":0.35},"state":{"hp":15.0}},"wave":{"id":1,"active":true,"spawnQueue":[{"enemyType":"normal","delay":1.0,"enemy":_enemy(3)}]}}
	r.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"dt":0})
	r.core.cooldown = 0.5
	r.process_command({"epoch":1,"sequence":1,"steps":[{"dt":0.1,"running":true},{"dt":10.0,"running":true}]})
	check(r.terminal and r.defense.failed,"second sameframe arrival defeats core immediately")
	near(r.defense.hp,0.0,"lethal loss clamps at zero")
	near(r.defense.round_hp_lost,15.0,"lethal hit records only remaining HP loss")
	check(r.wave.is_empty() and r.pending_steps.is_empty(),"defeat clears pending births and future dt steps")
	check(r.core.activation_count==0,"lethal frame never activates offensive core")
	var kinds: Array = r.events.map(func(v): return v.kind)
	check(kinds.count("arrival")==2 and kinds.count("coreDefeated")==1 and kinds.count("waveCompleted")==0,"two arrivals produce one defeat and no round clear")
	check(kinds.find("coreDefeated")>kinds.rfind("arrival"),"defeat event follows lethal arrival event")
	var snap := JSON.stringify(r.snapshot())
	r.process_command({"epoch":1,"sequence":1,"dt":999})
	check(JSON.stringify(r.snapshot())==snap,"duplicate lethal packet cannot apply damage twice")
	r.process_command({"epoch":1,"sequence":2,"dt":2,"running":true})
	near(r.clock,0.1,"later stale running cannot progress failed core")
	check(r.snapshot().defense.hp==0 and r.snapshot().defense.failed,"absolute failed defense snapshot is exported")
	# Completion recovers first, exports new HP, and preserves one reward event.
	var clear = Runtime.new()
	var b := bootstrap.duplicate(true)
	b.enemies = []
	b.wave.spawnQueue = []
	b.defense = {"config":{"maxHp":100.0,"roundRecoveryRate":0.1,"damageRestorationRate":0.25},"state":{"hp":70.0,"roundHpLost":20.0}}
	clear.process_command({"epoch":1,"sequence":0,"bootstrap":b,"dt":0.01,"running":true})
	near(clear.defense.hp,85.0,"wave completion applies recovery natively before snapshot")
	kinds = clear.events.map(func(v): return v.kind)
	check(kinds.find("coreRecovered")>=0 and kinds.find("coreRecovered")<kinds.find("waveCompleted"),"recovery is sequenced before round completion reward")
	check(clear.snapshot().defense.roundHpLost==0,"completed snapshot clears round loss")
	clear.process_command({"epoch":1,"sequence":1,"dt":0.01,"commands":[{"kind":"waveStart","wave":{"id":2,"active":true,"spawnQueue":[{"enemyType":"normal","delay":1.0,"enemy":_enemy(4)}]}}]})
	check(clear.wave.id==2 and not clear.defense.final_defense_used_this_round,"next round starts with fresh defense usage")
	# Native lightning beam must include both drawing endpoints and follow target.
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	var input: Dictionary = fixtures[0].input.duplicate(true)
	input.definition.type = "lightning"
	input.definition.damageFamily = "elemental"
	input.definition.criticalChance = 0.0
	var visual = Runtime.new()
	var target := _enemy(55)
	target.x = 50.0
	target.path = []
	target.speed = 0.0
	visual.process_command({"epoch":1,"sequence":0,"bootstrap":{"enemies":[target],"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{}}]},"dt":0.3})
	var frame: Dictionary = visual.decorate_frame({"presentation":{"effects":{}}})
	var links: Array = frame.presentation.effects.items.filter(func(v): return v.kind=="chain")
	check(links.size()==1 and links[0].points.size()==2,"native chain beam includes source and target")
	visual.enemies["55"].x = 60.0
	frame = visual.decorate_frame({"presentation":{"effects":{}}})
	links = frame.presentation.effects.items.filter(func(v): return v.kind=="chain")
	near(links[0].points[1][0],60.0,"snapshot-owned chain endpoint follows live logical target")

	visual.enemies["55"].hp = 0.0
	frame = visual.decorate_frame({"presentation":{"effects":{}}})
	links = frame.presentation.effects.items.filter(func(v): return v.kind=="chain")
	near(links[0].points[1][0],60.0,"chain retains last tracked endpoint after target dies")
