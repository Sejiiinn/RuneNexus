extends RefCounted
## Authoritative enemy state. Coordinates and distance use logical board pixels.
## Preserve discrete update order and discarded waypoint overshoot.
## Continuous damage integrates only the interval where each effect is active.

## Share of non-poison damage over time that enters the armor layer.
const DOT_ARMOR_FACTOR := 0.5
## Poison stacks are kept per source turret, each with its own timer.
const POISON_STACK_CAP := 20
## A source's poison deals this much more per active stack of that source.
const POISON_STACK_BONUS := 0.05
## Bosses resist this share of every slow.
const BOSS_SLOW_RESISTANCE := 0.5
const BOSS_TYPES := ["boss","shieldBoss","forgeBoss"]

static func create(raw: Dictionary) -> Dictionary:
	var e: Dictionary = raw.duplicate(true)
	var defaults := {"id":0,"maxHp":1.0,"maxShield":0.0,"maxArmor":0.0,"speed":0.0,"shieldRegenRate":0.0,"boardDistanceScale":1.0,"distanceTravelled":0.0,"targetIndex":1,"facingAngle":0.0,"shieldBroken":false,"arrived":false,"killReported":false,"burnInstances":[],"slowInstances":[],"firstControlApplied":false,"stunRemaining":0.0,"freezeRemaining":0.0,"poisonRemaining":0.0,"poisonDamagePerSecond":0.0,"poisonDamageMultiplier":1.0,"poisonStacks":0,"poisonInstances":[],"physicalVulnerabilityRemaining":0.0,"physicalVulnerabilityBonus":0.0,"elementalVulnerabilityRemaining":0.0,"elementalVulnerabilityBonus":0.0,"riftMarkRemaining":0.0,"riftMarkDamageAmplification":0.0,"burnNumberDamage":0.0,"burnNumberTimer":0.0,"poisonNumberDamage":0.0,"poisonNumberTimer":0.0,"hitFlashTimer":0.0,"statusEffectTime":0.0,"laneOffsetRatio":0.0,"visualPhase":0.0,"diamondReward":0,"path":[]}
	for key in defaults:
		if not e.has(key): e[key] = defaults[key]
	e.hp = clampf(float(e.get("hp",e.maxHp)),0,float(e.maxHp))
	e.shield = clampf(float(e.get("shield",0.0)),0,float(e.maxShield))
	e.armor = clampf(float(e.get("armor",0.0)),0,float(e.maxArmor))
	e.shieldBroken = e.maxShield > 0 and e.shieldBroken
	e.distanceTravelled = maxf(0,e.distanceTravelled)
	for key in ["stunRemaining","freezeRemaining","poisonRemaining","poisonDamagePerSecond","poisonDamageMultiplier","poisonStacks","physicalVulnerabilityRemaining","physicalVulnerabilityBonus","elementalVulnerabilityRemaining","elementalVulnerabilityBonus","riftMarkRemaining","riftMarkDamageAmplification"]:
		e[key] = maxf(0,float(e[key]))
	var slows: Array = e.slowInstances.duplicate(true)
	e.slowInstances = []
	for slow in slows: add_slow(e,float(slow.multiplier),float(slow.remaining))
	for burn in e.burnInstances:
		for key in ["remaining","damagePerSecond","damageMultiplier"]:
			burn[key] = maxf(0,float(burn.get(key,1.0 if key == "damageMultiplier" else 0.0)))
		burn["ignoreArmorReduction"] = burn.get("ignoreArmorReduction",false)
		burn["sourceX"] = burn.get("sourceX")
		burn["sourceY"] = burn.get("sourceY")
		if burn.has("damageOverTimeIncreaseMultiplier"):
			var increase := dot_increase_multiplier(burn.damageOverTimeIncreaseMultiplier)
			if increase == 1.0: burn.erase("damageOverTimeIncreaseMultiplier")
			else: burn.damageOverTimeIncreaseMultiplier = increase
	if e.burnInstances.is_empty() and float(e.get("burnRemaining",0)) > 0 and float(e.get("burnDamagePerSecond",0)) > 0:
		add_burn(e,{"remaining":e.burnRemaining,"damagePerSecond":e.burnDamagePerSecond,"damageMultiplier":e.get("burnDamageMultiplier",1.0)})
	var poisons: Array = e.poisonInstances
	e.poisonInstances = []
	for poison in poisons:
		if poison is Dictionary: add_poison(e,poison)
	_restore_legacy_poison(e)
	_rebuild_path(e,e.path)
	_place_at_distance(e,e.distanceTravelled)
	if raw.has("x") and raw.has("y"): _set_position(e,float(raw.x),float(raw.y))
	elif raw.has("position"): _set_position(e,float(raw.position.x),float(raw.position.y))
	if raw.has("targetIndex"): e.targetIndex = int(raw.targetIndex)
	if raw.has("facingAngle"): e.facingAngle = float(raw.facingAngle)
	_restore_teleport_exit(e)
	return e

