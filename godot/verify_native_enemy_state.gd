extends SceneTree
const Enemy = preload("res://combat/native_enemy_state.gd")
var checks := 0
var failures: Array=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func close(actual: float,expected: float,label: String) -> void:
	check(absf(actual-expected)<0.00001,label+" got "+str(actual)+" expected "+str(expected))
func count(events: Array,kind: String) -> int:
	return events.filter(func(e): return e.type==kind).size()
func poison(e: Dictionary,dps: float,duration: float,extra: Dictionary={}) -> void:
	var value := {"damagePerSecond":dps,"duration":duration}
	value.merge(extra,true)
	Enemy.add_poison(e,value)
func enemy(extra: Dictionary={}) -> Dictionary:
	var raw := {"id":5,"maxHp":1000.0,"hp":1000.0,"speed":10.0,"path":[{"x":0.0,"y":0.0},{"x":10.0,"y":0.0},{"x":10.0,"y":10.0}]}
	raw.merge(extra,true)
	return Enemy.create(raw)
func _initialize() -> void:
	_training_dot_checks()
	_target_multiplier_checks()
	_path_revision_checks()
	_vulnerability_timer_checks()
	_dot_armor_checks()
	_dot_expiry_checks()
	_dot_reapplication_checks()
	_dot_expiry_event_checks()
	_boss_slow_checks()
	var e := enemy({"speed":0.0,"maxShield":100.0,"shield":20.0,"shieldRegenRate":0.1,"maxArmor":100.0,"armor":10.0})
	Enemy.add_burn(e,{"damagePerSecond":30.0,"duration":1.0})
	Enemy.step(e,1.0)
	close(e.shield,0,"regen before burn")
	check(e.shieldBroken,"shield break latch")
	close(e.armor,10,"no burn spill after regen")
	Enemy.step(e,1.0)
	close(e.shield,0,"broken shield never regenerates")
	var result := Enemy.apply_hit(e,{"damage":40.0})
	var mitigated := 40.0*(0.12+0.88*40.0/70.0)
	close(result.actualDamage,mitigated,"armor reduction")
	close(e.hp,1000.0-(mitigated-10.0),"armor overflow")
	e=enemy({"maxArmor":100.0,"armor":20.0})
	Enemy.add_rift_mark(e,0.25,1)
	result=Enemy.apply_hit(e,{"damage":20.0,"ignoreArmorReduction":true})
	close(e.hp,995,"piercing still consumes armor")
	close(result.bonusDamage,5,"rift contribution")
	e=enemy()
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":0.1,"sourceX":1,"sourceY":2})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":2.0,"sourceX":2,"sourceY":3})
	Enemy.step(e,0.5)
	close(e.hp,965,"different source burns stack within their lifetimes")
	Enemy.step(e,0.5)
	close(e.hp,940,"remaining source burns independently")
	Enemy.add_burn(e,{"damagePerSecond":25.0,"duration":4.0,"damageMultiplier":2.0,"sourceX":2,"sourceY":3,"ignoreArmorReduction":true})
	var transfer := Enemy.burn_transfer(e,{"x":2,"y":3})
	close(transfer.damagePerSecond,50,"same source retains strongest dps")
	close(transfer.remaining,4,"same source refresh max duration")
	check(transfer.ignoreArmorReduction,"same source retains armor bypass")
	Enemy.clear_burn_source(e,{"x":2,"y":3})
	check(Enemy.burn_transfer(e,{"x":2,"y":3}).is_empty(),"source removal clears attribution")
	check(e.burnInstances.size()==1,"source removal preserves damage")
	e=enemy()
	poison(e,10,0.01)
	poison(e,10,0.01)
	Enemy.step(e,0.5)
	# Two stacks: 20 DPS with a 10% stack bonus for 0.01s.
	close(e.hp,999.78,"poison last tick clips to active lifetime")
	check(e.poisonInstances.is_empty(),"poison expiration clears stacks")
	e=enemy()
	Enemy.add_slow(e,0.2,0.1)
	Enemy.add_slow(e,0.5,1.0)
	Enemy.step(e,0.2)
	close(e.x,1,"expired strong slow removed before movement")
	Enemy.add_slow(e,0.5,0.1)
	close(e.slowInstances[0].remaining,0.8,"same slow cannot shorten")
	Enemy.add_vulnerability(e,"physical",0.3,0.1)
	Enemy.add_vulnerability(e,"elemental",0.4,1.0)
	Enemy.add_rift_mark(e,0.25,0.01)
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":1})
	Enemy.step(e,0.2)
	close(e.hp,975,"rift active for dot before timer expiration")
	close(e.physicalVulnerabilityBonus,0,"physical expires independently")
	close(e.elementalVulnerabilityBonus,0.4,"elemental remains")
	close(e.riftMarkDamageAmplification,0,"rift expires after dot")
	e=enemy({"hp":5.0})
	Enemy.add_burn(e,{"damagePerSecond":10.0,"duration":3,"sourceX":2,"sourceY":3})
	poison(e,100,1)
	var events := Enemy.step(e,1)
	check(count(events,"killed")==1,"burn then poison kills exactly once")
	check(count(Enemy.step(e,1),"killed")==0,"dead repeated step no kill")
	check(not Enemy.apply_hit(e,{"damage":100}).killed,"dead direct hit no kill")
	close(e.x,0,"dead cannot move")
	e=enemy()
	events=Enemy.step(e,2)
	close(e.x,10,"one waypoint per frame")
	close(e.y,0,"overshoot discarded")
	check(count(events,"coreArrival")==0,"intermediate waypoint no arrival")
	events=Enemy.step(e,2)
	check(count(events,"coreArrival")==1,"arrival event")
	check(Enemy.step(e,2).is_empty(),"arrival exactly once")
	e=enemy({"distanceTravelled":5.0})
	close(e.x,5,"restore distance")
	Enemy.update_path(e,[{"x":0,"y":0},{"x":20,"y":0},{"x":20,"y":20}])
	close(e.x,10,"path resize preserves progress")
	var restored := Enemy.create(Enemy.snapshot(e))
	close(restored.x,e.x,"snapshot position roundtrip")
	check(restored.targetIndex==e.targetIndex,"snapshot waypoint roundtrip")
	e=enemy({"path":[{"x":0,"y":0},{"x":0,"y":0},{"x":10,"y":0}],"distanceTravelled":5})
	close(e.x,5,"duplicate waypoint restore")
	check(e.targetIndex==2,"duplicate skipped by path cache")
	e=enemy({"burnRemaining":2,"burnDamagePerSecond":10,"slowMultiplier":0.1,"slowRemaining":3})
	check(e.burnInstances.size()==1,"legacy burn restored")
	check(e.slowInstances.is_empty(),"legacy single slow intentionally ignored")
	e=enemy({"speed":1.0,"path":[{"x":0.0,"y":0.0},{"x":1000.123456789,"y":2000.987654321}]})
	Enemy.step(e,0.123456789)
	var angle := atan2(2000.987654321,1000.123456789)
	check(absf(e.x-cos(angle)*0.123456789)<1e-14,"double precision movement x")
	check(absf(e.y-sin(angle)*0.123456789)<1e-14,"double precision movement y")
	e=enemy({"hp":1.0})
	Enemy.add_burn(e,{"damagePerSecond":10.0,"duration":2,"sourceX":1,"sourceY":1})
	Enemy.add_burn(e,{"damagePerSecond":10.0,"duration":3,"sourceX":2,"sourceY":2})
	events=Enemy.step(e,0.5)
	var kill: Dictionary=events.filter(func(event): return event.type=="killed")[0]
	check(kill.burnTransfer.sourceX==2,"latest source burn ticks first")
	close(kill.burnTransfer.remaining,2.5,"kill transfer uses decremented lifetime")
	e=enemy({"maxArmor":100,"armor":100,"riftMarkRemaining":2,"riftMarkDamageAmplification":0.25})
	result=Enemy.apply_hit(e,{"damage":20})
	close(result.bonusDamage,25*(0.12+0.88*25/55.0)-20*(0.12+0.88*20/50.0),"rift bonus includes nonlinear armor response")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _vulnerability_timer_checks() -> void:
	var e := enemy({"speed":0.0,"physicalVulnerabilityRemaining":0.1,"physicalVulnerabilityBonus":0.2,
		"elementalVulnerabilityRemaining":0.2,"elementalVulnerabilityBonus":0.3,
		"riftMarkRemaining":0.3,"riftMarkDamageAmplification":0.4})
	var before := Enemy.snapshot(e)
	Enemy.step(e,0.0)
	for field in ["physicalVulnerabilityRemaining","physicalVulnerabilityBonus","elementalVulnerabilityRemaining","elementalVulnerabilityBonus","riftMarkRemaining","riftMarkDamageAmplification"]:
		close(e[field],before[field],"zero step preserves "+field)
	Enemy.step(e,0.1)
	close(e.physicalVulnerabilityRemaining,0,"physical exact expiry")
	close(e.physicalVulnerabilityBonus,0,"physical expiry clears own bonus")
	close(e.elementalVulnerabilityRemaining,0.1,"elemental countdown independent")
	close(e.elementalVulnerabilityBonus,0.3,"elemental bonus survives physical expiry")
	close(e.riftMarkRemaining,0.2,"rift countdown independent")
	close(e.riftMarkDamageAmplification,0.4,"rift amplification survives other expiry")
	Enemy.step(e,0.1)
	close(e.elementalVulnerabilityBonus,0,"elemental exact expiry clears own bonus")
	Enemy.step(e,0.2)
	close(e.riftMarkRemaining,0,"rift overshoot clamps to zero")
	close(e.riftMarkDamageAmplification,0,"rift expiry clears amplification")
	# Inactive values are left alone; only a positive timer owns expiry reset.
	e.physicalVulnerabilityBonus=0.2
	e.elementalVulnerabilityRemaining=-1.0
	e.elementalVulnerabilityBonus=0.3
	Enemy.step(e,0.1)
	close(e.physicalVulnerabilityBonus,0.2,"zero inactive timer leaves bonus unchanged")
	close(e.elementalVulnerabilityRemaining,-1,"negative inactive timer left unchanged")
	close(e.elementalVulnerabilityBonus,0.3,"negative inactive timer leaves bonus unchanged")


