extends SceneTree
## Hard difficulty: deterministic promotion, rune multiplier, separate record,
## optional save fields and the normal-clear unlock.
const Catalog = preload("res://content/content_catalog.gd")
const Difficulty = preload("res://content/stage_difficulty.gd")
const Rarity = preload("res://combat/enemy_rarity.gd")
const Quests = preload("res://app/quest_progress.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Outbox = preload("res://app/reward_outbox.gd")
const Settlement = preload("res://app/reward_settlement.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var catalog = Catalog.new()
	check(catalog.load_catalog(), "catalog")
	_promotion_cases(catalog)
	_reward_cases()
	_save_cases()
	_unlock_cases()
	_hard_reward_cases()
	_diamond_cases(catalog)
	print("STAGE_DIFFICULTY checks=%d failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)

func _rolled(catalog, stage: int, round_index: int, seed: int, hard_seed: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return catalog.random_spawn_values(stage, round_index, rng, hard_seed)

func _promotion_cases(catalog) -> void:
	var rules: Dictionary = catalog.enemy_rarity_rules()
	# Normal keeps every draw; hard only adds rarity fields to ordinary spawns.
	var stage: int = catalog.stage_index(6)
	for round_index in [0, 14, 34, 39]:
		var normal := _rolled(catalog, stage, round_index, 77, "")
		var hard := _rolled(catalog, stage, round_index, 77, "run-a")
		check(normal.size() == hard.size(), "same spawn count r%d" % round_index)
		for i in normal.size():
			for key in ["laneOffsetRatio", "visualPhase", "diamondReward"]:
				check(normal[i][key] == hard[i][key], "hard keeps %s r%d#%d" % [key, round_index, i])
			if normal[i].has("rarity"): check(normal[i].rarity == hard[i].rarity and normal[i].affixes == hard[i].affixes, "authored elite unchanged r%d#%d" % [round_index, i])
		check(_same_rarity(hard, _rolled(catalog, stage, round_index, 991, "run-a")), "promotion ignores the shared spawn RNG r%d" % round_index)
	# Rates by band, affix counts, exclusions and boss immunity over many runs.
	var magic := [0, 0, 0, 0]
	var rare := [0, 0, 0, 0]
	var total := [0, 0, 0, 0]
	var together := 0
	for run in range(160):
		var seed := "run-%d" % run
		for round_index in [0, 9, 10, 19, 20, 29, 30, 39]:
			var band: int = mini(3, round_index / 10)
			var schedule: Array = catalog._schedule(stage, round_index)
			var authored: Dictionary = catalog.elite_spawns(stage, round_index)
			var values := _rolled(catalog, stage, round_index, 5, seed)
			for i in values.size():
				var type: String = schedule[i][0]
				if authored.has(i) or not Rarity.eligible(rules, type):
					if not authored.has(i): check(not values[i].has("rarity"), "excluded type never promoted: " + type)
					continue
				total[band] += 1
				if not values[i].has("rarity"): continue
				var rarity: String = values[i].rarity
				var affixes: Array = values[i].affixes
				if rarity == "magic": magic[band] += 1
				else: rare[band] += 1
				check(Rarity.authored_affixes_valid(rules, rarity, affixes), "promoted affixes valid %s %s" % [rarity, affixes])
				if "warded" in affixes and "regenerating" in affixes: together += 1
	check(together == 0, "warded and regenerating never together")
	for band in 4:
		var expected: Array = Difficulty.PROMOTION_BANDS[band]
		var magic_rate := float(magic[band]) / maxf(1, total[band])
		var rare_rate := float(rare[band]) / maxf(1, total[band])
		check(absf(magic_rate - float(expected[1])) < 0.025, "band %d magic rate %.3f" % [band, magic_rate])
		check(absf(rare_rate - float(expected[2])) < 0.015, "band %d rare rate %.3f" % [band, rare_rate])
	check(rare[0] == 0, "no rare in the first ten rounds")
	# Bosses are excluded content-wide.
	for boss in ["boss", "shieldBoss", "forgeBoss"]:
		for i in 200: check(Difficulty.promote("s%d" % i, 1, 39, 0, boss, rules).is_empty(), "boss never promoted")
	check(Difficulty.promote("x", 1, 30, 3, "fast", rules) == Difficulty.promote("x", 1, 30, 3, "fast", rules), "promotion is deterministic")

func _same_rarity(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if a[i].get("rarity") != b[i].get("rarity") or a[i].get("affixes") != b[i].get("affixes"): return false
	return true

func _reward_cases() -> void:
	var quests = Quests.new()
	# Repeat hard runs: the hard first clear is already taken.
	var base := {"runes":0, "clearedStageNumbers":[1, 2, 3], "bestRoundsByStage":{"3":40}, "claimedCorePointStageRewards":[1, 2, 3], "hardClearedStageNumbers":[3], "totalCorePoints":6, "researchLevels":{}}
	for rounds in [1, 17, 40]:
		var normal: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":rounds, "success":rounds == 40})
		var hard: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":rounds, "success":rounds == 40, "difficulty":"hard"})
		check(absi(int(hard.lastRunRuneReward) - int(round(normal.lastRunRuneReward * 1.5))) <= 1 and hard.lastRunRuneReward > normal.lastRunRuneReward, "hard runes x1.5 at %d rounds" % rounds)
		check(hard.bestRoundsByStage == {"3":40} and hard.hardBestRoundsByStage == {"3":rounds}, "hard keeps a separate record")
		check(hard.totalCorePoints == 6 and hard.lastRunCorePointReward == 0 and hard.lastRunTurretModuleTicketReward == 0, "hard grants no first-clear reward")
		check(not normal.has("hardBestRoundsByStage"), "normal never writes the hard record")
	# A hard event without the normal claim still grants no core point.
	var unclaimed := base.duplicate(true)
	unclaimed.claimedCorePointStageRewards = []
	var hard: Dictionary = quests.finish(unclaimed, {"stageNumber":3, "completedRounds":40, "success":true, "difficulty":"hard", "firstClearCorePointReward":2})
	check(hard.totalCorePoints == 6 and hard.claimedCorePointStageRewards.is_empty(), "hard never claims the normal core point")

func _envelope(run_extra: Dictionary, progression_extra: Dictionary) -> Dictionary:
	var run := {"phase":"preparation", "stageNumber":3, "economyRunId":"run-1", "turrets":[], "enemies":[], "spawnQueue":[]}
	run.merge(run_extra, true)
	var progression := {"clearedStageNumbers":[1, 2, 3], "bestRoundsByStage":{"3":40}}
	progression.merge(progression_extra, true)
	return {"version":2, "savedAtMillis":1, "preferences":{}, "progression":progression, "turretModules":{}, "activeRun":run}

func _save_cases() -> void:
	var plain: Variant = Codec.decode(_envelope({}, {}))
	check(plain != null and not plain.activeRun.has("difficulty") and not plain.progression.has("hardBestRoundsByStage"), "normal saves carry no hard fields")
	var normal_tag: Variant = Codec.decode(_envelope({"difficulty":"normal"}, {}))
	check(not normal_tag.activeRun.has("difficulty"), "explicit normal is dropped")
	check(Hash.hash_payload(normal_tag) == Hash.hash_payload(plain), "normal payload hash unchanged")
	var hard: Variant = Codec.decode(_envelope({"difficulty":"hard"}, {"hardBestRoundsByStage":{"3":12, "x":4, "5":0}}))
	check(hard.activeRun.difficulty == "hard" and hard.progression.hardBestRoundsByStage == {"3":12}, "hard fields round trip and normalize")
	check(Difficulty.promotion_seed(hard.activeRun) == "run-1" and Difficulty.promotion_seed(plain.activeRun) == "", "restored hard run reproduces its promotions")
	check(Hash.hash_payload(hard) != Hash.hash_payload(plain), "hard fields are hashed")
	var again: Variant = Codec.decode(hard)
	check(Hash.hash_payload(again) == Hash.hash_payload(hard), "hard save is stable on re-decode")
	check(Codec.decode(_envelope({"difficulty":"master"}, {})).activeRun.has("difficulty") == false, "unknown difficulty reads as normal")

func _unlock_cases() -> void:
	check(not Difficulty.hard_unlocked({"clearedStageNumbers":[1, 2]}, 3) and Difficulty.hard_unlocked({"clearedStageNumbers":[1, 2, 3]}, 3), "hard opens after the normal clear")

func _hard_reward_cases() -> void:
	var quests = Quests.new()
	var base := {"runes":0, "clearedStageNumbers":[1, 2, 3], "bestRoundsByStage":{"3":40}, "claimedCorePointStageRewards":[1, 2, 3], "totalCorePoints":6, "researchLevels":{}}
	var first: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":40, "success":true, "difficulty":"hard"})
	check(first.totalCorePoints == 7 and first.lastRunCorePointReward == 1 and first.lastRunTurretModuleTicketReward == 2 and first.hardClearedStageNumbers == [3], "hard first clear adds 1P and two tickets")
	var again: Dictionary = quests.finish(first, {"stageNumber":3, "completedRounds":40, "success":true, "difficulty":"hard"})
	check(again.totalCorePoints == 7 and again.lastRunCorePointReward == 0 and again.lastRunTurretModuleTicketReward == 0, "hard first clear is once per stage")
	var failed: Dictionary = quests.finish(base, {"stageNumber":3, "completedRounds":30, "success":false, "difficulty":"hard"})
	check(not failed.has("hardClearedStageNumbers") and failed.lastRunTurretModuleTicketReward == 0, "a hard failure is not a clear")
	var decoded: Variant = Codec.decode(_envelope({}, {"hardClearedStageNumbers":[3, 3, "x"]}))
	check(decoded.progression.hardClearedStageNumbers == [3], "hard clears normalize")
	# Chances match server/internal/economy/hard_rewards.go.
	check(is_equal_approx(Difficulty.ticket_chance(1), 0.05) and is_equal_approx(Difficulty.ticket_chance(30), 0.10), "ticket chance 1-1 5%, 3-10 10%")
	check(is_equal_approx(Difficulty.loot_chance(1), 0.25) and is_equal_approx(Difficulty.loot_chance(30), 0.40) and is_equal_approx(Difficulty.loot_extra_chance(30), 0.30), "loot chances")
	check(Difficulty.ticket_chance(15) > Difficulty.ticket_chance(14) and Difficulty.ticket_chance(999) == 0.0, "chances follow the progression ordinal")
	check(Difficulty.percent_text(0.004) == "1%" and Difficulty.percent_text(0.3724) == "37%" and Difficulty.percent_text(0.999) == "99%", "tooltip percent text")
	# The queued settlement carries the hard ticket gift; the server checks the run.
	var reward := {"runId":"0198b955-3656-7c40-b3cb-87f427b90bf2", "stageNumber":3, "completedRounds":40, "success":true, "pendingDiamonds":0, "createdAtMillis":1, "firstClearModuleTickets":2}
	check(Outbox.valid_reward(reward), "hard first-clear tickets queue")
	reward.success = false
	check(not Outbox.valid_reward(reward), "tickets need a clear")
	var drops: Dictionary = Settlement.hard_rewards({"hardDropModuleTickets":1, "hardLootModules":[{"id":"m", "turretType":"cannon", "part":"core", "grade":"rare", "options":[]}]})
	check(drops == {"moduleTickets":1, "modules":[{"turretType":"cannon", "part":"core", "grade":"rare"}]}, "receipt drops are kept for the result")
	check(Settlement.hard_rewards({"grantedModuleTickets":5}).is_empty(), "no drop keeps nothing")

func _diamond_cases(catalog) -> void:
	# Same roll, wider carrier band: magic x2, rare x4 (their gold multipliers).
	for roll in [0.0, 0.0049, 0.0051, 0.0099, 0.0101, 0.0199, 0.0201, 0.5]:
		check((catalog._diamonds(roll, 1.0) > 0) == (roll < 0.005), "normal carrier %s" % roll)
		check((catalog._diamonds(roll, 2.0) > 0) == (roll < 0.01), "magic carrier %s" % roll)
		check((catalog._diamonds(roll, 4.0) > 0) == (roll < 0.02), "rare carrier %s" % roll)
	check(catalog._diamonds(-1.0, 4.0) == 0, "bosses never carry")
	var carried := {"": [0, 0], "magic": [0, 0], "rare": [0, 0]}
	for seed in range(400):
		var values := _rolled(catalog, catalog.stage_index(6), 34, seed, "run-%d" % seed)
		for value in values:
			var key: String = value.get("rarity", "")
			carried[key][0] += 1
			if int(value.diamondReward) > 0: carried[key][1] += 1
	var base_rate := float(carried[""][1]) / maxf(1, carried[""][0])
	var magic_rate := float(carried.magic[1]) / maxf(1, carried.magic[0])
	check(base_rate < 0.0075 and magic_rate > base_rate * 1.3, "magic carries more often (%.4f vs %.4f)" % [magic_rate, base_rate])
