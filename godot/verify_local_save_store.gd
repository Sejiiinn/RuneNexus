extends SceneTree
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const Codec = preload("res://app/save_codec.gd")
const WebStore = preload("res://app/web_save_store.gd")
class CountingStore extends Store:
	var writes := 0
	var reads := 0
	func _read_text(path: String) -> Variant:
		reads += 1
		return super._read_text(path)
	func _write_atomic(path: String, contents: String) -> Error:
		writes += 1
		return super._write_atomic(path, contents)
class ReadFile extends RefCounted:
	var bytes: PackedByteArray
	var length: int
	var error: Error
	var closed := false
	func get_length() -> int:
		return length
	func get_buffer(_length: int) -> PackedByteArray:
		return bytes
	func get_error() -> Error:
		return error
	func close() -> void:
		closed = true
class ReadFaultStore extends CountingStore:
	var fault_path: String
	var read_file: ReadFile
	func _open_read(path: String):
		return read_file if path == fault_path else super._open_read(path)
var failures: Array[String] = []
var checks := 0
var test_directory: String

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func write(path: String, raw: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(raw)
	file.close()

func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child in directory.get_directories():
		remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)

func verify_read_failure(store: CountingStore, a: Dictionary, b: Dictionary, expected_error: Error, label: String) -> void:
	var writes := store.writes
	check(store.load_save() == null and store.last_error == expected_error and not store.last_error_message.is_empty(), label + " load reports I/O error")
	check(store.save_save(b) == expected_error, label + " save stops before replacement")
	check(store.preserve_current_as_backup() == expected_error, label + " backup stops before replacement")
	check(store.writes == writes, label + " no writes after failed read")
	check(FileAccess.get_file_as_string(store.backup_path) == JSON.stringify(a), label + " backup bytes retained")

func verify_read_errors(a: Dictionary, b: Dictionary) -> void:
	var store := ReadFaultStore.new(test_directory.path_join("read-errors"))
	var raw := JSON.stringify(a)
	write(store.primary_path, raw)
	write(store.backup_path, raw)
	store.fault_path = store.primary_path
	store.read_file = ReadFile.new()
	store.read_file.bytes = raw.to_utf8_buffer()
	store.read_file.length = store.read_file.bytes.size()
	store.read_file.error = ERR_FILE_CANT_READ
	verify_read_failure(store, a, b, ERR_FILE_CANT_READ, "read failure")
	check(store.read_file.closed and FileAccess.get_file_as_string(store.primary_path) == raw, "failed read closes handle and preserves primary")
	store.read_file.error = ERR_FILE_EOF
	check(store.load_save() == a and store.last_error == OK, "complete read with EOF succeeds")
	store.read_file.bytes = raw.left(5).to_utf8_buffer()
	verify_read_failure(store, a, b, ERR_FILE_CANT_READ, "short read with EOF")
	store.read_file.error = OK
	verify_read_failure(store, a, b, ERR_FILE_CANT_READ, "short read without engine error")
	# The same reader also protects fallback, imports, conflict files, and pending writes.
	store.read_file.error = ERR_FILE_CANT_READ
	store.fault_path = store.backup_path
	write(store.primary_path, "{broken")
	check(store.load_save() == null and store.last_error == ERR_FILE_CANT_READ and store.writes == 0, "backup read failure cannot repair primary")
	check(FileAccess.get_file_as_string(store.primary_path) == "{broken" and FileAccess.get_file_as_string(store.backup_path) == raw, "backup read failure retains both files")
	store.legacy_path = test_directory.path_join("read-errors-legacy.json")
	write(store.legacy_path, JSON.stringify({"version":1,"stageNumber":3}))
	store.clear()
	write(store.legacy_path, JSON.stringify({"version":1,"stageNumber":3}))
	store.fault_path = store.legacy_path
	check(store.load_save() == null and store.last_error == ERR_FILE_CANT_READ and not FileAccess.file_exists(store.primary_path), "legacy read failure cannot import")
	var conflict := {"version":1,"rebaseId":"r1","data":a}
	write(store.conflict_path, JSON.stringify(conflict))
	store.fault_path = store.conflict_path
	check(store.preserve_conflict_backup({"version":1,"rebaseId":"r2","data":b}) == ERR_FILE_CANT_READ and FileAccess.get_file_as_string(store.conflict_path) == JSON.stringify(conflict), "conflict read failure cannot replace backup")
	for path in [store.primary_path, store.backup_path, store.conflict_path]:
		store.clear()
		write(path + ".tmp", raw)
		store.fault_path = path + ".tmp"
		var result: Variant = store.preserve_conflict_backup(conflict) if path == store.conflict_path else store.load_save()
		check((result == ERR_FILE_CANT_READ if path == store.conflict_path else result == null) and store.last_error == ERR_FILE_CANT_READ, "pending read failure reported: " + path.get_file())
		check(not FileAccess.file_exists(path) and FileAccess.get_file_as_string(path + ".tmp") == raw and store.writes == 0, "pending read failure retains artifact: " + path.get_file())
	store.clear()
	write(store.primary_path, "")
	store.fault_path = ""
	check(store.load_save() == null and store.last_error == OK, "empty file is invalid data without I/O failure")
	if OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "Android"]:
		verify_open_errors(a, b)

