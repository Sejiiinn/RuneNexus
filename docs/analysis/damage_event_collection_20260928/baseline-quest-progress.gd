extends RefCounted
## Pure progression transitions. Account currency is only granted by economy receipts.
const DAILY := {"clearWaves": 30, "killBosses": 3, "killEnemies": 100, "buyRunUpgrades": 5}
const WEEKLY := {"clearWaves": 150, "killBosses": 15, "killEnemies": 500, "buyRunUpgrades": 25}
var _play_time_remainder := 0.0

func refresh(progression: Dictionary, now_millis: int) -> Dictionary:
	return refresh_owned(progression.duplicate(true), now_millis)

## Internal transaction path: caller exclusively owns p and all nested values.
func refresh_owned(p: Dictionary, now_millis: int) -> Dictionary:
	var day := int(float(now_millis + 14400000) / 86400000.0)
	var day_changed := int(p.get("dailyQuestDayKey", -1)) != day
	var last := int(p.get("lastDailyQuestSeenMillis", 0))
	if day_changed:
		p.dailyQuestDayKey = day
		p.dailyQuestProgress = {}
		p.claimedDailyQuestRewards = []
		p.dailyAttendanceRewardClaimed = false
		p.dailyQuestAllCompleteClaimed = false
		p.dailyQuestClockRollbackDetected = false
	elif last > 0 and now_millis + 300000 < last:
		p.dailyQuestClockRollbackDetected = true
	if day_changed or last == 0 or now_millis - last >= 60000:
		p.lastDailyQuestSeenMillis = now_millis
	var week := int(float(day + 3) / 7.0)
	if int(p.get("weeklyQuestWeekKey", -1)) != week:
		p.weeklyQuestWeekKey = week
		p.weeklyQuestProgress = {}
		p.claimedWeeklyQuestRewards = []
		p.weeklyQuestAllCompleteClaimed = false
		p.weeklyAttendanceDayKeys = []
		p.weeklyAttendanceRewardClaimed = false
	if not p.has("weeklyAttendanceDayKeys"): p.weeklyAttendanceDayKeys = []
	if not day in p.weeklyAttendanceDayKeys: p.weeklyAttendanceDayKeys.append(day)
	return p

func record(progression: Dictionary, type: String, amount: int, now_millis: int) -> Dictionary:
	return record_owned(progression.duplicate(true), type, amount, now_millis)

func record_owned(p: Dictionary, type: String, amount: int, now_millis: int) -> Dictionary:
	if amount <= 0: return p
	refresh_owned(p, now_millis)
	if not DAILY.has(type): return p
	for period in ["daily", "weekly"]:
		var field: String = period + "QuestProgress"
		var targets: Dictionary = DAILY if period == "daily" else WEEKLY
		if not p.has(field): p[field] = {}
		p[field][type] = mini(int(targets[type]), int(p[field].get(type, 0)) + amount)
	return p

func record_play_time(progression: Dictionary, elapsed_seconds: float) -> Dictionary:
	return record_play_time_owned(progression.duplicate(true), elapsed_seconds)

func record_play_time_owned(p: Dictionary, elapsed_seconds: float) -> Dictionary:
	if not is_finite(elapsed_seconds) or elapsed_seconds <= 0: return p
	_play_time_remainder += elapsed_seconds * 1000.0
	var elapsed := int(floor(_play_time_remainder))
	if elapsed > 0:
		p.totalPlayTimeMillis = int(p.get("totalPlayTimeMillis", 0)) + elapsed
		_play_time_remainder -= elapsed
	return p

