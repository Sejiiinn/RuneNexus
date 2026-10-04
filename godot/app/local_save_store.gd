class_name LocalSaveStore
extends RefCounted
## Native, synchronous repository. Callers must check errors before acknowledging saves.
## Pass the existing Flutter application-support directory to hand off an installation.
## A v1 system-temp path is opt-in; never infer or scan another application's files.
const Codec = preload("res://app/save_codec.gd")
const SaveJson = preload("res://app/save_json.gd")
const Slot = preload("res://app/local_save_slot.gd")
var last_error: Error = OK
var last_error_message: String = ""
var primary_path: String
var backup_path: String
var conflict_path: String
var legacy_path: String
var _valid_slot: bool = true
var transition_recovery_enabled := true
var transition_directory: String
var transition_owner: String
# A single immutable JSON string, never caller-owned data or a destination cache.
# Reuse its v2 validation only after recovery and a complete read match its bytes.
var _validated_v2_raw: String = ""

func _init(base_directory: String = "user://", slot = null, legacy_file: String = "") -> void:
	if slot == null:
		slot = Slot.guest()
	_valid_slot = slot.is_valid()
	if not _valid_slot:
		return
	transition_directory = base_directory
	transition_owner = "guest" if slot.is_guest() else slot.account_id.to_lower()
	var directory: String = base_directory.path_join("saves/guest" if slot.is_guest() else "saves/accounts/" + slot.account_id.to_lower())
	primary_path = directory.path_join("save_v2.json")
	backup_path = directory.path_join("save_v2.backup.json")
	conflict_path = directory.path_join("save_v2.conflict.json")
	legacy_path = legacy_file if slot.is_guest() else ""

func _begin() -> bool:
	last_error = OK
	last_error_message = ""
	if not _valid_slot:
		_fail(ERR_INVALID_PARAMETER, "Invalid account save slot")
	if _valid_slot and transition_recovery_enabled:
		var journal = load("res://app/run_transition_journal.gd").new(transition_directory, transition_owner)
		if journal.recover_transaction(self) != OK:
			_fail(journal.last_error, journal.last_error_message)
	return _valid_slot and last_error == OK

func _fail(code: Error, context: String) -> Error:
	if last_error == OK:
		last_error = code
		last_error_message = context
	return code

func load_save() -> Variant:
	if not _begin():
		return null
	var primary := _read_valid(primary_path)
	if not primary.is_empty():
		return primary.data
	if last_error != OK:
		return null
	var backup := _read_valid(backup_path)
	if not backup.is_empty():
		if save_save(backup.data) != OK:
			return null
		return backup.data
	if last_error != OK or legacy_path.is_empty():
		return null
	var legacy := _read_valid(legacy_path, true)
	if legacy.is_empty() or save_save(legacy.data) != OK:
		return null
	return legacy.data

func save_save(data: Dictionary) -> Error:
	if not _begin():
		return last_error
	if not SaveJson.is_json_value(data) or not Codec.is_normalized_v2(data):
		return _fail(ERR_INVALID_DATA, "Expected normalized typed v2 save")
	for path in [primary_path, backup_path]:
		if _recover(path) != OK:
			return last_error
	var raw := JSON.stringify(data, "", false, true)
	var current := _read_valid(primary_path, false, false)
	if last_error != OK:
		return last_error
	# Read/recover/validate before skipping IO, including after external replacement.
	if not current.is_empty() and current.raw == raw:
		return OK
	if not current.is_empty() and current.raw != raw:
		if _write_atomic(backup_path, current.raw) != OK:
			return last_error
	var result := _write_atomic(primary_path, raw)
	# Validated normalized JSON values serialized by Godot have the same canonical
	# envelope and signed-int64/finite-number contract as parse_record accepts.
	# Failed writes cannot certify the attempted replacement's bytes.
	if result == OK: _validated_v2_raw = raw
	return result

func preserve_current_as_backup() -> Error:
	if not _begin():
		return last_error
	var current := _read_valid(primary_path, false, false)
	if last_error != OK or current.is_empty():
		return last_error
	return _write_atomic(backup_path, current.raw)

func preserve_conflict_backup(envelope: Dictionary) -> Error:
	if not _begin():
		return last_error
	if not SaveJson.is_json_value(envelope) or envelope.get("version") != 1 or not envelope.get("rebaseId") is String or not Codec.is_normalized_v2(envelope.get("data")):
		return _fail(ERR_INVALID_DATA, "Invalid conflict backup")
	if _recover(conflict_path) != OK:
		return last_error
	var existing: Variant = _read_json(conflict_path)
	if last_error != OK:
		return last_error
	if existing is Dictionary and existing.get("version") == 1 and Codec.is_canonical_v2(existing.get("data")) and existing.get("rebaseId") == envelope.rebaseId:
		return OK
	return _write_atomic(conflict_path, JSON.stringify(envelope, "", false, true))