func _dot_armor_checks() -> void:
	# Poison passes armor fully. Burn without armor piercing enters armor at a
	# fixed 50%; neither uses the size-based hit formula.
	var e := enemy({"speed":0.0,"maxShield":15.0,"shield":15.0,"maxArmor":20.0,"armor":20.0})
	# One stack: 40 DPS with a 5% stack bonus deals 21 per half second.
	poison(e,40.0,2.0)
	Enemy.step(e,0.5)
	close(e.shield,0,"poison: shield consumed first")
	check(e.shieldBroken,"poison: shield break latched")
	close(e.armor,14,"poison: overflow consumes armor without reduction")
	close(e.hp,1000,"poison: armor protects HP")
	Enemy.step(e,0.5)
	close(e.armor,0,"poison: armor consumed before HP")
	close(e.hp,993,"poison: only armor overflow reaches HP")
	e = enemy({"speed":0.0,"maxShield":15.0,"shield":15.0,"maxArmor":20.0,"armor":20.0})
	Enemy.add_burn(e,{"damagePerSecond":40.0,"duration":2.0,"ignoreArmorReduction":false})
	Enemy.step(e,0.5)
	close(e.shield,0,"burn: shield consumed first at full damage")
	check(e.shieldBroken,"burn: shield break latched")
	close(e.armor,17.5,"burn: overflow enters armor at fixed half")
	close(e.hp,1000,"burn: armor protects HP")
	Enemy.step(e,0.5)
	close(e.armor,7.5,"burn: half rate continues on armor")
	Enemy.step(e,0.5)
	close(e.armor,0,"burn: armor consumed before HP")
	close(e.hp,997.5,"burn: only reduced armor overflow reaches HP")
	e = enemy({"speed":0.0,"maxArmor":100.0,"armor":100.0})
	Enemy.add_burn(e,{"damagePerSecond":40.0,"duration":2.0,"ignoreArmorReduction":true})
	Enemy.step(e,0.5)
	close(e.armor,80,"armor-piercing burn passes armor fully")
	# Same game time, different frame intervals and 4x at 60 FPS.
	for kind in ["burn","poison"]:
		for dt in [1.0/120.0,1.0/60.0,1.0/30.0,4.0/60.0]:
			e = enemy({"speed":0.0,"maxArmor":120.0,"armor":120.0})
			if kind == "burn":
				Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":2.0})
			else:
				poison(e,100.0,2.0)
			for tick in range(roundi(1.0/dt)): Enemy.step(e,dt)
			close(e.armor,70 if kind == "burn" else 15,kind+": armor damage independent of dt "+str(dt))
			close(e.hp,1000,kind+": no premature HP damage "+str(dt))
	# Old saves with a false or missing per-burn flag use the fixed armor factor.
	for burn in [{"remaining":2.0,"damagePerSecond":40.0,"ignoreArmorReduction":false},{"remaining":2.0,"damagePerSecond":40.0}]:
		var restored := Enemy.create(Enemy.snapshot(enemy({"speed":0.0,"maxArmor":100.0,"armor":100.0,"burnInstances":[burn]})))
		Enemy.step(restored,0.5)
		close(restored.armor,90,"restored burn without piercing uses fixed armor factor")
	var legacy := enemy({"speed":0.0,"maxArmor":100.0,"armor":100.0,"burnRemaining":2.0,"burnDamagePerSecond":40.0})
	Enemy.step(legacy,0.5)
	close(legacy.armor,90,"legacy scalar burn uses fixed armor factor")
	var marked := enemy({"speed":0.0,"maxArmor":20.0,"armor":20.0})
	Enemy.add_rift_mark(marked,0.25,2.0)
	Enemy.add_burn(marked,{"damagePerSecond":100.0,"duration":2.0,"sourceX":1,"sourceY":2})
	var events := Enemy.step(marked,0.5)
	# 62.5 marked damage enters armor at half: 20 armor, 11.25 overflow.
	close(marked.hp,988.75,"rift amplifies burn before armor factor")
	var damage: Dictionary = events.filter(func(event): return event.type=="damage" and event.kind=="burn")[0]
	close(damage.damage,31.25,"burn event includes armor and HP damage")
	close(damage.bonusDamage,6.25,"burn event retains rift contribution")
	check(damage.sourceX==1 and damage.sourceY==2,"burn event retains source attribution")
	var dying := enemy({"speed":0.0,"hp":5.0,"maxArmor":10.0,"armor":10.0})
	Enemy.add_burn(dying,{"damagePerSecond":40.0,"duration":3.0,"sourceX":1,"sourceY":2,"ignoreArmorReduction":false})
	events = Enemy.step(dying,1.0)
	check(count(events,"killed")==1,"armored burn reports kill once")
	var kills := events.filter(func(event): return event.type=="killed")
	if kills.is_empty(): return
	var transfer: Dictionary = kills[0].burnTransfer
	var recipient := enemy({"speed":0.0,"maxArmor":20.0,"armor":20.0})
	Enemy.add_burn(recipient,transfer)
	Enemy.step(recipient,1.0)
	close(recipient.armor,0,"transferred burn keeps fixed armor factor")
	close(recipient.hp,1000,"transferred burn still consumes armor")


