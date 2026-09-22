extends RefCounted
## Application event owner. Save and reward outbox I/O are checkpoint responsibilities.
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const QuestProgress = preload("res://app/quest_progress.gd")
var growth = Growth.new()
var quests = QuestProgress.new()
var service
var state: Dictionary = {}
var error := ""
var event_ack := 0
var epoch := -1
var collected_wall_time := 0.0
var now_millis: Callable = func(): return int(Time.get_unix_time_from_system() * 1000)

static func new_run_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

func initialize(catalog, progression: Dictionary, stage_index: int, scene_epoch: int) -> bool:
	if not growth.load_catalog():
		error = growth.error
		return false
	service = Commands.new(catalog, growth)
	state = service.initial_state(quests.refresh(progression, int(now_millis.call())), stage_index)
	state.economyRunId = new_run_id()
	for key in ["lastRunRuneReward", "lastRunCorePointReward", "lastRunTurretModuleTicketReward"]: state.progression[key] = 0
	epoch = scene_epoch
	event_ack = 0
	collected_wall_time = 0.0
	quests = QuestProgress.new()
	error = ""
	return not state.is_empty()

func restore(restored: Dictionary) -> void:
	state = restored.duplicate(true)
	if state.get("economyRunId") == null: state.economyRunId = new_run_id()
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

func finish(success: bool) -> void:
	if is_finished(): return
	var stage: Dictionary = service.catalog.stage(int(state.stage))
	state.completedRounds = stage.waves.size() if success else int(state.roundIndex)
	# Presentation-only comparisons; old v2 terminal saves may omit them.
	state.lastRunPreviousBestRound = int(state.progression.get("bestRoundsByStage", {}).get(str(stage.id), 0))
	state.lastRunWasNewBestRound = int(state.completedRounds) > int(state.lastRunPreviousBestRound)
	state.lastRunFirstClear = success and int(stage.id) not in state.progression.get("clearedStageNumbers", [])
	state.progression = quests.finish(state.progression, {
		"completedRounds":state.completedRounds, "success":success, "stageNumber":int(stage.id),
		"firstClearCorePointReward":int(stage.firstClearCorePointReward),
		"firstClearTurretModuleTicketReward":int(stage.firstClearTurretModuleTicketReward),
		"grantEconomyRewardsLocally":false,
		"runeResonanceBonusRate":float(growth.derive(state.progression).get("runeResonanceBonusRate",0.0))})
	_mark_finished()

func selected_id(tile: Vector2i) -> int:
	for turret in state.get("turrets", []):
		if int(turret.x) == tile.x and int(turret.y) == tile.y: return int(turret.id)
	return -1

func apply(command: Dictionary) -> Dictionary:
	var result: Dictionary = service.apply(state, command)
	if result.get("ok", false):
		state = result.state
		if command.get("kind") == "runUpgrade":
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
	# Detach once per collection. Events only mutate scalar run fields and owned
	# progression; turret/inventory transactions retain their pure API.
	state = state.duplicate()
	state.progression = state.progression.duplicate(true)
	var kill_derived: Dictionary = {}
	var wall: float = runtime.wall_elapsed
	if wall > collected_wall_time:
		state.progression = quests.record_play_time_owned(state.progression, wall-collected_wall_time)
		collected_wall_time = wall
	state.progression = quests.refresh_owned(state.progression, int(now_millis.call()))
	var commands: Array = []
	for event in runtime.events:
		if int(event.id) <= event_ack: continue
		var result: Dictionary = {"ok": true}
		var quest_types: Array = []
		match str(event.kind):
			"kill":
				var enemy: Dictionary = runtime.enemies.get(str(event.enemyId), {})
				if enemy.is_empty():
					error = "Missing enemy for reward; event retained"
					return {"ok": false, "commands": commands}
				if not bool(enemy.get("isDebug",false)):
					if kill_derived.is_empty(): kill_derived = service.derived(state)
					result = service.award_kill_owned(state, enemy, kill_derived)
					quest_types.append("killEnemies")
					if service.catalog.data.enemyDefinitions.get(enemy.type,{}).get("isBoss",false): quest_types.append("killBosses")
			"waveCompleted":
				if runtime.defense.hp > 0:
					result = service.complete_wave(state, int(event.waveId))
					quest_types.append("clearWaves")
			"coreDefeated":
				state.phase = "coreDestruction"
		if not result.get("ok", false):
			error = str(result.get("error", "Event rejected; retained"))
			return {"ok": false, "commands": commands}
		if result.has("state"): state = result.state
		for type in quest_types: state.progression = quests.record_owned(state.progression,type,1,int(now_millis.call()))
		if state.phase in ["success", "coreDestruction", "failure"]:
			finish(state.phase == "success")
			# Finishing can change growth inputs before a later event in this batch.
			kill_derived = {}
		commands.append_array(result.get("commands", []))
		# Advance only after corresponding economy and progression were applied.
		event_ack = int(event.id)
	if runtime.session.get("phase") == "failure":
		state.phase = "failure"
		finish(false)
	if state.phase in ["success", "failure", "coreDestruction"]: finish(state.phase == "success")
	error = ""
	return {"ok": true, "commands": commands}
