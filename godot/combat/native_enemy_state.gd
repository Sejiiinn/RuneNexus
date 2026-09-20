extends RefCounted
## Authoritative enemy state. Coordinates and distance use logical board pixels.
## Preserve EnemyComponent's discrete frame order, including discarded waypoint
## overshoot and poison's full-dt final tick (burn instead clips its lifetime).

static func create(raw: Dictionary) -> Dictionary:
	var e: Dictionary = raw.duplicate(true)
	var defaults := {"id":0,"maxHp":1.0,"maxShield":0.0,"maxArmor":0.0,"speed":0.0,"shieldRegenRate":0.0,"boardDistanceScale":1.0,"distanceTravelled":0.0,"targetIndex":1,"facingAngle":0.0,"shieldBroken":false,"arrived":false,"killReported":false,"burnInstances":[],"slowInstances":[],"poisonRemaining":0.0,"poisonDamagePerSecond":0.0,"poisonDamageMultiplier":1.0,"poisonStacks":0,"physicalVulnerabilityRemaining":0.0,"physicalVulnerabilityBonus":0.0,"elementalVulnerabilityRemaining":0.0,"elementalVulnerabilityBonus":0.0,"riftMarkRemaining":0.0,"riftMarkDamageAmplification":0.0,"burnNumberDamage":0.0,"burnNumberTimer":0.0,"poisonNumberDamage":0.0,"poisonNumberTimer":0.0,"hitFlashTimer":0.0,"statusEffectTime":0.0,"laneOffsetRatio":0.0,"visualPhase":0.0,"diamondReward":0,"path":[]}
	for key in defaults:
		if not e.has(key): e[key] = defaults[key]
	e.hp = clampf(float(e.get("hp",e.maxHp)),0,float(e.maxHp))
	e.shield = clampf(float(e.get("shield",0.0)),0,float(e.maxShield))
	e.armor = clampf(float(e.get("armor",0.0)),0,float(e.maxArmor))
	e.shieldBroken = e.maxShield > 0 and e.shieldBroken
	e.distanceTravelled = maxf(0,e.distanceTravelled)
	for key in ["poisonRemaining","poisonDamagePerSecond","poisonDamageMultiplier","poisonStacks","physicalVulnerabilityRemaining","physicalVulnerabilityBonus","elementalVulnerabilityRemaining","elementalVulnerabilityBonus","riftMarkRemaining","riftMarkDamageAmplification"]:
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
	if e.burnInstances.is_empty() and float(e.get("burnRemaining",0)) > 0 and float(e.get("burnDamagePerSecond",0)) > 0:
		add_burn(e,{"remaining":e.burnRemaining,"damagePerSecond":e.burnDamagePerSecond,"damageMultiplier":e.get("burnDamageMultiplier",1.0)})
	_rebuild_path(e,e.path)
	_place_at_distance(e,e.distanceTravelled)
	if raw.has("x") and raw.has("y"): _set_position(e,float(raw.x),float(raw.y))
	elif raw.has("position"): _set_position(e,float(raw.position.x),float(raw.position.y))
	if raw.has("targetIndex"): e.targetIndex = int(raw.targetIndex)
	if raw.has("facingAngle"): e.facingAngle = float(raw.facingAngle)
	return e

static func _set_position(e: Dictionary,x: float,y: float) -> void:
	e.x=x
	e.y=y
	e.position={"x":x,"y":y}

static func _px(p) -> float:
	return float(p[0]) if p is Array else float(p.x)

static func _py(p) -> float:
	return float(p[1]) if p is Array else float(p.y)

static func _rebuild_path(e: Dictionary,path: Array) -> void:
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

static func _event(e: Dictionary,kind: String,details: Dictionary={}) -> Dictionary:
	var result := {"type":kind,"enemyId":e.id,"x":e.x,"y":e.y}
	result.merge(details,true)
	return result

static func _apply_layers(e: Dictionary,damage: float,ignore: bool) -> float:
	var actual := 0.0
	if e.shield>0:
		var taken := minf(e.shield,damage)
		e.shield=maxf(0,e.shield-taken)
		actual+=taken
		damage-=taken
		if e.shield==0: e.shieldBroken=true
	if damage>0 and e.armor>0:
		if not ignore:
			var pressure := sqrt(float(e.maxArmor))*3.0
			damage *= 0.12+0.88*damage/(damage+pressure)
		var taken := minf(e.armor,damage)
		e.armor=maxf(0,e.armor-taken)
		actual+=taken
		damage=maxf(0,damage-taken)
	if damage>0:
		var taken := minf(e.hp,damage)
		e.hp=maxf(0,e.hp-taken)
		actual+=taken
	return actual