func _path_revision_checks() -> void:
	var legacy := enemy({"distanceTravelled":3.0,"x":2.5,"y":0.0})
	var versioned := legacy.duplicate(true)
	var route: Array = legacy.path.duplicate(true)
	for dt in [0.0,0.1,0.4,0.0]:
		check(Enemy.step(legacy,dt,route) == Enemy.step(versioned,dt,route,1), "versioned unchanged path events")
		check(Enemy.snapshot(legacy) == Enemy.snapshot(versioned), "versioned unchanged path preserves movement and supplied position")
	# 같은 길이/시작점/끝점이라도 중간 경유지가 바뀌면 새 경로를 적용한다.
	route = [{"x":0.0,"y":0.0},{"x":0.0,"y":10.0},{"x":10.0,"y":10.0}]
	Enemy.step(legacy,0.0,route)
	Enemy.step(versioned,0.0,route,2)
	check(Enemy.snapshot(legacy) == Enemy.snapshot(versioned), "revision change preserves reroute progress")
	check(not Enemy.snapshot(versioned).has("_path_revision"), "revision cache excluded from snapshot")
	var restored := Enemy.create(Enemy.snapshot(versioned))
	var raw_restored := Enemy.create(versioned)
	check(not restored.has("_path_revision") and not raw_restored.has("_path_revision"), "create never trusts saved revision cache")
	for e in [legacy,versioned,restored]:
		Enemy.update_path(e,[[0,0],[100,0]])
	Enemy.step(legacy,0.1,route)
	Enemy.step(versioned,0.1,route,2)
	Enemy.step(restored,0.1,route,2)
	check(Enemy.snapshot(legacy) == Enemy.snapshot(versioned), "explicit path update invalidates cached revision")
	check(Enemy.snapshot(legacy) == Enemy.snapshot(restored), "restored path resynchronizes on first step")
	# 기존 3인자 API는 같은 배열의 내용 변경도 계속 감지한다.
	route[1].x = 5.0
	Enemy.step(legacy,0.0,route)
	Enemy.step(versioned,0.0,route,3)
	check(Enemy.snapshot(legacy) == Enemy.snapshot(versioned), "legacy content comparison remains compatible")
	for invalid_path in [[], [[0,0]]]:
		Enemy.step(legacy,0.1,invalid_path)
		Enemy.step(versioned,0.1,invalid_path,4)
		check(Enemy.snapshot(legacy) == Enemy.snapshot(versioned), "empty and short path behavior preserved")


