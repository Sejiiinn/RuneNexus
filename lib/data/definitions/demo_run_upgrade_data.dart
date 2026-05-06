import '../../domain/run_upgrade/run_upgrade_definition.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';

const demoRunUpgrades = <RunUpgradeType, RunUpgradeDefinition>{
  RunUpgradeType.towerDamage: RunUpgradeDefinition(
    type: RunUpgradeType.towerDamage,
    name: '포탑 화력',
    description: '모든 포탑 피해가 증가합니다.',
    effectLabel: '+3%',
    maxLevel: 10,
    baseCost: 40,
    costMultiplier: 1.5,
    effectPerLevel: 0.03,
  ),
  RunUpgradeType.killGold: RunUpgradeDefinition(
    type: RunUpgradeType.killGold,
    name: '처치 보너스',
    description: '적 처치 골드가 증가합니다.',
    effectLabel: '+2%',
    maxLevel: 20,
    baseCost: 20,
    costMultiplier: 1.2,
    effectPerLevel: 0.02,
  ),
  RunUpgradeType.waveGold: RunUpgradeDefinition(
    type: RunUpgradeType.waveGold,
    name: '정비 보급',
    description: '웨이브 종료 골드가 증가합니다.',
    effectLabel: '+2G',
    maxLevel: 20,
    baseCost: 10,
    costMultiplier: 1.2,
    effectPerLevel: 2,
  ),
};
