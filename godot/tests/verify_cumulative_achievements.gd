extends SceneTree
## Cumulative achievements: lifetime counters from quest events and attendance,
## tiers and reward keys (same table as the server), tier-5 medals with their
## achievement stats, the account count and the optional save fields.
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Challenges = preload("res://content/stage_challenges.gd")
const Cumulative = preload("res://content/cumulative_achievements.gd")
const Quests = preload("res://app/quest_progress.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")

const DAY := 86400000
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_counter_cases()
	_tier_cases()
	_medal_cases()
	_save_cases()
	print("CUMULATIVE_ACHIEVEMENTS checks=%d failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)

func _counter_cases() -> void:
	var quests = Quests.new()
	var now := 20000 * DAY
	var p: Dictionary = quests.refresh({}, now)
	check(Cumulative.count(p, "attendance") == 0, "opening the app alone counts no attendance")
	p = _claim_attendance(quests, p, now)
	check(Cumulative.count(p, "attendance") == 1, "the daily reward claim counts today")
	p = quests.refresh(p, now + 3600000)
	check(Cumulative.count(p, "attendance") == 1, "a day counts once")
	check(not quests.apply_receipt(p, _attendance_receipt("daily", p)).ok and Cumulative.count(p, "attendance") == 1, "a repeated claim counts no day again")
	p = quests.refresh(p, now + DAY)
	check(Cumulative.count(p, "attendance") == 1, "a day without a claim is not counted")
	p = _claim_attendance(quests, p, now + DAY)
	p = _claim_attendance(quests, p, now + 9 * DAY)
	check(Cumulative.count(p, "attendance") == 3, "days add up without needing a streak")
	p = _claim_attendance(quests, p, now + 2 * DAY)
	check(Cumulative.count(p, "attendance") == 3, "a clock moved back counts no day again")
	var weekly: Dictionary = quests.refresh({}, now)
	weekly.weeklyAttendanceDayKeys = range(5).map(func(i): return int(weekly.weeklyQuestWeekKey) * 7 - 3 + i)
	var weekly_claim: Dictionary = quests.apply_receipt(weekly, _attendance_receipt("weekly", weekly))
	check(weekly_claim.ok and Cumulative.count(weekly_claim.progression, "attendance") == 0, "the weekly attendance reward adds no day")
	# Days counted at refresh before this rule stay, and a counted day is not added again.
	var legacy: Dictionary = quests.refresh({"achievementCounters":{"attendance":4}, "achievementAttendanceDayKey":int(float(now + 14400000) / DAY)}, now)
	check(not quests.needs_refresh(legacy, now + 1000), "an unclaimed attendance day needs no refresh")
	check(Cumulative.count(_claim_attendance(quests, legacy, now + 1000), "attendance") == 4, "a day counted before the claim rule stays once")
	# Lifetime counters keep growing past the daily and weekly caps.
	for i in range(200): p = quests.record_owned(p, "killEnemies", 3, now + 9 * DAY)
	p = quests.record_owned(p, "killBosses", 2, now + 9 * DAY)
	p = quests.record_owned(p, "buyRunUpgrades", 4, now + 9 * DAY)
	check(Cumulative.count(p, "killEnemies") == 600 and p.weeklyQuestProgress.killEnemies == 500, "enemy kills exceed the weekly cap")
	check(Cumulative.count(p, "killBosses") == 2 and not p.achievementCounters.has("buyRunUpgrades"), "only achievement counters are kept")
	check(Cumulative.count({"turretModules":{"drawCount":61}}, "moduleDraws") == 61, "draws read the module draw count")

func _attendance_receipt(period: String, p: Dictionary) -> Dictionary:
	if period == "weekly": return {"period":"weekly", "rewardType":"attendance", "weekKey":p.weeklyQuestWeekKey, "rewardDiamonds":40}
	return {"period":"daily", "rewardType":"attendance", "dayKey":p.dailyQuestDayKey}

func _claim_attendance(quests, p: Dictionary, now: int) -> Dictionary:
	var fresh: Dictionary = quests.refresh(p, now)
	var result: Dictionary = quests.apply_receipt(fresh, _attendance_receipt("daily", fresh))
	check(result.ok, "attendance claim at %d" % now)
	return result.progression

func _tier_cases() -> void:
	var p := {"achievementCounters":{"attendance":30, "killBosses":1200}, "turretModules":{"drawCount":19}}
	check(Cumulative.reached(p, "attendance") == 2 and Cumulative.reached(p, "killBosses") == 5 and Cumulative.reached(p, "moduleDraws") == 0, "reached tiers")
	check(Cumulative.next_tier(p, [], "attendance") == 1, "the first unreceived tier is next")
	var keys := [Cumulative.reward_key("attendance", 1), Cumulative.reward_key("attendance", 2)]
	check(Cumulative.next_tier(p, keys, "attendance") == 3, "received tiers are skipped")
	check(Cumulative.reward_key("killEnemies", 4) == "achievement:killEnemies:4", "reward key matches the server")
	check(Cumulative.any_claimable(p, keys), "boss tiers are claimable")
	var bosses: Array = range(1, 5).map(func(t): return Cumulative.reward_key("killBosses", t))
	check(Cumulative.next_tier(p, keys + bosses, "killBosses") == 5, "tier 5 waits for the medal")
	check(Challenges.any_claimable(p, keys + bosses), "a ready cumulative medal lights the lobby badge")
	var done := p.duplicate(true)
	done.claimedAchievementMedals = ["killBosses"]
	check(Cumulative.next_tier(done, keys + bosses, "killBosses") == 0 and not Challenges.any_claimable(done, keys + bosses), "every tier received")
	check(Cumulative.achievement_count(p) == [7, 25], "cumulative tiers count")
	check(Challenges.achievement_count(p) == [7, 91], "account count adds cumulative tiers")
	check(Cumulative.DIAMONDS == [300, 500, 700, 1000], "tier diamonds match the server")

func _arrow_stats(catalog, derived: Dictionary) -> Dictionary:
	var input: Dictionary = derived.turretStatInputs.machinegun.duplicate(true)
	input.merge({"level":1, "primaryTrait":"", "secondaryTrait":"", "gems":[]}, true)
	var stat: Dictionary = catalog.turret("machinegun", {"tileSize":1.0, "statInput":input})
	check(not stat.is_empty(), "cumulative stat inputs pass the catalog (%s)" % catalog.error)
	return stat

func _medal_cases() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(), "content")
	var service = Commands.new(catalog, growth)
	var p := {"achievementCounters":{"attendance":180, "clearWaves":12000, "killBosses":1200, "killEnemies":199999}, "turretModules":{"tickets":0, "items":[], "drawCount":400, "ticketPurchaseCount":0, "itemSequence":0}}
	check(not growth.execute(p, {"kind":"claimCumulativeMedal", "achievementId":"killEnemies"}).ok, "an unreached medal is rejected")
	check(not growth.execute(p, {"kind":"claimCumulativeMedal", "achievementId":"playTime"}).ok, "an unknown medal is rejected")
	var state := p
	for id in ["attendance", "clearWaves", "killBosses", "moduleDraws"]:
		var result: Dictionary = growth.execute(state, {"kind":"claimCumulativeMedal", "achievementId":id})
		check(result.ok, "claim %s medal" % id)
		state = result.state
	check(state.claimedAchievementMedals == ["attendance", "clearWaves", "killBosses", "moduleDraws"], "medals are recorded")
	check(not growth.execute(state, {"kind":"claimCumulativeMedal", "achievementId":"attendance"}).ok, "a medal is claimed once")
	check(Challenges.medal_total(state) == 4, "owned medal total")
	state.claimedAchievementMedals.append("killEnemies")
	state.claimedCollectionMedals = [11, 12]
	var stats: Dictionary = Challenges.achievement_stats(state)
	check(is_equal_approx(stats.turretDamage, 0.05) and is_equal_approx(stats.nexusHp, 0.08) and is_equal_approx(stats.bossDamage, 0.03), "collection and cumulative stats add")
	var base: Dictionary = service.derived(service.initial_state({}))
	var full: Dictionary = service.derived(service.initial_state(state))
	check(is_equal_approx(full.maxNexusHp, base.maxNexusHp * 1.08), "core durability adds before one multiply")
	check(not base.turretStatInputs.machinegun.has("achievementAttackSpeedMultiplier") and not base.turretStatInputs.machinegun.has("achievementCriticalChanceBonusRate"), "no medal leaves stat inputs unchanged")
	var plain_stat := _arrow_stats(catalog, base)
	var boosted_stat := _arrow_stats(catalog, full)
	if plain_stat.is_empty() or boosted_stat.is_empty(): return
	for path in ["shared", "direct"]:
		var plain: Dictionary = Stats.shared_stats_at(plain_stat, 1) if path == "shared" else Stats.stats_at(plain_stat, 1)
		var boosted: Dictionary = Stats.shared_stats_at(boosted_stat, 1) if path == "shared" else Stats.stats_at(boosted_stat, 1)
		check(is_equal_approx(boosted.attackRate, plain.attackRate * 1.02), "%s attack speed +2%%" % path)
		check(is_equal_approx(boosted.criticalChance, minf(1.0, plain.criticalChance + 0.02)), "%s critical chance adds percentage points" % path)
		check(is_equal_approx(boosted.damage, plain.damage * 1.05), "%s turret damage +5%%" % path)
	check(Challenges.stat_text("attackSpeed", 0.02) == "포탑 공격 속도 +2%" and Challenges.stat_text("criticalChance", 0.02) == "치명타 확률 +2%", "stat labels")

