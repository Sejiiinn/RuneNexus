extends "res://app/local_save_store.gd"
## Account-compatible Dart economy outbox. Guest queue is local only and never
## automatically transferred to an account. Failed reads never initialize over data.
var owner: String
var state: Dictionary = {}
var loaded := false

func _init(base_directory: String = "user://", account_owner: String = "guest") -> void:
	super(base_directory)
	owner = account_owner.to_lower()
	_valid_slot = owner == "guest" or Slot.account(owner) != null
	var directory := base_directory.path_join("saves/guest" if owner == "guest" else "saves/accounts/" + owner)
	primary_path = directory.path_join("godot_reward_outbox.json" if owner == "guest" else "economy_outbox.json")
	backup_path = primary_path + ".backup"

func load_state() -> Error:
	if not _begin(): return last_error
	loaded = false
	var existed := false
	for path in [primary_path, backup_path]:
		for suffix in ["", ".tmp", ".replace"]:
			existed = existed or FileAccess.file_exists(path + suffix)
		if _recover(path) != OK: return last_error
		var value: Variant = _read_json(path)
		if valid_state(value):
			if path == backup_path and _write_atomic(primary_path, JSON.stringify(value)) != OK: return last_error
			state = value
			loaded = true
			return OK
	if existed: return _fail(ERR_FILE_CORRUPT, "Reward outbox is corrupt or belongs to another account")
	state = {"version": 1, "accountIdBinding": owner, "inFlight": null, "pendingRewards": []}
	loaded = true
	return OK

func save_state(next: Dictionary) -> Error:
	if not _begin(): return last_error
	if not loaded or not valid_state(next): return _fail(ERR_INVALID_DATA, "Invalid or unread reward outbox")
	if _recover(primary_path) != OK: return last_error
	var old: Variant = _read_json(primary_path)
	if FileAccess.file_exists(primary_path) and not valid_state(old): return _fail(ERR_FILE_CORRUPT, "Refusing to overwrite corrupt outbox")
	if old != null and _write_atomic(backup_path, JSON.stringify(old, "", false, true)) != OK: return last_error
	if _write_atomic(primary_path, JSON.stringify(next, "", false, true)) != OK: return last_error
	state = next.duplicate(true)
	return OK

func enqueue(reward: Dictionary) -> Error:
	if not loaded:
		if load_state() != OK: return last_error
	if not valid_reward(reward): return _fail(ERR_INVALID_DATA, "Invalid run reward")
	if reward.runId in state.get("completedRunIds", []): return OK
	for existing in state.pendingRewards:
		if existing.runId == reward.runId:
			for key in ["stageNumber", "completedRounds", "success", "pendingDiamonds", "firstClearModuleTickets"]:
				if existing.get(key, 0) != reward.get(key, 0): return _fail(ERR_INVALID_DATA, "Conflicting run reward")
			return OK
	var next := state.duplicate(true)
	next.pendingRewards.append(reward.duplicate(true))
	return save_state(next)

func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.get("accountIdBinding") != owner or not value.get("pendingRewards") is Array: return false
	if not value.get("completedRunIds", []) is Array: return false
	for id in value.get("completedRunIds", []):
		if not id is String or Slot.account(id) == null: return false
	if value.has("lastServerSnapshot") and not load("res://app/reward_settlement.gd").valid_snapshot(value.lastServerSnapshot): return false
	var seen := {}
	for reward in value.pendingRewards:
		if not valid_reward(reward) or seen.has(reward.runId): return false
		seen[reward.runId] = true
	var command: Variant = value.get("inFlight")
	if command != null:
		if not command is Dictionary: return false
		for key in ["kind", "path", "idempotencyKey", "encodedBody"]:
			if not command.get(key) is String or command[key].is_empty(): return false
		if not command.get("createdAtMillis") is int or command.createdAtMillis < 0: return false
		if not SaveJson.parse(command.encodedBody) is Dictionary: return false
	return SaveJson.is_json_value(value)

static func valid_reward(value: Variant) -> bool:
	if not value is Dictionary or not value.get("runId") is String or Slot.account(value.runId) == null or not value.get("success") is bool: return false
	for key in ["stageNumber", "completedRounds", "pendingDiamonds", "createdAtMillis"]:
		if not value.get(key) is int or value[key] < 0: return false
	var tickets: Variant = value.get("firstClearModuleTickets", 0)
	return value.stageNumber > 0 and value.stageNumber <= 15 and value.completedRounds <= 40 and value.pendingDiamonds <= (value.completedRounds + 1) * 300 and tickets is int and (tickets == 0 or (tickets == 5 and value.success and value.stageNumber == 11))

func _recover(path: String) -> Error:
	if not FileAccess.file_exists(path):
		for suffix in [".replace", ".tmp"]:
			if FileAccess.file_exists(path + suffix) and valid_state(_read_json(path + suffix)):
				if _rename(path + suffix, path) != OK: return last_error
				break
	if FileAccess.file_exists(path) and valid_state(_read_json(path)):
		for suffix in [".replace", ".tmp"]:
			if _remove(path + suffix) != OK: return last_error
	return OK