func _advance_dot(e: Dictionary,total: float,dt: float) -> Array:
	var events: Array = []
	var remaining := total
	while remaining > 0.000000001:
		var tick := minf(remaining,dt)
		events.append_array(Enemy.step(e,tick))
		remaining -= tick
	return events

func _damage_total(events: Array,kind: String) -> float:
	var damage := 0.0
	for event in events:
		if event.type == "damage" and event.kind == kind: damage += event.damage
	return damage

func _dot_expiry_checks() -> void:
	# The oracle is the continuous active interval, independent of caller dt.
	# Each source burns for its own lifetime: 100*.1 + 50*.37 + 25*.8 = 48.5.
	# The shield takes 15, the other 33.5 enters armor at half (16.75).
	for dt in [1.0/120.0,1.0/60.0,1.0/30.0,4.0/60.0,0.1,0.5,1.0]:
		var suffix := " dt="+str(dt)
		var poisoned := enemy({"speed":0.0,"maxShield":15.0,"shield":15.0,"maxArmor":20.0,"armor":20.0})
		# Three stacks: 120 DPS with a 15% stack bonus for 0.37s = 51.06.
		for stack in range(3): poison(poisoned,40.0,0.37)
		var events := _advance_dot(poisoned,1.0,dt)
		close(_damage_total(events,"poison"),51.06,"poison active interval total"+suffix)
		close(poisoned.shield,0,"poison expiry shield layer"+suffix)
		close(poisoned.armor,0,"poison expiry armor layer"+suffix)
		close(poisoned.hp,983.94,"poison expiry HP overflow"+suffix)
		check(poisoned.shieldBroken,"poison expiry keeps shield break"+suffix)
		check(poisoned.poisonInstances.is_empty(),"poison expiry clears damage state"+suffix)
		close(poisoned.poisonNumberDamage,0,"poison expiry flushes damage number"+suffix)
		var burning := enemy({"speed":0.0,"maxShield":15.0,"shield":15.0,"maxArmor":20.0,"armor":20.0})
		Enemy.add_burn(burning,{"damagePerSecond":100.0,"duration":0.1,"sourceX":1,"sourceY":1})
		Enemy.add_burn(burning,{"damagePerSecond":50.0,"duration":0.37,"sourceX":2,"sourceY":2})
		Enemy.add_burn(burning,{"damagePerSecond":25.0,"duration":0.8,"sourceX":3,"sourceY":3})
		events = _advance_dot(burning,1.0,dt)
		close(_damage_total(events,"burn"),31.75,"burn integrates each source's active interval"+suffix)
		close(burning.shield,0,"burn expiry shield layer"+suffix)
		close(burning.armor,3.25,"burn expiry armor remainder"+suffix)
		close(burning.hp,1000,"burn expiry armor protects HP"+suffix)
		check(burning.burnInstances.is_empty(),"all burn expiries removed"+suffix)
		close(burning.burnNumberDamage,0,"burn expiry flushes damage number"+suffix)
	# Exactly aligned endpoints and zero dt cannot introduce another tick.
	for kind in ["burn","poison"]:
		var e := enemy({"speed":0.0})
		if kind == "burn": Enemy.add_burn(e,{"damagePerSecond":64.0,"duration":0.125})
		else: poison(e,64.0,0.125)
		close(_damage_total(Enemy.step(e,0.0),kind),0,kind+" zero dt does not tick")
		close(e.hp,1000,kind+" zero dt preserves HP")
		# One poison stack carries the 5% stack bonus.
		var lifetime := 8.0 if kind == "burn" else 8.4
		close(_damage_total(Enemy.step(e,0.125),kind),lifetime,kind+" exact boundary has one active interval")
		close(_damage_total(Enemy.step(e,0.5),kind),0,kind+" expired effect cannot tick again")
		close(e.hp,1000.0-lifetime,kind+" exact lifetime damage")
	# Within one source, a weaker effect that ends under a stronger one adds nothing.
	var hidden := enemy({"speed":0.0})
	Enemy.add_burn(hidden,{"damagePerSecond":20.0,"duration":0.1})
	Enemy.add_burn(hidden,{"damagePerSecond":50.0,"duration":0.2})
	close(_damage_total(Enemy.step(hidden,0.5),"burn"),10,"expired weaker burn does not reappear")
	# Different sources each tick for their own lifetime.
	var stacked := enemy({"speed":0.0})
	Enemy.add_burn(stacked,{"damagePerSecond":20.0,"duration":0.1,"sourceX":1,"sourceY":1})
	Enemy.add_burn(stacked,{"damagePerSecond":50.0,"duration":0.2,"sourceX":2,"sourceY":2})
	close(_damage_total(Enemy.step(stacked,0.5),"burn"),12,"different source burns add their lifetimes")
	# Restoring mid-effect preserves the same remaining-time integral.
	var saved := enemy({"speed":0.0,"burnInstances":[{"remaining":0.1,"damagePerSecond":100.0},{"remaining":0.5,"damagePerSecond":50.0}],"poisonRemaining":0.05,"poisonDamagePerSecond":20.0,"poisonStacks":2})
	var restored := Enemy.create(Enemy.snapshot(saved))
	var original_events := Enemy.step(saved,0.5)
	var restored_events := Enemy.step(restored,0.5)
	check(original_events==restored_events,"DoT expiry events roundtrip through saved remaining time")
	# Burn 30, legacy poison as two stacks: 40 DPS with a 10% bonus for 0.05s.
	close(restored.hp,967.8,"restored DoTs use actual active intervals")

