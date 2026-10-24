extends SceneTree
## 독 포탑 전투: 대상 추적 포물선 바닥 착탄, 반경 안 모든 적에게 100% 범위 피해와 그 피해 기준 독 1중첩(공통 30% 규칙),
## 착탄 지점의 독 장판(포탑 피해 절반 기준 독 1중첩).
## 장판은 포탑별 주기마다 안의 적에게 독 1중첩을 주고, 같은 포탑 웅덩이를 겹쳐 밟아도 주기당 1중첩,
## 포탑당 웅덩이 상한, 유지 시간 뒤 소멸, 치명타 미반영, 방어구 무시 틱, 지속피해 집계.
## 독 피해 계열(물리 약화 미적용)과 특성 4종: 독액 웅덩이·가압 급액·농축 독소·부식 독소.
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Stats = preload("res://combat/turret_stat_calculation.gd")
const Catalog = preload("res://content/content_catalog.gd")
var failures: Array[String] = []
var checks := 0

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 1e-6 * maxf(1.0, absf(expected)), "%s actual=%s expected=%s" % [label, actual, expected])

func _input() -> Dictionary:
	var catalog = Catalog.new()
	if not catalog.load_catalog(): return {}
	var input: Dictionary = catalog._data.turrets.poison.configuration.statInput.duplicate(true)
	input.definition.criticalChance = 0.0
	return input

func _enemy(id: int, x: float, progress: float, extra: Dictionary = {}) -> Dictionary:
	var e := {"id": id, "hp": 1000.0, "maxHp": 1000.0, "x": x, "y": 0.0, "speed": 0.0, "distanceTravelled": progress}
	e.merge(extra, true)
	return e

func _runtime(input: Dictionary, enemies: Array):
	var r = Runtime.new()
	r.start(100, {"combatConfig": {}, "enemies": enemies, "turrets": [{"id": 1, "position": [0, 0], "statInput": input, "state": {"x": 0, "y": 0}}]}, {"clock": "godot", "phase": "wave", "running": true})
	return r

func _step_until_landed(r, limit: int = 120) -> void:
	var fired := false
	for i in range(limit):
		r._step(1.0 / 60.0)
		if not r.projectiles.is_empty(): fired = true
		if fired and r.projectiles.is_empty(): return
	failures.append("독액이 착탄하지 않음")

func _initialize() -> void:
	var input := _input()
	_check(not input.is_empty() and input.definition.type == "poison", "콘텐츠의 독 포탑 입력")
	if input.is_empty():
		_finish()
		return
	var stats := Stats.stats_at(input, 1)
	_check(stats.damage > 0.0 and stats.attackRate > 0.0 and stats.splashRadius > 0.0, "1레벨 피해·연사·착탄 범위")
	_landing_checks(input)
	_puddle_checks(input)
	_overlap_and_cap_checks(input)
	_dead_target_checks(input)
	_critical_checks(input)
	_tick_checks(input)
	_family_checks(input)
	_trait_checks(input)
	_finish()

# 시험용 장판 규칙: 2.1초 유지(주기 4번), 0.5초 주기, 상한 2. 중첩 규칙(30%·절반·5초)은 현행과 같다.
func _rules(r) -> void:
	r.poison_puddle = {"duration": 2.1, "tick": 0.5, "maxCount": 2, "hitShare": 0.3, "puddleBase": 0.5, "stackSeconds": 5.0}

# 착탄 중첩: 맞은 피해의 30%를 5초. 웅덩이 중첩: 포탑 피해 절반의 30%를 5초.
func _hit_stack_dps(d: float) -> float: return d * 0.3 / 5.0
func _puddle_stack_dps(d: float) -> float: return d * 0.5 * 0.3 / 5.0

func _damage(input: Dictionary) -> float:
	return float(Stats.stats_at(input, 1).damage)

