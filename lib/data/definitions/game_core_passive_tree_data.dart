import '../../domain/core/core_passive_tree.dart';

const int corePassiveTreeRevision = 3;

const double corePassiveAttackSyncDurationSeconds = 2;

const List<double> _attackHasteRecoveryRates = [
  0.02,
  0.04,
  0.06,
  0.08,
  0.10,
];
const List<double> _attackOutputIncreaseRates = [
  0.05,
  0.10,
  0.15,
  0.20,
  0.25,
];
const List<double> _attackSpeedSyncAmplificationRates = [
  0.03,
  0.06,
  0.09,
  0.12,
  0.15,
];
const List<double> _attackDamageSyncAmplificationRates = [
  0.04,
  0.08,
  0.12,
  0.16,
  0.20,
];
const List<double> _continuousComputationRecoveryRates = [0.05, 0.10, 0.15];
const List<double> _criticalOutputAmplificationRates = [0.20, 0.30, 0.40];
const double _transcendentOutputAmplificationRate = 0.25;
const List<double> _reinforcedShellMaxHpRates = [
  0.05,
  0.10,
  0.15,
  0.20,
  0.25,
];
const List<double> _selfRepairRecoveryRates = [
  0.01,
  0.015,
  0.02,
  0.025,
  0.03,
];
const List<double> _damageRestorationRates = [0.15, 0.25, 0.35];
const List<double> _impactDispersionReductionRates = [
  0.03,
  0.06,
  0.09,
  0.12,
  0.15,
];
const List<double> _threatWeakeningReductionRates = [
  0.05,
  0.10,
  0.15,
  0.20,
  0.25,
];
const List<double> _emergencyChargeRecoveryRates = [0.15, 0.25, 0.35];

double _corePassiveRankRate(List<double> rates, int rank) {
  if (rank <= 0) {
    return 0;
  }
  return rates[rank.clamp(1, rates.length).toInt() - 1];
}

double corePassiveCooldownRecoveryRate(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return _corePassiveRankRate(
        _attackHasteRecoveryRates,
        nodeRanks[CorePassiveNodeId.attackHaste] ?? 0,
      ) +
      _corePassiveRankRate(
        _continuousComputationRecoveryRates,
        nodeRanks[CorePassiveNodeId.attackGuardianBeam] ?? 0,
      );
}

double corePassiveTurretAttackRateAmplification(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return _corePassiveRankRate(
    _attackSpeedSyncAmplificationRates,
    nodeRanks[CorePassiveNodeId.attackPrecompute] ?? 0,
  );
}

double corePassiveTurretDamageAmplification(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return _corePassiveRankRate(
    _attackDamageSyncAmplificationRates,
    nodeRanks[CorePassiveNodeId.attackFocus] ?? 0,
  );
}

double corePassiveCoreSkillPowerMultiplier(
  Map<CorePassiveNodeId, int> nodeRanks, {
  required int activationNumber,
}) {
  final outputIncrease = _corePassiveRankRate(
    _attackOutputIncreaseRates,
    nodeRanks[CorePassiveNodeId.attackOutput] ?? 0,
  );
  final criticalOutputAmplification =
      activationNumber > 0 && activationNumber % 3 == 0
      ? _corePassiveRankRate(
          _criticalOutputAmplificationRates,
          nodeRanks[CorePassiveNodeId.attackRiftMark] ?? 0,
        )
      : 0.0;
  final transcendentOutputAmplification =
      (nodeRanks[CorePassiveNodeId.attackOverclock] ?? 0) > 0
      ? _transcendentOutputAmplificationRate
      : 0.0;
  return (1.0 + outputIncrease) *
      (1.0 + criticalOutputAmplification) *
      (1.0 + transcendentOutputAmplification);
}

double corePassiveNexusMaxHpMultiplier(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return 1.0 +
      _corePassiveRankRate(
        _reinforcedShellMaxHpRates,
        nodeRanks[CorePassiveNodeId.controlSelfRepair] ?? 0,
      );
}

double corePassiveRoundRecoveryRate(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return _corePassiveRankRate(
    _selfRepairRecoveryRates,
    nodeRanks[CorePassiveNodeId.controlRetarget] ?? 0,
  );
}

double corePassiveDamageRestorationRate(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return _corePassiveRankRate(
    _damageRestorationRates,
    nodeRanks[CorePassiveNodeId.controlBufferShell] ?? 0,
  );
}

