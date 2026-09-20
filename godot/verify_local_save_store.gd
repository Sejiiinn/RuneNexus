extends SceneTree
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
const Codec = preload("res://app/save_codec.gd")
const WebStore = preload("res://app/web_save_store.gd")
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
	var store := Store.new(test_directory)
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
	store.save_save(b)
	check(JSON.parse_string(FileAccess.get_file_as_string(store.backup_path)).savedAtMillis == 1, "identical save preserves backup")
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
