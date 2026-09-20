extends SceneTree
## Expected values are from the pre-removal Dart assertions, not this runtime.
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
var fixtures: Array = []
var checks: int = 0
var failures: Array = []
func _initialize() -> void:
	fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	_slow()
	_path()
	_frost()
	_multi()
	_projectiles()
	_global_attacks()
	_traits()
	_area()
	_balance()
	if failures.is_empty():
		print("PASS legacy combat replacements: ",checks," checks from slow/path/frost/multi/projectile/area/trait/global-attack Dart assertions")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func near(actual: float, expected: float, label: String, epsilon: float = 0.000001) -> void:
	check(absf(actual-expected)<=epsilon,label+" actual="+str(actual)+" expected="+str(expected))
func _input(type: String) -> Dictionary:
	for f in fixtures:
		var c: Dictionary = f.config
		if c.type==type and c.level==1 and c.gems.is_empty() and c.primary==null and c.secondary==null and c.boost==0 and c.scale==1:
			return f.input.duplicate(true)
	push_error("Missing legacy fixture "+type)
	return {}
func _raw(id: int, x: float = 0, y: float = 0, radius: float = 9.2736) -> Dictionary:
	return {"id":id,"maxHp":1000.0,"hp":1000.0,"x":x,"y":y,"collisionRadius":radius,"targetingRadius":radius/0.42*0.5,"path":[],"speed":0.0}
