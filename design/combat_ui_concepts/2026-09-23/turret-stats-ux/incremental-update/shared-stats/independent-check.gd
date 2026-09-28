extends SceneTree
const Fixture = preload("res://verify_battle_hud.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const OracleStats = preload("res://independent-oracle-stats.gd")
const OracleCatalog = preload("res://independent-oracle-catalog.gd")
const OracleRuntime = preload("res://independent-oracle-runtime.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Selection = preload("res://ui/app_selection.gd")
const OracleSelection = preload("res://independent-oracle-selection.gd")
class CountingCatalog extends "res://content/content_catalog.gd":
 var calls: Array = []
 func turret_stats(type: String = "arrow", inputs: Dictionary = {}) -> Dictionary:
  calls.append([type, inputs.tileSize, inputs.statInput.level])
  return super.turret_stats(type,inputs)
var app
var hud
var adapter
var failures: Array = []
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); print("FAIL ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 matrix()
 app = Fixture.App.new()
 app.catalog = CountingCatalog.new()
 check(app.catalog.load_catalog(),"catalog")
 check(app.run_domain.initialize(app.catalog,{},0,100),"domain")
 app.run_domain.state.gold = 100000
 app.run_domain.state.tileSize = 1.0
 var map: Dictionary = app.catalog.stage(0).map
 var points: Array = []
 for i in map.tiles.size():
  if map.tiles[i] == "build": points.append(Vector2i(i % int(map.columns),i / int(map.columns)))
 app.selected = points[0]
 app.build_selected()
 var base: Dictionary = app.run_domain.state.turrets[0].duplicate(true)
 app.run_domain.state.turrets.clear()
 var types := ["arrow","cannon","magic","frost","sniper","lightning"]
 for i in types.size():
  var t := base.duplicate(true)
  t.id = 1000+i; t.type = types[i]; t.x = points[i].x; t.y = points[i].y
  app.run_domain.state.turrets.append(t)
 var runtime = Runtime.new()
 var config: Dictionary = app.run_domain.growth.core_config(app.run_domain.state,0,0,app.catalog)
 config.attackSyncDamageMultiplier = 1.35; config.attackSyncAttackRateMultiplier = 1.2
 var bootstrap: Dictionary = app.catalog.bootstrap(0,{"tileSize":1.0,"coreConfig":config})
 bootstrap.turrets = []
 for command in app.run_domain.service.runtime_commands(app.run_domain.state): bootstrap.turrets.append(command.turret)
 Stats.clear_shared_cache(); Stats.independent_calls = 0
 runtime.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"session":{"clock":"godot","phase":"preparation","paused":true,"speed":1.0}},false)
 app.scene._native_combat = runtime
 root.add_child(app)
 app.scene._native_combat_base_frame = {"presentation":{}}
 adapter = Selection.new()
 hud = load("res://ui/battle_hud.gd").new(); hud.app = app; app.hud = hud
 root.add_child(hud); hud.set_process(false)
 hud.main_tab = "turrets"
 check(Stats.independent_calls == 6,"initial native+HUD 6 calculations actual "+str(Stats.independent_calls))
 verify("initial",0)
 verify("unchanged",0)
 app.run_domain.state.turrets[0].level += 1
 verify("level target only",1)
 adapter.level_preview = true
 verify("preview distinct",1)
 verify("preview unchanged",0)
 adapter.level_preview = false
 verify("preview off reuse",0)
 app.run_domain.state.turrets[0].level += 1
 verify("preview promoted current",0)
 app.scene._native_combat.core.attack_sync_remaining = 3.0
 verify("core sync on",0)
 app.scene._native_combat.turrets["1000"].cleanup = 2.0
 verify("chain cleanup core",0)
 app.scene._native_combat.core.attack_sync_remaining = 0.0
 verify("core sync expired",0)
 app.run_domain.state.gold -= 1
 verify("wallet only",0)
 app.run_domain.state.runUpgradeLevels.towerDamage = 1
 verify("global upgrade",-1)
 app.run_domain.state.progression.corePassiveNodeRanks = {"attackHaste":1,"efficiencyGemSpectrum":1,"efficiencyCombinedFront":1}
 verify("core growth",-1)
 app.run_domain.state.turrets[0].equippedGemSlots = ["range"]
 verify("gem diversity",-1)
 app.run_domain.state.turrets[1].type = "arrow"
 app.run_domain.state.turrets[2].type = "arrow"
 app.run_domain.state.turrets[3].type = "arrow"
 verify("type diversity",-1)
 var deleted: Dictionary = app.run_domain.state.turrets.pop_back()
 verify("delete",-1)
 deleted.level = 4
 app.run_domain.state.turrets.append(deleted)
 verify("recreate same id",1)
 var previous = app.run_domain
 app.run_domain = load("res://session/run_session.gd").new()
 check(app.run_domain.initialize(app.catalog,{},0,100),"replace domain")
 app.run_domain.state = previous.state.duplicate(true)
 verify("session replaced",-1)
 app.catalog.data.turrets.arrow.configuration.statInput.definition.damage += 3
 verify("catalog in-place",-1)
 var replacement := CountingCatalog.new(); replacement.data = app.catalog.data.duplicate(true)
 app.catalog = replacement
 verify("catalog replaced",-1)
 app.run_domain.state.progression.physicalDamageTrainingUpgradeLevel = 1
 verify("physical training",-1)
 var growth = load("res://app/growth_rules.gd").new()
 growth.data = app.run_domain.growth.data.duplicate(true)
 growth.data.constants.familyDamageTrainingBonusPerUpgradeLevel = 0.25
 app.run_domain.growth = growth; app.run_domain.service.growth = growth
 verify("growth object replaced",-1)
 app.run_domain.growth.data.constants.familyDamageTrainingBonusPerUpgradeLevel = 0.4
 hud.configuration_cache.invalidate()
 verify("growth hotedit explicit invalidate",-1)
 print("INDEPENDENT_SHARED_STATS failures=",failures)
 hud.free(); app.free(); quit(1 if failures.size() else 0)
