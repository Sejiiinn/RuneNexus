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

func _init(base_directory: String = "user://", slot = null, legacy_file: String = "") -> void:
	if slot == null:
		slot = Slot.guest()
	_valid_slot = slot.is_valid()
	if not _valid_slot:
		return
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
	return _valid_slot

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
	var current := _read_valid(primary_path)
	if last_error != OK:
		return last_error
	if not current.is_empty() and current.raw != raw:
		if _write_atomic(backup_path, current.raw) != OK:
			return last_error
	return _write_atomic(primary_path, raw)

func preserve_current_as_backup() -> Error:
	if not _begin():
		return last_error
	var current := _read_valid(primary_path)
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
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return SaveJson.parse(file.get_as_text())

func _read_valid(path: String, legacy_only: bool = false) -> Dictionary:
	if _recover(path) != OK or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	var parsed := SaveJson.parse_record(raw)
	if not parsed.ok:
		return {}
	var value: Variant = parsed.value
	if legacy_only:
		if not value is Dictionary or value.get("version") != 1:
			return {}
	elif not Codec.is_canonical_v2(value):
		return {}
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
		elif FileAccess.file_exists(temporary) and Codec.decode(_read_json(temporary)) != null:
			if _rename(temporary, path) != OK:
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
