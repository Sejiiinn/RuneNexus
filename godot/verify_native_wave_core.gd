extends SceneTree
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Wave = preload("res://combat/native_wave_state.gd")
const Core = preload("res://combat/native_core_skill_state.gd")
var checks: int = 0
var failures: Array = []
func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/native_wave_core_timing.json"))
	_reference(fixture)
	_runtime()
	if failures.is_empty():
		print("PASS native wave/core: ",checks," checks; original Dart timing fixture, spawn/beam order, caps, sync, queue restore, immediate native defense, terminal failure, ACK idempotency, round transitions")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _compare(actual, expected, name: String) -> void:
	if expected is float or expected is int:
		_check((actual is float or actual is int) and absf(float(actual)-float(expected))<0.000000001,name+": "+str(actual)+" != "+str(expected))
	elif expected is Array:
		_check(actual is Array and actual.size()==expected.size(),name+" length")
		if actual is Array and actual.size()==expected.size():
			for index in range(expected.size()): _compare(actual[index],expected[index],name+"/"+str(index))
	elif expected is Dictionary:
		for key in expected:
			_check(actual.has(key),name+" has "+key)
			if actual.has(key): _compare(actual[key],expected[key],name+"/"+key)
	else:
		_check(actual == expected,name)

func _config(skill = "guardianBeam") -> Dictionary:
	return {"runSkill":skill,"cooldownRecoveryMultiplier":1.25,"guardianBeamInterval":5.0,"guardianBeamDuration":1.0,"guardianBeamTickInterval":0.1,"riftMarkInterval":10.0,"attackSyncDuration":2.0,"normalMaxHp":1000.0,"guardianMinNormalHpRate":0.1,"guardianDpsRate":0.08,"enemyHpCapRate":0.35,"bossHpCapRate":0.025,"powerMultiplier":1.5,"powerEveryThirdMultiplier":1.2,"attackSyncDamageMultiplier":1.25,"attackSyncAttackRateMultiplier":1.1}

func _reference(fixture: Dictionary) -> void:
	var w = Wave.new()
	w.start({"id":1,"active":true,"spawnQueue":fixture.schedule})
	for frame in fixture.waveFrames:
		var types: Array = []
		for spawned in w.advance(frame.dt): types.append(spawned.enemyType)
		_compare(types,frame.spawned,"Dart wave spawned dt="+str(frame.dt))
		_compare(w.snapshot().spawnQueue,frame.remaining,"Dart wave remaining")
	for case in fixture.cores:
		var c = Core.new()
		c.configure(_config(case.skill))
		for frame in case.frames:
			if frame.get("reset",false): c.reset_cycle()
			if frame.has("emergency"):
				_compare(c.emergency_charge(frame.emergency),frame.emergencyUsed,"Dart emergency")
			var ticks: Array = []
			var powers: Array = []
			c.update(frame.dt,func(): return bool(frame.target),func(): return 100.0,func(d): ticks.append(d),func(p): powers.append(p))
			_compare(c.snapshot(),frame.state,"Dart "+case.skill+" dt="+str(frame.dt))
			_compare(ticks,frame.ticks,"Dart beam ticks")
			_compare(powers,frame.powers,"Dart rift power")
	# A restored queue with close delays must not have the initial .18 gap reapplied.
	w.start({"id":2,"active":true,"spawnQueue":[{"enemyType":"fast","delay":0.01},{"enemyType":"normal","delay":0.0}]})
	_check(w.advance(0.01).size()==2,"restore preserves close remaining delays")
	w.start({"id":2,"active":true,"spawnQueue":fixture.schedule})
	w.advance(1.5)
	var restored = Wave.new()
	restored.start({"id":2,"active":true,"spawnQueue":w.snapshot().spawnQueue})
	var original_ready: Array = w.advance(0.35).map(func(v): return v.enemyType)
	var restored_ready: Array = restored.advance(0.35).map(func(v): return v.enemyType)
	_compare(original_ready,restored_ready,"restored cursor consumes same next entries")
	_compare(w.snapshot().spawnQueue,restored.snapshot().spawnQueue,"restored remaining queue equivalent")

func _enemy(id: int, hp: float = 1000.0, type: String = "normal") -> Dictionary:
	return {"id":id,"hp":hp,"maxHp":hp,"x":50.0,"y":0.0,"type":type,"path":[],"speed":0.0}

func _setup(enemies: Array = [], queue: Array = [], skill = "guardianBeam"):
	var r = Runtime.new()
	r.process_command({"epoch":1,"sequence":0,"running":true,"dt":0,"bootstrap":{"enemies":enemies,"turrets":[],"coreConfig":_config(skill),"wave":{"id":1,"active":true,"spawnQueue":queue}}})
	return r

