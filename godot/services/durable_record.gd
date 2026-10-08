extends RefCounted
## Fail closed on unreadable state. Keep last valid record and interrupted writes.
const SaveJson = preload("res://app/save_json.gd")
var path: String
var backup_path: String
var validate: Callable
var last_error: Error = OK

func _init(record_path: String, validator: Callable = Callable(), backup: String = "") -> void:
	path = record_path
	backup_path = backup if not backup.is_empty() else path + ".backup"
	validate = validator

func load_record() -> Dictionary:
	last_error = OK
	var exists := _exists(path) or _exists(backup_path)
	var records := _inspect_records()
	if last_error != OK: return {"ok": false, "code": "RECORD_IO_ERROR"}
	for candidate in [path, backup_path]:
		if _recover(candidate, records[candidate]) != OK: return {"ok": false, "code": "RECORD_IO_ERROR"}
		var data := _read(candidate)
		if last_error != OK: return {"ok": false, "code": "RECORD_IO_ERROR"}
		if not data.is_empty():
			if candidate != path and _write(path, data.raw) != OK: return {"ok": false, "code": "RECORD_IO_ERROR"}
			return {"ok": true, "value": data.value}
	return {"ok": not exists, "value": null, "code": "RECORD_CORRUPT" if exists else ""}

func save_record(value: Dictionary) -> Error:
	last_error = OK
	if not SaveJson.is_json_value(value) or (validate.is_valid() and not validate.call(value)):
		last_error = ERR_INVALID_DATA
		return last_error
	var records := _inspect_records()
	if last_error != OK: return last_error
	for candidate in [path, backup_path]:
		if _recover(candidate, records[candidate]) != OK: return last_error
	var raw := JSON.stringify(value, "", false, true)
	var old := _read(path)
	if last_error != OK: return last_error
	if not old.is_empty() and old.raw == raw: return OK
	if not old.is_empty() and old.raw != raw:
		if _write(backup_path, old.raw) != OK: return last_error
	return _write(path, raw)

func _open_read(candidate: String):
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		if error != ERR_FILE_NOT_FOUND: last_error = error
	return file

func _read_text(candidate: String) -> Variant:
	# file_exists() also hides inaccessible parent directories. Only an open's
	# explicit NOT_FOUND is missing; permission and read errors must stop recovery.
	var file = _open_read(candidate)
	if file == null: return null
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: Error = file.get_error()
	file.close()
	if error != OK and error != ERR_FILE_EOF:
		last_error = error
		return null
	if bytes.size() != length:
		last_error = ERR_FILE_CANT_READ
		return null
	return bytes.get_string_from_utf8()

func _decode(raw: Variant) -> Dictionary:
	if raw == null: return {}
	var value: Variant = SaveJson.parse(raw)
	if not value is Dictionary or (validate.is_valid() and not validate.call(value)): return {}
	return {"value": value, "raw": raw}

func _read(candidate: String) -> Dictionary:
	return _decode(_read_text(candidate))

func _inspect(candidate: String) -> Dictionary:
	var files := {}
	for suffix in ["", ".tmp", ".replace"]:
		files[suffix] = _read_text(candidate + suffix)
		if last_error != OK: return {}
	return files

func _inspect_records() -> Dictionary:
	# Inspect both records and interrupted writes before any rename/removal.
	# An unreadable current record must never be replaced by an older backup.
	var records := {}
	for candidate in [path, backup_path]:
		records[candidate] = _inspect(candidate)
		if last_error != OK: return {}
	return records

func _exists(candidate: String) -> bool:
	return FileAccess.file_exists(candidate) or FileAccess.file_exists(candidate + ".tmp") or FileAccess.file_exists(candidate + ".replace")

func _recover(candidate: String, files: Dictionary = {}) -> Error:
	if files.is_empty(): files = _inspect(candidate)
	if last_error != OK: return last_error
	var installed: bool = files[""] != null
	if not installed:
		if files[".replace"] != null:
			last_error = DirAccess.rename_absolute(candidate + ".replace", candidate)
			installed = last_error == OK
		elif not _decode(files[".tmp"]).is_empty():
			last_error = DirAccess.rename_absolute(candidate + ".tmp", candidate)
			installed = last_error == OK
	if last_error != OK: return last_error
	if installed:
		for suffix in [".tmp", ".replace"]:
			if FileAccess.file_exists(candidate + suffix):
				last_error = DirAccess.remove_absolute(candidate + suffix)
				if last_error != OK: return last_error
	return OK

func _write(candidate: String, raw: String) -> Error:
	last_error = DirAccess.make_dir_recursive_absolute(candidate.get_base_dir())
	if last_error != OK: return last_error
	var file := FileAccess.open(candidate + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		return last_error
	file.store_string(raw)
	file.flush()
	last_error = file.get_error()
	file.close()
	if last_error != OK: return last_error
	last_error = DirAccess.rename_absolute(candidate + ".tmp", candidate)
	if last_error == OK: return OK
	if FileAccess.file_exists(candidate):
		last_error = DirAccess.rename_absolute(candidate, candidate + ".replace")
		if last_error != OK: return last_error
	last_error = DirAccess.rename_absolute(candidate + ".tmp", candidate)
	if last_error != OK: return last_error
	return _recover(candidate)
