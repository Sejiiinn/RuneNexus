extends SceneTree
## Stage challenges: condition text, reward table (same as the server), run
## tracking through builds, achievement on clear, core point claims, collection
## medals with their achievement stat layers, and the optional save fields.
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Challenges = preload("res://content/stage_challenges.gd")
const Quests = preload("res://app/quest_progress.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const RunSession = preload("res://session/run_session.gd")
const Progression = preload("res://content/stage_progression.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Notice = preload("res://ui/hud_challenge_notice.gd")

class FakeRuntime extends RefCounted:
	var epoch := 1
	var events: Array = []
	var enemies: Dictionary = {}
	var wall_elapsed := 0.0
	var session := {"phase":"wave"}
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_text_cases()
	_reward_cases()
	_condition_cases()
	_build_cases()
	_achievement_cases()
	_claim_cases()
	_session_cases()
	_medal_cases()
	_notice_cases()
	_save_cases()
	print("STAGE_CHALLENGES checks=%d failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)

func _text_cases() -> void:
	# Stage ids follow the progression order: 1-1 is 1, 1-6 is 16, 2-1 is 6, 3-1 is 11.
	check(Challenges.lines(1) == ["코어 피해 없이 클리어", "적이 코어에 닿으면 실패"], "1-1 core")
	check(Challenges.lines(3) == ["냉기 포탑 없이 클리어", "냉기 계열 포탑을 설치하면 실패"], "1-3 without frost")
	check(Challenges.lines(6) == ["포탑 7기 이하로 클리어", "동시에 설치된 포탑 수 기준"], "2-1 turret limit")
	check(Challenges.lines(8) == ["물리·라이트닝만으로 클리어", "다른 계열 포탑을 설치하면 실패"], "2-3 only")
	check(Challenges.lines(24) == ["화염·냉기·라이트닝만으로 클리어", "다른 계열 포탑을 설치하면 실패"], "2-9 three families")
	var names := {"arrow":"기관총", "cannon":"대포", "sniper":"저격", "lightning":"라이트닝"}
	check(Challenges.family_members(8, names) == "물리 계열: 기관총·대포·저격 포탑 · 라이트닝 계열: 라이트닝 포탑", "family bubble")
	check(Challenges.family_members(1, names) == "", "no families for core")
	var counted := 0
	for id in range(1, 31): if Challenges.has_challenge(id): counted += 1
	check(counted == 30 and not Challenges.has_challenge(31), "every current stage has one challenge")

func _reward_cases() -> void:
	# Same table as server/internal/economy/challenge_rewards_test.go.
	for spec in [[1, "normal", "diamonds", 100], [2, "hard", "tickets", 5], [16, "normal", "tickets", 4], [6, "hard", "diamonds", 300], [5, "normal", "diamonds", 100], [5, "hard", "corePoints", 1], [20, "hard", "corePoints", 1], [20, "normal", "tickets", 4], [12, "hard", "tickets", 7], [30, "normal", "tickets", 6]]:
		var reward := Challenges.reward(spec[0], spec[1])
		check(reward.get("kind") == spec[2] and int(reward.get("amount", -1)) == spec[3], "reward %d %s" % [spec[0], spec[1]])
	check(Challenges.reward_key(15, "hard") == "stage:15:challenge:hard" and Challenges.reward_key(15, "normal") == "stage:15:challenge:normal", "reward keys")

func _condition_cases() -> void:
	check(Challenges.met({"challengePeakTurrets":7}, 6) and not Challenges.met({"challengePeakTurrets":8}, 6), "seven turrets at once")
	check(Challenges.met({"challengePeakTurrets":0}, 6), "no build meets the limit")
	check(not Challenges.met({"challengePeakTurrets":2, "challengeTurretTypes":["arrow", "frost"]}, 3) and Challenges.met({"challengePeakTurrets":2, "challengeTurretTypes":["arrow", "magic"]}, 3), "without frost")
	check(Challenges.met({"challengePeakTurrets":3, "challengeTurretTypes":["arrow", "sniper", "lightning"]}, 8) and not Challenges.met({"challengePeakTurrets":2, "challengeTurretTypes":["arrow", "magic"]}, 8), "only physical and lightning")
	check(Challenges.met({"challengePeakTurrets":0}, 1) and not Challenges.met({"challengePeakTurrets":0, "challengeCoreReached":true}, 1), "no core contact")
	check(not Challenges.met({"challengePeakTurrets":0}, 99), "no challenge, never met")
	# A run saved before tracking existed (no peak field) cannot prove its play.
	for id in [1, 3, 6, 8]: check(not Challenges.met({"turrets":[]}, id), "untracked run %d achieves nothing" % id)

func _build_cases() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(), "content")
	var service = Commands.new(catalog, growth)
	var state: Dictionary = service.initial_state()
	check(state.challengePeakTurrets == 0, "a new run is tracked from its start")
	state.gold = 100000
	var map: Dictionary = catalog.stage(0).map
	var tiles: Array = []
	for i in map.tiles.size():
		if map.tiles[i] == "build": tiles.append(i)
	var built: Dictionary = state
	for k in 3:
		var tile: int = tiles[k]
		built = service.apply(built, {"kind":"build", "type":["arrow", "frost", "arrow"][k], "x":tile % int(map.columns), "y":tile / int(map.columns)}).state
	check(built.challengePeakTurrets == 3 and built.challengeTurretTypes == ["arrow", "frost"], "builds record the peak and types")
	var sold: Dictionary = service.apply(built, {"kind":"sell", "id":int(built.turrets[0].id)})
	check(sold.ok and sold.state.turrets.size() == 2 and sold.state.challengePeakTurrets == 3, "a sale keeps the peak")
	var rebuilt: Dictionary = service.apply(sold.state, {"kind":"build", "type":"magic", "x":tiles[0] % int(map.columns), "y":tiles[0] / int(map.columns)}).state
	check(rebuilt.challengePeakTurrets == 3 and rebuilt.challengeTurretTypes == ["arrow", "frost", "magic"], "a later build adds its type")
	# A run saved before tracking existed: selling and building again must not start tracking.
	var legacy: Dictionary = built.duplicate(true)
	legacy.erase(Challenges.PEAK_FIELD)
	legacy.erase(Challenges.TYPES_FIELD)
	var legacy_sold: Dictionary = service.apply(legacy, {"kind":"sell", "id":int(legacy.turrets[1].id)}).state
	var legacy_built: Dictionary = service.apply(legacy_sold, {"kind":"build", "type":"arrow", "x":tiles[1] % int(map.columns), "y":tiles[1] / int(map.columns)}).state
	check(not legacy_built.has(Challenges.PEAK_FIELD) and not legacy_built.has(Challenges.TYPES_FIELD) and not Challenges.met(legacy_built, 3), "an untracked run stays untracked after building")

func _achievement_cases() -> void:
	var quests = Quests.new()
	var base := {"runes":0, "clearedStageNumbers":[1, 2, 3], "bestRoundsByStage":{"3":40}, "claimedCorePointStageRewards":[1, 2, 3], "totalCorePoints":6, "researchLevels":{}}
	var normal: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":40, "success":true, "challengeMet":true})
	check(normal.challengeStageNumbers == [3] and not normal.has("hardChallengeStageNumbers"), "normal achievement")
	check(Challenges.achieved(normal, 3, "normal") and not Challenges.achieved(normal, 3, "hard"), "normal does not credit hard")
	var hard: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":40, "success":true, "difficulty":"hard", "challengeMet":true})
	check(hard.hardChallengeStageNumbers == [3] and hard.challengeStageNumbers == [3], "hard also credits normal")
	var failed: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":20, "success":false, "challengeMet":true})
	check(not failed.has("challengeStageNumbers"), "a failure achieves nothing")
	var unmet: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":40, "success":true, "challengeMet":false})
	check(not unmet.has("challengeStageNumbers"), "an unmet condition achieves nothing")
	var p := {"challengeStageNumbers":[1, 2], "hardChallengeStageNumbers":[2]}
	check(Challenges.chapter_count(p, 1, "normal") == 2 and Challenges.chapter_count(p, 1, "hard") == 1, "chapter counts")
	check(Challenges.any_claimable(p, []) and not Challenges.any_claimable(p, ["stage:1:challenge:normal", "stage:2:challenge:normal", "stage:2:challenge:hard"]), "claimable follows server keys")

func _claim_cases() -> void:
	var growth = Growth.new()
	check(growth.load_catalog(), "growth")
	var p := {"clearedStageNumbers":[5], "hardChallengeStageNumbers":[5], "totalCorePoints":10}
	check(Challenges.claimed(p, [], 5, "normal") == false and Challenges.claimed(p, [], 5, "hard") == false, "nothing claimed yet")
	var claimed: Dictionary = growth.execute(p, {"kind":"claimChallengeCorePoint", "stageNumber":5})
	check(claimed.ok and claimed.state.totalCorePoints == 11 and claimed.state.claimedChallengeCorePointStages == [5], "hard 1-5 core point")
	check(Challenges.claimed(claimed.state, [], 5, "hard") and not Challenges.any_claimable({"hardChallengeStageNumbers":[5], "claimedChallengeCorePointStages":[5]}, ["stage:5:challenge:normal"]), "core claim is recorded")
	check(not growth.execute(claimed.state, {"kind":"claimChallengeCorePoint", "stageNumber":5}).ok, "core point once")
	check(not growth.execute({"challengeStageNumbers":[5], "totalCorePoints":10}, {"kind":"claimChallengeCorePoint", "stageNumber":5}).ok, "normal achievement gives no core point")
	check(not growth.execute({"hardChallengeStageNumbers":[1], "totalCorePoints":10}, {"kind":"claimChallengeCorePoint", "stageNumber":1}).ok, "diamond stages are server claims")

func _session(arrivals: Dictionary) -> Variant:
	var catalog = Catalog.new()
	catalog.load_catalog()
	var session = RunSession.new()
	check(session.initialize(catalog, {"clearedStageNumbers":[]}, 0, 1), "session")
	var runtime := FakeRuntime.new()
	var id := 0
	for enemy in arrivals:
		id += 1
		runtime.events.append({"id":id, "kind":"arrival", "enemyId":enemy})
		runtime.enemies[enemy] = arrivals[enemy]
	check(session.collect(runtime).get("ok", false), "collect arrivals")
	session.finish(true)
	return session

func _session_cases() -> void:
	# Stage index 0 is 1-1, whose challenge is no core contact.
	var clean = _session({})
	check(clean.state.lastRunChallengeAchieved and clean.state.progression.get("challengeStageNumbers", []) == [1], "clean clear achieves 1-1")
	var touched = _session({"7":{"type":"normal"}})
	check(touched.state.get("challengeCoreReached", false) and not touched.state.lastRunChallengeAchieved and not touched.state.progression.has("challengeStageNumbers"), "a core arrival fails 1-1")
	var debug = _session({"8":{"type":"normal", "isDebug":true}})
	check(not debug.state.has("challengeCoreReached") and debug.state.lastRunChallengeAchieved, "debug enemies do not count")

func _arrow_stats(catalog, derived: Dictionary) -> Dictionary:
	var input: Dictionary = derived.turretStatInputs.arrow.duplicate(true)
	input.merge({"level":1, "primaryTrait":"", "secondaryTrait":"", "gems":[]}, true)
	var stat: Dictionary = catalog.turret("arrow", {"tileSize":1.0, "statInput":input})
	check(not stat.is_empty(), "medal stat inputs pass the catalog (%s)" % catalog.error)
	return Stats.shared_stats_at(stat, 1) if not stat.is_empty() else {}

func _medal_cases() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(), "medal content")
	var service = Commands.new(catalog, growth)
	var chapter_one: Array = Progression.ids_for_chapter(1)
	var p := {"clearedStageNumbers":chapter_one.duplicate(), "challengeStageNumbers":chapter_one.duplicate()}
	var keys: Array = chapter_one.map(func(id): return Challenges.reward_key(id, "normal"))
	check(Challenges.medal_ready(p, 11) and not Challenges.medal_ready(p, 12) and not Challenges.medal_ready(p, 21), "chapter 1 normal collection is complete")
	check(Challenges.any_claimable(p, keys), "a ready medal lights the lobby badge")
	check(Challenges.achievement_count(p) == [11, 91], "achievements count challenges, completed collections and cumulative tiers")
	var rejected: Dictionary = growth.execute(p, {"kind":"claimCollectionMedal", "medalId":12})
	check(not rejected.ok, "an incomplete collection gives no medal")
	var claimed: Dictionary = growth.execute(p, {"kind":"claimCollectionMedal", "medalId":11})
	check(claimed.ok and claimed.state.claimedCollectionMedals == [11] and not Challenges.any_claimable(claimed.state, keys), "chapter 1 normal medal")
	check(not growth.execute(claimed.state, {"kind":"claimCollectionMedal", "medalId":11}).ok, "a medal is claimed once")
	# Stats: core durability on the normal medal, turret damage on the hard one.
	var base: Dictionary = service.derived(service.initial_state({}))
	var with_core: Dictionary = service.derived(service.initial_state(claimed.state))
	check(is_equal_approx(with_core.maxNexusHp, base.maxNexusHp * 1.05), "core durability +5%")
	check(not base.turretStatInputs.arrow.has("achievementTurretDamageMultiplier"), "no medal leaves stat inputs unchanged")
	var all_medals := {"claimedCollectionMedals":[11, 12, 21, 22, 31, 32]}
	var full: Dictionary = service.derived(service.initial_state(all_medals))
	check(is_equal_approx(full.turretStatInputs.arrow.achievementTurretDamageMultiplier, 1.06), "two turret damage medals add, then multiply once")
	var plain := _arrow_stats(catalog, base)
	var boosted := _arrow_stats(catalog, full)
	check(is_equal_approx(boosted.damage, plain.damage * 1.06), "turret damage amplification layer")
	check(is_equal_approx(boosted.range, plain.range * 1.03), "turret range layer")
	check(is_equal_approx(boosted.criticalDamageMultiplier, plain.criticalDamageMultiplier + 0.10), "critical damage adds percentage points")
	var config: Dictionary = growth.combat_config(full)
	check(is_equal_approx(config.achievementBossDamageRate, 0.05) and not growth.combat_config(base).has("achievementBossDamageRate"), "boss medal reaches the combat config")
	var runtime = Runtime.new()
	runtime._configure_combat({"bossDamageBonusRate":0.2, "achievementBossDamageRate":0.05})
	check(is_equal_approx(runtime._target_damage_multiplier({"type":"boss"}), 1.2 * 1.05) and runtime._target_damage_multiplier({"type":"normal"}) == 1.0, "boss training and medal multiply")
	var stats: Dictionary = Challenges.achievement_stats(all_medals)
	check(Challenges.stat_text("turretDamage", stats.turretDamage) == "모든 포탑 피해 증폭 +6%" and Challenges.stat_text("criticalDamage", 0.1) == "치명타 피해 +10%", "stat labels")

## Battle notice: the condition once when first seen intact, the failure once
## when it breaks, nothing for untracked, achieved or already broken runs.
func _notice_cases() -> void:
	check(Challenges.broken_line(1) == "적이 코어에 닿았습니다" and Challenges.broken_line(6) == "포탑이 7기를 넘었습니다", "core and turret failure lines")
	check(Challenges.broken_line(3) == "냉기 포탑을 설치했습니다" and Challenges.broken_line(8) == "다른 계열 포탑을 설치했습니다", "family failure lines")
	var notice = Notice.new(null)
	var run := {"phase":"preparation", "challengePeakTurrets":0, "turrets":[], "progression":{}}
	check(notice.step(run, 3) == "start", "an intact condition is announced once")
	check(notice.step(run, 3) == "", "the start notice does not repeat")
	run.challengeTurretTypes = ["arrow"]
	check(notice.step(run, 3) == "", "a permitted build keeps the condition")
	run.challengeTurretTypes = ["arrow", "frost"]
	check(notice.step(run, 3) == "fail", "a frost build breaks 1-3 once")
	check(notice.step(run, 3) == "", "the failure does not repeat")
	var resumed = Notice.new(null)
	check(resumed.step(run, 3) == "" and resumed.step(run, 3) == "", "a run already broken when first seen shows neither")
	var untracked = Notice.new(null)
	check(untracked.step({"phase":"wave", "turrets":[], "progression":{}}, 3) == "", "an untracked run shows nothing")
	var done = Notice.new(null)
	check(done.step({"phase":"wave", "challengePeakTurrets":0, "turrets":[], "progression":{"challengeStageNumbers":[3]}}, 3) == "", "an achieved challenge shows nothing")
	var hard = Notice.new(null)
	check(hard.step({"phase":"wave", "difficulty":"hard", "challengePeakTurrets":0, "turrets":[], "progression":{"challengeStageNumbers":[3]}}, 3) == "start", "normal achievement still announces hard")
	var reward = Notice.new(null)
	check(reward.step({"phase":"reward", "challengePeakTurrets":0, "turrets":[], "progression":{}}, 3) == "" and reward.step({"phase":"wave", "challengePeakTurrets":0, "turrets":[], "progression":{}}, 3) == "start", "waits for a battle phase")
	var core = Notice.new(null)
	var defended := {"phase":"wave", "challengePeakTurrets":2, "turrets":[], "progression":{}}
	core.step(defended, 1)
	defended.challengeCoreReached = true
	check(core.step(defended, 1) == "fail", "a core arrival breaks 1-1")
	var shown = Notice.new(null)
	var strip := PanelContainer.new()
	shown.notice = strip
	shown.observe({"phase":"reward", "challengePeakTurrets":0, "turrets":[], "progression":{}}, 3)
	check(shown.notice == null and strip.is_queued_for_deletion(), "rewards and results clear a showing notice")

func _envelope(run_extra: Dictionary, progression_extra: Dictionary) -> Dictionary:
	var run := {"phase":"preparation", "stageNumber":3, "economyRunId":"run-1", "turrets":[], "enemies":[], "spawnQueue":[]}
	run.merge(run_extra, true)
	var progression := {"clearedStageNumbers":[1, 2, 3], "bestRoundsByStage":{"3":40}}
	progression.merge(progression_extra, true)
	return {"version":2, "savedAtMillis":1, "preferences":{}, "progression":progression, "turretModules":{}, "activeRun":run}

func _save_cases() -> void:
	var plain: Variant = Codec.decode(_envelope({}, {}))
	check(plain != null and not plain.activeRun.has("challengePeakTurrets") and not plain.progression.has("challengeStageNumbers"), "saves without challenges carry no fields")
	var tracked: Variant = Codec.decode(_envelope({"challengePeakTurrets":4, "challengeTurretTypes":["arrow", "bogus", "arrow"], "challengeCoreReached":true}, {"challengeStageNumbers":[3, 3, "x"], "hardChallengeStageNumbers":[2], "claimedChallengeCorePointStages":[5], "claimedCollectionMedals":[11]}))
	check(tracked.activeRun.challengePeakTurrets == 4 and tracked.activeRun.challengeTurretTypes == ["arrow"] and tracked.activeRun.challengeCoreReached == true, "run tracking round trips and normalizes")
	check(tracked.progression.challengeStageNumbers == [3] and tracked.progression.hardChallengeStageNumbers == [2] and tracked.progression.claimedChallengeCorePointStages == [5] and tracked.progression.claimedCollectionMedals == [11], "achievements and medals round trip")
	check(Hash.hash_payload(tracked) != Hash.hash_payload(plain), "challenge fields are hashed")
	check(Hash.hash_payload(Codec.decode(tracked)) == Hash.hash_payload(tracked), "challenge save is stable on re-decode")