static func _set_position(e: Dictionary,x: float,y: float) -> void:
	e.x=x
	e.y=y
	# The mirror is owned by this enemy (create deep-copies, snapshots deep-copy),
	# so moving rewrites it instead of allocating one per step.
	var p = e.get("position")
	if p is Dictionary and p.size() == 2 and p.has("x") and p.has("y"):
		p.x=x
		p.y=y
	else:
		e.position={"x":x,"y":y}

static func _px(p) -> float:
	return float(p[0]) if p is Array else float(p.x)

static func _py(p) -> float:
	return float(p[1]) if p is Array else float(p.y)

static func _rebuild_path(e: Dictionary,path: Array) -> void:
	e.erase("_path_revision")
	e.path = path.duplicate(true)
	e._ends=[]
	e._lengths=[]
	e._cumulative=[]
	e._total=0.0
	for i in range(1,path.size()):
		var dx := _px(path[i])-_px(path[i-1])
		var dy := _py(path[i])-_py(path[i-1])
		var length := sqrt(dx*dx+dy*dy)
		if length == 0: continue
		e._total += length
		e._ends.append(i)
		e._lengths.append(length)
		e._cumulative.append(e._total)

static func update_path(e: Dictionary,path: Array) -> void:
	if path.size()<2: return
	var ratio: float = 0.0 if e._total == 0 else clampf(e.distanceTravelled/e._total,0,1)
	_rebuild_path(e,path)
	e.distanceTravelled=e._total*ratio
	_place_at_distance(e,e.distanceTravelled)
	_restore_teleport_exit(e)

static func _place_at_distance(e: Dictionary,distance: float) -> void:
	if e.path.is_empty():
		_set_position(e,0,0)
		return
	var low := 0
	var high: int = e._cumulative.size()
	while low < high:
		var middle: int = low + ((high-low)>>1)
		if e._cumulative[middle] < distance: low=middle+1
		else: high=middle
	if low == e._ends.size():
		_set_position(e,_px(e.path[-1]),_py(e.path[-1]))
		e.targetIndex=e.path.size()-1
		return
	var end: int=e._ends[low]
	var start: float=0.0 if low==0 else e._cumulative[low-1]
	var ratio := clampf((distance-start)/e._lengths[low],0,1)
	var dx := _px(e.path[end])-_px(e.path[end-1])
	var dy := _py(e.path[end])-_py(e.path[end-1])
	_set_position(e,_px(e.path[end-1])+dx*ratio,_py(e.path[end-1])+dy*ratio)
	e.targetIndex=end
	e.facingAngle=atan2(dy,dx)

## Read-only sampling for lane presentation, reusing the movement path cache.
## It must not change position, facing or the next authoritative waypoint.
static func point_at_distance(e: Dictionary,distance: float) -> Vector2:
	if e.path.is_empty(): return Vector2.ZERO
	distance = maxf(0.0,distance)
	var low := 0
	var high: int = e._cumulative.size()
	while low < high:
		var middle: int = low + ((high-low)>>1)
		if e._cumulative[middle] < distance: low=middle+1
		else: high=middle
	if low == e._ends.size():
		return Vector2(_px(e.path[-1]),_py(e.path[-1]))
	var end: int = e._ends[low]
	var start: float = 0.0 if low == 0 else e._cumulative[low-1]
	var from := Vector2(_px(e.path[end-1]),_py(e.path[end-1]))
	var to := Vector2(_px(e.path[end]),_py(e.path[end]))
	return from.lerp(to,clampf((distance-start)/e._lengths[low],0.0,1.0))

static func _event(e: Dictionary,kind: String,details: Dictionary={}) -> Dictionary:
	var result := {"type":kind,"enemyId":e.id,"x":e.x,"y":e.y}
	result.merge(details,true)
	return result