func _runtime(input: Dictionary, enemies: Array):
	var r = Runtime.new()
	r.process_command({"epoch":1,"sequence":0,"dt":0,"bootstrap":{"tileSize":48.0,"enemies":enemies,"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{"x":0,"y":0}}]}})
	return r
func _attack(r, critical: float = 1.0) -> Dictionary:
	var t: Dictionary = r.turrets["1"]
	var a := Stats.firing_stats(t.statInput,t.stats,critical)
	a.definition = t.statInput.definition
	a.burnDamagePerSecondScale = 0.5
	a.burnDurationSeconds = 2.0
	return a
func _slow_strength(e: Dictionary) -> float:
	var multiplier := 1.0
	for s in e.slowInstances: multiplier = minf(multiplier,s.multiplier)
	return multiplier
func _slow_remaining(e: Dictionary) -> float:
	var strength := _slow_strength(e)
	var remaining := 0.0
	for s in e.slowInstances:
		if s.multiplier==strength: remaining=maxf(remaining,s.remaining)
	return remaining
func _slow() -> void:
	var legacy := _raw(1)
	legacy.hp=750.0
	legacy.distanceTravelled=30.0
	legacy.slowMultiplier=0.5
	legacy.slowRemaining=5.0
	var e := Enemy.create(legacy)
	near(e.hp,750,"slow legacy hp restored")
	near(e.distanceTravelled,30,"slow legacy distance restored")
	near(_slow_strength(e),1,"legacy single slow ignored")
	for reverse in [false,true]:
		e=Enemy.create(_raw(1))
		if reverse: Enemy.add_slow(e,0.8,5)
		Enemy.add_slow(e,0.5,1)
		if not reverse: Enemy.add_slow(e,0.8,5)
		near(_slow_strength(e),0.5,"strong slow wins independently of application order")
		near(_slow_remaining(e),1,"strong slow own duration")
		e=Enemy.create(Enemy.snapshot(e))
		Enemy.step(e,1)
		near(_slow_strength(e),0.8,"weaker slow resumes after strong expiry")
		near(_slow_remaining(e),4,"weaker own lifetime persists through save")
		Enemy.step(e,4)
		near(_slow_strength(e),1,"all slows expire")
	e=Enemy.create(_raw(1))
	Enemy.add_slow(e,0.5,1)
	Enemy.step(e,0.5)
	Enemy.add_slow(e,0.8,5)
	Enemy.add_slow(e,0.8,2)
	Enemy.step(e,0.5)
	near(_slow_remaining(e),4.5,"weak hit cannot refresh stronger slow")
	check(e.slowInstances.size()==1,"same strength coalesces to one instance")
	Enemy.add_slow(e,0.8,6)
	near(_slow_remaining(e),6,"longer same strength extends its own lifetime")
	e=Enemy.create(_raw(1))
	Enemy.add_slow(e,0.5,5)
	Enemy.add_slow(e,0.8,1)
	Enemy.add_slow(e,-1,10)
	Enemy.add_slow(e,0.1,NAN)
	Enemy.step(e,2)
	check(e.slowInstances.size()==1,"invalid/expired weak slows do not return")
	near(_slow_strength(e),0.5,"valid strong slow unaffected by invalid inputs")
	Enemy.step(e,3)
	near(_slow_strength(e),1,"invalid slow does not survive strong expiry")
func _point(d: float) -> Vector2:
	d=clampf(d,0,200)
	return Vector2(d,0) if d<=100 else Vector2(100,d-100)
func _path() -> void:
	var r = Runtime.new()
	var plain: Array = [[0,0],[100,0],[100,100]]
	var duplicate: Array = [[0,0],[0,0],[100,0],[100,0],[100,100],[100,100]]
	for distance in [0.0,5.0,80.8,90.0,100.0,110.0,195.0,200.0,250.0]:
		var e := Enemy.create({"id":1,"hp":100,"maxHp":100,"distanceTravelled":distance,"laneOffsetRatio":0.12,"path":plain})
		var center := _point(distance)
		var tangent := _point(distance+19.2)-_point(distance-19.2)
		var fade := clampf(minf(distance,200-distance)/(48*0.55),0,1)
		var offset := Vector2.ZERO if tangent.length_squared()<=0.001 else Vector2(-tangent.y,tangent.x).normalized()*5.76*fade
		near(e.x,center.x,"path restored x",0.00001)
		near(e.y,center.y,"path restored y",0.00001)
		var actual: Vector2 = r._visual_enemy_offset(e)
		near(actual.x,offset.x,"path corner lane offset x",0.00001)
		near(actual.y,offset.y,"path corner lane offset y",0.00001)
		var dup := Enemy.create({"id":2,"hp":100,"maxHp":100,"distanceTravelled":distance,"laneOffsetRatio":0.12,"path":duplicate})
		near(dup.x,e.x,"duplicate path restored x")
		near(dup.y,e.y,"duplicate path restored y")
		near(r._visual_enemy_offset(dup).distance_to(actual),0,"duplicate path lane sample unchanged",0.00001)
	for points in [[[7,11]],[[7,11],[7,11],[7,11]]]:
		for distance in [0.0,10.0]:
			var e := Enemy.create({"id":1,"hp":100,"maxHp":100,"distanceTravelled":distance,"laneOffsetRatio":0.12,"path":points})
			near(e.x,7,"degenerate path x")
			near(e.y,11,"degenerate path y")
			near(r._visual_enemy_offset(e).length(),0,"degenerate path no lane offset")
			Enemy.update_path(e,[[0,0],[200,0]])
			near(e.distanceTravelled,0,"zero-length path resize resets normalized progress")
	var e := Enemy.create({"id":1,"hp":100,"maxHp":100,"distanceTravelled":150,"path":plain})
	Enemy.update_path(e,[[0,0],[200,0],[200,200]])
	near(e.distanceTravelled,300,"resize path preserves normalized distance")
	near(e.y,100,"resize places on corresponding segment")
	Enemy.update_path(e,[[0,0],[200,0],[200,600]])
	near(e.distanceTravelled,600,"second path replacement refreshes cache")
	near(e.y,400,"second path replacement position")
	Enemy.update_path(e,[[1,1]])
	near(e.y,400,"invalid single-point replacement keeps live path")
	var vertical := Enemy.create({"id":1,"hp":100,"maxHp":100,"distanceTravelled":100,"laneOffsetRatio":0.12,"path":[[0,0],[0,200]]})
	near(vertical.x,0,"restored replacement path x")
	near(vertical.y,100,"restored replacement path y")
	near(r._visual_enemy_offset(vertical).x,-5.76,"vertical path lane offset")
func _frost() -> void:
	for critical in [false,true]:
		var i := _input("frost")
		i.definition.criticalChance=1.0 if critical else 0.0
		i.criticalDamageProgressionBonusRate=0.15
		var r = _runtime(i,[_raw(1,10),_raw(2,20),_raw(3,10000)])
		r._tick_turret(r.turrets["1"],0.01)
		for id in ["1","2"]:
			near(r.enemies[id].hp,993.4 if critical else 996.0,"frost shared critical hit literal legacy HP")
			near(_slow_strength(r.enemies[id]),0.8,"frost crit does not amplify slow")
			near(_slow_remaining(r.enemies[id]),1.0,"frost crit does not amplify slow duration")
		near(r.enemies["3"].hp,1000,"frost outside unaffected")
		var one = _runtime(i,[_raw(1,10)])
		one._tick_turret(one.turrets["1"],0.01)
		check(one.rng.state==r.rng.state,"frost RNG consumed once per shot regardless of target count")
	var r = _runtime(_input("frost"),[_raw(1,10)])
	var before: int = r.rng.state
	r._hit(r.turrets["1"],_attack(r,1.8),r.enemies["1"],1,"splash",false)
	near(r.enemies["1"].hp,992.8,"explicit frost crit snapshot preserved")
	check(r.rng.state==before,"explicit attack snapshot never rerolls critical")
func _custom_multi(count: int = 1) -> Dictionary:
	var i := _input("arrow")
	i.definition.damage=100.0
	i.definition.range=200.0
	i.definition.attackRate=1.0
	i.definition.projectileSpeed=500.0
	i.definition.projectileCount=count
	i.definition.criticalChance=0.0
	i.gems=["multipleProjectiles"]
	return i
func _move_all(r, dt: float) -> Array:
	var moving: Array = r.projectiles
	r.projectiles=[]
	for p in moving: r._move_projectile(p,dt)
	return moving
func _multi() -> void:
	var r = _runtime(_custom_multi(),[_raw(1,100,0,42)])
	r._tick_turret(r.turrets["1"],0)
	check(r.projectiles.size()==3,"multi adds exactly two projectiles")
	for index in range(3):
		near(r.projectiles[index].attack.damage,50,"all multi projectiles use fixed half damage")
		near(r.projectiles[index].direction.angle(),(index-1)*PI/18,"symmetric ten degree projectile fan")
		check(is_same(r.projectiles[0].attack,r.projectiles[index].attack),"projectiles share immutable firing snapshot")
	var moved := _move_all(r,0.3)
	near(r.enemies["1"].hp,850,"all three projectiles independently hit one large enemy")
	check(not is_same(moved[0].excluded,moved[1].excluded),"direct-hit histories are per projectile")
	var five = _runtime(_custom_multi(3),[_raw(1,70,0,42)])
	five._tick_turret(five.turrets["1"],0)
	check(five.projectiles.size()==5,"native triple shot adds two rather than multiplying")
	_move_all(five,0.3)
	near(five.enemies["1"].hp,750,"five half-damage projectiles all hit")
	var i := _custom_multi()
	i.gems=["multipleProjectiles","chain"]
	var chains = _runtime(i,[_raw(1,70,0,33.6),_raw(2,140),_raw(3,210)])
	chains._tick_turret(chains.turrets["1"],0)
	var a: Dictionary = chains.projectiles[0].attack
	chains.turrets["1"].statInput.gems=[]
	_move_all(chains,0.2)
	near(chains.enemies["1"].hp,850,"three initial shots retain launch damage after gem removal")
	check(chains.projectiles.size()==3,"three independent first chain segments")
	for p in chains.projectiles:
		check(p.chains==1 and is_same(p.attack,a),"first chain retains snapshot and spends one jump")
	_move_all(chains,0.3)
	near(chains.enemies["2"].hp,925,"first chains use original fifty percent damage")
	check(chains.projectiles.size()==3,"three independent second chain segments")
	for p in chains.projectiles: check(p.chains==0,"second chain exhausts jump count")
	_move_all(chains,0.3)
	near(chains.enemies["3"].hp,925,"second chains do not attenuate a second time")
	check(chains.projectiles.is_empty(),"no extra projectiles after exhausted chains")
	var boosted := _custom_multi()
	boosted.level=3
	boosted.moduleEffect.gemEffectIncreaseRate=0.5
	boosted.passiveNumericGemEffectMultiplier=1.2
	boosted.gems=["damageAmplifier"]
	var base := Stats.stats_at(boosted,3)
	boosted.gems.append("multipleProjectiles")
	var multi := Stats.stats_at(boosted,3)
	near(multi.damage/base.damage,0.5,"multi half damage remains fixed under numeric gem amplification")
	near(multi.damage*multi.projectileCount/(base.damage*base.projectileCount),1.5,"multi total direct DPS increases fifty percent")
	var fire := _input("magic")
	fire.gems=["multipleProjectiles","explosion"]
	var burn = _runtime(fire,[_raw(1),_raw(2,10)])
	burn._impact(burn.turrets["1"],_attack(burn,2),burn.enemies["1"],Vector2.ZERO)
	near(burn.enemies["1"].hp,984,"multi critical fire direct damage")
	near(burn.enemies["2"].hp,992,"multi critical fire splash damage")
	near(Enemy.snapshot(burn.enemies["1"]).burnDamagePerSecond,4,"multi burn excludes critical")
	near(Enemy.snapshot(burn.enemies["2"]).burnDamagePerSecond,2,"multi splash burn coefficient")
	var chained = _runtime(fire,[_raw(1),_raw(2,10)])
	chained._impact(chained.turrets["1"],_attack(chained,2),chained.enemies["1"],Vector2.ZERO,0.5,true)
	near(chained.enemies["1"].hp,992,"multi critical chained direct")
	near(chained.enemies["2"].hp,996,"multi critical chained splash")
	near(Enemy.snapshot(chained.enemies["1"]).burnDamagePerSecond,2,"multi chained burn half original")
	near(Enemy.snapshot(chained.enemies["2"]).burnDamagePerSecond,1,"multi chained splash burn quarter original")
	Enemy.step(chained.enemies["1"],1)
	Enemy.step(chained.enemies["2"],1)
	near(chained.enemies["1"].hp,990,"multi chain burn ticks actual native enemy")
	near(chained.enemies["2"].hp,995,"multi chain splash burn ticks")
func _projectiles() -> void:
	var r = _runtime(_input("arrow"),[_raw(1,80),_raw(2,40)])
	r._projectile(r.turrets["1"],_attack(r),Vector2.ZERO,Vector2.RIGHT,2,[],false,200)
	var p: Dictionary = r.projectiles[0]
	_move_all(r,100.0/620.0)
	near(r.enemies["2"].hp,993,"segment hits first intersected body, independent of insertion order")
	near(r.enemies["1"].hp,1000,"segment does not hit farther endpoint first")
	check(p.position.x>0 and p.position.x<40,"segment hit is first circle intersection")
	check("2" in p.excluded,"collision adds actual direct hit to history")
	var chain = _runtime(_input("arrow"),[_raw(1,0),_raw(2,90),_raw(3,45)])
	var visited: Array = ["1"]
	chain._projectile(chain.turrets["1"],_attack(chain),Vector2.ZERO,Vector2.RIGHT,1,visited,true,110)
	p=chain.projectiles[0]
	_move_all(chain,100.0/620.0)
	near(chain.enemies["1"].hp,1000,"chain ignores prior direct target at origin")
	near(chain.enemies["3"].hp,996.5,"chain strikes intervening body before intended enemy")
	near(chain.enemies["2"].hp,1000,"intended target is not a homing hit")
	check(visited==["1"] and p.excluded==["1","3"],"chain collision history does not mutate caller history")
	var capped = _runtime(_input("arrow"),[_raw(1,100)])
	capped._projectile(capped.turrets["1"],_attack(capped),Vector2.ZERO,Vector2.RIGHT,0,[],false,20)
	p=capped.projectiles[0]
	_move_all(capped,200.0/620.0)
	near(p.position.x,20,"long frame stops exactly at max travel distance")
	near(capped.enemies["1"].hp,1000,"long frame never collides beyond travel limit")
	var moving = _runtime(_input("arrow"),[_raw(1,90)])
	moving._projectile(moving.turrets["1"],_attack(moving),Vector2.ZERO,Vector2.RIGHT,1,[],true,110)
	moving.enemies["1"].y=100.0
	p=moving.projectiles[0]
	_move_all(moving,100.0/620.0)
	near(p.position.x,100,"chain retains original launch direction x")
	near(p.position.y,0,"chain retains original launch direction y")
	near(moving.enemies["1"].hp,1000,"moving away avoids nonhoming projectile")
	var nearest = _runtime(_input("arrow"),[_raw(1),_raw(2,20),_raw(3,111),_raw(4,105)])
	nearest.enemies["2"].hp=0
	check(nearest._target(Vector2.ZERO,110,"nearest",["1"]).id==4,"nearest chain target filters dead visited and outside range")
func _global_attacks() -> void:
	var i := _input("cannon")
	i.gems=["explosion"]
	var r = _runtime(i,[_raw(1),_raw(2,20),_raw(3,30),_raw(4,50)])
	var a := _attack(r)
	r._impact(r.turrets["1"],a,r.enemies["1"],Vector2.ZERO)
	for index in range(4): near(r.enemies[str(index+1)].hp,[975.0,987.5,987.5,987.5][index],"initial explosion direct/splash independent")
	r._impact(r.turrets["1"],a,r.enemies["2"],Vector2(20,0),0.5,true)
	for index in range(4): near(r.enemies[str(index+1)].hp,[968.75,975.0,981.25,987.5][index],"first chain explosion can rehit old direct target")
	r._impact(r.turrets["1"],a,r.enemies["3"],Vector2(30,0),0.5,true)
	for index in range(4): near(r.enemies[str(index+1)].hp,[968.75,968.75,968.75,981.25][index],"second chain uses original damage and independent blast radius")
	var crit = _runtime(_input("cannon"),[_raw(1),_raw(2,10)])
	a=_attack(crit,2)
	crit._impact(crit.turrets["1"],a,crit.enemies["1"],Vector2.ZERO)
	near(crit.enemies["1"].hp,950,"critical cannon primary")
	near(crit.enemies["2"].hp,975,"critical cannon splash")
	crit._impact(crit.turrets["1"],a,crit.enemies["2"],Vector2(10,0),0.5,true)
	near(crit.enemies["1"].hp,937.5,"critical chained splash preserves original crit")
	near(crit.enemies["2"].hp,950,"critical chained direct preserves original crit")
	i=_input("magic")
	i.gems=["explosion"]
	var fire = _runtime(i,[_raw(1),_raw(2,10)])
	fire._impact(fire.turrets["1"],_attack(fire),fire.enemies["1"],Vector2.ZERO,0.5,true)
	near(fire.enemies["1"].hp,992,"chained fire direct")
	near(fire.enemies["2"].hp,996,"chained fire splash")
	near(Enemy.snapshot(fire.enemies["1"]).burnDamagePerSecond,4,"chained fire burn direct")
	near(Enemy.snapshot(fire.enemies["2"]).burnDamagePerSecond,2,"chained fire burn splash")
	Enemy.step(fire.enemies["1"],1)
	Enemy.step(fire.enemies["2"],1)
	near(fire.enemies["1"].hp,988,"chain burn duration not attenuated")
	near(fire.enemies["2"].hp,994,"chain splash burn ticks unshortened")
	i=_input("arrow")
	i.gems=["chain"]
	var arrow = _runtime(i,[_raw(1,40),_raw(2,120),_raw(3,200),_raw(4,280)])
	arrow._projectile(arrow.turrets["1"],_attack(arrow),Vector2.ZERO,Vector2.RIGHT,2,[],false,160)
	_move_all(arrow,60.0/620.0)
	near(arrow.enemies["1"].hp,993,"arrow direct seven damage")
	check(arrow.projectiles.size()==1 and arrow.projectiles[0].chains==1,"one sequential first jump")
	arrow.turrets["1"].statInput.gems=["damageAmplifier"]
	_move_all(arrow,100.0/620.0)
	near(arrow.enemies["2"].hp,996.5,"first jump ignores midflight gem replacement")
	check(arrow.projectiles.size()==1 and arrow.projectiles[0].chains==0,"one sequential second jump")
	_move_all(arrow,100.0/620.0)
	near(arrow.enemies["3"].hp,996.5,"second jump does not compound attenuation")
	near(arrow.enemies["4"].hp,1000,"fourth enemy beyond two jump budget untouched")
	check(arrow.projectiles.is_empty(),"chain terminates at exact budget")
	i=_input("lightning")
	i.gems=["explosion"]
	var lightning = _runtime(i,[_raw(1,20),_raw(2,30),_raw(3,40)])
	a=_attack(lightning)
	lightning._impact(lightning.turrets["1"],a,lightning.enemies["1"],Vector2(20,0))
	for index in range(3): near(lightning.enemies[str(index+1)].hp,[976.0,988.0,988.0][index],"lightning initial explosion")
	lightning._release({"owner":"1","kind":"chain","position":[20,0],"attack":a,"excluded":["1"],"used":0})
	for index in range(3): near(lightning.enemies[str(index+1)].hp,[970.0,976.0,982.0][index],"lightning chain may choose prior splash target")
	var next: Dictionary = lightning.delayed.pop_front()
	lightning._release(next)
	for index in range(3): near(lightning.enemies[str(index+1)].hp,[964.0,970.0,970.0][index],"lightning next splash may hit former chain target")
func _traits() -> void:
	var i := _input("arrow")
	i.primaryTrait="overheatMagazine"
	var r = _runtime(i,[_raw(1),_raw(2)])
	var t: Dictionary = r.turrets["1"]
	var a := _attack(r)
	near(r._traits(t,a,r.enemies["1"]),1.02,"overheat first hit")
	near(r._traits(t,a,r.enemies["1"]),1.04,"overheat same target stacks")
	near(r._traits(t,a,r.enemies["2"]),1.02,"overheat target switch resets stacks")
	for index in range(30): r._traits(t,a,r.enemies["2"])
	near(r._traits(t,a,r.enemies["2"]),1.3,"overheat capped at fifteen stacks")
	i=_input("arrow")
	i.secondaryTrait="suppressiveFire"
	r=_runtime(i,[_raw(1)])
	t=r.turrets["1"]
	a=_attack(r)
	for index in range(4): r._traits(t,a,r.enemies["1"])
	near(r.enemies["1"].physicalVulnerabilityBonus,0,"suppressive fire has no debuff before fifth hit")
	r._traits(t,a,r.enemies["1"])
	near(r.enemies["1"].physicalVulnerabilityBonus,0.2,"fifth suppressive hit applies vulnerability")
	near(r.enemies["1"].physicalVulnerabilityRemaining,2,"suppressive debuff duration")
	i=_input("cannon")
	i.primaryTrait="compressedCharge"
	i.secondaryTrait="fractureImpact"
	r=_runtime(i,[_raw(1),_raw(2,10)])
	a=_attack(r)
	near(r._traits(r.turrets["1"],a,r.enemies["1"]),1.35,"compressed charge direct multiplier")
	a.appliesCompressedCharge=false
	r._impact(r.turrets["1"],a,r.enemies["1"],Vector2.ZERO)
	near(r.enemies["1"].hp,970,"fracture attack-local physical minus20 points")
	near(r.enemies["2"].hp,985,"fracture splash also uses attack-local resistance")
	near(r.enemies["1"].physicalVulnerabilityBonus,0,"fracture does not persist an enemy debuff")
	near(r.enemies["2"].physicalVulnerabilityBonus,0,"fracture splash has no persisted debuff")
	i=_input("frost")
	i.secondaryTrait="frostCrack"
	r=_runtime(i,[_raw(1)])
	a=_attack(r)
	r._hit(r.turrets["1"],a,r.enemies["1"],1,"splash",false)
	near(r.enemies["1"].hp,996,"frost crack does not retroactively amplify first hit")
	near(r.enemies["1"].elementalVulnerabilityBonus,0.15,"frost crack adds15 points elemental vulnerability")
	r._hit(r.turrets["1"],a,r.enemies["1"],1,"splash",false)
	near(r.enemies["1"].hp,991.4,"second frost hit uses previous crack vulnerability")
	i=_input("sniper")
	i.secondaryTrait="exposedMark"
	r=_runtime(i,[_raw(1)])
	near(r._traits(r.turrets["1"],_attack(r),r.enemies["1"]),1,"exposed mark changes resistance not damage multiplier")
	near(r.enemies["1"].physicalVulnerabilityBonus,0.15,"exposed mark physical vulnerability")
	i.secondaryTrait="finishingShot"
	var durable := _raw(1)
	durable.maxHp=100
	durable.hp=100
	durable.maxArmor=40
	durable.armor=40
	durable.maxShield=20
	durable.shield=20
	r=_runtime(i,[durable])
	a=_attack(r)
	near(r._traits(r.turrets["1"],a,r.enemies["1"]),1,"finisher skips full three-layer durability")
	r.enemies["1"].hp=30
	r.enemies["1"].armor=15
	r.enemies["1"].shield=10
	near(r._traits(r.turrets["1"],a,r.enemies["1"]),1.45,"finisher uses combined remaining durability threshold")
	i=_input("arrow")
	i.secondaryTrait="chainCleanup"
	r=_runtime(i,[_raw(1)])
	r._traits(r.turrets["1"],_attack(r),r.enemies["1"])
	r._collect(Enemy.apply_hit(r.enemies["1"],{"damage":10000}).events)
	near(r.turrets["1"].cleanup,3,"assisted kill enables three-second cleanup")
	r.running=false
	r._tick_turret(r.turrets["1"],3.1)
	near(r.turrets["1"].cleanup,0,"cleanup expires after three seconds")
	i=_input("lightning")
	i.primaryTrait="focusedLightning"
	i.secondaryTrait="lightningRecovery"
	r=_runtime(i,[_raw(1)])
	a=_attack(r)
	near(r._traits(r.turrets["1"],a,r.enemies["1"]),1.3,"focused lightning direct damage")
	r.turrets["1"].cooldown=1.0
	r.turrets["1"].lastBaseCooldown=2.0
	r.turrets["1"].lightningElapsed=0.3
	a.lightningChainMaxJumps=3
	r._lightning_complete(r.turrets["1"],a,1)
	near(r.turrets["1"].cooldown,1,"recovery never lengthens an already shorter cooldown")
	r.turrets["1"].cooldown=2.0
	r._lightning_complete(r.turrets["1"],a,1)
	near(r.turrets["1"].cooldown,2.0/1.3-0.3,"unused lightning jumps improve reload denominator")
func _area() -> void:
	var i := _input("arrow")
	i.gems=["explosion"]
	var s := Stats.stats_at(i,1)
	near(s.splashRadius,42.5,"explosion grants34 radius and25 percent area together")
	near(s.splashSecondaryDamageMultiplier,0.5,"default splash half damage")
	near(s.range,96,"explosion does not change arrow attack range")
	i=_input("cannon")
	i.gems=["explosion","heavyWeapon"]
	s=Stats.stats_at(i,1)
	near(s.effectAreaMultiplier,1.45,"explosion and heavy radius increases are additive")
	near(s.splashRadius,60.9,"cannon native42 radius keeps identity at1.45")
	near(s.damage,32.5,"heavy physical cannon damage multiplier")
	i=_input("frost")
	i.gems=["explosion"]
	i.definition.criticalChance=0.0
	var r = _runtime(i,[_raw(1,91.2),_raw(2,114)])
	r._tick_turret(r.turrets["1"],0.01)
	near(r.turrets["1"].stats.range,76,"frost base range remains76")
	near(r.turrets["1"].stats.centeredAreaRadius,95,"frost actual effect radius expands25 percent")
	near(r.turrets["1"].stats.splashRadius,0,"frost does not gain duplicate explosion")
	near(r.enemies["1"].hp,996,"frost expanded area includes near outside-base-range enemy")
	near(r.enemies["2"].hp,1000,"frost outside expanded area excluded")
	for type in ["arrow","cannon","magic","frost","sniper","lightning"]:
		i=_input(type)
		i.gems=["chain"]
		s=Stats.stats_at(i,1)
		near(s.chainCount,4 if type=="lightning" else (0 if type in ["frost","sniper"] else 2),"chain capability "+type)
	# Preserve all existing fixed Dart stat fixtures, including numeric trait paths.
	for fixture in fixtures:
		var actual := Stats.stats_at(fixture.input,int(fixture.input.level))
		for key in actual:
			if actual[key] is float or actual[key] is int:
				near(actual[key],fixture.expected[key],"fixed Dart stat fixture "+fixture.name+"/"+key,0.00001)
			else:
				check(actual[key]==fixture.expected[key],"fixed Dart stat fixture flag "+fixture.name+"/"+key)

func _balance() -> void:
	# Literal assertions from game_balance_test.dart (0241ef6).
	var raw_enemies: Array = []
	for index in range(5):
		var e := _raw(index+1,[70,65,60,55,20][index])
		e.hp=[100,100,200,20,100][index]
		e.maxHp=e.hp
		e.distanceTravelled=[90,10,50,50,50][index]
		raw_enemies.append(e)
	var r = _runtime(_input("arrow"),raw_enemies)
	for priority in ["first","last","strongest","weakest","nearest"]:
		var expected: Dictionary = {"first":1,"last":2,"strongest":3,"weakest":4,"nearest":5}
		check(int(r._target(Vector2.ZERO,100,priority).id)==expected[priority],"original target priority "+priority)
	var e := Enemy.create({"id":1,"hp":100,"maxHp":100,"maxArmor":54,"armor":54})
	var hit := Enemy.apply_hit(e,{"damage":7})
	near(hit.actualDamage,2.324572,"armor54 mitigates basic7",0.001)
	near(e.armor,51.675428,"armor54 remaining",0.001)
	near(e.hp,100,"armor54 protects HP")
	e=Enemy.create({"id":1,"hp":100,"maxHp":100,"maxArmor":50,"armor":50})
	near(Enemy.apply_hit(e,{"damage":7,"ignoreArmorReduction":true}).actualDamage,7,"piercing ignores reduction")
	near(e.armor,43,"piercing still consumes armor")
	Enemy.apply_hit(e,{"damage":50,"ignoreArmorReduction":true})
	near(e.hp,93,"piercing overflow hits HP")
	e=Enemy.create({"id":1,"hp":100,"maxHp":100})
	Enemy.add_poison(e,3,6,4)
	Enemy.add_poison(e,3,6,4)
	Enemy.step(e,1)
	near(e.hp,94,"two poison stacks literal original six damage")
	for index in range(8): Enemy.add_poison(e,3,6,4)
	check(e.poisonStacks==4,"poison maximum stack cap")
	var i := _input("magic")
	i.secondaryTrait="ignitionBurst"
	r=_runtime(i,[_raw(1)])
	e=r.enemies["1"]
	Enemy.add_burn(e,{"damagePerSecond":10,"duration":2,"sourceX":0,"sourceY":0})
	r._impact(r.turrets["1"],_attack(r),e,Vector2.ZERO)
	near(e.hp,978,"ignition fixed magic-88 base16 plus 10*2*.3 burst")
	near(r.turrets["1"].directDamageDealt,22,"ignition attributed as direct damage")
	i.secondaryTrait="chainIgnition"
	var source := _raw(1)
	source.hp=5
	source.maxHp=5
	var target := _raw(2,40)
	target.hp=100
	target.maxHp=100
	target.distanceTravelled=1
	r=_runtime(i,[source,target])
	Enemy.add_burn(r.enemies["1"],{"damagePerSecond":10,"duration":2,"sourceX":0,"sourceY":0})
	r._collect(Enemy.step(r.enemies["1"],1))
	r._collect(Enemy.step(r.enemies["2"],0.6))
	check(r.enemies["1"].hp==0,"lethal burn kills source")
	near(r.enemies["2"].hp,94,"DoT kill transfers 10DPS for original .6 seconds")
	near(r.turrets["1"].burnDamageDealt,11,"credit only actual5 source HP plus6 transferred damage")
	r=_runtime(i,[source,target])
	Enemy.add_burn(r.enemies["1"],{"damagePerSecond":1,"duration":2,"sourceX":0,"sourceY":0})
	r._impact(r.turrets["1"],_attack(r),r.enemies["1"],Vector2.ZERO)
	r._collect(Enemy.step(r.enemies["2"],0.6))
	near(r.enemies["1"].hp,0,"direct fire kill transfers newly applied stronger burn")
	near(r.enemies["2"].hp,95.2,"fixed magic-88 base16*.5 native burn transferred for .6 seconds")
	r=_runtime(_input("magic"),[target])
	Enemy.add_burn(r.enemies["2"],{"damagePerSecond":10,"duration":2,"sourceX":0,"sourceY":0})
	r._collect(Enemy.step(r.enemies["2"],1))
	near(r.enemies["2"].hp,90,"original source credited burn damage")
	near(r.turrets["1"].burnDamageDealt,10,"burn source stat receives actual damage")

	# Refund removes attribution without removing the existing burn.
	r._command({"kind":"removeTurret","id":1})
	r._command({"kind":"turret","turret":{"id":2,"position":[0,0],"statInput":_input("arrow"),"state":{"x":0,"y":0}}})
	r._collect(Enemy.step(r.enemies["2"],0.5))
	near(r.enemies["2"].hp,85,"refund retains old burn damage")
	near(r.turrets["2"].burnDamageDealt,0,"rebuilt turret never inherits refunded burn credit")
	var body := _raw(1,105.9,0,5.04)
	body.targetingRadius=6.0
	r=_runtime(_input("arrow"),[body])
	check(not r._target(Vector2.ZERO,100,"first",[],true).is_empty(),"body radius includes inner .1 boundary")
	r.enemies["1"].x=106.1
	check(r._target(Vector2.ZERO,100,"first",[],true).is_empty(),"body radius excludes outer .1 boundary")
	i=_input("lightning")
	r=_runtime(i,[_raw(1,20),_raw(2,40),_raw(3,60)])
	for index in range(3): r.enemies[str(index+1)].distanceTravelled=30-index*10
	r.running=false
	r._release({"kind":"charge","owner":"1","attack":_attack(r)})
	near(r.enemies["1"].hp,976,"lightning initial24 immediate")
	r._step(0.069)
	near(r.enemies["2"].hp,1000,"lightning jump waits .07")
	r._step(0.002)
	near(r.enemies["2"].hp,988,"lightning first delayed jump12")
	near(r.enemies["3"].hp,1000,"third awaits distinct next jump")
	r._step(0.07)
	near(r.enemies["3"].hp,988,"lightning second delayed jump12")
	near(r.turrets["1"].directDamageDealt,24,"lightning direct statistic")
	near(r.turrets["1"].chainDamageDealt,24,"lightning delayed chain statistic")
	r=_runtime(i,[_raw(1,20)])
	r.running=false
	r.delayed.append({"kind":"charge","timer":0.3,"owner":"1","attack":_attack(r)})
	r._step(0.299)
	near(r.enemies["1"].hp,1000,"charge waits .299")
	r._step(0.002)
	near(r.enemies["1"].hp,976,"charge releases after .301")
	i.secondaryTrait="currentAmplification"
	r=_runtime(i,[_raw(1,20),_raw(2,40)])
	r.enemies["1"].distanceTravelled=10
	r._release({"kind":"charge","owner":"1","attack":_attack(r)})
	r._release(r.delayed.pop_front())
	near(r.enemies["1"].hp,976,"current amplification leaves initial24 unchanged")
	near(r.enemies["2"].hp,983.2,"followup current amplification24*.7")
	i=_input("lightning")
	i.gems=["explosion"]
	r=_runtime(i,[_raw(1,20),_raw(2,21),_raw(3,70),_raw(4,80)])
	var a := _attack(r)
	r._impact(r.turrets["1"],a,r.enemies["1"],Vector2(20,0))
	r._impact(r.turrets["1"],a,r.enemies["3"],Vector2(70,0),0.5,true)
	for index in range(4): near(r.enemies[str(index+1)].hp,[976.0,988.0,988.0,994.0][index],"original game balance lightning initial/followup splash")