# 사이의 적은 지나치고, 선택한 대상 위치 바닥에 떨어져 반경 안 모든 적을 100%로 맞히고 독 1중첩을 건다.
func _landing_checks(input: Dictionary) -> void:
	var r = _runtime(input, [_enemy(1, 30.0, 0.0), _enemy(2, 60.0, 5.0), _enemy(3, 75.0, 1.0), _enemy(4, 95.0, 0.5)])
	_rules(r)
	r._step(1.0 / 60.0)
	_check(r.projectiles.size() == 1 and r.projectiles[0].get("lobTarget") == "2", "가장 앞선 적을 겨냥한 독액 1발")
	_step_until_landed(r)
	var d := _damage(input)
	_near(1000.0 - float(r.enemies["1"].hp), 0.0, "경로 위 적은 맞지 않음")
	_near(1000.0 - float(r.enemies["2"].hp), d, "대상 위치 범위 피해 100%")
	_near(1000.0 - float(r.enemies["3"].hp), d, "반경 안 다른 적도 범위 피해 100%")
	_near(1000.0 - float(r.enemies["4"].hp), 0.0, "반경 밖 적은 피해 없음")
	_check(r.enemies["2"].poisonInstances.size() == 1 and r.enemies["3"].poisonInstances.size() == 1, "착탄에 맞은 적마다 독 1중첩")
	_check(r.enemies["1"].poisonInstances.is_empty() and r.enemies["4"].poisonInstances.is_empty(), "착탄에 맞지 않은 적은 중첩 없음")
	if r.enemies["3"].poisonInstances.size() == 1:
		_near(r.enemies["3"].poisonInstances[0].damagePerSecond, _hit_stack_dps(d), "착탄 중첩: 맞은 피해 100% 기준 30%를 5초")
	_check(r.enemies["2"].burnInstances.is_empty(), "독 포탑은 화상을 걸지 않음")
	_check(r.puddles.size() == 1 and r.puddles[0].owner == "1", "착탄 지점에 웅덩이 1개")

# 장판 주기마다 반경 안의 적에게 1중첩, 밖의 적과 경로 위 적은 없음. 유지 시간이 지나면 사라진다.
func _puddle_checks(input: Dictionary) -> void:
	var r = _runtime(input, [_enemy(1, 30.0, 0.0), _enemy(2, 60.0, 5.0), _enemy(3, 75.0, 1.0), _enemy(4, 95.0, 0.5)])
	_rules(r)
	r._step(1.0 / 60.0)
	_step_until_landed(r)
	r.running = false
	for i in range(30): r._step(1.0 / 60.0)
	var d := _damage(input)
	var target: Dictionary = r.enemies["2"]
	_check(target.poisonInstances.size() == 2 and r.enemies["3"].poisonInstances.size() == 2, "착탄 1중첩 + 주기 한 번에 웅덩이 안의 적마다 1중첩")
	_check(r.enemies["1"].poisonInstances.is_empty() and r.enemies["4"].poisonInstances.is_empty(), "웅덩이 밖 적은 중첩 없음")
	if target.poisonInstances.size() == 2:
		_near(target.poisonInstances[0].damagePerSecond, _hit_stack_dps(d), "착탄 중첩 하나")
		_near(target.poisonInstances[1].damagePerSecond, _puddle_stack_dps(d), "웅덩이 중첩 하나: 포탑 피해 절반 기준")
	for i in range(120): r._step(1.0 / 60.0)
	_check(r.puddles.is_empty(), "유지 시간 뒤 웅덩이 소멸")
	var stacks := int(target.poisonInstances.size())
	_check(stacks == 5, "착탄 1 + 2.1초 동안 0.5초 주기로 4중첩 (실제 %d)" % stacks)
	for i in range(60): r._step(1.0 / 60.0)
	_check(int(target.poisonInstances.size()) == stacks, "웅덩이가 사라진 뒤에는 중첩이 늘지 않음")

# 같은 포탑 웅덩이가 겹쳐도 주기당 1중첩, 포탑당 상한을 넘으면 가장 오래된 웅덩이가 사라진다.
func _overlap_and_cap_checks(input: Dictionary) -> void:
	var r = _runtime(input, [_enemy(1, 60.0, 5.0)])
	_rules(r)
	r.running = false
	var t: Dictionary = r.turrets["1"]
	var attack: Dictionary = Stats.firing_stats(t.statInput, t.stats, 1.0)
	attack.definition = t.statInput.definition
	var at: Vector2 = r._pos(r.enemies["1"])
	r._add_puddle(t, attack, at)
	r._add_puddle(t, attack, at)
	r._step(0.5)
	_check(r.enemies["1"].poisonInstances.size() == 1, "같은 포탑 웅덩이 2개를 밟아도 주기당 1중첩")
	var first_visual: int = int(r.puddles[0].visualId)
	r._add_puddle(t, attack, at + Vector2(200, 0))
	_check(r.puddles.size() == 2 and int(r.puddles[0].visualId) != first_visual, "상한 2를 넘으면 가장 오래된 웅덩이 제거")
	_check(not r.visual_effects.any(func(v): return int(v.id) == first_visual), "제거된 웅덩이의 연출도 함께 제거")

