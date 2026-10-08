extends SceneTree
## First-strike target priority must survive the lightning charge delay.
const Runtime = preload("res://combat/native_combat_runtime.gd")
var failures: Array[String] = []
var checks := 0
var input: Dictionary = {}

func _initialize() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	for fixture in fixtures:
		if fixture.input.definition.type == "lightning" and fixture.input.level == 1 and fixture.input.gems.is_empty():
			input = fixture.input.duplicate(true)
			break
	check(not input.is_empty(), "base lightning fixture exists")
	if input.is_empty(): quit(1);return
	input.definition.criticalChance = 0.0
	priority_checks()
	retarget_checks()
	chain_checks()
	print("LIGHTNING_TARGET_PRIORITY checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func enemy(id: int, hp: float, x: float, progress: float) -> Dictionary:
	return {"id":id,"hp":hp,"maxHp":hp,"x":x,"y":0.0,"distanceTravelled":progress,"collisionRadius":1.0}

func charged(priority: String, rows: Array):
	var runtime = Runtime.new()
	runtime.rng.seed = 431
	runtime.process_command({"epoch":1,"sequence":0,"dt":0.0,"bootstrap":{"enemies":rows,"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{"targetPriority":priority}}]}})
	runtime._tick_turret(runtime.turrets["1"], 0.0)
	check(runtime.delayed.size() == 1 and runtime.delayed[0].kind == "charge", priority + " starts one delayed charge")
	return runtime

func strike(runtime) -> void:
	check(not runtime.delayed.is_empty(), "delayed strike exists")
	if not runtime.delayed.is_empty(): runtime._release(runtime.delayed.pop_front())

func hit_ids(runtime) -> Array:
	var ids: Array = []
	for effect in runtime.visual_effects:
		if effect.kind == "chain": ids.append(effect.targetIds[-1])
	return ids

func priority_checks() -> void:
	var expected := {"first":1, "last":2, "strongest":2, "weakest":1, "nearest":2}
	for priority: String in expected:
		var runtime = charged(priority, [enemy(1, 100, 50, 100), enemy(2, 1000, 40, 1)])
		check(runtime.turrets["1"].directDamageDealt == 0, priority + " does not hit during charge")
		strike(runtime)
		check(hit_ids(runtime) == [expected[priority]], priority + " first strike uses configured priority")
		check(is_equal_approx(runtime.enemies[str(expected[priority])].hp, (100.0 if expected[priority] == 1 else 1000.0) - 24.0), priority + " applies exact direct damage")
		check(is_equal_approx(runtime.turrets["1"].directDamageDealt, 24.0), priority + " records one direct hit")
	# The runtime accepts both packet-level and saved-state priorities.
	var override = charged("first", [enemy(1, 100, 50, 100), enemy(2, 1000, 40, 1)])
	override.turrets["1"].targetPriority = "last"
	strike(override)
	check(hit_ids(override) == [2], "packet priority takes precedence at release")
	var fallback = charged("last", [enemy(1, 100, 50, 100), enemy(2, 1000, 40, 1)])
	fallback.turrets["1"].state.erase("targetPriority")
	strike(fallback)
	check(hit_ids(fallback) == [1], "missing priority keeps first fallback")
	# Equal score/tie preserves stable enemy insertion order at every discharge.
	for repeat in 3:
		var tied = charged("strongest", [enemy(7, 100, 40, 1), enemy(3, 100, 40, 1)])
		strike(tied)
		check(hit_ids(tied) == [7], "equal priority remains deterministic")

func retarget_checks() -> void:
	for invalidation in ["dead", "arrived", "removed", "out-of-range"]:
		var runtime = charged("last", [enemy(1, 100, 50, 100), enemy(2, 1000, 40, 1), enemy(3, 1000, 60, 2)])
		match invalidation:
			"dead": runtime.enemies["2"].hp = 0.0
			"arrived": runtime.enemies["2"].arrived = true
			"removed": runtime.enemies.erase("2")
			"out-of-range": runtime.enemies["2"].x = 10000.0
		strike(runtime)
		check(hit_ids(runtime) == [3], invalidation + " charge retarget uses last, not first")
		check(runtime.enemies["1"].hp == 100 and runtime.enemies["3"].hp == 976, invalidation + " damages only eligible replacement")
	var empty = charged("last", [enemy(1, 100, 50, 1)])
	empty.enemies["1"].hp = 0.0
	strike(empty)
	check(empty.delayed.is_empty() and hit_ids(empty).is_empty() and empty.turrets["1"].directDamageDealt == 0, "no eligible enemy ends charge without ghost hit or chain")
	var removed_owner = charged("last", [enemy(1, 100, 50, 1)])
	removed_owner.turrets.clear()
	strike(removed_owner)
	check(removed_owner.delayed.is_empty() and removed_owner.enemies["1"].hp == 100, "removed turret cannot finish charge")
	var edge = charged("last", [enemy(1, 100, 50, 100), enemy(2, 1000, 40, 1)])
	edge.enemies["2"].targetingRadius = 8.0
	edge.enemies["2"].x = edge.turrets["1"].stats.range + 8.0
	strike(edge)
	check(hit_ids(edge) == [2], "first strike keeps body-inclusive acquisition range")

func chain_checks() -> void:
	var runtime = charged("last", [enemy(1, 1000, 50, 100), enemy(2, 1000, 40, 1), enemy(3, 1000, 45, 50), enemy(4, 1000, 60, 2)])
	strike(runtime)
	check(hit_ids(runtime) == [2] and runtime.delayed[0].timer == 0.07, "charge first strike keeps delayed chain timing")
	strike(runtime)
	check(hit_ids(runtime) == [2, 1], "chain keeps first priority rather than last or nearest")
	strike(runtime)
	check(hit_ids(runtime) == [2, 1, 3] and runtime.delayed.is_empty(), "chain excludes previous hits and keeps two-jump cap")
	check(runtime.enemies["2"].hp == 976 and runtime.enemies["1"].hp == 988 and runtime.enemies["3"].hp == 988 and runtime.enemies["4"].hp == 1000, "primary and chain damage multipliers stay unchanged")
	check(runtime.turrets["1"].directDamageDealt == 24 and runtime.turrets["1"].chainDamageDealt == 24, "direct and chain accounting remain separate")
