extends SceneTree
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Json = preload("res://app/save_json.gd")
class CountingCommands extends Commands:
	var derive_calls := 0
	func derived(state: Dictionary) -> Dictionary:
		derive_calls += 1
		return super.derived(state)
class CountingCatalog extends Catalog:
	var turret_calls: Array = []
	func turret(type: String = "arrow", inputs: Dictionary = {}) -> Dictionary:
		turret_calls.append(type)
		return super.turret(type, inputs)

var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog(),"content")
	check(growth.load_catalog(),"growth")
	var service = Commands.new(catalog,growth)
	_build_price_cache_checks(catalog,growth)
	var path := ProjectSettings.globalize_path("res://../test/fixtures/growth_cases.json")
	var fixtures: Dictionary = Json.parse(FileAccess.get_file_as_string(path))
	var kinds := {"levelUp":"level","upgradeLink":"link","choosePrimaryTrait":"primaryTrait","chooseSecondaryTrait":"secondaryTrait","equipGem":"equipGem","removeGem":"removeGem","refund":"sell"}
	for fixture in fixtures.cases:
		var state: Dictionary = service.initial_state()
		for key in ["gold","gemShards","gemInventory"]: state[key] = fixture.before[key].duplicate(true) if fixture.before[key] is Dictionary else fixture.before[key]
		var t: Dictionary = fixture.before.turret.duplicate(true)
		t.id = 1
		state.turrets = [t]
		state.tileSize = 48.0
		var raw: Dictionary = fixture.command
		state.phase = raw.get("phase","preparation")
		if not raw.get("canEditBoard",true): state.phase = "failure"
		var command := {"kind":kinds[raw.type],"id":1,"type":raw.get("gem",raw.get("trait",""))}
		if raw.get("slotIndex") != null: command.slot = raw.slotIndex
		var before := state.duplicate(true)
		var result: Dictionary = service.apply(state,command)
		check(state == before,fixture.name+": input immutable")
		check(result.ok == fixture.ok,fixture.name+": accepted")
		for key in ["gold","gemShards","gemInventory"]: check(result.state[key] == fixture.after[key],fixture.name+": "+key)
		if fixture.after.turret == null:
			check(result.state.turrets.is_empty(),fixture.name+": removed")
		else:
			var actual: Dictionary = result.state.turrets[0].duplicate(true)
			actual.erase("id")
			check(actual == fixture.after.turret,fixture.name+": turret config")
			var commands: Array = service.runtime_commands(result.state)
			var input: Dictionary = commands[0].turret.statInput
			check(Stats.stats_at(input,int(actual.level)) == Stats.stats_at(fixture.after.statInput,int(actual.level)),fixture.name+": combat stats")
	var state: Dictionary = service.initial_state()
	state.gold = 100000
	var map: Dictionary = catalog.stage(0).map
	var tile: int = map.tiles.find("build")
	var build := {"kind":"build","type":"arrow","x":tile%int(map.columns),"y":int(tile/int(map.columns))}
	var built: Dictionary = service.apply(state,build)
	check(built.ok and built.state.gold == state.gold-service.build_cost(state,"arrow"),"build charges cost")
	check(not service.apply(built.state,build).ok,"occupied rejected")
	check(not service.apply(state,{"kind":"build","type":"sniper","x":build.x,"y":build.y}).ok,"locked turret rejected")
	state = built.state
	var buy: Dictionary = service.apply(state,{"kind":"runUpgrade","type":"towerDamage"})
	check(buy.ok and buy.state.runUpgradeLevels.towerDamage == 1,"run upgrade")
	check(buy.commands[0].turret.statInput.towerDamageMultiplier > built.commands[0].turret.statInput.towerDamageMultiplier,"run upgrade refresh")
	state.gemShards = 100
	var reward: Dictionary = service.apply(state,{"kind":"purchaseGemChoice"})
	check(reward.ok and reward.state.phase == "reward" and reward.state.rewardOptions.size() == 3,"purchase gem choice")
	check(not service.apply(reward.state,{"kind":"chooseRewardShards"}).ok,"purchased choice cannot become shards")
	var chosen: Dictionary = service.apply(reward.state,{"kind":"chooseRewardGem","type":reward.state.rewardOptions[0]})
	check(chosen.ok and chosen.state.phase == "preparation" and chosen.state.rewardOptions.is_empty(),"choice resumes prior phase")
	state = service.initial_state()
	state.phase = "wave"
	state.runUpgradeLevels = {"killGold":1}
	for i in range(10): state = service.award_kill(state,{"type":"normal"}).state
	check(state.gold == service.initial_state().gold+50,"fraction bonus does not round each kill")
	state = service.award_kill(state,{"type":"normal"}).state
	check(state.gold == service.initial_state().gold+56,"fraction wallet eventually pays")
	var wave: Dictionary = service.complete_wave(state,1)
	check(wave.ok and wave.state.completedRounds == 1 and wave.state.roundIndex == 1,"wave settles once")
	check(not service.complete_wave(wave.state,1).ok,"duplicate completed wave rejected")
	state.roundIndex = 4
	state.completedRounds = 4
	var fifth: Dictionary = service.complete_wave(state,5)
	check(fifth.ok and fifth.state.phase == "reward" and fifth.state.rewardOptions.size() == 3,"fifth round gem reward")
	check(service.apply(fifth.state,{"kind":"chooseRewardShards"}).ok,"round reward can become shards")
	var runtime = Runtime.new()
	runtime.process_command({"epoch":1,"sequence":0,"dt":0.0,"bootstrap":{"turrets":[built.commands[0].turret]}})
	var tower: Dictionary = runtime.turrets[str(built.state.turrets[0].id)]
	tower.cooldown = 0.37
	tower.aimProgress = 0.27
	tower.directDamageDealt = 123.0
	tower.recent = {"77":1.3}
	var upgraded: Dictionary = service.apply(built.state,{"kind":"level","id":built.state.turrets[0].id})
	runtime.process_command({"epoch":1,"sequence":1,"dt":0.0,"commands":upgraded.commands})
	tower = runtime.turrets[str(built.state.turrets[0].id)]
	check(tower.cooldown == 0.37 and tower.aimProgress == 0.27 and tower.directDamageDealt == 123.0 and tower.recent == {"77":1.3},"upgrading preserves combat clocks and damage")
	_targeted_level_cases(catalog,growth,built.state)
	_light_weapon_equip_cases(service,built.state)
	_reward_equip_cases(service,built.state)
	_reward_slot_purchase_cases(service,built.state)
	_game_cases(service)
	print("RUN_COMMANDS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func _targeted_level_cases(catalog, growth, built: Dictionary) -> void:
	var counted := CountingCatalog.new()
	check(counted.load_fixture_content(catalog.domain_snapshot()),"counting catalog fixture")
	var service := Commands.new(counted,growth)
	var state := built.duplicate(true)
	state.phase = "wave"
	state.tileSize = 48.0
	state.progression.corePassiveNodeRanks = {"efficiencyDiversity":5,"efficiencyGemSpectrum":5,"efficiencyCombinedFront":1}
	state.turrets = []
	var types := ["arrow","cannon","magic","frost"]
	var gems := ["range","multipleProjectiles","damageOverTime","attackSpeed"]
	for i in types.size():
		var turret: Dictionary = built.turrets[0].duplicate(true)
		turret.id = 200+i
		turret.type = types[i]
		turret.x += i
		turret.equippedGemSlots = [gems[i]]
		turret.equippedGems = [gems[i]]
		state.turrets.append(turret)
	var target_id: int = state.turrets[1].id
	var before := state.duplicate(true)
	var cost: int = service.quotes(state,target_id).level
	var initial_commands: Array = service.runtime_commands(state)
	check(counted.turret_calls == types,"default refresh calculates every turret in order")
	var core_config := {"runSkill":"guardianBeam","normalMaxHp":0.0,"guardianBeamInterval":5.0,"guardianDpsRate":0.08,"attackSyncDamageMultiplier":1.2,"attackSyncAttackRateMultiplier":1.15}
	var bootstrap := {"tileSize":48.0,"turrets":initial_commands.map(func(c): return c.turret),"coreConfig":core_config,"core":{"attackSyncRemaining":1.0,"cooldown":0.0}}
	var runtime := Runtime.new()
	var full_runtime := Runtime.new()
	for current in [runtime,full_runtime]:
		current.process_command({"epoch":1,"sequence":0,"dt":0.0,"bootstrap":bootstrap})
		for turret in current.turrets.values():
			turret.cooldown = 0.37
			turret.aimProgress = 0.27
			turret.aimTargetId = 77
			turret.directDamageDealt = 123.0
			turret.recent = {"77":1.3}
	var runtime_before: Dictionary = runtime.turrets.duplicate(true)
	var core_damage_before: float = runtime._core_base_damage()
	counted.turret_calls.clear()
	var result: Dictionary = service.apply(state,{"kind":"level","id":target_id})
	check(result.ok and result.commands.size() == 1 and result.commands[0].kind == "turret" and result.commands[0].turret.id == target_id,"level emits only the selected turret")
	check(counted.turret_calls == ["cannon"],"level calculates only the selected turret instead of filtering full results")
	check(state == before and result.state.gold == state.gold-cost and result.state.turrets[1].investedGold == state.turrets[1].investedGold+cost,"targeted level preserves quote, investment and immutable input")
	var full_commands: Array = service.runtime_commands(result.state)
	check(result.commands[0] == full_commands[1],"targeted level has identical full-board growth inputs and combat stats")
	check(result.commands[0].turret.statInput.passiveNumericGemEffectMultiplier > 1.0,"targeted level retains other turrets' gem diversity bonus")
	runtime.process_command({"epoch":1,"sequence":1,"dt":0.0,"commands":result.commands})
	full_runtime.process_command({"epoch":1,"sequence":1,"dt":0.0,"commands":full_commands})
	for i in types.size():
		var id := str(state.turrets[i].id)
		check(runtime.turrets[id] == full_runtime.turrets[id],"targeted level matches full runtime including combat clocks "+id)
		if i != 1:
			check(result.state.turrets[i] == state.turrets[i] and runtime.turrets[id] == runtime_before[id],"level leaves other turret configuration and runtime untouched "+id)
	var core_damage: float = runtime._core_base_damage()
	check(core_damage > core_damage_before and _near(core_damage,full_runtime._core_base_damage()),"core damage includes all turrets and the selected turret's new stats")
	for current in [runtime,full_runtime]:
		current.core.update(0.01,func(): return true,current._core_base_damage,func(_damage): pass,func(_power): pass)
	check(runtime.core.guardian_beam_tick_damage > 0 and _near(runtime.core.guardian_beam_tick_damage,full_runtime.core.guardian_beam_tick_damage),"guardian activation damage matches full refresh after targeted level")
	counted.turret_calls.clear()
	var run_upgrade: Dictionary = service.apply(result.state,{"kind":"runUpgrade","type":"towerDamage"})
	check(run_upgrade.ok and run_upgrade.commands.size() == types.size() and counted.turret_calls == types,"run upgrade still calculates and updates every turret")
	for i in types.size():
		check(run_upgrade.commands[i].turret.statInput.towerDamageMultiplier > full_commands[i].turret.statInput.towerDamageMultiplier,"run upgrade refresh reaches turret "+str(i))
	for reason in ["gold","requirement","turret","phase"]:
		var rejected := state.duplicate(true)
		var command := {"kind":"level","id":target_id}
		match reason:
			"gold": rejected.gold = cost-1
			"requirement": rejected.turrets[1].level = int(growth.data.turretRules.cannon.maxLevel)
			"turret": command.id = -1
			"phase": rejected.phase = "reward"
		var rejected_before := rejected.duplicate(true)
		counted.turret_calls.clear()
		var failure: Dictionary = service.apply(rejected,command)
		check(not failure.ok and failure.error == reason and failure.commands.is_empty() and counted.turret_calls.is_empty() and failure.state == rejected_before and rejected == rejected_before,"failed level leaves state untouched without calculating or emitting turrets: "+reason)

func _near(actual: Variant, expected: Variant) -> bool:
	if expected is int or expected is float:
		return (actual is int or actual is float) and absf(float(actual)-float(expected)) <= 0.00000001 * maxf(1.0,absf(float(expected)))
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not _near(actual[key],expected[key]): return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size(): return false
		for i in expected.size():
			if not _near(actual[i],expected[i]): return false
		return true
	return actual == expected

func _game_cases(service) -> void:
	var fixtures: Dictionary = Json.parse(FileAccess.get_file_as_string("res://../test/fixtures/growth_game_cases.json"))
	check(fixtures.cases.size() >= 204,"actual game fixture coverage")
	for fixture in fixtures.cases:
		var p: Dictionary = fixture.progression.duplicate(true)
		p.turretModules = fixture.moduleInventory.duplicate(true)
		var state: Dictionary = service.initial_state(p)
		for key in ["gold","gemShards","phase","runUpgradeLevels","turrets"]:
			state[key] = fixture.before[key].duplicate(true) if fixture.before[key] is Dictionary or fixture.before[key] is Array else fixture.before[key]
		for i in state.turrets.size(): state.turrets[i].id = i+1
		state.nextTurretId = state.turrets.size()+1
		var expected_inputs: Array = fixture.after.statInputs
		if not expected_inputs.is_empty(): state.tileSize = float(expected_inputs[0].boardDistanceScale)*48.0
		var before := state.duplicate(true)
		var result: Dictionary = service.apply(state,fixture.command)
		check(state == before,fixture.name+": actual input immutable")
		check(result.ok == (fixture.before != fixture.after),fixture.name+": actual accepted")
		for key in ["gold","gemShards","phase","runUpgradeLevels"]:
			check(result.state[key] == fixture.after[key],fixture.name+": actual "+key)
		var turrets: Array = result.state.turrets.duplicate(true)
		for t in turrets: t.erase("id")
		check(_near(turrets,fixture.after.turrets),fixture.name+": actual turret save state")
		var commands: Array = service.runtime_commands(result.state)
		check(commands.size() == expected_inputs.size(),fixture.name+": actual stats count")
		for i in mini(commands.size(),expected_inputs.size()):
			var actual: Dictionary = Stats.resolve(commands[i].turret.statInput)
			var expected: Dictionary = Stats.resolve(expected_inputs[i])
			check(_near(actual,expected),fixture.name+": actual combat all levels and firing snapshot "+str(i))

func _reward_equip_cases(service, built: Dictionary) -> void:
	var state := built.duplicate(true)
	state.phase = "reward"
	state.rewardOptions = ["attackSpeed","range"]
	state.rewardReturnPhase = "wave"
	var id: int = state.turrets[0].id
	var before := state.duplicate(true)
	var command := {"kind":"chooseRewardGemEquip","type":"attackSpeed","id":id,"slot":0}
	var result: Dictionary = service.apply(state,command)
	check(result.ok and result.state.phase == "wave","reward equip resumes wave atomically")
	check(result.state.turrets[0].equippedGemSlots == ["attackSpeed"] and not result.state.gemInventory.has("attackSpeed"),"reward equip no inventory duplication")
	check(result.commands.size() == 1 and result.state.rewardOptions.is_empty(),"reward equip updates runtime and consumes choice")
	check(state == before,"reward equip input immutable")
	check(not service.apply(result.state,command).ok,"reward cannot settle twice")
	for change in [{"slot":-1},{"slot":99},{"id":-1},{"type":"missing"}]:
		var bad := command.duplicate()
		bad.merge(change,true)
		var failure: Dictionary = service.apply(state,bad)
		check(not failure.ok and failure.state == before and failure.commands.is_empty(),"invalid reward equip rolls back "+str(change))
	state.turrets[0].equippedGemSlots = ["range"]
	state.turrets[0].equippedGems = ["range"]
	result = service.apply(state,command)
	check(result.ok and result.state.gemInventory.get("range") == 1 and result.state.turrets[0].equippedGemSlots == ["attackSpeed"],"reward replacement returns old gem")
	state.turrets[0].equippedGemSlots = ["attackSpeed"]
	before = state.duplicate(true)
	result = service.apply(state,command)
	check(not result.ok and result.state == before,"duplicate gem preserves choice")
	state.rewardOptions = ["heavyWeapon"]
	command.type = "heavyWeapon"
	result = service.apply(state,command)
	check(not result.ok and result.state == state,"incompatible reward preserves choice")

func _reward_slot_purchase_cases(service, built: Dictionary) -> void:
	var state := built.duplicate(true)
	state.phase = "reward"
	state.rewardOptions = ["attackSpeed","range","heavyWeapon"]
	state.rewardReturnPhase = "wave"
	state.isPurchasedGemReward = true
	state.turrets[0].equippedGemSlots = ["range"]
	state.turrets[0].equippedGems = ["range"]
	var id: int = state.turrets[0].id
	var cost: int = service.quotes(state,id).link
	state.gold = cost
	var command := {"kind":"chooseRewardGemEquip","type":"attackSpeed","id":id,"slot":1,"buySlot":true}
	var before := state.duplicate(true)
	var result: Dictionary = service.apply(state,command)
	check(result.ok and result.state.gold == 0,"reward slot purchase uses exact quoted gold")
	check(result.state.turrets[0].investedGold == state.turrets[0].investedGold+cost,"reward slot purchase contributes refund investment")
	check(result.state.turrets[0].slotLimit == 2 and result.state.turrets[0].equippedGemSlots == ["range","attackSpeed"] and result.state.turrets[0].equippedGems == ["range","attackSpeed"],"reward slot purchase preserves old gem and equips new gem")
	check(result.state.gemInventory == state.gemInventory and state == before,"reward slot purchase preserves inventory and input")
	check(result.state.phase == "wave" and result.state.rewardOptions.is_empty() and not result.state.isPurchasedGemReward and result.state.rewardReturnPhase == null and result.commands.size() == 1,"reward slot purchase settles reward and runtime together")
	for change in [{"slot":-1},{"slot":0},{"slot":2},{"id":-1},{"type":"missing"},{"type":"range"},{"type":"heavyWeapon"}]:
		var bad := command.duplicate()
		bad.merge(change,true)
		_check_reward_slot_rejection(service,state,bad,"invalid purchase "+str(change))
	_check_reward_slot_rejection(service,state,{"kind":"link","id":id},"generic link remains blocked during reward")
	state.gold = cost-1
	_check_reward_slot_rejection(service,state,command,"insufficient purchase gold")
	state.gold = 100000
	state.phase = "preparation"
	_check_reward_slot_rejection(service,state,command,"purchase outside reward")
	state.phase = "reward"
	state.turrets[0].slotLimit = 2
	state.turrets[0].equippedGemSlots.append(null)
	command.slot = 2
	_check_reward_slot_rejection(service,state,command,"third slot level requirement")
	state.turrets[0].level = 5
	result = service.apply(state,command)
	check(result.ok and result.state.turrets[0].slotLimit == 3 and result.state.turrets[0].equippedGemSlots == ["range",null,"attackSpeed"] and result.state.gold == state.gold-int(service.quotes(state,id).link),"third slot unlock uses existing quote")
	state.turrets[0].slotLimit = int(service.derived(state).maxTurretLinkSlots)
	state.turrets[0].equippedGemSlots.resize(state.turrets[0].slotLimit)
	command.slot = state.turrets[0].slotLimit
	_check_reward_slot_rejection(service,state,command,"maximum slot requirement")

func _check_reward_slot_rejection(service, state: Dictionary, command: Dictionary, label: String) -> void:
	var before := state.duplicate(true)
	var result: Dictionary = service.apply(state,command)
	check(not result.ok and result.state == before and state == before and result.commands.is_empty(),label+": atomic rejection")


func _build_price_cache_checks(catalog, growth) -> void:
	var service := CountingCommands.new(catalog,growth)
	var state: Dictionary = service.initial_state()
	var configuration: Dictionary = service.derived(state)
	var previous := service.derive_calls
	for type in configuration.availableTurretTypes:
		var quote: int = service.build_cost_from_derived(type,configuration)
		check(service.derive_calls == previous, "UI price quote reuses derived configuration")
		check(quote == service.build_cost(state,type), "UI price matches fresh authoritative price")
		check(service.derive_calls == previous + 1, "authoritative build price derives exactly once")
		previous = service.derive_calls
	check(service.build_cost(state,"unsupported") == 0, "unknown turret price remains zero")

func _light_weapon_equip_cases(service, built: Dictionary) -> void:
	for type in service.catalog.turret_types():
		var allowed: bool = "light" in service.catalog.turret_definition(type).attackTags
		for kind in ["equipGem","chooseRewardGemEquip"]:
			for buy_slot in ([false,true] if kind == "chooseRewardGemEquip" else [false]):
				var state := built.duplicate(true)
				state.turrets[0].type = type
				state.turrets[0].equippedGemSlots = ["range"]
				state.turrets[0].equippedGems = ["range"]
				state.gemInventory = {"lightWeapon":2}
				state.gold = 100000
				if kind == "chooseRewardGemEquip":
					state.phase = "reward"
					state.rewardOptions = ["lightWeapon","attackSpeed","range"]
					state.rewardReturnPhase = "wave"
				var before := state.duplicate(true)
				var command := {"kind":kind,"type":"lightWeapon","id":state.turrets[0].id,"slot":1 if buy_slot else 0,"buySlot":buy_slot}
				var result: Dictionary = service.apply(state,command)
				var label: String = type+" "+kind+" buySlot="+str(buy_slot)
				check(result.ok == allowed,label+": only light attack tag can equip")
				check(state == before,label+": source immutable")
				if allowed:
					check("lightWeapon" in result.state.turrets[0].equippedGemSlots and result.commands.size() == 1,label+": accepted equipment reaches combat")
					check(result.state.gemInventory.lightWeapon == (1 if kind == "equipGem" else 2),label+": inventory charged exactly once")
				else:
					check(result.state == before and result.commands.is_empty(),label+": rejection preserves inventory, reward, slots and gold")
