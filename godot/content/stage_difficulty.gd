extends RefCounted
## Hard stage difficulty (docs/stage_difficulty_design.md). The promotion table
## is the play-tuning draft; normal runs carry no difficulty field at all, so
## their saves and payload hashes are unchanged.

const Rarity = preload("res://combat/enemy_rarity.gd")
const StageProgression = preload("res://content/stage_progression.gd")

const NORMAL := "normal"
const HARD := "hard"
const RUNE_MULTIPLIER := 1.5
## Extra first-clear rewards on top of normal. The server grants the tickets
## (server/internal/economy/hard_rewards.go) and rolls the repeat rewards below.
const FIRST_CLEAR_CORE_POINTS := 1
const FIRST_CLEAR_MODULE_TICKETS := 2
## Repeat hard-clear chances: [ordinal 1 (1-1), ordinal 30 (3-10)], linear in the
## progression ordinal and still rising after 3-10. Loot chains up to 3 modules.
const TICKET_CHANCE := [0.05, 0.10]
const LOOT_FIRST_CHANCE := [0.25, 0.40]
const LOOT_EXTRA_CHANCE := [0.20, 0.30]
const LOOT_MAX_MODULES := 3
## [first 0-based round index, magic chance, rare chance]; later bands win.
const PROMOTION_BANDS := [[0, 0.08, 0.0], [10, 0.12, 0.02], [20, 0.16, 0.04], [30, 0.20, 0.06]]
## Affixes that suit an enemy type are drawn twice as often, like authored rounds.
const AFFINITY := {"fast": ["swift", "steadfast"], "shielded": ["warded", "regenerating"], "armored": ["plated", "sturdy"], "tank": ["plated", "sturdy"]}
const AFFINITY_WEIGHT := 2.0
## Two layers of recovery on one enemy outpace direct fire.
const EXCLUSIVE := [["warded", "regenerating"]]

static func of(run: Dictionary) -> String:
	return HARD if run.get("difficulty") == HARD else NORMAL

static func is_hard(run: Dictionary) -> bool:
	return of(run) == HARD

## Hard opens once the stage has a normal clear.
static func hard_unlocked(progression: Dictionary, stage_id: int) -> bool:
	return stage_id in progression.get("clearedStageNumbers", [])

static func rune_multiplier(difficulty: String) -> float:
	return RUNE_MULTIPLIER if difficulty == HARD else 1.0

static func hard_cleared(progression: Dictionary, stage_id: int) -> bool:
	return stage_id in progression.get("hardClearedStageNumbers", [])

static func _ordinal_chance(stage_id: int, bounds: Array) -> float:
	var ordinal := StageProgression.ordinal_for(stage_id)
	if ordinal < 1: return 0.0
	return minf(1.0, float(bounds[0]) + float(ordinal - 1) * (float(bounds[1]) - float(bounds[0])) / 29.0)

static func ticket_chance(stage_id: int) -> float:
	return _ordinal_chance(stage_id, TICKET_CHANCE)

static func loot_chance(stage_id: int) -> float:
	return _ordinal_chance(stage_id, LOOT_FIRST_CHANCE)

static func loot_extra_chance(stage_id: int) -> float:
	return _ordinal_chance(stage_id, LOOT_EXTRA_CHANCE)

## Whole percent for one-line tooltips, never shown as 0% or 100% by rounding.
static func percent_text(chance: float) -> String:
	return "%d%%" % clampi(int(round(chance * 100.0)), 1 if chance > 0.0 else 0, 99 if chance < 1.0 else 100)

static func best_rounds_key(difficulty: String) -> String:
	return "hardBestRoundsByStage" if difficulty == HARD else "bestRoundsByStage"

static func best_rounds(progression: Dictionary, stage_id: int, difficulty: String) -> int:
	return int(progression.get(best_rounds_key(difficulty), {}).get(str(stage_id), 0))

## Empty for normal runs. Hard promotions are keyed by the run, never by the
## shared spawn RNG, so lanes/diamonds keep their draws and resumes reproduce them.
static func promotion_seed(run: Dictionary) -> String:
	return str(run.get("economyRunId", "")) if is_hard(run) else ""

static func band(round_index: int) -> Array:
	var chosen: Array = PROMOTION_BANDS[0]
	for row in PROMOTION_BANDS:
		if round_index >= int(row[0]): chosen = row
	return chosen

## {} or {rarity, affixes} for one eligible, non-authored spawn.
static func promote(seed: String, stage_id: int, round_index: int, spawn_index: int, type: String, rules: Dictionary) -> Dictionary:
	if rules.is_empty() or not Rarity.eligible(rules, type): return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s:%d:%d:%d" % [seed, stage_id, round_index, spawn_index]).hash()
	var chances := band(round_index)
	var roll := rng.randf()
	var rarity := "rare" if roll < float(chances[2]) else ("magic" if roll < float(chances[2]) + float(chances[1]) else "")
	if rarity.is_empty(): return {}
	var count_range: Array = rules.rarities[rarity].affixCount
	var count := rng.randi_range(int(count_range[0]), int(count_range[1]))
	var preferred: Array = AFFINITY.get(type, [])
	var chosen: Array = []
	for _i in range(count):
		var pool: Array = []
		var total := 0.0
		for affix in Rarity.AFFIXES:
			if affix in chosen or _blocked(affix, chosen): continue
			var weight := AFFINITY_WEIGHT if affix in preferred else 1.0
			pool.append([affix, weight])
			total += weight
		if pool.is_empty(): break
		var pick := rng.randf() * total
		for entry in pool:
			pick -= float(entry[1])
			if pick < 0.0 or entry == pool[-1]:
				chosen.append(entry[0])
				break
	return {"rarity": rarity, "affixes": Rarity.sorted_affixes(chosen)}

static func _blocked(affix: String, chosen: Array) -> bool:
	for group in EXCLUSIVE:
		if affix in group:
			for other in group:
				if other != affix and other in chosen: return true
	return false
