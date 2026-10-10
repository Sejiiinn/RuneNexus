extends RefCounted
## Reusable legal-state combat fixture, NOT an economy or balance certification.
## A progressed account (all preceding stages cleared), capped permanent upgrades,
## 60,000 seeded run gold and 60 copies of each unlocked gem are explicit seeds.
## Every board, level, link, gem and run-upgrade purchase uses RunCommands.
## No enemy/turret damage, enemy HP, core HP or schedule overrides are permitted.
const Domain = preload("res://session/run_session.gd")
const SEED := 271828
const TILE_SIZE := 48.0
const START_GOLD := 60000
const TURRET_COUNT := 12

static func create(catalog, stage_id: int, round_number: int) -> Dictionary:
	var domain = Domain.new()
	domain.now_millis = func(): return 1791560000000
	var stage: int = catalog.stage_index(stage_id)
	var progression := {"growthVersion":1,"progressionVersion":1,"clearedStageNumbers":[],"researchLevels":{},"coreCombatSkill":null}
	for id in range(1,stage_id): progression.clearedStageNumbers.append(id)
	if not domain.initialize(catalog,progression,stage,stage_id): return {"error":domain.error}
	for key in domain.growth.data.permanentUpgrades:
		var definition: Dictionary = domain.growth.data.permanentUpgrades[key]
		if definition.get("enabled",true): domain.state.progression[definition.get("field",key+"UpgradeLevel")] = mini(30,int(definition.maxLevel))
	for key in domain.growth.data.research:
		domain.state.progression.researchLevels[key] = mini(3,int(domain.growth.data.research[key].maxLevel))
	domain.state.tileSize = TILE_SIZE
	domain.state.gold = START_GOLD
	domain.state.gemShards = 1000
	domain.state.roundIndex = round_number-1
	domain.state.completedRounds = round_number-1
	domain.state.runCoreCombatSkill = null
	var derived: Dictionary = domain.service.derived(domain.state)
	for gem in derived.availableGemTypes: domain.state.gemInventory[gem] = 60
	var commands: Array = []
	for type in ["towerDamage","killGold","waveGold"]:
		for count in range(10): commands.append({"kind":"runUpgrade","type":type})
	var map: Dictionary = catalog.stage_map(stage)
	var types: Array = derived.availableTurretTypes
	var placed := 0
	# Row-major build cells deliberately make placement reproducible on every map.
	for cell in map.tiles.size():
		if map.tiles[cell] != "build" or placed >= TURRET_COUNT: continue
		var type: String = types[placed % types.size()]
		var id := 1000+placed
		commands.append({"kind":"build","type":type,"x":cell%int(map.columns),"y":int(cell/int(map.columns))})
		for level in range(9): commands.append({"kind":"level","id":id})
		commands.append({"kind":"link","id":id})
		commands.append({"kind":"link","id":id})
		var compatible: Array = domain.growth.data.turretRules[type].compatibleGems
		var equipped := 0
		for gem in ["attackSpeed","range","damageAmplifier","physicalDamage","elementalDamage"]:
			if equipped >= 3: break
			if gem in compatible and gem in derived.availableGemTypes:
				commands.append({"kind":"equipGem","id":id,"type":gem,"slot":equipped})
				equipped += 1
		placed += 1
	for command in commands:
		var result: Dictionary = domain.apply(command)
		if not result.ok: return {"error":"fixture command rejected: "+str(command)+" "+domain.error}
	derived = domain.service.derived(domain.state)
	var bootstrap: Dictionary = catalog.bootstrap(stage,{"tileSize":TILE_SIZE,"defenseConfig":derived.defenseConfig,"coreConfig":domain.growth.core_config(domain.state,stage,round_number-1,catalog)})
	bootstrap.turrets = []
	for command in domain.service.runtime_commands(domain.state): bootstrap.turrets.append(command.turret)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + stage_id*100 + round_number
	var wave: Dictionary = catalog.wave(stage,round_number-1,100000,{"tileSize":TILE_SIZE,"spawnValues":catalog.random_spawn_values(stage,round_number-1,rng)})
	return {"domain":domain,"bootstrap":bootstrap,"wave":wave,"seed":rng.seed,"commandCount":commands.size(),"error":""}
