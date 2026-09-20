extends RefCounted
## Exact CoreCombatSkillController timer order; target/damage execution is injected.
var configured: bool = false
var config: Dictionary = {}
var skill = null
var cooldown: float = 0
var guardian_beam_active_remaining: float = 0
var guardian_beam_tick_timer: float = 0
var guardian_beam_tick_damage: float = 0
var attack_sync_remaining: float = 0
var activation_count: int = 0
var direct_damage_dealt: float = 0
var bonus_damage_dealt: float = 0
var emergency_charge_used_this_round: bool = false

func configure(raw: Dictionary, restore: Dictionary = {}) -> void:
	var was_configured := configured
	configured = true
	config = raw.duplicate(true)
	skill = config.get("runSkill", config.get("skill"))
	if not was_configured:
		reset_cycle()
	if not restore.is_empty():
		restore_state(restore)

func restore_state(raw: Dictionary) -> void:
	skill = raw.get("skill", raw.get("runSkill", skill))
	cooldown = maxf(0, raw.get("cooldown", interval()))
	guardian_beam_active_remaining = maxf(0, raw.get("guardianBeamActiveRemaining", 0))
	guardian_beam_tick_timer = float(raw.get("guardianBeamTickTimer", 0))
	guardian_beam_tick_damage = maxf(0, raw.get("guardianBeamTickDamage", 0))
	attack_sync_remaining = maxf(0, raw.get("attackSyncRemaining", 0))
	activation_count = maxi(0, int(raw.get("activationCount", 0)))
	direct_damage_dealt = maxf(0, raw.get("directDamageDealt", 0))
	bonus_damage_dealt = maxf(0, raw.get("bonusDamageDealt", 0))
	emergency_charge_used_this_round = bool(raw.get("emergencyChargeUsedThisRound", false))

func interval() -> float:
	var recovery := maxf(0.000001, config.get("cooldownRecoveryMultiplier", 1.0))
	if skill == "guardianBeam": return float(config.get("guardianBeamInterval", 5.0)) / recovery
	if skill == "riftMark": return float(config.get("riftMarkInterval", 10.0)) / recovery
	return 0.0

func reset_cycle() -> void:
	cooldown = interval()
	guardian_beam_active_remaining = 0
	guardian_beam_tick_timer = 0
	guardian_beam_tick_damage = 0
	attack_sync_remaining = 0
	emergency_charge_used_this_round = false

func power_for_activation(number: int) -> float:
	return float(config.get("powerMultiplier", 1.0)) * (float(config.get("powerEveryThirdMultiplier", 1.0)) if number > 0 and number % 3 == 0 else 1.0)

func activate() -> float:
	activation_count += 1
	attack_sync_remaining = float(config.get("attackSyncDuration", 2.0))
	return power_for_activation(activation_count)

func emergency_charge(recovery_rate: float) -> bool:
	if emergency_charge_used_this_round or skill == null or guardian_beam_active_remaining > 0 or cooldown <= 0 or recovery_rate <= 0 or interval() <= 0:
		return false
	cooldown = maxf(0, cooldown - interval() * recovery_rate)
	emergency_charge_used_this_round = true
	return true

func update(dt: float, has_target: Callable, base_damage: Callable, beam_tick: Callable, rift: Callable) -> void:
	if not configured or dt <= 0: return
	attack_sync_remaining = maxf(0, attack_sync_remaining - dt)
	if skill == null:
		reset_cycle()
		return
	if skill == "riftMark":
		guardian_beam_active_remaining = 0
		guardian_beam_tick_timer = 0
		guardian_beam_tick_damage = 0
		cooldown = maxf(0, cooldown-dt)
		if cooldown <= 0 and bool(has_target.call()):
			# Candidate validation precedes activation; an empty field consumes none.
			var power := activate()
			rift.call(power)
			cooldown = interval()
		return
	if skill != "guardianBeam": return
	if guardian_beam_active_remaining > 0:
		_update_active(dt, beam_tick)
		return
	cooldown = maxf(0, cooldown-dt)
	if cooldown > 0 or not bool(has_target.call()): return
	guardian_beam_active_remaining = float(config.get("guardianBeamDuration", 1.0))
	guardian_beam_tick_timer = 0
	# Read DPS before activate(), after the old attack-sync timer has expired.
	var damage := float(base_damage.call())
	var power := activate()
	guardian_beam_tick_damage = damage * power / (float(config.get("guardianBeamDuration", 1.0)) / float(config.get("guardianBeamTickInterval", 0.1)))
	_update_active(0, beam_tick)

func _update_active(dt: float, beam_tick: Callable) -> void:
	guardian_beam_active_remaining = maxf(0, guardian_beam_active_remaining-dt)
	guardian_beam_tick_timer -= dt
	while guardian_beam_tick_timer <= 0 and guardian_beam_active_remaining > 0:
		guardian_beam_tick_timer += float(config.get("guardianBeamTickInterval", 0.1))
		beam_tick.call(guardian_beam_tick_damage)
	if guardian_beam_active_remaining <= 0:
		cooldown = interval()
		guardian_beam_tick_timer = 0
		guardian_beam_tick_damage = 0

func snapshot() -> Dictionary:
	var duration := float(config.get("guardianBeamDuration", 1.0))
	var tick := float(config.get("guardianBeamTickInterval", 0.1))
	return {"skill":skill,"cooldown":cooldown,"guardianBeamActiveRemaining":guardian_beam_active_remaining,"guardianBeamTickTimer":guardian_beam_tick_timer,"guardianBeamTickDamage":guardian_beam_tick_damage,"attackSyncRemaining":attack_sync_remaining,"activationCount":activation_count,"directDamageDealt":direct_damage_dealt,"bonusDamageDealt":bonus_damage_dealt,"emergencyChargeUsedThisRound":emergency_charge_used_this_round,"cooldownInterval":interval(),"guardianBeamActiveDamage":guardian_beam_tick_damage*duration/tick if tick>0 else 0.0}
