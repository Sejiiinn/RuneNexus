enum CorePassiveBranch { attack, control, efficiency }

enum CorePassiveNodeGrade { normal, notable, keystone }

enum CorePassiveNodeId {
  attackHaste,
  attackOutput,
  attackPrecompute,
  attackFocus,
  attackGuardianBeam,
  attackRiftMark,
  attackOverclock,
  controlThreatSense,
  controlSelfRepair,
  controlRetarget,
  controlRearLock,
  controlEmergencyCharge,
  controlBufferShell,
  controlFinalLine,
  efficiencySaving,
  efficiencyDiversity,
  efficiencyFirstDeploy,
  efficiencyFirstLink,
  efficiencyGemSpectrum,
  efficiencySupplyRecovery,
  efficiencyCombinedFront,
}

class CorePassiveNodeDefinition {
  const CorePassiveNodeDefinition({
    required this.id,
    required this.branch,
    required this.grade,
    required this.maxRank,
    required this.rankCosts,
    required this.neighbors,
    required this.displayValues,
  });

  final CorePassiveNodeId id;
  final CorePassiveBranch branch;
  final CorePassiveNodeGrade grade;
  final int maxRank;
  final List<int> rankCosts;
  final List<CorePassiveNodeId> neighbors;

  /// UI 문구 조합 전용 값. 전투 계산에는 사용하지 않는다.
  final List<String> displayValues;
}