func verify_open_errors(a: Dictionary, b: Dictionary) -> void:
	var store := CountingStore.new(test_directory.path_join("open-errors"))
	var raw := JSON.stringify(a)
	write(store.primary_path, raw)
	write(store.backup_path, raw)
	check(FileAccess.set_unix_permissions(store.primary_path, 0) == OK, "remove primary read permission")
	var probe := FileAccess.open(store.primary_path, FileAccess.READ)
	check(probe == null, "fixture actually denies open")
	var open_error := FileAccess.get_open_error()
	if probe != null:
		probe.close()
	else:
		verify_read_failure(store, a, b, open_error, "open failure")
	check(FileAccess.set_unix_permissions(store.primary_path, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER) == OK, "restore primary permission")
	check(FileAccess.get_file_as_string(store.primary_path) == raw, "open failure preserves primary bytes")
	for path in [store.backup_path, store.conflict_path, test_directory.path_join("open-errors-legacy.json"), store.primary_path + ".tmp"]:
		store.clear()
		store.legacy_path = ""
		write(path, raw)
		if path == store.backup_path:
			write(store.primary_path, "{broken")
		elif path != store.conflict_path and path != store.primary_path + ".tmp":
			store.legacy_path = path
		check(FileAccess.set_unix_permissions(path, 0) == OK, "remove read permission: " + path.get_file())
		var result: Variant = store.preserve_conflict_backup({"version":1,"rebaseId":"open","data":b}) if path == store.conflict_path else store.load_save()
		check((result != OK if path == store.conflict_path else result == null) and store.last_error != OK and not store.last_error_message.is_empty(), "open failure propagates: " + path.get_file())
		check(store.writes == 0, "open failure prevents writes: " + path.get_file())
		check(FileAccess.set_unix_permissions(path, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER) == OK, "restore read permission: " + path.get_file())
		check(FileAccess.get_file_as_string(path) == raw, "open failure retains bytes: " + path.get_file())
		if path == store.backup_path:
			check(FileAccess.get_file_as_string(store.primary_path) == "{broken", "backup open failure does not repair primary")
		elif path == store.primary_path + ".tmp":
			check(not FileAccess.file_exists(store.primary_path), "temporary open failure does not promote")
	store.clear()
	store.legacy_path = ""
	write(store.primary_path, raw)
	write(store.backup_path, raw)
	var directory := store.primary_path.get_base_dir()
	check(FileAccess.set_unix_permissions(directory, 0) == OK, "remove save directory access")
	check(store.load_save() == null and store.last_error != OK, "inaccessible directory is an I/O error rather than missing save")
	check(store.save_save(b) != OK and store.writes == 0, "inaccessible directory prevents replacement")
	check(FileAccess.set_unix_permissions(directory, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER) == OK, "restore save directory access")
	check(FileAccess.get_file_as_string(store.primary_path) == raw and FileAccess.get_file_as_string(store.backup_path) == raw, "directory access failure retains both files")
	store.clear()

