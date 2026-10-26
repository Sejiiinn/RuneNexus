extends SceneTree
## Isolated, cross-platform read-fault coverage for online durable records.
const Durable = preload("res://services/durable_record.gd")
var failures: Array[String] = []
var checks := 0
var sandbox: String

class BrokenRead extends RefCounted:
	var bytes := '{"id":"B"}'.to_utf8_buffer()
	var extra_length := 0
	var error: Error = OK
	func get_length() -> int: return bytes.size() + extra_length
	func get_buffer(_length: int) -> PackedByteArray: return bytes
	func get_error() -> Error: return error
	func close() -> void: pass

class FaultRecord extends Durable:
	var unreadable_path := ""
	var broken_read_path := ""
	var broken_read: BrokenRead
	var fail_write_path := ""
	var fail_open_at := 1
	var matching_opens := 0
	func _open_read(candidate: String):
		if candidate == unreadable_path:
			matching_opens += 1
			if matching_opens >= fail_open_at:
				last_error = ERR_FILE_CANT_READ
				return null
		if candidate == broken_read_path: return broken_read
		return super._open_read(candidate)
	func _write(candidate: String, raw: String) -> Error:
		if candidate == fail_write_path:
			last_error = ERR_FILE_CANT_WRITE
			return last_error
		return super._write(candidate, raw)

func _initialize() -> void:
	sandbox = OS.get_environment("RUNE_ACCOUNT_TEST_ROOT").path_join("durable")
	if OS.get_environment("RUNE_ACCOUNT_TEST_ROOT").is_empty():
		push_error("RUNE_ACCOUNT_TEST_ROOT must name an isolated directory")
		quit(2)
		return
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func _put(path: String, raw: String) -> void:
	check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "Create isolated fixture directory")
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open isolated fixture")
	if file != null:
		file.store_string(raw)
		file.close()

func _record(label: String) -> FaultRecord:
	return FaultRecord.new(sandbox.path_join(label).path_join("record.json"))

func _seed(label: String, sidecars: bool = false) -> FaultRecord:
	var record := _record(label)
	_put(record.path, '{"id":"B"}')
	_put(record.backup_path, '{"id":"A"}')
	if sidecars:
		for candidate in [record.path, record.backup_path]:
			_put(candidate + ".tmp", '{"id":"pending"}')
			_put(candidate + ".replace", '{"id":"replaced"}')
	return record

func _snapshot(record: FaultRecord) -> Dictionary:
	var files := {}
	for candidate in [record.path, record.backup_path]:
		for suffix in ["", ".tmp", ".replace"]:
			var path: String = candidate + suffix
			files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return files

func _expect_io(record: FaultRecord, write: bool, label: String) -> void:
	var before := _snapshot(record)
	if write:
		check(record.save_record({"id": "C"}) == ERR_FILE_CANT_READ, label + " save propagates I/O error")
	else:
		var result := record.load_record()
		check(not result.ok and result.get("code") == "RECORD_IO_ERROR", label + " load fails closed")
	check(record.last_error == ERR_FILE_CANT_READ, label + " retains I/O error")
	check(_snapshot(record) == before, label + " preserves all record/sidecar bytes")

func _read_failures() -> void:
	for write in [false, true]:
		for index in 6:
			var record := _seed("read-%s-%s" % [write, index], true)
			var candidate := record.path if index < 3 else record.backup_path
			record.unreadable_path = candidate + ["", ".tmp", ".replace"][index % 3]
			_expect_io(record, write, "Unreadable path %s/%s" % [write, index])
		# Simulate an inaccessible parent: file_exists() is false, but open fails.
		var inaccessible := _record("inaccessible-%s/missing-parent" % write)
		inaccessible.unreadable_path = inaccessible.path
		_expect_io(inaccessible, write, "Inaccessible parent %s" % write)
		# No recovery mutation may occur before discovering a backup I/O error.
		var pending := _record("pending-backup-error-%s" % write)
		_put(pending.path + ".tmp", '{"id":"B"}')
		_put(pending.backup_path, '{"id":"A"}')
		pending.unreadable_path = pending.backup_path
		_expect_io(pending, write, "Pending recovery with unreadable backup %s" % write)
		for index in 3:
			var record := _seed("short-read-%s-%s" % [write, index])
			record.broken_read_path = record.path
			record.broken_read = BrokenRead.new()
			record.broken_read.extra_length = 1 if index < 2 else 0
			record.broken_read.error = [OK, ERR_FILE_EOF, ERR_FILE_CANT_READ][index]
			_expect_io(record, write, "Incomplete/failed read %s/%s" % [write, index])
		# Also check errors from the final record read after successful preflight.
		var changed := _seed("read-after-recovery-%s" % write)
		changed.unreadable_path = changed.path
		changed.fail_open_at = 2
		_expect_io(changed, write, "Read error after preflight %s" % write)
		var recovered := _record("recovery-then-read-error-%s" % write)
		_put(recovered.path + ".tmp", '{"id":"B"}')
		_put(recovered.backup_path, '{"id":"A"}')
		recovered.unreadable_path = recovered.path
		recovered.fail_open_at = 2
		if write:
			check(recovered.save_record({"id": "C"}) == ERR_FILE_CANT_READ, "Save read failure after valid recovery propagates")
		else:
			var failed := recovered.load_record()
			check(not failed.ok and failed.code == "RECORD_IO_ERROR", "Load read failure after valid recovery propagates")
		check(FileAccess.get_file_as_string(recovered.path) == '{"id":"B"}' and FileAccess.get_file_as_string(recovered.backup_path) == '{"id":"A"}', "Later read failure retains recovered current bytes and old backup")
	var retry := _seed("retry-after-io")
	retry.unreadable_path = retry.path
	_expect_io(retry, false, "Retry initial fault")
	retry.unreadable_path = ""
	check(retry.load_record().value == {"id": "B"} and retry.last_error == OK, "Readable retry clears earlier load error")
	check(retry.save_record({"id": "C"}) == OK and retry.last_error == OK, "Readable retry can save without stale error")
	var eof := _seed("complete-eof")
	eof.broken_read_path = eof.path
	eof.broken_read = BrokenRead.new()
	eof.broken_read.error = ERR_FILE_EOF
	check(eof.load_record().value == {"id": "B"} and eof.last_error == OK, "EOF after a complete read remains valid")

