extends RefCounted
## Fixed save IDs and display/progression order are separate contracts.
const Registry = preload("res://content/generated_progression.gd")
const VERSION := Registry.VERSION
const ORDER := Registry.ORDER
const REQUIREMENTS := Registry.REQUIREMENTS
const LEGACY_REQUIREMENTS := Registry.LEGACY_REQUIREMENTS
static func ordered_ids() -> Array:
	return ORDER.duplicate()
static func ordinal_for(id: int) -> int:
	return ORDER.find(id) + 1
static func chapter_for(id: int) -> int:
	return int(Registry.STAGES.get(id,{}).get("chapter",0))
static func chapter_stage_for(id: int) -> int:
	return int(Registry.STAGES.get(id,{}).get("chapterStage",0))
static func unlock_items(id: int) -> Array:
	return Registry.UNLOCKS.get(id,[]).duplicate(true)
static func reward_icons(id: int) -> Array:
	return Registry.REWARD_ICONS.get(id,[]).duplicate()
static func stage_label(id: int) -> String:
	return "%d-%d" % [chapter_for(id),chapter_stage_for(id)]
static func ids_for_chapter(chapter: int) -> Array:
	return ORDER.filter(func(id): return chapter_for(id) == chapter)
static func requirement(kind: String, key: String) -> int:
	return int(REQUIREMENTS.get(kind,{}).get(key,0))
static func _legacy_unlock(p: Dictionary, kind: String, key: String) -> bool:
	var cleared: Array = p.get("clearedStageNumbers",[])
	if kind == "core": return key == "guardianBeam" or (key == "riftMark" and (int(p.get("unlockedStageCount",1)) >= 6 or p.get("coreCombatSkill") == "riftMark"))
	var old: Dictionary = LEGACY_REQUIREMENTS.get(kind,{})
	if kind == "gem" and not old.has(key): return true
	if not old.has(key): return false
	if int(old[key]) == 0 or int(old[key]) in cleared: return true
	if kind == "upgrade" and int(p.get(key+"UpgradeLevel",0)) > 0: return true
	if kind == "research":
		if int(p.get("researchLevels",{}).get(key,0)) > 0 or int(p.get("researchElapsedMillis",{}).get(key,0)) > 0: return true
		for active in p.get("activeResearches",[]):
			if active.get("type") == key: return true
	if kind == "feature" and key == "researchSlotTwoPreview" and 10 in cleared: return true
	if kind == "feature" and key.begins_with("researchSlotTwo") and p.get("researchSlotTwoUnlocked",false): return true
	return false
static func has_unlock(p: Dictionary, kind: String, key: String) -> bool:
	if kind == "upgrade" and key in ["criticalChance","emergencySale"]: return false
	if kind == "gem" and not REQUIREMENTS.gem.has(key): return true
	if not REQUIREMENTS.get(kind,{}).has(key): return false
	if kind == "research" and key == "linkExpansionTwo": return requirement(kind,key) in p.get("clearedStageNumbers",[])
	if kind+":"+key in p.get("grandfatherUnlocks",[]): return true
	if int(p.get("progressionVersion",0)) < VERSION and _legacy_unlock(p,kind,key): return true
	var required := requirement(kind,key)
	return required == 0 or required in p.get("clearedStageNumbers",[])
static func stage_unlocked(p: Dictionary, id: int) -> bool:
	var ordinal := ordinal_for(id)
	if ordinal <= 0: return false
	if id == 1 or id in p.get("unlockedStageIds",[]) or id in p.get("clearedStageNumbers",[]): return true
	if int(p.get("progressionVersion",0)) < VERSION and id <= clampi(int(p.get("unlockedStageCount",1)),1,Registry.LEGACY_STAGE_COUNT): return true
	return ORDER[ordinal-2] in p.get("clearedStageNumbers",[])
