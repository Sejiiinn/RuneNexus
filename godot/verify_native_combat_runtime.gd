extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
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
	_exact_checks(fixtures)
	_response_mode_checks()
	if failures.is_empty():
		print("PASS native combat runtime: ", count, " configured turret cases, all six types, damage, ACK idempotency, gap rejection, batched timestep preservation")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

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
