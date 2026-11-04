extends SceneTree
## Headless balance benchmark. A heuristic player runs a stage through the real
## run domain (run_session/run_commands/growth_rules) and NativeCombatRuntime at
## uncapped speed. Server-only steps are stubbed locally: the gem deck follows
## the server sampling rule (3 distinct unlocked gems per offer) and run-end
## runes use the same local quest formula. Development tool; never shipped.
##
## User args (after `--`):
##   --stage=<id>          stage id (default 1)
##   --mode=grind|single   grind: fresh account replays until clear; single: one budget
##   --trajectories=<n>    grind trajectories (default 5)
##   --max-attempts=<n>    grind attempt cap per trajectory (default 30)
##   --mode=margin         single budget at falling spend rates: how much slack the stage leaves
##   --mode=campaign       fresh account through --stages=<first>-<last> in progression order;
##                         --margin=1 adds each stage's slack at the account that cleared it
##   --mode=checkpoint     like campaign, but every stage before <first> is assumed cleared once
##                         (recommended flow, settled without combat); after each failed
##                         attempt --farm-clears=<n> repeat clears of the last cleared stage
##                         are settled before the retry
##   --runes=<n>           single/margin: runes spent on permanent upgrades first
##   --progression-file=<path>  single/margin: start from this account (a report snapshot)
##   --checkpoint-dir=<dir>     checkpoint/campaign: after each clear, store the trajectory's
##                         state (account, bot memory, module RNG) in <dir>/after-<id>/
##   --resume-state=<path>      checkpoint/campaign, one trajectory: start from a stored
##                         state.bin instead of a new account; --stages must begin right after it
##   --cleared=<first>-<last>   single/margin fresh account: stages marked cleared (unlocks)
##   --params='{...}'      decision parameters over calibration.json (see DEFAULT_PARAMS)
##   --seeds=<n>           single/margin: runs per budget (default 10)
##   --spend-rate=<0..1>   single: share of gold income the bot may spend (default 1)
##   --seed=<n>            base seed (default 1)
##   --out=<path>          JSON report path (optional)
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const RunSession = preload("res://session/run_session.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Deck = preload("res://app/gem_deck.gd")
const GemReroll = preload("res://app/gem_reroll.gd")
const GemSlots = preload("res://app/gem_slot_rules.gd")
const StageProgression = preload("res://content/stage_progression.gd")
const StageDifficulty = preload("res://content/stage_difficulty.gd")
const CombatKinds = preload("res://combat/combat_kinds.gd")
const RunKinds = preload("res://app/run_command_kinds.gd")
const QuestProgress = preload("res://app/quest_progress.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")

const NOW_MILLIS := 1791560000000
const MAX_GAME_SECONDS := 4 * 3600.0
# Economy upgrades are judged by the gold they return within this many waves.
const ECONOMY_HORIZON_WAVES := 8
# Tunable decision parameters. res://tools/calibration.json (tool/balance_benchmark/
# calibration.json) overrides these defaults, and --params='{...}' overrides both.
#   saveForBest   spend only on options reaching this share of the best value per
#                 gold; otherwise save for the better option
#   gemMinGain    a reward gem worth less than this share of its turret is skipped
#   typeFactors   per turret type value multiplier, fitted from actual damage
#   slowUptime    share of a slowed stretch where the slow is actually applied
#   dotFactor/armorPierceFactor  effects the stat sheet omits
#   traitChoices  {type: {primaryTrait: index, secondaryTrait: index}}
#   gemPurchase   buy shard gem choices when shards exceed the next trait cost
#   explore       build the least-built unlocked type (calibration data only)
#   playSpeed/secondsBetweenRuns  real time per run for the research clock
#   waveLookahead upcoming waves whose shields/armor weigh each hit's value
#   newTypeBonus  extra value share for building a type not yet on the board
#   minDistinctTypes  until the board has this many types, only new types are built
#   bannedTypes   turret types the bot never builds (composition experiments)
#   typeShares    {type: share} forced composition: only listed types are built, each
#                 only while its count stays below its share of the board
#   typeAfter     {type: count} a type is built only once the board has that many turrets
#   typeProgress  {type: [from, to]} a type only on tiles whose covered path's mean
#                 progress (0 spawn, 1 core) lies in that window
#   runeWeights   {upgrade id: weight} replaces RUNE_WEIGHTS entries (e.g. an elemental board's
#                 starting account trains elemental instead of physical damage)
#   moduleType    draw every module for this turret type instead of the last run's top damage type
#   moduleFloor   grade every turret type's core/barrel/frame is lifted to before each run
#                 ("rare"): a missing or lower slot gets a rare module rolled by the draw rules,
#                 so modules do not decide which type looks strong; "" leaves draws alone
#   turretOverrides  {type: {definition field: value}} balance experiments: replaces
#                 base stats (damage, attackRate, splashRadius...) in this process only
#   baselineRunGameSeconds  game time of one assumed clear (research clock)
#   greed         between waves without pressure, buy affordable economy levels
#                 (waveGold/killGold) returning at least greedMinRoi times their cost over
#                 the remaining waves before any defense; pressure = core damage in the
#                 last wave or the 90th percentile of recent deaths at or past
#                 greedPressure of the path
#   frontTypes/frontProgress  role composition: frontTypes before that path share,
#                 the other types behind it
#   bossWeight    boss role: a turret's value adds bossWeight * shortfall * its
#                 single-target damage over the boss path. shortfall = 1 - capacity /
#                 bossMargin, capacity = damage the board deals to the coming (during
#                 a wave: the current) boss wave's bosses (within bossLookahead waves) walking the whole path
#                 / their durability. 0 keeps the crowd value alone
#   bossYield     no boss part while the crowd presses (under_pressure: core damage
#                 this wave or deep recent deaths), so crowd defense comes first
#   bossFirstHit  share of a turret's shots that reach the boss while it targets
#                 "first"; with target priority research, turrets whose hit reaches
#                 strongestHitShare of the upcoming crowd's mean durability target
#                 "strongest" and get every shot
#   bossExtraProjectileHit  share of extra projectiles that also hit the boss
#   grantResearch {id: level} research assumed done on the loaded account (ab only)
#   shardPolicy   "value": shards go to the trait or gem choice with the most value
#                 per shard (any turret; save only for an option worth more, spend
#                 everything in the last shardSpendAllWaves waves), and a reward
#                 gem must beat 10 shards at that rate. "fixed": first-ranked turret's
#                 next trait, gem choices only above the next trait cost
#   playHoursPerDay  calendar: real time passes 24 / playHoursPerDay times faster
#                 than play (research runs offline) and every elapsed day grants
#                 the daily and weekly quest/attendance rewards (all completed).
#                 0 keeps continuous play without them
#   modules       diamonds become module tickets (40 each); every ticket draws a
#                 module for the last run's top-damage turret type with the server
#                 grade/option rules, and each part keeps its best module. Run
#                 diamond drops, first-clear tickets and challenge rewards count;
#                 settled clears add the last run's drops (baselineRunDiamonds first)
#   boardRuneWeights  after a run, damage upgrades (and critical chance research) are
#                 valued by the last board's actual damage gain per level, gold
#                 upgrades by their gold as a share of the last run's income times
#                 goldElasticity (starting gold times startingGoldFactor: it compounds)
#   gemLinkCost   a gem needing a bought link nets the gold's best alternative use
#   gemReplace    a reward gem may replace an equipped one worth less
const DEFAULT_PARAMS := {
	"saveForBest": 0.7, "gemMinGain": 0.02, "typeFactors": {}, "slowUptime": 0.5,
	"dotFactor": 1.3, "armorPierceFactor": 1.1, "traitChoices": {}, "gemPurchase": true, "explore": false,
	"playSpeed": 2.0, "secondsBetweenRuns": 60.0, "waveLookahead": 3, "newTypeBonus": 0.0,
	"minDistinctTypes": 0, "bannedTypes": [], "typeShares": {}, "typeAfter": {}, "typeProgress": {}, "turretOverrides": {}, "moduleType": "", "moduleFloor": "", "runeWeights": {}, "baselineRunGameSeconds": 800.0,
	"greed": false, "greedMinRoi": 2.0, "greedPressure": 0.6, "frontTypes": [], "frontProgress": 0.5,
	"bossWeight": 0.0, "bossLookahead": 10, "bossYield": false, "bossMargin": 1.5, "strongestHitShare": 1.0, "bossFirstHit": 0.4, "bossExtraProjectileHit": 0.3,
	"grantResearch": {}, "gemLinkCost": false, "gemReplace": false,
	"shardPolicy": "fixed", "shardSpendAllWaves": 3,
	"playHoursPerDay": 0.0, "modules": false, "baselineRunDiamonds": 0,
	"boardRuneWeights": false, "goldElasticity": 0.8, "startingGoldFactor": 3.0,
}
var P: Dictionary = {}
# Rough value of one permanent upgrade level, in percent of total damage output.
# Heuristic weights; the report prints them so results can be judged against them.
const RUNE_WEIGHTS := {
	"fireTraining": 1.5, "physicalDamageTraining": 1.4, "elementalDamageTraining": 0.6,
	"poisonDamageTraining": 0.0, "criticalChance": 0.5, "criticalDamage": 0.05,
	"directDamageTraining": 0.4, "splashDamageTraining": 0.15, "damageOverTimeTraining": 0.1,
	"startingGold": 0.6, "supply": 0.6, "killGold": 0.6, "nexusHp": 0.8,
	"turretLevelUpOptimization": 0.7, "linkCostOptimization": 0.1,
	"bossBounty": 0.2, "bossDamageTraining": 0.15, "emergencySale": 0.05,
}
var catalog = Catalog.new()
var args := {}

# Per-run state.
var domain
var runtime
var epoch := 1000
const CHECKPOINT_SCHEMA := 1
var stage := 0
var next_round := 0
var next_enemy_id := 100000
var spawn_rng := RandomNumberGenerator.new()
var deck: Dictionary = {}
var path_samples: PackedVector2Array = PackedVector2Array()
# Original-path progress (0..1) of each sample; teleport jumps count as distance
# like the enemy state does, but have no samples.
var sample_progress := PackedFloat32Array()
# Branching maps (routes): each route is sampled in turn. A sample's weight is its
# route's share of the stage's enemy durability (1 on a single path); boss terms
# use the next boss's route instead.
var sample_weight := PackedFloat32Array()
var sample_route := PackedInt32Array()
var route_ids: Array = []
var boss_route := -1
const SAMPLE_STEP := 0.05
# Per turret type: predicted value at wave start and actual damage that wave.
var type_stats := {}
var wave_predicted := {}
var wave_damage_start := {}
var damage_density := PackedFloat32Array()
# Upcoming waves' layers: [{count, hp, shield, armor}] per enemy type, and the
# cached share of a hit's damage that survives armor for a given hit size.
var wave_profile: Array = []
var hit_cache := {}
var kill_gold_total := 0.0
var wave_start_hp := 0.0
# The core lost HP at some point this wave (end-of-wave recovery can hide it).
var wave_hurt := false
var coverage_cache := {}
# Path progress (0..1) where recent enemies died or arrived. Turret value only
# counts path that enemies actually reach, like a player watching the board.
var outcomes: Array = []
# The same outcomes per route id, for each route's reach.
var route_outcomes := {}
const OUTCOME_MEMORY := 150
# Shifts the observed reach outward because later waves push deeper.
const REACH_MARGIN := 0.1
var reach := PackedFloat32Array()
# Boss role (update_roles): weight of the boss part, the board's boss part total,
# the next boss wave's boss durability and speed (tiles/s), and the mean durability
# of upcoming crowd enemies (big hits above it target the strongest).
var boss_weight := 0.0
var boss_total := 0.0
var boss_need := 0.0
var boss_speed := 1.0
var crowd_durability := 0.0
var boss_capacity := 0.0
# Report only: path progress where each boss died (1 = reached the core).
var boss_results: Array = []
# Value per gold of the best purchase in the last spend pass (link cost of gems).
var gold_value_rate := 0.0
# Value per shard of the best shard option in the last shard pass (reward shards).
var shard_value_rate := 0.0
# Share of cumulative gold income the bot may spend (handicap for margin tests).
var spend_rate := 1.0
var spent_total := 0
# Board and gold income of the last finished run, for boardRuneWeights.
var last_board: Array = []
var last_income := {}
# Last run's damage per turret type (module draw target) and its diamond drops.
var last_type_damage := {}
var last_run_diamonds := -1
var module_rng := RandomNumberGenerator.new()
# Game seconds and diamond drops of the last clear per stage id, for settled clears.
var clear_stats := {}
# Set when the run cannot start (unreadable --progression-file): no report.
var fatal := false
var build_tiles: Array = []
var log_actions: Array = []
var failure := ""

func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var text := str(raw)
		if not text.begins_with("--"): continue
		var parts := text.substr(2).split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	P = DEFAULT_PARAMS.duplicate(true)
	var calibration := FileAccess.get_file_as_string("res://tools/calibration.json") if FileAccess.file_exists("res://tools/calibration.json") else ""
	for source in [calibration, str(args.get("params", ""))]:
		var parsed: Variant = JSON.parse_string(source) if not source.is_empty() else null
		if parsed is Dictionary: P.merge(parsed, true)
	if not catalog.load_catalog():
		print(JSON.stringify({"error": catalog.error}))
		quit(1)
		return
	for type in P.turretOverrides:
		var definition: Dictionary = catalog._data.turrets[type].configuration.statInput.definition
		for key in P.turretOverrides[type]:
			if not definition.has(key):
				print(JSON.stringify({"error": "unknown turret field %s.%s" % [type, key]}))
				quit(1)
				return
			definition[key] = P.turretOverrides[type][key]
	var stage_id := int(args.get("stage", "1"))
	stage = catalog.stage_index(stage_id)
	if stage < 0:
		print(JSON.stringify({"error": "unknown stage %d" % stage_id}))
		quit(1)
		return
	var started := Time.get_ticks_msec()
	var report: Dictionary
	match str(args.get("mode", "grind")):
		"single": report = single_mode(stage_id)
		"margin": report = margin_mode(stage_id)
		"campaign": report = campaign_mode()
		"checkpoint": report = checkpoint_mode()
		_: report = grind_mode(stage_id)
	if fatal:
		quit(1)
		return
	report.wallSeconds = (Time.get_ticks_msec() - started) / 1000.0
	report.heuristics = {"runeWeights": RUNE_WEIGHTS, "coreWeights": CORE_WEIGHTS, "params": P,
		"economyHorizonWaves": ECONOMY_HORIZON_WAVES, "reachMargin": REACH_MARGIN}
	var out := str(args.get("out", ""))
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "  "))
	print("BALANCE_REPORT " + JSON.stringify(summary(report)))
	quit(0)