# 대상이 먼저 사라져도 마지막 위치에 떨어져 같은 100% 범위 피해·중첩과 웅덩이를 남긴다.
func _dead_target_checks(input: Dictionary) -> void:
	var r = _runtime(input, [_enemy(1, 60.0, 5.0), _enemy(2, 70.0, 1.0)])
	_rules(r)
	r._step(1.0 / 60.0)
	_check(r.projectiles.size() == 1, "독액 발사")
	r.enemies["1"].hp = 0.0
	r.running = true
	var before := float(r.enemies["2"].hp)
	_step_until_landed(r)
	_near(before - float(r.enemies["2"].hp), _damage(input), "대상 소멸 후 착탄 지점 범위 피해 100%")
	_check(r.enemies["2"].poisonInstances.size() == 1, "대상 소멸 후 범위에 맞은 적도 독 1중첩")
	_check(r.puddles.size() == 1, "대상 소멸 후에도 웅덩이 생성")

# 치명타는 착탄 피해와 착탄 중첩(추가분의 50%)에 반영하고, 웅덩이 중첩도 걸 때마다 판정해 추가분의 50%를 반영한다.
func _critical_checks(input: Dictionary) -> void:
	var crit_input := input.duplicate(true)
	crit_input.definition.criticalChance = 1.0
	var r = _runtime(crit_input, [_enemy(1, 60.0, 5.0)])
	_rules(r)
	r.running = false
	var t: Dictionary = r.turrets["1"]
	var attack: Dictionary = Stats.firing_stats(t.statInput, t.stats, 1.5)
	attack.definition = t.statInput.definition
	attack.hasDamageOverTime = false
	var e: Dictionary = r.enemies["1"]
	var d := _damage(input)
	r._venom_burst(t, attack, r._pos(e))
	_near(1000.0 - float(e.hp), d * 1.5, "치명타 착탄 1.5배")
	if e.poisonInstances.size() == 1:
		_near(e.poisonInstances[0].damagePerSecond, _hit_stack_dps(d) * 1.25, "착탄 중첩은 치명타 추가분의 50%")
	r._add_puddle(t, attack, r._pos(e))
	r._step(0.5)
	if e.poisonInstances.size() == 2:
		_near(e.poisonInstances[1].damagePerSecond, _puddle_stack_dps(d) * 1.25, "웅덩이 중첩도 치명타 판정, 추가분의 50%")
	else:
		_check(false, "치명타 착탄 뒤 장판 1중첩")
	# 치명타 확률 0이면 웅덩이 중첩은 치명타 없이 걸린다.
	var plain = _runtime(input, [_enemy(1, 60.0, 5.0)])
	_rules(plain)
	plain.running = false
	var pt: Dictionary = plain.turrets["1"]
	var plain_attack: Dictionary = Stats.firing_stats(pt.statInput, pt.stats, 1.0)
	plain_attack.definition = pt.statInput.definition
	plain._add_puddle(pt, plain_attack, plain._pos(plain.enemies["1"]))
	plain._step(0.5)
	if plain.enemies["1"].poisonInstances.size() == 1:
		_near(plain.enemies["1"].poisonInstances[0].damagePerSecond, _puddle_stack_dps(d), "치명타가 없으면 웅덩이 중첩 기본값")

# 틱은 방어구를 그대로 통과하고 포탑 지속피해 집계에 들어간다. 중첩 보너스 5%/중첩.
func _tick_checks(input: Dictionary) -> void:
	var r = _runtime(input, [_enemy(1, 60.0, 5.0, {"maxArmor": 1000.0, "armor": 1000.0})])
	_rules(r)
	r.running = false
	var t: Dictionary = r.turrets["1"]
	var attack: Dictionary = Stats.firing_stats(t.statInput, t.stats, 1.0)
	attack.definition = t.statInput.definition
	r._add_puddle(t, attack, Vector2(-5000, -5000))
	var stack: Dictionary = r.puddles[0].attack
	r.puddles.clear()
	var e: Dictionary = r.enemies["1"]
	for i in range(4): r._poison_stack(t, stack, e)
	_check(e.poisonInstances.size() == 4, "같은 포탑 중첩 4개")
	var armor_before := float(e.armor)
	var dot_before := float(t.burnDamageDealt)
	r._step(0.1)
	# 4중첩 × 웅덩이 중첩 초당 피해 × (1 + 0.05 × 4) × 0.1초
	var expected := 4.0 * _puddle_stack_dps(_damage(input)) * 1.2 * 0.1
	_near(armor_before - float(e.armor), expected, "독 틱은 방어구 감쇄 없이 그대로 소모")
	_near(float(t.burnDamageDealt) - dot_before, expected, "독 틱을 포탑 지속피해에 집계")