static func apply_hit(e: Dictionary,attack: Dictionary) -> Dictionary:
	var result := {"actualDamage":0.0,"bonusDamage":0.0,"killed":false,"events":[]}
	var damage := float(attack.get("damage",0.0))
	if damage<=0 or e.hp<=0 or e.arrived: return result
	var ignore := bool(attack.get("ignoreArmorReduction",false))
	var amp: float = float(e.riftMarkDamageAmplification) if e.riftMarkRemaining>0 else 0.0
	var base := 0.0
	if amp>0: base=_apply_layers(e.duplicate(),damage,ignore)
	result.actualDamage=_apply_layers(e,damage*(1+amp),ignore)
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

static func add_burn(e: Dictionary,burn: Dictionary) -> void:
	var dps := float(burn.get("damagePerSecond",0))
	var duration := float(burn.get("duration",burn.get("remaining",0)))
	if dps<=0 or duration<=0: return
	var value := {"remaining":duration,"damagePerSecond":dps,"damageMultiplier":float(burn.get("damageMultiplier",1)),"sourceX":burn.get("sourceX"),"sourceY":burn.get("sourceY"),"ignoreArmorReduction":burn.get("ignoreArmorReduction",false)}
	if value.sourceX!=null and value.sourceY!=null:
		for b in e.burnInstances:
			if b.sourceX==value.sourceX and b.sourceY==value.sourceY:
				for key in ["remaining","damagePerSecond","damageMultiplier"]: b[key]=maxf(b[key],value[key])
				b.ignoreArmorReduction=b.ignoreArmorReduction or value.ignoreArmorReduction
				return
	e.burnInstances.append(value)

static func burn_transfer(e: Dictionary,source: Dictionary) -> Dictionary:
	var strongest: Dictionary={}
	for b in e.burnInstances:
		if b.sourceX!=source.get("x") or b.sourceY!=source.get("y") or b.remaining<=0: continue
		if strongest.is_empty() or b.damagePerSecond>strongest.damagePerSecond or (b.damagePerSecond==strongest.damagePerSecond and b.remaining>strongest.remaining): strongest=b
	return strongest.duplicate(true)

static func clear_burn_source(e: Dictionary,source: Dictionary) -> void:
	for b in e.burnInstances:
		if b.sourceX==source.get("x") and b.sourceY==source.get("y"):
			b.sourceX=null
			b.sourceY=null

static func add_poison(e: Dictionary,dps: float,duration: float,max_stacks: int,multiplier: float=1) -> void:
	e.poisonDamagePerSecond=dps
	e.poisonDamageMultiplier=multiplier
	e.poisonStacks=mini(max_stacks,int(e.poisonStacks)+1)
	e.poisonRemaining=duration

static func add_vulnerability(e: Dictionary,kind: String,bonus: float,duration: float) -> void:
	if kind not in ["physical","elemental"] or bonus<=0 or duration<=0: return
	var prefix := kind+"Vulnerability"
	e[prefix+"Bonus"]=maxf(e[prefix+"Bonus"],bonus)
	e[prefix+"Remaining"]=maxf(e[prefix+"Remaining"],duration)

static func add_rift_mark(e: Dictionary,amplification: float,duration: float) -> void:
	if amplification<=0 or duration<=0: return
	e.riftMarkDamageAmplification=maxf(e.riftMarkDamageAmplification,amplification)
	e.riftMarkRemaining=maxf(e.riftMarkRemaining,duration)

static func _dot_hit(e: Dictionary,attack: Dictionary,kind: String,events: Array) -> float:
	var result := apply_hit(e,attack)
	events.append_array(result.events)
	if result.actualDamage>0:
		events.append(_event(e,"damage",{"kind":kind,"damage":result.actualDamage,"bonusDamage":result.bonusDamage,"sourceX":attack.get("sourceX"),"sourceY":attack.get("sourceY")}))
	return result.actualDamage

static func _max_burn_multiplier(e: Dictionary) -> float:
	var value := 1.0 if e.burnInstances.is_empty() else 0.0
	for b in e.burnInstances: value=maxf(value,b.damageMultiplier)
	return value

