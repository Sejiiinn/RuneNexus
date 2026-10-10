extends SceneTree
## Actual main/HUD with the legal, explicitly seeded normal-combat profile.
## Required observed interactions only; full-wave outcomes are a separate 60 Hz test.
## Five representative boss waves, not economy/balance or Android certification.
## Set RUNE_CH3_COMBAT_CAPTURE_DIR; no network or production saves are used.
const Fixture = preload("res://session/chapter_three_combat_fixture.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
var scene
var app
var directory := ""
var failures: Array[String] = []
var reports: Array = []
var seen_event := 0
var counts := {}
var witnessed := {}
var routes_seen := {}
var boss_ids := {}
var startup_smoke := false

func progress(stage_id: int, label: String) -> void:
	var runtime = scene._native_combat
	print("COMBAT_PROGRESS ", JSON.stringify({"stage":stage_id,"point":label,"clock":runtime.clock,"paused":runtime.session.get("paused"),"phase":runtime.session.get("phase"),"speed":runtime.session.get("speed"),"focus":scene._session_has_focus,"suspended":scene._session_suspended,"battleVisible":scene._battle_visible,"preparing":scene._stage_preparation_pending,"saveFailed":app.save_failed,"debt":runtime.simulation_debt,"enemies":runtime.enemies.size(),"events":counts}))

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok and label not in failures:
		failures.append(label)
		push_error(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	print("COMBAT_CAPTURE_BEGIN ",label)
	for frame in range(2): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png")) == OK,"capture "+label)
	print("COMBAT_CAPTURE ",label)

func present() -> void:
	scene._apply_frame(scene._native_combat_base_frame)
	app.hud.refresh()

func observe_step() -> void:
	var runtime = scene._native_combat
	for enemy: Dictionary in runtime.enemies.values():
		if enemy.hp <= 0 or enemy.arrived: continue
		routes_seen[str(enemy.get("routeId","default"))] = true
		if str(enemy.type).to_lower().contains("boss"):
			boss_ids[int(enemy.id)] = true
			witnessed.boss = true
			if float(enemy.hp)+float(enemy.armor)+float(enemy.shield) < float(enemy.maxHp)+float(enemy.maxArmor)+float(enemy.maxShield): witnessed.bossDamage = true
	for turret: Dictionary in runtime.turrets.values():
		if int(turret.shotSequence)>0: witnessed.shots = true
		if float(turret.directDamageDealt)+float(turret.splashDamageDealt)+float(turret.chainDamageDealt)+float(turret.burnDamageDealt)>0: witnessed.damage = true
		if boss_ids.has(int(turret.aimTargetId)): witnessed.bossTarget = true
	if not runtime.projectiles.is_empty(): witnessed.projectile = true
	for event: Dictionary in runtime.events:
		if int(event.id) <= seen_event: continue
		seen_event = int(event.id)
		if counts.has(event.kind): counts[event.kind] += 1

func connect_observer() -> void:
	var runtime = scene._native_combat
	# Observe completed real steps before the ordinary app settles and ACKs them.
	if runtime.step_completed.is_connected(app._on_combat_step_completed): runtime.step_completed.disconnect(app._on_combat_step_completed)
	runtime.step_completed.connect(observe_step)
	runtime.step_completed.connect(app._on_combat_step_completed)
	seen_event = 0

func active_identity() -> Array:
	var result: Array = []
	for enemy: Dictionary in scene._native_combat.enemies.values():
		if enemy.hp <= 0 or enemy.arrived: continue
		result.append([str(enemy.type),str(enemy.get("routeId","")),str(enemy.get("spawnPortalId","")),snappedf(float(enemy.distanceTravelled),0.0001)])
	result.sort_custom(func(a,b): return JSON.stringify(a)<JSON.stringify(b))
	return result

func press_text(parent: Node,text: String) -> bool:
	for button: Button in parent.find_children("*","Button",true,false):
		if button.text == text:
			check(not button.disabled,"enabled UI "+text)
			button.pressed.emit()
			return true
	check(false,"find UI "+text)
	return false

func save_restore(stage_id: int) -> bool:
	var before: Array = active_identity()
	var original = scene._native_combat
	app.hud.home.pressed.emit()
	if not press_text(app.hud.modal,"저장하고 나가기"): return false
	check(app.in_lobby and not app.save_failed,"save-to-lobby UI "+str(stage_id))
	await capture("stage-%d-saved-lobby" % stage_id)
	# Exercise the disk adapter and a fresh runtime, not cached Continue alone.
	check(app.checkpoint.load_session(app) == OK,"load real disk checkpoint "+str(stage_id))
	check(scene._native_combat != original,"disk load creates fresh runtime "+str(stage_id))
	check(active_identity() == before,"active route/portal identity and distance survive disk restore "+str(stage_id))
	check(bool(scene._native_combat.session.paused),"restore paused "+str(stage_id))
	connect_observer()
	app.lobby.page = "로비"
	app._refresh_ui()
	await process_frame
	var button := app.lobby.find_child("ContinueRun",true,false) as Button
	check(button != null,"actual Continue UI exists "+str(stage_id))
	if button == null: return false
	button.pressed.emit()
	while app._stage_entry_pending: await process_frame
	check(not app.in_lobby,"Continue UI returns to battlefield "+str(stage_id))
	present()
	await capture("stage-%d-restored-paused" % stage_id)
	app.hud.start.pressed.emit()
	app.hud.speed_buttons[4].pressed.emit()
	check(not bool(scene._native_combat.session.paused),"UI resumes restored combat "+str(stage_id))
	return true

func run() -> void:
	directory = OS.get_environment("RUNE_CH3_COMBAT_CAPTURE_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../normal-combat-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(440,900)
	scene = load("res://main.gd").new()
	scene._app_mode = true
	root.add_child(scene)
	app = scene._standalone_session
	var services = app.services
	app.services = null
	if services != null: services.free()
	app.checkpoint = Checkpoint.new(directory.path_join("isolated-save"))
	app.checkpoint.allow_progression_only = true
	check(app.retry_load(),"isolated offline startup")
	startup_smoke = "--startup-smoke" in OS.get_cmdline_user_args()
	var selected_cases: Array = [[26,10]] if startup_smoke else ([[28,10],[29,10],[30,30]] if "--remaining-cases" in OS.get_cmdline_user_args() else [[26,10],[27,20],[28,10],[29,10],[30,30]])
	for spec in selected_cases:
		var stage_id: int = spec[0]
		var round_number: int = spec[1]
		var fixture: Dictionary = Fixture.create(app.catalog,stage_id,round_number)
		check(fixture.error.is_empty(),"legal seeded profile "+str(stage_id))
		if not fixture.error.is_empty(): continue
		var seeded: Dictionary = fixture.domain.state.duplicate(true)
		# The reusable numeric simulation uses 48-unit tiles; the shipped app's
		# checkpoint contract uses one-tile coordinates. Re-derive all positions
		# and ranges, preserving exactly the legally purchased board and stats.
		seeded.tileSize = 1.0
		var index: int = app.catalog.stage_index(stage_id)
		var derived: Dictionary = fixture.domain.service.derived(seeded)
		var bootstrap: Dictionary = app.catalog.bootstrap(index,{"tileSize":1.0,"defenseConfig":derived.defenseConfig,"coreConfig":fixture.domain.growth.core_config(seeded,index,round_number-1,app.catalog)})
		bootstrap.turrets = []
		for command in fixture.domain.service.runtime_commands(seeded): bootstrap.turrets.append(command.turret)
		scene._native_combat.active = false
		app.run_domain.state.clear()
		app.progression_inputs = seeded.progression.duplicate(true)
		check(await app.start_stage(index),"prepare real stage "+str(stage_id))
		app.battle_inputs = {"tileSize":1.0}
		app.enter_stage(index,bootstrap,{"phase":"preparation","paused":false},seeded)
		check(is_equal_approx(scene._native_combat.tile_size,1.0),"native checkpoint coordinates "+str(stage_id))
		check(scene._native_combat.turrets.size() == seeded.turrets.size(),"seed/runtime legal board count "+str(stage_id))
		print("COMBAT_SETUP stage=",stage_id," seeded_turrets=",seeded.turrets.size()," runtime_turrets=",scene._native_combat.turrets.size()," tile_size=",scene._native_combat.tile_size)
		app.next_round = round_number-1
		app.spawn_rng.seed = Fixture.SEED+stage_id*100+round_number
		app._refresh_ui()
		present()
		counts = {"kill":0,"arrival":0,"teleport":0,"waveCompleted":0,"coreDefeated":0}
		witnessed = {"shots":false,"projectile":false,"damage":false,"boss":false,"bossTarget":false,"bossDamage":false}
		routes_seen.clear(); boss_ids.clear()
		connect_observer()
		await capture("stage-%d-round-%d-legal-board" % [stage_id,round_number])
		app.hud.start.pressed.emit()
		check(scene._native_combat.wave.active,"Start UI begins authored wave "+str(stage_id))
		check(not app.save_failed,"Start UI persists checkpoint "+str(stage_id)+": "+app.checkpoint.message)
		check(not bool(scene._native_combat.session.paused),"Start UI leaves combat running "+str(stage_id))
		print("COMBAT_STARTED stage=",stage_id," save_failed=",app.save_failed," paused=",scene._native_combat.session.paused)
		if app.save_failed: break
		var shots_saved := false
		var boss_saved := false
		var kill_saved := false
		var teleport_saved := false
		var pause_done := false
		var restored := false
		var after_restore_damage := false
		var damage_at_restore := 0.0
		var terminal := false
		var observed := false
		var resume_clock := -1.0
		var steps := 0
		var last_log := Time.get_ticks_msec()
		var last_motion := last_log
		var last_clock: float = scene._native_combat.clock
		while steps < 12000:
			await process_frame
			var runtime = scene._native_combat
			if not failures.is_empty(): break
			steps += 1
			var now := Time.get_ticks_msec()
			if runtime.clock != last_clock:
				last_clock = runtime.clock
				last_motion = now
			if now-last_log >= 10000:
				progress(stage_id,"live frame %d" % steps)
				last_log = now
			if now-last_motion > 45000:
				progress(stage_id,"stalled")
				check(false,"no combat clock progress for 45 real seconds stage="+str(stage_id))
				break
			if steps == 10:
				print("COMBAT_LIVE stage=",stage_id," clock=",runtime.clock," session=",runtime.session," focus=",scene._session_has_focus," suspended=",scene._session_suspended)
			if app.save_failed:
				check(false,"combat checkpoint failure: "+app.checkpoint.message)
				break
			if not shots_saved and witnessed.projectile:
				shots_saved = true
				await capture("stage-%d-real-projectiles" % stage_id)
			if not boss_saved and witnessed.bossDamage:
				boss_saved = true
				await capture("stage-%d-boss-hit" % stage_id)
			if not kill_saved and counts.kill>0:
				kill_saved = true
				await capture("stage-%d-real-kill" % stage_id)
			if stage_id == 27 and not teleport_saved and counts.teleport > 0:
				teleport_saved = true
				await capture("stage-27-real-teleport")
			if not pause_done and shots_saved and not runtime.enemies.is_empty():
				app.hud.pause_button.pressed.emit()
				var clock_before: float = runtime.clock
				var identity_before := active_identity()
				await process_frame
				await process_frame
				check(runtime.clock == clock_before and active_identity() == identity_before,"Pause UI freezes actual combat "+str(stage_id))
				present()
				await capture("stage-%d-paused" % stage_id)
				progress(stage_id,"before resume")
				app.hud.start.pressed.emit()
				progress(stage_id,"after resume")
				check(not bool(runtime.session.paused) and not app.save_failed,"Resume UI runs and saves stage="+str(stage_id))
				app.hud.speed_buttons[4].pressed.emit()
				progress(stage_id,"after 4x")
				check(not bool(runtime.session.paused) and not app.save_failed,"4x keeps combat running stage="+str(stage_id))
				check(float(runtime.session.speed) == 4.0,"4x UI applies "+str(stage_id))
				pause_done = true
				resume_clock = runtime.clock
				last_motion = Time.get_ticks_msec()
			if stage_id in [28,30] and not restored and pause_done:
				var alive_routes := {}
				for row: Array in active_identity(): alive_routes[row[1]] = true
				if alive_routes.size() >= 2:
					progress(stage_id,"before disk restore")
					restored = await save_restore(stage_id)
					progress(stage_id,"after disk restore")
					if not restored:
						check(false,"disk restore/Continue interaction failed stage="+str(stage_id))
						write_report()
						break
					last_motion = Time.get_ticks_msec()
					runtime = scene._native_combat
					damage_at_restore = total_damage(runtime)
			if restored and total_damage(runtime) > damage_at_restore: after_restore_damage = true
			var combat_observed: bool = witnessed.shots and witnessed.projectile and witnessed.damage and counts.kill > 0 and witnessed.boss and witnessed.bossTarget and witnessed.bossDamage
			var controls_observed: bool = pause_done and runtime.clock > resume_clock + 1.0 and not bool(runtime.session.paused)
			var mechanism_observed: bool = (stage_id != 27 or counts.teleport > 0) and (stage_id not in [28,30] or (restored and after_restore_damage and routes_seen.size() >= 2))
			observed = combat_observed and controls_observed and mechanism_observed
			if observed: break
			if startup_smoke and runtime.clock >= 4.0 and witnessed.shots: break
			if runtime.wave.completed or runtime.defense.hp <= 0:
				terminal = true
				break
		var runtime = scene._native_combat
		if not startup_smoke: check(observed,"all required real combat observations "+str(stage_id))
		check(witnessed.shots and witnessed.projectile and witnessed.damage and (startup_smoke or counts.kill>0),"real firing hits and kills "+str(stage_id))
		check(startup_smoke or (witnessed.boss and witnessed.bossTarget and witnessed.bossDamage),"real boss target and damage "+str(stage_id))
		check(pause_done,"actual Pause/4x exercised "+str(stage_id))
		if stage_id == 27: check(counts.teleport > 0,"authored combat traverses teleport")
		if stage_id in [28,30]: check(restored and after_restore_damage,"real combat after route-preserving restore "+str(stage_id))
		await capture("stage-%d-observed-combat" % stage_id)
		reports.append({"stage":stage_id,"round":round_number,"seed":fixture.seed,"legalCommands":fixture.commandCount,"turrets":seeded.turrets.size(),"events":counts.duplicate(),"witnessed":witnessed.duplicate(),"routes":routes_seen.keys(),"restored":restored,"damageAfterRestore":after_restore_damage,"coreHp":runtime.defense.hp,"phase":app.run_domain.state.phase,"steps":steps,"requiredObservationsComplete":observed,"naturalTerminalObserved":terminal,"fullWaveCompletion":false})
		print("NORMAL_COMBAT_CASE ",JSON.stringify(reports[-1]))
		write_report()
		if not failures.is_empty(): break
	write_report()
	print("CH3_NORMAL_COMBAT_RENDER failures=",failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func total_damage(runtime) -> float:
	var result := 0.0
	for turret: Dictionary in runtime.turrets.values():
		for key in ["directDamageDealt","splashDamageDealt","chainDamageDealt","burnDamageDealt"]: result += float(turret[key])
	return result

func write_report() -> void:
	var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":Fixture.SEED,"profile":"legal-state progressed fixture, 60000 seeded run gold, 1000 shards, 60 each unlocked gem; authored combat stats","balanceCertification":false,"fullWaveCompletion":false,"startupSmokeOnly":startup_smoke,"remainingCasesOnly":"--remaining-cases" in OS.get_cmdline_user_args(),"renderer":RenderingServer.get_current_rendering_method(),"failures":failures,"cases":reports},"  "))
