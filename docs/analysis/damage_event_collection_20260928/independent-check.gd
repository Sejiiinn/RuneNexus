extends SceneTree
const Current = preload("res://session/run_session.gd")
const Original = preload("res://independent-oracle-run.gd")
const Catalog = preload("res://content/content_catalog.gd")
class Clock extends RefCounted:
 var ticks: Array = []
 var calls := 0
 func now() -> int:
  var value: int = ticks[mini(calls,ticks.size()-1)]; calls += 1; return value
var shared_catalog = Catalog.new()
var failures: Array = []
var checks := 0
var steps := 0
var history: Array = []
var base_time := 20000*86400000-14400000+600000
func check(ok: bool,label: String) -> void:
 checks += 1
 if not ok: failures.append(label); print("FAIL ",label)
func pair() -> Array:
 history.clear()
 var result := []
 for script in [Current,Original]:
  var catalog = shared_catalog
  var run = script.new(); run.now_millis = func(): return base_time
  check(run.initialize(catalog,{"researchLevels":{"crystalRecovery":2},"killGoldUpgradeLevel":3,"bossBountyUpgradeLevel":3,"clearedStageNumbers":[1,2,3,4,5]},0,7),"initialize")
  run.state.economyRunId = "independent-damage-collect"
  run.state.progression.turretModules = {"items":[],"tickets":7}
  for i in 400: run.state.progression.turretModules.items.append({"id":str(i),"payload":{"values":[i,i+1]}})
  run.state.progression.dailyQuestProgress = {"killEnemies":5}
  run.state.progression.weeklyQuestProgress = {"killEnemies":7}
  run.state.progression.claimedEventIds = ["historical-event"]
  result.append(run)
 return result
func runtime() -> Dictionary:
 return {"epoch":7,"wall_elapsed":0.0,"events":[],"enemies":{"1":{"type":"normal","diamondReward":1},"2":{"type":"boss","diamondReward":3}},"defense":{"hp":100},"session":{"phase":"wave"}}
func step(label: String,p: Array,r: Dictionary,times: Array,expect_shared := false) -> void:
 var a = p[0]; var b = p[1]
 var clock_a := Clock.new(); clock_a.ticks = times; var clock_b := Clock.new(); clock_b.ticks = times
 a.now_millis = clock_a.now; b.now_millis = clock_b.now
 var previous: Dictionary = a.state
 history.append([previous,previous.duplicate(true)])
 var before := var_to_bytes(r)
 seed(12345)
 var result: Dictionary = a.collect(r)
 seed(12345)
 var expected: Dictionary = b.collect(r.duplicate(true))
 steps += 1
 check(result == expected,label+" result")
 check(a.state == b.state,label+" state")
 check(a.event_ack == b.event_ack,label+" ack")
 check(a.error == b.error,label+" error")
 check(a.collected_wall_time == b.collected_wall_time,label+" collected wall")
 check(a.quests._play_time_remainder == b.quests._play_time_remainder,label+" fraction")
 check(a.state_revision == b.state_revision,label+" revision")
 check(clock_a.calls == clock_b.calls,label+" now callback count")
 check(var_to_bytes(r) == before,label+" runtime immutable")
 for item in history: check(item[0] == item[1],label+" prior state immutable")
 if expect_shared:
  check(is_same(previous.progression.turretModules,a.state.progression.turretModules),label+" heavy nested not copied")
  check(is_same(previous.progression.researchLevels,a.state.progression.researchLevels),label+" research nested not copied")
 print("STEP ",label," ok=",result.ok," ack=",a.event_ack," play_ms=",a.state.progression.get("totalPlayTimeMillis",0)," remainder=",a.quests._play_time_remainder)