func clear() -> Error:
	if not _begin():
		return last_error
	for path in [primary_path, backup_path, conflict_path, legacy_path]:
		if path.is_empty():
			continue
		for suffix in ["", ".tmp", ".replace"]:
			if _remove(path + suffix) != OK:
				return last_error
	return OK

func _read_json(path: String) -> Variant:
	var raw: Variant = _read_text(path)
	return null if raw == null else SaveJson.parse(raw)

func _open_read(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		if error != ERR_FILE_NOT_FOUND:
			_fail(error, "Open save: " + path)
	return file

func _read_text(path: String) -> Variant:
	# file_exists() also returns false when a parent directory is inaccessible.
	# Opening distinguishes a missing save from those I/O failures.
	var file = _open_read(path)
	if file == null:
		return null
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: Error = file.get_error()
	file.close()
	# Check before text decoding (and any seek that may clear the read error).
	# EOF is harmless only if the requested bytes were all read.
	if error != OK and error != ERR_FILE_EOF:
		_fail(error, "Read save: " + path)
		return null
	if bytes.size() != length:
		_fail(ERR_FILE_CANT_READ, "Incomplete save read: " + path)
		return null
	return bytes.get_string_from_utf8()

func _read_valid(path: String, legacy_only: bool = false, decode_data: bool = true) -> Dictionary:
	if _recover(path) != OK:
		return {}
	var raw: Variant = _read_text(path)
	if raw == null:
		return {}
	if not legacy_only and not decode_data and not _validated_v2_raw.is_empty() and raw == _validated_v2_raw:
		return {"raw":raw}
	var parsed := SaveJson.parse_record(raw)
	if not parsed.ok:
		return {}
	var value: Variant = parsed.value
	if legacy_only:
		if not value is Dictionary or value.get("version") != 1:
			return {}
	elif not Codec.is_canonical_v2(value):
		return {}
	if not legacy_only: _validated_v2_raw = raw
	# The v2 reader accepts every canonical envelope and normalizes its fields.
	# Backup rotation only needs validated bytes, not a discarded normalized tree.
	if not decode_data and not legacy_only:
		return {"raw": raw}
	var decoded: Variant = Codec.decode(value)
	return {} if decoded == null else {"data": decoded, "raw": raw}

func _remove(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	var error := DirAccess.remove_absolute(path)
	return OK if error == OK else _fail(error, "Remove: " + path)

func _rename(source: String, destination: String) -> Error:
	var error := DirAccess.rename_absolute(source, destination)
	return OK if error == OK else _fail(error, "Rename: " + source)

func _recover(path: String) -> Error:
	var temporary := path + ".tmp"
	var displaced := path + ".replace"
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(displaced):
			if _rename(displaced, path) != OK:
				return last_error
		elif FileAccess.file_exists(temporary):
			var pending: Variant = _read_json(temporary)
			if last_error != OK:
				return last_error
			if Codec.decode(pending) != null and _rename(temporary, path) != OK:
				return last_error
	if FileAccess.file_exists(path):
		for artifact in [displaced, temporary]:
			if _remove(artifact) != OK:
				return last_error
	return OK

func _write_atomic(path: String, contents: String) -> Error:
	var ancestor := path.get_base_dir()
	while not ancestor.is_empty():
		if FileAccess.file_exists(ancestor):
			return _fail(ERR_FILE_BAD_PATH, "Save parent is a file")
		var parent := ancestor.get_base_dir()
		if parent == ancestor: break
		ancestor = parent
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return _fail(error, "Create save directory")
	if _recover(path) != OK:
		return last_error
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail(FileAccess.get_open_error(), "Open temporary save")
	file.store_string(contents)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return _fail(error, "Flush temporary save")
	# POSIX rename is atomic. Windows may require displacing the old file.
	if DirAccess.rename_absolute(temporary, path) == OK:
		return OK
	var displaced := path + ".replace"
	if _remove(displaced) != OK:
		return last_error
	if FileAccess.file_exists(path) and _rename(path, displaced) != OK:
		return last_error
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		if not FileAccess.file_exists(path) and FileAccess.file_exists(displaced):
			DirAccess.rename_absolute(displaced, path)
		return _fail(error, "Replace save")
	return _remove(displaced)
