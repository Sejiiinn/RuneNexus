extends SceneTree
## Magic/rare enemy placement, affix effects, rewards, save restore and presentation rows.
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
const Rarity = preload("res://combat/enemy_rarity.gd")
const FrameRows = preload("res://presentation/frame_rows.gd")
const HudMenuPanel = preload("res://ui/hud_menu_panel.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func close(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) <= absf(expected) * 0.000001 + 0.000001, "%s got %s expected %s" % [label, actual, expected])

func _initialize() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(), "catalogs")
	var rules: Dictionary = catalog.enemy_rarity_rules()
	check(rules.rarities.magic.affixCount == [1, 2] and rules.rarities.rare.affixCount == [3, 3], "authored affix counts")
	check(rules.rarities.magic.maxHpMultiplier == 1.5 and rules.rarities.rare.maxHpMultiplier == 2.0, "fixed rarity HP multipliers")
	_placement_cases(catalog)
	_affix_cases(catalog, rules)
	_step_cases()
	_reward_cases(catalog, growth)
	_save_cases(catalog, growth)
	_presentation_cases(catalog)
	print("ENEMY_RARITY checks=%d failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)

func _placement_cases(catalog) -> void:
	# Chapter 1 stays ordinary; chapter 2/3 fixed rounds carry authored elites.
	for round_index in range(40): check(catalog.elite_spawns(0, round_index).is_empty(), "chapter 1 has no elites r" + str(round_index + 1))
	var stage: int = catalog.stage_index(6)
	var magic_only: Dictionary = catalog.elite_spawns(stage, 14)
	check(rarities(magic_only).count("magic") == 2 and magic_only.size() == 2, "2-1 round 15: two magic")
	for elite in magic_only.values(): check(elite.affixes.size() == 1, "round 15 magic has one authored affix")
	var mixed: Dictionary = catalog.elite_spawns(stage, 34)
	check(rarities(mixed).count("magic") == 2 and rarities(mixed).count("rare") == 1, "2-1 round 35: two magic and one rare")
	for elite in mixed.values(): check(Rarity.authored_affixes_valid(catalog.enemy_rarity_rules(), elite.rarity, elite.affixes), "authored affixes valid")
	check(catalog.elite_spawns(stage, 15).is_empty(), "non-elite round untouched")
	var forge: Dictionary = catalog.elite_spawns(catalog.stage_index(11), 34)
	check(rarities(forge).count("magic") == 3 and rarities(forge).count("rare") == 1, "chapter 3 round 35: three magic and one rare")
	var summary: Dictionary = catalog.wave_summary(stage, 34)
	var tallied := 0
	for type in summary.eliteCounts:
		for rarity in summary.eliteCounts[type]: tallied += int(summary.eliteCounts[type][rarity])
	check(tallied == 3 and HudMenuPanel.top_rarity(summary.eliteCounts) == "rare", "summary elite tally and top tier")
	# Authored identity consumes no draws, so every spawn's random values are identical.
	var plain := RandomNumberGenerator.new(); plain.seed = 77
	var elite := RandomNumberGenerator.new(); elite.seed = 77
	var legacy: Array = catalog.random_spawn_values(stage, 15, plain)
	plain.seed = 77
	var expected: Array = catalog.random_spawn_values(stage, 34, plain)
	var rolled: Array = catalog.random_spawn_values(stage, 34, elite)
	check(not legacy.is_empty() and legacy.all(func(v): return not v.has("rarity")), "non-elite wave has no rarity")
	var again := RandomNumberGenerator.new(); again.seed = 9
	var other: Array = catalog.random_spawn_values(stage, 34, again)
	for index in range(rolled.size()):
		var value: Dictionary = rolled[index]
		check(value.laneOffsetRatio == expected[index].laneOffsetRatio and value.visualPhase == expected[index].visualPhase and value.diamondReward == expected[index].diamondReward, "legacy draws unchanged " + str(index))
		if mixed.has(index):
			check(value.rarity == mixed[index].rarity and value.affixes == mixed[index].affixes, "fixed affixes " + str(index))
			check(other[index].rarity == value.rarity and other[index].affixes == value.affixes, "affixes independent of seed " + str(index))
		else:
			check(not value.has("rarity"), "ordinary spawn " + str(index))
	var wave: Dictionary = catalog.wave(stage, 34, 100000, {"spawnValues": rolled})
	for index in range(wave.spawnQueue.size()):
		var prepared: Dictionary = wave.spawnQueue[index].enemy
		check(prepared.get("rarity", "") == mixed.get(index, {}).get("rarity", ""), "wave enemy rarity " + str(index))
		if mixed.has(index):
			var base: float = catalog.wave_durability(stage, 34, prepared.type).maxHp
			var multiplier: float = catalog.enemy_rarity_rules().rarities[mixed[index].rarity].maxHpMultiplier
			if "sturdy" in prepared.affixes: multiplier *= catalog.enemy_rarity_rules().affixes.sturdy.maxHpMultiplier
			close(prepared.maxHp, base * multiplier, "wave elite max HP " + str(index))
			close(prepared.hp, prepared.maxHp, "wave elite starts full " + str(index))

func rarities(elites: Dictionary) -> Array:
	return elites.values().map(func(e): return e.rarity)

func _affix_cases(catalog, rules: Dictionary) -> void:
	var stage: int = catalog.stage_index(6)
	var base: Dictionary = catalog.enemy(stage, 14, "normal", 1)
	var all: Dictionary = catalog.enemy(stage, 14, "normal", 2, {"enemyValues": {"rarity": "rare", "affixes": ["steadfast", "swift", "sturdy", "plated", "warded", "regenerating"]}})
	var hp: float = base.maxHp * rules.rarities.rare.maxHpMultiplier * rules.affixes.sturdy.maxHpMultiplier
	close(all.maxHp, hp, "rare sturdy max HP")
	close(all.speed, base.speed * rules.affixes.swift.speedMultiplier, "swift speed")
	close(all.maxArmor, hp * rules.affixes.plated.armorRatio, "plated armor from final HP")
	close(all.armor, all.maxArmor, "plated armor full")
	close(all.maxShield, hp * rules.affixes.warded.shieldRatio, "warded shield from final HP")
	close(all.shieldRegenRate, rules.affixes.warded.shieldRegenRate, "warded regen")
	close(all.hpRegenRate, rules.affixes.regenerating.hpRegenRate, "regenerating rate")
	close(all.slowResistance, rules.affixes.steadfast.slowResistance, "steadfast resistance")
	check(all.affixes == Rarity.AFFIXES, "affixes stored in fixed order")
	var magic: Dictionary = catalog.enemy(stage, 14, "shielded", 3, {"enemyValues": {"rarity": "magic"}})
	var plain: Dictionary = catalog.enemy(stage, 14, "shielded", 4)
	close(magic.maxHp, plain.maxHp * rules.rarities.magic.maxHpMultiplier, "magic without affix only scales HP")
	check(magic.maxShield == plain.maxShield and magic.speed == plain.speed and not magic.has("hpRegenRate"), "magic without affix keeps other stats")
	# Rejections never fall back to an ordinary enemy.
	check(catalog.enemy(stage, 14, "shieldBoss", 5, {"enemyValues": {"rarity": "rare", "affixes": []}}).is_empty(), "boss rarity rejected")
	check(catalog.enemy(stage, 14, "normal", 6, {"enemyValues": {"rarity": "legendary", "affixes": []}}).is_empty(), "unknown rarity rejected")
	check(catalog.enemy(stage, 14, "normal", 7, {"enemyValues": {"rarity": "magic", "affixes": ["swift", "swift"]}}).is_empty(), "duplicate affix rejected")
	check(catalog.enemy(stage, 14, "normal", 8, {"enemyValues": {"affixes": ["swift"]}}).is_empty(), "affix without rarity rejected")

func _step_cases() -> void:
	var path := [{"x": 0.0, "y": 0.0}, {"x": 1000.0, "y": 0.0}]
	var regen := Enemy.create({"id": 1, "maxHp": 100.0, "hp": 50.0, "speed": 0.0, "hpRegenRate": 0.02, "path": path})
	Enemy.step(regen, 1.0)
	close(regen.hp, 52.0, "regeneration per second")
	regen.hp = 99.5
	Enemy.step(regen, 1.0)
	close(regen.hp, 100.0, "regeneration caps at max HP")
	var plain := Enemy.create({"id": 2, "maxHp": 100.0, "hp": 100.0, "speed": 10.0, "path": path})
	var steadfast := Enemy.create({"id": 3, "maxHp": 100.0, "hp": 100.0, "speed": 10.0, "slowResistance": 0.5, "path": path})
	for e in [plain, steadfast]:
		Enemy.add_slow(e, 0.4, 5.0)
		Enemy.step(e, 1.0)
	close(plain.distanceTravelled, 4.0, "ordinary slowed movement")
	close(steadfast.distanceTravelled, 7.0, "steadfast halves the slowed share")
	Enemy.add_control(steadfast, "stun", 1.0)
	var before: float = steadfast.distanceTravelled
	Enemy.step(steadfast, 0.5)
	close(steadfast.distanceTravelled, before, "steadfast does not resist stun")

func _reward_cases(catalog, growth) -> void:
	var service = Commands.new(catalog, growth)
	var state: Dictionary = service.initial_state({"growthVersion": 1, "runes": 0, "coreCombatSkill": null, "turretModules": {"tickets": 0, "items": []}}, 0)
	var base_gold := int(state.gold)
	var reward := int(catalog.enemy_definition("normal").rewardGold)
	var result: Dictionary = service.award_kill(state, {"type": "normal"})
	check(result.ok and int(result.state.gold) - base_gold == reward, "ordinary kill gold")
	for rarity in ["magic", "rare"]:
		result = service.award_kill(state, {"type": "normal", "rarity": rarity, "affixes": []})
		check(result.ok and int(result.state.gold) - base_gold == reward * int(catalog.enemy_rarity_rules().rarities[rarity].rewardGoldMultiplier), rarity + " kill gold multiplier")

func _save_cases(catalog, growth) -> void:
	var service = Commands.new(catalog, growth)
	var adapter = Adapter.new(catalog, growth)
	var stage: int = catalog.stage_index(6)
	var round_index := 34
	var state: Dictionary = service.initial_state({"growthVersion": 1, "runes": 10, "coreCombatSkill": null, "turretModules": {"tickets": 0, "items": []}}, stage)
	state.phase = "wave"
	state.roundIndex = round_index
	state.completedRounds = round_index
	state.tileSize = 48.0
	state.runCoreCombatSkill = null
	state.economyRunId = "rarity-save-run"
	var input := {"tileSize": 48.0, "defenseConfig": service.derived(state).defenseConfig}
	var bootstrap: Dictionary = catalog.bootstrap(stage, input)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var wave_input := input.duplicate(); wave_input.spawnValues = catalog.random_spawn_values(stage, round_index, rng)
	bootstrap.wave = catalog.wave(stage, round_index, 100000, wave_input)
	var all_values := {"rarity": "rare", "affixes": ["plated", "warded", "swift"]}
	var live_input := input.duplicate(); live_input.enemyValues = all_values
	var live: Dictionary = catalog.enemy(stage, round_index, "normal", 90000, live_input)
	live.hp *= 0.5; live.armor *= 0.25; live.shield *= 0.75
	live.distanceTravelled = 48.0 * 2.5
	for field in ["x", "y", "position", "targetIndex", "facingAngle"]: live.erase(field)
	var ordinary: Dictionary = catalog.enemy(stage, round_index, "fast", 90001, input)
	for field in ["x", "y", "position", "targetIndex", "facingAngle"]: ordinary.erase(field)
	bootstrap.enemies = [live, ordinary]
	var runtime = Runtime.new()
	runtime.process_command({"epoch": 1, "sequence": 0, "session": {"clock": "godot", "phase": "wave", "paused": true}, "bootstrap": bootstrap})
	runtime.process_command({"epoch": 1, "sequence": 1, "ackEvent": runtime.event_id})
	var saved: Dictionary = adapter.capture(state, runtime.snapshot(), 123, {"selectedStageNumber": 6})
	check(not saved.is_empty(), "capture: " + adapter.error)
	if saved.is_empty(): return
	var saved_enemy: Dictionary = saved.activeRun.enemies[0]
	check(saved_enemy.rarity == "rare" and saved_enemy.affixes == ["swift", "plated", "warded"], "rarity and affixes persisted")
	check(not saved.activeRun.enemies[1].has("rarity"), "ordinary enemy keeps v2 shape")
	check(Codec.is_normalized_v2(saved), "normalized v2 with rarity")
	var without := saved.duplicate(true)
	without.activeRun.enemies[0].erase("rarity"); without.activeRun.enemies[0].erase("affixes")
	check(Hash.hash_payload(saved) != Hash.hash_payload(without), "payload hash covers rarity")
	check(Hash.hash_payload(without) == Hash.hash_payload(Codec.decode(without)), "rarity-free payload hash unchanged by decode")
	var prepared: Dictionary = adapter.prepare(saved, {"tileSize": 48.0})
	check(not prepared.is_empty(), "prepare: " + adapter.error)
	if prepared.is_empty(): return
	var restored = Runtime.new()
	restored.process_command({"epoch": 2, "sequence": 0, "session": prepared.session, "bootstrap": prepared.bootstrap})
	var back: Dictionary = restored.enemies["100000"]
	var source: Dictionary = runtime.enemies["90000"]
	for field in ["maxHp", "hp", "armor", "shield", "maxArmor", "maxShield", "speed", "shieldRegenRate"]:
		close(float(back[field]), float(source[field]), "restored rare " + field)
	check(back.rarity == "rare" and back.affixes == ["swift", "plated", "warded"], "restored identity")
	check(not restored.enemies["100001"].has("rarity"), "restored ordinary enemy")
	# Pending elites come back from the authored placement with the same affixes.
	var authored: Dictionary = catalog.elite_spawns(stage, round_index)
	var offset: int = int(catalog.wave_summary(stage, round_index).spawnCount) - prepared.bootstrap.wave.spawnQueue.size()
	for pending_index in range(prepared.bootstrap.wave.spawnQueue.size()):
		var pending: Dictionary = prepared.bootstrap.wave.spawnQueue[pending_index].enemy
		var expected: Dictionary = authored.get(offset + pending_index, {})
		check(pending.get("rarity", "") == expected.get("rarity", "") and pending.get("affixes", []) == expected.get("affixes", []), "pending authored elite " + str(pending_index))
	var tampered := saved.duplicate(true)
	tampered.activeRun.enemies[0].rarity = "legendary"
	check(not Codec.decode(tampered).activeRun.enemies[0].has("rarity"), "invalid saved rarity dropped by codec")

func _presentation_cases(catalog) -> void:
	var row := FrameRows.Enemy.new()
	row.id = 9; row.type = "normal"; row.rarity = "magic"
	var round_trip := FrameRows.Enemy.from_array(row.to_array())
	check(round_trip.rarity == "magic", "frame row keeps rarity")
	var plain := FrameRows.Enemy.new()
	check(plain.to_array().size() == 12 and FrameRows.Enemy.from_array(plain.to_array()).rarity == "", "ordinary row keeps legacy width")
