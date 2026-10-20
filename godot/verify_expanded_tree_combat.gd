extends SceneTree
## Focused expanded-tree formulas, real hits, control and stage durability.
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Defense = preload("res://combat/native_core_defense_state.gd")
const Core = preload("res://combat/native_core_skill_state.gd")
var checks := 0
var failures: Array = []
var inputs: Dictionary = {}

func _initialize() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	for fixture: Dictionary in fixtures:
		var input: Dictionary = fixture.input
		if input.level == 1 and input.gems.is_empty() and not inputs.has(input.definition.type):
			inputs[input.definition.type] = input.duplicate(true)
	_formulas()
	_damage_components()
	_chain_ranges()
	_chain_layers()
	_dot()
	_control()
	_core_charge()
	_defense()
	print("EXPANDED_TREE_COMBAT checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) <= 1e-9 * maxf(1.0, absf(expected)), label + " actual=" + str(actual) + " expected=" + str(expected))

func input_for(type: String, effects: Dictionary = {}) -> Dictionary:
	var input: Dictionary = inputs[type].duplicate(true)
	input.coreEffects = effects.duplicate(true)
	input.definition.criticalChance = 0.0
	return input

func _formulas() -> void:
	var input := input_for("arrow", {"turretLevelDamageIncrease":0.295,"maxTurretLevelBonus":1})
	var base: float = input.definition.damage
	near(Stats.stats_at(input,1).damage,base,"level bonus does not change level one")
	near(Stats.stats_at(input,11).damage,base*(1.0+(pow(1.2,10)-1.0)*1.295),"earned level damage uses existing exponential curve through level11")
	near(Stats.stats_at(input,99).damage,Stats.stats_at(input,11).damage,"elite level cap11 clamps excessive inputs")
	var legacy := input_for("arrow")
	near(Stats.stats_at(legacy,11).damage,Stats.stats_at(legacy,10).damage,"legacy cap remains10")
	input = input_for("cannon", {"rangeIncrease":0.05,"attackRateIncrease":0.03,"projectileSpeedIncrease":0.06,"criticalChanceBonus":0.02,"criticalDamageBonus":0.1,"splashRadiusIncrease":0.2,"splashSecondaryDamageBonus":0.15})
	input.moduleEffect.rangeIncreaseRate = 0.2
	input.moduleEffect.attackRateIncreaseRate = 0.1
	input.moduleEffect.projectileSpeedIncreaseRate = 0.3
	input.moduleEffect.criticalChanceBonusRate = 0.05
	input.moduleEffect.criticalDamageBonusRate = 0.15
	var stats := Stats.stats_at(input,1)
	near(stats.range,input.definition.range*1.25,"tree and module range increases add")
	near(stats.attackRate,input.definition.attackRate*1.13,"tree and module rate increases add")
	near(stats.projectileSpeed,input.definition.projectileSpeed*1.36,"tree and module projectile speed increases add")
	near(stats.criticalChance,0.07,"critical chance percentage points add")
	near(stats.criticalDamageMultiplier,input.definition.criticalDamageMultiplier+0.25,"critical damage percentage points add")
	near(stats.splashRadius,input.definition.splashRadius*1.2,"area bonus applies radius")
	near(stats.splashSecondaryDamageMultiplier,0.65,"K4 adds15 percentage points to50 percent")
	for type in inputs:
		var i := input_for(type,{"equippedGemDamageAmplificationPerGem":0.05})
		for count in range(6):
			i.gems = ["armorPiercing","chain","range","criticalChance","aimSpeed"].slice(0,count)
			var plain := i.duplicate(true)
			plain.coreEffects = {}
			near(Stats.stats_at(i,1).damage,Stats.stats_at(plain,1).damage*(1+count*0.05),"K6 all equipped gem types count once for " + type + ":" + str(count))
	var frost := input_for("frost", {"controlDurationIncrease":0.375,"slowStrengthBonus":0.057,"splashRadiusIncrease":0.165})
	frost.moduleEffect.slowDurationIncreaseRate = 0.2
	frost.moduleEffect.slowStrengthBonusRate = 0.01
	stats = Stats.stats_at(frost,1)
	near(stats.slowDuration,frost.definition.slowDuration*1.575,"general control duration joins slow module layer")
	near(stats.slowMultiplier,maxf(0.1,frost.definition.slowMultiplier-0.067),"slow strength stays slow-only")
	near(stats.centeredAreaRadius,stats.range*1.165,"area radius affects existing frost centered attack")
	var lightning := input_for("lightning", {"lightningChainDamageIncrease":0.09,"lightningChainRangeIncrease":0.135})
	lightning.moduleEffect.lightningChainDamageIncreaseRate = 0.2
	lightning.moduleEffect.lightningChainRangeIncreaseRate = 0.1
	stats = Stats.stats_at(lightning,1)
	near(stats.lightningChainDamageMultiplier,0.5*1.2,"tree chain hit does not alter existing module coefficient or DoT scale")
	var attack := Stats.firing_stats(lightning,stats,1.0)
	near(attack.lightningChainJumpRange,lightning.lightningChainJumpRange*1.235,"same chain range layer adds module and tree")
	for type in inputs:
		var cached_input := input_for(type,{"turretLevelDamageIncrease":0.16,"maxTurretLevelBonus":1,"equippedGemDamageAmplificationPerGem":0.05,"attackRateIncrease":0.03,"damageOverTimeSpeedMultiplier":1.5})
		cached_input.gems = ["chain","damageOverTime"]
		cached_input.boardDistanceScale = 1.7
		cached_input.corePassiveTurretDamageMultiplier = 1.2
		cached_input.corePassiveTurretAttackRateMultiplier = 1.1
		cached_input.chainCleanupActive = true
		var direct := Stats.stats_at(cached_input,11)
		var shared := Stats.shared_stats_at(cached_input,11)
		for key in direct:
			if direct[key] is float: near(shared[key],direct[key],"shared cache equals fresh: " + type + "/" + key)
			else: check(shared[key] == direct[key],"shared cache scalar equals fresh: " + type + "/" + key)

func enemy(id: int = 1) -> Dictionary:
	return {"id":id,"maxHp":10000.0,"hp":10000.0,"x":float(id)*5,"y":0.0,"speed":0.0,"radius":1.0,"coreDamage":10.0}

func runtime(type: String, effects: Dictionary = {}):
	var r = Runtime.new()
	r.start(1,{"turrets":[{"id":1,"position":[0,0],"statInput":input_for(type,effects),"state":{"x":0,"y":0}}],"enemies":[enemy(1),enemy(2)]},{"clock":"godot","phase":"wave","running":true})
	return r

func attack_for(t: Dictionary) -> Dictionary:
	var attack := Stats.firing_stats(t.statInput,t.stats,1.0)
	attack.definition = t.statInput.definition
	attack.burnDamagePerSecondScale = 0.5
	attack.burnDurationSeconds = 2.0
	return attack

func _damage_components() -> void:
	var r = runtime("cannon",{"directDamageIncrease":0.23,"splashDamageIncrease":0.06,"splashSecondaryDamageBonus":0.15})
	var t: Dictionary = r.turrets["1"]
	var a := attack_for(t)
	r._impact(t,a,r.enemies["1"],Vector2(5,0))
	near(10000-r.enemies["1"].hp,a.damage*1.23,"K4 does not alter primary explosion hit")
	near(10000-r.enemies["2"].hp,a.damage*0.65*1.29,"secondary coefficient and same hit-increase layer applied once")
	var magic = runtime("magic",{"directDamageIncrease":0.23,"damageOverTimeIncrease":0.153,"damageOverTimeSpeedMultiplier":1.5,"equippedGemDamageAmplificationPerGem":0.05})
	t = magic.turrets["1"]
	t.statInput.gems = ["range","chain"]
	t.stats = Stats.shared_stats_at(t.statInput,1)
	a = attack_for(t)
	magic._hit(t,a,magic.enemies["1"],1.0,"direct",true)
	near(10000-magic.enemies["1"].hp,a.damage*1.23,"direct increase applies to existing direct hit")
	near(magic.enemies["1"].burnInstances[0].damagePerSecond,a.damage*0.5*1.153*1.5,"direct-only increase does not leak into burn; K6 shared damage does")
	var arrow = runtime("arrow",{"damageOverTimeIncrease":0.153,"damageOverTimeSpeedMultiplier":1.5})
	t = arrow.turrets["1"]
	arrow._hit(t,attack_for(t),arrow.enemies["1"],1.0,"direct",true)
	check(arrow.enemies["1"].burnInstances.is_empty() and arrow.enemies["1"].poisonRemaining == 0.0,"tree never invents DoT on attacks without one")

func _chain_ranges() -> void:
	for bonus in [0.0,0.135]:
		var r = runtime("arrow",{"lightningChainRangeIncrease":bonus})
		var t: Dictionary = r.turrets["1"]
		t.statInput.gems = ["chain"]
		t.stats = Stats.shared_stats_at(t.statInput,1)
		var a := attack_for(t)
		r.enemies["2"].x = 125.0
		r.enemies["2"].position.x = 125.0
		r._projectile(t,a,Vector2.ZERO,Vector2.RIGHT,2,[],false,500)
		var p: Dictionary = r.projectiles.pop_front()
		r._move_projectile(p,0.1)
		check((not r.projectiles.is_empty()) == (bonus>0.0),"projectile chain actually uses expanded search range")
		r = runtime("lightning",{"lightningChainRangeIncrease":bonus})
		t = r.turrets["1"]
		a = attack_for(t)
		r.enemies["2"].x = 125.0
		r.enemies["2"].position.x = 125.0
		r._release({"kind":"chain","owner":"1","attack":a,"position":[5,0],"excluded":["1"],"used":0})
		check((r.enemies["2"].hp<10000.0) == (bonus>0.0),"lightning chain actually uses expanded search range")

func _chain_layers() -> void:
	for type in ["arrow", "lightning"]:
		for module_increase in [0.0, 0.2]:
			var r = runtime(type,{"directDamageIncrease":0.2,"splashDamageIncrease":0.3,"lightningChainDamageIncrease":0.4})
			var t: Dictionary = r.turrets["1"]
			t.statInput.moduleEffect.lightningChainDamageIncreaseRate = module_increase
			t.stats = Stats.shared_stats_at(t.statInput,1)
			var a := attack_for(t)
			# Give this fixture an already-existing DoT to check separation only.
			a.hasDamageOverTime = true
			var scale: float = a.lightningChainDamageMultiplier if type == "lightning" else 0.5
			r._hit(t,a,r.enemies["1"],scale,"chain",false,true)
			near(10000-r.enemies["1"].hp,a.damage*scale*1.6,type+" chain primary adds direct+chain once")
			near(r.enemies["1"].burnInstances[0].damagePerSecond,a.damage*0.5*scale,type+" chain DoT excludes all hit-only increases")
			r._hit(t,a,r.enemies["2"],scale*0.5,"splash",false,true)
			near(10000-r.enemies["2"].hp,a.damage*scale*0.5*1.5,type+" chain explosion adds direct+area without chain")
			near(r.enemies["2"].burnInstances[0].damagePerSecond,a.damage*0.5*scale*0.5,type+" chain explosion DoT excludes hit-only increases")

func _dot() -> void:
	var normal := input_for("magic",{"damageOverTimeIncrease":0.153,"burnDurationIncrease":0.385})
	normal.gems = ["damageOverTime"]
	normal.moduleEffect.damageOverTimeIncreaseRate = 0.25
	normal.moduleEffect.burnDurationIncreaseRate = 0.1
	var sped := normal.duplicate(true)
	sped.coreEffects.damageOverTimeSpeedMultiplier = 1.5
	var a := Stats.stats_at(normal,1)
	var b := Stats.stats_at(sped,1)
	near(a.damageOverTimeDamageMultiplier,(1+0.25+0.153)*1.3,"DoT additive layer precedes gem amplification")
	near(b.damageOverTimeDamageMultiplier,a.damageOverTimeDamageMultiplier*1.5,"K3 DPS is1.5x")
	near(b.damageOverTimeDurationMultiplier,a.damageOverTimeDurationMultiplier/1.5,"K3 time is divided by1.5")
	near(b.damageOverTimeDamageMultiplier*b.damageOverTimeDurationMultiplier,a.damageOverTimeDamageMultiplier*a.damageOverTimeDurationMultiplier,"K3 single application total preserved")
	var e := Enemy.create(enemy())
	Enemy.add_burn(e,{"damagePerSecond":75.0,"duration":2.0/1.5,"sourceX":0,"sourceY":0})
	Enemy.step(e,3.0)
	near(e.hp,9900.0,"accelerated actual burn respects final fractional lifetime")
	e = Enemy.create(enemy())
	Enemy.add_burn(e,{"damagePerSecond":75.0,"duration":0.5,"sourceX":0,"sourceY":0})
	Enemy.add_burn(e,{"damagePerSecond":20.0,"duration":1.0,"sourceX":0,"sourceY":0})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":2.0,"sourceX":1,"sourceY":0})
	check(e.burnInstances.size()==2,"same-source refresh keeps one instance")
	Enemy.step(e,2.0)
	# Source 0 refreshes 75 DPS to 1s; source 1 still burns separately for 2s.
	near(e.hp,9825.0,"same-source refresh and other-source burns stack")
	e = Enemy.create(enemy())
	Enemy.add_poison(e,10.0,3.0,1,1.0,1.5)
	near(e.poisonDamagePerSecond,15.0,"existing poison shares speed mechanism")
	near(e.poisonRemaining,2.0,"existing poison lifetime compresses")
	Enemy.step(e,5.0)
	near(e.hp,9970.0,"existing poison total preserved without adding any poison attack")

func _control() -> void:
	var e := Enemy.create(enemy())
	e.controlImmunities = ["slow"]
	var options := {"multiplier":0.7,"durationMultiplier":1.375,"firstControlDurationMultiplier":2.0}
	check(not Enemy.add_control(e,"slow",2.0,options) and not e.firstControlApplied,"immune control does not consume first application")
	check(not Enemy.add_control(e,"poison",2.0,options) and not e.firstControlApplied,"DoT is not a control")
	check(Enemy.add_control(e,"stun",2.0,options),"generic stun accepted")
	near(e.stunRemaining,5.5,"first successful control duration doubles after general increase")
	check(Enemy.add_control(e,"freeze",2.0,options),"future freeze accepted")
	near(e.freezeRemaining,2.75,"second control type shares global first-use marker")
	var restored := Enemy.create(Enemy.snapshot(e))
	check(restored.firstControlApplied,"enemy first control marker roundtrips")
	restored.controlImmunities = []
	Enemy.add_control(restored,"slow",2.0,options)
	near(restored.slowInstances[0].remaining,2.75,"restore cannot gain another first-control bonus")
	e = Enemy.create({"id":5,"hp":100,"maxHp":100,"speed":10,"path":[[0,0],[100,0]]})
	Enemy.add_control(e,"freeze",0.25)
	Enemy.step(e,1.0)
	near(e.x,7.5,"hard control stops motion only during its remaining interval")
	var r = runtime("frost",{"controlDurationIncrease":0.1,"firstControlDurationMultiplier":2.0})
	var t: Dictionary = r.turrets["1"]
	var a := attack_for(t)
	r._hit(t,a,r.enemies["1"],1.0,"splash",false)
	near(r.enemies["1"].slowInstances[0].remaining,a.slowDuration*2.0,"real frost hit uses global first-control gate")

func _core_charge() -> void:
	var c = Core.new()
	c.configure({"runSkill":"guardianBeam","guardianBeamInterval":5.0,"killCoreChargeRate":0.1})
	near(c.charge_from_kill(),0.5,"kill adds10 percent maximum charge")
	near(c.cooldown,4.5,"kill leaves normal recharge active")
	c.update(1.0,func(): return false,func(): return 0.0,func(_damage): pass,func(_power): pass)
	near(c.cooldown,3.5,"normal time recharge still progresses")
	c.cooldown = 0.1
	near(c.charge_from_kill(),0.1,"kill charge caps ready")
	near(c.charge_from_kill(),0.0,"ready skill discards overflow")
	c.guardian_beam_active_remaining = 0.5
	c.cooldown = 5.0
	near(c.charge_from_kill(),0.0,"active core does not bank charge")
	var r = runtime("arrow")
	r.core.configure({"runSkill":"guardianBeam","guardianBeamInterval":5.0,"killCoreChargeRate":0.1})
	r.enemies["1"].hp = 1.0
	var t: Dictionary = r.turrets["1"]
	r._hit(t,attack_for(t),r.enemies["1"],1.0,"direct",true)
	near(r.core.cooldown,4.5,"actual turret kill charges once")
	r._hit(t,attack_for(t),r.enemies["1"],1.0,"direct",true)
	near(r.core.cooldown,4.5,"already dead enemy cannot charge twice")
	r._command({"kind":"coreDamage","enemyId":2,"damage":20000.0})
	near(r.core.cooldown,4.5,"core own damage kills excluded")

func _defense() -> void:
	var d = Defense.new()
	d.configure({"maxHp":150.0,"baseMaxHp":100.0,"nexusAdditionalHpRate":0.15,"hasIndomitableFortress":true,"roundRecoveryRate":0.1,"damageRestorationRate":1.0})
	near(d.additional_hp,15.0,"C12 uses base maxHP before tree hp multipliers")
	var e := enemy()
	e.coreDamage = 10.0
	var no_charge := func(_rate): return false
	d.arrive(e,false,no_charge)
	near(d.additional_hp,5.0,"additional HP is consumed before ordinary HP")
	near(d.hp,150.0,"ordinary HP protected by additional HP")
	near(d.round_hp_lost,0.0,"lost additional HP never enters healing restoration pool")
	d.recover_round()
	near(d.additional_hp,5.0,"wave recovery cannot replenish additional HP")
	d.configure(d.config)
	near(d.additional_hp,5.0,"configuration refresh cannot regrant additional HP")
	e.coreDamage = 200.0
	var hit: Dictionary = d.arrive(e,false,no_charge)
	check(hit.indomitableTriggered and not hit.defeated and not d.failed,"K8 intercepts lethal before failure")
	near(d.hp,1.0,"K8 leaves exactly one ordinary HP")
	near(d.additional_hp,0.0,"lethal damage fully consumes remaining additional HP")
	near(d.invulnerable_remaining,3.0,"K8 starts three seconds invulnerability")
	check(d.arrive(e,false,no_charge).prevented,"same-step subsequent arrivals blocked")
	d.reset_round()
	check(d.indomitable_used_this_stage and d.invulnerable_remaining==3.0,"round reset cannot reset stage defense")
	var restored = Defense.new()
	restored.configure(d.config,d.snapshot())
	check(restored.indomitable_used_this_stage and restored.additional_hp==0.0,"resume preserves spent one-time effects")
	restored.step(2.9)
	check(restored.arrive(e,false,no_charge).prevented,"invulnerability lasts full duration")
	restored.step(0.11)
	check(restored.arrive(e,false,no_charge).defeated and restored.failed,"next lethal hit after immunity fails; no second revival")
	var timed = Defense.new()
	timed.configure(d.config,{"hp":1.0,"indomitableUsedThisStage":true,"invulnerableRemaining":3.0})
	for frame in range(180): timed.step(1.0/60.0)
	check(timed.invulnerable_remaining == 0.0,"three seconds ends exactly after180 fixed steps")
	var legacy = Defense.new()
	legacy.configure({"maxHp":100.0,"nexusAdditionalHpRate":0.15},{"hp":50.0})
	near(legacy.additional_hp,0.0,"legacy/resumed state without bonus never creates fresh HP")
