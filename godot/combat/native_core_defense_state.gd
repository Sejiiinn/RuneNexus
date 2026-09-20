extends RefCounted
## Nexus durability and round defense, independent from the offensive core skill.
var configured: bool = false
var config: Dictionary = {}
var hp: float = 0.0
var max_hp: float = 0.0
var round_hp_lost: float = 0.0
var final_defense_used_this_round: bool = false
var emergency_charge_used_this_round: bool = false
var failed: bool = false

func configure(raw: Dictionary, state: Dictionary = {}) -> void:
	var was_configured := configured
	configured = true
	config = raw.duplicate(true)
	max_hp = maxf(0,float(config.get("maxHp",0)))
	if not state.is_empty():
		restore(state)
	else:
		hp = clampf(hp if was_configured else max_hp,0,max_hp)

func restore(state: Dictionary) -> void:
	hp = clampf(float(state.get("hp",max_hp)),0,max_hp)
	round_hp_lost = maxf(0,float(state.get("roundHpLost",0)))
	final_defense_used_this_round = bool(state.get("finalDefenseUsedThisRound",false))
	emergency_charge_used_this_round = bool(state.get("emergencyChargeUsedThisRound",false))
	failed = bool(state.get("failed",false)) or hp<=0

func reset_round() -> void:
	round_hp_lost = 0.0
	final_defense_used_this_round = false
	emergency_charge_used_this_round = false

func arrive(enemy: Dictionary, is_boss: bool, emergency: Callable) -> Dictionary:
	var result := {"damage":0.0,"prevented":false,"defeated":false,"emergencyCharged":false}
	if not configured or failed or bool(enemy.get("isDebug",false)):
		return result
	if bool(config.get("hasFinalDefense",false)) and not is_boss and not final_defense_used_this_round:
		final_defense_used_this_round = true
		result.prevented = true
		return result
	var max_durability := float(enemy.get("maxHp",0))+float(enemy.get("maxShield",0))+float(enemy.get("maxArmor",0))
	var current := float(enemy.get("hp",0))+maxf(0,float(enemy.get("shield",0)))+maxf(0,float(enemy.get("armor",0)))
	var lost_ratio := 0.0 if max_durability<=0 else clampf(1.0-current/max_durability,0,1)
	var multiplier := (1.0-float(config.get("impactDispersionRate",0)))*(1.0-float(config.get("threatWeakeningRate",0))*lost_ratio)
	var incoming := float(enemy.get("coreDamage",0))*multiplier
	var before := hp
	hp = maxf(0.0,hp-incoming)
	result.damage = before-hp
	if result.damage>0:
		round_hp_lost += result.damage
		if not emergency_charge_used_this_round and bool(emergency.call(float(config.get("emergencyRecoveryRate",0)))):
			emergency_charge_used_this_round = true
			result.emergencyCharged = true
	if hp<=0:
		failed = true
		result.defeated = true
	return result

func recover_round() -> float:
	if not configured: return 0.0
	var recovered := 0.0
	if not failed and hp>0 and hp<max_hp:
		var amount := max_hp*float(config.get("roundRecoveryRate",0))+round_hp_lost*float(config.get("damageRestorationRate",0))
		if amount>0:
			var before := hp
			hp = minf(max_hp,hp+amount)
			recovered = hp-before
	reset_round()
	return recovered

func snapshot() -> Dictionary:
	return {"hp":hp,"maxHp":max_hp,"roundHpLost":round_hp_lost,"finalDefenseUsedThisRound":final_defense_used_this_round,"emergencyChargeUsedThisRound":emergency_charge_used_this_round,"failed":failed}
