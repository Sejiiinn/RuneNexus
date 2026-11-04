extends RefCounted
## Application event owner. Save and reward outbox I/O are checkpoint responsibilities.
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const QuestProgress = preload("res://app/quest_progress.gd")
const StageDifficulty = preload("res://content/stage_difficulty.gd")
const StageChallenges = preload("res://content/stage_challenges.gd")
const CombatKinds = preload("res://combat/combat_kinds.gd")
const RunKinds = preload("res://app/run_command_kinds.gd")
const RunLog = preload("res://app/run_log.gd")
const MAX_RUN_LOGS := 3
var growth = Growth.new()
var quests = QuestProgress.new()
var service
# UI polling token, separate from saved state and combat progression.
var state_revision := 0
var state: Dictionary = {}:
	set(value):
		state = value
		state_revision += 1
var error := ""
var event_ack := 0
var epoch := -1
var collected_wall_time := 0.0
# Analysis-only run logs: session memory, never saved (docs/run_log_design.md).
var run_log_arrivals: Dictionary = {}
var run_log_resumed := false
var finished_run_logs: Array = []
var now_millis: Callable = func(): return int(Time.get_unix_time_from_system() * 1000)

static func new_run_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

func initialize(catalog, progression: Dictionary, stage_index: int, scene_epoch: int, authority_run_id: Variant = null) -> bool:
	if not growth.load_catalog():
		error = growth.error
		return false
	service = Commands.new(catalog, growth)
	state = service.initial_state(quests.refresh(progression, int(now_millis.call())), stage_index)
	state.economyRunId = new_run_id() if authority_run_id == null else (null if str(authority_run_id).is_empty() else str(authority_run_id))
	growth.fix_run_loadout(state)
	for key in ["lastRunRuneReward", "lastRunCorePointReward", "lastRunTurretModuleTicketReward"]: state.progression[key] = 0
	epoch = scene_epoch
	event_ack = 0
	collected_wall_time = 0.0
	run_log_arrivals = {}
	run_log_resumed = false
	quests = QuestProgress.new()
	error = ""
	return not state.is_empty()

func restore(restored: Dictionary) -> void:
	state = restored.duplicate(true)
	run_log_arrivals = {}
	run_log_resumed = true
	growth.fix_run_loadout(state)
	# Older v2 terminal saves already include progression results. Do not grant again.
	if state.phase in ["success", "failure", "coreDestruction"] and not is_finished():
		_mark_finished()

func finish_key() -> String:
	return "godot-run-finished:" + str(state.get("economyRunId", ""))

func is_finished() -> bool:
	return finish_key() in state.get("progression", {}).get("claimedEventIds", [])

func _mark_finished() -> void:
	if not state.progression.has("claimedEventIds"): state.progression.claimedEventIds = []
	if not finish_key() in state.progression.claimedEventIds: state.progression.claimedEventIds.append(finish_key())

func finish(success: bool, runtime = null) -> void:
	if is_finished(): return
	state_revision += 1
	var stage: Dictionary = service.catalog.stage_summary(int(state.stage))
	state.completedRounds = stage.waveCount if success else int(state.roundIndex)
	# Presentation-only comparisons; old v2 terminal saves may omit them.
	var difficulty := StageDifficulty.of(state)
	state.lastRunPreviousBestRound = StageDifficulty.best_rounds(state.progression, int(stage.id), difficulty)
	state.lastRunWasNewBestRound = int(state.completedRounds) > int(state.lastRunPreviousBestRound)
	state.lastRunFirstClear = success and int(stage.id) not in state.progression.get("clearedStageNumbers", []) and difficulty == StageDifficulty.NORMAL
	var challenge := success and StageChallenges.met(state, int(stage.id))
	state.lastRunChallengeAchieved = challenge and not StageChallenges.achieved(state.progression, int(stage.id), difficulty)
	state.progression = quests.finish(state.progression, {
		"completedRounds":state.completedRounds, "success":success, "stageNumber":int(stage.id), "difficulty":difficulty, "challengeMet":challenge,
		"firstClearCorePointReward":int(stage.firstClearCorePointReward),
		"firstClearTurretModuleTicketReward":int(stage.firstClearTurretModuleTicketReward),
		"grantEconomyRewardsLocally":false,
		"runeResonanceBonusRate":float(growth.derive(state.progression).get("runeResonanceBonusRate",0.0))})
	_mark_finished()
	var entry := RunLog.build(state, stage, runtime, run_log_arrivals, run_log_resumed)
	if not entry.is_empty():
		# A rolled-back finish (failed abandon save) runs again; keep the latest.
		finished_run_logs = finished_run_logs.filter(func(old): return old.runId != entry.runId)
		finished_run_logs.append(entry)
		if finished_run_logs.size() > MAX_RUN_LOGS: finished_run_logs.pop_front()

