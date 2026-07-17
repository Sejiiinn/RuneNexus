import 'package:flutter/material.dart';

import '../../domain/core/core_ability.dart';

const String _coreAbilityIconAssetRoot = 'assets/images/core_abilities';

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
