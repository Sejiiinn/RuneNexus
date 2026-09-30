extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Format = preload("res://content/runtime_content_format.gd")
const TypedJson = preload("res://app/save_json.gd")
var checks := 0
var failures := []

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void:
	var raw: Dictionary = TypedJson.parse(FileAccess.get_file_as_string("res://content/game_content.json"))
	_check(Format.validate(raw).is_empty(), "compiled runtime format accepted")
	var catalog = Catalog.new()
	_check(catalog.load_catalog(), "catalog loads compact format")
	var snapshot := catalog.domain_snapshot()
	_check(snapshot.schemaVersion == 1 and not snapshot.has("spawnSchedules"), "snapshot exposes expanded domain")
	var expected_wave: Dictionary = snapshot.stages[0].waves[0].duplicate(true)
	_check(catalog.wave_definition(0, 0) == expected_wave, "wave restores exact metadata/queue/durability")
	var summary := catalog.wave_summary(0, 0)
	_check(summary.spawnCount == expected_wave.spawnQueue.size(), "summary count")
	var counts := {}
	for spawn in expected_wave.spawnQueue: counts[spawn.enemyType] = int(counts.get(spawn.enemyType, 0)) + 1
	_check(summary.enemyCounts == counts, "summary enemy counts/order")
	var wave := catalog.wave_definition(0, 0)
	wave.spawnQueue[0].enemyType = "caller"
	wave.enemyDurability.normal.maxHp = 0.0
	wave.groups[0].enemyType = "caller"
	_check(catalog.wave_definition(0, 0) == expected_wave, "domain wave owns nested containers")
	var map := catalog.stage_map(0)
	map.path[0][0] = -99
	map.tiles[0] = "caller"
	_check(catalog.stage_map(0).path == snapshot.stages[0].map.path, "map owns nested coordinates")
	var definition := catalog.enemy_definition("normal")
	definition.maxHp = 0.0
	_check(catalog.enemy_definition("normal") == snapshot.enemyDefinitions.normal, "enemy definition owned")
	var template := catalog.enemy_template("normal")
	template.burnInstances.append({"caller": true})
	_check(catalog.enemy_template("normal") == snapshot.enemies.normal, "enemy template nested ownership")
	var turret := catalog.turret_definition("arrow")
	turret.damage = 0.0
	_check(catalog.turret_definition("arrow") == snapshot.turrets.arrow.configuration.statInput.definition, "turret definition owned")
	var rules := catalog.randomization()
	rules.laneOffsetAmplitudes.normal = 0.0
	_check(catalog.randomization() == snapshot.randomization, "randomization owned")
	summary.enemyCounts.clear()
	_check(catalog.wave_summary(0, 0).enemyCounts == counts, "summary nested ownership")
	var old_revision := catalog.content_revision()
	_check(catalog.load_fixture_content(snapshot), "fixture loader accepts expanded snapshot")
	_check(catalog.content_revision() == old_revision + 1, "fixture load revises cache identity")
	snapshot.stages[0].waves[0].spawnQueue[0].delay = 99.0
	_check(catalog.wave_definition(0, 0) == expected_wave, "fixture input owns copy")
	# Identical shared schedules in other waves stay independent at the domain boundary.
	for si in range(raw.stages.size()):
		for wi in range(raw.stages[si].waves.size()):
			var compact: Dictionary = raw.stages[si].waves[wi]
			_check(not compact.has("spawnQueue"), "wire wave remains compact")
			var restored := catalog.wave_definition(si, wi)
			_check(restored.enemyDurability.size() == catalog.enemy_types().size(), "all enemy durability columns restore")
	var invalids := []
	var item := raw.duplicate(true)
	item.schemaVersion = 2.0
	invalids.append(item)
	item = raw.duplicate(true)
	item.runtimeFormat.spawnColumns.reverse()
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].waves[0].spawnSchedule = "schedule_" + "0".repeat(64)
	invalids.append(item)
	var schedule: String = raw.stages[0].waves[0].spawnSchedule
	item = raw.duplicate(true)
	item.spawnSchedules[schedule][0][1] = 0
	invalids.append(item)
	item = raw.duplicate(true)
	item.spawnSchedules[schedule][0][0] = "missing"
	invalids.append(item)
	item = raw.duplicate(true)
	item.spawnSchedules[schedule][0].append(0.0)
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].waves[0].enemyDurability.normal[0] = 1
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].waves[0].enemyDurability.normal[0] = NAN
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].waves[0].enemyDurability.erase("normal")
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].waves[0].enemyDurability.normal.append(0.0)
	invalids.append(item)
	item = raw.duplicate(true)
	item.spawnSchedules[schedule][0][1] = -0.01
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].waves[0].round = 2
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].waves[0].clearRewardGold = 0.0
	invalids.append(item)
	item = raw.duplicate(true)
	item.stages[0].name = 1
	invalids.append(item)
	item = raw.duplicate(true)
	item.unexpected = true
	invalids.append(item)
	for invalid in invalids: _check(not Format.validate(invalid).is_empty(), "malformed compact rows/reference/header rejected")
	var bad_fixture := catalog.domain_snapshot()
	bad_fixture.stages[0].waves[0].spawnQueue[0].delay = -1.0
	old_revision = catalog.content_revision()
	_check(not catalog.load_fixture_content(bad_fixture) and not catalog.is_loaded() and not catalog.error.is_empty(), "failed load leaves unloaded catalog with error")
	_check(catalog.content_revision() == old_revision + 1, "failed load revises cache identity")
	_check(catalog.wave(0, 0).is_empty() and catalog.stage_count() == 0, "unloaded methods reject without materializing")
	_check(catalog.load_catalog() and catalog.is_loaded(), "recover valid load after malformed load")
	_check(catalog.wave_summary(0, -1).is_empty() and catalog.wave_durability(0, 0, "missing").is_empty(), "accessor index/type errors")
	if failures.is_empty():
		print("PASS runtime content format: ", checks, " checks; compact validation, domain contracts, ownership and failed-load recovery")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