# 독 포탑은 독 피해 계열: 물리 약화(물리 저항 감소)는 독 포탑 착탄을 키우지 않는다.
func _family_checks(input: Dictionary) -> void:
	_check(input.definition.damageFamily == "poison", "독 포탑 피해 계열은 독")
	var r = _runtime(input, [_enemy(1, 60.0, 5.0, {"physicalVulnerabilityBonus": 0.5, "physicalVulnerabilityRemaining": 10.0})])
	r.running = false
	var t: Dictionary = r.turrets["1"]
	var attack: Dictionary = Stats.firing_stats(t.statInput, t.stats, 1.0)
	attack.definition = t.statInput.definition
	attack.hasDamageOverTime = false
	var e: Dictionary = r.enemies["1"]
	r._venom_burst(t, attack, r._pos(e))
	_near(1000.0 - float(e.hp), _damage(input), "물리 약화가 독 피해에 들어가지 않음")
	# 독 계열 착탄은 방어구 감쇄 없이 방어구 내구도를 그대로 깎는다.
	r = _runtime(input, [_enemy(1, 60.0, 5.0, {"maxArmor": 1000.0, "armor": 1000.0})])
	r.running = false
	t = r.turrets["1"]
	attack = Stats.firing_stats(t.statInput, t.stats, 1.0)
	attack.definition = t.statInput.definition
	attack.hasDamageOverTime = false
	e = r.enemies["1"]
	r._venom_burst(t, attack, r._pos(e))
	_near(1000.0 - float(e.armor), _damage(input), "독 착탄은 방어구 감쇄 없이 그대로 소모")
	_near(1000.0 - float(e.hp), 0.0, "방어구가 남아 있으면 체력은 그대로")
	# 독 지속시간 모듈은 독 중첩 시간을 늘리고, 화상 지속시간 증가는 독에 들어가지 않는다.
	var duration_input := input.duplicate(true)
	duration_input.moduleEffect.poisonDurationIncreaseRate = 0.2
	_near(Stats.stats_at(duration_input, 1).damageOverTimeDurationMultiplier, 1.2, "독 지속시간 모듈")
	duration_input.moduleEffect.poisonDurationIncreaseRate = 0.0
	duration_input.moduleEffect.burnDurationIncreaseRate = 0.5
	_near(Stats.stats_at(duration_input, 1).damageOverTimeDurationMultiplier, 1.0, "화상 지속시간 모듈은 독 미적용")
	# 독 피해 젬만 독 계열을 40% 키우고, 물리·원소 피해 젬은 독 포탑에 적용되지 않는다.
	var base_damage: float = Stats.stats_at(input, 1).damage
	for gems in [["poisonDamage"], ["physicalDamage"], ["elementalDamage"]]:
		var gem_input := input.duplicate(true)
		gem_input.gems = gems
		_near(Stats.stats_at(gem_input, 1).damage, base_damage * (1.4 if gems[0] == "poisonDamage" else 1.0), "독 포탑 %s 젬 피해" % gems[0])
	for type in ["arrow", "magic"]:
		var other: Dictionary = input.duplicate(true)
		other.definition = other.definition.duplicate(true)
		other.definition.damageFamily = "physical" if type == "arrow" else "elemental"
		var plain: float = Stats.stats_at(other, 1).damage
		other.gems = ["poisonDamage"]
		_near(Stats.stats_at(other, 1).damage, plain, "%s 계열에는 독 피해 젬 미적용" % other.definition.damageFamily)

func _trait_input(input: Dictionary, primary, secondary) -> Dictionary:
	var out := input.duplicate(true)
	out.primaryTrait = primary
	out.secondaryTrait = secondary
	return out

