extends SceneTree
const Codec = preload("res://app/save_codec.gd")
const Adapter = preload("res://app/run_save_adapter.gd")
const SaveJson = preload("res://app/save_json.gd")
const Store = preload("res://app/local_save_store.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var large: int = 9007199254740993
	var raw := '{"savedAtMillis":9007199254740993,"min":-9223372036854775808,"max":9223372036854775807,"quoted":"9007199254740993","collision":"__rune_save_int__0","float":1.0,"escaped":"a\\\"9007199254740993"}'
	var parsed: Dictionary = SaveJson.parse(raw)
	check(parsed.savedAtMillis == large and parsed.savedAtMillis is int, "large int is exact")
	check(parsed.min == -9223372036854775807 - 1 and parsed.max == 9223372036854775807, "int64 limits exact")
	check(parsed.quoted == "9007199254740993" and parsed.collision == "__rune_save_int__0", "strings cannot alias integer markers")
	check(parsed.escaped == 'a"9007199254740993' and parsed.float is float, "escapes and float type preserved")
	for invalid in ['{"n":9223372036854775808}', '{"n":-9223372036854775809}', '{"n":01}', '{"n":--1}', '{"n":1x}', '{"n":1e99999}', '{"n":-1e99999}']:
		check(not SaveJson.parse_record(invalid).ok, "invalid/range JSON rejected: " + invalid)
	check(SaveJson.parse('{"n":9007199254740993,"s":"\\u005f_rune_save_int__0"}').s == "__rune_save_int__0", "escaped marker cannot become a number")
	check(SaveJson.parse_record('null').ok, "valid null distinct from parsing error")
	var envelope: Dictionary = Codec.decode({"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":{"phase":"wave","gold":321,"gemShards":7,"economyRunId":"synthetic-run","pendingEconomyDiamonds":3,"rewardOptions":["physicalDamage"],"runUpgradeLevels":{"towerDamage":2}}})
	var before := envelope.duplicate(true)
	var snapshot := {"session":{"phase":"wave"}, "defense":{"hp":8.0,"roundHpLost":2.0,"finalDefenseUsedThisRound":true,"emergencyChargeUsedThisRound":false},"wave":{"spawnQueue":[{"enemyType":"normal","delay":0.25}]},"enemies":[{"type":"normal","hp":80.0,"maxHp":100.0,"distanceTravelled":9.5,"burnInstances":[{"remaining":2.0,"damagePerSecond":4.0,"sourceX":3,"sourceY":4}],"slowInstances":[{"remaining":1.0,"multiplier":0.7}]}],"turrets":[{"id":8,"cooldown":0.5,"directDamageDealt":10.0,"splashDamageDealt":2.0,"chainDamageDealt":3.0,"burnDamageDealt":4.0}],"events":[],"core":{"directDamageDealt":5.0,"bonusDamageDealt":6.0,"activationCount":7}}
	var templates := {"8":{"type":"cannon","x":3,"y":4,"level":5,"investedGold":987,"equippedGems":["physicalDamage"],"equippedGemSlots":[null,"physicalDamage"],"slotLimit":2}}
	var saved: Dictionary = Adapter.capture(envelope, snapshot, templates, large)
	check(envelope == before, "capture cannot mutate app envelope")
	check(saved.activeRun.gold == 321 and saved.activeRun.gemShards == 7 and saved.activeRun.pendingEconomyDiamonds == 3 and saved.activeRun.economyRunId == "synthetic-run", "economy fields untouched")
	check(saved.progression == before.progression and saved.turretModules == before.turretModules, "progression and module inventory untouched")
	check(saved.activeRun.nexusHp == 8 and saved.activeRun.finalDefenseUsedThisRound, "core checkpoint")
	check(saved.activeRun.turrets[0].damageDealt == 19 and saved.activeRun.turrets[0].cooldown == 0.5 and saved.activeRun.turrets[0].investedGold == 987, "turret runtime and original invested cost")
	check(saved.activeRun.turrets[0].equippedGemSlots == [null, "physicalDamage"] and saved.activeRun.rewardOptions == ["physicalDamage"], "gem slot holes and reward options preserved")
	check(saved.activeRun.enemies[0].distanceTravelled == 9.5 and saved.activeRun.enemies[0].burnInstances[0].sourceX == 3 and saved.activeRun.enemies[0].slowInstances.size() == 1, "enemy distance and status preserved")
	check(saved.activeRun.spawnQueue[0].delay == 0.25 and not saved.activeRun.has("projectiles"), "remaining spawn delay and no new projectile schema")
	check(saved.activeRun.runCoreCombatSkillStats.activationCount == 7, "core stats refreshed")
	check(Adapter.capture(envelope, snapshot, {}, 1) == null, "missing turret configuration refused")
	snapshot.events = [{"kind":"kill"}]
	check(Adapter.capture(envelope, snapshot, templates, 1) == null, "unsettled events refused")
	snapshot.events.clear()
	snapshot.session.phase = "coreDestruction"
	check(Adapter.capture(envelope, snapshot, templates, 1).activeRun.phase == "failure", "destruction saves settled failure")
	check(Adapter.map_signature({"columns":2,"rows":1,"tiles":["path","build"]},[[0.5,0.5],[1.5,0.5]]) == "2x1|path,build,/|0,0;1,0;", "map signature same Dart format")
	var directory: String = OS.get_environment("TMPDIR").path_join("rune-json-test-" + str(OS.get_process_id()))
	if not directory.is_absolute_path():
		failures.append("isolated directory required")
	else:
		var store = Store.new(directory)
		check(store.save_save(saved) == OK, "int64 save writes")
		var restored = Store.new(directory).load_save()
		check(restored != null and restored.savedAtMillis == large, "new repository reload preserves int64")
		store.clear()
		DirAccess.remove_absolute(directory.path_join("saves/guest"))
		DirAccess.remove_absolute(directory.path_join("saves"))
		DirAccess.remove_absolute(directory)
	print("SAVE_RUN_ADAPTER checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
