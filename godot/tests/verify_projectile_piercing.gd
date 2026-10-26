extends SceneTree
## Maintained native-path regression: additive pierces, swept collisions, and
## terminal explosion/chain semantics. Uses authored inputs and the real runtime.
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Catalog = preload("res://content/content_catalog.gd")
var catalog = Catalog.new()
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	check(catalog.load_catalog(), "authored catalog loads")
	if not catalog.is_loaded(): finish(); return
	stat_checks()
	swept_checks()
	lifecycle_checks()
	status_checks()
	explosion_checks()
	chain_checks()
	multishot_checks()
	broadphase_checks()
	cadence_checks()
	finish()

func finish() -> void:
	print("PROJECTILE_PIERCING checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func input_for(type: String = "arrow", gems: Array = ["piercing"]) -> Dictionary:
	var input: Dictionary = catalog.turret(type, {"tileSize":48.0})
	input.gems = gems.duplicate()
	input.definition.damage = 100.0
	input.definition.criticalChance = 0.0
	input.definition.range = 300.0
	input.definition.projectileSpeed = 600.0
	return input

func enemy(id: int, x: float, y: float = 0.0, radius: float = 1.0) -> Dictionary:
	return {"id":id, "hp":1000.0, "maxHp":1000.0, "x":x, "y":y, "collisionRadius":radius, "speed":0.0, "path":[]}

func fired(input: Dictionary, rows: Array):
	var runtime = Runtime.new()
	runtime.rng.seed = 431
	var accepted: Dictionary = runtime.process_command({"epoch":1,"sequence":0,"dt":0.0,"bootstrap":{"tileSize":48.0,"boardDistanceScale":1.0,"enemies":rows,"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{"x":0,"y":0}}]}})
	check(accepted.accepted, "native bootstrap accepted")
	runtime._tick_turret(runtime.turrets["1"], 0.0)
	check(runtime.projectiles.size() == int(runtime.turrets["1"].stats.projectileCount), "native firing creates every projectile")
	return runtime

func move(runtime, distance: float, broadphase: Dictionary = {}) -> void:
	var moving: Array = runtime.projectiles
	runtime.projectiles = []
	for projectile: Dictionary in moving:
		runtime._move_projectile(projectile, distance / float(projectile.attack.projectileSpeed), broadphase)

func damage(runtime, ids: Array) -> Array:
	var result: Array = []
	for id in ids: result.append(1000.0 - float(runtime.enemies[str(id)].hp))
	return result

func impact_count(runtime, kind: String) -> int:
	var count := 0
	for effect: Dictionary in runtime.visual_effects:
		if effect.kind == kind: count += 1
	return count

func stat_checks() -> void:
	for type in ["arrow", "cannon", "magic"]:
		var input := input_for(type)
		var stats := Stats.stats_at(input, 1)
		check(stats.get("pierceCount", -1) == 2, type + " piercing adds exactly two continuations")
		check(Stats.firing_stats(input, stats, 1.0).get("pierceCount", -1) == 2, type + " firing snapshot retains pierces")
		input.gems = []
		check(Stats.stats_at(input, 1).get("pierceCount", -1) == 0, type + " legacy no-gem behavior has zero pierces")
	var amplified := input_for()
	amplified.moduleEffect.gemEffectIncreaseRate = 9.0
	amplified.passiveNumericGemEffectMultiplier = 8.0
	check(Stats.stats_at(amplified, 1).pierceCount == 2, "rule count ignores numeric gem amplification")
	amplified.definition.pierceCount = 1
	amplified.attackModifiers = [{"pierceCount":3}]
	check(Stats.stats_at(amplified, 1).pierceCount == 6, "native and future attack modifiers compose additively")
	check(Stats.shared_stats_at(amplified, 1).pierceCount == 6, "shared stats preserve additive modifier result")
	for type in ["sniper", "frost", "lightning"]:
		check(Stats.stats_at(input_for(type), 1).pierceCount == 0, type + " non-projectile capability cannot pierce")
	var future := input_for()
	future.definition.type = "futureProjectileTower"
	future.definition.attackCapabilities = ["projectile"]
	var runtime = fired(future, [enemy(1,30),enemy(2,60),enemy(3,90),enemy(4,120)])
	move(runtime, 150)
	check(damage(runtime, [1,2,3,4]) == [100.0,100.0,100.0,0.0], "future authored projectile type uses generic firing and modifiers")

func swept_checks() -> void:
	# Reverse insertion order and a later acquisition target must not reorder
	# direct hits or consume a separate simulation frame per collision.
	var runtime = fired(input_for(), [enemy(3,90),enemy(4,120),enemy(2,60),enemy(1,30)])
	var projectile: Dictionary = runtime.projectiles[0]
	move(runtime, 200)
	check(damage(runtime,[1,2,3,4]) == [100.0,100.0,100.0,0.0], "one swept step hits nearest three at full damage")
	check(projectile.excluded == ["1","2","3"], "exclusions record spatial order, independent of insertion")
	check(runtime.projectiles.is_empty() and projectile.pierces == 0, "third distinct hit terminates exactly once")
	check(runtime.turrets["1"].directDamageDealt == 300.0, "all pierced hits retain direct accounting")
	var partial = fired(input_for(), [enemy(1,30),enemy(2,60),enemy(3,90)])
	var p: Dictionary = partial.projectiles[0]
	var budget: float = p.remaining
	move(partial, 40)
	check(damage(partial,[1,2,3]) == [100.0,0.0,0.0] and p.pierces == 1, "first hit consumes one pierce only")
	check(p.position.is_equal_approx(Vector2(40,0)) and is_equal_approx(p.remaining,budget-40), "same-tick remainder preserves distance and straight flight")
	move(partial, 0)
	check(damage(partial,[1,2,3]) == [100.0,0.0,0.0], "zero-distance update cannot repeat a pierced target")
	move(partial, 100)
	check(damage(partial,[1,2,3]) == [100.0,100.0,100.0], "later ticks continue without damage decay")
	var overlap = fired(input_for(), [enemy(9,0),enemy(4,0),enemy(7,0),enemy(2,0)])
	var overlap_p: Dictionary = overlap.projectiles[0]
	move(overlap, 0)
	check(overlap_p.excluded == ["9","4","7"] and damage(overlap,[9,4,7,2]) == [100.0,100.0,100.0,0.0], "starting overlaps resolve once each in stable tie order")
	check(overlap.projectiles.is_empty(), "zero-length overlapping sweep terminates without looping")
	var ordinary = fired(input_for("arrow", []), [enemy(1,30),enemy(2,60)])
	move(ordinary, 100)
	check(damage(ordinary,[1,2]) == [100.0,0.0] and ordinary.projectiles.is_empty(), "ordinary projectile retains one direct hit")

func lifecycle_checks() -> void:
	var runtime = fired(input_for(), [enemy(1,20),enemy(2,30),enemy(3,40),enemy(4,60),enemy(5,80),enemy(6,100)])
	runtime.enemies["1"].hp = 0.0
	runtime.enemies["2"].arrived = true
	runtime.enemies.erase("3")
	var p: Dictionary = runtime.projectiles[0]
	move(runtime, 150)
	check(p.excluded == ["4","5","6"] and damage(runtime,[4,5,6]) == [100.0,100.0,100.0], "dead, arrived, and removed targets spend no pierces")
	var owner_removed = fired(input_for(), [enemy(1,30),enemy(2,60)])
	owner_removed.turrets.clear()
	move(owner_removed, 100)
	check(owner_removed.projectiles.is_empty() and damage(owner_removed,[1,2]) == [0.0,0.0], "removed owner cannot deliver ghost piercing damage")
	var miss = fired(input_for(), [enemy(1,30),enemy(2,60,20)])
	move(miss, 150)
	check(damage(miss,[1,2]) == [100.0,0.0] and miss.projectiles.size() == 1, "piercing does not home toward an off-axis next target")
	move(miss, 10000)
	check(miss.projectiles.is_empty() and damage(miss,[1,2]) == [100.0,0.0], "remaining pierces do not prevent travel expiry")

func status_checks() -> void:
	var input := input_for("magic")
	input.definition.slowMultiplier = 0.6
	input.definition.slowDuration = 3.0
	input.secondaryTrait = "frostCrack"
	var runtime = fired(input, [enemy(1,30),enemy(2,60),enemy(3,90)])
	move(runtime, 150)
	check(damage(runtime,[1,2,3]) == [100.0,100.0,100.0], "every pierce uses identical direct status/resistance order")
	for id in [1,2,3]:
		var e: Dictionary = runtime.enemies[str(id)]
		check(e.burnInstances.size() == 1 and is_equal_approx(e.burnInstances[0].damagePerSecond,50.0) and is_equal_approx(e.burnInstances[0].remaining,2.0), "full burn on direct target " + str(id))
		check(e.slowInstances.size() == 1 and is_equal_approx(e.slowInstances[0].multiplier,0.6) and is_equal_approx(e.slowInstances[0].remaining,3.0), "full slow on direct target " + str(id))
		check(is_equal_approx(e.elementalVulnerabilityRemaining,3.0) and is_equal_approx(e.elementalVulnerabilityBonus,0.15), "vulnerability on direct target " + str(id))

func explosion_checks() -> void:
	for type in ["arrow", "cannon"]:
		var input := input_for(type,["piercing","explosion"] if type == "arrow" else ["piercing"])
		if type == "arrow": input.explosionGemValue = 40.0
		else: input.definition.splashRadius = 50.0
		var runtime = fired(input, [enemy(1,40),enemy(2,55),enemy(3,70),enemy(4,65,20)])
		move(runtime, 40)
		check(damage(runtime,[1,2,3,4]) == [100.0,0.0,0.0,0.0], type + " first pierce has no early AoE")
		check(runtime.turrets["1"].splashDamageDealt == 0 and impact_count(runtime,"blast") == 0, type + " no early splash accounting or explosion visual")
		move(runtime, 40)
		check(damage(runtime,[1,2,3,4]) == [150.0,150.0,100.0,50.0], type + " final AoE may hit earlier pierced targets, primary only once")
		check(runtime.turrets["1"].directDamageDealt == 300 and runtime.turrets["1"].splashDamageDealt == 150, type + " direct and final splash totals stay distinct")
		if type == "cannon": check(impact_count(runtime,"blast") == 1, "native cannon emits exactly one terminal blast")
		var expired = fired(input, [enemy(1,40),enemy(2,50,20)])
		move(expired, 10000)
		check(expired.projectiles.is_empty() and damage(expired,[1,2]) == [100.0,0.0], type + " travel expiry with unused pierces does not explode")
		check(expired.turrets["1"].splashDamageDealt == 0 and impact_count(expired,"blast") == 0, type + " expiry emits no splash or explosion visual")

func chain_checks() -> void:
	var runtime = fired(input_for("arrow",["piercing","chain"]), [enemy(1,30),enemy(2,60),enemy(3,90),enemy(4,90,40),enemy(5,90,80),enemy(6,90,120)])
	move(runtime, 40)
	check(runtime.projectiles.size() == 1 and not runtime.projectiles[0].chained and runtime.projectiles[0].chains == 2, "pierce precedes chain and preserves chain budget")
	move(runtime, 60)
	check(damage(runtime,[1,2,3,4]) == [100.0,100.0,100.0,0.0] and runtime.projectiles.size() == 1 and runtime.projectiles[0].chained, "chain begins only after final straight direct hit")
	check(runtime.projectiles[0].pierces == 0 and runtime.projectiles[0].excluded == ["1","2","3"], "chain inherits exclusions without refilling pierces")
	check(is_equal_approx(runtime.projectiles[0].remaining,330.0), "existing chain travel range is unchanged")
	move(runtime, 100)
	check(damage(runtime,[4,5,6]) == [50.0,0.0,0.0] and runtime.projectiles.size() == 1 and runtime.projectiles[0].pierces == 0, "first chain applies half damage and still has no piercing")
	move(runtime, 100)
	check(damage(runtime,[1,2,3,4,5,6]) == [100.0,100.0,100.0,50.0,50.0,0.0] and runtime.projectiles.is_empty(), "existing two-jump chain cap and half damage remain intact")
	var input := input_for("cannon",["piercing","chain"])
	input.definition.splashRadius = 40.0
	var area = fired(input,[enemy(1,30),enemy(2,60),enemy(3,90),enemy(4,160,0),enemy(5,160,15),enemy(6,160,30)])
	move(area, 100)
	check(area.projectiles.size() == 1 and is_equal_approx(area.projectiles[0].remaining,330.0), "cannon creates ordinary chain after terminal explosion")
	move(area, 80)
	check(damage(area,[4,5,6]) == [50.0,25.0,0.0], "chained cannon keeps half damage and half splash radius")
	var out_of_range = fired(input_for("arrow",["piercing","chain"]),[enemy(1,30),enemy(2,60),enemy(3,90),enemy(4,210)])
	move(out_of_range, 100)
	check(out_of_range.projectiles.is_empty() and damage(out_of_range,[4]) == [0.0], "chain cannot acquire outside existing 110-unit radius")

func multishot_checks() -> void:
	var runtime = fired(input_for("arrow",["piercing","multipleProjectiles"]),[enemy(1,30,0,8),enemy(2,60,0,8),enemy(3,90,0,14),enemy(4,120,0,20)])
	check(runtime.projectiles.size() == 3, "multishot fires three real projectiles")
	var shots: Array = runtime.projectiles.duplicate()
	move(runtime, 40)
	check(damage(runtime,[1]) == [150.0], "each multishot projectile can hit the same target independently")
	check(shots[0].pierces == 1 and shots[1].pierces == 1 and shots[2].pierces == 1, "each multishot keeps its own remaining count")
	check(not is_same(shots[0].excluded,shots[1].excluded) and not is_same(shots[1].excluded,shots[2].excluded), "multishot hit exclusion arrays are independent")
	move(runtime, 150)
	check(damage(runtime,[1,2,3,4]) == [150.0,150.0,150.0,0.0], "every multishot gets three distinct hits at existing half damage")

func broadphase_checks() -> void:
	var rows: Array = [enemy(3,90),enemy(1,30),enemy(2,60),enemy(4,120)]
	for index in range(40): rows.append(enemy(100+index,1000+index*100,1000))
	var scan = fired(input_for(),rows)
	var grid = fired(input_for(),rows)
	var broadphase: Dictionary = grid._projectile_broadphase(8)
	check(broadphase.has("cells"), "large battle builds production broadphase grid")
	var candidates: Array = grid._projectile_candidates(Vector2.ZERO,Vector2(150,0),3.5,broadphase)
	check(candidates.size() < rows.size(), "test traverses culled grid candidates rather than full-scan fallback")
	move(scan,150)
	move(grid,150,broadphase)
	check(damage(scan,[1,2,3,4]) == damage(grid,[1,2,3,4]) and damage(grid,[1,2,3,4]) == [100.0,100.0,100.0,0.0], "broadphase retains spatial hit order and full-scan results")
	# Cross the real _step activation threshold, so the integrated production
	# path also builds and uses its grid while processing eight independent shots.
	var integrated = fired(input_for(),rows)
	var t: Dictionary = integrated.turrets["1"]
	var first: Dictionary = integrated.projectiles[0]
	for index in range(7): integrated._projectile(t,first.attack,first.origin,first.direction,0,[],false,first.remaining)
	t.cooldown = 100.0
	integrated._step(0.25)
	check(damage(integrated,[1,2,3,4]) == [800.0,800.0,800.0,0.0] and integrated.projectiles.is_empty(), "production step broadphase preserves eight independent three-hit shots")

func cadence_checks() -> void:
	var expected: Array = []
	for fps in [30,60,120]:
		var runtime = fired(input_for(),[enemy(3,90),enemy(1,30),enemy(2,60),enemy(4,120)])
		# Real fixed-step session entry, with one already-launched projectile and
		# a held cooldown so cadence compares the same single shot.
		runtime.turrets["1"].cooldown = 100.0
		runtime.process_command({"epoch":1,"sequence":1,"dt":0.0,"session":{"clock":"godot","phase":"wave"}})
		for frame in range(fps): runtime.advance_session(1.0/float(fps))
		check(runtime.simulation_tick == 60, "real session advances 60 fixed ticks at " + str(fps) + " FPS")
		var result := damage(runtime,[1,2,3,4])
		if expected.is_empty(): expected = result
		check(result == [100.0,100.0,100.0,0.0] and result == expected and runtime.projectiles.is_empty(), "fixed-step native combat matches at " + str(fps) + " FPS")