func verify_validated_bytes(a: Dictionary, b: Dictionary) -> void:
	var store := CountingStore.new(test_directory.path_join("validated-bytes"))
	write(store.primary_path, "")
	write(store.backup_path, JSON.stringify(b))
	check(store.save_save(a) == OK and FileAccess.get_file_as_string(store.backup_path) == JSON.stringify(b), "empty primary is invalid before any validation fact")
	var reads: int = store.reads
	var writes: int = store.writes
	check(store.save_save(a) == OK and store.reads > reads and store.writes == writes, "validated identical bytes still require a complete file read")
	# Same-length external replacement must rotate its actual bytes, even after
	# the requested payload has already been successfully written by this store.
	var replacement := JSON.stringify(b,"",false,true)
	write(store.primary_path,replacement)
	check(store.save_save(a) == OK and FileAccess.get_file_as_string(store.backup_path) == replacement, "same-length external replacement overrides validation reuse")
	var mutated := a.duplicate(true)
	check(store.save_save(mutated) == OK,"owned input fixture saved")
	mutated.progression.runes = 123
	check(store.save_save(mutated) == OK and store.load_save().progression.runes == 123,"later caller mutation cannot alter immutable validated bytes")
	check(FileAccess.get_file_as_string(store.backup_path) == JSON.stringify(a,"",false,true),"caller mutation keeps previous exact backup")
	write(store.primary_path,"{broken")
	check(Store.new(test_directory.path_join("validated-bytes")).save_save(b) == OK and FileAccess.get_file_as_string(store.backup_path) == JSON.stringify(a,"",false,true),"fresh store cannot certify another instance's corrupt primary")
	var edge: Dictionary = Codec.decode({"version":2,"savedAtMillis":9223372036854775807,"preferences":{},"progression":{"runes":9223372036854775807,"claimedEventIds":["__rune_save_int__0","한글\\\"\n"]},"turretModules":{},"activeRun":{"nexusHp":1e40,"killGoldFractionWallet":1e20}})
	check(store.save_save(edge) == OK and store.save_save(edge) == OK,"typed writer certifies int64, large floating numbers and escaped strings")
	check(Store.new(test_directory.path_join("validated-bytes")).load_save() == edge,"certified writer bytes also pass a fresh strict parser")
	store.clear()
	var fault := ReadFaultStore.new(test_directory.path_join("validated-read-fault"))
	check(fault.save_save(a) == OK,"warm read failure fixture")
	fault.fault_path = fault.primary_path
	fault.read_file = ReadFile.new()
	fault.read_file.bytes = JSON.stringify(a,"",false,true).to_utf8_buffer()
	fault.read_file.length = fault.read_file.bytes.size()
	fault.read_file.error = ERR_FILE_CANT_READ
	writes = fault.writes
	check(fault.save_save(a) == ERR_FILE_CANT_READ and fault.writes == writes,"cached identical content cannot hide a read error")
	fault.fault_path = ""
	fault.clear()

