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
	_reward_equip_cases(service,built.state)
	_reward_slot_purchase_cases(service,built.state)
	_game_cases(service)
	print("RUN_COMMANDS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)

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