static func step(e: Dictionary,dt: float,path: Array=[]) -> Array:
	var events: Array=[]
	if dt<0 or not is_finite(dt) or e.arrived: return events
	if not path.is_empty() and path!=e.path: update_path(e,path)
	e.hitFlashTimer=maxf(0,e.hitFlashTimer-dt)
	e.statusEffectTime+=dt
	if e.hp>0 and e.maxShield>0 and not e.shieldBroken and e.shield<e.maxShield and e.shieldRegenRate>0:
		e.shield=minf(e.maxShield,e.shield+e.maxShield*e.shieldRegenRate*dt)
	if not e.burnInstances.is_empty():
		e.burnNumberTimer+=dt
		var strongest: Dictionary={}
		var tick := 0.0
		for i in range(e.burnInstances.size()-1,-1,-1):
			var b: Dictionary=e.burnInstances[i]
			var duration := minf(dt,b.remaining)
			b.remaining=maxf(0,b.remaining-dt)
			if duration>0 and (strongest.is_empty() or b.damagePerSecond>strongest.damagePerSecond):
				strongest=b
				tick=duration
		if not strongest.is_empty():
			var attack: Dictionary=strongest.duplicate(true)
			attack.damage=strongest.damagePerSecond*tick
			attack.burnTransfer=strongest.duplicate(true)
			e.burnNumberDamage+=_dot_hit(e,attack,"burn",events)
		e.burnInstances=e.burnInstances.filter(func(b): return b.remaining>0)
		if e.hp>0 and (e.burnNumberTimer>=0.28 or e.burnInstances.is_empty()) and e.burnNumberDamage>0:
			events.append(_event(e,"damageNumber",{"kind":"burn","damage":e.burnNumberDamage,"damageMultiplier":_max_burn_multiplier(e)}))
			e.burnNumberDamage=0.0
			e.burnNumberTimer=0.0
	if e.poisonRemaining>0:
		e.poisonRemaining=maxf(0,e.poisonRemaining-dt)
		e.poisonNumberTimer+=dt
		e.poisonNumberDamage+=_dot_hit(e,{"damage":e.poisonDamagePerSecond*e.poisonStacks*dt},"poison",events)
		if e.hp>0 and (e.poisonNumberTimer>=0.5 or e.poisonRemaining==0):
			events.append(_event(e,"damageNumber",{"kind":"poison","damage":e.poisonNumberDamage,"damageMultiplier":e.poisonDamageMultiplier}))
			e.poisonNumberDamage=0.0
			e.poisonNumberTimer=0.0
		if e.poisonRemaining==0:
			e.poisonStacks=0
			e.poisonDamagePerSecond=0.0
			e.poisonNumberDamage=0.0
			e.poisonNumberTimer=0.0
	for slow in e.slowInstances: slow.remaining-=dt
	e.slowInstances=e.slowInstances.filter(func(s): return s.remaining>0)
	for prefix in ["physicalVulnerability","elementalVulnerability","riftMark"]:
		if e[prefix+"Remaining"]>0:
			e[prefix+"Remaining"]=maxf(0,e[prefix+"Remaining"]-dt)
			if e[prefix+"Remaining"]==0: e[prefix+("DamageAmplification" if prefix=="riftMark" else "Bonus")]=0.0
	if e.hp<=0 or int(e.targetIndex)>=e.path.size(): return events
	var target = e.path[int(e.targetIndex)]
	var dx := _px(target)-float(e.x)
	var dy := _py(target)-float(e.y)
	var distance := sqrt(dx*dx+dy*dy)
	if distance>0.001: e.facingAngle=atan2(dy,dx)
	var multiplier := 1.0
	for slow in e.slowInstances: multiplier=minf(multiplier,slow.multiplier)
	var movement: float=e.speed*e.boardDistanceScale*multiplier*dt
	if distance<=movement:
		e.distanceTravelled+=distance
		_set_position(e,_px(target),_py(target))
		e.targetIndex+=1
		if e.targetIndex>=e.path.size():
			e.arrived=true
			events.append(_event(e,"coreArrival"))
	else:
		_set_position(e,e.x+dx/distance*movement,e.y+dy/distance*movement)
		e.distanceTravelled+=movement
	return events

static func snapshot(e: Dictionary) -> Dictionary:
	var result: Dictionary=e.duplicate(true)
	for key in ["_ends","_lengths","_cumulative","_total"]: result.erase(key)
	result.burnRemaining=0.0
	result.burnDamagePerSecond=0.0
	for b in e.burnInstances:
		result.burnRemaining=maxf(result.burnRemaining,b.remaining)
		result.burnDamagePerSecond=maxf(result.burnDamagePerSecond,b.damagePerSecond)
	result.burnDamageMultiplier=_max_burn_multiplier(e)
	return result
