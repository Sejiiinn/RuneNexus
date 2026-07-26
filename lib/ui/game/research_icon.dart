import 'package:flutter/material.dart';

import '../../domain/research/research_type.dart';

const String _researchIconAssetRoot = 'assets/images/research';

/// 연구 효과를 고유 실루엣으로 표시하는 커스텀 아이콘.
class ResearchIcon extends StatelessWidget {
  const ResearchIcon(
    this.type, {
    this.size = 18,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final ResearchType type;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: researchIconImageProvider(type),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      semanticLabel: semanticLabel,
    );
  }
}

ImageProvider<Object> researchIconImageProvider(ResearchType type) {
  return ResizeImage.resizeIfNeeded(
    128,
    128,
    AssetImage(_researchIconAsset(type)),
  );
}

String _researchIconAsset(ResearchType type) {
  return switch (type) {
    ResearchType.researchEfficiency =>
      '$_researchIconAssetRoot/research_efficiency.png',
    ResearchType.researchCostEfficiency =>
      '$_researchIconAssetRoot/research_cost_efficiency.png',
    ResearchType.turretTargetPriority =>
      '$_researchIconAssetRoot/turret_target_priority.png',
    ResearchType.linkExpansionOne =>
      '$_researchIconAssetRoot/link_expansion_one.png',
    ResearchType.gemAttunement => '$_researchIconAssetRoot/gem_attunement.png',
    ResearchType.bossBounty => '$_researchIconAssetRoot/boss_bounty.png',
    ResearchType.linkMaintenance =>
      '$_researchIconAssetRoot/link_maintenance.png',
    ResearchType.crystalRecovery =>
      '$_researchIconAssetRoot/crystal_recovery.png',
    ResearchType.runeResonance => '$_researchIconAssetRoot/rune_resonance.png',
    ResearchType.runUpgradeCostOptimization =>
      '$_researchIconAssetRoot/run_upgrade_cost_optimization.png',
    ResearchType.towerDamageLimitExpansion =>
      '$_researchIconAssetRoot/tower_damage_limit_expansion.png',
    ResearchType.killGoldLimitExpansion =>
      '$_researchIconAssetRoot/kill_gold_limit_expansion.png',
    ResearchType.waveGoldLimitExpansion =>
      '$_researchIconAssetRoot/wave_gold_limit_expansion.png',
  };
}
