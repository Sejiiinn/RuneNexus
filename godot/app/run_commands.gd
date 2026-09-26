extends RefCounted
## Pure run transactions. Callers commit state and submit commands together.
## Never reads/writes player saves or authoritative account currencies.
var catalog
var growth

func _init(content = null, growth_rules = null) -> void:
	catalog = content
	growth = growth_rules

func derived(state: Dictionary) -> Dictionary:
	var types := {}
	var gems := {}
	for t in state.get("turrets", []):
		types[t.type] = true
		for gem in t.get("equippedGemSlots", []):
			if gem != null: gems[gem] = true
	return growth.derive(state.get("progression", {}), {"distinctTurretTypeCount":types.size(), "distinctEquippedGemTypeCount":gems.size(), "runUpgradeLevels":state.get("runUpgradeLevels", {})})

func initial_state(progression: Dictionary = {}, stage: int = 0) -> Dictionary:
	var state := {"phase":"preparation", "stage":stage, "progression":progression.duplicate(true), "turrets":[], "gemInventory":{}, "runUpgradeLevels":{}, "nextTurretId":1000, "gold":0, "gemShards":0, "killGoldFractionWallet":0.0,"roundIndex":0,"completedRounds":0,"pendingEconomyDiamonds":0, "rewardOptions":[]}
	var d := derived(state)
	state.gold = int(d.get("initialGold", 160))
	state.gemShards = int(d.get("startingGemShards", 0))
	return state

func _rule(type: String) -> Dictionary:
	return growth.data.get("turretRules", {}).get(type, {})

func _module(state: Dictionary, type: String) -> Dictionary:
	return derived(state).get("turretStatInputs", {}).get(type, {}).get("moduleEffect", {})

func build_cost(state: Dictionary, type: String) -> int:
	if _rule(type).is_empty(): return 0
	return build_cost_from_derived(type, derived(state))

# UI quotes may reuse their configuration cache. Purchases use build_cost above
# to derive the current authoritative state again before accepting a command.
func build_cost_from_derived(type: String, configuration: Dictionary) -> int:
	var r := _rule(type)
	if r.is_empty(): return 0
	var base := int(r.buildCost)
	var module: Dictionary = configuration.get("turretStatInputs", {}).get(type, {}).get("moduleEffect", {})
	var discounted := maxi(roundi(base * (1.0 - clampf(float(module.get("buildCostDiscountRate",0)),0,0.8))), roundi(base * 0.8))
	return maxi(1, roundi(discounted * float(configuration.get("passiveTurretBuildCostMultiplier",1))))

func quotes(state: Dictionary, id: int) -> Dictionary:
	var t := turret(state,id)
	if t.is_empty(): return {}
	var d := derived(state)
	var r := _rule(t.type)
	var m := _module(state,t.type)
	var level := int(t.level)
	var slot := int(t.slotLimit)
	var level_discount := clampf(float(m.get("levelUpCostDiscountRate",0)) + (float(m.get("highLevelUpgradeCostDiscountRate",0)) if level >= 5 else 0.0),0,0.8)
	var link_discount := clampf(float(m.get("linkUpgradeCostDiscountRate",0)) + (float(d.get("firstLinkUpgradeDiscountRate",0)) if slot == 1 else 0.0),0,0.8)
	var level_base := int(r.levelUpCosts[mini(level-1,r.levelUpCosts.size()-1)])
	var link_base := int(r.linkUpgradeCosts[mini(slot-1,r.linkUpgradeCosts.size()-1)])
	return {"level":maxi(1,roundi(level_base*(1-level_discount)*float(d.get("passiveTurretLevelUpCostMultiplier",1))*float(d.get("permanentTurretLevelUpCostMultiplier",1)))) if level < int(r.get("maxLevel",10)) else 0,
		"link":maxi(1,roundi(link_base*(1-link_discount)*float(d.get("passiveTurretLinkCostMultiplier",1))*float(d.get("permanentLinkCostMultiplier",1)))) if slot < int(d.get("maxTurretLinkSlots",3)) and level >= (5 if slot >= 2 else 1) else 0,
		"sell":int(int(t.investedGold)*int(d.get("turretRefundPercent",50))/100),
		"primaryTrait":maxi(1,roundi(12*float(d.get("passiveTraitShardCostMultiplier",1)))), "secondaryTrait":maxi(1,roundi(24*float(d.get("passiveTraitShardCostMultiplier",1)))),
		"primaryTraits":r.get("primaryTraits",[]), "secondaryTraits":r.get("secondaryTraits",[])}