## A negative armor factor selects the size-based hit formula. Ticks pass a
## fixed factor so small frame slices are never crushed by that formula.
static func _apply_layers(e: Dictionary,damage: float,ignore: bool,armor_factor: float=-1.0) -> float:
	var actual := 0.0
	if e.shield>0:
		var taken := minf(e.shield,damage)
		e.shield=maxf(0,e.shield-taken)
		actual+=taken
		damage-=taken
		if e.shield==0: e.shieldBroken=true
	if damage>0 and e.armor>0:
		damage=_armor_damage(e,damage,ignore,armor_factor)
		var taken := minf(e.armor,damage)
		e.armor=maxf(0,e.armor-taken)
		actual+=taken
		damage=maxf(0,damage-taken)
	if damage>0:
		var taken := minf(e.hp,damage)
		e.hp=maxf(0,e.hp-taken)
		actual+=taken
	return actual

static func _armor_damage(e: Dictionary,damage: float,ignore: bool,armor_factor: float) -> float:
	if ignore: return damage
	if armor_factor >= 0.0: return damage*armor_factor
	var pressure := sqrt(float(e.maxArmor))*3.0
	return damage*(0.12+0.88*damage/(damage+pressure))

## Same arithmetic as _apply_layers without mutating the enemy, so the rift-mark
## bonus baseline needs no copy of the whole enemy per hit.
static func _layer_damage(e: Dictionary,damage: float,ignore: bool,armor_factor: float) -> float:
	var actual := 0.0
	var shield := float(e.shield)
	if shield>0:
		var taken := minf(shield,damage)
		actual+=taken
		damage-=taken
	if damage>0 and e.armor>0:
		damage=_armor_damage(e,damage,ignore,armor_factor)
		var taken := minf(e.armor,damage)
		actual+=taken
		damage=maxf(0,damage-taken)
	if damage>0:
		actual+=minf(e.hp,damage)
	return actual

static func apply_hit(e: Dictionary,attack: Dictionary,target_multiplier: float=1.0) -> Dictionary:
	var result := {"actualDamage":0.0,"bonusDamage":0.0,"killed":false,"events":[]}
	# Target bonuses are applied once at impact/tick time, never baked into saved
	# DoT DPS. Core callers keep the neutral default.
	var damage := float(attack.get("damage",0.0)) * target_multiplier
	if damage<=0 or e.hp<=0 or e.arrived: return result
	var ignore := bool(attack.get("ignoreArmorReduction",false))
	var armor_factor := float(attack.get("armorFactor",-1.0))
	var amp: float = float(e.riftMarkDamageAmplification) if e.riftMarkRemaining>0 else 0.0
	var base := 0.0
	if amp>0: base=_layer_damage(e,damage,ignore,armor_factor)
	result.actualDamage=_apply_layers(e,damage*(1+amp),ignore,armor_factor)
	result.bonusDamage=maxf(0,result.actualDamage-base) if amp>0 else 0.0
	if e.hp<=0 and not e.killReported:
		e.killReported=true
		result.killed=true
		result.events.append(_event(e,"killed",{"burnTransfer":attack.get("burnTransfer",{})}))
	return result

static func add_slow(e: Dictionary,multiplier: float,duration: float) -> void:
	if not is_finite(multiplier) or multiplier<0 or multiplier>=1 or not is_finite(duration) or duration<=0: return
	for slow in e.slowInstances:
		if slow.multiplier==multiplier:
			slow.remaining=maxf(slow.remaining,duration)
			return
	e.slowInstances.append({"multiplier":multiplier,"remaining":duration})

## Shared successful-control gate for current slow and future stun/freeze attacks.
## Restoring slowInstances uses add_slow directly, never this application gate.
static func add_control(e: Dictionary, kind: String, duration: float, options: Dictionary = {}) -> bool:
	if kind not in ["slow", "stun", "freeze"] or e.hp <= 0.0 or e.arrived: return false
	if bool(e.get("controlImmune", false)) or kind in e.get("controlImmunities", []) or bool(e.get(kind + "Immune", false)): return false
	var multiplier := float(options.get("multiplier", 1.0))
	if kind == "slow" and (not is_finite(multiplier) or multiplier < 0.0 or multiplier >= 1.0): return false
	duration *= float(options.get("durationMultiplier", 1.0))
	if not is_finite(duration) or duration <= 0.0: return false
	if not bool(e.get("firstControlApplied", false)):
		duration *= maxf(1.0, float(options.get("firstControlDurationMultiplier", 1.0)))
	if not is_finite(duration) or duration <= 0.0: return false
	# Immunity and invalid/no-op controls do not consume the global first control.
	e.firstControlApplied = true
	if kind == "slow": add_slow(e, multiplier, duration)
	else: e[kind + "Remaining"] = maxf(float(e.get(kind + "Remaining", 0.0)), duration)
	return true

