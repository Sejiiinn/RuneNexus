extends SceneTree
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	for fixture in fixtures:
		for scale in [1.0,1.0/48.0,2.75]:
			for buff in [1.0,1.375]:
				var input: Dictionary = fixture.input.duplicate(true)
				input.boardDistanceScale = scale
				input.corePassiveTurretDamageMultiplier = buff
				input.corePassiveTurretAttackRateMultiplier = buff
				for cleanup in [false,true]:
					input.chainCleanupActive = cleanup
					var actual := Stats.shared_stats_at(input,int(input.level))
					check(actual == Stats.stats_at(input,int(input.level)),fixture.name+": exact raw/shared stats scale/core/cleanup")
	var catalog := Catalog.new()
	check(catalog.load_catalog(),"catalog")
	for type in catalog.data.turrets:
		Stats.clear_shared_cache()
		var before := Stats.shared_calculation_count
		var input: Dictionary = catalog.turret(type,{"tileSize":1.0,"statInput":{"level":4}})
		var runtime := Runtime.new()
		runtime.process_command({"epoch":1,"sequence":0,"bootstrap":{"enemies":[],"turrets":[{"id":1,"position":[0,0],"state":{"x":0,"y":0},"statInput":input}]}})
		check(Stats.shared_calculation_count == before+1,type+": combat calculates once")
		for tile in [1.0,48.0]:
			var result := catalog.turret_stats(type,{"tileSize":tile,"statInput":{"level":4}})
			check(result == Stats.stats_at(catalog.turret(type,{"tileSize":tile,"statInput":{"level":4}}),4),type+": UI exact units")
		check(Stats.shared_calculation_count == before+1,type+": current combat and both UI units share one calculation")
		input.corePassiveTurretDamageMultiplier = 1.375
		input.corePassiveTurretAttackRateMultiplier = 1.625
		input.chainCleanupActive = true
		runtime._turret({"id":1,"position":[0,0],"statInput":input})
		check(runtime.turrets["1"].stats == Stats.stats_at(input,4),type+": transient combat stats exact")
		check(Stats.shared_calculation_count == before+1,type+": transient core and cleanup reuse base")
		for tile in [1.0,48.0]: catalog.turret_stats(type,{"tileSize":tile,"statInput":{"level":5}})
		check(Stats.shared_calculation_count == before+2,type+": preview separately computes once")
		input.level = 5
		runtime._turret({"id":1,"position":[0,0],"statInput":input})
		check(Stats.shared_calculation_count == before+2,type+": preview confirmation reuses computed base in combat")
		var owned := Stats.shared_stats_at(input,5)
		owned.damage = -1
		check(Stats.shared_stats_at(input,5).damage > 0,type+": callers cannot mutate cache")
		# Exact input snapshots invalidate in-place catalog/module changes.
		input.moduleEffect.damageIncreaseRate += 0.125
		check(Stats.shared_stats_at(input,5) == Stats.stats_at(input,5),type+": module edit invalidation")
		check(Stats.shared_calculation_count == before+3,type+": changed module computes once")
	Stats.clear_shared_cache()
	var varied := catalog.turret("arrow")
	for index in range(Stats.SHARED_CACHE_LIMIT+7):
		varied.towerDamageMultiplier = 1.0+index*0.01
		Stats.shared_stats_at(varied,1)
	check(Stats._shared_order.size() == Stats.SHARED_CACHE_LIMIT,"shared cache bounded after many configurations")
	check(Stats.shared_stats_at(varied,1) == Stats.stats_at(varied,1),"eviction preserves values")
	Stats.clear_shared_cache()
	print("SHARED_TURRET_STATS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
