import '../domain/combat/game_phase.dart';
import '../domain/combat/auto_start_mode.dart';
import '../domain/combat/run_panel_tab.dart';
import '../domain/enemy/enemy_type.dart';
import '../domain/gem/gem_type.dart';
import '../domain/map/grid_point.dart';
import '../domain/research/research_progress.dart';
import '../domain/research/research_type.dart';
import '../domain/run_upgrade/run_upgrade_type.dart';
import '../domain/turret/turret_target_priority.dart';
import '../domain/turret/turret_trait_type.dart';
import '../domain/turret/turret_type.dart';

class GameSnapshot {
  const GameSnapshot({
    required this.gold,
    required this.gemShards,
    required this.nexusHp,
    required this.maxNexusHp,
    required this.round,
    required this.maxRound,
    required this.phase,
    required this.restoredPhase,
    required this.hasStageProgress,
    required this.placedTurretCount,
    required this.currentStageNumber,
    required this.unlockedStageCount,
    required this.bestRoundsByStage,
    required this.clearedStageNumbers,
    required this.availableTurretTypes,
    required this.selectedTurretType,
    required this.selectedRunPanelTab,
    required this.previewText,
    required this.rewardOptions,
    required this.isPurchasedGemReward,
    required this.gemInventory,
    required this.gemCollection,
    required this.selectedBuildPoint,
    required this.selectedBuildTurretType,
    required this.selectedPortalPoint,
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
    required this.selectedTurretLevelUpPreviewActive,
    required this.selectedTurretNextLevel,
    required this.selectedTurretNextDamage,
    required this.selectedTurretNextRange,
    required this.selectedTurretNextAttackRate,
    required this.selectedTurretNextBurnDamagePerSecond,
    required this.selectedTurretNextBurnDuration,
    required this.selectedTurretRefundGold,
    required this.selectedTurretDamage,
    required this.selectedTurretRange,
    required this.selectedTurretAttackRate,
    required this.selectedTurretBurnDamagePerSecond,
    required this.selectedTurretBurnDuration,
    required this.selectedTurretDamageDealt,
    required this.selectedTurretDirectDamageDealt,
    required this.selectedTurretSplashDamageDealt,
    required this.selectedTurretChainDamageDealt,
    required this.selectedTurretBurnDamageDealt,
    required this.canSetTurretTargetPriority,
    required this.selectedTurretTargetPriority,
    required this.selectedTurretSupportsTraits,
    required this.selectedTurretPrimaryTraitChoices,
    required this.selectedTurretSecondaryTraitChoices,
    required this.selectedTurretPrimaryTrait,
    required this.selectedTurretSecondaryTrait,
    required this.selectedTurretCanChoosePrimaryTrait,
    required this.selectedTurretCanChooseSecondaryTrait,
    required this.selectedTurretPrimaryTraitCost,
    required this.selectedTurretSecondaryTraitCost,
    required this.selectedTurretPrimaryTraitRequiredLevel,
    required this.selectedTurretSecondaryTraitRequiredLevel,
    required this.topDamageTurretName,
    required this.topDamageTurretDamageDealt,
    required this.totalTurretDps,
    required this.nexusCoreBeamIntervalSeconds,
    required this.nexusCoreBeamCooldownSeconds,
    required this.nexusCoreBeamActive,
    required this.nexusCoreBeamDamage,
    required this.nextWaveEnemyTypes,
    required this.nextWaveEnemyCounts,
    required this.nextWaveClearRewardGold,
    required this.nextWaveKillRewardGold,
    required this.nextWaveClearRewardGemShards,
    required this.autoStartMode,
    required this.speedMultiplier,
    required this.killGoldFractionWallet,
    required this.runUpgradeLevels,
    required this.towerDamageRunBonusRate,
    required this.killGoldRunBonusRate,
    required this.waveClearGoldRunBonus,
    required this.runes,
    required this.lastRunRuneReward,
    required this.projectedFailureRuneReward,
    required this.lastRunPreviousBestRound,
    required this.lastRunWasNewBestRound,
    required this.lastRunUnlockedStageNumber,
    required this.lastRunUnlockedSniperTurret,
    required this.completedRounds,
    required this.startingGoldUpgradeLevel,
    required this.startingGoldUpgradeCost,
    required this.canUpgradeStartingGold,
    required this.nexusHpUpgradeLevel,
    required this.nexusHpUpgradeCost,
    required this.canUpgradeNexusHp,
    required this.supplyUpgradeLevel,
    required this.supplyUpgradeCost,
    required this.canUpgradeSupply,
    required this.waveClearGoldProgressionBonus,
    required this.fireTrainingUpgradeLevel,
    required this.fireTrainingUpgradeCost,
    required this.canUpgradeFireTraining,
    required this.fireTrainingDamageBonusRate,
    required this.criticalChanceUpgradeLevel,
    required this.criticalChanceUpgradeCost,
    required this.canUpgradeCriticalChance,
    required this.criticalChanceProgressionBonusRate,
    required this.criticalDamageUpgradeLevel,
    required this.criticalDamageUpgradeCost,
    required this.canUpgradeCriticalDamage,
    required this.criticalDamageProgressionBonusRate,
    required this.killGoldUpgradeLevel,
    required this.killGoldUpgradeCost,
    required this.canUpgradeKillGold,
    required this.killGoldProgressionBonusRate,
    required this.emergencySaleUpgradeLevel,
    required this.emergencySaleUpgradeCost,
    required this.canUpgradeEmergencySale,
    required this.turretRefundPercent,
    required this.researchSlotCount,
    required this.researchLevels,
    required this.researchElapsedMillis,
    required this.activeResearches,
    required this.startingGemShards,
  });