func verify(label: String,expected: int) -> void:
 app.selection_view.level_preview = adapter.level_preview
 app.catalog.calls.clear(); Stats.independent_calls = 0
 var runtime = app.scene._native_combat
 var ids := {}
 for command in app.run_domain.service.runtime_commands(app.run_domain.state):
  ids[str(command.turret.id)] = true
  runtime._turret(command.turret)
 for id in runtime.turrets.keys():
  if not ids.has(id): runtime.turrets.erase(id)
 adapter.apply(app); hud.refresh()
 var calls: int = Stats.independent_calls
 if expected >= 0: check(calls == expected,label+" calculations expected "+str(expected)+" actual "+str(calls))
 var oracle = Fixture.App.new()
 oracle.catalog = OracleCatalog.new()
 oracle.catalog.data = app.catalog.data.duplicate(true)
 check(oracle.run_domain.initialize(oracle.catalog,{},0,100),label+" oracle init")
 oracle.run_domain.growth.data = app.run_domain.growth.data.duplicate(true)
 oracle.run_domain.state = app.run_domain.state.duplicate(true)
 oracle.selected = app.selected; oracle.turret_type = app.turret_type
 oracle.scene._native_combat_base_frame = {"presentation":{}}
 var selection = OracleSelection.new(); selection.level_preview = adapter.level_preview; selection.apply(oracle)
 var actual: Dictionary = app.scene._native_combat_base_frame.presentation.selection.state
 var wanted: Dictionary = oracle.scene._native_combat_base_frame.presentation.selection.state
 check(actual == wanted,label+" full selection equality")
 var d: Dictionary = oracle.run_domain.service.derived(oracle.run_domain.state)
 check(hud.configuration_cache.derived(app.run_domain.state,app.run_domain.service) == d,label+" full derived configuration")
 var total := 0.0
 for t in app.run_domain.state.turrets:
  var input: Dictionary = d.turretStatInputs[t.type].duplicate(true)
  input.merge({"level":t.level,"primaryTrait":t.get("primaryTrait"),"secondaryTrait":t.get("secondaryTrait"),"gems":t.equippedGemSlots.filter(func(g): return g != null)},true)
  var stats: Dictionary = oracle.catalog.turret_stats(t.type,{"tileSize":48.0,"statInput":input})
  var cached: Dictionary = hud._stats(app.run_domain.state,t)
  check(cached == stats,label+" HUD complete stats + cache purity "+str(t.id))
  total += float(stats.damage)*float(stats.attackRate)+(float(stats.damage)*0.5*float(stats.damageOverTimeDamageMultiplier) if t.type == "magic" else 0.0)
  if t.type in ["arrow","cannon"]: total += float(stats.damage)*float(stats.attackRate)*(int(stats.projectileCount)-1)
 check(is_equal_approx(hud.total_dps,total),label+" full DPS")
 check(Stats.independent_calls == calls,label+" cached read added math")
 var old_runtime = OracleRuntime.new()
 old_runtime.core.configure(runtime.core.config,runtime.core.snapshot())
 for t in runtime.turrets.values():
  check(t.stats == OracleStats.stats_at(t.statInput,int(t.statInput.level)),label+" native exact stats "+str(t.id))
  old_runtime._turret(t)
 check(runtime._core_base_damage() == old_runtime._core_base_damage(),label+" core guardian exact damage")
 check(runtime.snapshot().turrets == old_runtime.snapshot().turrets,label+" turret saved snapshot parity")
 print("CASE ",label," calls=",calls," total=",hud.total_dps)
 oracle.free()

