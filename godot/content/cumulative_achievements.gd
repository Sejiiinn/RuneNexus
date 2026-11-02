extends RefCounted
## Cumulative achievements (docs/stage_difficulty_design.md#누적-업적). Each
## counts one lifetime total in five tiers: tiers 1-4 grant diamonds from the
## server (server/internal/economy/achievement_rewards.go, same table) and tier 5
## grants a medal kept in client progression. Counters other than module draws
## are client-trusted progression; draws read the server's draw count.

## Lifetime counters by achievement id, recorded from the moment of release.
const COUNTERS_FIELD := "achievementCounters"
## The last attendance day counted, so each day counts once.
const ATTENDANCE_DAY_FIELD := "achievementAttendanceDayKey"
const MEDAL_FIELD := "claimedAchievementMedals"
## Weekly quest types that also count toward a lifetime counter.
const QUEST_COUNTERS := ["clearWaves", "killBosses", "killEnemies"]
const ORDER := ["attendance", "clearWaves", "killBosses", "killEnemies", "moduleDraws"]
const NAMES := {"attendance":"누적 출석", "clearWaves":"라운드 클리어", "killBosses":"보스 처치", "killEnemies":"적 처치", "moduleDraws":"모듈 뽑기"}
const UNITS := {"attendance":"일", "moduleDraws":"회"}
const ICONS := {"attendance":"quests/attendance.png", "clearWaves":"quests/clear_waves.png", "killBosses":"quests/kill_bosses.png", "killEnemies":"quests/kill_enemies.png", "moduleDraws":"stage_rewards/reward_module_ticket.png"}
const TIERS := {
	"attendance": [7, 30, 60, 120, 180],
	"clearWaves": [300, 1500, 4000, 8000, 12000],
	"killBosses": [30, 150, 400, 800, 1200],
	"killEnemies": [3000, 20000, 60000, 120000, 200000],
	"moduleDraws": [20, 60, 150, 250, 400],
}
## Diamonds of tiers 1-4; tier 5 is the medal.
const DIAMONDS := [300, 500, 700, 1000]
const MEDAL_TIER := 5
## Medal achievement stats [stat, rate] (temporary values).
const MEDAL_STATS := {"attendance":["turretDamage", 0.02], "clearWaves":["attackSpeed", 0.02], "killBosses":["bossDamage", 0.03], "killEnemies":["criticalChance", 0.02], "moduleDraws":["nexusHp", 0.03]}

static func count(p: Dictionary, id: String) -> int:
	if id == "moduleDraws": return maxi(0, int(p.get("turretModules", {}).get("drawCount", 0)))
	return maxi(0, int(p.get(COUNTERS_FIELD, {}).get(id, 0)))

## Reached tiers, 0-5.
static func reached(p: Dictionary, id: String) -> int:
	var value := count(p, id)
	var tier := 0
	for threshold in TIERS.get(id, []):
		if value >= int(threshold): tier += 1
	return tier

static func reward_key(id: String, tier: int) -> String:
	return "achievement:%s:%d" % [id, tier]

static func tier_claimed(p: Dictionary, claimed_keys: Array, id: String, tier: int) -> bool:
	if tier == MEDAL_TIER: return medal_owned(p, id)
	return reward_key(id, tier) in claimed_keys

## The first tier not yet received (1-5), or 0 when all five are received.
static func next_tier(p: Dictionary, claimed_keys: Array, id: String) -> int:
	for tier in range(1, MEDAL_TIER + 1):
		if not tier_claimed(p, claimed_keys, id, tier): return tier
	return 0

static func medal_owned(p: Dictionary, id: String) -> bool:
	return id in p.get(MEDAL_FIELD, [])

static func medal_ready(p: Dictionary, id: String) -> bool:
	return TIERS.has(id) and reached(p, id) >= MEDAL_TIER

## Claims a reached tier-5 medal once; false when not claimable.
static func claim_medal(p: Dictionary, id: String) -> bool:
	if not medal_ready(p, id) or medal_owned(p, id): return false
	var ids: Array = p.get(MEDAL_FIELD, []).duplicate()
	ids.append(id)
	p[MEDAL_FIELD] = ids
	return true

## Any reached, unreceived tier (lobby badge).
static func any_claimable(p: Dictionary, claimed_keys: Array) -> bool:
	for id in ORDER:
		for tier in range(1, reached(p, id) + 1):
			if not tier_claimed(p, claimed_keys, id, tier): return true
	return false

## [reached, total] tiers over every cumulative achievement.
static func achievement_count(p: Dictionary) -> Array:
	var done := 0
	for id in ORDER: done += reached(p, id)
	return [done, ORDER.size() * MEDAL_TIER]

## Adds a gameplay amount to its lifetime counter (owned progression).
static func record_owned(p: Dictionary, type: String, amount: int) -> void:
	if amount <= 0 or not type in QUEST_COUNTERS: return
	_add(p, type, amount)

## Counts the day once. A clock moved backwards never counts a day again.
static func record_attendance_owned(p: Dictionary, day: int) -> void:
	if day <= int(p.get(ATTENDANCE_DAY_FIELD, -1)): return
	p[ATTENDANCE_DAY_FIELD] = day
	_add(p, "attendance", 1)

static func _add(p: Dictionary, id: String, amount: int) -> void:
	var counters: Dictionary = p.get(COUNTERS_FIELD, {}).duplicate()
	counters[id] = int(counters.get(id, 0)) + amount
	p[COUNTERS_FIELD] = counters