# ---------------------------------------------------------------- account layer

func fresh_progression() -> Dictionary:
	var probe = RunSession.new()
	probe.growth.load_catalog()
	return probe.growth.data.defaultProgression.duplicate(true)

## Account for single/margin: --progression-file (a campaign clear snapshot) or
## a fresh account with --runes to spend.
func start_progression() -> Dictionary:
	var path := str(args.get("progression-file", ""))
	if not path.is_empty():
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		# Never fall back to a fresh account: that would report the wrong account.
		# The launcher treats the error line as a failed job.
		if not loaded is Dictionary:
			push_error("Unreadable --progression-file: " + path)
			fatal = true
			return {}
		var account: Dictionary = integral(loaded)
		var levels: Dictionary = account.get("researchLevels", {})
		for id in P.grantResearch: levels[id] = maxi(int(levels.get(id, 0)), int(P.grantResearch[id]))
		account.researchLevels = levels
		return account
	var p := fresh_progression()
	p.runes = int(args.get("runes", "0"))
	# --cleared=<first>-<last>: mark stages cleared for their unlocks (calibration accounts).
	if args.has("cleared"): p.clearedStageNumbers = ordered_range(str(args.cleared))
	return p

## Stage ids from <first>-<last> in progression order.
func ordered_range(text: String) -> Array:
	var bounds := text.split("-")
	var first := StageProgression.ordinal_for(int(bounds[0]))
	var last := StageProgression.ordinal_for(int(bounds[-1]))
	return StageProgression.ordered_ids().filter(func(id): return StageProgression.ordinal_for(int(id)) >= first and StageProgression.ordinal_for(int(id)) <= last)