  final int gold;
  final int gemShards;
  final int nexusHp;
  final int maxNexusHp;
  final int round;
  final int maxRound;
  final GamePhase phase;
  final GamePhase? restoredPhase;
  final bool hasStageProgress;
  final int placedTurretCount;
  final int currentStageNumber;
  final int unlockedStageCount;
  final Map<int, int> bestRoundsByStage;
  final Set<int> clearedStageNumbers;
  final List<TurretType> availableTurretTypes;
  final TurretType selectedTurretType;
  final RunPanelTab selectedRunPanelTab;
  final String previewText;
  final List<GemType> rewardOptions;
  final bool isPurchasedGemReward;
  final Map<GemType, int> gemInventory;
  final Map<GemType, int> gemCollection;
  final GridPoint? selectedBuildPoint;
  final TurretType? selectedBuildTurretType;
  final GridPoint? selectedPortalPoint;
  final GridPoint? selectedTurretPoint;
  final String? selectedTurretName;
  final List<GemType?> selectedTurretGems;
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
  final bool selectedTurretLevelUpPreviewActive;
  final int selectedTurretNextLevel;
  final double selectedTurretNextDamage;
  final double selectedTurretNextRange;
  final double selectedTurretNextAttackRate;
  final double selectedTurretNextBurnDamagePerSecond;
  final double selectedTurretNextBurnDuration;
  final int selectedTurretRefundGold;
  final double selectedTurretDamage;
  final double selectedTurretRange;
  final double selectedTurretAttackRate;
  final double selectedTurretBurnDamagePerSecond;
  final double selectedTurretBurnDuration;
  final double selectedTurretDamageDealt;
  final double selectedTurretDirectDamageDealt;
  final double selectedTurretSplashDamageDealt;
  final double selectedTurretChainDamageDealt;
  final double selectedTurretBurnDamageDealt;
  final bool canSetTurretTargetPriority;
  final TurretTargetPriority selectedTurretTargetPriority;
  final bool selectedTurretSupportsTraits;
  final List<TurretTraitType> selectedTurretPrimaryTraitChoices;
  final List<TurretTraitType> selectedTurretSecondaryTraitChoices;
  final TurretTraitType? selectedTurretPrimaryTrait;
  final TurretTraitType? selectedTurretSecondaryTrait;
  final bool selectedTurretCanChoosePrimaryTrait;
  final bool selectedTurretCanChooseSecondaryTrait;
  final int selectedTurretPrimaryTraitCost;
  final int selectedTurretSecondaryTraitCost;
  final int selectedTurretPrimaryTraitRequiredLevel;
  final int selectedTurretSecondaryTraitRequiredLevel;
  final String? topDamageTurretName;
  final double topDamageTurretDamageDealt;
  final double totalTurretDps;
  final double nexusCoreBeamIntervalSeconds;
  final double nexusCoreBeamCooldownSeconds;
  final bool nexusCoreBeamActive;
  final double nexusCoreBeamDamage;
  final List<EnemyType> nextWaveEnemyTypes;
  final Map<EnemyType, int> nextWaveEnemyCounts;
  final int nextWaveClearRewardGold;
  final int nextWaveKillRewardGold;
  final int nextWaveClearRewardGemShards;
  final AutoStartMode autoStartMode;
  final double speedMultiplier;
  final double killGoldFractionWallet;
  final Map<RunUpgradeType, int> runUpgradeLevels;
  final double towerDamageRunBonusRate;
  final double killGoldRunBonusRate;
  final int waveClearGoldRunBonus;
  final int runes;
  final int lastRunRuneReward;
  final int projectedFailureRuneReward;
  final int lastRunPreviousBestRound;
  final bool lastRunWasNewBestRound;
  final int? lastRunUnlockedStageNumber;
  final bool lastRunUnlockedSniperTurret;
  final int completedRounds;
  final int startingGoldUpgradeLevel;
  final int startingGoldUpgradeCost;
  final bool canUpgradeStartingGold;
  final int nexusHpUpgradeLevel;
  final int nexusHpUpgradeCost;
  final bool canUpgradeNexusHp;
  final int supplyUpgradeLevel;
  final int supplyUpgradeCost;
  final bool canUpgradeSupply;
  final int waveClearGoldProgressionBonus;
  final int fireTrainingUpgradeLevel;
  final int fireTrainingUpgradeCost;
  final bool canUpgradeFireTraining;
  final double fireTrainingDamageBonusRate;
  final int criticalChanceUpgradeLevel;
  final int criticalChanceUpgradeCost;
  final bool canUpgradeCriticalChance;
  final double criticalChanceProgressionBonusRate;
  final int criticalDamageUpgradeLevel;
  final int criticalDamageUpgradeCost;
  final bool canUpgradeCriticalDamage;
  final double criticalDamageProgressionBonusRate;
  final int killGoldUpgradeLevel;
  final int killGoldUpgradeCost;
  final bool canUpgradeKillGold;
  final double killGoldProgressionBonusRate;
  final int emergencySaleUpgradeLevel;
  final int emergencySaleUpgradeCost;
  final bool canUpgradeEmergencySale;
  final int turretRefundPercent;
  final int researchSlotCount;
  final Map<ResearchType, int> researchLevels;
  final Map<ResearchType, int> researchElapsedMillis;
  final List<ResearchProgress> activeResearches;
  final int startingGemShards;
}
