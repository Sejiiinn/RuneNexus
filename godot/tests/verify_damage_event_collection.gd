extends SceneTree
const Session = preload("res://session/run_session.gd")
const Quests = preload("res://app/quest_progress.gd")
const Catalog = preload("res://content/content_catalog.gd")
var failures: Array[String] = []
var now := 1720000000000
class CountingQuests extends Quests:
	var refresh_calls := 0
	func refresh_owned(p: Dictionary, timestamp: int) -> Dictionary:
		refresh_calls += 1
		return super.refresh_owned(p,timestamp)
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.load_catalog(),"catalog")
	var session := Session.new()
	session.now_millis = func(): return now
	check(session.initialize(catalog,{"turretModules":{"items":[{"id":"module","nested":[1,2,3]}]},"researchLevels":{"range":1}},0,7),"initialize")
	session.quests = CountingQuests.new()
	var runtime := {"epoch":7,"wall_elapsed":0.0,"events":[],"enemies":{},"defense":{"hp":100},"session":{"phase":"wave"}}
	var before: Dictionary = session.state
	var snapshot := before.duplicate(true)
	for index in range(60):
		runtime.wall_elapsed = (index+1)*0.000625
		runtime.events = [{"id":index+1,"kind":"damage","damage":1.0}]
		check(session.collect(runtime).ok,"damage collection")
	check(before == snapshot,"damage/play time preserves old state")
	check(is_same(before.progression.turretModules,session.state.progression.turretModules),"damage path shares untouched module inventory")
	check(is_same(before.progression.dailyQuestProgress,session.state.progression.dailyQuestProgress),"damage path shares untouched quest dictionaries")
	check(session.state.progression.totalPlayTimeMillis == 37,"fractional play time accumulated exactly")
	check(session.quests.refresh_calls == 0 and session.event_ack == 60,"no-op quest refresh skipped while ACK progresses")
	var paid: Dictionary = session.state.duplicate(true)
	check(session.collect(runtime).ok and session.state == paid,"duplicate event no additional play time")
	# Refresh predicates preserve every calendar transition and fill missing attendance.
	for shift in [59999,60000,86400000,7*86400000,-300001]:
		var p: Dictionary = before.progression.duplicate(true)
		var expected := Quests.new().refresh(p,now+shift)
		var guarded := p.duplicate()
		if session.quests.needs_refresh(guarded,now+shift): guarded = session.quests.refresh_owned(guarded.duplicate(true),now+shift)
		check(guarded == expected,"refresh guard parity shift "+str(shift))
	for attendance in [null,[]]:
		var p: Dictionary = before.progression.duplicate(true)
		if attendance == null: p.erase("weeklyAttendanceDayKeys")
		else: p.weeklyAttendanceDayKeys = attendance
		check(session.quests.needs_refresh(p,now),"missing current attendance requests refresh")
		var original := p.duplicate(true)
		session.state.progression = p
		runtime.events = [{"id":61+session.event_ack,"kind":"damageNumber"}]
		check(session.collect(runtime).ok and p == original,"attendance refresh preserves old array")
		check(session.state.progression == Quests.new().refresh(p,now),"attendance refresh equals public oracle")
	# A later nested writer must detach data shared by prior damage collections.
	before = session.state
	snapshot = before.duplicate(true)
	runtime.enemies = {"1":{"type":"normal","diamondReward":0}}
	runtime.events = [{"id":session.event_ack+1,"kind":"kill","enemyId":1}]
	check(session.collect(runtime).ok,"kill after damage")
	check(before == snapshot,"later kill preserves prior shared progression")
	check(not is_same(before.progression.dailyQuestProgress,session.state.progression.dailyQuestProgress),"kill quest writer owns nested dictionary")
	check(session.state.progression.dailyQuestProgress.killEnemies == 1,"kill recorded")
	before = session.state
	snapshot = before.duplicate(true)
	runtime.enemies["1"].isDebug = true
	runtime.events = [{"id":session.event_ack+1,"kind":"kill","enemyId":1}]
	check(session.collect(runtime).ok and before == snapshot,"debug kill acknowledged without progression mutation")
	check(is_same(before.progression.turretModules,session.state.progression.turretModules),"debug kill does not copy unrelated inventory")
	print("DAMAGE_EVENT_COLLECTION failures=",failures)
	quit(0 if failures.is_empty() else 1)