## Removes and returns the logs of runs the server has settled.
func take_run_logs(settled_run_ids: Array) -> Array:
	var taken := finished_run_logs.filter(func(entry): return entry.runId in settled_run_ids)
	finished_run_logs = finished_run_logs.filter(func(entry): return not entry.runId in settled_run_ids)
	return taken

func selected_id(tile: Vector2i) -> int:
	for turret in state.get("turrets", []):
		if int(turret.x) == tile.x and int(turret.y) == tile.y: return int(turret.id)
	return -1

func apply(command: Dictionary) -> Dictionary:
	var result: Dictionary = service.apply(state, command)
	if result.get("ok", false):
		state = result.state
		if command.get("kind") == RunKinds.RUN_UPGRADE:
			state.progression = quests.record(state.progression,"buyRunUpgrades",1,int(now_millis.call()))
		result.state = state
		error = ""
	else:
		error = str(result.get("error", "Command rejected"))
	return result

func collect(runtime) -> Dictionary:
	if runtime.epoch != epoch:
		error = "Stale combat epoch"
		return {"ok": false, "commands": []}
	# Damage/ACK-only collections update scalar play time, without copying module
	# inventories and quest histories. Detach nested data only before a writer.
	state = state.duplicate()
	state.progression = state.progression.duplicate()
	var progression_owned := false
	var kill_derived: Dictionary = {}
	var wall: float = runtime.wall_elapsed
	if wall > collected_wall_time:
		state.progression = quests.record_play_time_owned(state.progression, wall-collected_wall_time)
		collected_wall_time = wall
	var now := int(now_millis.call())
	if quests.needs_refresh(state.progression,now):
		state.progression = state.progression.duplicate(true)
		progression_owned = true
		state.progression = quests.refresh_owned(state.progression,now)
	var commands: Array = []
	for event in runtime.events:
		if int(event.id) <= event_ack: continue
		var result: Dictionary = {"ok": true}
		var quest_types: Array = []
		match str(event.kind):
			CombatKinds.KILL:
				var enemy: Dictionary = runtime.enemies.get(str(event.enemyId), {})
				if enemy.is_empty():
					error = "Missing enemy for reward; event retained"
					return {"ok": false, "commands": commands}
				if not bool(enemy.get("isDebug",false)):
					if kill_derived.is_empty(): kill_derived = service.kill_rewards(state)
					result = service.award_kill_owned(state, enemy, kill_derived)
					quest_types.append("killEnemies")
					if service.catalog.enemy_definition(enemy.type).get("isBoss",false): quest_types.append("killBosses")
			CombatKinds.WAVE_COMPLETED:
				if runtime.defense.hp > 0:
					result = service.complete_wave(state, int(event.waveId))
					# The pure wave transaction already returns deeply owned state.
					if result.get("ok",false): progression_owned = true
					quest_types.append("clearWaves")
			CombatKinds.ARRIVAL:
				# Any contact breaks a no-core-damage challenge, even when prevented.
				var arrived: Dictionary = runtime.enemies.get(str(event.enemyId), {})
				if not bool(arrived.get("isDebug", false)):
					state[StageChallenges.CORE_FIELD] = true
					var rarity := str(arrived.get("rarity", ""))
					var key := "%s:%s" % [arrived.get("type", ""), rarity if not rarity.is_empty() else "normal"]
					run_log_arrivals[key] = int(run_log_arrivals.get(key, 0)) + 1
			CombatKinds.CORE_DEFEATED:
				state.phase = "coreDestruction"
		if not result.get("ok", false):
			error = str(result.get("error", "Event rejected; retained"))
			return {"ok": false, "commands": commands}
		if result.has("state"): state = result.state
		if not quest_types.is_empty() and not progression_owned:
			state.progression = state.progression.duplicate(true)
			progression_owned = true
		for type in quest_types: state.progression = quests.record_owned(state.progression,type,1,int(now_millis.call()))
		if state.phase in ["success", "coreDestruction", "failure"]:
			finish(state.phase == "success", runtime)
			# Finishing can change growth inputs before a later event in this batch.
			kill_derived = {}
		commands.append_array(result.get("commands", []))
		# Advance only after corresponding economy and progression were applied.
		event_ack = int(event.id)
	if runtime.session.get("phase") == "failure":
		state.phase = "failure"
		finish(false, runtime)
	if state.phase in ["success", "failure", "coreDestruction"]: finish(state.phase == "success", runtime)
	error = ""
	return {"ok": true, "commands": commands}
