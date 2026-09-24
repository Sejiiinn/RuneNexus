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
	for candidate in [path, backup_path]:
		if _recover(candidate) != OK: return {"ok": false, "code": "RECORD_IO_ERROR"}
		var data := _read(candidate)
		if not data.is_empty():
			if candidate != path and _write(path, data.raw) != OK: return {"ok": false, "code": "RECORD_IO_ERROR"}
			return {"ok": true, "value": data.value}
	return {"ok": not exists, "value": null, "code": "RECORD_CORRUPT" if exists else ""}

func save_record(value: Dictionary) -> Error:
	last_error = OK
	if not SaveJson.is_json_value(value) or (validate.is_valid() and not validate.call(value)): return ERR_INVALID_DATA
	for candidate in [path, backup_path]:
		if _recover(candidate) != OK: return last_error
	var raw := JSON.stringify(value, "", false, true)
	var old := _read(path)
	if not old.is_empty() and old.raw != raw:
		if _write(backup_path, old.raw) != OK: return last_error
	return _write(path, raw)

func _read(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate): return {}
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null: return {}
	var raw := file.get_as_text()
	var value: Variant = SaveJson.parse(raw)
	if not value is Dictionary or (validate.is_valid() and not validate.call(value)): return {}
	return {"value": value, "raw": raw}

func _exists(candidate: String) -> bool:
	return FileAccess.file_exists(candidate) or FileAccess.file_exists(candidate + ".tmp") or FileAccess.file_exists(candidate + ".replace")

func _recover(candidate: String) -> Error:
	if not FileAccess.file_exists(candidate):
		if FileAccess.file_exists(candidate + ".replace"):
			last_error = DirAccess.rename_absolute(candidate + ".replace", candidate)
		elif not _read(candidate + ".tmp").is_empty():
			last_error = DirAccess.rename_absolute(candidate + ".tmp", candidate)
	if last_error != OK: return last_error
	if FileAccess.file_exists(candidate):
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
