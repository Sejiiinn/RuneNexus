extends SceneTree
## Production frozen-build stockpile: two charges, actual fire, checkpoint and fixed clock.
const Runtime = preload("res://combat/native_combat_runtime.gd")
const STEP := 1.0 / 60.0
var checks := 0
var failures: Array = []
var sniper: Dictionary = {}
var arrow: Dictionary = {}
var lightning: Dictionary = {}

func _initialize() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	for fixture: Dictionary in fixtures:
		var input: Dictionary = fixture.input
		if input.level != 1 or not input.gems.is_empty(): continue
		if input.definition.type == "sniper" and sniper.is_empty(): sniper = input.duplicate(true)
		if input.definition.type == "arrow" and arrow.is_empty(): arrow = input.duplicate(true)
		if input.definition.type == "lightning" and lightning.is_empty(): lightning = input.duplicate(true)
	sniper.level = 5
	sniper.definition.criticalChance = 0.0
	arrow.definition.criticalChance = 0.0
	_charge_checks()
	_aim_and_shot_checks()
	_lifecycle_checks()
	_lightning_checks()
	_all_turret_checks(fixtures)
	_cadence_checks()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func close(actual: float, expected: float, label: String) -> void:
	check(absf(actual-expected) < 0.00000001, label + ": " + str(actual) + " != " + str(expected))

func raw_turret(input: Dictionary) -> Dictionary:
	return {"id":1,"position":[0,0],"statInput":input.duplicate(true),"state":{"x":0,"y":0}}

func make_runtime(input: Dictionary, enabled: bool = true):
	var r = Runtime.new()
	var configured := input.duplicate(true)
	configured.coreEffects = {"hasStockpileFire":enabled}
	r.start(1,{"seed":71423,"turrets":[raw_turret(configured)]},{"clock":"godot","phase":"wave","running":true,"speed":1.0})
	if enabled: check(r.stockpile_firing_state(1).enabled,"frozen build automatically enables stockpile")
	return r

func target(r, id: int = 1) -> void:
	r._spawn({"id":id,"x":50.0,"y":0.0,"hp":100000.0,"maxHp":100000.0,"speed":0.0,"collisionRadius":1.0})

func _charge_checks() -> void:
	var r = make_runtime(sniper)
	var t: Dictionary = r.turrets["1"]
	var interval: float = r.stockpile_firing_state(1).chargeInterval
	close(interval,1.0/t.stats.attackRate+t.stats.aimDuration,"interval is current normal cooldown plus normal aim")
	t.cooldown = 1.0
	r._tick_turret(t,0.6)
	check(t.stockpileCharges == 0 and t.stockpileIdleElapsed == 0.0,"no charging during cooldown")
	r._tick_turret(t,0.5)
	close(t.stockpileIdleElapsed,0.1,"crossing cooldown counts only remaining ready time")
	r._tick_turret(t,interval-0.1001)
	check(t.stockpileCharges == 0,"no early charge")
	r._tick_turret(t,0.0001)
	check(t.stockpileCharges == 1,"one charge exactly at normal interval")
	r._tick_turret(t,interval*0.5)
	check(t.stockpileCharges == 1,"one charge never accelerates its own charging interval")
	close(t.stockpileIdleElapsed,interval*0.5,"partial second interval is tracked")
	r._tick_turret(t,interval*20)
	check(t.stockpileCharges == 2 and t.stockpileIdleElapsed == 0.0,"cap is two without overflow banking")
	var refreshed := raw_turret(sniper)
	refreshed.statInput.coreEffects = {"hasStockpileFire":true}
	r._turret(refreshed)
	check(r.stockpile_firing_state(1).charges == 2,"configuration refresh retains completed charges")
	r._turret(refreshed)
	check(r.stockpile_firing_state(1).charges == 2,"repeated configuration is idempotent")
	refreshed.statInput.coreEffects.hasStockpileFire = false
	r._turret(refreshed)
	check(r.stockpile_firing_state(1).charges == 0,"a replaced build without K2 clears charges")
	check(r.stockpile_firing_state(99).is_empty(),"unknown turret observation is empty")
	var normal = make_runtime(sniper,false)
	normal._tick_turret(normal.turrets["1"],interval*20)
	check(normal.stockpile_firing_state(1).charges == 0,"feature is off for ordinary turrets")
	# Ordinary stat changes affect the interval, stockpile never changes stats.
	var faster := sniper.duplicate(true)
	faster.corePassiveTurretAttackRateMultiplier = 1.25
	faster.gems = ["attackSpeed","aimSpeed"]
	var buffed = make_runtime(faster)
	var state: Dictionary = buffed.stockpile_firing_state(1)
	close(state.chargeInterval,1.0/buffed.turrets["1"].stats.attackRate+buffed.turrets["1"].stats.aimDuration,"ordinary buffs contribute to charge interval")
	check(state.chargeInterval < interval,"ordinary faster rate/aim reduces interval")
	var no_aim = make_runtime(arrow)
	close(no_aim.stockpile_firing_state(1).chargeInterval,1.0/no_aim.turrets["1"].stats.attackRate,"no-aim turret charges on cooldown only")
	var delayed = make_runtime(lightning)
	check(delayed.stockpile_firing_state(1).enabled,"delayed lightning uses the production frozen perk")
	close(delayed.stockpile_firing_state(1).normalAimDuration,0.3,"lightning ordinary prefire contributes to normal interval")