func finish(progression: Dictionary, event: Dictionary) -> Dictionary:
	var p := progression.duplicate(true)
	var stage := int(event.get("stageNumber", 1))
	var rounds := int(event.get("completedRounds", 0))
	var success := bool(event.get("success", false))
	var cleared: Array = p.get("clearedStageNumbers", []).duplicate()
	var first := success and stage > 0 and not stage in cleared
	var resonance := float(event.get("runeResonanceBonusRate", float(p.get("researchLevels", {}).get("runeResonance", 0)) * 0.02))
	var reward := 0
	if rounds > 0:
		var progress := (pow(1.04, clampi(rounds, 0, 40)) - 1.0) / (pow(1.04, 40) - 1.0)
		reward = maxi(1, int(round(150.0 * progress * pow(1.18, clampi(stage, 1, 15) - 1) * (1.0 + resonance))))
	p.lastRunRuneReward = reward
	p.runes = int(p.get("runes", 0)) + reward
	p.lastRunCorePointReward = 0
	var core_reward := int(event.get("firstClearCorePointReward", 0))
	var claimed: Array = p.get("claimedCorePointStageRewards", []).duplicate()
	if success and stage > 0 and core_reward >= 0 and not stage in claimed:
		claimed.append(stage)
		p.totalCorePoints = int(p.get("totalCorePoints", 0)) + core_reward
		p.lastRunCorePointReward = core_reward
	p.claimedCorePointStageRewards = claimed
	if stage > 0:
		if rounds > 0:
			if not p.has("bestRoundsByStage"): p.bestRoundsByStage = {}
			p.bestRoundsByStage[str(stage)] = maxi(int(p.bestRoundsByStage.get(str(stage), 0)), rounds)
		if success and not stage in cleared: cleared.append(stage)
	p.clearedStageNumbers = cleared
	var unlocked := int(p.get("unlockedStageCount", 1))
	if success and stage >= unlocked and unlocked < 15: p.unlockedStageCount = mini(15, stage + 1)
	p.lastRunTurretModuleTicketReward = maxi(0, int(event.get("firstClearTurretModuleTicketReward", 0))) if first else 0
	if bool(event.get("grantEconomyRewardsLocally", false)):
		if not p.has("turretModules"): p.turretModules = {}
		p.turretModules.tickets = int(p.turretModules.get("tickets", 0)) + int(p.lastRunTurretModuleTicketReward)
	return p

## Apply claim flags after an authoritative receipt, never wallet balances.
## receipt={period:daily|weekly,rewardType:quest|all_complete|attendance,
##          questType?,dayKey|weekKey,rewardDiamonds?,rewardModuleTickets?}
func apply_receipt(progression: Dictionary, receipt: Dictionary) -> Dictionary:
	var p := progression.duplicate(true)
	var period := str(receipt.get("period", ""))
	if period not in ["daily", "weekly"]: return {"ok": false, "progression": p}
	var weekly := period == "weekly"
	var key_field := "weeklyQuestWeekKey" if weekly else "dailyQuestDayKey"
	var receipt_key := "weekKey" if weekly else "dayKey"
	if not receipt.has(receipt_key) or int(p.get(key_field, -1)) != int(receipt[receipt_key]) or p.get("dailyQuestClockRollbackDetected", false):
		return {"ok": false, "progression": p}
	if weekly and int(receipt.get("rewardDiamonds", 0)) <= 0: return {"ok": false, "progression": p}
	var kind := str(receipt.get("rewardType", ""))
	var targets: Dictionary = WEEKLY if weekly else DAILY
	var progress: Dictionary = p.get(period + "QuestProgress", {})
	var claimed_field := "claimedWeeklyQuestRewards" if weekly else "claimedDailyQuestRewards"
	var claimed: Array = p.get(claimed_field, []).duplicate()
	match kind:
		"quest":
			var type := str(receipt.get("questType", ""))
			if not targets.has(type) or type in claimed or int(progress.get(type, 0)) < int(targets[type]): return {"ok": false, "progression": p}
			claimed.append(type)
			p[claimed_field] = claimed
		"all_complete":
			var field := period + "QuestAllCompleteClaimed"
			if p.get(field, false) or (weekly and int(receipt.get("rewardModuleTickets", -1)) < 0): return {"ok": false, "progression": p}
			for type in targets:
				if int(progress.get(type, 0)) < int(targets[type]): return {"ok": false, "progression": p}
			p[field] = true
		"attendance":
			var field := period + "AttendanceRewardClaimed"
			if p.get(field, false) or (weekly and p.get("weeklyAttendanceDayKeys", []).size() < 5): return {"ok": false, "progression": p}
			p[field] = true
		_: return {"ok": false, "progression": p}
	return {"ok": true, "progression": p}