double corePassiveNexusDamageMultiplier(
  Map<CorePassiveNodeId, int> nodeRanks, {
  required double lostDurabilityRatio,
}) {
  final impactDispersionRate = _corePassiveRankRate(
    _impactDispersionReductionRates,
    nodeRanks[CorePassiveNodeId.controlThreatSense] ?? 0,
  );
  final threatWeakeningRate = _corePassiveRankRate(
    _threatWeakeningReductionRates,
    nodeRanks[CorePassiveNodeId.controlRearLock] ?? 0,
  );
  final durabilityRatio = lostDurabilityRatio.clamp(0.0, 1.0).toDouble();
  return (1.0 - impactDispersionRate) *
      (1.0 - threatWeakeningRate * durabilityRatio);
}

double corePassiveEmergencyChargeRecoveryRate(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return _corePassiveRankRate(
    _emergencyChargeRecoveryRates,
    nodeRanks[CorePassiveNodeId.controlEmergencyCharge] ?? 0,
  );
}

bool corePassiveHasFinalDefense(
  Map<CorePassiveNodeId, int> nodeRanks,
) {
  return (nodeRanks[CorePassiveNodeId.controlFinalLine] ?? 0) > 0;
}

const Set<CorePassiveNodeId> corePassiveStartingNodeIds = {
  CorePassiveNodeId.attackHaste,
  CorePassiveNodeId.attackOutput,
  CorePassiveNodeId.efficiencySaving,
  CorePassiveNodeId.efficiencyDiversity,
  CorePassiveNodeId.controlSelfRepair,
  CorePassiveNodeId.controlThreatSense,
};

const List<int> _normalCosts = [1, 1, 2, 2, 3];
const List<int> _notableCosts = [2, 3, 5];
const List<int> _keystoneCosts = [5];

class _CorePassiveNodeSpec {
  const _CorePassiveNodeSpec({
    required this.branch,
    required this.grade,
    required this.displayValues,
  });

  final CorePassiveBranch branch;
  final CorePassiveNodeGrade grade;
  final List<String> displayValues;
}

const Map<CorePassiveNodeId, _CorePassiveNodeSpec> _nodeSpecs = {
  CorePassiveNodeId.attackHaste: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.attack,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['2%', '4%', '6%', '8%', '10%'],
  ),
  CorePassiveNodeId.attackOutput: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.attack,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['5%', '10%', '15%', '20%', '25%'],
  ),
  CorePassiveNodeId.attackPrecompute: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.attack,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['3%', '6%', '9%', '12%', '15%'],
  ),
  CorePassiveNodeId.attackFocus: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.attack,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['4%', '8%', '12%', '16%', '20%'],
  ),
  CorePassiveNodeId.attackGuardianBeam: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.attack,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['5%', '10%', '15%'],
  ),
  CorePassiveNodeId.attackRiftMark: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.attack,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['20%', '30%', '40%'],
  ),
  CorePassiveNodeId.attackOverclock: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.attack,
    grade: CorePassiveNodeGrade.keystone,
    displayValues: ['25%'],
  ),
  CorePassiveNodeId.controlThreatSense: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.control,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['3%', '6%', '9%', '12%', '15%'],
  ),
  CorePassiveNodeId.controlSelfRepair: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.control,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['5%', '10%', '15%', '20%', '25%'],
  ),
  CorePassiveNodeId.controlRetarget: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.control,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['1%', '1.5%', '2%', '2.5%', '3%'],
  ),
  CorePassiveNodeId.controlRearLock: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.control,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['5%', '10%', '15%', '20%', '25%'],
  ),
  CorePassiveNodeId.controlEmergencyCharge: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.control,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['15%', '25%', '35%'],
  ),
  CorePassiveNodeId.controlBufferShell: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.control,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['15%', '25%', '35%'],
  ),
  CorePassiveNodeId.controlFinalLine: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.control,
    grade: CorePassiveNodeGrade.keystone,
    displayValues: ['1'],
  ),
  CorePassiveNodeId.efficiencySaving: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.efficiency,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['3%', '6%', '9%', '12%', '15%'],
  ),
  CorePassiveNodeId.efficiencyDiversity: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.efficiency,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['0.5%', '0.75%', '1%', '1.25%', '1.5%'],
  ),
  CorePassiveNodeId.efficiencyFirstDeploy: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.efficiency,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['4%', '8%', '12%', '16%', '20%'],
  ),
  CorePassiveNodeId.efficiencyFirstLink: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.efficiency,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['4%', '8%', '12%', '16%', '20%'],
  ),
  CorePassiveNodeId.efficiencyGemSpectrum: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.efficiency,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['2%', '3%', '4%'],
  ),
  CorePassiveNodeId.efficiencySupplyRecovery: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.efficiency,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['8%', '12%', '16%'],
  ),
  CorePassiveNodeId.efficiencyCombinedFront: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.efficiency,
    grade: CorePassiveNodeGrade.keystone,
    displayValues: ['20% / 10%'],
  ),
  CorePassiveNodeId.hybridEmergencyCompute: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.hybrid,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['5%', '10%', '15%', '20%', '25%'],
  ),
  CorePassiveNodeId.hybridCounterFire: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.hybrid,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['10%', '20%', '30%'],
  ),
  CorePassiveNodeId.hybridResonanceLoop: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.hybrid,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['0.1초', '0.2초', '0.3초', '0.4초', '0.5초'],
  ),
  CorePassiveNodeId.hybridMixedFire: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.hybrid,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['6%', '9%', '12%'],
  ),
  CorePassiveNodeId.hybridSupplyBarrier: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.hybrid,
    grade: CorePassiveNodeGrade.normal,
    displayValues: ['1', '2', '3', '4', '5'],
  ),
  CorePassiveNodeId.hybridRecoveryBudget: _CorePassiveNodeSpec(
    branch: CorePassiveBranch.hybrid,
    grade: CorePassiveNodeGrade.notable,
    displayValues: ['8%', '12%', '16%'],
  ),
};