func _dot_reapplication_checks() -> void:
	# A new stack keeps its own timer and never refreshes older stacks.
	var e := enemy({"speed":0.0})
	poison(e,10.0,0.2,{"sourceX":1,"sourceY":1})
	Enemy.step(e,0.1)
	poison(e,10.0,0.2,{"sourceX":1,"sourceY":1,"damageMultiplier":2.0})
	check(e.poisonInstances.size()==2,"same-source poison adds a stack")
	close(e.poisonInstances[0].remaining,0.1,"new stack does not refresh older stack")
	close(e.poisonInstances[1].remaining,0.2,"new stack keeps its own duration")
	var before: float = e.hp
	var events := Enemy.step(e,0.3)
	# Two stacks for 0.1s (20 DPS, +10%), then one stack for 0.1s (10 DPS, +5%).
	close(before-e.hp,2.2+1.05,"stack bonus follows stacks active in each slice")
	check(e.poisonInstances.is_empty(),"all independent stacks expire")
	var numbers := events.filter(func(event): return event.type=="damageNumber" and event.kind=="poison")
	check(numbers.size()==1 and numbers[0].damageMultiplier==2.0,"poison number shows the strongest active display multiplier")
	# The same lifetime split over smaller steps gives the same damage.
	for dt in [0.3,0.1,1.0/60.0]:
		var split := enemy({"speed":0.0})
		poison(split,10.0,0.1)
		poison(split,10.0,0.3)
		var split_before: float = split.hp
		_advance_dot(split,0.3,dt)
		close(split_before-split.hp,2.2+2.1,"poison stack expiry independent of dt "+str(dt))
	# Different sources keep separate stack counts and bonuses.
	e = enemy({"speed":0.0})
	poison(e,10.0,1.0,{"sourceX":1,"sourceY":1})
	poison(e,10.0,1.0,{"sourceX":1,"sourceY":1})
	poison(e,10.0,1.0,{"sourceX":2,"sourceY":2})
	events = Enemy.step(e,0.1)
	close(1000.0-e.hp,2.2+1.05,"sources do not share stack bonus")
	var poison_damages := events.filter(func(event): return event.type=="damage" and event.kind=="poison")
	check(poison_damages.size()==2 and poison_damages[0].sourceX==2 and poison_damages[1].sourceX==1,"poison damage keeps per-source attribution, latest source first")
	# The source cap replaces only the stack with the least time left.
	e = enemy({"speed":0.0})
	for i in range(Enemy.POISON_STACK_CAP): poison(e,1.0,1.0+i*0.1,{"sourceX":3,"sourceY":3})
	poison(e,1.0,0.5,{"sourceX":4,"sourceY":4})
	poison(e,1.0,9.0,{"sourceX":3,"sourceY":3})
	var capped: Array = e.poisonInstances.filter(func(p): return p.sourceX==3)
	check(capped.size()==Enemy.POISON_STACK_CAP,"source poison stacks stop at the cap")
	var shortest := INF
	for p in capped: shortest = minf(shortest,p.remaining)
	close(shortest,1.1,"cap replaces the stack with the least time left")
	check(e.poisonInstances.filter(func(p): return p.sourceX==4).size()==1,"another source is unaffected by the cap")
	# K3 speed raises DPS and shortens the stack, keeping its total.
	e = enemy({"speed":0.0})
	poison(e,20.0,0.3,{"speedMultiplier":1.5})
	close(e.poisonInstances[0].damagePerSecond,30,"poison speed raises stack DPS")
	close(e.poisonInstances[0].remaining,0.2,"poison speed shortens stack lifetime")
	# Legacy scalar poison restores as detached stacks once.
	var legacy := enemy({"speed":0.0,"poisonRemaining":0.4,"poisonDamagePerSecond":5.0,"poisonStacks":3,"poisonDamageMultiplier":1.5,"poisonDamageOverTimeIncreaseMultiplier":2.0})
	check(legacy.poisonInstances.size()==3,"legacy poison stacks become independent stacks")
	check(legacy.poisonStacks==0 and legacy.poisonRemaining==0 and legacy.poisonDamagePerSecond==0 and not legacy.has("poisonDamageOverTimeIncreaseMultiplier"),"legacy poison fields are cleared after conversion")
	for p in legacy.poisonInstances:
		check(p.sourceX==null and p.damageMultiplier==1.5 and p.damageOverTimeIncreaseMultiplier==2.0,"legacy poison keeps display and original layer")
	var reloaded := Enemy.create(Enemy.snapshot(legacy))
	check(reloaded.poisonInstances.size()==3,"converted poison is not restored twice")
	e = enemy({"speed":0.0})
	Enemy.add_burn(e,{"damagePerSecond":60.0,"duration":0.1,"sourceX":1,"sourceY":2})
	Enemy.step(e,0.04)
	Enemy.add_burn(e,{"damagePerSecond":30.0,"duration":0.2,"damageMultiplier":2.0,"sourceX":1,"sourceY":2,"ignoreArmorReduction":true})
	check(e.burnInstances.size()==1,"same source burn refresh keeps one instance")
	close(e.burnInstances[0].damagePerSecond,60,"burn refresh keeps stronger DPS")
	close(e.burnInstances[0].remaining,0.2,"burn refresh extends remaining duration")
	close(e.burnInstances[0].damageMultiplier,2,"burn refresh keeps maximum display multiplier")
	check(e.burnInstances[0].ignoreArmorReduction,"burn refresh keeps saved armor bypass flag")
	Enemy.step(e,0.5)
	close(e.hp,985.6,"refreshed burn clips extended lifetime")
	Enemy.add_burn(e,{"damagePerSecond":30.0,"duration":0.1,"sourceX":1,"sourceY":2})
	Enemy.step(e,0.5)
	close(e.hp,982.6,"same source after expiry starts new burn")

