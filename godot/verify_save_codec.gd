extends SceneTree
const SaveJson = preload("res://app/save_json.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")

func _initialize() -> void:
	var inputs: Variant = SaveJson.parse(FileAccess.get_file_as_string("res://fixtures/godot_save_codec_inputs.json"))
	var expected: Variant = SaveJson.parse(FileAccess.get_file_as_string("res://fixtures/godot_save_codec_expected.json"))
	if not inputs is Array or not expected is Array or inputs.size() != expected.size():
		push_error("Missing save codec fixtures")
		quit(1)
		return
	var failures := _integer_boundaries() + _boss_damage_training() + _damage_training() + _dot_metadata() + _poison_turret()
	for i in inputs.size():
		# Historical synthetic scalar fixtures used 7.8, negative and nonnumeric
		# revisions. Since v5, revision is a discriminant, not a lossy scalar:
		# reject those records without changing the archived fixture/oracle.
		if inputs[i] is Dictionary and inputs[i].get("progression") is Dictionary:
			var p: Dictionary = inputs[i].progression
			if p.has("corePassiveTreeRevision") and (not p.corePassiveTreeRevision is int or p.corePassiveTreeRevision < 0 or p.corePassiveTreeRevision > 5):
				if Codec.decode(inputs[i]) != null or Codec.is_canonical_v2(inputs[i]):
					failures += 1
					print("SAVE_CODEC_UNSUPPORTED_REVISION_ACCEPTED ",i)
				continue
		var actual: Variant = Codec.decode(inputs[i])
		if Codec.is_canonical_v2(inputs[i]) != expected[i].canonical or not _equal(actual, expected[i].decoded):
			failures += 1
			print("SAVE_CODEC_MISMATCH ", i, " expected=", JSON.stringify(expected[i].decoded), " actual=", JSON.stringify(actual))
		for path in expected[i].numericTypes:
			var value: Variant = actual
			for part in path.split("/", false):
				value = value[int(part)] if value is Array else value.get(part)
			var wanted: int = TYPE_INT if expected[i].numericTypes[path] == "int" else TYPE_FLOAT
			if typeof(value) != wanted:
				failures += 1
				print("SAVE_CODEC_TYPE_MISMATCH ", i, " ", path)
		if actual != null and not _equal(Codec.decode(actual), actual):
			failures += 1
			print("SAVE_CODEC_NON_IDEMPOTENT ", i)
	print("SAVE_CODEC_FIXTURES count=", inputs.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)

# These binary64 neighbours straddle the int64 boundary. Keep expected values
# as integer literals: converting INT64_MAX to float would hide off-by-one loss.
func _integer_boundaries() -> int:
	var cases := [
		[9223372036854775807, 9223372036854775807],
		[-9223372036854775807 - 1, -9223372036854775807 - 1],
		[9223372036854774784.0, 9223372036854774784],
		[-9223372036854774784.0, -9223372036854774784],
		[9223372036854775808.0, 9223372036854775807],
		[-9223372036854775808.0, -9223372036854775807 - 1],
		[9223372036854777856.0, 9223372036854775807],
		[-9223372036854777856.0, -9223372036854775807 - 1],
		[1e20, 9223372036854775807], [-1e20, -9223372036854775807 - 1],
		[1e308, 9223372036854775807], [-1e308, -9223372036854775807 - 1],
		[7.9, 7], [-7.9, -7], [-0.0, 0],
	]
	var failures := 0
	for test in cases:
		var actual: Variant = Codec._int(test[0])
		if typeof(actual) != TYPE_INT or actual != test[1]:
			failures += 1
			print("SAVE_CODEC_INT_BOUNDARY_MISMATCH input=", test[0], " expected=", test[1], " actual=", actual)
	# Check the public decoder's signed, nonnegative, nullable, map/list and
	# field-specific clamping rules still compose with saturated conversion.
	var decoded: Dictionary = Codec.decode({"version":2, "savedAtMillis":-1e20,
		"preferences":{}, "progression":{"runes":1e20,"totalPlayTimeMillis":-1e20,
			"researchLevels":{"researchEfficiency":1e20},"weeklyAttendanceDayKeys":[-1e20,1e20]},
		"turretModules":{}, "activeRun":{"phase":"wave","gold":-1e20,"pendingEconomyDiamonds":1e20}})
	var expected := [-9223372036854775807 - 1,9223372036854775807,0,9223372036854775807,
		[9223372036854775807],-9223372036854775807 - 1,1000000]
	var actual := [decoded.savedAtMillis,decoded.progression.runes,decoded.progression.totalPlayTimeMillis,
		decoded.progression.researchLevels.researchEfficiency,decoded.progression.weeklyAttendanceDayKeys,
		decoded.activeRun.gold,decoded.activeRun.pendingEconomyDiamonds]
	if actual != expected or Codec._int(null,null) != null or Codec._int("123",17) != 17 or Codec._int(true,17) != 17:
		failures += 1
		print("SAVE_CODEC_INT_RULE_MISMATCH expected=", expected, " actual=", actual)
	print("SAVE_CODEC_INT_BOUNDARIES count=",cases.size()," failures=",failures)
	return failures