## JSON numbers load as floats; saves keep integral values as ints.
func integral(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 9.0e15: return int(value)
	if value is Array: return value.map(func(item): return integral(item))
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = integral(value[key])
		return result
	return value

## Rough value of one research level, on the RUNE_WEIGHTS scale. Economy research
## (rune income, costs, time) is valued like a small damage gain. Target priority
## counts only with a boss role (bossWeight); emergency sale is never chosen.
const RESEARCH_WEIGHTS := {
	"criticalChance": 1.0, "runeResonance": 1.0, "researchEfficiency": 0.2, "researchCostEfficiency": 0.3,
	"runUpgradeCostOptimization": 0.3, "towerDamageLimitExpansion": 1.5, "waveGoldLimitExpansion": 0.3,
	"killGoldLimitExpansion": 0.3, "gemAttunement": 1.0, "linkExpansionOne": 1.5, "crystalRecovery": 0.2,
	"linkMaintenance": 0.1, "turretTargetPriority": 3.0,
}
# Account wall clock for research, kept in the bot's progression copies only.
const CLOCK_KEY := "_botClockMillis"
# Play time alone (clock without the calendar's offline time).
const PLAY_KEY := "_botPlayMillis"

## Spends runes on permanent upgrades and research, best weight per rune first.
## Research needs a free slot and runs on the account clock; finished research
## is collected first. Like gold, runes are saved for an option worth more.
func spend_runes(progression: Dictionary, growth) -> Dictionary:
	var p := progression.duplicate(true)
	var now := int(p.get(CLOCK_KEY, 0))
	var finished: Dictionary = growth.execute(p, {"kind": "completeFinishedResearches", "nowMillis": now})
	if finished.get("ok", false): p = finished.state
	var bought := {}
	while true:
		var options: Array = []
		var base_dps := board_damage(p, growth) if bool(P.boardRuneWeights) else 0.0
		for id in RUNE_WEIGHTS:
			var weight: float = upgrade_weight(id, p, growth, base_dps)
			if weight <= 0.0 or not growth.data.permanentUpgrades.has(id): continue
			var d: Dictionary = growth.data.permanentUpgrades[id]
			var level := int(p.get(d.field, 0))
			if not d.get("enabled", true) or level >= int(d.maxLevel) or not StageProgression.has_unlock(p, "upgrade", id): continue
			var cost := int(d.costs[level])
			options.append({"ratio": weight / cost, "cost": cost, "command": {"kind": "upgradePermanent", "id": id}})
		var slots := 2 if p.get("researchSlotTwoUnlocked", false) else 1
		if p.get("activeResearches", []).size() < slots:
			for id in RESEARCH_WEIGHTS:
				if not growth.data.research.has(id) or not StageProgression.has_unlock(p, "research", id) or not growth.research_prerequisites_met(p, id): continue
				if id == "turretTargetPriority" and float(P.bossWeight) <= 0.0: continue
				if p.get("activeResearches", []).any(func(active): return active.type == id): continue
				var quote: Dictionary = growth.research_quote(p, id)
				if quote.is_empty() or int(quote.level) >= int(growth.data.research[id].maxLevel): continue
				var research_weight: float = RESEARCH_WEIGHTS[id]
				if id == "criticalChance" and base_dps > 0.0:
					var next := p.duplicate(true)
					next.researchLevels = next.get("researchLevels", {}).duplicate()
					next.researchLevels[id] = int(next.researchLevels.get(id, 0)) + 1
					research_weight = 100.0 * (board_damage(next, growth) / base_dps - 1.0)
				options.append({"ratio": research_weight / int(quote.cost), "cost": int(quote.cost),
					"command": {"kind": "startResearch", "id": id, "nowMillis": now}})
		var best_ratio := 0.0
		for option in options: best_ratio = maxf(best_ratio, option.ratio)
		var pick := {}
		for option in options:
			if option.cost > int(p.get("runes", 0)) or option.ratio < best_ratio * float(P.saveForBest): continue
			if pick.is_empty() or option.ratio > pick.ratio: pick = option
		if pick.is_empty(): break
		var result: Dictionary = growth.execute(p, pick.command)
		if not result.get("ok", false): break
		p = result.state
		var label: String = ("research:" if pick.command.kind == "startResearch" else "") + str(pick.command.id)
		bought[label] = int(bought.get(label, 0)) + 1
	return {"progression": p, "bought": bought}

# Upgrades whose value boardRuneWeights reads from the last board's damage.
const BOARD_DAMAGE_UPGRADES := ["fireTraining", "physicalDamageTraining", "elementalDamageTraining",
	"poisonDamageTraining", "criticalChance", "criticalDamage"]

## Percent of output one more level adds: RUNE_WEIGHTS, or with boardRuneWeights
## and a finished run, measured on the last board (damage) or income (gold).
func upgrade_weight(id: String, p: Dictionary, growth, base_dps: float) -> float:
	var weight := float(P.runeWeights.get(id, RUNE_WEIGHTS[id]))
	if base_dps <= 0.0 or last_income.is_empty() or float(last_income.gold) <= 0.0: return weight
	var c: Dictionary = growth.data.constants
	var gold := float(last_income.gold)
	match id:
		"supply": return 100.0 * float(P.goldElasticity) * float(c.supplyGoldPerUpgradeLevel) * int(last_income.waves) / gold
		"killGold": return 100.0 * float(P.goldElasticity) * float(c.killGoldBonusPerUpgradeLevel) * float(last_income.killGold) / gold
		"startingGold": return 100.0 * float(P.goldElasticity) * float(P.startingGoldFactor) * float(c.startingGoldPerUpgradeLevel) / gold
	if id not in BOARD_DAMAGE_UPGRADES or not growth.data.permanentUpgrades.has(id): return weight
	var next := p.duplicate(true)
	var field: String = growth.data.permanentUpgrades[id].field
	next[field] = int(next.get(field, 0)) + 1
	return 100.0 * (board_damage(next, growth) / base_dps - 1.0)

## Damage per second of the last run's board under account p (0 without one).
func board_damage(p: Dictionary, growth) -> float:
	if last_board.is_empty(): return 0.0
	var types := {}
	var gems := {}
	for t in last_board:
		types[t.type] = true
		for gem in t.get("equippedGemSlots", []):
			if gem != null: gems[gem] = true
	var d: Dictionary = growth.derive(p, {"distinctTurretTypeCount": types.size(), "distinctEquippedGemTypeCount": gems.size(),
		"runUpgradeLevels": last_income.get("runUpgradeLevels", {})})
	var total := 0.0
	for t in last_board:
		var sheet := turret_dps(t.type, int(t.level), t, d)
		if not sheet.is_empty(): total += float(sheet.dps) * float(P.typeFactors.get(t.type, 1.0))
	return total

## Moves the account clock past one run and the pause before the next.
## With playHoursPerDay, real time runs 24 / playHoursPerDay times play time and
## each elapsed day adds the quest and attendance rewards.
func advance_clock(p: Dictionary, game_seconds: float) -> void:
	var real_seconds := game_seconds / maxf(0.1, float(P.playSpeed)) + float(P.secondsBetweenRuns)
	p[PLAY_KEY] = int(p.get(PLAY_KEY, 0)) + int(real_seconds * 1000.0)
	if float(P.playHoursPerDay) > 0.0:
		real_seconds *= 24.0 / float(P.playHoursPerDay)
		var days := real_seconds / 86400.0
		# Daily: 4 quests x20 + all complete 40 + attendance 20 diamonds, 1 ticket;
		# weekly: 4 x40 + 100 + attendance 40, 4 tickets (server/internal/weeklyreward).
		add_currency(p, days * (140.0 + 300.0 / 7.0), days * (1.0 + 4.0 / 7.0))
	p[CLOCK_KEY] = int(p.get(CLOCK_KEY, 0)) + int(real_seconds * 1000.0)

# Fractional currency stays in bot-only keys until it adds up to whole units.
const DIAMOND_FRACTION_KEY := "_botDiamondFraction"
const TICKET_FRACTION_KEY := "_botTicketFraction"
const TICKET_DIAMONDS := 40

func add_currency(p: Dictionary, diamonds: float, tickets: float) -> void:
	var d := float(p.get(DIAMOND_FRACTION_KEY, 0.0)) + diamonds
	var t := float(p.get(TICKET_FRACTION_KEY, 0.0)) + tickets
	p.freeDiamonds = int(p.get("freeDiamonds", 0)) + int(floor(d))
	p[MODULE_TICKET_KEY] = int(p.get(MODULE_TICKET_KEY, 0)) + int(floor(t))
	p[DIAMOND_FRACTION_KEY] = d - floor(d)
	p[TICKET_FRACTION_KEY] = t - floor(t)

# Server-held balances, kept on the bot's progression copy.
const MODULE_TICKET_KEY := "_botModuleTickets"
const DRAW_COUNT_KEY := "_botModuleDraws"

## Run economy the server would grant: diamond drops, first-clear tickets and
## newly met challenge rewards (odd chapter positions diamonds, even tickets).
func settle_run_economy(before: Dictionary, after: Dictionary, stage_id: int, diamonds: int, success: bool) -> void:
	var tickets := 0
	if success and not stage_id in before.get("clearedStageNumbers", []):
		tickets += int(catalog.stage_summary(catalog.stage_index(stage_id)).get("firstClearTurretModuleTicketReward", 0))
	var met: Array = after.get(StageChallenges.NORMAL_FIELD, [])
	if stage_id in met and not stage_id in before.get(StageChallenges.NORMAL_FIELD, []):
		var row: Array = StageChallenges.REWARDS[mini(StageProgression.chapter_for(stage_id), 3)]
		if StageProgression.chapter_stage_for(stage_id) % 2 == 1: diamonds += int(row[0])
		else: tickets += int(row[2])
	add_currency(after, diamonds, tickets)

## modules: all diamonds into tickets, every ticket a draw for the main type.
func draw_modules(p: Dictionary, growth) -> Dictionary:
	if not bool(P.modules): return {}
	var buy := int(p.get("freeDiamonds", 0)) / TICKET_DIAMONDS
	p.freeDiamonds = int(p.get("freeDiamonds", 0)) - buy * TICKET_DIAMONDS
	var tickets := int(p.get(MODULE_TICKET_KEY, 0)) + buy
	p[MODULE_TICKET_KEY] = 0
	if tickets <= 0: return {}
	var type := "machinegun"
	var top := -1.0
	for key in last_type_damage:
		if float(last_type_damage[key]) > top and growth.data.module.pools.has(key):
			top = float(last_type_damage[key])
			type = key
	if not str(P.moduleType).is_empty(): type = str(P.moduleType)
	var kept := 0
	for _draw in range(tickets):
		if keep_module(p, growth, generate_module(type, int(p.get(DRAW_COUNT_KEY, 0)), growth)): kept += 1
		p[DRAW_COUNT_KEY] = int(p.get(DRAW_COUNT_KEY, 0)) + 1
	return {"type": type, "draws": tickets, "kept": kept}

## Server draw rules (server/internal/economy/catalog.go): uniform part, grade by
## draw count, option count by grade, distinct pool options, uniform values.
func generate_module(type: String, draws: int, growth) -> Dictionary:
	var part: String = ["core", "barrel", "frame"][module_rng.randi_range(0, 2)]
	var rates := [64, 26, 7, 3]
	if draws >= 800: rates = [45, 35, 15, 5]
	elif draws >= 500: rates = [51, 33, 12, 4]
	elif draws >= 250: rates = [56, 30, 10, 4]
	elif draws >= 100: rates = [60, 28, 9, 3]
	var grades := ["normal", "magic", "rare", "unique"]
	return roll_module(type, part, grades[pick_weighted(rates)], growth)

## One module of a fixed grade: option count by grade, distinct pool options, uniform values.
func roll_module(type: String, part: String, grade: String, growth) -> Dictionary:
	var module_data: Dictionary = growth.data.module
	var count: int = pick_weighted({"normal": [85, 15, 0], "magic": [40, 60, 0], "rare": [10, 55, 35], "unique": [0, 40, 60]}[grade]) + 1
	var pool: Array = module_data.pools[type][part].duplicate()
	var options: Array = []
	for _i in range(mini(count, pool.size())):
		var key: String = pool.pop_at(module_rng.randi_range(0, pool.size() - 1))
		var limits: Dictionary = module_data.get("partRanges", {}).get(part, {}).get(key, module_data.ranges[key])[grade]
		options.append({"type": key, "value": module_rng.randi_range(int(limits.min), int(limits.max))})
	return {"turretType": type, "part": part, "family": module_data.families[type][part], "grade": grade, "options": options, "equipped": true}

func pick_weighted(weights: Array) -> int:
	var roll := module_rng.randi_range(0, 99)
	var cursor := 0
	for index in range(weights.size()):
		cursor += int(weights[index])
		if roll < cursor: return index
	return weights.size() - 1

## Keeps the module if it beats the equipped one of its part (only the best per
## part is kept; others count as disassembled).
func keep_module(p: Dictionary, growth, module: Dictionary) -> bool:
	var grades := ["normal", "magic", "rare", "unique"]
	if grades.find(str(module.grade)) < grades.find(str(P.moduleFloor)):
		refund_module(p, module)
		return false
	var items: Array = p.get("turretModules", {}).get("items", []).duplicate(true)
	var current := -1
	for index in range(items.size()):
		if items[index].turretType == module.turretType and items[index].part == module.part and items[index].get("equipped", false): current = index
	var trial := items.duplicate(true)
	if current >= 0: trial[current] = module
	else: trial.append(module)
	if current >= 0 and module_score(p, trial, growth) <= module_score(p, items, growth):
		refund_module(p, module)
		return false
	if current >= 0: refund_module(p, items[current])
	var modules: Dictionary = p.get("turretModules", {}).duplicate(true)
	modules.items = trial
	p.turretModules = modules
	return true

## moduleFloor: every type's empty or weaker part gets a module of that grade.
## Floor modules are bench stand-ins and refund nothing when replaced.
func lift_modules(p: Dictionary, growth) -> void:
	var grades := ["normal", "magic", "rare", "unique"]
	var floor_rank := grades.find(str(P.moduleFloor))
	if not bool(P.modules) or floor_rank < 0: return
	var modules: Dictionary = p.get("turretModules", {}).duplicate(true)
	var items: Array = modules.get("items", [])
	for type in growth.data.module.pools:
		for part in ["core", "barrel", "frame"]:
			var current := -1
			for index in range(items.size()):
				if items[index].turretType == type and items[index].part == part and items[index].get("equipped", false): current = index
			if current >= 0 and grades.find(str(items[current].grade)) >= floor_rank: continue
			var module := roll_module(type, part, str(P.moduleFloor), growth)
			module.benchFloor = true
			if current >= 0: items[current] = module
			else: items.append(module)
	modules.items = items
	p.turretModules = modules

## Disassembly refund in free diamonds (server catalog.go gradeRefund).
func refund_module(p: Dictionary, module: Dictionary) -> void:
	if module.get("benchFloor", false): return
	p.freeDiamonds = int(p.get("freeDiamonds", 0)) + int({"normal": 2, "magic": 5, "rare": 20, "unique": 50}.get(str(module.grade), 0))

## Last board's damage with these modules, plus half of each cost discount; a
## sum of damage-like options before any board exists.
func module_score(p: Dictionary, items: Array, growth) -> float:
	var discounts := 0.0
	var plain := 0.0
	for item in items:
		for option in item.options:
			if str(option.type).ends_with("Discount"): discounts += float(option.value)
			elif option.type in ["damageIncrease", "attackRateIncrease", "criticalChanceBonus", "gemEffectIncrease"]: plain += float(option.value)
			elif option.type == "criticalDamageBonus": plain += float(option.value) * 0.2
	var trial := p.duplicate()
	var modules: Dictionary = p.get("turretModules", {}).duplicate()
	modules.items = items
	trial.turretModules = modules
	var damage := board_damage(trial, growth)
	if damage <= 0.0: return plain + discounts * 0.5
	return 100.0 * damage + discounts * 0.5 * damage

func upgrade_levels(p: Dictionary, growth) -> Dictionary:
	var levels := {}
	for id in growth.data.permanentUpgrades:
		var level := int(p.get(growth.data.permanentUpgrades[id].field, 0))
		if level > 0: levels[id] = level
	return levels

## Runes in permanent upgrades plus research (list prices; cost efficiency ignored).
func runes_invested(p: Dictionary, growth) -> int:
	var total := 0
	for id in growth.data.permanentUpgrades:
		var d: Dictionary = growth.data.permanentUpgrades[id]
		for level in range(int(p.get(d.field, 0))): total += int(d.costs[level])
	for id in p.get("researchLevels", {}):
		if growth.data.research.has(id):
			for level in range(int(p.researchLevels[id])): total += int(growth.data.research[id].costs[level])
	return total

## Rough damage-equivalent value of one unit of each core passive effect
## (+1.0 directDamageIncrease = +100% direct damage). Multipliers count |value - 1|.
const CORE_WEIGHTS := {
	"directDamageIncrease": 90.0, "turretAttackRateAmplification": 100.0, "attackRateIncrease": 100.0,
	"turretLevelDamageIncrease": 60.0, "rangeIncrease": 60.0, "criticalChanceBonus": 50.0, "criticalDamageBonus": 5.0,
	"splashDamageIncrease": 30.0, "splashRadiusIncrease": 20.0, "damageOverTimeIncrease": 20.0, "burnDurationIncrease": 10.0,
	"nexusMaxHpMultiplier": 80.0, "roundClearGoldMultiplier": 40.0, "startingGoldMultiplier": 20.0,
	"buildCostMultiplier": 50.0, "turretLevelUpCostMultiplier": 70.0, "linkCostMultiplier": 5.0,
	"coreSkillPowerMultiplier": 30.0, "cooldownRecoveryRate": 20.0,
}
const MULTIPLIER_EFFECTS := ["nexusMaxHpMultiplier", "roundClearGoldMultiplier", "startingGoldMultiplier",
	"buildCostMultiplier", "turretLevelUpCostMultiplier", "linkCostMultiplier", "coreSkillPowerMultiplier"]

## Spends unspent core points one rank at a time, best weighted effect per point.
## Keystones and unweighted effects are never chosen.
func spend_core_points(progression: Dictionary, growth) -> Dictionary:
	var p := progression.duplicate(true)
	var nodes: Dictionary = growth.data.core.nodes
	while true:
		var ranks: Dictionary = p.get("corePassiveNodeRanks", {})
		var best := {}
		var best_ratio := 0.0
		for id in nodes:
			var node: Dictionary = nodes[id]
			var rank := int(ranks.get(id, 0))
			if rank >= int(node.maxRank) or bool(node.get("terminal", false)): continue
			var before: Dictionary = node.effects[rank]
			var after: Dictionary = node.effects[rank + 1]
			var value := 0.0
			for key in after:
				if not CORE_WEIGHTS.has(key) or not (after[key] is float or after[key] is int): continue
				value += absf(float(after[key]) - float(before.get(key, 1.0 if key in MULTIPLIER_EFFECTS else 0.0))) * CORE_WEIGHTS[key]
			if value <= 0.0: continue
			var trial := ranks.duplicate()
			trial[id] = rank + 1
			if not growth.valid_core_ranks(p, trial): continue
			var ratio := value / float(node.rankCosts[rank])
			if ratio > best_ratio:
				best_ratio = ratio
				best = trial
		if best.is_empty(): break
		var result: Dictionary = growth.execute(p, {"kind": "setCorePassiveRanks", "ranks": best})
		if not result.get("ok", false): break
		p = result.state
	return p

## Account spending between runs: runes on permanent upgrades, then core points.
func spend_account(progression: Dictionary, growth) -> Dictionary:
	var p := progression.duplicate(true)
	var drawn := draw_modules(p, growth)
	lift_modules(p, growth)
	var spent := spend_runes(p, growth)
	if not drawn.is_empty(): spent.bought["modules"] = drawn
	spent.progression = spend_core_points(spent.progression, growth)
	return spent

## Replays one stage, spending the account between attempts, until it clears.
func grind_stage(progression: Dictionary, stage_index: int, seed_base: int, max_attempts: int, farm_stage := 0, farm_clears := 0) -> Dictionary:
	stage = stage_index
	var p := progression
	var attempts: Array = []
	var snapshot := {}
	var probe = RunSession.new()
	probe.growth.load_catalog()
	for attempt in range(max_attempts):
		var spent := spend_account(p, probe.growth)
		p = spent.progression
		snapshot = p.duplicate(true)
		var run := play_run(p, seed_base + attempt)
		run.attempt = attempt + 1
		run.boughtBefore = spent.bought
		run.runesInvestedBefore = runes_invested(p, probe.growth)
		run.upgradesBefore = upgrade_levels(p, probe.growth)
		run.coreRanksBefore = p.get("corePassiveNodeRanks", {}).duplicate()
		run.corePointsBefore = int(p.get("totalCorePoints", 0))
		run.researchBefore = p.get("researchLevels", {}).duplicate()
		run.activeResearchBefore = p.get("activeResearches", []).map(func(active): return active.type)
		run.clockHoursBefore = snappedf(int(p.get(CLOCK_KEY, 0)) / 3600000.0, 0.01)
		run.playHoursBefore = snappedf(int(p.get(PLAY_KEY, 0)) / 3600000.0, 0.01)
		var before_run := p
		p = run.progression
		advance_clock(p, run.gameSeconds)
		if bool(P.modules):
			settle_run_economy(before_run, p, int(catalog.stage_summary(stage).get("id", 0)), int(run.diamonds), run.success)
			last_run_diamonds = int(run.diamonds)
		last_type_damage = {}
		for t in run.turrets: last_type_damage[t.type] = float(last_type_damage.get(t.type, 0.0)) + float(t.damage)
		run.modulesBefore = before_run.get("turretModules", {}).get("items", []).map(func(m): return [m.turretType, m.part, m.grade, m.options])
		run.erase("progression")
		attempts.append(run)
		if run.success: clear_stats[int(catalog.stage_summary(stage).get("id", 0))] = {"gameSeconds": float(run.gameSeconds), "diamonds": int(run.diamonds)}
		if run.success or not run.error.is_empty() or attempt == max_attempts - 1: break
		if farm_stage > 0 and farm_clears > 0:
			# Assumed farming: repeat clears of the last cleared stage, settled without combat.
			var before := int(p.get("runes", 0))
			for _clear in range(farm_clears): p = settle_clear(p, farm_stage, probe.growth)
			run.farmedAfter = {"stage": farm_stage, "clears": farm_clears, "runes": int(p.get("runes", 0)) - before}
	var cleared: bool = not attempts.is_empty() and attempts[-1].success
	return {"cleared": cleared, "attempts": attempts, "progression": p, "clearSnapshot": snapshot if cleared else {}}

func grind_mode(stage_id: int) -> Dictionary:
	var trajectories := int(args.get("trajectories", "5"))
	var max_attempts := int(args.get("max-attempts", "30"))
	var base_seed := int(args.get("seed", "1"))
	var results: Array = []
	for trajectory in range(trajectories):
		last_board = []
		last_income = {}
		last_type_damage = {}
		last_run_diamonds = -1
		clear_stats = {}
		module_rng.seed = base_seed + trajectory * 7717
		var result := grind_stage(fresh_progression(), stage, base_seed + trajectory * 1000, max_attempts)
		results.append({"trajectory": trajectory + 1, "cleared": result.cleared, "attempts": result.attempts})
	return {"mode": "grind", "stage": stage_id, "trajectories": results}

## One normal clear of a stage applied to the account without playing it: the
## same run-end settlement (runes, first-clear core points, unlocks) and clock.
func settle_clear(p: Dictionary, stage_id: int, growth) -> Dictionary:
	var summary: Dictionary = catalog.stage_summary(catalog.stage_index(stage_id))
	var result: Dictionary = QuestProgress.new().finish(p, {"completedRounds": int(summary.waveCount), "success": true,
		"stageNumber": stage_id, "difficulty": StageDifficulty.NORMAL, "challengeMet": false,
		"firstClearCorePointReward": int(summary.firstClearCorePointReward),
		"firstClearTurretModuleTicketReward": int(summary.firstClearTurretModuleTicketReward),
		"grantEconomyRewardsLocally": false,
		"runeResonanceBonusRate": float(growth.derive(p).get("runeResonanceBonusRate", 0.0))})
	# The stage's own last clear when one was played, else the assumed defaults.
	var known: Dictionary = clear_stats.get(stage_id, {})
	advance_clock(result, float(known.get("gameSeconds", P.baselineRunGameSeconds)))
	if bool(P.modules):
		settle_run_economy(p, result, stage_id, int(known.get("diamonds", P.baselineRunDiamonds)), true)
	return result

## Recommended-flow account at a stage: fresh, then every earlier stage cleared
## once in progression order, spending runes and core points before each.
func baseline_account(first_id: int, growth) -> Dictionary:
	var p := fresh_progression()
	for id in StageProgression.ordered_ids():
		if StageProgression.ordinal_for(int(id)) >= StageProgression.ordinal_for(first_id): break
		p = spend_account(p, growth).progression
		p = settle_clear(p, int(id), growth)
	return p

func checkpoint_mode() -> Dictionary:
	var order := ordered_range(str(args.get("stages", "8-10")))
	var trajectories := int(args.get("trajectories", "3"))
	var max_attempts := int(args.get("max-attempts", "10"))
	var farm_clears := int(args.get("farm-clears", "3"))
	var base_seed := int(args.get("seed", "1"))
	var probe = RunSession.new()
	probe.growth.load_catalog()
	var ids: Array = StageProgression.ordered_ids()
	var first_previous := int(ids[StageProgression.ordinal_for(int(order[0])) - 2]) if StageProgression.ordinal_for(int(order[0])) > 1 else 0
	var resume := load_resume(int(order[0]), base_seed, trajectories)
	if fatal: return {}
	var start: Dictionary
	if resume.is_empty():
		# The baseline draws modules too; seed first so every process starts alike.
		module_rng.seed = base_seed
		start = baseline_account(int(order[0]), probe.growth)
	else:
		start = resume.progression
	var results: Array = []
	var snapshots := {}
	for trajectory in range(trajectories):
		if resume.is_empty():
			reset_memory(base_seed + trajectory * 7717)
		else:
			restore_memory(resume)
		var p := start.duplicate(true)
		var previous := first_previous
		var stages: Array = []
		for id in order:
			var result := grind_stage(p, catalog.stage_index(id), base_seed + trajectory * 100000 + id * 1000, max_attempts, previous, farm_clears)
			p = result.progression
			stages.append({"stage": id, "cleared": result.cleared, "attempts": result.attempts})
			if trajectory == 0 and result.cleared: snapshots[str(id)] = result.clearSnapshot
			if not result.cleared: break
			save_checkpoint(p, int(id), base_seed, trajectory)
			previous = int(id)
		results.append({"trajectory": trajectory + 1, "stages": stages})
	return {"mode": "checkpoint", "stage": "%d-%d" % [int(order[0]), int(order[-1])], "farmClears": farm_clears,
		"baseline": {"runesInvested": runes_invested(start, probe.growth), "runes": int(start.get("runes", 0)),
			"upgrades": upgrade_levels(start, probe.growth), "research": start.get("researchLevels", {}),
			"corePoints": int(start.get("totalCorePoints", 0)), "clockHours": snappedf(int(start.get(CLOCK_KEY, 0)) / 3600000.0, 0.01),
			"resumedFrom": str(args.get("resume-state", ""))},
		"trajectories": results, "margins": {}, "clearSnapshots": snapshots}

## Bot memory that outlives a run: module draws, rune weights and settled clears read it.
func reset_memory(module_seed: int) -> void:
	last_board = []
	last_income = {}
	last_type_damage = {}
	last_run_diamonds = -1
	clear_stats = {}
	module_rng.seed = module_seed

## State after a clear's settlement, before the next stage spends: everything the
## following stages read. Godot's binary Variant format keeps int keys
## (clear_stats), int64 RNG state and Dictionary order that JSON would lose.
func trajectory_state(p: Dictionary, stage_id: int, base_seed: int, trajectory: int) -> Dictionary:
	return {"schema": CHECKPOINT_SCHEMA, "stage": stage_id, "baseSeed": base_seed, "trajectory": trajectory,
		"progression": p, "lastBoard": last_board, "lastIncome": last_income, "lastTypeDamage": last_type_damage,
		"lastRunDiamonds": last_run_diamonds, "clearStats": clear_stats,
		"moduleSeed": module_rng.seed, "moduleState": module_rng.state, "epoch": epoch}

## --checkpoint-dir: state.bin, then manifest.json (written last, so a folder
## without it is incomplete). Both go through a temp name and a rename.
func save_checkpoint(p: Dictionary, stage_id: int, base_seed: int, trajectory: int) -> void:
	var root := str(args.get("checkpoint-dir", ""))
	if root.is_empty(): return
	var folder := root.path_join("after-%d" % stage_id)
	DirAccess.make_dir_recursive_absolute(folder)
	var state_path := folder.path_join("state.bin")
	var file := FileAccess.open(state_path + ".tmp", FileAccess.WRITE)
	file.store_var(trajectory_state(p, stage_id, base_seed, trajectory), false)
	file.close()
	DirAccess.rename_absolute(state_path + ".tmp", state_path)
	var manifest := {"schema": CHECKPOINT_SCHEMA, "stage": stage_id, "baseSeed": base_seed, "trajectory": trajectory,
		"stateSha256": FileAccess.get_sha256(state_path), "engine": Engine.get_version_info().string}
	var info := FileAccess.open(folder.path_join("manifest.json.tmp"), FileAccess.WRITE)
	info.store_string(JSON.stringify(manifest, "  "))
	info.close()
	DirAccess.rename_absolute(folder.path_join("manifest.json.tmp"), folder.path_join("manifest.json"))

## --resume-state: the stored trajectory state, checked against this process's
## stages and seed. {} without the option; fatal on any mismatch.
func load_resume(first_id: int, base_seed: int, trajectories: int) -> Dictionary:
	var path := str(args.get("resume-state", ""))
	if path.is_empty(): return {}
	var problem := ""
	var state: Variant = null
	if trajectories != 1: problem = "resume runs one trajectory per process"
	elif not FileAccess.file_exists(path): problem = "missing " + path
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		state = file.get_var(false)
		if not state is Dictionary or int(state.get("schema", -1)) != CHECKPOINT_SCHEMA: problem = "unreadable state " + path
		elif int(state.baseSeed) != base_seed: problem = "seed %d does not match the stored trajectory's %d" % [base_seed, int(state.baseSeed)]
		else:
			var ids: Array = StageProgression.ordered_ids()
			var next := ids.find(int(state.stage)) + 1
			if next <= 0 or next >= ids.size() or int(ids[next]) != first_id:
				problem = "--stages must start right after stage %d" % int(state.stage)
	if not problem.is_empty():
		push_error("Cannot resume: " + problem)
		fatal = true
		return {}
	return state

func restore_memory(state: Dictionary) -> void:
	last_board = state.lastBoard.duplicate(true)
	last_income = state.lastIncome.duplicate(true)
	last_type_damage = state.lastTypeDamage.duplicate(true)
	last_run_diamonds = int(state.lastRunDiamonds)
	clear_stats = state.clearStats.duplicate(true)
	# Seed first: assigning the seed resets the state.
	module_rng.seed = int(state.moduleSeed)
	module_rng.state = int(state.moduleState)
	epoch = int(state.epoch)

## Fresh account through the stages in progression order (--stages=1-5): each
## stage is replayed until it clears, keeping runes, core points and unlocks.
## --margin=1 then measures each stage's slack with the account that cleared it
## in the first trajectory.
func campaign_mode() -> Dictionary:
	var order := ordered_range(str(args.get("stages", "1-5")))
	var first := int(order[0])
	var last := int(order[-1])
	var trajectories := int(args.get("trajectories", "3"))
	var max_attempts := int(args.get("max-attempts", "30"))
	var base_seed := int(args.get("seed", "1"))
	var resume := load_resume(first, base_seed, trajectories)
	if fatal: return {}
	var results: Array = []
	var margin_inputs := {}
	for trajectory in range(trajectories):
		if resume.is_empty():
			reset_memory(base_seed + trajectory * 7717)
		else:
			restore_memory(resume)
		var p: Dictionary = fresh_progression() if resume.is_empty() else resume.progression.duplicate(true)
		var stages: Array = []
		for id in order:
			var result := grind_stage(p, catalog.stage_index(id), base_seed + trajectory * 100000 + id * 1000, max_attempts)
			p = result.progression
			stages.append({"stage": id, "cleared": result.cleared, "attempts": result.attempts})
			if trajectory == 0 and result.cleared: margin_inputs[id] = result.clearSnapshot
			if not result.cleared: break
			save_checkpoint(p, int(id), base_seed, trajectory)
		results.append({"trajectory": trajectory + 1, "stages": stages})
	var margins := {}
	if args.get("margin", "0") == "1":
		for id in margin_inputs:
			stage = catalog.stage_index(id)
			margins[str(id)] = margin_levels(margin_inputs[id], int(args.get("seeds", "3")), base_seed)
	var snapshots := {}
	for id in margin_inputs: snapshots[str(id)] = margin_inputs[id]
	return {"mode": "campaign", "stage": "%d-%d" % [first, last], "trajectories": results, "margins": margins, "clearSnapshots": snapshots}

func single_mode(stage_id: int) -> Dictionary:
	var seeds := int(args.get("seeds", "10"))
	var base_seed := int(args.get("seed", "1"))
	var p := start_progression()
	if fatal: return {}
	var probe = RunSession.new()
	probe.growth.load_catalog()
	var spent := spend_runes(p, probe.growth)
	spend_rate = clampf(float(args.get("spend-rate", "1")), 0.0, 1.0)
	var runs := play_seeds(spent.progression, seeds, base_seed)
	return {"mode": "single", "stage": stage_id, "runeBudget": int(args.get("runes", "0")), "spendRate": spend_rate,
		"upgrades": upgrade_levels(spent.progression, probe.growth), "runs": runs}

func play_seeds(progression: Dictionary, seeds: int, base_seed: int) -> Array:
	var runs: Array = []
	for index in range(seeds):
		var run := play_run(progression, base_seed + index)
		run.erase("progression")
		runs.append(run)
	return runs

## Lowers the spendable share of gold until the bot stops clearing. A stage
## the bot clears on a small share leaves a lot of slack for real players.
func margin_mode(stage_id: int) -> Dictionary:
	var seeds := int(args.get("seeds", "5"))
	var base_seed := int(args.get("seed", "1"))
	var p := start_progression()
	if fatal: return {}
	var probe = RunSession.new()
	probe.growth.load_catalog()
	var spent := spend_runes(p, probe.growth)
	return {"mode": "margin", "stage": stage_id, "runeBudget": int(args.get("runes", "0")),
		"upgrades": upgrade_levels(spent.progression, probe.growth), "levels": margin_levels(spent.progression, seeds, base_seed)}

func margin_levels(progression: Dictionary, seeds: int, base_seed: int) -> Array:
	var levels: Array = []
	for rate in [1.0, 0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.15, 0.1]:
		spend_rate = rate
		var runs := play_seeds(progression, seeds, base_seed)
		var clears := 0
		var waves: Array = []
		var core: Array = []
		for run in runs:
			if run.success: clears += 1
			waves.append(run.completedRounds)
			core.append(snappedf(run.coreHp, 0.1))
			run.erase("actionLog")
		levels.append({"spendRate": rate, "clearRate": float(clears) / seeds, "waves": waves, "coreHp": core, "runs": runs})
		if clears == 0: break
	spend_rate = 1.0
	return levels

func summary(report: Dictionary) -> Dictionary:
	var result := {"mode": report.mode, "stage": report.stage, "wallSeconds": report.wallSeconds}
	if report.mode == "grind":
		var rows: Array = []
		for trajectory in report.trajectories:
			var waves: Array = []
			for run in trajectory.attempts: waves.append(run.completedRounds)
			var last: Dictionary = trajectory.attempts[-1]
			rows.append({"cleared": trajectory.cleared, "attempts": trajectory.attempts.size(), "wavesPerAttempt": waves,
				"runesInvestedAtClear": last.runesInvestedBefore, "lastCoreHp": last.coreHp, "error": last.error})
		result.trajectories = rows
	elif report.mode in ["campaign", "checkpoint"]:
		var rows: Array = []
		for trajectory in report.trajectories:
			var stages: Array = []
			for entry in trajectory.stages:
				var waves: Array = []
				for run in entry.attempts: waves.append(run.completedRounds)
				var last: Dictionary = entry.attempts[-1]
				stages.append({"stage": entry.stage, "cleared": entry.cleared, "wavesPerAttempt": waves,
					"runesInvested": last.runesInvestedBefore, "corePoints": last.corePointsBefore,
					"coreHp": snappedf(last.coreHp, 0.1), "error": last.error})
			rows.append(stages)
		result.trajectories = rows
		var margins := {}
		for id in report.margins:
			var levels: Array = []
			for level in report.margins[id]: levels.append([level.spendRate, level.clearRate, level.coreHp])
			margins[id] = levels
		result.margins = margins
	elif report.mode == "margin":
		var rows: Array = []
		for level in report.levels: rows.append({"spendRate": level.spendRate, "clearRate": level.clearRate, "waves": level.waves})
		result.merge({"runeBudget": report.runeBudget, "levels": rows})
	else:
		var clears := 0
		var waves: Array = []
		for run in report.runs:
			if run.success: clears += 1
			waves.append(run.completedRounds)
		result.merge({"runeBudget": report.runeBudget, "clearRate": float(clears) / maxf(1, report.runs.size()), "waves": waves})
	return result

# ---------------------------------------------------------------- run layer

func play_run(progression: Dictionary, seed: int) -> Dictionary:
	epoch += 1
	next_round = 0
	next_enemy_id = 100000
	failure = ""
	log_actions = []
	outcomes = []
	route_outcomes = {}
	boss_results = []
	boss_weight = 0.0
	boss_total = 0.0
	boss_need = 0.0
	crowd_durability = 0.0
	gold_value_rate = 0.0
	shard_value_rate = 0.0
	spent_total = 0
	kill_gold_total = 0.0
	wave_start_hp = 0.0
	wave_hurt = false
	spawn_rng.seed = seed
	domain = RunSession.new()
	domain.now_millis = func(): return NOW_MILLIS
	# A seeded run id keeps accounts (claimedEventIds) identical across repeated runs.
	if not domain.initialize(catalog, progression, stage, epoch, "bench-%d-%d" % [seed, epoch]):
		return run_result(progression, 0.0, "initialize: " + str(domain.error))
	domain.state.tileSize = 1.0
	var effects: Dictionary = domain.growth.derive(domain.growth.run_effect_progression(domain.state))
	var inputs := {"defenseConfig": effects.defenseConfig, "combatConfig": domain.growth.combat_config(effects),
		"coreConfig": domain.growth.core_config(domain.state, stage, 0, catalog)}
	var initial: Dictionary = catalog.bootstrap(stage, inputs)
	if initial.is_empty(): return run_result(progression, 0.0, "bootstrap: " + str(catalog.error))
	initial.seed = seed
	runtime = Runtime.new()
	var rejected: String = runtime.start(epoch, initial, {"clock": "godot", "phase": "preparation", "paused": false, "speed": 4.0})
	if not rejected.is_empty(): return run_result(progression, 0.0, "start: " + rejected)
	runtime.step_completed.connect(_on_step)
	prepare_board(initial)
	wave_profile = []
	hit_cache = {}
	type_stats = {}
	wave_predicted = {}
	deck = make_deck(domain.state, seed)
	var game_time := 0.0
	var since_spend := 0.0
	while failure.is_empty() and game_time < MAX_GAME_SECONDS:
		match str(domain.state.phase):
			"preparation":
				spend()
				if not start_wave(): break
			"reward":
				handle_reward()
			"wave":
				var before: float = runtime.clock
				runtime.advance_session(0.25)
				var step: float = maxf(0.0, runtime.clock - before)
				if runtime.defense.hp < wave_start_hp - 0.001: wave_hurt = true
				if step <= 0.0 and str(domain.state.phase) == "wave":
					failure = "combat stalled at wave %d" % next_round
					break
				game_time += step
				since_spend += step
				if since_spend >= 1.0 and str(domain.state.phase) == "wave":
					since_spend = 0.0
					spend()
			_:
				break
	if failure.is_empty() and str(domain.state.phase) == "wave": failure = "time cap"
	close_wave_stats()
	if not domain.state.turrets.is_empty():
		last_board = domain.state.turrets.duplicate(true)
		last_income = {"gold": float(spent_total + int(domain.state.gold)), "killGold": kill_gold_total,
			"runUpgradeLevels": domain.state.get("runUpgradeLevels", {}).duplicate(),
			"waves": int(domain.state.get("completedRounds", 0))}
	return run_result(domain.state.progression, game_time, failure)

func run_result(progression: Dictionary, game_time: float, error: String) -> Dictionary:
	var state: Dictionary = domain.state if domain != null else {}
	var turrets: Array = []
	var derived: Dictionary = domain.service.derived(state) if domain != null and not state.is_empty() else {}
	for t in state.get("turrets", []):
		var sheet := turret_dps(t.type, int(t.level), t, derived) if not derived.is_empty() else {}
		turrets.append({"type": t.type, "x": t.x, "y": t.y, "level": t.level, "gems": t.equippedGemSlots.filter(func(g): return g != null),
			"primaryTrait": t.primaryTrait, "targetPriority": t.get("targetPriority", "first"), "damage": roundi(float(t.get("damageDealt", 0.0))),
			"pathProgress": snappedf(covered_progress(Vector2i(t.x, t.y), float(sheet.range)), 0.01) if not sheet.is_empty() else -1.0})
	for live in (runtime.turrets.values() if runtime != null else []):
		for row in turrets:
			if row.x == int(live.state.x) and row.y == int(live.state.y):
				row.damage = roundi(float(live.get("directDamageDealt", 0)) + float(live.get("splashDamageDealt", 0)) + float(live.get("chainDamageDealt", 0)) + float(live.get("burnDamageDealt", 0)))
				row.damageParts = [roundi(float(live.get("directDamageDealt", 0))), roundi(float(live.get("splashDamageDealt", 0))), roundi(float(live.get("chainDamageDealt", 0))), roundi(float(live.get("burnDamageDealt", 0)))]
	return {"success": str(state.get("phase", "")) == "success", "completedRounds": int(state.get("completedRounds", 0)),
		"waveCount": catalog.wave_count(stage), "coreHp": (runtime.defense.hp if runtime != null else 0.0),
		"coreMaxHp": (float(runtime.defense.max_hp) if runtime != null and "max_hp" in runtime.defense else 0.0),
		"runeReward": int(progression.get("lastRunRuneReward", 0)), "runesAfter": int(progression.get("runes", 0)),
		"gameSeconds": snappedf(game_time, 0.1), "goldLeft": int(state.get("gold", 0)), "turrets": turrets,
		"actions": log_actions.size(), "actionLog": log_actions, "typeStats": type_stats.duplicate(true),
		"gemShardsLeft": int(state.get("gemShards", 0)), "bossResults": boss_results.duplicate(),
		"diamonds": int(state.get("pendingEconomyDiamonds", 0)), "error": error, "progression": progression}

func _on_step() -> void:
	if runtime.event_id > domain.event_ack:
		# Read death progress before the ACK removes the enemy.
		for event in runtime.events:
			if int(event.id) <= domain.event_ack: continue
			if event.kind != CombatKinds.ARRIVAL and event.kind != CombatKinds.KILL: continue
			var enemy: Dictionary = runtime.enemies.get(str(event.get("enemyId", "")), {})
			var boss := not enemy.is_empty() and bool(catalog.enemy_definition(str(enemy.get("type", ""))).get("isBoss", false))
			var outcome := -1.0
			if event.kind == CombatKinds.ARRIVAL:
				# The wave-end heal can undo the last arrival within the same advance.
				wave_hurt = true
				outcome = 1.0
			else:
				if not enemy.is_empty() and float(enemy.get("_total", 0.0)) > 0.0:
					outcome = clampf(float(enemy.distanceTravelled) / float(enemy._total), 0.0, 1.0)
				if not enemy.is_empty(): kill_gold_total += float(catalog.enemy_definition(str(enemy.get("type", ""))).get("rewardGold", 0))
			if outcome < 0.0: continue
			outcomes.append(outcome)
			if not enemy.is_empty():
				var route := route_key(str(enemy.get("routeId", "")))
				var list: Array = route_outcomes.get(route, [])
				list.append(outcome)
				route_outcomes[route] = list.slice(list.size() - OUTCOME_MEMORY) if list.size() > OUTCOME_MEMORY else list
			if boss: boss_results.append([next_round, snappedf(outcome, 0.01)])
		if outcomes.size() > OUTCOME_MEMORY: outcomes = outcomes.slice(outcomes.size() - OUTCOME_MEMORY)
	if runtime.event_id > domain.event_ack or runtime.session.get("phase") != domain.state.phase:
		if not send(): runtime.session.paused = true

func send(commands: Array = [], patch: Dictionary = {}) -> bool:
	var collected: Dictionary = domain.collect(runtime)
	if not collected.get("ok", false):
		failure = "collect: " + str(domain.error)
		return false
	if not patch.has("phase"): patch.phase = domain.state.phase
	var rejected: String = runtime.apply_batch(epoch, collected.get("commands", []) + commands, patch, domain.event_ack)
	if not rejected.is_empty():
		failure = "runtime rejected: " + rejected
		return false
	return true

func apply(request: Dictionary) -> bool:
	if not send(): return false
	var previous: Dictionary = domain.state.duplicate(true)
	var result: Dictionary = domain.apply(request)
	if not result.get("ok", false): return false
	if not send(result.get("commands", []), {"phase": domain.state.phase}):
		domain.state = previous
		return false
	spent_total += maxi(0, int(previous.gold) - int(domain.state.gold))
	log_actions.append(request)
	return true

func start_wave() -> bool:
	if not send(): return false
	if str(domain.state.phase) != "preparation" or next_round >= catalog.wave_count(stage): return false
	close_wave_stats()
	update_reach()
	update_wave_profile()
	open_wave_stats()
	if float(P.bossWeight) > 0.0 and catalog.wave_has_boss(stage, next_round):
		update_roles(domain.service.derived(domain.state))
		log_actions.append({"kind": "bossCheck", "round": next_round + 1, "capacity": snappedf(boss_capacity, 0.01)})
	wave_start_hp = runtime.defense.hp
	wave_hurt = false
	var inputs := {"initialDelay": catalog.initial_delay(),
		"spawnValues": catalog.random_spawn_values(stage, next_round, spawn_rng, StageDifficulty.promotion_seed(domain.state))}
	var wave: Dictionary = catalog.wave(stage, next_round, next_enemy_id, inputs)
	if wave.is_empty():
		failure = "wave: " + str(catalog.error)
		return false
	wave.coreConfig = domain.growth.core_config(domain.state, stage, next_round, catalog)
	next_enemy_id += wave.spawnQueue.size()
	domain.state.phase = "wave"
	domain.state.roundIndex = next_round
	next_round += 1
	return send([{"kind": CombatKinds.COMMAND_WAVE_START, "wave": wave}], {"phase": "wave", "paused": false})

func live_damage() -> Dictionary:
	var result := {}
	for live in runtime.turrets.values():
		result[int(live.id)] = float(live.get("directDamageDealt", 0)) + float(live.get("splashDamageDealt", 0)) + float(live.get("chainDamageDealt", 0)) + float(live.get("burnDamageDealt", 0))
	return result

## Predicted value of each turret for the coming wave, compared with the damage
## it actually deals in that wave (calibration data for typeFactors).
func open_wave_stats() -> void:
	var d: Dictionary = domain.service.derived(domain.state)
	wave_predicted = {}
	for t in domain.state.turrets:
		# Own damage only, unscaled by typeFactors, so a fit is relative to the raw
		# stat model. Slow value is tuned separately (slowUptime).
		var sheet := turret_dps(t.type, int(t.level), t, d)
		if sheet.is_empty(): continue
		wave_predicted[int(t.id)] = {"type": t.type, "predicted": sheet.dps * coverage(Vector2i(t.x, t.y), sheet.range)}
	wave_damage_start = live_damage()

## Waves that hurt the core also count separately: the board was saturated, so
## a strong type's damage is not capped by enemies it had nothing left to hit.
func close_wave_stats() -> void:
	if wave_predicted.is_empty(): return
	var now := live_damage()
	var pressured: bool = wave_hurt or (runtime != null and runtime.defense.hp < wave_start_hp - 0.001)
	for id in wave_predicted:
		if not now.has(id): continue
		var row: Dictionary = wave_predicted[id]
		var stats: Dictionary = type_stats.get(row.type, {"predicted": 0.0, "actual": 0.0, "turretWaves": 0,
			"pressurePredicted": 0.0, "pressureActual": 0.0, "pressureWaves": 0})
		var dealt: float = now[id] - float(wave_damage_start.get(id, 0.0))
		stats.predicted += row.predicted
		stats.actual += dealt
		stats.turretWaves += 1
		if pressured:
			stats.pressurePredicted += row.predicted
			stats.pressureActual += dealt
			stats.pressureWaves += 1
		type_stats[row.type] = stats
	wave_predicted = {}

# ---------------------------------------------------------------- gem deck stub

func make_deck(state: Dictionary, seed: int) -> Dictionary:
	var available: Array = []
	for gem in GemReroll.GEM_TYPES:
		if StageProgression.has_unlock(state.progression, "gem", gem): available.append(gem)
	if available.size() < 3: return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 17
	var waves := {}
	for wave in range(5, 36, 5):
		waves[str(wave)] = {"offerId": "bot-wave-%d" % wave, "options": [sample_gems(available, rng)]}
	var purchases: Array = []
	for index in range(24): purchases.append({"offerId": "bot-purchase-%d" % index, "options": sample_gems(available, rng)})
	return {"version": Deck.VERSION, "runId": str(state.economyRunId), "waves": waves, "purchases": purchases}

func sample_gems(available: Array, rng: RandomNumberGenerator) -> Array:
	var pool := available.duplicate()
	var picked: Array = []
	for i in range(3):
		var index := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return picked

## Best placement of one gem: an empty compatible slot with the largest gain.
## With buy_slot, also a turret whose next link slot the gold can buy now.
## Best turret and slot for a gem: an empty slot, a bought link (its gold's best
## alternative use subtracted with gemLinkCost) or, with gemReplace, an equipped
## gem worth less. gain is the net value increase.
func best_gem_target(gem: String, d: Dictionary, buy_slot: bool = false) -> Dictionary:
	var best := {}
	for t in domain.state.turrets:
		if not GemSlots.can_equip(t, gem, domain.service._rule(t.type)): continue
		var tile := Vector2i(t.x, t.y)
		var before := turret_value(t.type, int(t.level), t, d, tile)
		if before <= 0.0: continue
		var candidates: Array = []
		var empty: int = t.equippedGemSlots.find(null)
		if empty >= 0: candidates.append({"slot": empty, "linkCost": 0})
		else:
			var link_cost := int(domain.service.quotes_from_derived(domain.state, int(t.id), d).get("link", 0))
			if buy_slot and link_cost > 0: candidates.append({"slot": int(t.slotLimit), "linkCost": link_cost})
			if bool(P.gemReplace):
				for slot in range(t.equippedGemSlots.size()):
					if t.equippedGemSlots[slot] != gem: candidates.append({"slot": slot, "linkCost": 0, "replace": true})
		for candidate in candidates:
			var trial: Dictionary = t.duplicate(true)
			if candidate.slot >= trial.equippedGemSlots.size(): trial.equippedGemSlots.append(gem)
			else: trial.equippedGemSlots[candidate.slot] = gem
			var gain := turret_value(t.type, int(t.level), trial, d, tile) - before
			if bool(P.gemLinkCost): gain -= candidate.linkCost * gold_value_rate
			if gain <= 0.0: continue
			if best.is_empty() or gain > best.gain:
				best = {"id": int(t.id), "slot": candidate.slot, "gain": gain, "share": gain / before,
					"linkCost": candidate.linkCost, "replace": candidate.get("replace", false)}
	return best

func handle_reward() -> void:
	if not GemReroll.current_offer(domain.state):
		var offered: Dictionary = Deck.offer(domain.state, deck) if not deck.is_empty() else {}
		if offered.is_empty():
			# No local candidate (too few unlocked gems): continue like a skipped reward.
			domain.state.phase = "preparation"
			send([], {"phase": "preparation"})
			return
		domain.state = offered
	var purchased := bool(domain.state.get("isPurchasedGemReward", false))
	var d: Dictionary = domain.service.derived(domain.state)
	update_roles(d)
	var best_gem := "shards"
	var best := {}
	for gem in domain.state.rewardOptions:
		var target := best_gem_target(gem, d, true)
		if target.is_empty(): continue
		if not purchased and target.share < float(P.gemMinGain): continue
		if not purchased and P.shardPolicy == "value" and target.gain < 10.0 * shard_value_rate: continue
		if best.is_empty() or target.gain > best.gain:
			best = target
			best_gem = gem
	# A purchased offer has no shard alternative; keep the first gem in the bag.
	if purchased and best_gem == "shards": best_gem = domain.state.rewardOptions[0]
	var chosen: Dictionary = Deck.choose(domain.state, best_gem)
	if chosen.is_empty():
		failure = "gem choice rejected"
		return
	domain.state = chosen
	log_actions.append({"kind": "gemChoice", "choice": best_gem, "purchased": purchased})
	send([], {"phase": domain.state.phase})
	equip_bag_gems()

## Equips bag gems into empty slots (buying a link when it pays for itself).
func equip_bag_gems() -> void:
	for gem in domain.state.get("gemInventory", {}).keys():
		if int(domain.state.gemInventory.get(gem, 0)) <= 0: continue
		var d: Dictionary = domain.service.derived(domain.state)
		update_roles(d)
		var target := best_gem_target(gem, d, true)
		if target.is_empty() or target.share < float(P.gemMinGain): continue
		if target.linkCost > 0:
			if target.linkCost > spendable_gold(): continue
			if not apply({"kind": RunKinds.LINK, "id": target.id}): continue
		apply({"kind": RunKinds.EQUIP_GEM, "id": target.id, "type": gem, "slot": target.slot})
		if target.replace: log_actions.append({"kind": "gemReplace", "gem": gem, "id": target.id})

## Spends spare shards on a gem choice, keeping enough for the next trait.
func buy_gem_choice() -> void:
	if not bool(P.gemPurchase) or deck.is_empty() or str(domain.state.phase) != "preparation": return
	var cost := int(domain.service.growth.data.constants.gemChoicePurchaseCost)
	var reserve := 0
	var d: Dictionary = domain.service.derived(domain.state)
	for t in domain.state.turrets:
		var q: Dictionary = domain.service.quotes_from_derived(domain.state, int(t.id), d)
		if t.get("primaryTrait") == null and int(t.level) >= 2: reserve = maxi(reserve, int(q.get("primaryTrait", 0)))
		elif t.get("secondaryTrait") == null and int(t.level) >= 6: reserve = maxi(reserve, int(q.get("secondaryTrait", 0)))
	if int(domain.state.gemShards) < cost + reserve: return
	var next: Dictionary = Deck.purchase(domain.state, deck, cost)
	if next.is_empty(): return
	domain.state = next
	send([], {"phase": domain.state.phase})
	handle_reward()

# ---------------------------------------------------------------- placement and value

func prepare_board(initial: Dictionary) -> void:
	coverage_cache = {}
	reach = PackedFloat32Array()
	damage_density = PackedFloat32Array()
	path_samples = PackedVector2Array()
	sample_progress = PackedFloat32Array()
	sample_weight = PackedFloat32Array()
	sample_route = PackedInt32Array()
	boss_route = -1
	var routes: Array = initial.get("routes", [])
	if routes.is_empty(): routes = [{"id": "", "path": initial.path, "teleportPairs": initial.get("teleportPairs", [])}]
	route_ids = routes.map(func(route): return str(route.id))
	var shares := route_shares()
	for index in range(routes.size()):
		sample_route_path(routes[index].path, routes[index].get("teleportPairs", []), index, shares[index])
	build_tiles = []
	var map: Dictionary = catalog.stage_map(stage)
	for index in range(map.tiles.size()):
		if map.tiles[index] == "build": build_tiles.append(Vector2i(index % int(map.columns), int(index / int(map.columns))))

func sample_route_path(world_path: Array, teleports: Array, route: int, weight: float) -> void:
	var jumps := {}
	for pair in teleports: jumps[int(pair.entranceIndex)] = int(pair.exitIndex)
	var total := 0.0
	for i in range(world_path.size() - 1):
		total += Vector2(float(world_path[i].x), float(world_path[i].y)).distance_to(Vector2(float(world_path[i + 1].x), float(world_path[i + 1].y)))
	var travelled := 0.0
	for i in range(world_path.size() - 1):
		var a := Vector2(float(world_path[i].x), float(world_path[i].y))
		var b := Vector2(float(world_path[i + 1].x), float(world_path[i + 1].y))
		var length := a.distance_to(b)
		if jumps.get(i, -1) != i + 1:
			var steps := maxi(1, int(ceil(length / SAMPLE_STEP)))
			for s in range(steps):
				path_samples.append(a.lerp(b, float(s) / steps))
				sample_progress.append((travelled + length * s / steps) / maxf(0.001, total))
				sample_weight.append(weight)
				sample_route.append(route)
		travelled += length

## Each route's share of the stage's enemy durability (groups without a route
## walk the primary one, route 0).
func route_shares() -> Array:
	if route_ids.size() == 1: return [1.0]
	var totals: Array = []
	totals.resize(route_ids.size())
	totals.fill(0.0)
	for wave in catalog._data.stages[stage].waves:
		var durability: Dictionary = wave.get("enemyDurability", {})
		for group in wave.groups:
			var layers: Array = durability.get(group.enemyType, [1.0, 0.0, 0.0])
			totals[route_index(str(group.get("routeId", "")))] += (float(layers[0]) + float(layers[1]) + float(layers[2])) * int(group.count)
	var sum: float = totals.reduce(func(a, b): return a + b, 0.0)
	return totals.map(func(value): return value / sum if sum > 0.0 else 1.0 / route_ids.size())

func route_index(route_id: String) -> int:
	return maxi(0, route_ids.find(route_id))

func route_key(route_id: String) -> String:
	return str(route_ids[route_index(route_id)])

## Weight of a sample for boss terms: the next boss's route, else the crowd share.
func boss_path_length() -> float:
	var total := 0.0
	for i in range(path_samples.size()): total += boss_sample_weight(i)
	return total * SAMPLE_STEP

func boss_sample_weight(i: int) -> float:
	if boss_route < 0: return sample_weight[i]
	return 1.0 if sample_route[i] == boss_route else 0.0

## Reached path length (tiles) inside the turret's range: how long enemies that
## actually get there stay targetable. Before any outcome every sample counts.
## With full, the whole path (a boss the board cannot kill walks all of it).
func coverage(tile: Vector2i, radius: float, full := false) -> float:
	var key := "%d,%d,%.2f,%s,%d" % [tile.x, tile.y, radius, full, boss_route if full else -2]
	if coverage_cache.has(key): return coverage_cache[key]
	var curve := PackedFloat32Array() if full else reach
	var center := Vector2(tile.x + 0.5, tile.y + 0.5)
	var inside := 0.0
	for i in range(path_samples.size()):
		if path_samples[i].distance_to(center) <= radius:
			inside += (curve[i] if not curve.is_empty() else 1.0) * (boss_sample_weight(i) if full else sample_weight[i])
	var value := inside * SAMPLE_STEP
	coverage_cache[key] = value
	return value

## Survival curve of recent enemies along the path.
func update_reach() -> void:
	coverage_cache = {}
	reach = survival(outcomes)
	if route_ids.size() > 1 and not reach.is_empty():
		# Each route's own outcomes where it has any.
		for route in range(route_ids.size()):
			var curve := survival(route_outcomes.get(route_ids[route], []))
			if curve.is_empty(): continue
			for i in range(path_samples.size()):
				if sample_route[i] == route: reach[i] = curve[i]

## Share of the outcomes still alive at each sample, shifted outward by the margin.
func survival(list: Array) -> PackedFloat32Array:
	var curve := PackedFloat32Array()
	if list.is_empty(): return curve
	var sorted := list.duplicate()
	sorted.sort()
	var count := path_samples.size()
	curve.resize(count)
	var cursor := 0
	# Samples are in path order, so their progress only increases within a route.
	for i in range(count):
		if i > 0 and sample_route[i] != sample_route[i - 1]: cursor = 0
		var progress := maxf(0.0, sample_progress[i] - REACH_MARGIN)
		while cursor < sorted.size() and sorted[cursor] < progress: cursor += 1
		curve[i] = maxf(0.02, float(sorted.size() - cursor) / sorted.size())
	return curve

func stat_input(type: String, level: int, turret: Dictionary, d: Dictionary) -> Dictionary:
	var input: Dictionary = d.get("turretStatInputs", {}).get(type, {}).duplicate(true)
	var gems: Array = turret.get("equippedGemSlots", []).filter(func(g): return g != null)
	input.merge({"level": level, "primaryTrait": turret.get("primaryTrait"), "secondaryTrait": turret.get("secondaryTrait"), "gems": gems}, true)
	return catalog.turret(type, {"tileSize": 1.0, "statInput": input})

## Turret value: crowd part plus the boss part weighted by the boss shortfall.
## Without a boss weight it is the crowd part alone.
func turret_value(type: String, level: int, turret: Dictionary, d: Dictionary, tile: Vector2i) -> float:
	var parts := turret_parts(type, level, turret, d, tile)
	return parts.x + boss_weight * parts.y

## Crowd part: damage per second delivered to the path, plus the extra damage a
## slow lets other turrets deal in the slowed stretch. Boss part: single-target
## damage per second times the path length in range (damage = part / boss speed).
func turret_parts(type: String, level: int, turret: Dictionary, d: Dictionary, tile: Vector2i) -> Vector2:
	var sheet := turret_dps(type, level, turret, d)
	if sheet.is_empty(): return Vector2.ZERO
	var value: float = sheet.dps * float(P.typeFactors.get(type, 1.0)) * coverage(tile, sheet.range)
	var boss := 0.0
	if float(P.bossWeight) > 0.0:
		# typeFactors carry overkill on small enemies, which a boss does not have.
		var aim := 1.0 if aims_strongest(sheet, d) else float(P.bossFirstHit)
		var boss_coverage := coverage(tile, sheet.range, true)
		boss = sheet.single * aim * boss_coverage
		# Combat-only traits the stat sheet omits: finishing shot (+45% below 35%
		# durability) on its own hits, exposed mark (+15% physical taken for 2 s)
		# on everyone's hits while the boss is in its range.
		if turret.get("secondaryTrait") == "finishingShot": boss *= 1.0 + 0.45 * 0.35
		if turret.get("secondaryTrait") == "exposedMark":
			var path_share := minf(1.0, boss_coverage / maxf(0.001, boss_path_length()))
			boss += 0.15 * minf(1.0, 2.0 / sheet.cycle) * aim * boss_total * path_share
	for kind in ["primaryTrait", "secondaryTrait"]:
		var effect: Array = COMBAT_TRAITS.get(str(turret.get(kind, "")), [1.0, 1.0])
		value *= effect[0]
		boss *= effect[1]
	if sheet.slow < 1.0 and not damage_density.is_empty():
		# A slowed enemy stays 1/slow times longer in every overlapping range.
		var center := Vector2(tile.x + 0.5, tile.y + 0.5)
		var boosted := 0.0
		for i in range(path_samples.size()):
			if path_samples[i].distance_to(center) <= sheet.range: boosted += damage_density[i] * sample_weight[i]
		value += boosted * SAMPLE_STEP * (1.0 / maxf(0.1, sheet.slow) - 1.0) * float(P.slowUptime)
	return Vector2(value, boss)

# Combat-only traits the stat sheet omits, as [crowd, boss] damage multipliers
# (combat_runtime_damage._traits). Sniper's exposed mark and finishing shot are
# boss terms in turret_parts; their crowd share is small.
#   overheatMagazine  +2% per hit on the same target up to 15 hits: short on a
#                     crowd, near full on a boss
#   chainCleanup      x1.4 attack rate for 3 s after a recently hit enemy dies
#   suppressiveFire   +20% physical taken for 2 s every 5 hits on one target
#   compressedCharge/focusedLightning  flat hit multipliers
const COMBAT_TRAITS := {
	"overheatMagazine": [1.08, 1.27], "chainCleanup": [1.2, 1.0], "suppressiveFire": [1.03, 1.12],
	"compressedCharge": [1.35, 1.35], "focusedLightning": [1.3, 1.3],
	"exposedMark": [1.03, 1.0], "finishingShot": [1.05, 1.0],
}

## Big hits (strongestHitShare of the upcoming crowd's mean durability or more)
## lose little on small enemies, so with target priority research such turrets
## target the strongest enemy.
func aims_strongest(sheet: Dictionary, d: Dictionary) -> bool:
	return d.get("canSetTurretTargetPriority", false) and crowd_durability > 0.0 and float(sheet.hit) >= crowd_durability * float(P.strongestHitShare)

## Boss shortfall for the next boss wave within bossLookahead: the damage the
## board deals to its bosses over the whole path against their durability.
func update_roles(d: Dictionary) -> void:
	boss_weight = 0.0
	if float(P.bossWeight) <= 0.0: return
	var waves: Array = catalog._data.stages[stage].waves
	boss_need = 0.0
	boss_route = -1
	var crowd := 0.0
	var crowd_count := 0
	# start_wave advances next_round, so during a wave the current one counts.
	var first := next_round - 1 if str(domain.state.phase) == "wave" else next_round
	for index in range(maxi(0, first), mini(first + int(P.bossLookahead), waves.size())):
		var durability: Dictionary = waves[index].get("enemyDurability", {})
		for group in waves[index].groups:
			var layers: Array = durability.get(group.enemyType, [0.0, 0.0, 0.0])
			var hp: float = float(layers[0]) + float(layers[1]) + float(layers[2])
			var definition: Dictionary = catalog.enemy_definition(str(group.enemyType))
			if bool(definition.get("isBoss", false)):
				boss_need += hp * int(group.count)
				boss_route = route_index(str(group.get("routeId", "")))
				boss_speed = maxf(0.01, float(definition.get("speed", 1.0)) / catalog.tile_size())
			elif index < first + int(P.waveLookahead):
				crowd += hp * int(group.count)
				crowd_count += int(group.count)
		if boss_need > 0.0: break
	crowd_durability = crowd / crowd_count if crowd_count > 0 else 0.0
	if boss_need <= 0.0: return
	boss_total = 0.0
	for t in domain.state.turrets: boss_total += turret_parts(t.type, int(t.level), t, d, Vector2i(t.x, t.y)).y
	boss_capacity = boss_total / boss_speed / boss_need
	if bool(P.bossYield) and str(domain.state.phase) != "reward" and under_pressure(): return
	boss_weight = float(P.bossWeight) * clampf(1.0 - boss_capacity / float(P.bossMargin), 0.0, 1.0)

## With target priority research, big-hit turrets target the strongest enemy.
func assign_priorities(d: Dictionary) -> void:
	if float(P.bossWeight) <= 0.0 or not d.get("canSetTurretTargetPriority", false): return
	for t in domain.state.turrets:
		var sheet := turret_dps(t.type, int(t.level), t, d)
		if sheet.is_empty(): continue
		var wanted := "strongest" if aims_strongest(sheet, d) else "first"
		if str(t.get("targetPriority", "first")) != wanted:
			apply({"kind": RunKinds.TARGET_PRIORITY, "id": int(t.id), "type": wanted})

## Reached damage per path sample from turrets that do not slow, for slow value.
func update_density(d: Dictionary) -> void:
	damage_density = PackedFloat32Array()
	damage_density.resize(path_samples.size())
	for t in domain.state.turrets:
		var sheet := turret_dps(t.type, int(t.level), t, d)
		if sheet.is_empty() or sheet.slow < 1.0: continue
		var center := Vector2(t.x + 0.5, t.y + 0.5)
		var dps: float = sheet.dps * float(P.typeFactors.get(t.type, 1.0))
		for i in range(path_samples.size()):
			if path_samples[i].distance_to(center) <= sheet.range: damage_density[i] += dps * (reach[i] if not reach.is_empty() else 1.0)

## Single-turret damage per second with rough multipliers for area, chains and
## damage over time that the single-target sheet omits; range and slow multiplier.
func turret_dps(type: String, level: int, turret: Dictionary, d: Dictionary) -> Dictionary:
	var input := stat_input(type, level, turret, d)
	if input.is_empty(): return {}
	var s: Dictionary = Stats.stats_at(input, level)
	var rate := maxf(0.01, float(s.attackRate))
	var cycle := 1.0 / rate + float(s.get("aimDuration", 0.0))
	var crit := float(s.criticalChance) * maxf(0.0, float(s.criticalDamageMultiplier) - 1.0)
	var dps := float(s.damage) / cycle * maxi(1, int(s.projectileCount)) * (1.0 + crit)
	# One target: extra projectiles partly, no splash spread or chain jumps.
	var single := float(s.damage) / cycle * (1.0 + (maxi(1, int(s.projectileCount)) - 1) * float(P.bossExtraProjectileHit)) * (1.0 + crit)
	var definition: Dictionary = input.definition
	if bool(definition.get("centeredAreaAttack", false)): dps *= 2.0
	elif float(s.splashRadius) > 0.0: dps *= 1.0 + minf(2.0, float(s.splashRadius) * 1.5) * float(s.splashSecondaryDamageMultiplier)
	if int(s.chainCount) > 0:
		var chain_multiplier := float(s.lightningChainDamageMultiplier) if type == "lightning" else 0.5
		dps *= 1.0 + int(s.chainCount) * chain_multiplier * 0.6
	if "damageOverTime" in definition.get("attackTags", []):
		dps *= float(P.dotFactor)
		single *= float(P.dotFactor)
	if bool(s.ignoresArmorReduction):
		dps *= float(P.armorPierceFactor)
		single *= float(P.armorPierceFactor)
	var pierces: bool = bool(s.ignoresArmorReduction) or definition.get("damageFamily") == "poison"
	var floor_rate := 0.5 if "damageOverTime" in definition.get("attackTags", []) else 0.0
	var effectiveness := hit_effectiveness(float(s.damage) * (1.0 + crit), pierces, floor_rate)
	return {"dps": dps * effectiveness, "single": single * effectiveness, "hit": float(s.damage) * (1.0 + crit), "cycle": cycle, "range": float(s.range), "slow": float(s.slowMultiplier)}

## Upcoming waves (next waveLookahead) as durability layers per enemy.
func update_wave_profile() -> void:
	wave_profile = []
	hit_cache = {}
	var waves: Array = catalog._data.stages[stage].waves
	for index in range(next_round, mini(next_round + int(P.waveLookahead), waves.size())):
		var counts: Dictionary = catalog.wave_summary(stage, index).get("enemyCounts", {})
		var durability: Dictionary = waves[index].get("enemyDurability", {})
		for type in counts:
			var layers: Array = durability.get(type, [0.0, 0.0, 0.0])
			wave_profile.append({"count": int(counts[type]), "hp": float(layers[0]), "shield": float(layers[1]), "armor": float(layers[2])})

## Share of a turret's damage that counts against the upcoming enemies'
## durability, from the armor reduction rule (damage_calculation_rules.md):
## armor takes damage * (12% + 88% * damage / (damage + 3 * sqrt(max armor))).
## Burn keeps at least floor_rate on armor; piercing hits ignore the reduction.
func hit_effectiveness(hit: float, pierces: bool, floor_rate: float) -> float:
	if wave_profile.is_empty() or pierces or hit <= 0.0: return 1.0
	var key := "%d,%.2f" % [roundi(hit * 10.0), floor_rate]
	if hit_cache.has(key): return hit_cache[key]
	var total := 0.0
	var work := 0.0
	for row in wave_profile:
		total += row.count * (row.hp + row.shield + row.armor)
		var rate := 1.0
		if row.armor > 0.0:
			rate = maxf(floor_rate, 0.12 + 0.88 * hit / (hit + 3.0 * sqrt(row.armor)))
		work += row.count * (row.hp + row.shield + row.armor / rate)
	var value := total / work if work > 0.0 else 1.0
	hit_cache[key] = value
	return value

## frontTypes composition: those types only on tiles whose covered path lies
## mostly before frontProgress, every other type only behind it.
func role_allows(type: String, tile: Vector2i, d: Dictionary) -> bool:
	if P.frontTypes.is_empty() and not P.typeProgress.has(type): return true
	var sheet := turret_dps(type, 1, {"equippedGemSlots": [null]}, d)
	if sheet.is_empty(): return false
	var progress := covered_progress(tile, sheet.range)
	if progress < 0.0: return false
	if P.typeProgress.has(type):
		var window: Array = P.typeProgress[type]
		if progress < float(window[0]) or progress > float(window[1]): return false
	if P.frontTypes.is_empty(): return true
	return (progress < float(P.frontProgress)) == (type in P.frontTypes)

## Mean path progress of the samples inside the range, or -1 when none are.
func covered_progress(tile: Vector2i, radius: float) -> float:
	var center := Vector2(tile.x + 0.5, tile.y + 0.5)
	var weight := 0.0
	var progress := 0.0
	for i in range(path_samples.size()):
		if path_samples[i].distance_to(center) <= radius:
			weight += sample_weight[i]
			progress += sample_progress[i] * sample_weight[i]
	return progress / weight if weight > 0.0 else -1.0

func free_tiles() -> Array:
	var used := {}
	for t in domain.state.turrets: used[Vector2i(t.x, t.y)] = true
	for core in domain.state.get("supportCores", []): used[Vector2i(core.x, core.y)] = true
	return build_tiles.filter(func(tile): return not used.has(tile))

func board_value(d: Dictionary) -> float:
	var total := 0.0
	for t in domain.state.turrets: total += turret_value(t.type, int(t.level), t, d, Vector2i(t.x, t.y))
	return total

## Greedy gold spending: best damage per gold among build/level/run upgrades.
## Shards go to traits whenever affordable.
## Recent kill gold per completed wave (base enemy rewards).
func kill_gold_per_wave() -> float:
	return kill_gold_total / maxf(1.0, float(domain.state.get("completedRounds", 0)))

## Pressure: the core lost HP this wave, or recent enemies died deep in the path.
func under_pressure() -> bool:
	if runtime.defense.hp < wave_start_hp - 0.001: return true
	if outcomes.size() < 5: return false
	var recent: Array = outcomes.slice(maxi(0, outcomes.size() - 40))
	recent.sort()
	return float(recent[int(recent.size() * 0.9)]) >= float(P.greedPressure)

func spendable_gold() -> int:
	var gold := int(domain.state.gold)
	if spend_rate < 1.0: gold = mini(gold, int(spend_rate * (gold + spent_total)) - spent_total)
	return gold

func spend() -> void:
	if str(domain.state.phase) == "preparation":
		update_wave_profile()
		if P.shardPolicy != "value": buy_gem_choice()
		equip_bag_gems()
	for _guard in range(60):
		if not failure.is_empty() or str(domain.state.phase) not in ["preparation", "wave"]: return
		if P.shardPolicy == "value": spend_shards()
		else: buy_traits()
		var d: Dictionary = domain.service.derived(domain.state)
		update_density(d)
		update_roles(d)
		var gold := spendable_gold()
		var options: Array = []
		var tiles := free_tiles()
		var types: Array = d.get("availableTurretTypes", []).filter(func(type): return type not in P.bannedTypes)
		var built := {}
		for t in domain.state.turrets: built[t.type] = true
		if built.size() < int(P.minDistinctTypes) and types.any(func(type): return not built.has(type)):
			types = types.filter(func(type): return not built.has(type))
		if not P.typeShares.is_empty():
			var shares: Dictionary = P.typeShares
			var counts := {}
			for t in domain.state.turrets: counts[t.type] = int(counts.get(t.type, 0)) + 1
			var next: int = domain.state.turrets.size() + 1
			types = types.filter(func(type): return shares.has(type) and int(counts.get(type, 0)) < float(shares[type]) * next)
		if not P.typeAfter.is_empty():
			var after: Dictionary = P.typeAfter
			var board: int = domain.state.turrets.size()
			types = types.filter(func(type): return board >= int(after.get(type, 0)))
		if bool(P.explore):
			# Calibration: always offer the least-built type so every type gets data.
			var counts := {}
			for t in domain.state.turrets: counts[t.type] = int(counts.get(t.type, 0)) + 1
			var fewest: int = types.reduce(func(m, type): return mini(m, int(counts.get(type, 0))), 1 << 30)
			types = types.filter(func(type): return int(counts.get(type, 0)) == fewest)
		for type in types:
			var cost: int = domain.service.build_cost_from_derived(type, d)
			if cost <= 0: continue
			var best_tile := Vector2i(-1, -1)
			var best := 0.0
			for tile in tiles:
				if not role_allows(type, tile, d): continue
				var value := turret_value(type, 1, {"equippedGemSlots": [null]}, d, tile)
				if value > best:
					best = value
					best_tile = tile
			if best_tile.x >= 0:
				if not domain.state.turrets.any(func(t): return t.type == type): best *= 1.0 + float(P.newTypeBonus)
				options.append({"ratio": best / cost, "cost": cost, "request": {"kind": RunKinds.BUILD, "type": type, "x": best_tile.x, "y": best_tile.y}})
		for t in domain.state.turrets:
			var q: Dictionary = domain.service.quotes_from_derived(domain.state, int(t.id), d)
			var cost := int(q.get("level", 0))
			if cost <= 0: continue
			var tile := Vector2i(t.x, t.y)
			var gain := turret_value(t.type, int(t.level) + 1, t, d, tile) - turret_value(t.type, int(t.level), t, d, tile)
			options.append({"ratio": gain / cost, "cost": cost, "request": {"kind": RunKinds.LEVEL, "id": int(t.id)}})
		var total := board_value(d)
		var best_ratio := 0.0
		for option in options: best_ratio = maxf(best_ratio, option.ratio)
		gold_value_rate = best_ratio
		var remaining := catalog.wave_count(stage) - int(domain.state.get("completedRounds", 0))
		var safe: bool = not domain.state.turrets.is_empty() and runtime.defense.hp >= runtime.defense.max_hp - 0.001
		var economy: Array = []
		for type in domain.service.growth.data.get("runUpgrades", {}):
			var quote: Dictionary = domain.service.run_upgrade_quote_from_derived(domain.state, type, d)
			var cost := int(quote.get("cost", 0))
			if cost <= 0: continue
			var effect := float(domain.service.growth.data.runUpgrades[type].get("effectPerLevel", 0.0))
			var request := {"kind": RunKinds.RUN_UPGRADE, "type": type}
			if type == "towerDamage":
				# The run bonus adds into towerDamageMultiplier with fire and family
				# training, so a level adds effect / multiplier to each turret.
				var gain := 0.0
				for t in domain.state.turrets:
					var multiplier := float(d.get("turretStatInputs", {}).get(t.type, {}).get("towerDamageMultiplier", 1.0))
					gain += turret_value(t.type, int(t.level), t, d, Vector2i(t.x, t.y)) * effect / maxf(0.01, multiplier)
				options.append({"ratio": gain / cost, "cost": cost, "request": request})
				continue
			# Gold an economy level returns over the remaining waves.
			var per_wave := effect if type == "waveGold" else effect * kill_gold_per_wave()
			economy.append({"roi": per_wave * remaining / cost, "cost": cost, "request": request})
			if type == "waveGold" and safe:
				# Default: only the return within the horizon, converted at the board's
				# best rate and discounted for the delay, while the core is safe.
				options.append({"ratio": best_ratio * (effect * mini(remaining, ECONOMY_HORIZON_WAVES)) / cost / 2.0, "cost": cost, "request": request})
		if bool(P.greed) and str(domain.state.phase) == "preparation" and not domain.state.turrets.is_empty() and not under_pressure():
			# Greed: between waves without pressure, affordable economy levels that
			# pay back greedMinRoi times over the remaining waves come first. The
			# rest, and all gold earned during a wave, keeps the defense up.
			var best_economy := {}
			for option in economy:
				if option.roi >= float(P.greedMinRoi) and option.cost <= gold and (best_economy.is_empty() or option.roi > best_economy.roi): best_economy = option
			if not best_economy.is_empty():
				if not apply(best_economy.request): return
				continue
		best_ratio = 0.0
		for option in options: best_ratio = maxf(best_ratio, option.ratio)
		var pick := {}
		for option in options:
			if option.cost > gold or option.ratio < best_ratio * float(P.saveForBest): continue
			if pick.is_empty() or option.ratio > pick.ratio: pick = option
		if pick.is_empty() or not apply(pick.request): break
	if failure.is_empty() and str(domain.state.phase) == "preparation":
		var d: Dictionary = domain.service.derived(domain.state)
		update_roles(d)
		assign_priorities(d)

## shardPolicy "value": spends shards on the best value per shard among every
## trait a turret can take now and, between waves, a gem choice; saves only for
## an unaffordable option worth more, except in the last shardSpendAllWaves waves.
func spend_shards() -> void:
	for _guard in range(12):
		if not failure.is_empty(): return
		var d: Dictionary = domain.service.derived(domain.state)
		var options := shard_options(d)
		var best_ratio := 0.0
		for option in options: best_ratio = maxf(best_ratio, option.ratio)
		shard_value_rate = best_ratio
		var remaining := catalog.wave_count(stage) - int(domain.state.get("completedRounds", 0))
		var floor_ratio := 0.0 if remaining <= int(P.shardSpendAllWaves) else best_ratio * float(P.saveForBest)
		var pick := {}
		for option in options:
			if option.cost > int(domain.state.gemShards) or option.ratio <= 0.0 or option.ratio < floor_ratio: continue
			if pick.is_empty() or option.ratio > pick.ratio: pick = option
		if pick.is_empty(): return
		if pick.has("request"):
			if not apply(pick.request): return
			continue
		var next: Dictionary = Deck.purchase(domain.state, deck, int(pick.cost))
		if next.is_empty(): return
		domain.state = next
		send([], {"phase": domain.state.phase})
		handle_reward()

## Trait options (best choice by value unless traitChoices fixes it) and the gem
## choice: expected best of 3 distinct unlocked gems, each at its best target.
func shard_options(d: Dictionary) -> Array:
	var options: Array = []
	for t in domain.state.turrets:
		var q: Dictionary = domain.service.quotes_from_derived(domain.state, int(t.id), d)
		var tile := Vector2i(t.x, t.y)
		var before := -1.0
		for kind in [RunKinds.PRIMARY_TRAIT, RunKinds.SECONDARY_TRAIT]:
			var choices: Array = q.get(kind + "s", [])
			if t.get(kind) != null or int(t.level) < (3 if kind == RunKinds.PRIMARY_TRAIT else 7) or choices.is_empty(): continue
			if kind == RunKinds.SECONDARY_TRAIT and t.get("primaryTrait") == null: continue
			var cost := int(q.get(kind, 0))
			if cost <= 0: continue
			if P.traitChoices.get(t.type, {}).has(kind): choices = [choices[clampi(int(P.traitChoices[t.type][kind]), 0, choices.size() - 1)]]
			if before < 0.0: before = turret_value(t.type, int(t.level), t, d, tile)
			for choice in choices:
				var trial: Dictionary = t.duplicate(true)
				trial[kind] = choice
				var gain := turret_value(t.type, int(t.level), trial, d, tile) - before
				options.append({"ratio": gain / cost, "cost": cost, "request": {"kind": kind, "id": int(t.id), "type": choice}})
	var cost := int(domain.service.growth.data.constants.gemChoicePurchaseCost)
	if bool(P.gemPurchase) and not deck.is_empty() and str(domain.state.phase) == "preparation":
		var gains: Array = []
		for gem in GemReroll.GEM_TYPES:
			if not StageProgression.has_unlock(domain.state.progression, "gem", gem): continue
			var target := best_gem_target(gem, d, true)
			gains.append(0.0 if target.is_empty() else float(target.gain))
		if gains.size() >= 3:
			gains.sort()
			# P(max of 3 distinct = i-th smallest) = C(i, 2) / C(n, 3), 0-based i.
			var n := gains.size()
			var expected := 0.0
			for i in range(2, n): expected += gains[i] * (i * (i - 1) / 2.0) / (n * (n - 1) * (n - 2) / 6.0)
			options.append({"ratio": expected / cost, "cost": cost})
	return options

func buy_traits() -> void:
	var d: Dictionary = domain.service.derived(domain.state)
	var ranked: Array = domain.state.turrets.duplicate()
	ranked.sort_custom(func(a, b): return turret_value(a.type, int(a.level), a, d, Vector2i(a.x, a.y)) > turret_value(b.type, int(b.level), b, d, Vector2i(b.x, b.y)))
	for t in ranked:
		var q: Dictionary = domain.service.quotes_from_derived(domain.state, int(t.id), d)
		for kind in [RunKinds.PRIMARY_TRAIT, RunKinds.SECONDARY_TRAIT]:
			var required := 3 if kind == RunKinds.PRIMARY_TRAIT else 7
			var choices: Array = q.get(kind + "s", [])
			if t.get(kind) != null or int(t.level) < required or choices.is_empty(): continue
			if kind == RunKinds.SECONDARY_TRAIT and t.get("primaryTrait") == null: continue
			if int(domain.state.gemShards) < int(q.get(kind, 0)): return
			var index := int(P.traitChoices.get(t.type, {}).get(kind, 0))
			if not apply({"kind": kind, "id": int(t.id), "type": choices[clampi(index, 0, choices.size() - 1)]}): return
			return