func turret(state: Dictionary, id: int) -> Dictionary:
	for t in state.get("turrets", []):
		if int(t.id) == id: return t
	return {}

func run_upgrade_quote(state: Dictionary, type: String) -> Dictionary:
	var r: Dictionary = growth.data.get("runUpgrades", {}).get(type,{})
	if r.is_empty(): return {}
	var d := derived(state)
	var level := int(state.get("runUpgradeLevels",{}).get(type,0))
	var maximum := int(r.maxLevel) + int(d.get("runUpgradeMaxLevelBonuses",{}).get(type,0))
	return {"level":level,"maxLevel":maximum,"cost":maxi(1,roundi(roundi(float(r.baseCost)*pow(float(r.costMultiplier),level))*float(d.get("runUpgradeCostMultiplier",1)))) if level < maximum else 0}

func runtime_commands(state: Dictionary) -> Array:
	var result: Array = []
	var d := derived(state)
	for t in state.turrets:
		var input: Dictionary = d.get("turretStatInputs",{}).get(t.type,{}).duplicate(true)
		input.merge({"level":t.level,"primaryTrait":t.primaryTrait,"secondaryTrait":t.secondaryTrait,"gems":t.equippedGemSlots.filter(func(g): return g != null)},true)
		var stat: Dictionary = catalog.turret(t.type,{"tileSize":state.get("tileSize",1.0),"statInput":input})
		result.append({"kind":"turret","turret":{"id":t.id,"position":[(float(t.x)+0.5)*float(state.get("tileSize",1.0)),(float(t.y)+0.5)*float(state.get("tileSize",1.0))],"state":t.duplicate(true),"statInput":stat}})
	return result

func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {"ok":false,"error":reason,"state":state,"commands":[]}