func _boss_damage_training() -> int:
	var failures := 0
	var legacy := {"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":null}
	if Codec.decode(legacy).progression.has("bossDamageTrainingUpgradeLevel"):
		failures += 1
		print("SAVE_CODEC_TRAINING_SYNTHETIC_ZERO")
	for level in [0, 1, 40]:
		var input: Dictionary = legacy.duplicate(true)
		input.progression.bossDamageTrainingUpgradeLevel = level
		var decoded: Variant = Codec.decode(input)
		if decoded == null or decoded.progression.bossDamageTrainingUpgradeLevel != level or not Codec.is_normalized_v2(decoded) or Codec.decode(decoded) != decoded:
			failures += 1
			print("SAVE_CODEC_TRAINING_ROUNDTRIP ",level)
	for invalid in [-1, 41, 1.0, 1.5, "1", true, null]:
		var input: Dictionary = legacy.duplicate(true)
		input.progression.bossDamageTrainingUpgradeLevel = invalid
		if Codec.is_canonical_v2(input) or Codec.decode(input) != null:
			failures += 1
			print("SAVE_CODEC_TRAINING_INVALID ",invalid)
	print("SAVE_CODEC_BOSS_DAMAGE_TRAINING failures=",failures)
	return failures

func _damage_training() -> int:
	var failures := 0
	var legacy := {"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":null}
	for key in ["directDamageTrainingUpgradeLevel", "splashDamageTrainingUpgradeLevel", "damageOverTimeTrainingUpgradeLevel"]:
		if Codec.decode(legacy).progression.has(key): failures += 1
		for level in [0, 1, 60, 80]:
			var input: Dictionary = legacy.duplicate(true)
			input.progression[key] = level
			var decoded: Variant = Codec.decode(input)
			if decoded == null or decoded.progression[key] != level or not Codec.is_normalized_v2(decoded) or Codec.decode(decoded) != decoded: failures += 1
		for invalid in [-1, 81, 1.0, 1.5, "1", true, null]:
			var input: Dictionary = legacy.duplicate(true)
			input.progression[key] = invalid
			if Codec.is_canonical_v2(input) or Codec.decode(input) != null: failures += 1
	print("SAVE_CODEC_DAMAGE_TRAINING failures=", failures)
	return failures

func _dot_metadata() -> int:
	var failures := 0
	var base := {"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":{"phase":"wave","enemies":[{"type":"normal","burnInstances":[{"remaining":3.0,"damagePerSecond":5.0}]}]}}
	for key in ["damageOverTimeIncreaseMultiplier", "poisonDamageOverTimeIncreaseMultiplier"]:
		for value in [1.0, 1.5, 4.0]:
			var input: Dictionary = base.duplicate(true)
			var record: Dictionary = input.activeRun.enemies[0].burnInstances[0] if key == "damageOverTimeIncreaseMultiplier" else input.activeRun.enemies[0]
			record[key] = value
			var decoded: Variant = Codec.decode(input)
			if decoded == null:
				failures += 1
				continue
			var actual: Dictionary = decoded.activeRun.enemies[0].burnInstances[0] if key == "damageOverTimeIncreaseMultiplier" else decoded.activeRun.enemies[0]
			if (actual.has(key) if value == 1.0 else actual.get(key) != value) or not Codec.is_normalized_v2(decoded): failures += 1
		for value in [0, -1, 0.9, 4.01, INF, NAN, "1", true, null]:
			var input: Dictionary = base.duplicate(true)
			var record: Dictionary = input.activeRun.enemies[0].burnInstances[0] if key == "damageOverTimeIncreaseMultiplier" else input.activeRun.enemies[0]
			record[key] = value
			if Codec.is_canonical_v2(input) or Codec.decode(input) != null: failures += 1
	print("SAVE_CODEC_DOT_METADATA failures=", failures)
	return failures

