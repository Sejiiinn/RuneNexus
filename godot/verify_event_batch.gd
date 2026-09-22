extends SceneTree
const Session = preload("res://session/run_session.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Quests = preload("res://app/quest_progress.gd")
class CountingGrowth extends "res://app/growth_rules.gd":
	var derive_calls := 0
	func derive(p: Dictionary, context: Dictionary = {}) -> Dictionary:
		derive_calls += 1
		return super.derive(p, context)
var failures: Array = []
var fixed_now := 1720000000000
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func make_session(script = Session):
	var catalog = Catalog.new()
	check(catalog.load_catalog(), "catalog")
	var session = script.new()
	session.now_millis = func(): return fixed_now
	check(session.initialize(catalog, {"researchLevels":{"crystalRecovery":2},"killGoldUpgradeLevel":3,"bossBountyUpgradeLevel":3,"clearedStageNumbers":[1,2,3,4,5]},0,7), "initialize")
	session.state.economyRunId = "event-batch-fixture"
	session.state.runUpgradeLevels = {"killGold":1}
	session.state.killGoldFractionWallet = 0.37
	var counted := CountingGrowth.new()
	counted.data = session.growth.data
	session.growth = counted
	session.service.growth = counted
	return session
func runtime_for(session, count: int) -> Dictionary:
	var enemy_types: Array = session.service.catalog.data.enemyDefinitions.keys()
	var ordinary: String = enemy_types[0]
	var boss := ordinary
	for type in enemy_types:
		if session.service.catalog.data.enemyDefinitions[type].get("isBoss",false): boss = type
	var events: Array = []
	var enemies := {}
	for i in range(count):
		events.append({"id":i+1,"kind":"kill","enemyId":i+1})
		enemies[str(i+1)] = {"type":boss if i%10==0 else ordinary,"diamondReward":1}
	return {"epoch":7,"wall_elapsed":0.0006,"events":events,"enemies":enemies,"defense":{"hp":100},"session":{"phase":"wave"}}
func exercise(script = Session) -> Dictionary:
	var session = make_session(script)
	var runtime := runtime_for(session, 120)
	var before: Dictionary = session.state
	var snapshot := before.duplicate(true)
	var runtime_before := runtime.duplicate(true)
	var d: Dictionary = session.service.derived(session.state)
	var base_gold := 0
	var bonus_gold := 0.37
	var expected_shards: int = snapshot.gemShards
	for enemy in runtime.enemies.values():
		var definition: Dictionary = session.service.catalog.data.enemyDefinitions[enemy.type]
		var base: int = definition.rewardGold
		base_gold += base
		bonus_gold += base * (float(d.killGoldBonusRate) + (float(d.bossBountyBonusRate) if definition.get("isBoss",false) else 0.0))
		if definition.get("isBoss",false): expected_shards += int(d.bossKillGemShardBonus)
	session.growth.derive_calls = 0
	check(session.collect(runtime).ok, "kill batch accepted")
	check(session.growth.derive_calls == (1 if script == Session else 120), "one growth derivation per kill batch")
	check(session.state.gold == snapshot.gold + base_gold + floori(bonus_gold), "fractional and boss bonus gold paid exactly")
	check(is_equal_approx(session.state.killGoldFractionWallet, bonus_gold-floori(bonus_gold)), "fractional wallet expected remainder")
	check(session.state.gemShards == expected_shards, "boss shard reward exact")
	check(before == snapshot, "collection preserves prior state")
	check(runtime == runtime_before, "runtime input immutable")
	check(session.state.killGoldFractionWallet >= 0 and session.state.killGoldFractionWallet < 1, "fraction wallet remains normalized")
	check(session.state.gemShards > snapshot.gemShards, "boss shards awarded")
	check(session.event_ack == 120 and session.state.pendingEconomyDiamonds == 120, "all rewards and ACK")
	check(session.state.progression.dailyQuestProgress.killBosses == 3, "boss quest capped")
	var paid: Dictionary = session.state.duplicate(true)
	check(session.collect(runtime).ok and session.state == paid, "duplicate polling pays nothing")
	# A committed prefix must survive a missing enemy; retry must apply only suffix.
	runtime.events.append({"id":121,"kind":"kill","enemyId":1})
	runtime.events.append({"id":122,"kind":"kill","enemyId":999})
	runtime.events.append({"id":123,"kind":"kill","enemyId":2})
	check(not session.collect(runtime).ok and session.event_ack == 121, "partial success ACK stops before missing enemy")
	check(session.state.pendingEconomyDiamonds == 121, "successful prefix committed")
	runtime.enemies["999"] = {"type":"not-an-enemy"}
	check(not session.collect(runtime).ok and session.event_ack == 121, "invalid enemy retained")
	runtime.enemies["999"] = runtime.enemies["1"].duplicate(true)
	runtime.wall_elapsed = 0.0012
	check(session.collect(runtime).ok and session.event_ack == 123, "retry suffix accepted")
	check(session.state.pendingEconomyDiamonds == 123, "retry never double-pays prefix")
	check(session.state.progression.totalPlayTimeMillis == 1, "fractional play time survives polls")
	var first_wave: int = session.service.catalog.stage(0).waves[0].round
	runtime.events.append({"id":124,"kind":"waveCompleted","waveId":first_wave})
	runtime.events.append({"id":125,"kind":"coreDefeated"})
	runtime.events.append({"id":126,"kind":"kill","enemyId":1})
	check(session.collect(runtime).ok and session.event_ack == 126, "wave/core/kill order accepted")
	check(session.state.completedRounds == 1 and session.state.phase == "coreDestruction", "wave before defeat retained")
	check(session.is_finished(), "finish marker committed")
	var result: Dictionary = session.state.duplicate(true)
	check(session.collect(runtime).ok and session.state == result, "terminal rewards deduplicated")
	runtime.epoch = 8
	check(not session.collect(runtime).ok and session.state == result, "stale epoch unchanged")
	var dead = make_session(script)
	var dead_runtime := runtime_for(dead,0)
	dead_runtime.defense.hp = 0
	dead_runtime.events = [{"id":1,"kind":"waveCompleted","waveId":first_wave},{"id":2,"kind":"coreDefeated"}]
	check(dead.collect(dead_runtime).ok and dead.state.completedRounds == 0, "dead core suppresses wave reward")
	return result
func quest_edges() -> void:
	var rules = Quests.new()
	var source := {"nested":{"keep":[1,2]}}
	var before := source.duplicate(true)
	var day := 20000
	var boundary := day*86400000-14400000
	var p: Dictionary = rules.record(source,"killEnemies",7,boundary-1)
	check(source == before, "public record input immutable")
	var old := p.duplicate(true)
	p = rules.record(p,"killEnemies",2,boundary)
	check(p.dailyQuestProgress.killEnemies == 2 and old.dailyQuestProgress.killEnemies == 7, "day boundary reset")
	p = rules.refresh(p,boundary+600000)
	p = rules.refresh(p,boundary+1)
	check(p.dailyQuestClockRollbackDetected, "same-day clock rollback")
	var week_before: int = p.weeklyQuestWeekKey
	p = rules.record(p,"killBosses",1,boundary+7*86400000)
	check(p.weeklyQuestWeekKey > week_before and p.weeklyQuestProgress == {"killBosses":1}, "week boundary reset")
	var saved := p.duplicate(true)
	check(rules.record(p,"killEnemies",0,boundary) == saved and p == saved, "zero amount leaves time keys unchanged")
	check(rules.record_play_time(p,NAN) == saved and p == saved, "invalid play time unchanged")
func benchmark(script, count: int, repeats: int) -> int:
	var session = make_session(script)
	var input := runtime_for(session,count)
	var original: Dictionary = session.state.duplicate(true)
	var elapsed := 0
	for i in range(repeats):
		session.state = original.duplicate(true)
		session.event_ack = 0
		var start := Time.get_ticks_usec()
		session.collect(input)
		elapsed += Time.get_ticks_usec()-start
	return elapsed
func _initialize() -> void:
	var result := exercise()
	quest_edges()
	# Optional isolated baseline is supplied by the benchmark runner, never production.
	if FileAccess.file_exists("res://baseline/run_session.gd"):
		var baseline = load("res://baseline/run_session.gd")
		check(exercise(baseline) == result, "baseline ordered state parity")
		benchmark(Session,120,2)
		benchmark(baseline,120,2)
		for i in range(3):
			var old_us: int
			var new_us: int
			if i%2==0:
				old_us = benchmark(baseline,120,20)
				new_us = benchmark(Session,120,20)
			else:
				new_us = benchmark(Session,120,20)
				old_us = benchmark(baseline,120,20)
			print("EVENT_BATCH_CPU sample=",i," kills=120 repeats=20 baseline_us=",old_us," current_us=",new_us)
	print("EVENT_BATCH failures=",failures)
	quit(0 if failures.is_empty() else 1)