# Metadata is optional. Legacy baked DPS has no recoverable additive source
# layer, so it deliberately uses neutral1 rather than guessing from live gear.
static func dot_increase_multiplier(value: Variant) -> float:
	var multiplier := float(value)
	return multiplier if is_finite(multiplier) and multiplier >= 1.0 and multiplier <= 4.0 else 1.0

static func burn_damage_per_second(burn: Dictionary,training_rate: float=0.0) -> float:
	var dps := float(burn.get("damagePerSecond", 0.0))
	if training_rate <= 0.0: return dps
	return dps * (1.0 + training_rate / dot_increase_multiplier(burn.get("damageOverTimeIncreaseMultiplier", 1.0)))

static func add_burn(e: Dictionary,burn: Dictionary) -> void:
	var dps := float(burn.get("damagePerSecond",0))
	var duration := float(burn.get("duration",burn.get("remaining",0)))
	if dps<=0 or duration<=0: return
	var value := {"remaining":duration,"damagePerSecond":dps,"damageMultiplier":float(burn.get("damageMultiplier",1)),"sourceX":burn.get("sourceX"),"sourceY":burn.get("sourceY"),"ignoreArmorReduction":burn.get("ignoreArmorReduction",false)}
	var increase := dot_increase_multiplier(burn.get("damageOverTimeIncreaseMultiplier", 1.0))
	if increase != 1.0: value.damageOverTimeIncreaseMultiplier = increase
	if value.sourceX!=null and value.sourceY!=null:
		var source_burns: Array = []
		var same_layer: Dictionary = {}
		for b in e.burnInstances:
			if b.sourceX!=value.sourceX or b.sourceY!=value.sourceY: continue
			source_burns.append(b)
			value.remaining = maxf(value.remaining,b.remaining)
			value.damageMultiplier = maxf(value.damageMultiplier,b.damageMultiplier)
			value.ignoreArmorReduction = value.ignoreArmorReduction or b.ignoreArmorReduction
			if dot_increase_multiplier(b.get("damageOverTimeIncreaseMultiplier",1.0)) == increase:
				same_layer = b
		# A changed additive layer can reverse strength after a later purchase.
		# Retain those candidates but refresh the source's existing max lifetime,
		# display and armor flags together. Only one strongest candidate ticks.
		for b in source_burns:
			for key in ["remaining","damageMultiplier","ignoreArmorReduction"]: b[key] = value[key]
		if not same_layer.is_empty():
			same_layer.damagePerSecond = maxf(same_layer.damagePerSecond,value.damagePerSecond)
			return
	e.burnInstances.append(value)

static func burn_transfer(e: Dictionary,source: Dictionary,training_rate: float=0.0) -> Dictionary:
	var strongest: Dictionary={}
	for b in e.burnInstances:
		if b.sourceX!=source.get("x") or b.sourceY!=source.get("y") or b.remaining<=0: continue
		if strongest.is_empty() or burn_damage_per_second(b,training_rate)>burn_damage_per_second(strongest,training_rate) or (burn_damage_per_second(b,training_rate)==burn_damage_per_second(strongest,training_rate) and b.remaining>strongest.remaining): strongest=b
	return strongest.duplicate(true)

static func clear_burn_source(e: Dictionary,source: Dictionary) -> void:
	for b in e.burnInstances:
		if b.sourceX==source.get("x") and b.sourceY==source.get("y"):
			b.sourceX=null
			b.sourceY=null