# Poison turrets keep type, traits and per-stack timers. Saves without poison
# stacks gain no field, so their payload hash is unchanged.
func _poison_turret() -> int:
	var failures := 0
	var stack := {"remaining":3.0,"damagePerSecond":1.5,"sourceX":2,"sourceY":3,"stackBonus":0.1,"corrosive":true,"damageOverTimeIncreaseMultiplier":1.5,"unknown":1}
	var base := {"version":2,"preferences":{},"progression":{},"turretModules":{},"activeRun":{"phase":"wave",
		"turrets":[{"id":1,"type":"poison","x":2,"y":3,"primaryTrait":"venomPool","secondaryTrait":"corrosiveToxin"}],
		"enemies":[{"type":"normal","poisonInstances":[stack,{"remaining":0.0,"damagePerSecond":1.0},{"remaining":2.0,"damagePerSecond":1.0,"corrosive":"yes"}]}]}}
	var decoded: Variant = Codec.decode(base)
	if not decoded is Dictionary: return 1
	var turret: Dictionary = decoded.activeRun.turrets[0]
	if turret.type != "poison" or turret.primaryTrait != "venomPool" or turret.secondaryTrait != "corrosiveToxin": failures += 1
	for trait_id in ["pressurizedFeed","concentratedToxin"]:
		if Codec._enum("TurretTraitType", trait_id) != trait_id: failures += 1
	# Poison modules keep their turret, family and duration option.
	var modules: Dictionary = base.duplicate(true)
	modules.turretModules = {"tickets":0,"items":[{"id":"p1","turretType":"poison","part":"core","family":"venomCore","grade":"rare","equipped":true,"acquiredOrder":1,"options":[{"type":"poisonDurationIncrease","value":20}]}]}
	var module_items: Array = Codec.decode(modules).turretModules.get("items", [])
	if module_items.size() != 1 or module_items[0].family != "venomCore" or module_items[0].options[0].type != "poisonDurationIncrease": failures += 1
	# The poison damage gem survives inventory, offers and equipped slots.
	var gems: Dictionary = base.duplicate(true)
	gems.activeRun.gemInventory = {"poisonDamage":2}
	gems.activeRun.rewardOptions = ["poisonDamage","range","chain"]
	gems.activeRun.turrets[0].equippedGemSlots = ["poisonDamage"]
	var gems_decoded: Variant = Codec.decode(gems)
	if gems_decoded == null or gems_decoded.activeRun.gemInventory != {"poisonDamage":2} or not "poisonDamage" in gems_decoded.activeRun.rewardOptions or gems_decoded.activeRun.turrets[0].equippedGemSlots != ["poisonDamage"]: failures += 1
	var poisons: Array = decoded.activeRun.enemies[0].get("poisonInstances", [])
	if poisons.size() != 2: failures += 1
	elif poisons[0] != {"remaining":3.0,"damagePerSecond":1.5,"damageMultiplier":1.0,"sourceX":2,"sourceY":3,"stackBonus":0.1,"corrosive":true,"damageOverTimeIncreaseMultiplier":1.5} or poisons[1].has("corrosive"): failures += 1
	if not _equal(Codec.decode(decoded), decoded) or not Codec.is_normalized_v2(decoded): failures += 1
	var without: Dictionary = base.duplicate(true)
	without.activeRun.enemies[0].erase("poisonInstances")
	var plain: Variant = Codec.decode(without)
	if plain == null or plain.activeRun.enemies[0].has("poisonInstances"): failures += 1
	without.activeRun.enemies[0].poisonInstances = []
	if Codec.decode(without) != plain or Hash.hash_payload(Codec.decode(without)) != Hash.hash_payload(plain): failures += 1
	if Hash.hash_payload(decoded) == Hash.hash_payload(plain): failures += 1
	# Poison damage training is optional 0..50; absence keeps old hashes.
	var trained: Dictionary = without.duplicate(true)
	if Codec.decode(trained).progression.has("poisonDamageTrainingUpgradeLevel"): failures += 1
	trained.progression.poisonDamageTrainingUpgradeLevel = 50
	var trained_decoded: Variant = Codec.decode(trained)
	if trained_decoded == null or trained_decoded.progression.poisonDamageTrainingUpgradeLevel != 50 or Hash.hash_payload(trained_decoded) == Hash.hash_payload(plain): failures += 1
	for value in [51, -1, 1.5, "1"]:
		trained.progression.poisonDamageTrainingUpgradeLevel = value
		if Codec.decode(trained) != null: failures += 1
	for value in [0.9, 4.01, "1"]:
		var invalid: Dictionary = base.duplicate(true)
		invalid.activeRun.enemies[0].poisonInstances[0].damageOverTimeIncreaseMultiplier = value
		if Codec.decode(invalid) != null: failures += 1
		# A malformed burn list must not skip poison metadata validation.
		invalid.activeRun.enemies[0].burnInstances = "bad"
		if Codec.decode(invalid) != null: failures += 1
	print("SAVE_CODEC_POISON failures=", failures)
	return failures

# Godot JSON parses every number as float; compare values recursively without
# equating booleans/strings to numbers or losing array order and null slots.
func _equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _equal(a[i], b[i]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return a == b
	return typeof(a) == typeof(b) and a == b
