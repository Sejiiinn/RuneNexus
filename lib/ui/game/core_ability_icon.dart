import 'package:flutter/material.dart';

import '../../domain/core/core_ability.dart';
import '../../domain/core/core_passive_tree.dart';

const String _coreAbilityIconAssetRoot = 'assets/images/core_abilities';
const String _corePassiveIconAssetRoot = 'assets/images/core_passives';

/// 코어 전투 스킬을 전용 시질 자산으로 표시하는 아이콘.
class CoreAbilityIcon extends StatelessWidget {
  const CoreAbilityIcon(
    this.skill, {
    this.size = 18,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final CoreCombatSkill skill;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _coreAbilityIconAsset(skill),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      cacheWidth: 128,
      cacheHeight: 128,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      semanticLabel: semanticLabel,
    );
  }
}

String _coreAbilityIconAsset(CoreCombatSkill skill) {
  return switch (skill) {
    CoreCombatSkill.guardianBeam =>
      '$_coreAbilityIconAssetRoot/guardian_beam.png',
    CoreCombatSkill.riftMark => '$_coreAbilityIconAssetRoot/rift_mark.png',
  };
}

/// 패시브 트리 노드를 자산 또는 Material 아이콘으로 표시하는 아이콘.
class CorePassiveNodeIcon extends StatelessWidget {
  const CorePassiveNodeIcon(
    this.nodeId, {
    this.size = 18,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final CorePassiveNodeId nodeId;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final asset = _corePassiveNodeIconAsset(nodeId);
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        cacheWidth: 128,
        cacheHeight: 128,
        color: color,
        colorBlendMode: color == null ? null : BlendMode.srcIn,
        semanticLabel: semanticLabel,
      );
    }
    return Semantics(
      label: semanticLabel,
      child: Icon(
        _corePassiveNodeMaterialIcon(nodeId),
        size: size,
        color: color,
      ),
    );
  }
}

String? _corePassiveNodeIconAsset(CorePassiveNodeId nodeId) {
  return switch (nodeId) {
    CorePassiveNodeId.controlSelfRepair =>
      '$_corePassiveIconAssetRoot/self_repair.png',
    CorePassiveNodeId.efficiencySaving =>
      '$_corePassiveIconAssetRoot/cost_saving_design.png',
    CorePassiveNodeId.attackHaste =>
      '$_corePassiveIconAssetRoot/skill_acceleration.png',
    CorePassiveNodeId.attackGuardianBeam =>
      '$_coreAbilityIconAssetRoot/guardian_beam.png',
    CorePassiveNodeId.attackRiftMark =>
      '$_coreAbilityIconAssetRoot/rift_mark.png',
    _ => null,
  };
}

IconData _corePassiveNodeMaterialIcon(CorePassiveNodeId nodeId) {
  return switch (nodeId) {
    CorePassiveNodeId.attackOutput => Icons.bolt,
    CorePassiveNodeId.attackPrecompute => Icons.timelapse,
    CorePassiveNodeId.attackFocus => Icons.center_focus_strong,
    CorePassiveNodeId.attackOverclock => Icons.electric_bolt,
    CorePassiveNodeId.controlThreatSense => Icons.radar,
    CorePassiveNodeId.controlRetarget => Icons.sync,
    CorePassiveNodeId.controlRearLock => Icons.shield_outlined,
    CorePassiveNodeId.controlEmergencyCharge => Icons.battery_charging_full,
    CorePassiveNodeId.controlBufferShell => Icons.health_and_safety_outlined,
    CorePassiveNodeId.controlFinalLine => Icons.security,
    CorePassiveNodeId.efficiencyDiversity => Icons.hub_outlined,
    CorePassiveNodeId.efficiencyFirstDeploy =>
      Icons.precision_manufacturing_outlined,
    CorePassiveNodeId.efficiencyFirstLink => Icons.device_hub,
    CorePassiveNodeId.efficiencyGemSpectrum => Icons.auto_awesome,
    CorePassiveNodeId.efficiencySupplyRecovery => Icons.savings_outlined,
    CorePassiveNodeId.efficiencyCombinedFront => Icons.account_tree_outlined,
    CorePassiveNodeId.hybridEmergencyCompute => Icons.warning_amber_rounded,
    CorePassiveNodeId.hybridCounterFire => Icons.gps_fixed,
    CorePassiveNodeId.hybridResonanceLoop => Icons.all_inclusive,
    CorePassiveNodeId.hybridMixedFire => Icons.call_split,
    CorePassiveNodeId.hybridSupplyBarrier => Icons.shield_moon_outlined,
    CorePassiveNodeId.hybridRecoveryBudget => Icons.build_circle_outlined,
    CorePassiveNodeId.attackHaste ||
    CorePassiveNodeId.attackGuardianBeam ||
    CorePassiveNodeId.attackRiftMark ||
    CorePassiveNodeId.controlSelfRepair ||
    CorePassiveNodeId.efficiencySaving => Icons.circle_outlined,
  };
}
