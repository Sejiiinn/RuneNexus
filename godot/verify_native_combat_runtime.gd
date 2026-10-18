extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Enemy = preload("res://combat/native_enemy_state.gd")
var failures: Array = []
func _initialize() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	var count := 0
	for fixture in fixtures:
		if float(fixture.expected.damage) <= 0 or float(fixture.expected.range) <= 0: continue
		var runtime = Runtime.new()
		var input: Dictionary = fixture.input.duplicate(true)
		var enemies: Array = []
		for index in range(6):
			enemies.append({"id": index + 1, "x": (10.0 + index * 3) * float(input.boardDistanceScale), "y": 0.0, "maxHp": 5000.0, "hp": 5000.0, "collisionRadius": 2.0 * float(input.boardDistanceScale), "distanceTravelled": float(index), "path": [], "speed": 0.0})
		var bootstrap := {"enemies": enemies, "turrets": [{"id": 11, "position": [0,0], "statInput": input, "state": {"x":0,"y":0}}]}
		var packet := {"epoch": 1, "sequence": 0, "bootstrap": bootstrap, "dt": 0.0}
		runtime.process_command(packet)
		for frame in range(180):
			runtime.process_command({"epoch": 1,"sequence":frame + 1,"dt":1.0/60.0})
		var result: Dictionary = runtime.snapshot()
		var damage := 0.0
		for e in result.enemies: damage += 5000.0 - float(e.hp)
		_check(damage > 0, fixture.name + " delivers damage")
		var before := JSON.stringify(result)
		runtime.process_command({"epoch":1,"sequence":180,"dt":9.0})
		_check(before == JSON.stringify(runtime.snapshot()), "duplicate batch idempotency")
		var rejected: Dictionary = runtime.process_command({"epoch":1,"sequence":182,"dt":1.0})
		_check(not rejected.accepted, "sequence gap rejected")
		count += 1
	# Identical queued steps must match individually delivered simulation updates.
	var a = Runtime.new()
	var b = Runtime.new()
	var setup := {"epoch":4,"sequence":0,"dt":0.0,"bootstrap":{"enemies":[{"id":1,"hp":100,"maxHp":100,"speed":10,"path":[[0,0],[5,0],[50,0]]}],"turrets":[]}}
	a.process_command(setup)
	b.process_command(setup)
	a.process_command({"epoch":4,"sequence":1,"dtSteps":[0.6,0.2]})
	b.process_command({"epoch":4,"sequence":1,"dt":0.6})
	b.process_command({"epoch":4,"sequence":2,"dt":0.2})
	_check(JSON.stringify(a.snapshot().enemies) == JSON.stringify(b.snapshot().enemies), "batched original timestep equivalence")
	_damage_training_checks(fixtures)
	_boss_damage_checks(fixtures)
	_exact_checks(fixtures)
	_response_mode_checks()
	_path_revision_checks()
	_projectile_travel_checks(fixtures)
	_initial_facing_checks(fixtures)
	if failures.is_empty():
		print("PASS native combat runtime: ", count, " configured turret cases, all six types, damage, ACK idempotency, gap rejection, batched timestep preservation, triple projectile travel and late collision")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initial_facing_checks(fixtures: Array) -> void:
	var input: Dictionary = {}
	for fixture in fixtures:
		if fixture.input.definition.type == "arrow" and fixture.input.level == 1 and fixture.input.gems.is_empty():
			input = fixture.input.duplicate(true)
			break
	var raw := {"id":1,"position":[0,0],"statInput":input,"state":{"aimAngle":3.0*PI/4.0}}
	var runtime = Runtime.new()
	runtime._turret(raw)
	runtime.running = false
	runtime._tick_turret(runtime.turrets["1"],1.0)
	_check(is_equal_approx(runtime.turrets["1"].aimAngle,3.0*PI/4.0),"paused initial southwest facing stays in native state")
	# Zero is a real saved/target angle, never an idle sentinel.
	var restored = Runtime.new()
	var saved := raw.duplicate(true)
	saved.state.aimAngle = 0.0
	restored._turret(saved)
	_check(restored.turrets["1"].aimAngle == 0.0,"explicit saved zero angle is preserved")
	saved.state.aimAngle = -0.7
	var other = Runtime.new()
	other._turret(saved)
	_check(is_equal_approx(other.turrets["1"].aimAngle,-0.7),"explicit saved nonzero angle is preserved")
	runtime._spawn({"id":1,"x":10.0,"y":0.0,"hp":10000.0,"maxHp":10000.0,"collisionRadius":1.0})
	runtime.running = true
	runtime._tick_turret(runtime.turrets["1"],1.0)
	_check(runtime.turrets["1"].aimAngle == 0.0 and runtime.turrets["1"].shotSequence == 1,"east target immediately replaces initial angle and fires")
	_check(runtime.projectiles.size() == 1 and runtime.projectiles[0].direction.is_equal_approx(Vector2.RIGHT),"east projectile keeps the real zero angle")
	runtime._turret(raw)
	_check(runtime.turrets["1"].aimAngle == 0.0,"configuration refresh cannot reset acquired zero angle")