func _initialize() -> void:
 check(shared_catalog.load_catalog(),"catalog")
 var p := pair(); var r := runtime()
 for i in 20:
  r.wall_elapsed += 0.0002
  r.events.append({"id":i+1,"kind":"damage","enemyId":1,"damage":1.0})
  step("fraction damage "+str(i),p,r,[base_time+i],true)
 step("duplicate damage",p,r,[base_time+100],true)
 r.events.append({"id":21,"kind":"coreBonusDamage","enemyId":1,"damage":2.0})
 r.wall_elapsed = 1.234567
 step("core bonus / wall",p,r,[base_time+1000],true)
 r.wall_elapsed = 0.5; step("wall backwards",p,r,[base_time+2000],true)
 r.wall_elapsed = INF; step("wall infinity",p,r,[base_time+3000],true)
 r.wall_elapsed = 2.0; step("wall after infinity",p,r,[base_time+4000],true)
 for delta in [59999,60000,60001,-300000,-300001,-400000]:
  p = pair(); r = runtime(); r.events=[{"id":1,"kind":"damage"}]; r.wall_elapsed=0.033333
  step("time edge "+str(delta),p,r,[base_time+delta])
 for offset in [86400000,7*86400000,-86400000]:
  p = pair(); r = runtime(); r.events=[{"id":1,"kind":"damage"}]
  step("rollover "+str(offset),p,r,[base_time+offset])
 for field in ["weeklyAttendanceDayKeys","dailyQuestDayKey","weeklyQuestWeekKey","lastDailyQuestSeenMillis"]:
  p=pair();r=runtime()
  for run in p: run.state.progression.erase(field)
  step("missing "+field,p,r,[base_time])
 p=pair();r=runtime()
 for run in p: run.state.progression.weeklyAttendanceDayKeys=[]
 step("attendance append",p,r,[base_time])
 p=pair();r=runtime()
 r.events=[{"id":1,"kind":"damage"},{"id":2,"kind":"kill","enemyId":1},{"id":3,"kind":"kill","enemyId":999},{"id":4,"kind":"damage"},{"id":5,"kind":"kill","enemyId":2}]
 step("partial prefix missing enemy",p,r,[base_time])
 r.enemies["999"]={"type":"unknown"};step("invalid reward retry",p,r,[base_time+1])
 r.enemies["999"]={"type":"normal","diamondReward":1};r.wall_elapsed=0.0007
 step("suffix retry",p,r,[base_time+2]);step("suffix duplicate",p,r,[base_time+3])
 r.events.append({"id":6,"kind":"waveCompleted","waveId":999});step("wave rejected",p,r,[base_time+4])
 r.events[-1].waveId=p[0].service.catalog.stage(0).waves[0].round
 r.events.append({"id":7,"kind":"coreDefeated"});r.events.append({"id":8,"kind":"kill","enemyId":1})
 step("wave core kill ordered",p,r,[base_time+5]);step("finish duplicate",p,r,[base_time+6])
 r.epoch=8;step("epoch rejected",p,r,[base_time+100000])
 p=pair();r=runtime();r.defense.hp=0;r.events=[{"id":1,"kind":"waveCompleted","waveId":p[0].service.catalog.stage(0).waves[0].round},{"id":2,"kind":"coreDefeated"}]
 step("dead core wave",p,r,[base_time])
 p=pair();r=runtime();r.session.phase="failure";step("terminal no events",p,r,[base_time]);step("terminal repeat",p,r,[base_time])
 p=pair();r=runtime()
 for run in p: run.state.roundIndex=run.service.catalog.stage(0).waves.size()-1; run.state.phase="wave"
 r.events=[{"id":1,"kind":"waveCompleted","waveId":p[0].service.catalog.stage(0).waves[-1].round}]
 step("success rewards",p,r,[base_time]);step("success duplicate",p,r,[base_time])
 p=pair();r=runtime();r.events=[{"id":1,"kind":"damage"},{"id":2,"kind":"kill","enemyId":1},{"id":3,"kind":"kill","enemyId":2}]
 var boundary := 20001*86400000-14400000
 step("midbatch day boundary",p,r,[boundary-1,boundary,boundary+1])
 print("INDEPENDENT_DAMAGE_COLLECT steps=",steps," checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
