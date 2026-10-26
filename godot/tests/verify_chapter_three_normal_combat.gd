extends SceneTree
## Authored stats + real targeting, projectiles, kills, arrivals and settlement.
## Independent representative waves are seeded; wins are reported, not required.
const Catalog = preload("res://content/content_catalog.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Fixture = preload("res://session/chapter_three_combat_fixture.gd")
const Adapter = preload("res://app/content_run_save.gd")
var checks := 0
var failures: Array = []
var reports: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	var catalog = Catalog.new()
	check(catalog.load_catalog(),"catalog loads")
	for stage_id in range(26,31):
		for round_number in [10,20,30,40]: run_case(catalog,stage_id,round_number)
		var stage_kills := 0
		for report in reports:
			if report.stage == stage_id: stage_kills += int(report.events.kill)
		check(stage_kills > 0,str(stage_id)+" real authored-enemy kills")
	print(JSON.stringify({"checks":checks,"failures":failures,"cases":reports,"seed":Fixture.SEED,"balanceCertification":false}))
	quit(0 if failures.is_empty() else 1)
func run_case(catalog, stage_id: int, round_number: int) -> void:
	var label := "%d/%d" % [stage_id,round_number]
	var fixture: Dictionary = Fixture.create(catalog,stage_id,round_number)
	check(fixture.error.is_empty(),label+" legal fixture: "+fixture.error)
	if not fixture.error.is_empty(): return
	var domain = fixture.domain
	var runtime = Runtime.new()
	var sequence := 0
	check(runtime.process_command({"epoch":stage_id,"sequence":sequence,"bootstrap":fixture.bootstrap,"session":{"clock":"godot","phase":"preparation","paused":false}},false).accepted,label+" bootstrap")
	domain.state.phase = "wave"
	sequence += 1
	runtime.process_command({"epoch":stage_id,"sequence":sequence,"session":{"phase":"wave","paused":false},"running":true,"commands":[{"kind":"waveStart","wave":fixture.wave}]},false)
	var counts := {"kill":0,"arrival":0,"waveCompleted":0,"coreDefeated":0}
	var gold_before: int = domain.state.gold
	var saw_projectile := false
	var saw_damage := false
	var captured := false
	var duration := 0.0
	for frame in range(12000):
		runtime.advance_session(1.0/30.0)
		duration += 1.0/30.0
		if not runtime.projectiles.is_empty(): saw_projectile = true
		for turret in runtime.turrets.values():
			if float(turret.get("directDamageDealt",0))+float(turret.get("splashDamageDealt",0)) > 0: saw_damage = true
		for event in runtime.events:
			if int(event.id) > domain.event_ack and counts.has(event.kind): counts[event.kind] += 1
		var collected: Dictionary = domain.collect(runtime)
		check(collected.ok,label+" collect "+domain.error)
		if not collected.ok: return
		sequence += 1
		runtime.process_command({"epoch":stage_id,"sequence":sequence,"ackEvent":domain.event_ack,"commands":collected.commands},false)
		if not captured and frame >= 90 and not runtime.enemies.is_empty():
			captured = true
			sequence += 1
			runtime.process_command({"epoch":stage_id,"sequence":sequence,"session":{"paused":true}},false)
			var paused_clock: float = runtime.clock
			check(not runtime.advance_session(0.5) and runtime.clock == paused_clock,label+" actual native pause gate blocks fixed steps")
			var adapter = Adapter.new(catalog,domain.growth)
			var saved: Dictionary = adapter.capture(domain.state,runtime.snapshot(),1791560000000)
			check(not saved.is_empty(),label+" paused capture "+adapter.error)
			if not saved.is_empty():
				var prepared: Dictionary = adapter.prepare(saved)
				check(not prepared.is_empty(),label+" paused prepare "+adapter.error)
				if not prepared.is_empty():
					var restored = Runtime.new()
					restored.process_command({"epoch":stage_id,"sequence":0,"session":prepared.session,"bootstrap":prepared.bootstrap},false)
					check(restored.session.paused and restored.enemies.size() == runtime.enemies.size(),label+" paused restore enemies")
					check(is_equal_approx(restored.defense.hp,runtime.defense.hp),label+" restore natural core HP")
					# Continue the saved combat, not the original runtime.
					runtime = restored
					domain.restore(prepared.state)
					domain.event_ack = 0
					domain.collected_wall_time = restored.wall_elapsed
					sequence = 0
			sequence += 1
			runtime.process_command({"epoch":stage_id,"sequence":sequence,"session":{"paused":false}},false)
		if runtime.wave.completed or runtime.defense.hp <= 0: break
	check(saw_projectile and saw_damage,label+" real turret projectile damage")
	check(domain.state.gold > gold_before,label+" kill/clear gold awarded")
	check(counts.waveCompleted == 1 or counts.coreDefeated == 1,label+" natural terminal event")
	check(captured,label+" live paused checkpoint exercised")
	var settled: Dictionary = domain.state.duplicate(true)
	check(domain.collect(runtime).ok and domain.state == settled,label+" collection reward idempotence")
	reports.append({"stage":stage_id,"round":round_number,"events":counts,"seconds":snappedf(duration,0.01),"coreHp":runtime.defense.hp,"goldEarned":int(domain.state.gold)-gold_before,"turrets":domain.state.turrets.size(),"projectile":saw_projectile,"damage":saw_damage,"phase":domain.state.phase})