func _envelope(progression_extra: Dictionary) -> Dictionary:
	var progression := {"clearedStageNumbers":[1]}
	progression.merge(progression_extra, true)
	return {"version":2, "savedAtMillis":1, "preferences":{}, "progression":progression, "turretModules":{}, "activeRun":null}

func _save_cases() -> void:
	var plain: Variant = Codec.decode(_envelope({}))
	check(plain != null and not plain.progression.has("achievementCounters") and not plain.progression.has("claimedAchievementMedals"), "saves without achievements carry no fields")
	var tracked: Variant = Codec.decode(_envelope({"achievementCounters":{"killEnemies":40, "attendance":3, "bogus":9, "killBosses":-2}, "achievementAttendanceDayKey":20001, "claimedAchievementMedals":["attendance", "attendance", 7]}))
	check(tracked.progression.achievementCounters == {"attendance":3, "killBosses":0, "killEnemies":40} and tracked.progression.achievementAttendanceDayKey == 20001 and tracked.progression.claimedAchievementMedals == ["attendance"], "achievement fields round trip and normalize")
	check(Hash.hash_payload(tracked) != Hash.hash_payload(plain), "achievement fields are hashed")
	check(Hash.hash_payload(Codec.decode(tracked)) == Hash.hash_payload(tracked), "achievement save is stable on re-decode")
	var reordered: Variant = Codec.decode(_envelope({"achievementCounters":{"attendance":3, "killEnemies":40, "killBosses":0}, "achievementAttendanceDayKey":20001, "claimedAchievementMedals":["attendance"]}))
	check(Hash.hash_payload(reordered) == Hash.hash_payload(tracked), "counter key order does not change the hash")
