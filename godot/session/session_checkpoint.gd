extends RefCounted
## Local v2 checkpoints for the independent content session and legacy fixture.
## Account settlement and existing-installation data handoff remain separate.
const Codec = preload("res://app/save_codec.gd")
const Adapter = preload("res://app/run_save_adapter.gd")
const ContentSave = preload("res://app/content_run_save.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const RewardOutbox = preload("res://app/reward_outbox.gd")
const RewardSnapshot = preload("res://app/reward_snapshot.gd")
var store
var message := ""
var preferences: Dictionary = {}
var base_directory: String
var owner: String
var reward_queue
var queued_run_id := ""
var allow_progression_only := false

func _init(directory: String = "user://standalone-session", account_owner: String = "guest") -> void:
	base_directory = directory
	owner = account_owner.to_lower()
	var slot = Slot.guest() if owner == "guest" else Slot.account(owner)
	store = Store.new(directory, slot)
	if slot == null: store._valid_slot = false

func rewards():
	if reward_queue == null:
		reward_queue = RewardOutbox.new(base_directory, owner)
		if reward_queue.load_state() != OK: message = reward_queue.last_error_message
	return reward_queue

func enqueue_saved(saved: Dictionary) -> Error:
	var run: Variant = saved.get("activeRun")
	if not run is Dictionary or run.phase not in ["success", "failure", "coreDestruction"]: return OK
	var queue = rewards()
	if not queue.loaded:
		message = queue.last_error_message
		return queue.last_error
	var result: Error = queue.enqueue({"runId":run.economyRunId,"stageNumber":run.stageNumber,
		"completedRounds":run.completedRounds,"success":run.phase == "success",
		"pendingDiamonds":run.pendingEconomyDiamonds,
		"firstClearModuleTickets":int(saved.progression.get("lastRunTurretModuleTicketReward",0)) if run.phase == "success" else 0,
		"createdAtMillis":saved.savedAtMillis})
	if result != OK: message = queue.last_error_message
	else: queued_run_id = run.economyRunId
	return result

func enqueue_finished(app) -> Error:
	return _save_content(app)

func persist_state(app, candidate: Dictionary, abandoning: bool = false) -> Error:
	var runtime = app.scene._native_combat
	if not runtime.active or not is_equal_approx(runtime.tile_size, 1.0) or runtime.origin != Vector2.ZERO:
		message = "Unsupported checkpoint coordinate configuration"
		return ERR_UNAVAILABLE
	var snapshot: Dictionary = app.scene._native_combat.snapshot()
	if abandoning:
		snapshot.session.phase = "failure"
		snapshot.wave.spawnQueue = []
	var adapter = ContentSave.new(app.catalog, app.run_domain.growth)
	var saved: Dictionary = adapter.capture(candidate, snapshot, int(app.run_domain.now_millis.call()), preferences)
	if saved.is_empty():
		message = adapter.error
		return ERR_INVALID_DATA
	var result: Error = store.save_save(saved)
	if result == OK:
		preferences = saved.preferences.duplicate(true)
		result = enqueue_saved(saved)
	message = "Saved v2 checkpoint and retained run reward" if result == OK else (message if store.last_error == OK else store.last_error_message)
	return result

func apply_economy_snapshot(app, snapshot: Dictionary) -> bool:
	# Called only by the account-bound settlement worker after response validation.
	if owner == "guest": return false
	var mapper = RewardSnapshot.new()
	if not app.scene._native_combat.active:
		var saved = store.load_save()
		if saved == null: return false
		var input: Dictionary = saved.progression.duplicate(true)
		input.turretModules = saved.turretModules
		var mapped: Dictionary = mapper.apply_authoritative(input, snapshot)
		if mapped.is_empty(): return false
		saved.turretModules = mapped.turretModules
		mapped.erase("turretModules")
		saved.progression = mapped
		if store.save_save(saved) != OK: return false
		app.progression_inputs = input.duplicate(true)
		app.progression_inputs.merge(mapped,true)
		app.progression_inputs.turretModules = saved.turretModules.duplicate(true)
		return true
	if not app.command(): return false
	var candidate: Dictionary = app.run_domain.state.duplicate(true)
	var mapped: Dictionary = mapper.apply_authoritative(candidate.progression, snapshot)
	if mapped.is_empty():
		message = mapper.error
		return false
	candidate.progression = mapped
	if persist_state(app, candidate) != OK: return false
	app.run_domain.state = candidate
	app.progression_inputs = mapped.duplicate(true)
	var refresh: Dictionary = app.run_domain.service.refresh(candidate)
	app.run_domain.state = refresh.state
	return app.command(refresh.get("commands",[]))

func save_session(app) -> Error:
	if app.is_content_session(): return _save_content(app)
	var runtime = app.scene._native_combat
	if not runtime.active:
		message = "No active stage"
		return ERR_UNCONFIGURED
	# The development fixture has no reward/economy side effects to settle.
	app.command()
	var source: Dictionary = app.fixture.stages[app.stage]
	var phase: String = runtime.session.get("phase", "preparation")
	if runtime.wave.completed: phase = "preparation"
	var envelope = Codec.decode({
		"version": 2, "preferences": {"selectedStageNumber": app.stage + 1},
		"progression": {}, "turretModules": {}, "activeRun": {
			"runCoreCombatSkill": null,
			"stageNumber": app.stage + 1, "phase": phase,
			"mapSignature": Adapter.map_signature(source.map, source.path),
			"roundIndex": runtime.wave.id if runtime.wave.completed else maxi(0, runtime.wave.id - 1),
			"completedRounds": runtime.wave.id if runtime.wave.completed else maxi(0, runtime.wave.id - 1),
		},
	})
	var templates: Dictionary = {}
	for turret in runtime.turrets.values():
		templates[str(turret.id)] = {"type": "arrow", "x": turret.state.x, "y": turret.state.y, "level": 1}
	var snapshot: Dictionary = runtime.snapshot()
	snapshot.session.phase = phase
	var saved = Adapter.capture(envelope, snapshot, templates, int(Time.get_unix_time_from_system() * 1000))
	if saved == null:
		message = "Checkpoint rejected"
		return ERR_INVALID_DATA
	var error: Error = store.save_save(saved)
	message = "Saved v2 checkpoint" if error == OK else store.last_error_message
	return error

func load_session(app) -> Error:
	if app.is_content_session(): return _load_content(app)
	var saved = store.load_save()
	if saved == null:
		message = "No checkpoint" if store.last_error == OK else store.last_error_message
		return ERR_FILE_NOT_FOUND if store.last_error == OK else store.last_error
	var run = saved.activeRun
	if not run is Dictionary:
		message = "No active run"
		return ERR_INVALID_DATA
	var index := int(run.stageNumber) - 1
	if index < 0 or index >= app.fixture.stages.size(): return _unsupported()
	var source: Dictionary = app.fixture.stages[index]
	if run.mapSignature != Adapter.map_signature(source.map, source.path): return _unsupported()
	# Refuse unsupported real-game configurations instead of silently replacing them
	# with this fixture's basic arrow/normal-enemy definitions.
	var empty = Codec.decode({"version": 2, "preferences": {}, "progression": {}, "turretModules": {}, "activeRun": null})
	if saved.progression != empty.progression or saved.turretModules != empty.turretModules: return _unsupported()
	if not _is_fixture_run(run): return _unsupported()
	var towers: Array = []
	var enemies: Array = []
	var queue: Array = []
	var id := 1
	for turret in run.turrets:
		if turret.x < 0 or turret.y < 0 or turret.x >= source.map.columns or turret.y >= source.map.rows: return _unsupported()
		if source.map.tiles[int(turret.y) * int(source.map.columns) + int(turret.x)] != "build": return _unsupported()
		var stats: Dictionary = app.fixture.turret.duplicate(true)
		stats.boardDistanceScale = 1.0 / 48.0
		towers.append({"id": id, "position": [turret.x + 0.5, turret.y + 0.5], "statInput": stats, "state": turret.duplicate(true)})
		id += 1
	var next_turret_id := id
	for enemy in run.enemies:
		enemies.append(enemy_configuration(source.path, id, enemy))
		id += 1
	for pending in run.spawnQueue:
		queue.append({"delay": pending.delay, "enemyType": "normal", "enemy": enemy_configuration(source.path, id)})
		id += 1
	# Validation completed before replacing the current scene.
	app.enter_stage(index, {
		"path": source.path, "tileSize": 1.0, "boardDistanceScale": 1.0 / 48.0,
		"turrets": towers, "enemies": enemies,
		"wave": {"id": int(run.roundIndex) if run.phase == "preparation" else int(run.roundIndex) + 1, "active": run.phase == "wave", "spawnQueue": queue},
		"defense": {"config": {"maxHp": 100.0}, "state": {
			"hp": run.nexusHp, "roundHpLost": run.roundNexusHpLost,
			"finalDefenseUsedThisRound": run.finalDefenseUsedThisRound,
			"emergencyChargeUsedThisRound": run.emergencyChargeUsedThisRound,
			"failed": run.phase == "failure",
		}},
	}, {"phase": run.phase, "paused": true})
	app.next_id = next_turret_id
	message = "Loaded v2; Pause resumes"
	return OK

func _save_content(app) -> Error:
	var runtime = app.scene._native_combat
	if not runtime.active or app.run_domain.state.is_empty():
		message = "No active stage"
		return ERR_UNCONFIGURED
	# v2 positions use the existing one-tile coordinate contract.
	if not is_equal_approx(runtime.tile_size, 1.0) or runtime.origin != Vector2.ZERO:
		message = "Unsupported checkpoint coordinate configuration"
		return ERR_UNAVAILABLE
	# Apply economy exactly once and acknowledge it before capturing combat.
	if not app.command():
		message = app.run_domain.error
		return ERR_INVALID_DATA
	return persist_state(app, app.run_domain.state)

func save_progression(app, progression: Dictionary) -> Error:
	var values := progression.duplicate(true)
	var modules: Dictionary = values.get("turretModules", {}).duplicate(true)
	values.erase("turretModules")
	var saved: Variant = Codec.decode({"version":2,"savedAtMillis":int(app.run_domain.now_millis.call()),"preferences":preferences,"progression":values,"turretModules":modules,"activeRun":null})
	if saved == null: return ERR_INVALID_DATA
	var result: Error = store.save_save(saved)
	message = "진행 상황을 저장했습니다" if result == OK else store.last_error_message
	return result

func _load_content(app) -> Error:
	var saved = store.load_save()
	if saved == null:
		message = "No checkpoint" if store.last_error == OK else store.last_error_message
		return ERR_FILE_NOT_FOUND if store.last_error == OK else store.last_error
	# A local checkpoint is only a cache of server-owned balances. Restore the
	# durable newest receipt before allowing an older v2 file to become live.
	if owner != "guest":
		var queue = rewards()
		if not queue.loaded: return queue.last_error
		var cached: Dictionary = queue.state.get("lastServerSnapshot", {})
		if not cached.is_empty():
			var source: Dictionary = saved.progression.duplicate(true)
			source.turretModules = saved.turretModules
			var mapped: Dictionary = RewardSnapshot.new().apply_authoritative(source, cached)
			if mapped.is_empty():
				message = "Invalid cached authoritative economy"
				return ERR_INVALID_DATA
			saved.turretModules = mapped.turretModules
			mapped.erase("turretModules")
			saved.progression = mapped
	if saved.activeRun == null:
		if not allow_progression_only:
			message = "No active run"
			return ERR_INVALID_DATA
		app.progression_inputs = saved.progression.duplicate(true)
		app.progression_inputs.turretModules = saved.turretModules.duplicate(true)
		preferences = saved.preferences.duplicate(true)
		message = "진행 상황을 불러왔습니다"
		return OK
	var adapter = ContentSave.new(app.catalog, app.run_domain.growth)
	var restored: Dictionary = adapter.prepare(saved, app.battle_inputs)
	if restored.is_empty():
		message = adapter.error
		return ERR_INVALID_DATA
	# Assign an identity to older checkpoints before any durable enqueue.
	if restored.state.get("economyRunId") == null:
		restored.state.economyRunId = app.run_domain.new_run_id()
		saved.activeRun.economyRunId = restored.state.economyRunId
		if store.save_save(saved) != OK:
			message = store.last_error_message
			return store.last_error
	if enqueue_saved(saved) != OK: return reward_queue.last_error
	# All content/configuration validation precedes scene replacement and event ACK.
	app.enter_stage(restored.stage, restored.bootstrap, restored.session, restored.state)
	app.next_enemy_id = restored.nextEnemyId
	app.next_round = restored.nextRound
	preferences = saved.preferences.duplicate(true)
	message = "Loaded actual-content v2; Pause resumes"
	return OK

func _unsupported() -> Error:
	message = "Unsupported by development fixture; checkpoint unchanged"
	return ERR_UNAVAILABLE

static func _is_fixture_run(run: Dictionary) -> bool:
	if run.gold != 0 or run.gemShards != 0: return false
	if not run.phase in ["preparation", "wave", "failure"]: return false
	if run.runCoreCombatSkill != null or not run.runUpgradeLevels.is_empty() or not run.gemInventory.is_empty(): return false
	if run.economyRunId != null or run.pendingEconomyDiamonds != 0 or not run.rewardOptions.is_empty(): return false
	for turret in run.turrets:
		if turret.type != "arrow" or turret.level != 1 or turret.slotLimit != 1: return false
		if not turret.equippedGems.is_empty() or turret.equippedGemSlots.any(func(value): return value != null): return false
		if turret.primaryTrait != null or turret.secondaryTrait != null or turret.targetPriority != "first": return false
	for enemy in run.enemies:
		if enemy.type != "normal" or enemy.maxHp != 300.0 or enemy.shield != 0 or enemy.armor != 0 or enemy.diamondReward != 0: return false
	for pending in run.spawnQueue:
		if pending.enemyType != "normal": return false
	return true

static func enemy_configuration(path: Array, id: int, saved: Dictionary = {}) -> Dictionary:
	var result := {"id": id, "path": path, "speed": 38.4, "maxHp": 300.0, "hp": 300.0, "coreDamage": 20.0, "collisionRadius": 0.22, "presentationScale": 0.65, "presentationSize": [0.44, 0.44], "type": "normal", "boardDistanceScale": 1.0 / 48.0}
	result.merge(saved, true)
	return result
