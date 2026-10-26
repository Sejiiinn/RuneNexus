extends SceneTree
const Slots = preload("res://app/gem_slot_rules.gd")
const Catalog = preload("res://content/content_catalog.gd")
const Offers = preload("res://app/gem_reroll.gd")
func _initialize() -> void:
	var catalog := Catalog.new()
	assert(catalog.load_catalog())
	var growth: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/growth_content.json"))
	assert("piercing" in growth.gems)
	var rules = load("res://app/growth_rules.gd").new()
	assert(rules.load_catalog())
	assert("piercing" in rules.derive({}).availableGemTypes,"available from initial gem pool")
	for type in growth.turretRules:
		var rule: Dictionary = growth.turretRules[type]
		var capabilities: Array = catalog.turret_definition(type).get("attackCapabilities",[])
		assert(rule.attackCapabilities == capabilities)
		assert("piercing" not in rule.compatibleGems)
		assert(Slots.is_compatible("piercing",rule)==("projectile" in capabilities))
	var future := {"attackCapabilities":["projectile"],"compatibleGems":[]}
	assert(Slots.is_compatible("piercing",future))
	assert(not Slots.is_compatible("piercing",{"compatibleGems":["piercing"]}))
	assert(not Slots.is_compatible("piercing",["piercing"]))
	assert(not Slots.can_equip({"equippedGemSlots":["piercing"]},"piercing",future))
	assert(Slots.is_compatible("armorPiercing",{"compatibleGems":["armorPiercing"]}))
	assert(Slots.requirement_text("piercing")=="장착 조건: 투사체")
	assert("piercing" in Offers.GEM_TYPES)
	for path in ["app_selection","hud_gem_panel","hud_turret_panel","hud_build_panel","battle_rewards"]:
		assert(load("res://ui/"+path+".gd").can_instantiate())
	print("PASS projectile gem content: capability tags, future tower, legacy guard, labels, duplicate equip and UI script loading")
	quit(0)