## Adds one poison stack with its own timer. A new stack never refreshes older
## ones. At the source cap the stack with the least time left is replaced.
## Optional speed (K3) shortens the stack and raises its DPS, keeping its total.
static func add_poison(e: Dictionary,poison: Dictionary) -> void:
	var speed := maxf(0.000001,float(poison.get("speedMultiplier",1.0)))
	var dps := float(poison.get("damagePerSecond",0.0))*speed
	var duration := float(poison.get("duration",poison.get("remaining",0.0)))/speed
	if not is_finite(dps) or not is_finite(duration) or dps<=0 or duration<=0: return
	var value := {"remaining":duration,"damagePerSecond":dps,"damageMultiplier":maxf(0,float(poison.get("damageMultiplier",1.0))),"sourceX":poison.get("sourceX"),"sourceY":poison.get("sourceY")}
	var increase := dot_increase_multiplier(poison.get("damageOverTimeIncreaseMultiplier",1.0))
	if increase != 1.0: value.damageOverTimeIncreaseMultiplier = increase
	if poison.has("stackBonus"): value.stackBonus = float(poison.stackBonus)
	if bool(poison.get("corrosive", false)): value.corrosive = true
	var shortest := -1
	var count := 0
	for i in e.poisonInstances.size():
		var p: Dictionary = e.poisonInstances[i]
		if not _same_source(p,value): continue
		count += 1
		if shortest < 0 or p.remaining < e.poisonInstances[shortest].remaining: shortest = i
	if count >= POISON_STACK_CAP: e.poisonInstances.remove_at(shortest)
	e.poisonInstances.append(value)

# Old saves kept one scalar poison (DPS per stack, stack count, one timer).
# Convert it to detached stacks once; later snapshots never write it back.
static func _restore_legacy_poison(e: Dictionary) -> void:
	var stacks := mini(POISON_STACK_CAP,int(e.poisonStacks))
	if e.poisonInstances.is_empty() and e.poisonRemaining>0 and e.poisonDamagePerSecond>0:
		for i in stacks:
			add_poison(e,{"remaining":e.poisonRemaining,"damagePerSecond":e.poisonDamagePerSecond,"damageMultiplier":e.poisonDamageMultiplier,"damageOverTimeIncreaseMultiplier":e.get("poisonDamageOverTimeIncreaseMultiplier",1.0)})
	e.poisonRemaining=0.0
	e.poisonDamagePerSecond=0.0
	e.poisonDamageMultiplier=1.0
	e.poisonStacks=0
	e.erase("poisonDamageOverTimeIncreaseMultiplier")

static func is_boss(e: Dictionary) -> bool:
	return bool(e.get("isBoss",false)) or e.get("type","") in BOSS_TYPES

static func add_vulnerability(e: Dictionary,kind: String,bonus: float,duration: float) -> void:
	if kind not in ["physical","elemental"] or bonus<=0 or duration<=0: return
	var prefix := kind+"Vulnerability"
	e[prefix+"Bonus"]=maxf(e[prefix+"Bonus"],bonus)
	e[prefix+"Remaining"]=maxf(e[prefix+"Remaining"],duration)

static func add_rift_mark(e: Dictionary,amplification: float,duration: float) -> void:
	if amplification<=0 or duration<=0: return
	e.riftMarkDamageAmplification=maxf(e.riftMarkDamageAmplification,amplification)
	e.riftMarkRemaining=maxf(e.riftMarkRemaining,duration)

static func _dot_hit(e: Dictionary,attack: Dictionary,kind: String,events: Array,burn_step_dt: float=0.0,target_multiplier: float=1.0) -> float:
	# Continuous damage never uses the size-based hit formula and still consumes
	# shield/armor before HP. Poison passes armor fully; every other DoT enters
	# armor at a fixed factor unless its saved armor-piercing flag is set.
	if kind == "poison": attack["ignoreArmorReduction"] = true
	else: attack["armorFactor"] = DOT_ARMOR_FACTOR
	var result := apply_hit(e,attack,target_multiplier)
	if result.killed and kind == "burn":
		# Burn lifetimes advance after all active intervals have been resolved.
		# Retain the existing end-of-step transfer lifetime and independent copy.
		var transfer: Dictionary = attack.burnTransfer.duplicate(true)
		transfer.remaining = maxf(0,float(transfer.remaining)-burn_step_dt)
		result.events[0].burnTransfer = transfer
	events.append_array(result.events)
	if result.actualDamage>0:
		events.append(_event(e,"damage",{"kind":kind,"damage":result.actualDamage,"bonusDamage":result.bonusDamage,"sourceX":attack.get("sourceX"),"sourceY":attack.get("sourceY")}))
	return result.actualDamage

static func _same_source(a: Dictionary,b: Dictionary) -> bool:
	return a.sourceX==b.sourceX and a.sourceY==b.sourceY