func _aim_and_shot_checks() -> void:
	var r = make_runtime(sniper)
	var t: Dictionary = r.turrets["1"]
	var interval: float = r.stockpile_firing_state(1).chargeInterval
	var aim: float = t.stats.aimDuration
	var normal_stats: Dictionary = t.stats.duplicate(true)
	r._tick_turret(t,interval*1.5)
	target(r)
	r._tick_turret(t,aim/6.0)
	close(t.stockpileIdleElapsed,0.0,"target acquisition clears partial idle interval")
	check(t.stockpileCharges == 1 and t.shotSequence == 0,"acquiring/aiming does not consume a charge")
	close(t.aimProgress,aim/4.0,"one charge gives exactly 1.5x aim progress")
	r.enemies.clear()
	r._tick_turret(t,interval*0.25)
	check(t.stockpileCharges == 1 and t.aimProgress == 0.0,"target loss resets aim while preserving charge")
	close(t.stockpileIdleElapsed,interval*0.25,"target loss starts a fresh continuous interval")
	target(r,2)
	r._tick_turret(t,aim/6.0)
	check(t.stockpileCharges == 1,"reacquisition preserves charge")
	close(t.aimProgress,aim/4.0,"reacquisition restarts accelerated aim")
	close(t.stockpileIdleElapsed,0.0,"reacquisition clears partial idle time again")
	# Reset only the test target/aim, then compare identical RNG per-shot jitter.
	r.enemies.clear()
	t.aimProgress = 0.0
	r._tick_turret(t,interval)
	check(t.stockpileCharges == 2,"second charge is independently earned")
	target(r,3)
	var reference = make_runtime(sniper,false)
	target(reference,3)
	r._tick_turret(t,aim/1.5-0.0001)
	check(t.shotSequence == 0 and t.stockpileCharges == 2,"two charges do not stack the speed multiplier")
	r._tick_turret(t,0.0001+0.00000001)
	reference._tick_turret(reference.turrets["1"],aim+0.00000001)
	check(t.shotSequence == 1 and t.stockpileCharges == 1,"actual first shot consumes exactly one charge")
	close(t.cooldown,reference.turrets["1"].cooldown/1.5,"boosted shot starts normal randomized cooldown divided by 1.5")
	close(r.enemies["3"].hp,reference.enemies["3"].hp,"damage and critical calculation are unchanged")
	check(t.stats == normal_stats,"stockpile never mutates ordinary stats")
	# Finish the cooldown without donating an extra aim step to this test.
	t.cooldown = 0.0
	r._tick_turret(t,aim/1.5+0.00000001)
	check(t.shotSequence == 2 and t.stockpileCharges == 0,"actual second shot consumes final charge")
	check(t.cooldown < 1.05/t.stats.attackRate/1.5+0.00000001,"last charged shot still gets accelerated following cooldown")
	t.cooldown = 0.0
	r._tick_turret(t,aim/1.5)
	check(t.shotSequence == 2,"third aim returns to normal speed")
	r._tick_turret(t,aim/3.0+0.00000001)
	check(t.shotSequence == 3,"third shot completes at normal aim duration")
	check(t.cooldown >= 0.95/t.stats.attackRate,"third shot restores normal following cooldown")
	var projectile = make_runtime(arrow)
	projectile._tick_turret(projectile.turrets["1"],projectile.stockpile_firing_state(1).chargeInterval*2)
	target(projectile)
	projectile._tick_turret(projectile.turrets["1"],0.01)
	check(projectile.turrets["1"].stockpileCharges == 1 and projectile.projectiles.size() == 1,"projectile launch consumes one charge without needing a hit")

