import 'package:flutter/material.dart';

import '../../domain/core/core_ability.dart';

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

/// 코어 패시브를 전용 시질 자산으로 표시하는 아이콘.
class CorePassiveIcon extends StatelessWidget {
  const CorePassiveIcon(
    this.ability, {
    this.size = 18,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final CorePassiveAbility ability;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _corePassiveIconAsset(ability),
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

String _corePassiveIconAsset(CorePassiveAbility ability) {
  return switch (ability) {
    CorePassiveAbility.selfRepair =>
      '$_corePassiveIconAssetRoot/self_repair.png',
    CorePassiveAbility.costSavingDesign =>
      '$_corePassiveIconAssetRoot/cost_saving_design.png',
    CorePassiveAbility.skillAcceleration =>
      '$_corePassiveIconAssetRoot/skill_acceleration.png',
  };
}
