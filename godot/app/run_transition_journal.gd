extends "res://app/local_save_store.gd"
## Slot-local undo/redo record for a checkpoint + reward outbox transaction.
## Prepared is never externally visible; committed is the sole decision point.
const Outbox = preload("res://app/reward_outbox.gd")
var owner: String
var directory: String

func _init(base_directory: String, account_owner: String) -> void:
	owner = account_owner
	directory = base_directory
	super(base_directory, Slot.guest() if owner == "guest" else Slot.account(owner))
	transition_recovery_enabled = false
	_valid_slot = owner == "guest" or Slot.account(owner) != null
	primary_path = primary_path.get_base_dir().path_join("run_transition.json")
	backup_path = ""

func valid_record(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.get("owner") != owner or value.get("status") not in ["prepared", "committed"]: return false
	var queue = Outbox.new(directory, owner)
	for key in ["beforeSave", "afterSave"]:
		if not Codec.is_normalized_v2(value.get(key)): return false
	for key in ["beforeOutbox", "afterOutbox"]:
		if not queue.valid_state(value.get(key)): return false
	return SaveJson.is_json_value(value)

func _recover(path: String) -> Error:
	# The displaced old decision wins over an uninstalled temporary commit.
	var raw: Variant = _read_text(path)
	if last_error != OK: return last_error
	if raw == null:
		for suffix in [".replace", ".tmp"]:
			var pending: Variant = _read_text(path + suffix)
			if last_error != OK: return last_error
			if pending != null:
				if not valid_record(SaveJson.parse(pending)):
					# An incomplete first prepare has never installed a decision or
					# touched either resource. Installed/displaced records fail closed.
					if suffix == ".tmp": return _remove(path + suffix)
					return _fail(ERR_FILE_CORRUPT, "Invalid run transition journal")
				if _rename(path + suffix, path) != OK: return last_error
				raw = pending
				break
	if raw != null and not valid_record(SaveJson.parse(raw)): return _fail(ERR_FILE_CORRUPT, "Invalid run transition journal")
	return OK

func write_record(record: Dictionary) -> Error:
	if not _begin(): return last_error
	if not valid_record(record): return _fail(ERR_INVALID_DATA, "Invalid run transition record")
	if _recover(primary_path) != OK: return last_error
	var error := DirAccess.make_dir_recursive_absolute(primary_path.get_base_dir())
	if error != OK: return _fail(error, "Create run transition directory")
	var temporary := primary_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _fail(FileAccess.get_open_error(), "Open run transition temporary")
	file.store_string(JSON.stringify(record, "", false, true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return _fail(error, "Flush run transition temporary")
	return _install_temporary(temporary)

func _install_temporary(temporary: String) -> Error:
	# Once a decision rename succeeds, later artifact cleanup cannot turn it into
	# a reported failure. Cleanup is retried by recovery before the next operation.
	if DirAccess.rename_absolute(temporary, primary_path) == OK: return OK
	var displaced := primary_path + ".replace"
	if _remove(displaced) != OK: return last_error
	if FileAccess.file_exists(primary_path) and _rename(primary_path, displaced) != OK: return last_error
	var error := DirAccess.rename_absolute(temporary, primary_path)
	if error == OK: return OK
	if not FileAccess.file_exists(primary_path) and FileAccess.file_exists(displaced):
		DirAccess.rename_absolute(displaced, primary_path)
	return _fail(error, "Install run transition decision")

func read_record() -> Variant:
	if not _begin() or _recover(primary_path) != OK: return null
	return _read_json(primary_path)

func remove_record() -> Error:
	if not _begin(): return last_error
	# Delete the decision last, so an interrupted cleanup cannot resurrect an old
	# prepared decision from .replace after a committed primary was removed.
	for suffix in [".tmp", ".replace", ""]:
		if _remove(primary_path + suffix) != OK: return last_error
	return OK

func recover_transaction(target_store, queue = null) -> Error:
	if target_store.primary_path.get_file() != "save_v2.json":
		queue = target_store
		target_store = load("res://app/local_save_store.gd").new(directory, Slot.guest() if owner == "guest" else Slot.account(owner))
		target_store.transition_recovery_enabled = false
	var record: Variant = read_record()
	if last_error != OK: return last_error
	if record == null: return OK
	if queue == null: queue = Outbox.new(directory, owner)
	var store_guard: bool = target_store.transition_recovery_enabled
	var queue_guard: bool = queue.transition_recovery_enabled
	target_store.transition_recovery_enabled = false
	queue.transition_recovery_enabled = false
	var result: Error = _restore(record, target_store, queue)
	if result != OK:
		queue.loaded = false
		queue.state = {}
	target_store.transition_recovery_enabled = store_guard
	queue.transition_recovery_enabled = queue_guard
	return result

func _restore(record: Dictionary, target_store, queue) -> Error:
	var prefix: String = "after" if record.status == "committed" else "before"
	if target_store.save_save(record[prefix + "Save"]) != OK:
		return _fail(target_store.last_error, target_store.last_error_message)
	# Rollback must not leave the just-written terminal candidate as its fallback.
	if prefix == "before" and target_store._write_atomic(target_store.backup_path, JSON.stringify(record.beforeSave, "", false, true)) != OK:
		return _fail(target_store.last_error, target_store.last_error_message)
	# The valid journal is authoritative even when a first outbox write left only
	# an incomplete .tmp. Ordinary queue loading must reject that artifact; undo
	# recovery can replace it from the captured validated state. Read I/O errors
	# still stop _write_atomic before replacement.
	if not queue._begin(): return _fail(queue.last_error, queue.last_error_message)
	var restored: Dictionary = record[prefix + "Outbox"]
	if queue._write_atomic(queue.primary_path, JSON.stringify(restored, "", false, true)) != OK:
		return _fail(queue.last_error, queue.last_error_message)
	if prefix == "before" and queue._write_atomic(queue.backup_path, JSON.stringify(restored, "", false, true)) != OK:
		return _fail(queue.last_error, queue.last_error_message)
	queue.state = restored.duplicate(true)
	queue.loaded = true
	return remove_record()

func persist(target_store, queue, before: Dictionary, after: Dictionary, reward: Dictionary) -> Error:
	if recover_transaction(target_store, queue) != OK: return last_error
	if not queue.loaded and queue.load_state() != OK: return _fail(queue.last_error, queue.last_error_message)
	if not queue.valid_reward(reward): return _fail(ERR_INVALID_DATA, "Invalid transition reward")
	var next: Dictionary = queue.state.duplicate(true)
	var present: bool = reward.runId in next.get("completedRunIds", [])
	if not present:
		for existing in next.pendingRewards:
			if existing.runId == reward.runId:
				for key in ["stageNumber", "completedRounds", "success", "pendingDiamonds", "firstClearModuleTickets"]:
					if existing.get(key, 0) != reward.get(key, 0): return _fail(ERR_INVALID_DATA, "Conflicting run reward")
				present = true
	if not present: next.pendingRewards.append(reward.duplicate(true))
	var record := {"version":1, "owner":owner, "status":"prepared", "beforeSave":before,
		"afterSave":after, "beforeOutbox":queue.state.duplicate(true), "afterOutbox":next}
	if write_record(record) != OK: return last_error
	var store_guard: bool = target_store.transition_recovery_enabled
	var queue_guard: bool = queue.transition_recovery_enabled
	target_store.transition_recovery_enabled = false
	queue.transition_recovery_enabled = false
	var result: Error = target_store.save_save(after)
	if result != OK: _fail(result, target_store.last_error_message)
	if result == OK:
		result = queue.save_state(next)
		if result != OK: _fail(result, queue.last_error_message)
	if result == OK:
		record.status = "committed"
		result = write_record(record)
	if result != OK:
		# Keep prepared undo evidence if restoration itself fails. Every subsequent
		# reader/writer retries recovery and blocks until both resources agree.
		var failure_message: String = last_error_message
		recover_transaction(target_store, queue)
		last_error = result
		last_error_message = failure_message
	else:
		# Cleanup failure leaves a committed redo record; the transition succeeded.
		remove_record()
		last_error = OK
		last_error_message = ""
	target_store.transition_recovery_enabled = store_guard
	queue.transition_recovery_enabled = queue_guard
	return result