static func migrate_progression(p: Dictionary, run_evidence: Dictionary = {}, inventory: Dictionary = {}) -> Dictionary:
	var out := p.duplicate(true)
	var ids: Array = []
	for id in p.get("unlockedStageIds",[]):
		if id in ORDER and not id in ids: ids.append(id)
	if not 1 in ids: ids.append(1)
	var rights: Array = []
	for right in p.get("grandfatherUnlocks",[]):
		if right is String and not right in rights: rights.append(right)
	if int(p.get("progressionVersion",0)) < VERSION:
		for id in range(1,clampi(int(p.get("unlockedStageCount",1)),1,Registry.LEGACY_STAGE_COUNT)+1):
			if not id in ids: ids.append(id)
		for kind in REQUIREMENTS:
			for key in REQUIREMENTS[kind]:
				if _legacy_unlock(p,kind,key) and not kind+":"+key in rights: rights.append(kind+":"+key)
		# Existing acquired run equipment and server module items are evidence of
		# an old entitlement, never new currency or an ownership grant.
		for turret in run_evidence.get("turrets",[]) + inventory.get("items",[]):
			var type := str(turret.get("type",turret.get("turretType","")))
			if REQUIREMENTS.turret.has(type) and not "turret:"+type in rights: rights.append("turret:"+type)
			for gem in turret.get("equippedGemSlots",[]) + turret.get("equippedGems",[]):
				if gem in REQUIREMENTS.gem and not "gem:"+str(gem) in rights: rights.append("gem:"+str(gem))
		for gem in run_evidence.get("gemInventory",{}):
			if gem in REQUIREMENTS.gem and int(run_evidence.gemInventory[gem]) > 0 and not "gem:"+gem in rights: rights.append("gem:"+gem)
		for gem in run_evidence.get("rewardOptions",[]):
			if gem in REQUIREMENTS.gem and not "gem:"+str(gem) in rights: rights.append("gem:"+str(gem))
		if run_evidence.get("runCoreCombatSkill") == "riftMark" and not "core:riftMark" in rights: rights.append("core:riftMark")
	for id in ORDER:
		if stage_unlocked(p,id) and not id in ids: ids.append(id)
	ids.sort()
	rights.sort()
	out.progressionVersion = VERSION
	out.unlockedStageIds = ids
	out.grandfatherUnlocks = rights
	# Legacy scalar remains a compatibility field, never an expansion ID gate.
	out.unlockedStageCount = maxi(int(p.get("unlockedStageCount",1)),ids.size())
	_migrate_growth(out)
	return out
static func reward_ordinal(id: int) -> int:
	# Every map uses the same logical progression order for future run rewards.
	return ordinal_for(id)

static func _migrate_growth(p: Dictionary) -> void:
	if int(p.get("growthVersion",0)) >= 1: return
	var levels: Dictionary = p.get("researchLevels",{}).duplicate()
	levels["criticalChance"] = maxi(int(levels.get("criticalChance",0)),clampi(int(ceil(float(p.get("criticalChanceUpgradeLevel",0))/2.0)),0,10))
	levels["emergencySale"] = maxi(int(levels.get("emergencySale",0)),clampi(int(p.get("emergencySaleUpgradeLevel",0)),0,5))
	var bounty := int(levels.get("bossBounty",0))
	for active in p.get("activeResearches",[]):
		if active.get("type") == "bossBounty": bounty = maxi(bounty,int(active.get("targetLevel",0)))
	p.bossBountyUpgradeLevel = maxi(int(p.get("bossBountyUpgradeLevel",0)),clampi(bounty,0,40))
	levels.erase("bossBounty")
	p.researchLevels = levels
	p.activeResearches = p.get("activeResearches",[]).filter(func(active): return active.get("type") != "bossBounty")
	var elapsed: Dictionary = p.get("researchElapsedMillis",{}).duplicate()
	elapsed.erase("bossBounty")
	p.researchElapsedMillis = elapsed
	p.erase("criticalChanceUpgradeLevel")
	p.erase("emergencySaleUpgradeLevel")
	p.growthVersion = 1
	for key in ["criticalChance","emergencySale"]:
		if int(levels.get(key,0)) > 0 and not "research:"+key in p.grandfatherUnlocks: p.grandfatherUnlocks.append("research:"+key)
	if p.bossBountyUpgradeLevel > 0 and not "upgrade:bossBounty" in p.grandfatherUnlocks: p.grandfatherUnlocks.append("upgrade:bossBounty")
	p.grandfatherUnlocks.sort()
