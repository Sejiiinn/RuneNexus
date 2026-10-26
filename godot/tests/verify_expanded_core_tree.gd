extends SceneTree
const Growth = preload("res://app/growth_rules.gd")
const Codec = preload("res://app/save_codec.gd")
const Hash = preload("res://services/save_payload_hash.gd")
var assertions := 0
var failures: Array = []
func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures.append(label)
func _initialize() -> void:
	var growth := Growth.new()
	check(growth.load_catalog(), "load versioned catalogs")
	var p: Dictionary = growth.data.defaultProgression.duplicate(true)
	p.totalCorePoints = 777
	var tree: Dictionary = growth.core_catalog(p)
	check(tree.revision == 5 and tree.nodes.size() == 60, "60 purchasable nodes")
	check(tree.edges.size() == 89 and tree.edges.size() - (tree.nodes.size() + 1) + 1 == 29, "89 edges 29 independent cycles")
	check(tree.startingNodes.size() == 6, "six starts")
	check(growth.core_catalog({"corePassiveTreeRevision":-1}).is_empty() and growth.core_catalog({"corePassiveTreeRevision":6}).is_empty(), "unsupported catalog revision rejected")
	var full := {}
	for id in tree.nodes: full[id] = int(tree.nodes[id].maxRank)
	check(growth.valid_core_ranks(p, full), "full catalog reachable within actual total777")
	check(growth.core_spent_points({"S1":5}) == 9 and growth.core_spent_points({"B02":3}) == 10 and growth.core_spent_points({"K1":1}) == 5, "incremental costs")
	check(growth.valid_core_ranks(p, {"S1":3,"A02":1}), "OR one rank3 neighbor enough")
	check(not growth.valid_core_ranks(p, {"S1":2,"A02":1}), "rank2 cannot unlock")
	check(not growth.valid_core_ranks(p, {"A02":3,"A03":3,"B03":3}), "disconnected cycle cannot bootstrap")
	check(not growth.valid_core_ranks(p, {"S1":6}) and not growth.valid_core_ranks(p, {"unknown":1}) and not growth.valid_core_ranks(p, {"CORE":1}), "max rank and IDs")
	p.totalCorePoints = 4
	check(growth.execute(p, {"type":"setCorePassiveRank","id":"S1","rank":3}).ok, "three ranks cost4")
	check(not growth.execute(p, {"type":"setCorePassiveRank","id":"S1","rank":4}).ok, "budget not total-at-rank")
	p.totalCorePoints = 777
	p.corePassiveNodeRanks = {"S1":3,"A02":3}
	var refund: Dictionary = growth.core_refund_preview(p,"S1",2)
	check(not refund.valid and "A02" in refund.orphaned and refund.refundedPoints == 2 and refund.bundleRefundedPoints == 6, "orphan refund explicit preview")
	check(not growth.execute(p,{"type":"setCorePassiveRank","id":"S1","rank":2}).ok, "single refund rejects orphan")
	check(growth.execute(p,{"type":"setCorePassiveRanks","ranks":refund.bundleRanks}).ok, "explicit bundle accepted")
	var reset := growth.execute(p,{"type":"resetCorePassiveTree"})
	check(reset.ok and reset.state.totalCorePoints == 777 and reset.state.corePassiveNodeRanks.is_empty(), "free full reset actualpoints preserved")
	# Terminal nodes do not become traversal relays even if malformed rank input is supplied to reachability.
	var terminal: Dictionary = tree.nodes.K1
	var prior: Array = terminal.neighbors.duplicate()
	terminal.neighbors.append("TEST_ORPHAN")
	check(not "TEST_ORPHAN" in growth.core_accessible_nodes(full), "keystone never propagates")
	terminal.neighbors = prior
	var effects := growth.core_effects({"corePassiveTreeRevision":5,"corePassiveNodeRanks":{"S3":5,"A06":5,"C10":3,"C12":3,"K1":1,"K2":1,"K3":1,"K4":1,"K5":1,"K6":1,"K7":1,"K8":1}})
	check(is_equal_approx(effects.controlDurationIncrease,.375), "all control duration additions")
	check(effects.nexusAdditionalHpRate == .15 and effects.nexusMaxHpMultiplier == 1.0, "additional HP replaces C12 ordinary HP")
	check(effects.killCoreChargeRate == .1 and effects.hasStockpileFire and effects.stockpileAimSpeedMultiplier == 1.5 and effects.stockpileCooldownRecoveryMultiplier == 1.5, "K1 K2 revised contracts")
	check(effects.damageOverTimeSpeedMultiplier == 1.5 and effects.splashSecondaryDamageBonus == .15 and effects.maxTurretLevelBonus == 1, "K3 K4 K5 revised contracts")
	check(effects.equippedGemDamageAmplificationPerGem == .05 and effects.firstControlDurationMultiplier == 2.0 and effects.hasIndomitableFortress, "K6 K7 K8 revised contracts")
	check(effects.startingGoldMultiplier == 1.0 and effects.buildCostMultiplier == 1.0 and effects.turretLevelUpCostMultiplier == 1.0, "no keystone penalties")
	var old: Dictionary = p.duplicate(true)
	old.corePassiveTreeRevision = 4
	old.corePassiveNodeRanks = {"attackHaste":3,"attackPrecompute":3}
	old.claimedCorePointStageRewards = [1,2,30]
	var envelope := {"version":2,"preferences":{},"progression":old,"turretModules":{},"activeRun":{"phase":"wave","runCorePassiveNodeRanks":old.corePassiveNodeRanks.duplicate(true)}}
	var before := envelope.duplicate(true)
	var deferred := growth.migrate_core_tree(envelope)
	check(deferred.deferred and not deferred.changed and deferred.state == envelope and envelope == before, "active legacy run unchanged and not forced ended")
	envelope.activeRun.phase = "preparation"
	check(growth.migrate_core_tree(envelope).deferred, "suspended/preparation legacy run deferred")
	envelope.activeRun.phase = "success"
	var migrated := growth.migrate_core_tree(envelope)
	check(migrated.changed and not migrated.deferred, "terminal migration")
	check(migrated.state.progression.totalCorePoints == 777 and migrated.state.progression.claimedCorePointStageRewards == [1,2,30], "points and reward claims preserved")
	check(migrated.state.progression.corePassiveNodeRanks.is_empty() and migrated.state.progression.corePassiveLegacyAllocation.ranks == old.corePassiveNodeRanks and migrated.state.progression.corePassiveLegacyAllocation.refundedPoints == 8, "exact archive and refund")
	check(migrated.state.activeRun.runCorePassiveTreeRevision == 4 and migrated.state.activeRun.runCorePassiveNodeRanks == old.corePassiveNodeRanks, "terminal frozen old loadout")
	check(not growth.migrate_core_tree(migrated.state).changed, "migration idempotent")
	var run := {"progression":p.duplicate(true)}
	growth.fix_run_loadout(run)
	run.progression.corePassiveNodeRanks = {"S2":5}
	check(run.runCorePassiveTreeRevision == 5 and run.runCorePassiveNodeRanks == p.corePassiveNodeRanks, "stage-start snapshot immutable after allocation change")
	check(growth.run_effect_progression(run).corePassiveNodeRanks == p.corePassiveNodeRanks, "runtime uses frozen allocation")
	var terminal_state: Dictionary = migrated.state.activeRun.duplicate(true)
	terminal_state.progression = migrated.state.progression
	check(growth.core_effects(growth.run_effect_progression(terminal_state)).cooldownRecoveryRate == .06, "old evaluator retained after account migration")
	var canonical: Dictionary = Codec.decode(migrated.state)
	check(canonical.progression.corePassiveLegacyAllocation == migrated.state.progression.corePassiveLegacyAllocation and canonical.activeRun.runCorePassiveNodeRanks == old.corePassiveNodeRanks, "archive and old frozen ranks codec roundtrip")
	canonical.progression.corePassiveNodeRanks = {"S1":5,"K2":1}
	canonical.activeRun.runCorePassiveTreeRevision = 5
	canonical.activeRun.runCorePassiveNodeRanks = {"S1":5,"K2":1}
	canonical.activeRun.nexusAdditionalHp = 1.25
	canonical.activeRun.nexusAdditionalHpGranted = true
	canonical.activeRun.indomitableUsedThisStage = true
	canonical.activeRun.nexusInvulnerableRemaining = 1.75
	for revision in ["5",5.0,-1,6,null]:
		var invalid_revision := canonical.duplicate(true)
		invalid_revision.progression.corePassiveTreeRevision = revision
		check(Codec.decode(invalid_revision) == null, "invalid revision rejected " + str(revision))
	for bad in [{"unknown":1},{"S1":1.5},{"S1":6},{"K1":2}]:
		var invalid := canonical.duplicate(true)
		invalid.progression.corePassiveNodeRanks = bad
		check(Codec.decode(invalid) == null, "v5 malformed allocation rejected " + str(bad))
	for missing in ["runCorePassiveTreeRevision","runCorePassiveNodeRanks"]:
		var incomplete := canonical.duplicate(true)
		incomplete.activeRun.erase(missing)
		check(Codec.decode(incomplete) == null, "v5 frozen field required " + missing)
	var invalid_run := canonical.duplicate(true)
	invalid_run.activeRun.runCorePassiveNodeRanks = {"unknown":1}
	check(Codec.decode(invalid_run) == null, "v5 malformed frozen ranks rejected")
	var reloaded: Dictionary = Codec.decode(canonical)
	check(Codec.is_normalized_v2(canonical) and reloaded == canonical, "v5 rank and defense snapshot roundtrip")
	var hash_before := Hash.hash_payload(canonical)
	canonical.activeRun.nexusAdditionalHp = 1.0
	check(hash_before != Hash.hash_payload(canonical), "additionalHP included in payloadhash")
	var legacy: Dictionary = Codec.decode(before)
	check(not legacy.activeRun.has("runCorePassiveTreeRevision") and not legacy.activeRun.has("nexusAdditionalHp"), "absent legacy fields remain absent")
	var enemy: Dictionary = Codec._object("SavedEnemy",{"type":"normal","firstControlApplied":true,"stunRemaining":.4,"freezeRemaining":.2})
	check(enemy.firstControlApplied and enemy.stunRemaining == .4 and enemy.freezeRemaining == .2, "control state saved")
	var turret: Dictionary = Codec._object("SavedTurret",{"type":"arrow","stockpileCharges":2})
	check(turret.stockpileCharges == 2, "stockpile charge saved")
	print("EXPANDED_CORE_TREE assertions=%d failures=%s" % [assertions,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