func _initialize() -> void:
	test_directory = OS.get_environment("TMPDIR").path_join("rune-nexus-save-store-test-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec()))
	if not test_directory.is_absolute_path():
		push_error("Isolated temporary directory required")
		quit(1)
		return
	var a: Dictionary = Codec.decode({"version":2,"savedAtMillis":1,"preferences":{},"progression":{},"turretModules":{},"activeRun":null})
	var b := a.duplicate(true)
	b.savedAtMillis = 2
	var c := a.duplicate(true)
	c.savedAtMillis = 3
	verify_read_errors(a, b)
	verify_validated_bytes(a, b)
	var store := CountingStore.new(test_directory)
	check(store.primary_path == test_directory.path_join("saves/guest/save_v2.json"), "guest path")
	check(store.load_save() == null and store.last_error == OK, "empty load")
	check(store.save_save(a) == OK and store.load_save() == a, "first save and load")
	var original_bytes := FileAccess.get_file_as_bytes(store.primary_path)
	for bad_value in [NAN, INF, -INF, Vector2(1,2)]:
		var invalid_save := a.duplicate(true)
		invalid_save.progression.runes = bad_value
		check(store.save_save(invalid_save) == ERR_INVALID_DATA, "unsupported numeric/object write rejected")
		check(FileAccess.get_file_as_bytes(store.primary_path) == original_bytes and not FileAccess.file_exists(store.backup_path), "invalid write leaves primary and backup unchanged")
	for bad_value in ["123", true, 1.5]:
		var invalid_save := a.duplicate(true)
		invalid_save.progression.runes = bad_value
		check(store.save_save(invalid_save) == ERR_INVALID_DATA, "integer field refuses changed runtime type")
		check(FileAccess.get_file_as_bytes(store.primary_path) == original_bytes and not FileAccess.file_exists(store.backup_path), "type mismatch cannot damage existing save")
	check(store.save_save(b) == OK, "second save")
	check(JSON.parse_string(FileAccess.get_file_as_string(store.backup_path)).savedAtMillis == 1, "backup previous save")
	var writes: int = store.writes
	store.save_save(b)
	check(store.writes == writes, "identical save skips primary and backup writes")
	check(JSON.parse_string(FileAccess.get_file_as_string(store.backup_path)).savedAtMillis == 1, "identical save preserves backup")
	# External replacement remains authoritative, even when this instance has
	# previously written the requested payload. Backup bytes are never normalized.
	var permissive := {"version":2,"savedAtMillis":"41","preferences":{},"progression":{"runes":"17"},"turretModules":{},"activeRun":null,"extra":"preserve"}
	var permissive_raw := JSON.stringify(permissive, "  ")
	write(store.primary_path, permissive_raw)
	check(store.save_save(b) == OK, "save revalidates external canonical replacement")
	check(FileAccess.get_file_as_string(store.backup_path) == permissive_raw, "backup preserves exact permissive canonical bytes")
	write(store.primary_path, "{broken")
	check(store.save_save(b) == OK and FileAccess.get_file_as_string(store.backup_path) == permissive_raw, "invalid external primary cannot rotate over valid backup")
	write(store.primary_path, JSON.stringify(a))
	check(store.save_save(b) == OK, "restore previous-save fixture")
	writes = store.writes
	write(store.primary_path + ".tmp", JSON.stringify(c))
	check(store.save_save(b) == OK and store.writes == writes and not FileAccess.file_exists(store.primary_path + ".tmp"), "identical save still recovers stale write artifacts")
	write(store.primary_path, "{broken")
	check(store.load_save() == a and store.last_error == OK, "corrupt primary recovers backup")
	check(JSON.parse_string(FileAccess.get_file_as_string(store.primary_path)).savedAtMillis == 1, "recovery repairs primary")
	store.clear()
	write(store.primary_path + ".tmp", JSON.stringify(b))
	check(store.load_save() == b, "valid temporary promoted")
	store.clear()
	write(store.primary_path + ".tmp", "{broken")
	check(store.load_save() == null, "invalid temporary ignored")
	store.clear()
	write(store.primary_path + ".replace", JSON.stringify(a))
	write(store.primary_path + ".tmp", JSON.stringify(b))
	check(store.load_save() == a, "displaced takes priority over temporary")
	check(not FileAccess.file_exists(store.primary_path + ".tmp"), "recovery removes stale temporary")
	write(store.primary_path + ".replace", JSON.stringify(b))
	write(store.primary_path + ".tmp", JSON.stringify(c))
	check(store.load_save() == a and not FileAccess.file_exists(store.primary_path + ".replace"), "existing destination wins")
	store.clear()
	write(store.primary_path, JSON.stringify({"version": 1}))
	check(store.load_save() == null, "primary rejects legacy envelope")
	write(store.backup_path, JSON.stringify(b))
	check(store.load_save() == b, "invalid envelope recovers backup")
	store.clear()
	write(store.backup_path + ".tmp", JSON.stringify(c))
	check(store.load_save() == c, "interrupted backup recovered then primary repaired")
	store.clear()
	write(store.primary_path + ".replace", "broken")
	write(store.primary_path + ".tmp", JSON.stringify(c))
	write(store.backup_path, JSON.stringify(b))
	check(store.load_save() == b, "invalid displaced primary falls back to backup")
	var legacy_path := test_directory.path_join("legacy/rune_nexus_save_v1.json")
	var legacy := Store.new(test_directory.path_join("import"), null, legacy_path)
	write(legacy_path, JSON.stringify({"version":1,"stageNumber":3}))
	var imported: Variant = legacy.load_save()
	check(imported != null and imported.version == 2 and imported.preferences.selectedStageNumber == 3, "legacy v1 imported")
	check(FileAccess.file_exists(legacy.primary_path) and FileAccess.file_exists(legacy_path), "legacy source retained after import")
	var no_v2_legacy := Store.new(test_directory.path_join("no-v2-legacy"), null, test_directory.path_join("v2-legacy.json"))
	write(no_v2_legacy.legacy_path, JSON.stringify(a))
	check(no_v2_legacy.load_save() == null, "legacy location rejects v2 envelope")
	var upper := "ABCDEF01-2345-6789-ABCD-0123456789AB"
	var account_slot = Slot.account(upper)
	check(account_slot.get_namespace() == "account:" + upper.to_lower(), "UUID normalization and namespace")
	check(Slot.account("../../guest") == null, "unsafe account path rejected")
	var account_store := Store.new(test_directory, account_slot, legacy_path)
	check(account_store.primary_path == test_directory.path_join("saves/accounts/" + upper.to_lower() + "/save_v2.json"), "account exact path")
	check(account_store.load_save() == null, "account cannot import guest legacy")
	account_store.save_save(c)
	store.clear()
	check(account_store.load_save() == c, "guest clear isolates account")
	account_store.preserve_current_as_backup()
	check(JSON.parse_string(FileAccess.get_file_as_string(account_store.backup_path)).savedAtMillis == 3, "preserve current")
	var conflict := {"version":1,"rebaseId":"r1","accountId":upper.to_lower(),"baseRevision":1,"targetRevision":2,"localPayloadHash":"fixture","createdAt":"2026-09-21T00:00:00.000Z","data":a}
	check(account_store.preserve_conflict_backup(conflict) == OK, "conflict backup")
	conflict.data = b
	account_store.preserve_conflict_backup(conflict)
	check(JSON.parse_string(FileAccess.get_file_as_string(account_store.conflict_path)).data.savedAtMillis == 1, "same rebase id is idempotent")
	conflict.rebaseId = "r2"
	account_store.preserve_conflict_backup(conflict)
	check(JSON.parse_string(FileAccess.get_file_as_string(account_store.conflict_path)).data.savedAtMillis == 2, "new rebase id replaces conflict")
	for path in [legacy.primary_path, legacy.backup_path, legacy.conflict_path, legacy_path]:
		for suffix in [".tmp", ".replace"]:
			write(path + suffix, "artifact")
	check(legacy.clear() == OK, "clear with artifacts")
	for path in [legacy.primary_path, legacy.backup_path, legacy.conflict_path, legacy_path]:
		for suffix in ["", ".tmp", ".replace"]:
			check(not FileAccess.file_exists(path + suffix), "clear removes " + path.get_file() + suffix)
	check(store.save_save({"version":3}) == ERR_INVALID_DATA, "reject unsupported writes")
	write(test_directory.path_join("blocked"), "not a directory")
	var blocked := Store.new(test_directory.path_join("blocked"))
	check(blocked.save_save(a) != OK and not blocked.last_error_message.is_empty(), "I/O failure reported")
	var invalid_slot = Slot.guest()
	invalid_slot.account_id = "../unsafe"
	var invalid := Store.new(test_directory, invalid_slot)
	check(invalid.save_save(a) == ERR_INVALID_PARAMETER, "mutated invalid slot rejected")
	var web := WebStore.new()
	check(web.save_save(a) == ERR_UNAUTHORIZED, "web requires writer lock")
	remove_tree(test_directory)
	print(JSON.stringify({"suite":"local_save_store","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
