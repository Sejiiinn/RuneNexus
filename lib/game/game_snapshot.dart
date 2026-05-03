import '../domain/combat/game_phase.dart';
import '../domain/enemy/enemy_type.dart';
import '../domain/gem/gem_type.dart';
import '../domain/map/grid_point.dart';
import '../domain/turret/turret_type.dart';

class GameSnapshot {
  const GameSnapshot({
    required this.gold,
    required this.nexusHp,
    required this.maxNexusHp,
    required this.round,
    required this.maxRound,
    required this.phase,
    required this.selectedTurretType,
    required this.previewText,
    required this.rewardOptions,
    required this.gemInventory,
    required this.selectedBuildPoint,
    required this.selectedBuildTurretType,
    required this.selectedTurretPoint,
    required this.selectedTurretName,
    required this.selectedTurretGems,
    required this.selectedTurretGemSlotIndex,
    required this.selectedTurretSlotLimit,
    required this.selectedTurretHasLinkUpgrade,
    required this.selectedTurretCanUpgradeLink,
    required this.selectedTurretLinkUpgradeCost,
    required this.selectedTurretNextSlotLimit,
    required this.selectedTurretLinkUpgradeRequiredLevel,
    required this.selectedTurretLevel,
    required this.selectedTurretMaxLevel,
    required this.selectedTurretCanLevelUp,
    required this.selectedTurretLevelUpCost,
    required this.selectedTurretDamage,
    required this.selectedTurretRange,
    required this.selectedTurretAttackRate,
    required this.nextWaveEnemyTypes,
    required this.speedMultiplier,
    required this.runes,
    required this.lastRunRuneReward,
    required this.completedRounds,
    required this.startingGoldUpgradeLevel,
    required this.startingGoldUpgradeCost,
    required this.canUpgradeStartingGold,
    required this.nexusHpUpgradeLevel,
    required this.nexusHpUpgradeCost,
    required this.canUpgradeNexusHp,
  });

  final int gold;
  final int nexusHp;
  final int maxNexusHp;
  final int round;
  final int maxRound;
  final GamePhase phase;
  final TurretType selectedTurretType;
  final String previewText;
  final List<GemType> rewardOptions;
  final Map<GemType, int> gemInventory;
  final GridPoint? selectedBuildPoint;
  final TurretType? selectedBuildTurretType;
  final GridPoint? selectedTurretPoint;
  final String? selectedTurretName;
  final List<GemType> selectedTurretGems;
  final int? selectedTurretGemSlotIndex;
  final int selectedTurretSlotLimit;
  final bool selectedTurretHasLinkUpgrade;
  final bool selectedTurretCanUpgradeLink;
  final int selectedTurretLinkUpgradeCost;
  final int selectedTurretNextSlotLimit;
  final int selectedTurretLinkUpgradeRequiredLevel;
  final int selectedTurretLevel;
  final int selectedTurretMaxLevel;
  final bool selectedTurretCanLevelUp;
  final int selectedTurretLevelUpCost;
  final double selectedTurretDamage;
  final double selectedTurretRange;
  final double selectedTurretAttackRate;
  final List<EnemyType> nextWaveEnemyTypes;
  final double speedMultiplier;
  final int runes;
  final int lastRunRuneReward;
  final int completedRounds;
  final int startingGoldUpgradeLevel;
  final int startingGoldUpgradeCost;
  final bool canUpgradeStartingGold;
  final int nexusHpUpgradeLevel;
  final int nexusHpUpgradeCost;
  final bool canUpgradeNexusHp;
}