func _trait_checks(input: Dictionary) -> void:
	var base := Stats.stats_at(input, 1)
	# 1차 독액 웅덩이: 초당 0.4발, 피해 2배, 반경 2배, 웅덩이 3초. 웅덩이 중첩도 커진 피해의 절반 기준.
	var pool_input := _trait_input(input, "venomPool", null)
	var pool := Stats.stats_at(pool_input, 1)
	_near(pool.attackRate, base.attackRate * 0.4 / 1.4, "독액 웅덩이 공격 속도")
	_near(pool.damage, base.damage * 2.0, "독액 웅덩이 포탑 피해")
	_near(pool.splashRadius, base.splashRadius * 2.0, "독액 웅덩이 반경")
	var r = _runtime(pool_input, [_enemy(1, 60.0, 5.0)])
	r.running = false
	var t: Dictionary = r.turrets["1"]
	var attack: Dictionary = Stats.firing_stats(t.statInput, t.stats, 1.0)
	attack.definition = t.statInput.definition
	r._add_puddle(t, attack, r._pos(r.enemies["1"]))
	_near(float(r.puddles[0].remaining), 3.0, "독액 웅덩이 유지 3초")
	r._step(0.5)
	var e: Dictionary = r.enemies["1"]
	if e.poisonInstances.size() == 1:
		_near(e.poisonInstances[0].damagePerSecond, _puddle_stack_dps(pool.damage), "독액 웅덩이 중첩은 커진 피해의 절반 기준")
	else:
		_check(false, "독액 웅덩이 주기 1중첩")
	var rows: Array = r.decorate_frame({}).get("turrets", [])
	var row = rows[0] if not rows.is_empty() else null
	var extension = row.extension if row is Object else (row[8] if row is Array and row.size() > 8 else {})
	_check(extension is Dictionary and bool(extension.get("venomPool", false)), "독액 웅덩이 연출 표시")
	# 1차 가압 급액: 공격 속도 15% 증폭.
	_near(Stats.stats_at(_trait_input(input, "pressurizedFeed", null), 1).attackRate, base.attackRate * 1.15, "가압 급액 공격 속도")
	# 2차 농축 독소: 이 포탑 중첩당 보너스 10%.
	r = _runtime(_trait_input(input, null, "concentratedToxin"), [_enemy(1, 60.0, 5.0)])
	_rules(r)
	r.running = false
	t = r.turrets["1"]
	attack = Stats.firing_stats(t.statInput, t.stats, 1.0)
	attack.definition = t.statInput.definition
	r._add_puddle(t, attack, Vector2(-5000, -5000))
	var stack: Dictionary = r.puddles[0].attack
	r.puddles.clear()
	e = r.enemies["1"]
	for i in range(4): r._poison_stack(t, stack, e)
	var hp := float(e.hp)
	r._step(0.1)
	_near(hp - float(e.hp), 4.0 * _puddle_stack_dps(_damage(input)) * 1.4 * 0.1, "농축 독소 4중첩 보너스 40%")
	# 2차 부식 독소: 이 포탑 3중첩 이상인 동안만 물리 저항 -15%p.
	r = _runtime(_trait_input(input, null, "corrosiveToxin"), [_enemy(1, 60.0, 5.0)])
	_rules(r)
	r.running = false
	t = r.turrets["1"]
	attack = Stats.firing_stats(t.statInput, t.stats, 1.0)
	attack.definition = t.statInput.definition
	r._add_puddle(t, attack, Vector2(-5000, -5000))
	stack = r.puddles[0].attack
	r.puddles.clear()
	e = r.enemies["1"]
	for i in range(2): r._poison_stack(t, stack, e)
	r._step(1.0 / 60.0)
	_check(float(e.get("physicalVulnerabilityRemaining", 0.0)) <= 0.0, "부식 독소 2중첩은 물리 약화 없음")
	r._poison_stack(t, stack, e)
	r._step(1.0 / 60.0)
	_check(float(e.get("physicalVulnerabilityRemaining", 0.0)) > 0.0 and is_equal_approx(float(e.physicalVulnerabilityBonus), 0.15), "부식 독소 3중첩부터 물리 저항 -15%p")
	e.poisonInstances.clear()
	for i in range(30): r._step(1.0 / 60.0)
	_check(float(e.get("physicalVulnerabilityRemaining", 0.0)) <= 0.0 and r.corroding.is_empty(), "중첩이 사라지면 물리 약화도 곧 끝남")

func _finish() -> void:
	if failures.is_empty():
		print("POISON_TURRET checks=%d failures=0" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("POISON_TURRET checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