func _dot_expiry_event_checks() -> void:
	var e := enemy({"speed":0.0})
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":0.1,"sourceX":1,"sourceY":1})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":0.5,"sourceX":2,"sourceY":2})
	poison(e,20.0,0.1)
	var events := Enemy.step(e,0.5)
	var damages := events.filter(func(event): return event.type=="damage")
	check(damages.size()==3,"two source burns precede the poison tick")
	if damages.size()==3:
		check(damages[0].kind=="burn" and damages[0].sourceX==2,"latest source burns first")
		check(damages[1].kind=="burn" and damages[1].sourceX==1,"earlier source keeps its own attribution")
		check(damages[2].kind=="poison","burn intervals remain before poison")
		close(damages[0].damage,25,"latest source burn event damage")
		close(damages[1].damage,10,"earlier source clips to its lifetime")
		close(damages[2].damage,2.1,"poison event clips duration")
	var numbers := events.filter(func(event): return event.type=="damageNumber")
	check(numbers.size()==2,"expiry keeps one aggregate number per DoT kind")
	if numbers.size()==2:
		close(numbers[0].damage,35,"burn number aggregates both sources")
		close(numbers[1].damage,2.1,"poison number uses clipped interval")
		check(numbers[0].kind=="burn" and numbers[1].kind=="poison","damage-number order stays burn then poison")
	# Full-step regeneration still precedes every burn interval; breaking is final.
	# 30 burn: 10 breaks the regenerated shield, 20 enters 5 armor at half.
	e = enemy({"speed":0.0,"maxShield":100.0,"shield":5.0,"shieldRegenRate":0.1,"maxArmor":5.0,"armor":5.0})
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":0.1})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":0.5})
	Enemy.step(e,0.5)
	close(e.shield,0,"regen occurs once before piecewise burn")
	check(e.shieldBroken,"piecewise burn latches shield break")
	close(e.armor,0,"burn remainder crosses broken shield into armor")
	close(e.hp,995,"burn remainder reaches HP after armor")
	Enemy.step(e,0.5)
	close(e.shield,0,"piecewise-broken shield never regenerates")
	e = enemy({"speed":0.0,"maxShield":100.0,"shield":5.0,"shieldRegenRate":0.1})
	poison(e,40.0,0.1)
	Enemy.step(e,0.5)
	close(e.shield,5.8,"poison expiry avoids excess shield damage after regen")
	check(not e.shieldBroken,"short poison does not falsely latch shield break")
	Enemy.step(e,1.0)
	close(e.shield,15.8,"unbroken shield regenerates after poison expiry")
	# A kill by the source that ticks second belongs to that source, once only.
	e = enemy({"hp":12.0})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":0.5,"sourceX":2,"sourceY":2})
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":0.1,"sourceX":1,"sourceY":1})
	poison(e,100.0,0.5)
	events = Enemy.step(e,0.3)
	check(count(events,"killed")==1,"second source kills exactly once before poison")
	var kills := events.filter(func(event): return event.type=="killed")
	if kills.size()==1:
		var transfer: Dictionary = kills[0].burnTransfer
		check(not transfer.is_empty(),"second source kill retains a burn transfer")
		if not transfer.is_empty():
			check(transfer.sourceX==2,"second source kill uses that source")
			close(transfer.remaining,0.2,"kill transfer retains end-of-step lifetime")
			Enemy.step(e,0.1)
			close(transfer.remaining,0.2,"kill transfer remains an independent snapshot")
	check(events.size()==3 and events[0].type=="damage" and events[1].type=="killed" and events[2].type=="damage","kill is emitted before its lethal damage event")
	close(_damage_total(events,"burn"),12,"burn damage events clamp to actual HP on death")
	close(_damage_total(events,"poison"),0,"poison after burn death does not deal damage")
	close(e.x,0,"death by a burn prevents movement")
	check(count(Enemy.step(e,0.5),"killed")==0,"repeated dead step never repeats burn kill")

	# A short poison must not kill using damage from its inactive remainder.
	e = enemy({"hp":0.5})
	poison(e,10.0,0.01)
	events = Enemy.step(e,0.5)
	close(e.hp,0.395,"short poison does not overkill past its lifetime")
	check(count(events,"killed")==0,"short poison does not emit a false kill")
	close(e.x,5,"surviving poison expiry still permits movement")
	poison(e,40.0,0.1)
	events = Enemy.step(e,0.5)
	check(count(events,"killed")==1,"lethal poison reapplication kills exactly once")
	close(e.hp,0,"lethal poison clamps HP to zero")
	close(e.x,5,"poison death prevents movement")
	check(events.size()==2 and events[0].type=="killed" and events[1].type=="damage","poison kill precedes its damage event")
	check(count(Enemy.step(e,0.5),"killed")==0,"dead poison does not kill twice")
	# Equal-DPS sources both burn; the latest source still ticks first.
	e = enemy({"speed":0.0})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":0.5,"sourceX":1,"sourceY":1})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":0.1,"sourceX":2,"sourceY":2})
	events = Enemy.step(e,0.5)
	damages = events.filter(func(event): return event.type=="damage")
	close(e.hp,970,"equal-DPS sources each burn for their lifetime")
	check(damages.size()==2,"equal-DPS sources have separate attributed intervals")
	if damages.size()==2:
		check(damages[0].sourceX==2 and damages[1].sourceX==1,"latest source tick order holds for equal DPS")
	# Equal-DPS candidates of one source keep the latest-instance tie break.
	e = enemy({"speed":0.0})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":0.5})
	Enemy.add_burn(e,{"damagePerSecond":50.0,"duration":0.1})
	events = Enemy.step(e,0.5)
	close(e.hp,975,"same-source equal-DPS burn continues after selected instance expires")

