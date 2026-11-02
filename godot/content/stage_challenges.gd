extends RefCounted
## Stage challenges (docs/stage_difficulty_design.md#도전과제). One condition per
## stage; meeting it on a clear achieves that difficulty's challenge, and a hard
## achievement also credits normal. Diamond/ticket rewards are claimed from the
## server (server/internal/economy/challenge_rewards.go, same table); core point
## rewards stay in client progression like first-clear core points.

const StageProgression = preload("res://content/stage_progression.gd")

const MAX_TURRETS := 7
const NORMAL_FIELD := "challengeStageNumbers"
const HARD_FIELD := "hardChallengeStageNumbers"
## Core point rewards are client progression, so their claims are recorded here.
const CORE_CLAIM_FIELD := "claimedChallengeCorePointStages"
## Run fields read at the clear. A run starts with PEAK_FIELD = 0; a run saved
## before tracking existed lacks it and cannot achieve a challenge.
const PEAK_FIELD := "challengePeakTurrets"
const TYPES_FIELD := "challengeTurretTypes"
const CORE_FIELD := "challengeCoreReached"

const FAMILIES := {"arrow":"physical", "cannon":"physical", "sniper":"physical", "magic":"fire", "frost":"frost", "lightning":"lightning", "poison":"poison"}
const FAMILY_ORDER := ["physical", "fire", "frost", "lightning", "poison"]
const FAMILY_NAMES := {"physical":"물리", "fire":"화염", "frost":"냉기", "lightning":"라이트닝", "poison":"독"}
## [kind, families]; kinds: core = no core contact, turrets = at most MAX_TURRETS
## built at once, without = no turret of the family, only = only these families.
const CONDITIONS := {
	1: [["core"], ["turrets"], ["without", ["frost"]], ["core"], ["turrets"], ["without", ["fire"]], ["core"], ["turrets"], ["without", ["physical"]], ["core"]],
	2: [["turrets"], ["without", ["frost"]], ["only", ["physical", "lightning"]], ["core"], ["only", ["fire", "frost"]], ["turrets"], ["only", ["physical", "fire"]], ["core"], ["only", ["fire", "frost", "lightning"]], ["turrets"]],
	3: [["only", ["physical", "fire", "poison"]], ["core"], ["only", ["frost", "lightning", "poison"]], ["turrets"], ["only", ["fire", "lightning"]], ["core"], ["only", ["physical", "frost", "poison"]], ["turrets"], ["only", ["physical", "lightning", "poison"]], ["core"]],
}
## Per chapter: [normal diamonds, hard diamonds, normal tickets, hard tickets].
## Chapter 3 is the cap for later chapters.
const REWARDS := {1: [100, 200, 4, 5], 2: [200, 300, 5, 6], 3: [300, 400, 6, 7]}
const HARD_CORE_POINTS := 1

static func condition(stage_id: int) -> Array:
	var rows: Array = CONDITIONS.get(StageProgression.chapter_for(stage_id), [])
	var index := StageProgression.chapter_stage_for(stage_id) - 1
	return rows[index] if index >= 0 and index < rows.size() else []

static func has_challenge(stage_id: int) -> bool:
	return not condition(stage_id).is_empty()

static func _families(spec: Array) -> Array:
	return spec[1] if spec.size() > 1 else []

static func _family_list(families: Array) -> String:
	return "·".join(families.map(func(f): return FAMILY_NAMES[f]))

## [condition sentence, failure rule] for the stage card and achievement list.
static func lines(stage_id: int) -> Array:
	var spec := condition(stage_id)
	if spec.is_empty(): return []
	match str(spec[0]):
		"core": return ["코어 피해 없이 클리어", "적이 코어에 닿으면 실패"]
		"turrets": return ["포탑 %d기 이하로 클리어" % MAX_TURRETS, "동시에 설치된 포탑 수 기준"]
		"without":
			var name: String = FAMILY_NAMES[_families(spec)[0]]
			return ["%s 포탑 없이 클리어" % name, "%s 계열 포탑을 설치하면 실패" % name]
		_: return ["%s만으로 클리어" % _family_list(_families(spec)), "다른 계열 포탑을 설치하면 실패"]

## Turrets of each named family, for the condition bubble; "" when none apply.
static func family_members(stage_id: int, turret_names: Dictionary) -> String:
	var parts: Array = []
	for family in _families(condition(stage_id)):
		var names: Array = []
		for type in FAMILIES:
			if FAMILIES[type] == family: names.append(str(turret_names.get(type, type)))
		parts.append("%s 계열: %s 포탑" % [FAMILY_NAMES[family], "·".join(names)])
	return " · ".join(parts)

