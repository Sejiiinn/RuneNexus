extends RefCounted
const StageProgression = preload("res://content/stage_progression.gd")
## Local v2 checkpoints for the independent content session and legacy fixture.
## Account settlement and existing-installation data handoff remain separate.
const Codec = preload("res://app/save_codec.gd")
const GemReroll = preload("res://app/gem_reroll.gd")
const GemDeck = preload("res://app/gem_deck.gd")
const Adapter = preload("res://app/run_save_adapter.gd")
const ContentSave = preload("res://app/content_run_save.gd")
const Capture = preload("res://app/checkpoint_capture.gd")
const Worker = preload("res://app/checkpoint_worker.gd")
const SaveOrder = preload("res://app/local_save_order.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const RewardOutbox = preload("res://app/reward_outbox.gd")
const TransitionJournal = preload("res://app/run_transition_journal.gd")
const RewardSnapshot = preload("res://app/reward_snapshot.gd")
var store
var message := ""
var preferences: Dictionary = {}
var base_directory: String
var owner: String
var reward_queue
var queued_run_id := ""
var allow_progression_only := false
var worker
var generation := 1
var last_requested_sequence := 0
var last_completed_sequence := 0
var last_durable_sequence := 0
var _async_error: Error = OK
var _async_message := ""

func _init(directory: String = "user://standalone-session", account_owner: String = "guest") -> void:
	base_directory = directory
	owner = account_owner.to_lower()
	var slot = Slot.guest() if owner == "guest" else Slot.account(owner)
	store = Store.new(directory, slot)
	if slot == null: store._valid_slot = false

# Detached fixtures retain the synchronous contract unless explicitly enabled.
# Content and growth are cloned once per binding, never shared with live errors.
func enable_worker(app, before_commit: Callable = Callable()) -> void:
	if worker != null: return
	worker = Worker.new(app.catalog._data.duplicate(true), app.run_domain.growth.data.duplicate(true), base_directory, owner, before_commit)

func pending_count() -> int:
	return 0 if worker == null else worker.pending_count()

func _accept_completions(completed: Array) -> Array:
	var accepted := []
	var slot := SaveOrder.slot_key(base_directory, owner)
	for result in completed:
		if int(result.generation) != generation or result.slot != slot: continue
		last_completed_sequence = maxi(last_completed_sequence, int(result.sequence))
		if result.error == OK:
			last_durable_sequence = maxi(last_durable_sequence, int(result.sequence))
			if _async_error == OK and int(result.sequence) == last_requested_sequence: message = result.message
		elif _async_error == OK:
			_async_error = result.error
			_async_message = result.message
			message = _async_message
		accepted.append(result)
	return accepted

func poll_completions() -> Array:
	return [] if worker == null else _accept_completions(worker.take_completions())

# Returns durable completion, never mere queue acceptance. An explicit successful
# synchronous checkpoint may repair a prior background failure afterward.
func flush_pending() -> Error:
	if worker != null: _accept_completions(worker.flush())
	if _async_error != OK: message = _async_message
	return _async_error

func shutdown() -> Error:
	if worker != null:
		_accept_completions(worker.shutdown())
		worker = null
	var result: Error = _async_error
	generation += 1
	return result

func _clear_async_failure() -> void:
	_async_error = OK
	_async_message = ""

# OK means snapshot accepted; durable success/failure is delivered by poll/flush.
# Terminal checkpoints stay synchronous because the live outbox is main-owned.
func request_session(app) -> Error:
	# A request queued behind a slot transaction this thread holds could never run
	# before a later flush in that transaction; save synchronously inside it.
	if worker == null or store.slot_order().held_by_caller(): return save_session(app)
	if not app.is_content_session() or app.run_domain.state.is_empty(): return save_session(app)
	if not app.command():
		message = app.run_domain.error
		return ERR_INVALID_DATA
	if app.run_domain.state.phase in ["success", "failure", "coreDestruction"]: return save_session(app)
	var request := capture_state(app, app.run_domain.state)
	if request.is_empty(): return ERR_UNAVAILABLE
	request.generation = generation
	var accepted: Dictionary = worker.submit(request)
	if accepted.error != OK:
		message = "저장 작업을 시작하지 못했습니다"
		return accepted.error
	last_requested_sequence = int(accepted.sequence)
	return OK

func rewards():
	if reward_queue == null:
		reward_queue = RewardOutbox.new(base_directory, owner)
	if not reward_queue.loaded and reward_queue.load_state() != OK: message = reward_queue.last_error_message
	return reward_queue

# Runtime writes cannot certify a fallback backup. Only OnlineSave's canonical
# rebase may replace it after preserving the original conflict evidence.
func _ordinary_write_allowed() -> bool:
	if owner == "guest" or not store.has_recovery_marker(): return true
	message = "서버 저장 복구를 먼저 완료해 주세요"
	return false

func enqueue_saved(saved: Dictionary) -> Error:
	flush_pending()
	var _transaction_scope = store.transaction_scope()
	if not _ordinary_write_allowed(): return ERR_BUSY
	var run: Variant = saved.get("activeRun")
	if not run is Dictionary or run.phase not in ["success", "failure", "coreDestruction"]: return OK
	var queue = rewards()
	if not queue.loaded:
		message = queue.last_error_message
		return queue.last_error
	var result: Error = queue.enqueue(_saved_reward(saved))
	if result != OK: message = queue.last_error_message
	else: queued_run_id = run.economyRunId
	return result

func _saved_reward(saved: Dictionary) -> Dictionary:
	var run: Dictionary = saved.activeRun
	return {"runId":run.economyRunId,"stageNumber":run.stageNumber,
		"completedRounds":run.completedRounds,"success":run.phase == "success",
		"pendingDiamonds":run.pendingEconomyDiamonds,
		"firstClearModuleTickets":int(saved.progression.get("lastRunTurretModuleTicketReward",0)) if run.phase == "success" else 0,
		"createdAtMillis":saved.savedAtMillis}

func enqueue_finished(app) -> Error:
	return _save_content(app)

# The simulation/event ACK remains on main. Every branch handed to conversion
# is owned, so later live commands cannot mutate a queued checkpoint.
func capture_state(app, candidate: Dictionary, abandoning: bool = false, previous: Dictionary = {}) -> Dictionary:
	var runtime = app.scene.combat_runtime
	if not runtime.active or not is_equal_approx(runtime.tile_size, 1.0) or runtime.origin != Vector2.ZERO:
		message = "Unsupported checkpoint coordinate configuration"
		return {}
	return {"state":candidate.duplicate(true), "previous":previous.duplicate(true),
		"snapshot":runtime.snapshot(), "abandoning":abandoning,
		"saved_at":int(app.run_domain.now_millis.call()), "preferences":preferences.duplicate(true)}

# Synchronous durable boundary. Conversion is separate from live capture and
# commit_saved owns the complete save/outbox journal decision.
func commit_capture(request: Dictionary, content, growth_rules) -> Error:
	flush_pending()
	if request.is_empty(): return ERR_UNAVAILABLE
	var capture = Capture.new(content, growth_rules)
	var prepared: Dictionary = capture.prepare(request)
	if prepared.is_empty():
		message = capture.error
		return ERR_INVALID_DATA
	return commit_saved(prepared)

func commit_saved(prepared: Dictionary) -> Error:
	flush_pending()
	var _transaction_scope = store.transaction_scope()
	if not _ordinary_write_allowed(): return ERR_BUSY
	var saved: Dictionary = prepared.saved
	var before: Dictionary = prepared.before
	var result: Error
	if not before.is_empty():
		var queue = rewards()
		if not queue.loaded:
			message = queue.last_error_message
			return queue.last_error
		var journal = TransitionJournal.new(base_directory, owner)
		result = journal.persist(store, queue, before, saved, _saved_reward(saved))
		if result != OK: message = journal.last_error_message
		else: queued_run_id = saved.activeRun.economyRunId
	else:
		result = store.save_save(saved)
		if result == OK: result = enqueue_saved(saved)
	if result == OK:
		preferences = saved.preferences.duplicate(true)
		_clear_async_failure()
	message = "Saved v2 checkpoint and retained run reward" if result == OK else (message if store.last_error == OK else store.last_error_message)
	return result

func persist_state(app, candidate: Dictionary, abandoning: bool = false, previous: Dictionary = {}) -> Error:
	# The candidate already contains the terminal reward/claim decision. Migrate
	# only that ended run, and commit the refund/archive in the same checkpoint
	# (and transition journal when abandoning). Failure leaves live ranks intact.
	var migration := {"changed":false}
	if int(candidate.get("progression", {}).get("corePassiveTreeRevision", 4)) < 5 and str(candidate.get("phase", "preparation")) in ["success", "failure", "coreDestruction"]:
		migration = app.run_domain.growth.migrate_core_tree({"progression":candidate.get("progression", {}),"activeRun":candidate})
	var prepared := candidate
	if migration.get("changed", false):
		prepared = migration.state.activeRun
		prepared.progression = migration.state.progression
	var result := commit_capture(capture_state(app, prepared, abandoning, previous), app.catalog, app.run_domain.growth)
	if result == OK and migration.get("changed", false):
		var was_live := is_same(candidate, app.run_domain.state)
		candidate.clear()
		candidate.merge(prepared, true)
		if was_live:
			app.run_domain.state = candidate
			app.progression_inputs = candidate.progression.duplicate(true)
	return result

func apply_economy_snapshot(app, snapshot: Dictionary, command: Dictionary = {}) -> bool:
	flush_pending()
	var _transaction_scope = store.transaction_scope()
	# A fallback backup remains untouched until current canonical reconciliation;
	# projecting cached inventory first would destroy its original allocation.
	if owner == "guest" or store.has_recovery_marker(): return false
	var mapper = RewardSnapshot.new()
	if not app.scene.combat_runtime.active:
		var saved = store.load_save()
		if saved == null: return false
		var input: Dictionary = saved.progression.duplicate(true)
		input.turretModules = saved.turretModules
		var mapped: Dictionary = mapper.apply_authoritative(input, snapshot)
		if mapped.is_empty(): return false
		if saved.get("activeRun") is Dictionary: _hold_deck_tickets(mapped, saved.activeRun, snapshot)
		saved.turretModules = mapped.turretModules
		mapped.erase("turretModules")
		saved.progression = mapped
		if saved.get("activeRun") is Dictionary:
			var projected := GemReroll.project_snapshot(saved.activeRun, snapshot)
			if projected.is_empty(): return false
			saved.activeRun = projected
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
	_hold_deck_tickets(mapped, candidate, snapshot)
	candidate.progression = mapped
	candidate = _project_gem_offer(app, candidate, snapshot, command)
	if candidate.is_empty(): return false
	return app.commit_run_state(candidate)

# A deck run spends reset tickets locally; the server debits them when the run
# closes. Until then its open run keeps those tickets out of the local balance.
static func _hold_deck_tickets(progression: Dictionary, run: Dictionary, snapshot: Dictionary) -> void:
	var open: Variant = snapshot.get("run")
	if not run.has("gemDeckLog") or not progression.has("gemResetTickets") or not open is Dictionary or open.get("status") != "active" or open.get("runId") != run.get("economyRunId"): return
	progression.gemResetTickets = maxi(0, int(progression.gemResetTickets) - GemDeck.pending_ticket_cost(run))

func _project_gem_offer(app, state: Dictionary, snapshot: Dictionary, command: Dictionary = {}) -> Dictionary:
	var offer: Variant = snapshot.get("gemOffer")
	var next := GemReroll.project_snapshot(state, snapshot)
	if next.is_empty() or not offer is Dictionary or offer.status != "chosen": return next
	if next.get("economyRunId") != offer.runId or int(next.get("completedRounds", 0)) != offer.rewardWave or next.get("gemOfferId") != offer.offerId or int(next.get("gemOfferRevision", 0)) != offer.revision: return next
	if int(next.get("gemOfferEquipRevision", 0)) >= offer.revision: return next
	# Cached/offline projections cannot prove that a persisted baseRevision is
	# current. Only the explicit command callback after fresh reconciliation may
	# execute or cancel an unhandled equipment intent; inFlight retains retries.
	if command.is_empty(): return next
	var intent: Dictionary = command.get("equipIntent", {})
	if command.get("kind") != "choose_gem" or intent.is_empty(): return next
	var body: Variant = preload("res://app/save_json.gd").parse(command.get("encodedBody", ""))
	if not body is Dictionary or body.get("runId") != offer.runId or body.get("offerId") != offer.offerId or body.get("choice") != offer.grantedGem: return next
	# The grant is authoritative; local equipment is only a best-effort intent.
	# A newer canonical layout may have sold its target or occupied its slot.
	# Mark that intent handled without mutating the grant/layout, so recovery can
	# retire the successful choice and cannot redirect it after a later rebuild.
	var resolved := next.duplicate(true)
	resolved.gemOfferEquipRevision = offer.revision
	# Tile/type can be reused after a sale. Only the original mutation's current
	# canonical revision proves an unhandled target has not since been replaced.
	var canonical_revision := -1
	if app.services != null and app.services.online != null:
		canonical_revision = int(app.services.online.state.get("baseRevision", -1))
	if canonical_revision < 0: return next # Cached/offline projection has no fresh target proof.
	if canonical_revision != int(body.get("sourceSaveRevision", -2)) + 1: return resolved
	# Runtime IDs are reconstructed on resume. Match the approved target by its
	# stable tile/type; never redirect an old intent to a new target.
	var target := {}
	for turret in next.get("turrets", []):
		if int(turret.x) == int(intent.get("x", -1)) and int(turret.y) == int(intent.get("y", -1)) and turret.type == intent.get("turretType"):
			target = turret
			break
	if target.is_empty(): return resolved
	var service = app.run_domain.service
	var slot := int(intent.get("slot", -1))
	if intent.get("buySlot", false):
		if slot != int(target.slotLimit): return resolved
		var linked: Dictionary = service.apply(next, {"kind":"link", "id":target.id})
		if not linked.get("ok", false): return resolved
		next = linked.state
	var equipped: Dictionary = service.apply(next, {"kind":"equipGem", "id":target.id, "slot":slot, "type":offer.grantedGem})
	if not equipped.get("ok", false): return resolved
	next = equipped.state
	next.gemOfferEquipRevision = offer.revision
	return next

func save_session(app) -> Error:
	flush_pending()
	var _transaction_scope = store.transaction_scope()
	if not _ordinary_write_allowed(): return ERR_BUSY
	if app.is_content_session(): return _save_content(app)
	var runtime = app.scene.combat_runtime
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
	flush_pending()
	var _transaction_scope = store.transaction_scope()
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
	var entered: bool = app.enter_stage(index, {
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
	if not entered: return ERR_INVALID_DATA
	app.next_id = next_turret_id
	message = "Loaded v2; Pause resumes"
	return OK

func _save_content(app) -> Error:
	var runtime = app.scene.combat_runtime
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
	flush_pending()
	var _transaction_scope = store.transaction_scope()
	if not _ordinary_write_allowed(): return ERR_BUSY
	var values := progression.duplicate(true)
	var modules: Dictionary = values.get("turretModules", {}).duplicate(true)
	values.erase("turretModules")
	var saved: Variant = Codec.decode({"version":2,"savedAtMillis":int(app.run_domain.now_millis.call()),"preferences":preferences,"progression":values,"turretModules":modules,"activeRun":null})
	if saved == null: return ERR_INVALID_DATA
	var migration: Dictionary = app.run_domain.growth.migrate_core_tree(saved)
	if migration.get("changed", false): saved = migration.state
	var result: Error = store.save_save(saved)
	if result == OK:
		_clear_async_failure()
		if migration.get("changed", false):
			progression.clear()
			progression.merge(saved.progression, true)
			progression.turretModules = modules
	message = "진행 상황을 저장했습니다" if result == OK else store.last_error_message
	return result

func _load_content(app) -> Error:
	var saved = store.load_save()
	if saved == null:
		message = "No checkpoint" if store.last_error == OK else store.last_error_message
		return ERR_FILE_NOT_FOUND if store.last_error == OK else store.last_error
	var backup_uncertain: bool = owner != "guest" and store.has_recovery_marker()
	# Persist migration and rights together before the restored state is playable.
	var migrated := StageProgression.migrate_progression(saved.progression,saved.activeRun if saved.activeRun is Dictionary else {},saved.turretModules)
	if migrated != saved.progression:
		saved.progression = migrated
		if not backup_uncertain and store.save_save(saved) != OK:
			message = store.last_error_message
			return store.last_error
	# A local checkpoint is only a cache of server-owned balances. Restore the
	# durable newest receipt before allowing an older v2 file to become live.
	if owner != "guest" and not backup_uncertain:
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
			if saved.get("activeRun") is Dictionary: _hold_deck_tickets(mapped, saved.activeRun, cached)
			saved.turretModules = mapped.turretModules
			mapped.erase("turretModules")
			saved.progression = mapped
			if saved.get("activeRun") is Dictionary:
				var projected := GemReroll.project_snapshot(saved.activeRun, cached)
				if projected.is_empty(): return ERR_INVALID_DATA
				saved.activeRun = projected
				if not backup_uncertain and store.save_save(saved) != OK: return store.last_error
	if saved.activeRun is Dictionary and GemReroll.eligible(saved.activeRun) and not GemReroll.current_offer(saved.activeRun):
		# Pre-v8 random wave cards are not authority. Keep the paused reward and
		# migrate by requesting the initial server offer, never by uploading cards.
		saved.activeRun.rewardOptions = []
		if not backup_uncertain and store.save_save(saved) != OK: return store.last_error
	# Journal recovery and authoritative economy projection precede this change.
	# A suspended v4 run stays v4, including preparation/reward in the lobby.
	# Terminal run records remain available, with their old loadout pinned.
	var core_migration: Dictionary = app.run_domain.growth.migrate_core_tree(saved)
	if core_migration.get("changed", false) and not backup_uncertain:
		if store.save_save(core_migration.state) != OK:
			message = store.last_error_message
			return store.last_error
		saved = core_migration.state
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
	if owner == "guest" and restored.state.get("economyRunId") == null:
		restored.state.economyRunId = app.run_domain.new_run_id()
		saved.activeRun.economyRunId = restored.state.economyRunId
		if not backup_uncertain and store.save_save(saved) != OK:
			message = store.last_error_message
			return store.last_error
	if not backup_uncertain and enqueue_saved(saved) != OK: return reward_queue.last_error
	# All content/configuration validation precedes scene replacement and event ACK.
	if not app.enter_stage(restored.stage, restored.bootstrap, restored.session, restored.state):
		return ERR_INVALID_DATA
	app.next_enemy_id = restored.nextEnemyId
	app.next_round = restored.nextRound
	preferences = saved.preferences.duplicate(true)
	if owner != "guest" and not backup_uncertain:
		var cached: Dictionary = rewards().state.get("lastServerSnapshot", {})
		if not cached.is_empty() and not apply_economy_snapshot(app, cached): return ERR_FILE_CANT_WRITE
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