func _lifecycle_checks() -> void:
	var r = make_runtime(sniper)
	for i in range(30): r.advance_session(STEP)
	var before: Dictionary = r.stockpile_firing_state(1)
	r.apply_batch(1,[],{"paused":true},0)
	r.advance_session(100.0)
	check(r.stockpile_firing_state(1) == before,"paused wall time cannot charge")
	r.apply_batch(1,[],{"paused":false,"phase":"reward"},0)
	r.advance_session(100.0)
	check(r.stockpile_firing_state(1) == before,"reward wall time cannot charge")
	r.apply_batch(1,[],{"phase":"wave"},0)
	r.advance_session(STEP)
	close(r.stockpile_firing_state(1).idleElapsed,float(before.idleElapsed)+STEP,"resume adds only actual simulated time")
	var frozen: Dictionary = r.stockpile_firing_state(1)
	r.running = false
	r._tick_turret(r.turrets["1"],100.0)
	check(r.stockpile_firing_state(1) == frozen,"non-running preparation never earns charges")
	r.running = true
	r._tick_turret(r.turrets["1"],r.stockpile_firing_state(1).chargeInterval * 2.5)
	var saved: Dictionary = r.snapshot().turrets[0]
	check(saved.stockpileCharges == 2,"snapshot exports completed earned charges")
	var raw := raw_turret(sniper)
	raw.statInput.coreEffects = {"hasStockpileFire":true}
	raw.state.stockpileCharges = saved.stockpileCharges
	raw.state.stockpileIdleElapsed = 999.0
	r.start(2,{"turrets":[raw]},{"clock":"godot","phase":"wave","running":true})
	check(r.stockpile_firing_state(1).enabled and r.stockpile_firing_state(1).charges == 2,"new epoch restores earned charges from frozen build")
	close(r.stockpile_firing_state(1).idleElapsed,0.0,"checkpoint cannot replay a partial continuous idle interval")
	var disabled := raw_turret(sniper)
	disabled.state.stockpileCharges = 2
	r.start(3,{"turrets":[disabled]},{"clock":"godot","phase":"wave","running":true})
	check(not r.stockpile_firing_state(1).enabled and r.stockpile_firing_state(1).charges == 0,"legacy frozen build cannot gain perk through charge payload")

func _lightning_checks() -> void:
	var r = make_runtime(lightning)
	var t: Dictionary = r.turrets["1"]
	r._tick_turret(t,r.stockpile_firing_state(1).chargeInterval * 2)
	target(r)
	r._tick_turret(t,0.01)
	check(t.stockpileCharges == 2 and t.stockpilePrefiring,"lightning prefire reserves without consuming")
	close(r.delayed[0].timer,0.2,"stored lightning aim is accelerated by 1.5")
	var canceled: Dictionary = r.delayed.pop_front()
	r.enemies.clear()
	r._release(canceled)
	check(t.stockpileCharges == 2 and not t.stockpilePrefiring,"canceled discharge preserves completed charges")
	t.cooldown = 0.0
	target(r,2)
	r._tick_turret(t,0.01)
	var base: float = t.lastBaseCooldown
	var firing: Dictionary = r.delayed.pop_front()
	r._release(firing)
	check(t.stockpileCharges == 1 and not t.stockpilePrefiring,"actual lightning discharge consumes one charge")
	close(t.cooldown,base / 1.5,"actual discharge accelerates following cooldown")
	check(r.enemies["2"].hp < r.enemies["2"].maxHp,"lightning charge is spent only alongside actual damage")
	if not r.delayed.is_empty():
		r._release(r.delayed.pop_front())
		check(t.stockpileCharges == 1,"lightning chain jumps never spend more charges")

func _all_turret_checks(fixtures: Array) -> void:
	var seen := {}
	for fixture: Dictionary in fixtures:
		var input: Dictionary = fixture.input
		var type: String = input.definition.type
		if input.level != 1 or not input.gems.is_empty() or seen.has(type): continue
		seen[type] = true
		var r = make_runtime(input)
		var t: Dictionary = r.turrets["1"]
		r._tick_turret(t,r.stockpile_firing_state(1).chargeInterval)
		check(t.stockpileCharges == 1,type+" earns a stored shot through native production path")
		target(r)
		r._tick_turret(t,maxf(0.001,r.stockpile_firing_state(1).normalAimDuration / 1.5 + 1e-8))
		if type == "lightning": r._release(r.delayed.pop_front())
		check(t.stockpileCharges == 0,type+" real shot spends one stored charge")
	check(seen.size() == 6,"all six production turret types covered")

func replay(pattern: Array, speed: float) -> Dictionary:
	var r = make_runtime(sniper)
	r.apply_batch(1,[],{"speed":speed},0)
	# Inputs occur on game ticks, independent of render cadence and speed.
	r.step_completed.connect(func():
		if r.simulation_tick == 360: target(r)
		if r.simulation_tick == 390: r.enemies.clear()
		if r.simulation_tick == 420: target(r,2)
		if r.simulation_tick == 1200: r.apply_batch(1,[],{"paused":true},0))
	var index := 0
	while r.simulation_tick < 1200:
		r.advance_session(float(pattern[index%pattern.size()]))
		index += 1
	var t: Dictionary = r.turrets["1"]
	return {"stockpile":r.stockpile_firing_state(1),"shots":t.shotSequence,"aim":t.aimProgress,"cooldown":t.cooldown,"damage":t.directDamageDealt,"rng":r.rng.state,"enemies":r.snapshot().enemies}

func _cadence_checks() -> void:
	var reference := replay([STEP],1.0)
	check(reference.shots > 2 and reference.damage > 0,"fixed-clock scenario actually spends charges and damages enemies")
	for pattern in [[1.0/120.0],[STEP],[1.0/30.0],[1.0/20.0],[0.003,0.117,0.2,0.007,STEP]]:
		for speed in [1.0,2.0,4.0]:
			check(replay(pattern,speed) == reference,"stockpile combat is exact across cadence " + str(pattern) + " speed " + str(speed))