func _recovery_cases() -> void:
	var fresh := _record("fresh")
	var missing := fresh.load_record()
	check(missing.ok and missing.value == null and fresh.last_error == OK, "Missing is an empty record, not I/O/corruption")
	check(fresh.save_record({"id": "A"}) == OK and fresh.save_record({"id": "B"}) == OK, "New records save and rotate")
	var before := _snapshot(fresh)
	check(fresh.save_record({"id": "B"}) == OK and _snapshot(fresh) == before, "Identical save preserves backup")
	check(fresh.load_record().value == {"id": "B"}, "Valid primary wins over backup")
	_put(fresh.path, "invalid-json")
	check(fresh.load_record().value == {"id": "A"}, "Corrupt primary recovers valid backup")
	check(FileAccess.get_file_as_string(fresh.path) == '{"id":"A"}', "Backup restoration preserves exact bytes")
	_put(fresh.path, "invalid-json")
	_put(fresh.backup_path, "invalid-json")
	var corrupt := fresh.load_record()
	check(not corrupt.ok and corrupt.code == "RECORD_CORRUPT" and fresh.last_error == OK, "Corruption is distinct from I/O failure")
	var backup_only := _record("backup-only")
	_put(backup_only.backup_path, ' {"id":"A"} ')
	check(backup_only.load_record().value == {"id": "A"} and FileAccess.get_file_as_string(backup_only.path) == ' {"id":"A"} ', "Missing primary restores exact backup bytes")
	var temporary := _record("temporary")
	_put(temporary.path + ".tmp", '{"id":"B"}')
	check(temporary.load_record().value == {"id": "B"} and not FileAccess.file_exists(temporary.path + ".tmp"), "Valid interrupted temp recovers")
	var replaced := _record("replaced")
	_put(replaced.path + ".replace", '{"id":"A"}')
	_put(replaced.path + ".tmp", '{"id":"B"}')
	check(replaced.load_record().value == {"id": "A"} and not FileAccess.file_exists(replaced.path + ".tmp") and not FileAccess.file_exists(replaced.path + ".replace"), "Replace rollback precedes temp and cleans sidecars")
	var installed := _seed("installed", true)
	check(installed.load_record().value == {"id": "B"} and not FileAccess.file_exists(installed.path + ".tmp") and not FileAccess.file_exists(installed.path + ".replace"), "Readable installed record cleans interrupted sidecars")
	check(FileAccess.file_exists(installed.backup_path + ".tmp") and FileAccess.file_exists(installed.backup_path + ".replace"), "Valid primary does not eagerly recover or clean unused backup")
	var invalid_tmp := _record("invalid-temp")
	_put(invalid_tmp.path + ".tmp", "incomplete-json")
	var invalid := invalid_tmp.load_record()
	check(not invalid.ok and invalid.code == "RECORD_CORRUPT" and not FileAccess.file_exists(invalid_tmp.path), "Invalid interrupted temp is not promoted")
	var validated := Durable.new(sandbox.path_join("validator/record.json"), func(value): return value.get("id") is String)
	_put(validated.path, '{"id":1}')
	_put(validated.backup_path, '{"id":"A"}')
	check(validated.load_record().value == {"id": "A"}, "Validator corruption retains backup recovery")
	check(validated.save_record({"id": 1}) == ERR_INVALID_DATA and validated.last_error == ERR_INVALID_DATA, "Invalid save records its error")

func _write_failures() -> void:
	var backup_failure := _seed("backup-write-failure")
	var before := _snapshot(backup_failure)
	backup_failure.fail_write_path = backup_failure.backup_path
	check(backup_failure.save_record({"id": "C"}) == ERR_FILE_CANT_WRITE and backup_failure.last_error == ERR_FILE_CANT_WRITE, "Backup write failure propagates")
	check(_snapshot(backup_failure) == before, "Backup write failure preserves both records")
	var primary_failure := _seed("primary-write-failure")
	primary_failure.fail_write_path = primary_failure.path
	check(primary_failure.save_record({"id": "C"}) == ERR_FILE_CANT_WRITE, "Primary write failure propagates")
	check(FileAccess.get_file_as_string(primary_failure.path) == '{"id":"B"}' and FileAccess.get_file_as_string(primary_failure.backup_path) == '{"id":"B"}', "Primary write failure retains latest valid bytes")
	var restore_failure := _seed("restore-write-failure")
	_put(restore_failure.path, "corrupt")
	before = _snapshot(restore_failure)
	restore_failure.fail_write_path = restore_failure.path
	var result := restore_failure.load_record()
	check(not result.ok and result.code == "RECORD_IO_ERROR" and restore_failure.last_error == ERR_FILE_CANT_WRITE, "Backup restoration write failure propagates")
	check(_snapshot(restore_failure) == before, "Failed backup restoration preserves records")

func _run() -> void:
	_read_failures()
	_recovery_cases()
	_write_failures()
	if failures.is_empty(): print("PASS: durable record I/O, corruption, recovery and write errors checks=", checks)
	else: print("FAIL: ", failures)
	quit(0 if failures.is_empty() else 1)