func apply(state: Dictionary, command: Dictionary) -> Dictionary:
	var kind := str(command.get("kind",""))
	if kind in ["chooseRewardGem","chooseRewardShards","chooseRewardGemEquip"]: return _choose_reward(state,command)
	if kind == "purchaseGemChoice": return _purchase_gem_choice(state)
	if state.get("phase", "") not in ["preparation","wave"]: return _reject(state,"phase")
	var next := state.duplicate(true)
	var t := turret(next,int(command.get("id",-1)))
	var removed := -1
	if kind == "build":
		var type := str(command.get("type",""))
		var cost := build_cost(state,type)
		if cost <= 0: return _reject(state,"type")
		var d := derived(state)
		if type not in d.get("availableTurretTypes",["arrow","cannon","magic","frost"]): return _reject(state,"locked")
		var x := int(command.get("x",-1))
		var y := int(command.get("y",-1))
		var map: Dictionary = catalog.stage(int(state.get("stage",0))).get("map",{})
		if x < 0 or y < 0 or x >= int(map.get("columns",0)) or y >= int(map.get("rows",0)) or map.tiles[y*int(map.columns)+x] != "build": return _reject(state,"tile")
		for placed in state.turrets:
			if placed.x == x and placed.y == y: return _reject(state,"occupied")
		if int(state.gold) < cost: return _reject(state,"gold")
		next.gold -= cost
		t = {"id":int(next.nextTurretId),"type":type,"x":x,"y":y,"level":1,"slotLimit":1,"equippedGemSlots":[null],"equippedGems":[],"primaryTrait":null,"secondaryTrait":null,"targetPriority":"first","investedGold":cost,"cooldown":0.0,"damageDealt":0.0,"directDamageDealt":0.0,"splashDamageDealt":0.0,"chainDamageDealt":0.0,"burnDamageDealt":0.0}
		next.nextTurretId += 1
		next.turrets.append(t)
	elif kind == "runUpgrade":
		var type := str(command.get("type",""))
		var q := run_upgrade_quote(state,type)
		if q.is_empty() or int(q.cost) <= 0: return _reject(state,"maxLevel")
		if int(next.gold) < int(q.cost): return _reject(state,"gold")
		next.gold -= int(q.cost)
		next.runUpgradeLevels[type] = int(q.level)+1
	else:
		if t.is_empty(): return _reject(state,"turret")
		var q := quotes(state,int(t.id))
		match kind:
			"level", "link":
				var cost := int(q[kind])
				if cost <= 0: return _reject(state,"requirement")
				if int(next.gold) < cost: return _reject(state,"gold")
				next.gold -= cost
				t.investedGold += cost
				if kind == "level": t.level += 1
				else:
					t.slotLimit += 1
					t.equippedGemSlots.append(null)
			"sell":
				next.gold += int(q.sell)
				for gem in t.equippedGemSlots:
					if gem != null: next.gemInventory[gem] = int(next.gemInventory.get(gem,0))+1
				removed = int(t.id)
				next.turrets.erase(t)
			"equipGem", "removeGem":
				var slot := int(command.get("slot",-1))
				if kind == "equipGem" and command.has("slot"):
					slot = clampi(slot,0,int(t.slotLimit)-1)
				if not command.has("slot") and kind == "equipGem":
					slot = t.equippedGemSlots.find(null)
					if slot < 0: slot = 0
				if slot < 0 or slot >= int(t.slotLimit): return _reject(state,"slot")
				var old = t.equippedGemSlots[slot]
				if kind == "equipGem":
					var gem := str(command.get("type",""))
					if int(next.gemInventory.get(gem,0)) <= 0: return _reject(state,"inventory")
					if gem in t.equippedGemSlots or gem not in _rule(t.type).get("compatibleGems",[]): return _reject(state,"gem")
					next.gemInventory[gem] -= 1
					if next.gemInventory[gem] == 0: next.gemInventory.erase(gem)
					t.equippedGemSlots[slot] = gem
				else:
					if old == null: return _reject(state,"emptySlot")
					t.equippedGemSlots[slot] = null
				if old != null: next.gemInventory[old] = int(next.gemInventory.get(old,0))+1
				t.equippedGems = t.equippedGemSlots.filter(func(g): return g != null)
			"primaryTrait", "secondaryTrait":
				var secondary := kind == "secondaryTrait"
				var trait_name := str(command.get("type",""))
				if t[kind] != null or int(t.level) < (7 if secondary else 3) or (secondary and t.primaryTrait == null) or trait_name not in q[kind+"s"]: return _reject(state,"trait")
				if int(next.gemShards) < int(q[kind]): return _reject(state,"gemShards")
				next.gemShards -= int(q[kind])
				t[kind] = trait_name
			"targetPriority":
				if not derived(state).get("canSetTurretTargetPriority",false): return _reject(state,"research")
				var priority := str(command.get("type",""))
				if priority not in ["first","last","strongest","weakest","nearest"]: return _reject(state,"priority")
				t.targetPriority = priority
			_: return _reject(state,"command")
	var commands := runtime_commands(next)
	if kind in ["primaryTrait","secondaryTrait"]: commands.append({"kind":"resetTraitState","id":t.id,"primary":kind == "primaryTrait"})
	if removed >= 0: commands.push_front({"kind":"removeTurret","id":removed})
	return {"ok":true,"error":"","state":next,"commands":commands}

func _success(state: Dictionary, commands: Array = []) -> Dictionary:
	return {"ok":true,"error":"","state":state,"commands":commands}

func award_kill(state: Dictionary, enemy: Dictionary) -> Dictionary:
	var result := award_kill_owned(state.duplicate(true), enemy, derived(state))
	return result if result.ok else _reject(state, result.error)

## Internal transaction path: only scalar wallet fields are changed after validation.
## d may be shared while progression growth inputs, turrets and upgrades stay fixed.
func award_kill_owned(state: Dictionary, enemy: Dictionary, d: Dictionary) -> Dictionary:
	var type := str(enemy.get("type", enemy.get("enemyType","")))
	var definition: Dictionary = catalog.data.get("enemyDefinitions",{}).get(type,{})
	if definition.is_empty(): return _reject(state,"enemy")
	var boss := bool(definition.get("isBoss",false))
	var base := int(definition.get("rewardGold",0))
	if base < 0: return _reject(state,"reward")
	var next := state
	var bonus := base * (float(d.get("killGoldBonusRate",0)) + (float(d.get("bossBountyBonusRate",0)) if boss else 0.0))
	var whole := floori(bonus)
	var wallet := float(next.get("killGoldFractionWallet",0)) + bonus - whole
	var paid := floori(wallet)
	next.killGoldFractionWallet = wallet - paid
	next.gold += base + whole + paid
	if boss: next.gemShards += int(d.get("bossKillGemShardBonus",0))
	next.pendingEconomyDiamonds = int(next.get("pendingEconomyDiamonds",0)) + maxi(0,int(enemy.get("diamondReward",0)))
	return _success(next)

