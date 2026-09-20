extends RefCounted
## Save/restart proof for the fixed standalone fixture only. Not a production
## content resolver: real progression, rewards and definitions migrate separately.
const Codec = preload("res://app/save_codec.gd")
const Adapter = preload("res://app/run_save_adapter.gd")
const Store = preload("res://app/local_save_store.gd")
var store
var message := ""

func _init(directory: String = "user://standalone-session") -> void:
	store = Store.new(directory)

func save_session(app) -> Error:
	if app.content_enabled: return _unsupported_content()
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
	if app.content_enabled: return _unsupported_content()
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

func _unsupported_content() -> Error:
	message = "Save/load unavailable in content preview"
	return ERR_UNAVAILABLE

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