# Each source turret contributes its own strongest burn, so different turrets
# stack while one turret's candidates never do. Burns detached by turret removal
# share the null source and keep the strongest-only rule among themselves.
# The latest source ticks first, matching the previous latest-instance tie break.
static func _tick_burns(e: Dictionary,dt: float,training_rate: float,target_multiplier: float,events: Array) -> void:
	var count: int = e.burnInstances.size()
	var single := true
	for i in range(1,count):
		if not _same_source(e.burnInstances[0],e.burnInstances[i]):
			single = false
			break
	if single:
		_tick_burn_source(e,e.burnInstances,dt,training_rate,target_multiplier,events)
		return
	var handled := PackedByteArray()
	handled.resize(count)
	for start in range(count-1,-1,-1):
		if handled[start] == 1: continue
		if e.hp <= 0: return
		var group: Array = []
		for i in range(start+1):
			if handled[i] == 0 and _same_source(e.burnInstances[start],e.burnInstances[i]):
				handled[i] = 1
				group.append(e.burnInstances[i])
		_tick_burn_source(e,group,dt,training_rate,target_multiplier,events)

static func _tick_burn_source(e: Dictionary,burns: Array,dt: float,training_rate: float,target_multiplier: float,events: Array) -> void:
	var elapsed := 0.0
	while elapsed < dt and e.hp > 0:
		var strongest: Dictionary = {}
		# Reverse traversal preserves the latest-instance tie break. We only
		# split when the strongest expires; hidden weaker expiries add no DPS.
		for i in range(burns.size()-1,-1,-1):
			var b: Dictionary = burns[i]
			if b.remaining > elapsed and (strongest.is_empty() or burn_damage_per_second(b,training_rate) > burn_damage_per_second(strongest,training_rate)):
				strongest = b
		if strongest.is_empty(): break
		var interval_end := minf(dt,float(strongest.remaining))
		var attack := {"damage":burn_damage_per_second(strongest,training_rate)*(interval_end-elapsed),
			"ignoreArmorReduction":strongest.ignoreArmorReduction,
			"sourceX":strongest.sourceX,"sourceY":strongest.sourceY,
			"burnTransfer":strongest}
		e.burnNumberDamage+=_dot_hit(e,attack,"burn",events,dt,target_multiplier)
		elapsed = interval_end

# Each source's stacks deal the sum of their DPS times the source stack bonus.
# Stacks expiring inside dt split the step, so both the sum and the bonus use
# only the stacks active in each slice and the result is independent of dt.
static func _tick_poisons(e: Dictionary,dt: float,training_rate: float,target_multiplier: float,events: Array) -> void:
	var count: int = e.poisonInstances.size()
	var handled := PackedByteArray()
	handled.resize(count)
	for start in range(count-1,-1,-1):
		if handled[start] == 1: continue
		if e.hp <= 0: return
		var group: Array = []
		for i in range(start+1):
			if handled[i] == 0 and _same_source(e.poisonInstances[start],e.poisonInstances[i]):
				handled[i] = 1
				group.append(e.poisonInstances[i])
		var damage := _poison_source_damage(group,dt,training_rate)
		if damage > 0:
			var first: Dictionary = group[0]
			e.poisonNumberDamage+=_dot_hit(e,{"damage":damage,"sourceX":first.sourceX,"sourceY":first.sourceY},"poison",events,0.0,target_multiplier)

static func _poison_source_damage(stacks: Array,dt: float,training_rate: float) -> float:
	var ends: Array = []
	for p in stacks: ends.append(minf(dt,float(p.remaining)))
	ends.sort()
	var damage := 0.0
	var elapsed := 0.0
	# 중첩 보너스는 출처(포탑)마다 하나: 그 포탑 특성이 정한 값, 없으면 기본 5%.
	var bonus := POISON_STACK_BONUS
	for p in stacks: bonus = maxf(bonus, float(p.get("stackBonus", POISON_STACK_BONUS)))
	for end in ends:
		if end <= elapsed: continue
		var active := 0
		var dps := 0.0
		for p in stacks:
			if p.remaining > elapsed:
				active += 1
				dps += float(p.damagePerSecond)*(1.0 + training_rate / dot_increase_multiplier(p.get("damageOverTimeIncreaseMultiplier",1.0)))
		damage += dps*(1.0 + bonus*active)*(end-elapsed)
		elapsed = end
	return damage

static func _max_poison_multiplier(e: Dictionary) -> float:
	var value := 1.0 if e.poisonInstances.is_empty() else 0.0
	for p in e.poisonInstances: value=maxf(value,p.damageMultiplier)
	return value

static func _max_burn_multiplier(e: Dictionary) -> float:
	var value := 1.0 if e.burnInstances.is_empty() else 0.0
	for b in e.burnInstances: value=maxf(value,b.damageMultiplier)
	return value

