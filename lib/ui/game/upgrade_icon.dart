import 'package:flutter/material.dart';

const String _upgradeIconAssetRoot = 'assets/images/upgrades';

enum GameUpgradeIconType {
  nexusHp,
  towerDamage,
  physicalDamage,
  elementalDamage,
  criticalChance,
  criticalDamage,
  startingGold,
  waveGold,
  killGold,
  turretRefund,
}

/// 영구·런 업그레이드 효과를 공통 실루엣으로 표시하는 아이콘.
class UpgradeIcon extends StatelessWidget {
  const UpgradeIcon(
    this.type, {
    this.size = 18,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final GameUpgradeIconType type;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: upgradeIconImageProvider(type),
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

ImageProvider<Object> upgradeIconImageProvider(GameUpgradeIconType type) {
  return ResizeImage.resizeIfNeeded(
    128,
    128,
    AssetImage(_upgradeIconAsset(type)),
  );
}

String _upgradeIconAsset(GameUpgradeIconType type) {
  return switch (type) {
    GameUpgradeIconType.nexusHp => '$_upgradeIconAssetRoot/nexus_hp.png',
    GameUpgradeIconType.towerDamage =>
      '$_upgradeIconAssetRoot/tower_damage.png',
    GameUpgradeIconType.physicalDamage =>
      '$_upgradeIconAssetRoot/physical_damage.png',
    GameUpgradeIconType.elementalDamage =>
      '$_upgradeIconAssetRoot/elemental_damage.png',
    GameUpgradeIconType.criticalChance =>
      '$_upgradeIconAssetRoot/critical_chance.png',
    GameUpgradeIconType.criticalDamage =>
      '$_upgradeIconAssetRoot/critical_damage.png',
    GameUpgradeIconType.startingGold =>
      '$_upgradeIconAssetRoot/starting_gold.png',
    GameUpgradeIconType.waveGold => '$_upgradeIconAssetRoot/wave_gold.png',
    GameUpgradeIconType.killGold => '$_upgradeIconAssetRoot/kill_gold.png',
    GameUpgradeIconType.turretRefund =>
      '$_upgradeIconAssetRoot/turret_refund.png',
  };
}
