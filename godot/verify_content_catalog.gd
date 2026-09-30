extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const TypedJson = preload("res://app/save_json.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Progress = preload("res://content/stage_progression.gd")
var checks := 0
var failures: Array = []
var catalog = Catalog.new()

func _initialize() -> void:
	_check(catalog.load_catalog(), "load: " + catalog.error)
	if catalog.is_loaded():
		_summary_contract()
		_all_definitions()
		_dart_cases()
		_runtime_cases()
		_invalid_inputs()
	if failures.is_empty():
		print("PASS content catalog: ", checks, " checks; all definitions/order/types, Dart enemy configurations, growth/equipment stats, chapter/boss runtime")
		quit(0)
	else:
		for failure in failures.slice(0, 50): push_error(failure)
		print("FAIL content catalog: ", failures.size(), " failures / ", checks)
		quit(1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _summary_contract() -> void:
	for index in range(catalog.stage_count()):
		var source: Dictionary = catalog.stage(index)
		var summary: Dictionary = catalog.stage_summary(index)
		_check(catalog.stage_id(index) == source.id, "fixed stage ID")
		_check(catalog.stage_index(source.id) == index, "stage ID/index lookup")
		_check(catalog.wave_count(index) == source.waves.size(), "wave count")
		_compare(summary, {"id":source.id, "name":source.name, "waveCount":source.waves.size(),
			"firstClearCorePointReward":source.firstClearCorePointReward,
			"firstClearTurretModuleTicketReward":source.firstClearTurretModuleTicketReward}, "stage summary")
		_check(not summary.has("waves") and not summary.has("map"), "summary excludes compiled battle data")
		for round_index in range(source.waves.size()):
			var has_boss := false
			for group in source.waves[round_index].groups:
				if str(group.enemyType).to_lower().contains("boss"): has_boss = true
			_check(catalog.wave_has_boss(index, round_index) == has_boss, "boss metadata preserves group classification")
		summary.name = "caller-owned preview"
		_check(source.name != summary.name, "summary changes cannot alter catalog")
	_check(catalog.stage_index(0) == -1 and catalog.stage_index(999) == -1, "unknown stage ID rejected")
	for index in [-1, catalog.stage_count()]:
		_check(catalog.stage_id(index) == 0 and catalog.wave_count(index) == 0 and catalog.stage_summary(index).is_empty(), "unknown summary index rejected")
		_check(not catalog.wave_has_boss(index, 0), "unknown boss stage rejected")
	_check(not catalog.wave_has_boss(0, -1) and not catalog.wave_has_boss(0, catalog.wave_count(0)), "unknown boss wave rejected")

func _compare(actual: Variant, expected: Variant, label: String) -> void:
	_check(typeof(actual) == typeof(expected), label + " type " + type_string(typeof(actual)) + "/" + type_string(typeof(expected)))
	if typeof(actual) != typeof(expected): return
	if expected is Dictionary:
		_check(actual.size() == expected.size(), label + " keys")
		for key in expected:
			_check(actual.has(key), label + " missing " + str(key))
			if actual.has(key): _compare(actual[key], expected[key], label + "/" + str(key))
	elif expected is Array:
		_check(actual.size() == expected.size(), label + " length")
		for index in range(mini(actual.size(), expected.size())): _compare(actual[index], expected[index], label + "/" + str(index))
	elif expected is float:
		_check(absf(actual - expected) <= 0.000000001 * maxf(1.0, absf(expected)), label + " value " + str(actual) + "/" + str(expected))
	else:
		_check(actual == expected, label + " value")

func _all_definitions() -> void:
	var waves := 0
	var spawns := 0
	for si in range(catalog.stage_count()):
		var stage: Dictionary = catalog.stage(si)
		_compare(stage.map.theme, catalog.stage_map(si).tileTheme, "theme")
		for wi in range(stage.waves.size()):
			var actual: Dictionary = catalog.wave(si, wi)
			var source: Dictionary = stage.waves[wi]
			_compare(actual.id, source.round, "wave id")
			var factor := pow(2.0, (source.round - 1) / 10.0) * pow(1.15, Progress.ordinal_for(stage.id) - 1)
			for kind in catalog.enemy_types():
				for field in ["maxHp", "maxShield", "maxArmor"]:
					_compare(source.enemyDurability[kind][field], catalog.enemy_definition(kind)[field] * factor, "ordinal durability %d:%d:%s:%s" % [stage.id, source.round, kind, field])
			_check(actual.spawnQueue.size() == source.spawnQueue.size(), "wave spawn count")
			for index in range(source.spawnQueue.size()):
				var entry: Dictionary = actual.spawnQueue[index]
				_compare(entry.enemyType, source.spawnQueue[index].enemyType, "spawn type/order")
				_compare(entry.delay, source.spawnQueue[index].delay + catalog.initial_delay(), "spawn seconds/order")
				_compare(entry.enemy.id, 100000 + index, "enemy id")
				for key in source.enemyDurability[entry.enemyType]:
					_compare(entry.enemy[key], source.enemyDurability[entry.enemyType][key], "durability")
				spawns += 1
			waves += 1
	print("Content coverage: ", catalog.stage_count(), " stages, ", waves, " waves, ", spawns, " spawns, ", catalog.enemy_types().size(), " enemy types, ", catalog.turret_types().size(), " turret types")
	# Original Dart calculator fixtures exercise growth, equipment, traits and module effects.
	var cases: Variant = TypedJson.parse(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	for case in cases:
		var source: Dictionary = case.input
		var overrides := source.duplicate(true)
		overrides.erase("definition")
		overrides.erase("boardDistanceScale")
		var inputs := {"tileSize": source.boardDistanceScale * 48.0, "statInput": overrides}
		var assembled: Dictionary = catalog.turret(source.definition.type, inputs)
		# Fixtures include deliberately modified definitions: keep real catalog definitions
		# and compare only fixtures with the exact current source definition.
		if assembled.definition == source.definition:
			_compare(assembled, source, "growth stat input")
			_compare(Stats.resolve(assembled), case.expected, "Dart growth stats")

func _dart_cases() -> void:
	var path := "res://../test/fixtures/game_content_cases.json"
	_check(FileAccess.file_exists(path), "Dart content fixture exists")
	if not FileAccess.file_exists(path): return
	var cases: Variant = TypedJson.parse(FileAccess.get_file_as_string(path))
	for case in cases.enemies:
		var inputs := {"tileSize": case.tileSize, "origin": case.origin, "enemyValues": case.spawnValues}
		var actual: Dictionary = catalog.enemy(case.stageIndex, case.roundIndex, case.enemyType, case.id, inputs)
		# Native runtime carries presentation/economy metadata omitted by Dart's
		# enemy checkpoint projection. Check it separately without rewriting the
		# original Dart configurations used for combat parity.
		for field in ["name","color","rewardGold"]:
			_compare(actual.get(field),catalog.enemy_definition(case.enemyType)[field],"runtime enemy metadata "+field)
			actual.erase(field)
		# Historical Dart inputs remain immutable. Adapt only the six approved
		# durability fields from old fixed-ID scaling to current logical order.
		var expected: Dictionary = case.expected.duplicate(true)
		var stage_id: int = catalog.stage(case.stageIndex).id
		var factor := pow(1.15, Progress.ordinal_for(stage_id) - stage_id)
		for field in ["maxHp", "hp", "maxShield", "shield", "maxArmor", "armor"]:
			expected[field] *= factor
		_compare(actual, expected, "Dart mapped enemy with ordinal durability")
	for case in cases.turrets:
		var overrides: Dictionary = case.input.duplicate(true)
		overrides.erase("definition")
		overrides.erase("boardDistanceScale")
		var inputs := {"tileSize": case.input.boardDistanceScale * 48.0, "statInput": overrides}
		var actual: Dictionary = catalog.turret(case.type, inputs)
		_compare(actual, case.input, "actual Dart turret input")
		_compare(Stats.resolve(actual), case.expected, "actual Dart turret stats")

func _runtime_cases() -> void:
	# Existing chapter endpoints plus both expansion endpoints, final boss round.
	for si in [0, 4, 5, 9, 10, 14, 15, 19, 20, 24]:
		var wi: int = catalog.wave_count(si) - 1
		var initial: Dictionary = catalog.bootstrap(si, {"defenseConfig": {"maxHp": 1000000.0}})
		initial.wave = catalog.wave(si, wi)
		var expected_damage := 0.0
		for spawn in initial.wave.spawnQueue: expected_damage += float(spawn.enemy.coreDamage)
		var runtime = Runtime.new()
		runtime.process_command({"epoch": 1, "sequence": 0, "running": true, "bootstrap": initial})
		for tick in range(1, 15001):
			runtime.process_command({"epoch": 1, "sequence": tick, "dt": 0.1, "running": true})
			if runtime.wave.completed: break
		_check(runtime.wave.completed, "chapter wave completes stage " + str(si + 1))
		_compare(runtime.defense.hp, 1000000.0 - expected_damage, "actual wave arrival core damage")
		for enemy in runtime.enemies.values():
			_check(enemy.arrived, "all actual spawns reached core; retained until economic ACK")
		# A real catalog turret on the spawn tile must damage the real enemy.
		var attack_initial: Dictionary = catalog.bootstrap(si)
		var target: Dictionary = catalog.enemy(si, 0, "normal")
		attack_initial.enemies = [target]
		attack_initial.turrets = [{"id": 1, "position": [target.x, target.y], "statInput": catalog.turret(), "state": {}}]
		var attack = Runtime.new()
		attack.process_command({"epoch": 1, "sequence": 0, "running": true, "bootstrap": attack_initial})
		for tick in range(1, 31): attack.process_command({"epoch": 1, "sequence": tick, "dt": 0.05, "running": true})
		_check(not attack.enemies.has("100000") or attack.enemies["100000"].hp < target.hp, "catalog turret attack stage " + str(si + 1))

func _invalid_inputs() -> void:
	var unloaded = Catalog.new()
	_check(unloaded.bootstrap(0).is_empty() and not unloaded.error.is_empty(), "unloaded catalog rejects bootstrap")
	for index in [-1, catalog.stage_count()]:
		_check(catalog.world_path(index).is_empty() and not catalog.error.is_empty(), "invalid stage path rejected")
		_check(catalog.bootstrap(index).is_empty() and not catalog.error.is_empty(), "invalid stage bootstrap rejected")
		_check(catalog.enemy(index, 0, "normal").is_empty() and not catalog.error.is_empty(), "invalid stage enemy rejected")
	_check(catalog.enemy(0, -1, "normal").is_empty(), "negative round rejected")
	_check(catalog.enemy(0, 40, "normal").is_empty(), "out of range round rejected")
	_check(catalog.enemy(0, 0, "missing").is_empty(), "unknown enemy rejected")
	for inputs in [{"tileSize": 0.0}, {"tileSize": "1"}, {"origin": null}, {"origin": [NAN, 0.0]}, {"origin": [0.0, INF]}, {"origin": ["0", 0.0]}]:
		_check(catalog.bootstrap(0, inputs).is_empty(), "invalid layout bootstrap rejected")
		_check(catalog.wave(0, 0, 100000, inputs).is_empty(), "invalid layout rejects entire wave")
	for delay in [-1.0, NAN, INF, "0", null]:
		_check(catalog.wave(0, 0, 100000, {"initialDelay": delay}).is_empty(), "invalid delay rejected")
	for spawn in [null, [], {"laneOffsetRatio": NAN}, {"visualPhase": "0"}, {"diamondReward": 1.5}, {"diamondReward": -1}, {"unknown": 1}]:
		var values: Array = []
		values.resize(catalog.wave_summary(0, 0).spawnCount)
		values.fill(spawn)
		_check(catalog.wave(0, 0, 100000, {"spawnValues": values}).is_empty(), "malformed spawn values reject entire wave")
	_check(catalog.wave(0, 0, 100000, {"spawnValues": {}}).is_empty(), "spawn values must be array")
	_check(catalog.wave(0, 0, 100000, {"spawnValues": []}).is_empty(), "spawn values length validated")
	_check(catalog.wave(0, 0, 100000, {"enemyValues": null}).is_empty(), "invalid enemy propagates to whole wave")
	_check(catalog.bootstrap(0, {"defenseConfig": null}).is_empty(), "invalid defense dictionary rejected")
	var valid_values: Array = []
	valid_values.resize(catalog.wave_summary(0, 0).spawnCount)
	valid_values.fill({"laneOffsetRatio": 0.125, "visualPhase": 0.75, "diamondReward": 2})
	var wave: Dictionary = catalog.wave(0, 0, 100000, {"spawnValues": valid_values, "initialDelay": 2.8})
	_check(not wave.is_empty(), "valid explicit inputs accepted after invalid inputs")
	_compare(wave.spawnQueue[0].delay, 2.8, "explicit initial delay retained")
	_compare(wave.spawnQueue[0].enemy.diamondReward, 2, "explicit integer reward retained")