func matrix() -> void:
 var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/stats-matrix.json"))
 var comparisons := 0
 Stats.clear_shared_cache(); Stats.independent_calls = 0
 for fixture in fixtures:
  var input: Dictionary = fixture.input.duplicate(true)
  for scale in [1.0/48.0,1.0,2.5]:
   for buff in [[1.0,1.0],[1.35,1.2]]:
    for cleanup in [false,true]:
     input.boardDistanceScale = scale
     input.corePassiveTurretDamageMultiplier = buff[0]; input.corePassiveTurretAttackRateMultiplier = buff[1]
     input.chainCleanupActive = cleanup
     var actual: Dictionary = Stats.shared_stats_at(input,int(input.level))
     var wanted: Dictionary = OracleStats.stats_at(input,int(input.level))
     check(actual == wanted,"matrix "+str(fixture.name)+" scale="+str(scale)+" buff="+str(buff)+" cleanup="+str(cleanup))
     comparisons += 1
     actual.damage = -999
     check(Stats.shared_stats_at(input,int(input.level)) == wanted,"owned output "+str(fixture.name))
 check(Stats.independent_calls <= fixtures.size(),"matrix at most one neutral solve per fixture")
 var input: Dictionary = fixtures[0].input.duplicate(true)
 Stats.clear_shared_cache()
 var first := Stats.shared_stats_at(input,1)
 input.definition.damage += 2
 check(Stats.shared_stats_at(input,1) == OracleStats.stats_at(input,1),"owned nested input catalog mutation")
 Stats.clear_shared_cache(); var expected := Stats.shared_stats_at(input,1)
 var entry: Dictionary = Stats._shared_order[0]
 var wrong := entry.duplicate(true); wrong.input.level = 9; wrong.stats.damage = -999
 Stats._shared_buckets[entry.key].push_front(wrong)
 check(Stats.shared_stats_at(input,1) == expected,"hash bucket checks full input")
 Stats.clear_shared_cache()
 for i in 300:
  input.definition.damage = 1.0 + i
  Stats.shared_stats_at(input,1)
 check(Stats._shared_order.size() == 256,"bounded neutral cache")
 var count := 0
 for bucket in Stats._shared_buckets.values(): count += bucket.size()
 check(count == 256,"bounded hash buckets")
 input.definition.damage = 1.0
 check(Stats.shared_stats_at(input,1) == OracleStats.stats_at(input,1),"evicted result rebuilt accurately")
 print("MATRIX comparisons=",comparisons," bounded=",Stats._shared_order.size())