func _count(r, kind: String) -> int:
	var count := 0
	for e in r.events:
		if e.kind == kind: count += 1
	return count

func _runtime() -> void:
	var spawn := _enemy(31)
	spawn.speed = 10.0
	spawn.path = [{"x":0.0,"y":0.0},{"x":100.0,"y":0.0}]
	spawn.x = 0.0
	var r = _setup([], [{"enemyType":"normal","delay":0.5,"enemy":spawn}])
	r.core.cooldown = 0.5
	r.process_command({"epoch":1,"sequence":1,"dt":0.5,"running":true})
	_check(r.enemies.size()==1,"native wave timer creates queued enemy")
	_compare(r.enemies["31"].distanceTravelled,0.0,"spawned enemy does not move in birth frame")
	_compare(r.enemies["31"].hp,985.0,"core targets newly born enemy same frame")
	_compare(r.core.activation_count,1,"activation once at ready spawn")
	var first := JSON.stringify(r.snapshot())
	r.process_command({"epoch":1,"sequence":1,"dt":8.0})
	_check(JSON.stringify(r.snapshot())==first,"duplicate spawn batch leaves timer and spawn unchanged")
	var clock: float = r.clock
	r.process_command({"epoch":1,"sequence":2,"dt":0.0})
	_compare(r.clock,clock,"pause zero dt does not advance native timers")
	var pending = _setup([_enemy(1,10)],[{"enemyType":"normal","delay":1.0,"enemy":_enemy(2,100)}],null)
	pending.process_command({"epoch":1,"sequence":1,"dt":0.5,"commands":[{"kind":"coreDamage","enemyId":1,"damage":20}]})
	_check(_count(pending,"waveCompleted")==0,"last kill with pending spawn does not clear")
	pending.process_command({"epoch":1,"sequence":2,"dt":0.5})
	_check(pending.enemies.has("2") and _count(pending,"waveCompleted")==0,"due spawn suppresses sameframe clear")
	pending.process_command({"epoch":1,"sequence":3,"dt":0.01,"commands":[{"kind":"coreDamage","enemyId":2,"damage":200}]})
	_check(_count(pending,"waveCompleted")==1,"last kill with empty schedule completes once")
	pending.process_command({"epoch":1,"sequence":4,"steps":[{"dt":0.1,"running":true},{"dt":0.1,"running":true}]})
	_check(_count(pending,"waveCompleted")==1,"stale queued running flag does not repeat completion")
	pending.process_command({"epoch":1,"sequence":5,"steps":[{"dt":0.1,"running":true,"commands":[{"kind":"waveStart","wave":{"id":2,"active":true,"spawnQueue":[{"enemyType":"normal","delay":0,"enemy":_enemy(3)}]}}]}]})
	_check(pending.wave.id==2 and pending.enemies.has("3"),"new round resets completion latch and spawns")
	# Native defense resolves arrival before skill update without an ACK round trip.
	var arriving := _enemy(8)
	arriving.x = 0.0
	arriving.speed = 10.0
	arriving.coreDamage = 10.0
	arriving.path = [{"x":0.0,"y":0.0},{"x":1.0,"y":0.0}]
	var arrival = _setup([arriving],[{"enemyType":"normal","delay":0.2,"enemy":_enemy(9)}])
	arrival.defense.configure({"maxHp":100.0,"emergencyRecoveryRate":0.35},{"hp":100.0})
	arrival.process_command({"epoch":1,"sequence":1,"steps":[{"dt":0.1,"running":true},{"dt":0.1,"running":true}]})
	_check(arrival.pending_steps.is_empty() and arrival.enemies.has("9"),"native defense continues queued birth without barrier")
	_compare(arrival.clock,0.2,"immediate defense preserves shared dt clock")
	_compare(arrival.defense.hp,90.0,"native core arrival deducts absolute hp")
	_compare(arrival.core.cooldown,2.4,"native emergency precedes original two core dt steps")
	_check(arrival.defense.emergency_charge_used_this_round,"eligible emergency consumes once")
	var death = _setup([arriving],[{"enemyType":"normal","delay":0.2,"enemy":_enemy(9)}])
	death.defense.configure({"maxHp":5.0},{"hp":5.0})
	death.process_command({"epoch":1,"sequence":1,"steps":[{"dt":0.1,"running":true},{"dt":9.0,"running":true}]})
	_check(death.terminal and death.pending_steps.is_empty() and death.wave.is_empty(),"lethal arrival discards pending simulation and spawn queue")
	_check(_count(death,"waveCompleted")==0 and death.core.activation_count==0,"lethal arrival cannot fire core or clear wave")
	_check(_count(death,"coreDefeated")==1,"lethal arrival emits one defeat")
	_compare(death.clock,0.1,"terminal stale running cannot advance")
	# Guardian boss cap is based on max HP, and tied progress keeps insertion order.
	var boss := _enemy(1,1000.0,"boss")
	var beam = _setup([boss,_enemy(2)])
	beam.core.cooldown = 0
	beam.process_command({"epoch":1,"sequence":1,"dt":0.01})
	_compare(beam.enemies["1"].hp,997.5,"boss beam cap 1000 * .025 * .1")
	_compare(beam.enemies["2"].hp,1000.0,"core progress ties preserve first insertion")
	var marks: Array = []
	for index in range(6):
		var enemy := _enemy(index+1,float((index+1)*100),"boss" if index==5 else "normal")
		enemy.distanceTravelled = index
		marks.append(enemy)
	var rift = _setup(marks,[],"riftMark")
	rift.core.cooldown = 0
	rift.core.activation_count = 2
	rift.process_command({"epoch":1,"sequence":1,"dt":0.01})
	_compare(rift.enemies["6"].riftMarkDamageAmplification,0.125*1.5*1.2,"third rift activation passive layers and boss amp")
	_compare(rift.enemies["3"].riftMarkDamageAmplification,0.25*1.5*1.2,"rift fourth strongest receives mark")
	_compare(rift.enemies["2"].riftMarkRemaining,0.0,"rift excludes fifth candidate")

	# Attack sync changes cached future-shot stats at activation and at expiry.
	var turret_fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/turret_stat_calculation.json"))
	var input: Dictionary = turret_fixtures[0].input.duplicate(true)
	input.definition.criticalChance = 0.0
	var sync = _setup([_enemy(61,10000)])
	sync._turret({"id":1,"position":[5000,0],"statInput":input,"state":{}})
	var damage: float = sync.turrets["1"].stats.damage
	var rate: float = sync.turrets["1"].stats.attackRate
	sync.core.cooldown = 0.0
	sync.process_command({"epoch":1,"sequence":1,"dt":0.1})
	_compare(sync.turrets["1"].stats.damage,damage*1.25,"native sync activation refreshes damage")
	_compare(sync.turrets["1"].stats.attackRate,rate*1.1,"native sync activation refreshes attack rate")
	sync.process_command({"epoch":1,"sequence":2,"dt":2.1})
	_compare(sync.turrets["1"].stats.damage,damage,"native sync expiration restores damage")
	_compare(sync.turrets["1"].stats.attackRate,rate,"native sync expiration restores attack rate")
	# Two simultaneous arrivals apply sequentially and consume emergency only once.
	var second := arriving.duplicate(true)
	second.id = 18
	var multi = _setup([arriving,second],[{"enemyType":"normal","delay":1.0,"enemy":_enemy(19)}])
	multi.defense.configure({"maxHp":100.0,"emergencyRecoveryRate":0.35},{"hp":100.0})
	multi.process_command({"epoch":1,"sequence":1,"dt":0.1})
	_check(_count(multi,"arrival")==2,"multiple arrivals emitted once in same native frame")
	_compare(multi.defense.hp,80.0,"multiple arrivals deduct both damages")
	_compare(multi.core.cooldown,2.5,"multiarrival applies one emergency then one core dt")
	var resized = _setup([],[{"enemyType":"normal","delay":0.5,"enemy":spawn}])
	resized.process_command({"epoch":1,"sequence":1,"dt":0.5,"commands":[{"kind":"layout","origin":[10,20],"tileSize":2.0,"boardDistanceScale":2.0,"path":[{"x":10,"y":20},{"x":210,"y":20}]}]})
	_compare(resized.enemies["31"].x,10.0,"queued enemy spawn applies resized origin")
	_compare(resized.enemies["31"].path[1].x,210.0,"queued enemy spawn applies resized path")

	var visual_frame: Dictionary = beam.decorate_frame({"presentation":{"effects":{}}})
	var beams: Array = visual_frame.presentation.effects.items.filter(func(v): return v.kind == "coreBeam")
	_check(beams.size()==1 and beams[0].points.size()==2,"coreBeam contains origin and target drawing endpoints")
	_compare(beams[0].duration,0.14,"coreBeam preserves original lifetime")
	var numbers: Array = visual_frame.presentation.effects.items.filter(func(v): return v.kind == "damage")
	_check(numbers.size()==1 and numbers[0].text=="3","beam actual damage number is rounded and visible")
	_compare(numbers[0].duration,0.75,"core damage number lifetime matches original")
	var rift_frame: Dictionary = rift.decorate_frame({"presentation":{"effects":{}}})
	var pulses: Array = rift_frame.presentation.effects.items.filter(func(v): return v.kind == "rift")
	_check(pulses.size()==1 and pulses[0].points.size()==4,"rift contains all marked target endpoints")
	_compare(pulses[0].duration,0.42,"rift preserves original lifetime")