## True when the finished run's tracked play satisfies the stage condition.
static func met(run: Dictionary, stage_id: int) -> bool:
	var spec := condition(stage_id)
	if spec.is_empty() or not run.has(PEAK_FIELD): return false
	var used: Array = []
	for type in run.get(TYPES_FIELD, []):
		var family: String = FAMILIES.get(str(type), "")
		if not family.is_empty() and not family in used: used.append(family)
	match str(spec[0]):
		"core": return not bool(run.get(CORE_FIELD, false))
		"turrets": return int(run.get(PEAK_FIELD, 0)) <= MAX_TURRETS
		"without": return not _families(spec)[0] in used
		_: return used.all(func(f): return f in _families(spec))

## Marks a new run as tracked from its start.
static func start(run: Dictionary) -> void:
	run[PEAK_FIELD] = 0

## Records peak simultaneous turrets and built types after a build. A run
## that started untracked stays untracked: its earlier play is unknown.
static func track_build(run: Dictionary) -> void:
	if not run.has(PEAK_FIELD): return
	var turrets: Array = run.get("turrets", [])
	run[PEAK_FIELD] = maxi(int(run.get(PEAK_FIELD, 0)), turrets.size())
	var types: Array = run.get(TYPES_FIELD, []).duplicate()
	for turret in turrets:
		if not str(turret.type) in types: types.append(str(turret.type))
	run[TYPES_FIELD] = types

static func field(difficulty: String) -> String:
	return HARD_FIELD if difficulty == "hard" else NORMAL_FIELD

## Normal is also achieved by a hard achievement.
static func achieved(progression: Dictionary, stage_id: int, difficulty: String) -> bool:
	if stage_id in progression.get(HARD_FIELD, []): return true
	return difficulty != "hard" and stage_id in progression.get(NORMAL_FIELD, [])

## Adds the achievement in place; already held achievements stay as they are.
static func record(progression: Dictionary, stage_id: int, difficulty: String) -> void:
	for key in ([NORMAL_FIELD, HARD_FIELD] if difficulty == "hard" else [NORMAL_FIELD]):
		var ids: Array = progression.get(key, []).duplicate()
		if not stage_id in ids:
			ids.append(stage_id)
			progression[key] = ids

## {kind: diamonds|tickets|corePoints, amount}. Odd chapter positions give
## diamonds and even ones tickets; hard on the 5th and 10th gives a core point.
static func reward(stage_id: int, difficulty: String) -> Dictionary:
	var chapter := StageProgression.chapter_for(stage_id)
	var position := StageProgression.chapter_stage_for(stage_id)
	if chapter <= 0 or position <= 0: return {}
	var hard := difficulty == "hard"
	if hard and position % 5 == 0: return {"kind":"corePoints", "amount":HARD_CORE_POINTS}
	var row: Array = REWARDS[mini(chapter, 3)]
	if position % 2 == 1: return {"kind":"diamonds", "amount":row[1 if hard else 0]}
	return {"kind":"tickets", "amount":row[3 if hard else 2]}

static func reward_key(stage_id: int, difficulty: String) -> String:
	return "stage:%d:challenge:%s" % [stage_id, "hard" if difficulty == "hard" else "normal"]

## Claimed: server reward keys for diamonds/tickets, progression for core points.
static func claimed(progression: Dictionary, claimed_keys: Array, stage_id: int, difficulty: String) -> bool:
	if reward(stage_id, difficulty).get("kind") == "corePoints":
		return stage_id in progression.get(CORE_CLAIM_FIELD, [])
	return reward_key(stage_id, difficulty) in claimed_keys

## Grants a hard challenge core point once; false when not claimable.
static func claim_core_point(progression: Dictionary, stage_id: int) -> bool:
	if reward(stage_id, "hard").get("kind") != "corePoints" or not achieved(progression, stage_id, "hard"): return false
	var ids: Array = progression.get(CORE_CLAIM_FIELD, []).duplicate()
	if stage_id in ids: return false
	ids.append(stage_id)
	progression[CORE_CLAIM_FIELD] = ids
	progression.totalCorePoints = int(progression.get("totalCorePoints", 0)) + HARD_CORE_POINTS
	return true

## Any achieved, unclaimed reward (lobby badge).
static func any_claimable(progression: Dictionary, claimed_keys: Array) -> bool:
	for stage_id in StageProgression.ordered_ids():
		for difficulty in ["normal", "hard"]:
			if achieved(progression, stage_id, difficulty) and not claimed(progression, claimed_keys, stage_id, difficulty): return true
	return false

## Achieved count of one chapter and difficulty (collection progress).
static func chapter_count(progression: Dictionary, chapter: int, difficulty: String) -> int:
	return StageProgression.ids_for_chapter(chapter).filter(func(id): return achieved(progression, id, difficulty)).size()