func _projectile_test_runtime(input: Dictionary, scale: float, target_x: float):
	var r = Runtime.new()
	r.process_command({"epoch":80,"sequence":0,"dt":0.0,"bootstrap":{"boardDistanceScale":scale,"tileSize":48.0*scale,"enemies":[{"id":1,"hp":1000.0,"maxHp":1000.0,"x":target_x,"y":0.0,"collisionRadius":scale}],"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{}}]}})
	r._tick_turret(r.turrets["1"],0.0)
	return r

func _move_test_projectiles(r, distance: float) -> void:
	var moving: Array = r.projectiles
	r.projectiles = []
	for p in moving:
		r._move_projectile(p, distance / float(p.attack.projectileSpeed))

func _projectile_travel_checks(fixtures: Array) -> void:
	for type in ["arrow", "cannon", "magic"]:
		var base: Dictionary = {}
		for f in fixtures:
			if f.input.definition.type == type and f.input.level == 1 and f.input.gems.is_empty():
				base = f.input.duplicate(true)
				break
		_check(not base.is_empty(), "projectile fixture exists: " + type)
		if base.is_empty(): continue
		base.definition.criticalChance = 0.0
		for scale in [0.5, 1.0, 2.0]:
			var input := base.duplicate(true)
			input.boardDistanceScale = scale
			var label: String = type + " scale=" + str(scale)
			var r = _projectile_test_runtime(input,scale,40.0*scale)
			_check(r.projectiles.size() == 1, label + " fires one projectile")
			if r.projectiles.is_empty(): continue
			var p: Dictionary = r.projectiles[0]
			var old_limit: float = r.turrets["1"].stats.range + 64.0*scale
			var launch: Vector2 = p.origin
			_check(is_equal_approx(p.remaining,3.0*old_limit), label + " has triple distance budget")
			_check(is_equal_approx(p.attack.projectileSpeed,base.definition.projectileSpeed*scale), label + " retains projectile speed")
			r.enemies.clear()
			_move_test_projectiles(r,old_limit+scale)
			_check(r.projectiles.size() == 1 and is_equal_approx(p.position.distance_to(launch),old_limit+scale), label + " missed shot survives old limit")
			_move_test_projectiles(r,2.0*old_limit-2.0*scale)
			_check(r.projectiles.size() == 1, label + " survives just before new limit")
			_move_test_projectiles(r,2.0*scale)
			_check(r.projectiles.is_empty() and is_equal_approx(p.position.distance_to(launch),3.0*old_limit), label + " expires exactly at triple limit")
			# An acquired enemy can leave the line while another crosses it later.
			var late = _projectile_test_runtime(input,scale,40.0*scale)
			late.enemies.clear()
			_move_test_projectiles(late,old_limit+scale)
			late._spawn({"id":2,"hp":1000.0,"maxHp":1000.0,"x":launch.x+old_limit+30.0*scale,"y":0.0,"collisionRadius":scale})
			_move_test_projectiles(late,40.0*scale)
			_check(late.projectiles.is_empty() and is_equal_approx(late.enemies["2"].hp,1000.0-float(late.turrets["1"].stats.damage)), label + " late collision hits once and ends shot")
			var outside = _projectile_test_runtime(input,scale,float(r.turrets["1"].stats.range)+10.0*scale)
			_check(outside.projectiles.is_empty() and outside.turrets["1"].shotSequence == 0, label + " acquisition range remains unchanged")
			# Chain launch and target selection retain their independent contracts.
			input.gems = ["chain"]
			var chain = _projectile_test_runtime(input,scale,40.0*scale)
			chain._spawn({"id":2,"hp":1000.0,"maxHp":1000.0,"x":100.0*scale,"y":0.0,"collisionRadius":scale})
			_move_test_projectiles(chain,50.0*scale)
			_check(chain.projectiles.size() == 1 and chain.projectiles[0].chained, label + " hit starts one chain segment")
			if not chain.projectiles.is_empty():
				var jump: Dictionary = chain.projectiles[0]
				_check(jump.chains == 1 and is_equal_approx(jump.remaining,330.0*scale), label + " chain retains count with triple travel")
				chain.enemies.clear()
				_move_test_projectiles(chain,111.0*scale)
				_check(chain.projectiles.size() == 1, label + " missed chain survives old limit")
				_move_test_projectiles(chain,220.0*scale)
				_check(chain.projectiles.is_empty(), label + " missed chain expires at new limit")
			var chain_outside = _projectile_test_runtime(input,scale,40.0*scale)
			chain_outside._spawn({"id":2,"hp":1000.0,"maxHp":1000.0,"x":151.0*scale,"y":0.0,"collisionRadius":scale})
			_move_test_projectiles(chain_outside,50.0*scale)
			_check(chain_outside.projectiles.is_empty(), label + " chain acquisition stays within 110 board units")

func _exact_checks(fixtures: Array) -> void:
	var input: Dictionary = fixtures[0].input.duplicate(true)
	input.definition.criticalChance = 0.0
	var r = Runtime.new()
	var bootstrap := {"enemies":[{"id":1,"hp":100.0,"maxHp":100.0,"x":50.0,"y":0.0,"collisionRadius":1.0}],"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{}}]}
	r.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"dt":0.0})
	r.process_command({"epoch":1,"sequence":1,"dt":0.1})
	_check(is_equal_approx(r.enemies["1"].hp,93.0), "segment hit applies exact 7 basic damage")
	_check(r.turrets["1"].shotSequence == 1, "one shot in first frame")
	r.process_command({"epoch":1,"sequence":2,"dt":0.1})
	_check(r.turrets["1"].shotSequence == 1, "cooldown prevents premature second shot")
	var hp: float = r.enemies["1"].hp
	var elapsed: float = r.clock
	r.process_command({"epoch":1,"sequence":3,"running":false,"dt":0.0})
	_check(r.enemies["1"].hp == hp and r.clock == elapsed, "zero-dt pause stops combat clock and damage")
	# Direct core command shares durability and exactly once terminal event path.
	r.process_command({"epoch":1,"sequence":4,"dt":0,"commands":[{"kind":"coreDamage","enemyId":1,"damage":200}]})
	var kills := 0
	for event in r.events:
		if event.kind == "kill": kills += 1
	_check(kills == 1 and r.enemies["1"].hp == 0, "lethal core command emits one kill")
	r.process_command({"epoch":1,"sequence":5,"dt":0,"commands":[{"kind":"coreDamage","enemyId":1,"damage":200}]})
	var kills_after := 0
	for event in r.events:
		if event.kind == "kill": kills_after += 1
	_check(kills_after == 1, "dead target cannot pay reward twice")
	# Sniper retains target and waits for aim duration, then applies one critical roll.
	var sniper: Dictionary = {}
	for f in fixtures:
		if f.input.definition.type == "sniper" and f.input.level == 1 and f.input.gems.is_empty():
			sniper = f.input.duplicate(true)
			break
	sniper.definition.criticalChance = 1.0
	var s = Runtime.new()
	s.process_command({"epoch":1,"sequence":0,"dt":0,"bootstrap":{"enemies":[{"id":1,"hp":1000.0,"maxHp":1000.0,"x":50.0,"y":0.0}],"turrets":[{"id":1,"position":[0,0],"statInput":sniper,"state":{}}]}})
	var aim: float = s.turrets["1"].stats.aimDuration
	s.process_command({"epoch":1,"sequence":1,"dt":aim*0.5})
	_check(s.enemies["1"].hp == 1000, "sniper no hit before aim complete")
	s.process_command({"epoch":1,"sequence":2,"dt":aim*0.5+0.000001})
	var expected: float = s.turrets["1"].stats.damage*s.turrets["1"].stats.criticalDamageMultiplier
	_check(is_equal_approx(s.enemies["1"].hp,1000.0-expected), "sniper exact critical damage after aim")
	# Cannon direct and splash each apply resistance independently, current primary excluded.
	var cannon: Dictionary = input.duplicate(true)
	cannon.definition.type = "cannon"
	cannon.definition.damage = 100.0
	cannon.definition.splashRadius = 25.0
	var c = Runtime.new()
	c.process_command({"epoch":1,"sequence":0,"dt":0,"bootstrap":{"enemies":[{"id":1,"hp":1000.0,"maxHp":1000.0,"x":50.0,"y":0.0,"collisionRadius":1.0,"familyResistances":{"physical":0.2}},{"id":2,"hp":1000.0,"maxHp":1000.0,"x":55.0,"y":8.0,"collisionRadius":1.0,"familyResistances":{"physical":0.4}}],"turrets":[{"id":1,"position":[0,0],"statInput":cannon,"state":{}}]}})
	c.process_command({"epoch":1,"sequence":1,"dt":0.1})
	_check(is_equal_approx(c.enemies["1"].hp,920.0), "cannon primary receives 100 * 0.8 once")
	_check(is_equal_approx(c.enemies["2"].hp,970.0), "cannon splash receives 100 * 0.5 * 0.6")
	var decorated: Dictionary = c.decorate_frame({"presentation":{"effects":{},"labels":{}}})
	_check(decorated.enemies.size()==2 and decorated.turrets.size()==1, "native presentation creates actors without Dart rows")
	_check(decorated.presentation.labels.enemies[0].hp == 920.0, "native labels use authoritative HP")

	# Running=false permits status timers but never starts a turret attack.
	var quiet = Runtime.new()
	quiet.process_command({"epoch":1,"sequence":0,"bootstrap":bootstrap,"running":false,"dt":2.0})
	_check(quiet.turrets["1"].shotSequence == 0 and quiet.enemies["1"].hp == 100, "preparation never fires turrets")
	# Native lightning snapshots critical at charge start and releases after 0.3s.
	var lightning: Dictionary = input.duplicate(true)
	lightning.definition.type = "lightning"
	lightning.definition.damage = 20.0
	lightning.definition.damageFamily = "elemental"
	var l = Runtime.new()
	l.process_command({"epoch":1,"sequence":0,"dt":0,"bootstrap":{"enemies":[{"id":1,"hp":100.0,"maxHp":100.0,"x":50.0,"y":0.0,"distanceTravelled":10.0},{"id":2,"hp":100.0,"maxHp":100.0,"x":60.0,"y":0.0}],"turrets":[{"id":1,"position":[0,0],"statInput":lightning,"state":{}}]}})
	l.process_command({"epoch":1,"sequence":1,"dt":0.1})
	_check(l.enemies["1"].hp == 100.0, "lightning charge delays hit")
	l.process_command({"epoch":1,"sequence":2,"dt":0.2})
	_check(l.enemies["1"].hp == 80.0 and l.enemies["2"].hp == 100.0, "lightning release hits primary only")
	l.process_command({"epoch":1,"sequence":3,"dt":0.07})
	_check(l.enemies["2"].hp == 90.0, "lightning delayed chain uses original 50 percent damage")
	# A target removed during charge cannot receive ghost damage; retarget is native.
	var removed = Runtime.new()
	removed.process_command({"epoch":1,"sequence":0,"dt":0,"bootstrap":{"enemies":[{"id":1,"hp":100.0,"maxHp":100.0,"x":50.0,"y":0.0}],"turrets":[{"id":1,"position":[0,0],"statInput":lightning,"state":{}}]}})
	removed.process_command({"epoch":1,"sequence":1,"dt":0.1})
	removed.process_command({"epoch":1,"sequence":2,"dt":0.2,"commands":[{"kind":"coreDamage","enemyId":1,"damage":100}]})
	_check(removed.turrets["1"].directDamageDealt == 0, "charge target death produces no ghost damage")

func _response_mode_checks() -> void:
	var full = Runtime.new()
	var local = Runtime.new()
	var setup := {"epoch":44,"sequence":0,"session":{"clock":"godot","phase":"wave"},"bootstrap":{"enemies":[{"id":1,"hp":100,"maxHp":100,"speed":10,"path":[[0,0],[5,0],[50,0]]}],"turrets":[]}}
	full.process_command(setup)
	var ack: Dictionary = local.process_command(setup, false)
	_check(ack == {"accepted":true,"epoch":44,"ackSequence":0}, "local command returns only acknowledgement")
	for r in [full, local]:
		r.advance_session(0.2)
		r.submit_input({"kind":"boardTap","tileX":1,"tileY":2})
	var packet := {"epoch":44,"sequence":1,"ackEvent":full.event_id,"session":{"paused":true}}
	full.process_command(packet)
	local.process_command(packet, false)
	_check(JSON.stringify(full.snapshot()) == JSON.stringify(local.snapshot()), "snapshot omission preserves state and event acknowledgement")
	var before := JSON.stringify(local.snapshot())
	local.process_command(packet, false)
	_check(before == JSON.stringify(local.snapshot()), "local duplicate command remains idempotent")
	for rejected in [{"epoch":43,"sequence":2}, {"epoch":44,"sequence":3}, {"epoch":45,"sequence":0}]:
		_check(full.process_command(rejected) == local.process_command(rejected, false), "response mode preserves rejection")


func _path_revision_checks() -> void:
	var r = Runtime.new()
	var route := [[0,0],[10,0],[10,10]]
	var custom := [[0,0],[0,10],[10,10]]
	r.process_command({"epoch":70,"sequence":0,"dt":0.0,"bootstrap":{"path":route,"enemies":[{"id":1,"hp":100,"maxHp":100,"speed":1,"path":custom,"distanceTravelled":3}],"turrets":[]}})
	var initial: Dictionary = r.enemies["1"]
	_check(initial.path == r._path(custom), "spawn retains custom path before first simulation step")
	var revision: int = r._path_revision
	r.process_command({"epoch":70,"sequence":1,"dt":0.1})
	_check(initial.path == r._path(custom), "first step retains per-enemy custom path")
	r.process_command({"epoch":70,"sequence":2,"dt":0.1})
	_check(r._path_revision == revision, "ordinary steps do not advance route revision")
	var progress: float = initial.distanceTravelled / initial._total
	r.process_command({"epoch":70,"sequence":3,"dt":0.0,"commands":[{"kind":"layout","path":[[0,0],[0,20],[20,20]]}]})
	_check(r._path_revision > revision and initial.path == r._path(custom), "layout preserves custom route and advances revision")
	_check(is_equal_approx(initial.distanceTravelled / initial._total, progress), "layout keeps normalized path progress")
	r.process_command({"epoch":70,"sequence":4,"dt":0.1,"commands":[{"kind":"spawn","enemy":{"id":2,"hp":100,"maxHp":100,"speed":1}}]})
	_check(r.enemies["2"].path == r.path, "spawn after layout receives new path")
	var saved: Dictionary = r.snapshot().enemies[0]
	_check(not saved.has("_path_revision"), "runtime snapshot hides route revision")
	r.process_command({"epoch":71,"sequence":0,"dt":0.0,"bootstrap":{"path":route,"enemies":[saved],"turrets":[]}})
	r.process_command({"epoch":71,"sequence":1,"dt":0.1})
	_check(r.enemies["1"].path == r._path(custom), "new epoch restores saved custom route")

# The target bonus is live at impact/tick time and never changes attack/DoT inputs.
func _boss_damage_checks(fixtures: Array) -> void:
	var input: Dictionary = fixtures[0].input.duplicate(true)
	input.definition.damage = 100.0
	input.definition.criticalChance = 0.0
	var r = Runtime.new()
	var rows: Array = []
	for type in ["boss", "shieldBoss", "forgeBoss", "normal"]:
		rows.append({"id":rows.size()+1,"type":type,"hp":10000.0,"maxHp":10000.0,"x":50.0,"y":float(rows.size()),"speed":0.0})
	r.process_command({"epoch":91,"sequence":0,"bootstrap":{"combatConfig":{"bossDamageBonusRate":0.2},"enemies":rows,"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{"x":0,"y":0}}]}})
	var t: Dictionary = r.turrets["1"]
	var attack: Dictionary = preload("res://combat/turret_stat_calculation.gd").firing_stats(t.statInput,t.stats,1.0)
	attack.definition = input.definition
	attack.damage = 100.0
	for e in r.enemies.values():
		r._hit(t,attack,e,1.0,"direct",true)
		_check(is_equal_approx(10000.0-float(e.hp),100.0 if e.type == "normal" else 120.0),str(e.type)+" target bonus once")
	# Target multipliers stay separate from resistance, hit increases and rift.
	var boss: Dictionary = r.enemies["1"]
	boss.familyResistances = {input.definition.damageFamily:0.2}
	Enemy.add_rift_mark(boss,0.125,10.0)
	attack.directDamageIncrease = 0.3
	var before: float = boss.hp
	r._hit(t,attack,boss,1.0,"direct",true)
	_check(is_equal_approx(before-float(boss.hp),100.0*1.3*0.8*1.2*1.125),"boss target layer follows hit increase/resistance before rift")
	boss.familyResistances = {}
	boss.riftMarkRemaining = 0.0
	attack.directDamageIncrease = 0.0
	attack.splashRadius = 20.0
	before = boss.hp
	var normal_before: float = r.enemies["4"].hp
	r._impact(t,attack,boss,r._pos(boss),0.5,true)
	_check(is_equal_approx(before-float(boss.hp),60.0),"chain direct boss coefficient once")
	_check(is_equal_approx(normal_before-float(r.enemies["4"].hp),25.0),"chain splash normal has no boss bonus")
	before = r.enemies["2"].hp
	r._impact(t,attack,r.enemies["4"],r._pos(r.enemies["4"]))
	_check(is_equal_approx(before-float(r.enemies["2"].hp),60.0),"normal primary splash evaluates boss recipient")
	# A newly inflicted burn stores the raw post-resistance DPS, without boss bonus.
	attack.hasDamageOverTime = true
	attack.burnDamagePerSecondScale = 0.5
	attack.burnDurationSeconds = 2.0
	r._hit(t,attack,boss,1.0,"direct",true)
	_check(is_equal_approx(float(boss.burnInstances[0].damagePerSecond),50.0*float(attack.damageOverTimeDamageMultiplier)),"new boss burn stores raw DPS")
	boss.burnInstances.clear()
	attack.hasDamageOverTime = false
	# Existing DoT, including legacy poison, uses the latest setting each tick.
	r.running = false
	Enemy.add_burn(boss,{"damagePerSecond":50.0,"duration":5.0,"sourceX":0,"sourceY":0})
	Enemy.add_poison(boss,10.0,5.0,1)
	r.process_command({"epoch":91,"sequence":1,"commands":[{"kind":"combatConfig","config":{"bossDamageBonusRate":0.1}}]})
	before = boss.hp
	r._step(0.1)
	_check(is_equal_approx(before-float(boss.hp),6.6),"already attached burn and poison read changed growth")
	var stored: Dictionary = r.snapshot().enemies[0]
	_check(stored.burnInstances[0].damagePerSecond == 50.0 and stored.poisonDamagePerSecond == 10.0 and not stored.has("bossDamageBonusRate"),"snapshot preserves raw DPS without target config")
	# Transfer keeps raw DPS and evaluates the new recipient, in either direction.
	var transfer: Dictionary = Enemy.burn_transfer(boss,{"x":0,"y":0})
	var normal: Dictionary = r.enemies["4"]
	Enemy.add_burn(normal,transfer)
	before = normal.hp
	r._step(0.1)
	_check(is_equal_approx(before-float(normal.hp),5.0),"boss to normal burn transfer loses target bonus")
	var other: Dictionary = r.enemies["2"]
	Enemy.add_burn(other,Enemy.burn_transfer(normal,{"x":0,"y":0}))
	before = other.hp
	r._step(0.1)
	_check(is_equal_approx(before-float(other.hp),5.5),"normal to boss burn transfer gains target bonus once")
	# Ignition burst consumes unscaled saved DPS; only the resulting hit scales.
	attack.appliesIgnitionBurst = true
	before = boss.hp
	r._hit(t,attack,boss,1.0,"direct",true)
	_check(is_equal_approx(before-float(boss.hp),(100.0+50.0*2.0*float(attack.damageOverTimeDurationMultiplier)*0.3)*1.1),"ignition burst applies target bonus once")
	before = boss.hp
	r._command({"kind":"coreDamage","enemyId":1,"damage":100.0})
	_check(is_equal_approx(before-float(boss.hp),100.0),"core damage command excludes target bonus")
	for e in r.enemies.values(): e.distanceTravelled = 0.0
	boss.distanceTravelled = 1000.0
	before = boss.hp
	r._core_beam_tick(10.0)
	_check(is_equal_approx(before-float(boss.hp),10.0),"core beam excludes target bonus")
	# In-flight projectile uses the setting at impact, not the firing snapshot.
	var flight = _projectile_test_runtime(input,1.0,50.0)
	flight.enemies["1"].type = "boss"
	_check(flight.projectiles.size() == 1,"boss live growth fixture fired projectile")
	flight._command({"kind":"combatConfig","config":{"bossDamageBonusRate":0.2}})
	_move_test_projectiles(flight,60.0)
	_check(is_equal_approx(1000.0-float(flight.enemies["1"].hp),120.0),"in-flight shot receives newly purchased bonus")
	var core_before: float = r._core_base_damage()
	r._configure_combat({"bossDamageBonusRate":0.0})
	_check(t.stats.damage == 100.0 and is_equal_approx(core_before,r._core_base_damage()),"conditional bonus leaves base stats and core DPS input unchanged")

func _training_input(fixtures: Array,type: String) -> Dictionary:
	for fixture in fixtures:
		if fixture.input.definition.type == type and fixture.input.level == 1 and fixture.input.gems.is_empty():
			var input: Dictionary = fixture.input.duplicate(true)
			input.definition.damage = 100.0
			input.definition.criticalChance = 0.0
			return input
	return {}

func _training_runtime(input: Dictionary,config: Dictionary = {}):
	var r = Runtime.new()
	r.start(100,{"combatConfig":config,"enemies":[{"id":1,"hp":10000.0,"maxHp":10000.0,"x":50.0,"y":0.0,"speed":0.0},{"id":2,"hp":10000.0,"maxHp":10000.0,"x":55.0,"y":1.0,"speed":0.0}],"turrets":[{"id":1,"position":[0,0],"statInput":input,"state":{"x":0,"y":0}}]},{"clock":"godot","phase":"wave","running":true})
	return r

func _training_attack(t: Dictionary,crit: float = 1.0) -> Dictionary:
	var attack: Dictionary = preload("res://combat/turret_stat_calculation.gd").firing_stats(t.statInput,t.stats,crit)
	attack.definition = t.statInput.definition
	attack.burnDamagePerSecondScale = 0.5
	attack.burnDurationSeconds = 2.0
	return attack

func _training_near(actual: float,expected: float,label: String) -> void:
	_check(absf(actual-expected)<1e-8*maxf(1.0,absf(expected)),label+" actual="+str(actual)+" expected="+str(expected))

func _damage_training_checks(fixtures: Array) -> void:
	const Stats = preload("res://combat/turret_stat_calculation.gd")
	var config := {"directDamageTrainingBonusRate":0.3,"splashDamageTrainingBonusRate":0.3,"damageOverTimeTrainingBonusRate":0.3}
	var input := _training_input(fixtures,"arrow")
	var r = _training_runtime(input,config)
	var t: Dictionary = r.turrets["1"]
	var attack := _training_attack(t)
	var e: Dictionary = r.enemies["1"]
	for kind in ["direct","splash","chain"]:
		var before: float = e.hp
		r._hit(t,attack,e,1.0,kind,kind=="direct",kind=="chain")
		_training_near(before-e.hp,160.0 if kind=="splash" else 130.0,kind+" hit training adds once; area30+hit30 is60 percent")
	var maximum = _training_runtime(input,{"directDamageTrainingBonusRate":0.4,"splashDamageTrainingBonusRate":0.4,"damageOverTimeTrainingBonusRate":0.4})
	var maximum_turret: Dictionary = maximum.turrets["1"]
	var maximum_attack: Dictionary = _training_attack(maximum_turret)
	for kind in ["direct","splash"]:
		var maximum_before: float = maximum.enemies["1"].hp
		maximum._hit(maximum_turret,maximum_attack,maximum.enemies["1"],1.0,kind,kind=="direct",false)
		_training_near(maximum_before-maximum.enemies["1"].hp,180.0 if kind=="splash" else 140.0,kind+" level80 uses full40 percent per training")
	attack.directDamageIncrease = 0.2
	attack.splashDamageIncrease = 0.1
	attack.chainDamageIncrease = 0.4
	for kind in ["direct","splash","chain"]:
		var before: float = e.hp
		r._hit(t,attack,e,1.0,kind,kind=="direct",kind=="chain")
		_training_near(before-e.hp,100.0*({"direct":1.5,"splash":1.9,"chain":1.9}[kind]),kind+" training joins existing core increase layer")
	attack.directDamageIncrease = 0.0
	attack.splashDamageIncrease = 0.0
	attack.chainDamageIncrease = 0.0
	attack.splashRadius = 20.0
	var before: float = e.hp
	var second_before: float = r.enemies["2"].hp
	r._impact(t,attack,e,r._pos(e),0.5,true)
	_training_near(before-e.hp,65.0,"chain direct uses hit training without area")
	_training_near(second_before-r.enemies["2"].hp,40.0,"chain explosion includes hit+area training and original coefficient")
	var frost = _training_runtime(_training_input(fixtures,"frost"),config)
	var ft: Dictionary = frost.turrets["1"]
	frost._tick_turret(ft,0.0)
	_training_near(10000.0-frost.enemies["1"].hp,160.0,"centered frost attack receives hit+area training")
	# Actual in-flight attacks see later growth, without rewriting their damage.
	var flight = _projectile_test_runtime(input,1.0,50.0)
	_check(flight.projectiles.size()==1,"training live-growth fixture fired projectile")
	flight._command({"kind":"combatConfig","config":config})
	_move_test_projectiles(flight,60.0)
	_training_near(1000.0-flight.enemies["1"].hp,130.0,"in-flight projectile reads newly bought hit training")
	# The DoT display includes the same additive layer, while raw fired/stored
	# DPS excludes training and preserves gems, acceleration, crit and resistance.
	input = _training_input(fixtures,"magic")
	input.primaryTrait = "highHeatBurn"
	input.moduleEffect.damageOverTimeIncreaseRate = 0.25
	input.coreEffects = {"damageOverTimeIncrease":0.153,"damageOverTimeSpeedMultiplier":1.5}
	input.gems = ["damageOverTime"]
	var plain: Dictionary = Stats.shared_stats_at(input,1)
	input.damageOverTimeTrainingBonusRate = 0.3
	var shown: Dictionary = Stats.shared_stats_at(input,1)
	_training_near(shown.damageOverTimeDamageMultiplier,(1.0+0.25+0.25+0.153+0.3)*1.3*1.5,"DoT HUD adds training before gem amplification and speed")
	_training_near(shown.damage,plain.damage,"training never inflates base turret damage")
	r = _training_runtime(input,{})
	t = r.turrets["1"]
	e = r.enemies["1"]
	e.familyResistances = {"elemental":0.2}
	attack = _training_attack(t,2.0)
	_training_near(attack.damageOverTimeDamageMultiplier,plain.damageOverTimeDamageMultiplier,"firing snapshot removes display training")
	_training_near(attack.damageOverTimeIncreaseMultiplier,1.653,"firing snapshot carries original additive layer only")
	r._hit(t,attack,e,1.0,"direct",true)
	var raw_dps: float = 100.0*0.5*1.653*1.3*1.5*1.5*0.8
	_training_near(e.burnInstances[0].damagePerSecond,raw_dps,"stored burn excludes training and retains critical/resistance/amplification")
	var core_before: float = r._core_base_damage()
	r._command({"kind":"combatConfig","config":config})
	r.running = false
	before = e.hp
	r._step(0.1)
	_training_near(before-e.hp,raw_dps*(1.0+0.3/1.653)*0.1,"already attached burn gets same-layer training on next tick")
	_training_near(e.burnInstances[0].damagePerSecond,raw_dps,"live training never rewrites stored burn DPS")
	var transfer: Dictionary = Enemy.burn_transfer(e,{"x":0,"y":0},0.3)
	Enemy.add_burn(r.enemies["2"],transfer)
	second_before = r.enemies["2"].hp
	r._step(0.1)
	_training_near(second_before-r.enemies["2"].hp,raw_dps*(1.0+0.3/1.653)*0.1,"transferred burn preserves original layer and applies training once")
	# Ignition consumes the trained effective DPS but remains a DoT effect:
	# neither hit nor splash training applies to its burst a second time.
	attack.hasDamageOverTime = false
	attack.appliesIgnitionBurst = true
	before = e.hp
	r._hit(t,attack,e,1.0,"direct",true)
	var burst: float = raw_dps*(1.0+0.3/1.653)*2.0*float(attack.damageOverTimeDurationMultiplier)*0.3
	_training_near(before-e.hp,100.0*2.0*1.3*0.8+burst,"ignition burst uses current DoT training exactly once")
	# Saving and resuming adopts current account config, never a frozen bonus.
	var saved := r.snapshot()
	var restored = Runtime.new()
	restored.start(101,{"combatConfig":config,"enemies":saved.enemies,"turrets":[]},{"clock":"godot","phase":"preparation","running":false})
	before = restored.enemies["1"].hp
	restored._step(0.1)
	_training_near(before-restored.enemies["1"].hp,raw_dps*(1.0+0.3/1.653)*0.1,"resumed new burn reads saved additive layer and latest training")
	# Direct core commands and guardian base DPS exclude all three trainings,
	# including the public stat's trained DoT multiplier.
	before = e.hp
	r._command({"kind":"coreDamage","enemyId":1,"damage":100.0})
	_training_near(before-e.hp,100.0,"core direct command excludes damage trainings")
	_training_near(core_before,r._core_base_damage(),"live damage training leaves core base DPS unchanged")
	t.statInput.erase("damageOverTimeTrainingBonusRate")
	t.stats = Stats.shared_stats_at(t.statInput,1)
	_training_near(core_before,r._core_base_damage(),"removing displayed DoT training leaves core base DPS unchanged")
