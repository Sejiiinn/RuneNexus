extends SceneTree
## Focused production-path checks. No account, network, or player save is used.
const Catalog = preload("res://content/content_catalog.gd")
const Growth = preload("res://app/growth_rules.gd")
const Commands = preload("res://app/run_commands.gd")
const Adapter = preload("res://app/content_run_save.gd")
const Runtime = preload("res://combat/native_combat_runtime.gd")
const Codec = preload("res://app/save_codec.gd")
const Checkpoint = preload("res://session/session_checkpoint.gd")
const Controller = preload("res://session/session_controller.gd")
const App = preload("res://app/app_lifecycle.gd")
class Host extends "res://tests/verify_support_fake_battlefield.gd":
	func apply_frame(frame: Dictionary) -> void:
		if frame.get("reset", false):
			combat_runtime.active = false
			combat_base_frame = {}
class FailingCheckpoint extends Checkpoint:
	var fail_write := true
	func commit_capture(request: Dictionary, content, growth_rules) -> Error:
		if fail_write:
			message = "Injected terminal migration checkpoint failure"
			return ERR_FILE_CANT_WRITE
		return super.commit_capture(request, content, growth_rules)
var failures: Array = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var catalog = Catalog.new()
	var growth = Growth.new()
	check(catalog.load_catalog() and growth.load_catalog(), "catalogs load")
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.totalCorePoints = 999
	p.corePassiveTreeRevision = 5
	p.corePassiveNodeRanks = {}
	for key in growth.data.core.nodes:
		var node: Dictionary = growth.data.core.nodes[key]
		if not node.terminal: p.corePassiveNodeRanks[key] = mini(3, int(node.maxRank))
	for key in ["K2", "K5", "K7", "K8"]: p.corePassiveNodeRanks[key] = 1
	check(growth._valid_core(p.corePassiveNodeRanks, 999, 5), "connected high-earned-point fixture is valid")
	var service = Commands.new(catalog, growth)
	var state: Dictionary = service.initial_state(p, 0)
	growth.fix_run_loadout(state)
	state.gold = 100000
	state.tileSize = 1.0
	var map: Dictionary = catalog.stage_map(0)
	var tile: int = map.tiles.find("build")
	var built: Dictionary = service.apply(state, {"kind":"build", "type":"arrow", "x":tile % int(map.columns), "y":int(tile / int(map.columns))})
	check(built.ok, "build with frozen v5 loadout")
	state = built.state
	var id: int = state.turrets[0].id
	state.turrets[0].level = 10
	var before_gold: int = state.gold
	var quoted: int = service.quotes(state, id).level
	check(quoted > 0 and service._level_base_cost(growth.data.turretRules.arrow, 10) == 285, "elite level extends existing cost curve")
	var upgraded: Dictionary = service.apply(state, {"kind":"level", "id":id})
	check(upgraded.ok and upgraded.state.turrets[0].level == 11 and upgraded.state.gold == before_gold - quoted, "elite level is purchased with gold")
	state = upgraded.state
	check(int(service.quotes(state, id).level) == 0 and not service.apply(state, {"kind":"level", "id":id}).ok, "level 11 remains the cap")
	state.progression.corePassiveNodeRanks = {}
	check(service.max_turret_level(state, "arrow") == 11, "account reset does not alter stage-frozen cap")
	check(service.max_turret_level(service.initial_state(state.progression), "arrow") == 10, "next stage uses changed allocation")
	var defense_config: Dictionary = service.derived(state).defenseConfig
	var bootstrap: Dictionary = catalog.bootstrap(0, {"defenseConfig":defense_config,"coreConfig":growth.core_config(state, 0, 0, catalog)})
	bootstrap.turrets = service.runtime_commands(state).map(func(command): return command.turret)
	bootstrap.wave = {"id":1,"active":true,"spawnQueue":[]}
	var enemy: Dictionary = catalog.enemy(0, 0, "normal", 9000)
	enemy.firstControlApplied = true
	enemy.stunRemaining = 0.5
	enemy.freezeRemaining = 0.25
	bootstrap.enemies = [enemy]
	var runtime = Runtime.new()
	check(runtime.start(100, bootstrap, {"clock":"godot","phase":"wave","paused":true}).is_empty(), "production bootstrap starts")
	check(is_equal_approx(runtime.defense.additional_hp, float(defense_config.baseMaxHp) * 0.15), "stage start grants approved additional HP once")
	runtime.defense.additional_hp = 2.25
	runtime.defense.indomitable_used_this_stage = true
	runtime.defense.invulnerable_remaining = 1.25
	runtime.turrets[str(id)].stockpileCharges = 2
	state.phase = "wave"
	state.economyRunId = "00000000-0000-4000-8000-000000000123"
	runtime.apply_batch(100, [], {}, runtime.event_id)
	var adapter = Adapter.new(catalog, growth)
	var unfrozen := state.duplicate(true)
	unfrozen.erase("runCorePassiveTreeRevision")
	unfrozen.erase("runCorePassiveNodeRanks")
	var unfrozen_before := unfrozen.duplicate(true)
	check(adapter.capture(unfrozen, runtime.snapshot(), 123).is_empty() and adapter.error == "Domain state cannot roundtrip v2", "unfrozen v5 checkpoint fails without a script error")
	check(unfrozen == unfrozen_before, "rejected unfrozen checkpoint does not mutate its source")
	var saved: Dictionary = adapter.capture(state, runtime.snapshot(), 123)
	check(not saved.is_empty(), "save v5 checkpoint: " + adapter.error)
	if not saved.is_empty():
		check(saved.activeRun.runCorePassiveTreeRevision == 5 and saved.activeRun.turrets[0].level == 11, "save keeps frozen revision and elite level")
		check(saved.activeRun.nexusAdditionalHp == 2.25 and saved.activeRun.nexusAdditionalHpGranted and saved.activeRun.indomitableUsedThisStage and saved.activeRun.nexusInvulnerableRemaining == 1.25, "stage durability state saved")
		check(saved.activeRun.turrets[0].stockpileCharges == 2 and saved.activeRun.enemies[0].firstControlApplied, "earned charge and first-control marker saved")
		var restored: Dictionary = adapter.prepare(saved)
		check(not restored.is_empty(), "restore v5 checkpoint: " + adapter.error)
		if not restored.is_empty():
			var resumed = Runtime.new()
			check(resumed.start(101, restored.bootstrap, restored.session).is_empty(), "new epoch restores v5")
			check(resumed.defense.additional_hp == 2.25 and resumed.defense.indomitable_used_this_stage and resumed.defense.invulnerable_remaining == 1.25, "resume never regrants additional HP or fortress")
			check(resumed.turrets["1000"].stockpileCharges == 2 and resumed.turrets["1000"].stockpileIdleElapsed == 0.0, "earned charges survive while partial idle clock resets")
			check(resumed.enemies["100000"].firstControlApplied and resumed.enemies["100000"].stunRemaining == 0.5 and resumed.enemies["100000"].freezeRemaining == 0.25, "enemy control state survives resume")
		var forged := saved.duplicate(true)
		forged.activeRun.runCorePassiveNodeRanks = {}
		check(adapter.prepare(forged).is_empty(), "elite level cannot restore without frozen key")
	_migration_cases(growth)
	_checkpoint_migration_cases()
	print("EXPANDED_TREE_INTEGRATION checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _migration_cases(growth) -> void:
	var legacy_ranks := {"attackHaste":3,"attackPrecompute":3,"attackGuardianBeam":3,"attackOverclock":1}
	var legacy: Dictionary = Codec.decode({"version":2,"preferences":{},"turretModules":{},"progression":{"corePassiveTreeRevision":4,"corePassiveNodeRanks":legacy_ranks,"totalCorePoints":81,"claimedCorePointStageRewards":[1],"claimedEventIds":["kept"]},"activeRun":null})
	var once: Dictionary = growth.migrate_core_tree(legacy)
	check(once.changed and once.state.progression.totalCorePoints == 81 and once.state.progression.corePassiveNodeRanks.is_empty(), "refund preserves actual points above natural 60")
	check(once.state.progression.claimedCorePointStageRewards == [1] and once.state.progression.claimedEventIds == ["kept"], "refund preserves reward claims")
	check(once.state.progression.corePassiveLegacyAllocation.ranks == legacy_ranks and once.state.progression.corePassiveLegacyAllocation.refundedPoints == 23, "migration archives real v4 allocation and exact paid cost")
	check(not growth.migrate_core_tree(once.state).changed, "migration is idempotent")
	for phase in ["preparation", "wave", "reward", "restored"]:
		var waiting := legacy.duplicate(true)
		waiting.activeRun = {"phase":phase,"runCorePassiveNodeRanks":legacy.progression.corePassiveNodeRanks.duplicate(true)}
		var result: Dictionary = growth.migrate_core_tree(waiting)
		check(not result.changed and result.deferred and result.state == waiting, "migration defers suspended phase " + phase)
	for phase in ["success", "failure", "coreDestruction"]:
		var finished := legacy.duplicate(true)
		finished.activeRun = {"phase":phase,"runCorePassiveNodeRanks":legacy.progression.corePassiveNodeRanks.duplicate(true)}
		var result: Dictionary = growth.migrate_core_tree(finished)
		check(result.changed and result.state.activeRun.runCorePassiveTreeRevision == 4 and result.state.activeRun.runCorePassiveNodeRanks == legacy.progression.corePassiveNodeRanks, "ended run keeps old loadout " + phase)

func _checkpoint_migration_cases() -> void:
	var directory := OS.get_environment("TMPDIR").path_join("expanded-tree-checkpoint-" + str(OS.get_process_id()))
	var app = App.new()
	app.scene = Host.new()
	app.checkpoint = FailingCheckpoint.new(directory, "guest")
	app.checkpoint.allow_progression_only = true
	app.run_domain.now_millis = func(): return 1700000000000
	check(app.catalog.load_catalog() and app.run_domain.growth.load_catalog() and app.retry_load(), "isolated lifecycle initialized")
	app.progression_inputs.corePassiveTreeRevision = 4
	app.progression_inputs.corePassiveNodeRanks = {"attackHaste":3,"attackPrecompute":3,"attackGuardianBeam":3,"attackOverclock":1}
	app.progression_inputs.totalCorePoints = 83
	check(app.enter_stage(0), "legacy stage starts without migration")
	app.checkpoint.fail_write = false
	check(app.persist_progression(), "legacy preparation checkpoint saved")
	var initial: Dictionary = app.checkpoint.store.load_save()
	check(initial.progression.corePassiveTreeRevision == 4 and initial.activeRun.runCorePassiveTreeRevision == 4, "suspended preparation remains v4 on disk")
	var old_id: String = app.run_domain.state.economyRunId
	var old_ranks: Dictionary = app.run_domain.state.progression.corePassiveNodeRanks.duplicate(true)
	app.checkpoint.fail_write = true
	check(not app.prepare_run_transition(), "failed terminal migration stays blocked")
	check(app.run_domain.state.progression.corePassiveTreeRevision == 4 and app.run_domain.state.progression.corePassiveNodeRanks == old_ranks and app.run_domain.state.economyRunId == old_id and app.run_domain.state.phase == "preparation", "failed migration preserves live old run and allocation")
	check(app.checkpoint.store.load_save().progression.corePassiveTreeRevision == 4, "failed migration preserves durable old allocation")
	app.checkpoint.fail_write = false
	check(app.prepare_run_transition(), "retry terminal migration commits")
	var finished: Dictionary = app.checkpoint.store.load_save()
	check(finished.progression.corePassiveTreeRevision == 5 and finished.progression.totalCorePoints == 83 and finished.progression.corePassiveNodeRanks.is_empty(), "durable terminal commit refunds without changing earned points")
	check(finished.activeRun.runCorePassiveTreeRevision == 4 and finished.activeRun.runCorePassiveNodeRanks == old_ranks and finished.progression.corePassiveLegacyAllocation.refundedPoints == 23, "terminal record freezes v4 and archives paid allocation")
	check(app.checkpoint.rewards().state.pendingRewards.size() == 1, "terminal migration retains one reward outbox item")
	check(app.persist_progression() and app.checkpoint.rewards().state.pendingRewards.size() == 1, "repeat terminal checkpoint cannot duplicate refund or reward")
	app.scene.free()
	app.free()
	var restored = App.new()
	restored.scene = Host.new()
	restored.checkpoint = Checkpoint.new(directory, "guest")
	restored.checkpoint.allow_progression_only = true
	restored.run_domain.now_millis = func(): return 1700000000000
	check(restored.catalog.load_catalog() and restored.run_domain.growth.load_catalog() and restored.retry_load(), "migrated terminal checkpoint reloads")
	check(restored.run_domain.state.progression.corePassiveTreeRevision == 5 and restored.run_domain.state.runCorePassiveTreeRevision == 4 and restored.run_domain.state.progression.totalCorePoints == 83, "restart retains migrated account and legacy terminal run")
	restored.scene.free()
	restored.free()