# Teleports preserve original-path progress, so v2 distance alone restores the
# exit without a new save field or replaying the entrance. Walking still discards
# waypoint overshoot exactly as the existing combat contract requires.
static func _waypoint_distance(e: Dictionary,index: int) -> float:
	var segment: int = e._ends.find(index)
	return float(e._cumulative[segment]) if segment >= 0 else 0.0

static func _face_after_exit(e: Dictionary,index: int) -> void:
	if index + 1 < e.path.size():
		e.facingAngle = atan2(_py(e.path[index+1])-_py(e.path[index]),_px(e.path[index+1])-_px(e.path[index]))

static func _restore_teleport_exit(e: Dictionary) -> void:
	for pair in e.get("teleportPairs",[]):
		var index := int(pair.exitIndex)
		if index < e.path.size() and int(e.targetIndex) == index and is_equal_approx(float(e.distanceTravelled),_waypoint_distance(e,index)):
			e.targetIndex = index+1
			_face_after_exit(e,index)

static func _teleport_at(e: Dictionary,index: int,events: Array) -> bool:
	for pair in e.get("teleportPairs",[]):
		if int(pair.entranceIndex) != index: continue
		var exit_index := int(pair.exitIndex)
		var from_x := float(e.x)
		var from_y := float(e.y)
		_set_position(e,_px(e.path[exit_index]),_py(e.path[exit_index]))
		e.distanceTravelled = _waypoint_distance(e,exit_index)
		e.targetIndex = exit_index+1
		e.teleportSerial = int(e.get("teleportSerial",0))+1
		_face_after_exit(e,exit_index)
		events.append(_event(e,"teleport",{"color":pair.color,"fromX":from_x,"fromY":from_y,"teleportSerial":e.teleportSerial}))
		if e.targetIndex >= e.path.size():
			e.arrived = true
			events.append(_event(e,"coreArrival"))
		return true
	return false