const List<(CorePassiveNodeId, CorePassiveNodeId)> _edges = [
  (CorePassiveNodeId.attackHaste, CorePassiveNodeId.attackPrecompute),
  (CorePassiveNodeId.attackPrecompute, CorePassiveNodeId.attackGuardianBeam),
  (CorePassiveNodeId.attackGuardianBeam, CorePassiveNodeId.attackOverclock),
  (CorePassiveNodeId.attackOutput, CorePassiveNodeId.attackFocus),
  (CorePassiveNodeId.attackFocus, CorePassiveNodeId.attackRiftMark),
  (CorePassiveNodeId.attackRiftMark, CorePassiveNodeId.attackOverclock),
  (CorePassiveNodeId.efficiencySaving, CorePassiveNodeId.efficiencyFirstDeploy),
  (
    CorePassiveNodeId.efficiencyFirstDeploy,
    CorePassiveNodeId.efficiencyGemSpectrum,
  ),
  (
    CorePassiveNodeId.efficiencyGemSpectrum,
    CorePassiveNodeId.efficiencyCombinedFront,
  ),
  (
    CorePassiveNodeId.efficiencyDiversity,
    CorePassiveNodeId.efficiencyFirstLink,
  ),
  (
    CorePassiveNodeId.efficiencyFirstLink,
    CorePassiveNodeId.efficiencySupplyRecovery,
  ),
  (
    CorePassiveNodeId.efficiencySupplyRecovery,
    CorePassiveNodeId.efficiencyCombinedFront,
  ),
  (CorePassiveNodeId.controlSelfRepair, CorePassiveNodeId.controlRetarget),
  (CorePassiveNodeId.controlRetarget, CorePassiveNodeId.controlBufferShell),
  (CorePassiveNodeId.controlBufferShell, CorePassiveNodeId.controlFinalLine),
  (CorePassiveNodeId.controlThreatSense, CorePassiveNodeId.controlRearLock),
  (CorePassiveNodeId.controlRearLock, CorePassiveNodeId.controlEmergencyCharge),
  (
    CorePassiveNodeId.controlEmergencyCharge,
    CorePassiveNodeId.controlFinalLine,
  ),
  (CorePassiveNodeId.attackHaste, CorePassiveNodeId.hybridEmergencyCompute),
  (
    CorePassiveNodeId.controlThreatSense,
    CorePassiveNodeId.hybridEmergencyCompute,
  ),
  (
    CorePassiveNodeId.hybridEmergencyCompute,
    CorePassiveNodeId.hybridCounterFire,
  ),
  (CorePassiveNodeId.attackOutput, CorePassiveNodeId.hybridResonanceLoop),
  (CorePassiveNodeId.efficiencySaving, CorePassiveNodeId.hybridResonanceLoop),
  (CorePassiveNodeId.hybridResonanceLoop, CorePassiveNodeId.hybridMixedFire),
  (
    CorePassiveNodeId.efficiencyDiversity,
    CorePassiveNodeId.hybridSupplyBarrier,
  ),
  (CorePassiveNodeId.controlSelfRepair, CorePassiveNodeId.hybridSupplyBarrier),
  (
    CorePassiveNodeId.hybridSupplyBarrier,
    CorePassiveNodeId.hybridRecoveryBudget,
  ),
];

final Map<CorePassiveNodeId, CorePassiveNodeDefinition>
corePassiveNodeDefinitions = _buildCorePassiveNodeDefinitions();