func _target_multiplier_checks() -> void:
	var e := enemy({"speed":0.0,"maxShield":20.0,"shield":20.0,"maxArmor":100.0,"armor":100.0})
	Enemy.add_rift_mark(e,0.25,2.0)
	var result := Enemy.apply_hit(e,{"damage":40.0},1.2)
	# Target 1.2 and mark 1.25 apply before shield/armor; only remaining 40
	# enters armor reduction, with pressure sqrt(100)*3 = 30.
	var armor_loss := 40.0*(0.12+0.88*40.0/70.0)
	close(result.actualDamage,20.0+armor_loss,"target bonus precedes shield and armor")
	close(e.armor,100.0-armor_loss,"target bonus does not bypass armor")
	var plain := Enemy.apply_hit(enemy(),{"damage":40.0})
	close(plain.actualDamage,40.0,"neutral target multiplier preserves existing API")

func _training_dot_checks() -> void:
	var e := enemy({"speed":0.0})
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":0.2,"sourceX":0,"sourceY":0,"damageOverTimeIncreaseMultiplier":2.0})
	Enemy.add_burn(e,{"damagePerSecond":95.0,"duration":0.5,"sourceX":1,"sourceY":0})
	Enemy.step(e,0.1,[],-1,1.0,0.0)
	close(e.hp,980.5,"training0 burns each source at raw DPS")
	# 100*(1+.3/2) + 95*1.3: each source divides training by its own layer.
	Enemy.step(e,0.1,[],-1,1.0,0.3)
	close(e.hp,956.65,"training purchase applies per source original layer")
	var transfer := Enemy.burn_transfer(e,{"x":1,"y":0},0.3)
	close(transfer.damagePerSecond,95.0,"transfer keeps untrained raw DPS")
	check(not transfer.has("damageOverTimeIncreaseMultiplier"),"neutral burn metadata remains absent")
	var restored := Enemy.create(Enemy.snapshot(e))
	Enemy.step(restored,0.1,[],-1,1.2,0.3)
	close(restored.hp,941.83,"restored raw burn uses current training and target layer once")
	# Same-source different additive layers can reverse strength after purchase.
	e = enemy({"speed":0.0})
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":0.2,"sourceX":0,"sourceY":0,"damageOverTimeIncreaseMultiplier":2.0,"damageMultiplier":1.2})
	Enemy.add_burn(e,{"damagePerSecond":95.0,"duration":1.0,"sourceX":0,"sourceY":0,"ignoreArmorReduction":true})
	check(e.burnInstances.size()==2,"same source retains candidates with distinct original layers")
	for burn in e.burnInstances:
		close(burn.remaining,1.0,"same-source max lifetime refreshes all candidates")
		close(burn.damageMultiplier,1.2,"same-source max display multiplier refreshes all candidates")
		check(burn.ignoreArmorReduction,"same-source armor flag refreshes all candidates")
	close(Enemy.burn_transfer(e,{"x":0,"y":0},0.0).damagePerSecond,100.0,"same-source initial strongest raw selected")
	close(Enemy.burn_transfer(e,{"x":0,"y":0},0.3).damagePerSecond,95.0,"same-source transfer selects current trained strongest")
	Enemy.add_burn(e,{"damagePerSecond":90.0,"duration":0.5,"sourceX":0,"sourceY":0})
	check(e.burnInstances.size()==2,"same original layer still merges one candidate")
	Enemy.step(e,0.1,[],-1,1.0,0.3)
	close(e.hp,987.65,"same-source candidates never stack damage")
	Enemy.add_burn(e,{"damagePerSecond":97.0,"duration":0.5,"sourceX":0,"sourceY":0})
	check(e.burnInstances.size()==2,"same-layer stronger reapplication does not add a candidate")
	close(Enemy.burn_transfer(e,{"x":0,"y":0},0.3).damagePerSecond,97.0,"same-layer stronger reapplication replaces its raw DPS")
	var candidate_restore := Enemy.create(Enemy.snapshot(e))
	check(candidate_restore.burnInstances.size()==2,"snapshot restores both same-source original-layer candidates")
	Enemy.step(candidate_restore,0.1,[],-1,1.0,0.3)
	close(candidate_restore.hp,975.04,"restored same-source candidates choose current training strongest")
	Enemy.clear_burn_source(e,{"x":0,"y":0})
	for burn in e.burnInstances: check(burn.sourceX==null and burn.sourceY==null,"removing source clears all candidate attribution")
	# Detached candidates of a removed turret still never stack with each other.
	e = enemy({"speed":0.0})
	Enemy.add_burn(e,{"damagePerSecond":100.0,"duration":1.0,"sourceX":5,"sourceY":5,"damageOverTimeIncreaseMultiplier":2.0})
	Enemy.add_burn(e,{"damagePerSecond":95.0,"duration":1.0,"sourceX":5,"sourceY":5})
	Enemy.add_burn(e,{"damagePerSecond":40.0,"duration":1.0,"sourceX":6,"sourceY":6})
	Enemy.clear_burn_source(e,{"x":5,"y":5})
	Enemy.step(e,0.1)
	close(e.hp,986.0,"detached candidates keep one strongest beside other sources")
	# Poison supports the same optional original layer; legacy DPS uses neutral1.
	for increase in [1.0,2.0]:
		e = enemy({"speed":0.0})
		poison(e,20.0,0.2,{"speedMultiplier":1.5,"damageOverTimeIncreaseMultiplier":increase})
		check(e.poisonInstances[0].has("damageOverTimeIncreaseMultiplier") == (increase!=1.0),"poison original layer is optional")
		Enemy.step(e,0.2,[],-1,1.2,0.3)
		close(e.hp,1000.0-4.0*(1.0+0.3/increase)*1.05*1.2,"poison training same-layer add before stack bonus, amplification and clipped expiry")
		check(e.poisonInstances.is_empty(),"expired poison clears original layer metadata")

func _boss_slow_checks() -> void:
	# Bosses keep half of every slow's reduction; stronger affix resistance wins.
	for raw in [{"type":"boss"},{"type":"forgeBoss"},{"isBoss":true}]:
		var boss := enemy(raw)
		Enemy.add_slow(boss,0.5,1.0)
		Enemy.step(boss,0.5)
		close(boss.x,3.75,"boss resists half of a slow "+str(raw))
	var normal := enemy()
	Enemy.add_slow(normal,0.5,1.0)
	Enemy.step(normal,0.5)
	close(normal.x,2.5,"ordinary enemy takes the full slow")
	var resistant := enemy({"type":"boss","slowResistance":0.8})
	Enemy.add_slow(resistant,0.5,1.0)
	Enemy.step(resistant,0.5)
	close(resistant.x,4.5,"stronger slow resistance is kept on a boss")
	var stunned := enemy({"type":"boss","stunRemaining":0.5})
	Enemy.step(stunned,0.5)
	close(stunned.x,0,"boss slow resistance leaves stun intact")