static func step(e: Dictionary,dt: float,path: Array=[],path_revision: int=-1,target_multiplier: float=1.0,training_rate: float=0.0) -> Array:
	var events: Array=[]
	if dt<0 or not is_finite(dt) or e.arrived: return events
	# 런타임은 경로 변경 번호를 전달한다. 기존 외부 호출은 내용 비교를 유지한다.
	if not path.is_empty() and (path_revision < 0 or int(e.get("_path_revision", -1)) != path_revision):
		if path != e.path: update_path(e,path)
		if path_revision >= 0: e._path_revision = path_revision
	e.hitFlashTimer=maxf(0,e.hitFlashTimer-dt)
	e.statusEffectTime+=dt
	if e.hp>0 and e.maxShield>0 and not e.shieldBroken and e.shield<e.maxShield and e.shieldRegenRate>0:
		e.shield=minf(e.maxShield,e.shield+e.maxShield*e.shieldRegenRate*dt)
	# Regenerating affix; absent on ordinary enemies, so no per-step key lookup cost there.
	if e.has("hpRegenRate") and e.hp>0 and e.hp<e.maxHp:
		e.hp=minf(e.maxHp,e.hp+e.maxHp*float(e.hpRegenRate)*dt)
	if not e.burnInstances.is_empty():
		e.burnNumberTimer+=dt
		_tick_burns(e,dt,training_rate,target_multiplier,events)
		# Rebuild the list only when an instance expired this step.
		var burn_expired := false
		for b in e.burnInstances:
			b.remaining=maxf(0,b.remaining-dt)
			if not b.remaining>0: burn_expired=true
		if burn_expired: e.burnInstances=e.burnInstances.filter(func(b): return b.remaining>0)
		if e.hp>0 and (e.burnNumberTimer>=0.28 or e.burnInstances.is_empty()) and e.burnNumberDamage>0:
			events.append(_event(e,"damageNumber",{"kind":"burn","damage":e.burnNumberDamage,"damageMultiplier":_max_burn_multiplier(e)}))
			e.burnNumberDamage=0.0
			e.burnNumberTimer=0.0
	if not e.poisonInstances.is_empty():
		e.poisonNumberTimer+=dt
		var display_multiplier := _max_poison_multiplier(e)
		_tick_poisons(e,dt,training_rate,target_multiplier,events)
		var poison_expired := false
		for p in e.poisonInstances:
			p.remaining=maxf(0,p.remaining-dt)
			if not p.remaining>0: poison_expired=true
		if poison_expired: e.poisonInstances=e.poisonInstances.filter(func(p): return p.remaining>0)
		if e.hp>0 and (e.poisonNumberTimer>=0.5 or e.poisonInstances.is_empty()):
			events.append(_event(e,"damageNumber",{"kind":"poison","damage":e.poisonNumberDamage,"damageMultiplier":display_multiplier}))
			e.poisonNumberDamage=0.0
			e.poisonNumberTimer=0.0
		if e.poisonInstances.is_empty():
			e.poisonNumberDamage=0.0
			e.poisonNumberTimer=0.0
	var hard_controlled_time := minf(dt, maxf(float(e.stunRemaining), float(e.freezeRemaining)))
	e.stunRemaining = maxf(0.0, float(e.stunRemaining) - dt)
	e.freezeRemaining = maxf(0.0, float(e.freezeRemaining) - dt)
	if not e.slowInstances.is_empty():
		var slow_expired := false
		for slow in e.slowInstances:
			slow.remaining-=dt
			if not slow.remaining>0: slow_expired=true
		if slow_expired: e.slowInstances=e.slowInstances.filter(func(s): return s.remaining>0)
	# Fixed fields avoid assembling keys for every enemy at every 60 Hz step.
	# Keep physical -> elemental -> rift expiry after continuous damage.
	if e.physicalVulnerabilityRemaining>0:
		e.physicalVulnerabilityRemaining=maxf(0,e.physicalVulnerabilityRemaining-dt)
		if e.physicalVulnerabilityRemaining==0: e.physicalVulnerabilityBonus=0.0
	if e.elementalVulnerabilityRemaining>0:
		e.elementalVulnerabilityRemaining=maxf(0,e.elementalVulnerabilityRemaining-dt)
		if e.elementalVulnerabilityRemaining==0: e.elementalVulnerabilityBonus=0.0
	if e.riftMarkRemaining>0:
		e.riftMarkRemaining=maxf(0,e.riftMarkRemaining-dt)
		if e.riftMarkRemaining==0: e.riftMarkDamageAmplification=0.0
	if e.hp<=0 or int(e.targetIndex)>=e.path.size(): return events
	# Includes a portal at the spawn waypoint, without advancing a paused frame.
	if dt > 0 and not e.get("teleportPairs",[]).is_empty():
		var previous := int(e.targetIndex)-1
		if previous >= 0 and is_equal_approx(float(e.distanceTravelled),_waypoint_distance(e,previous)) and _teleport_at(e,previous,events): return events
	var target = e.path[int(e.targetIndex)]
	var dx := _px(target)-float(e.x)
	var dy := _py(target)-float(e.y)
	var distance := sqrt(dx*dx+dy*dy)
	if distance>0.001: e.facingAngle=atan2(dy,dx)
	var multiplier := 1.0
	for slow in e.slowInstances: multiplier=minf(multiplier,slow.multiplier)
	# Steadfast affix and bosses reduce only the slowed share; stun/freeze stay intact.
	if multiplier<1.0:
		var resistance := float(e.get("slowResistance",0.0))
		if is_boss(e): resistance = maxf(resistance,BOSS_SLOW_RESISTANCE)
		if resistance>0.0: multiplier=1.0-(1.0-multiplier)*(1.0-resistance)
	var movement: float=e.speed*e.boardDistanceScale*multiplier*maxf(0.0,dt-hard_controlled_time)
	if distance<=movement:
		e.distanceTravelled+=distance
		_set_position(e,_px(target),_py(target))
		e.targetIndex+=1
		if dt > 0 and _teleport_at(e,int(e.targetIndex)-1,events): return events
		if e.targetIndex>=e.path.size():
			e.arrived=true
			events.append(_event(e,"coreArrival"))
	else:
		_set_position(e,e.x+dx/distance*movement,e.y+dy/distance*movement)
		e.distanceTravelled+=movement
	return events

static func snapshot(e: Dictionary) -> Dictionary:
	var result: Dictionary=e.duplicate(true)
	for key in ["_ends","_lengths","_cumulative","_total","_path_revision"]: result.erase(key)
	result.burnRemaining=0.0
	result.burnDamagePerSecond=0.0
	for b in e.burnInstances:
		result.burnRemaining=maxf(result.burnRemaining,b.remaining)
		result.burnDamagePerSecond=maxf(result.burnDamagePerSecond,b.damagePerSecond)
	result.burnDamageMultiplier=_max_burn_multiplier(e)
	return result