Map<CorePassiveNodeId, CorePassiveNodeDefinition>
_buildCorePassiveNodeDefinitions() {
  final neighbors = {
    for (final id in CorePassiveNodeId.values) id: <CorePassiveNodeId>{},
  };
  for (final (first, second) in _edges) {
    neighbors[first]!.add(second);
    neighbors[second]!.add(first);
  }
  return Map.unmodifiable({
    for (final entry in _nodeSpecs.entries)
      entry.key: CorePassiveNodeDefinition(
        id: entry.key,
        branch: entry.value.branch,
        grade: entry.value.grade,
        maxRank: _rankCosts(entry.value.grade).length,
        rankCosts: _rankCosts(entry.value.grade),
        neighbors: List.unmodifiable(neighbors[entry.key]!),
        displayValues: entry.value.displayValues,
      ),
  });
}

List<int> _rankCosts(CorePassiveNodeGrade grade) => switch (grade) {
  CorePassiveNodeGrade.normal => _normalCosts,
  CorePassiveNodeGrade.notable => _notableCosts,
  CorePassiveNodeGrade.keystone => _keystoneCosts,
};

CorePassiveNodeDefinition corePassiveNodeById(CorePassiveNodeId id) =>
    corePassiveNodeDefinitions[id]!;

int corePassiveCumulativeCost(CorePassiveNodeId id, int rank) {
  final definition = corePassiveNodeById(id);
  if (rank < 0 || rank > definition.maxRank) {
    throw RangeError.range(rank, 0, definition.maxRank, 'rank');
  }
  return definition.rankCosts.take(rank).fold(0, (sum, cost) => sum + cost);
}

int corePassiveSpentPoints(Map<CorePassiveNodeId, int> ranks) {
  var spent = 0;
  for (final entry in ranks.entries) {
    if (entry.value > 0) {
      spent += corePassiveCumulativeCost(entry.key, entry.value);
    }
  }
  return spent;
}

Set<CorePassiveNodeId> accessibleCorePassiveNodeIds(
  Map<CorePassiveNodeId, int> ranks,
) {
  final accessible = <CorePassiveNodeId>{...corePassiveStartingNodeIds};
  var changed = true;
  while (changed) {
    changed = false;
    for (final id in accessible.toList()) {
      if ((ranks[id] ?? 0) < 3) {
        continue;
      }
      for (final neighbor in corePassiveNodeById(id).neighbors) {
        changed = accessible.add(neighbor) || changed;
      }
    }
  }
  return Set.unmodifiable(accessible);
}

bool isValidCorePassiveAllocation(Map<CorePassiveNodeId, int> ranks) {
  for (final entry in ranks.entries) {
    final definition = corePassiveNodeDefinitions[entry.key];
    if (definition == null ||
        entry.value < 0 ||
        entry.value > definition.maxRank) {
      return false;
    }
  }
  final accessible = accessibleCorePassiveNodeIds(ranks);
  return ranks.entries.every(
    (entry) => entry.value == 0 || accessible.contains(entry.key),
  );
}

List<String> corePassiveTreeValidationErrors() {
  final errors = <String>[];
  if (corePassiveNodeDefinitions.length != CorePassiveNodeId.values.length) {
    errors.add('node count mismatch');
  }
  if (corePassiveStartingNodeIds.length != 6) {
    errors.add('starting node count mismatch');
  }
  for (final definition in corePassiveNodeDefinitions.values) {
    if (definition.rankCosts.length != definition.maxRank ||
        definition.displayValues.length != definition.maxRank) {
      errors.add('${definition.id.name}: rank data mismatch');
    }
    if (definition.neighbors.contains(definition.id) ||
        definition.neighbors.toSet().length != definition.neighbors.length) {
      errors.add('${definition.id.name}: invalid neighbors');
    }
    for (final neighbor in definition.neighbors) {
      if (!corePassiveNodeById(neighbor).neighbors.contains(definition.id)) {
        errors.add(
          '${definition.id.name}: asymmetric neighbor ${neighbor.name}',
        );
      }
    }
  }
  final reached = <CorePassiveNodeId>{...corePassiveStartingNodeIds};
  var changed = true;
  while (changed) {
    changed = false;
    for (final id in reached.toList()) {
      for (final neighbor in corePassiveNodeById(id).neighbors) {
        changed = reached.add(neighbor) || changed;
      }
    }
  }
  if (reached.length != CorePassiveNodeId.values.length) {
    errors.add('unreachable nodes');
  }
  return List.unmodifiable(errors);
}