func _reward_options(state: Dictionary) -> Array:
	var options: Array = derived(state).get("availableGemTypes",growth.data.get("gems",[])).duplicate()
	options.shuffle()
	return options.slice(0,mini(3,options.size()))

func complete_wave(state: Dictionary, wave_id: int) -> Dictionary:
	var stage: Dictionary = catalog.stage(int(state.stage))
	var index := int(state.get("roundIndex",0))
	if index < 0 or index >= stage.waves.size() or int(stage.waves[index].round) != wave_id: return _reject(state,"wave")
	if int(state.get("completedRounds",0)) >= index+1: return _reject(state,"completed")
	var next := state.duplicate(true)
	var d := derived(state)
	var base := int(stage.waves[index].get("clearRewardGold",0))
	next.gold += roundi((base+int(d.get("waveClearGoldBonus",0))) * float(d.get("roundClearGoldMultiplier",1)))
	var completed := index+1
	var rewards: Array = growth.data.get("roundShardRewards",[])
	next.gemShards += int(rewards[completed]) if completed < rewards.size() else 0
	next.roundIndex = completed
	next.completedRounds = completed
	next.rewardOptions = []
	next.isPurchasedGemReward = false
	next.rewardReturnPhase = null
	if completed >= stage.waves.size(): next.phase = "success"
	elif completed in growth.data.get("rewardRounds",[]):
		next.phase = "reward"
		next.rewardOptions = _reward_options(next)
	else: next.phase = "preparation"
	return _success(next)

func _purchase_gem_choice(state: Dictionary) -> Dictionary:
	if state.get("phase") not in ["wave","preparation"]: return _reject(state,"phase")
	var cost := int(growth.data.constants.gemChoicePurchaseCost)
	if int(state.gemShards) < cost: return _reject(state,"gemShards")
	var options := _reward_options(state)
	if options.is_empty(): return _reject(state,"gems")
	var next := state.duplicate(true)
	next.gemShards -= cost
	next.rewardReturnPhase = state.phase
	next.phase = "reward"
	next.isPurchasedGemReward = true
	next.rewardOptions = options
	return _success(next)

func _choose_reward(state: Dictionary, command: Dictionary) -> Dictionary:
	if state.get("phase") != "reward": return _reject(state,"phase")
	var next := state.duplicate(true)
	if command.kind == "chooseRewardShards":
		if state.get("isPurchasedGemReward",false): return _reject(state,"purchasedReward")
		next.gemShards += int(growth.data.constants.gemShardRewardFallbackAmount)
	else:
		var gem := str(command.get("type",""))
		if gem not in state.rewardOptions: return _reject(state,"reward")
		if command.kind == "chooseRewardGemEquip":
			var target := turret(next,int(command.get("id",-1)))
			if target.is_empty(): return _reject(state,"turret")
			var slot := int(command.get("slot",-1))
			var buy_slot := bool(command.get("buySlot",false))
			if buy_slot:
				if slot != int(target.slotLimit): return _reject(state,"slot")
			elif slot < 0 or slot >= int(target.slotLimit): return _reject(state,"slot")
			if gem in target.equippedGemSlots or gem not in _rule(target.type).get("compatibleGems",[]): return _reject(state,"gem")
			if buy_slot:
				var cost := int(quotes(state,int(target.id)).get("link",0))
				if cost <= 0: return _reject(state,"requirement")
				if int(state.gold) < cost: return _reject(state,"gold")
				next.gold -= cost
				target.investedGold += cost
				target.slotLimit += 1
				target.equippedGemSlots.append(null)
			var old = target.equippedGemSlots[slot]
			if old != null: next.gemInventory[old] = int(next.gemInventory.get(old,0))+1
			target.equippedGemSlots[slot] = gem
			target.equippedGems = target.equippedGemSlots.filter(func(g): return g != null)
		else:
			next.gemInventory[gem] = int(next.gemInventory.get(gem,0))+1
	next.phase = state.get("rewardReturnPhase") if state.get("rewardReturnPhase") != null else "preparation"
	next.rewardOptions = []
	next.rewardReturnPhase = null
	next.isPurchasedGemReward = false
	return _success(next,runtime_commands(next) if command.kind == "chooseRewardGemEquip" else [])

func refresh(state: Dictionary) -> Dictionary:
	return _success(state.duplicate(true),runtime_commands(state))
