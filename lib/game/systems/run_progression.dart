import 'dart:math' as math;

import '../../data/definitions/demo_research_data.dart';
import '../../data/save/game_save_data.dart';
import '../../domain/research/research_progress.dart';
import '../../domain/research/research_type.dart';

class RunProgression {
  static const int baseInitialGold = 150;
  static const int baseNexusHp = 20;
  static const int maxStageCount = 5;
  static const int maxStartingGoldUpgradeLevel = 20;
  static const int maxNexusHpUpgradeLevel = 10;
  static const int maxSupplyUpgradeLevel = 10;
  static const int maxFireTrainingUpgradeLevel = 20;
  static const int maxKillGoldUpgradeLevel = 10;
  static const int maxEmergencySaleUpgradeLevel = 5;
  static const int researchSlotCount = 1;
  static const int gemShardsPerGemAttunementLevel = 2;
  static const double researchEfficiencyPerLevel = 0.05;
  static const double researchCostEfficiencyPerLevel = 0.05;
  static const int baseTurretRefundPercent = 75;
  static const int startingGoldUpgradeBaseCost = 4;
  static const int startingGoldUpgradeCostPerLevel = 4;
  static const int startingGoldPerUpgradeLevel = 5;
  static const int nexusHpUpgradeBaseCost = 14;
  static const int nexusHpUpgradeCostPerLevel = 7;
  static const int supplyUpgradeBaseCost = 7;
  static const int supplyUpgradeCostPerLevel = 4;
  static const int supplyGoldPerUpgradeLevel = 1;
  static const int fireTrainingUpgradeBaseCost = 7;
  static const int fireTrainingUpgradeCostPerLevel = 4;
  static const double fireTrainingDamagePerUpgradeLevel = 0.01;
  static const int killGoldUpgradeBaseCost = 7;
  static const int killGoldUpgradeCostPerLevel = 4;
  static const double killGoldBonusPerUpgradeLevel = 0.01;
  static const int emergencySaleUpgradeBaseCost = 80;
  static const int emergencySaleRefundPercentPerLevel = 1;
  static const List<int> emergencySaleUpgradeCosts = [80, 120, 180, 260, 360];
  static const List<double> _stageRuneRewardBonusRates = [
    0,
    0.20,
    0.45,
    0.75,
    1.10,
  ];

  int runes = 0;
  int lastRunRuneReward = 0;
  int startingGoldUpgradeLevel = 0;
  int nexusHpUpgradeLevel = 0;
  int supplyUpgradeLevel = 0;
  int fireTrainingUpgradeLevel = 0;
  int killGoldUpgradeLevel = 0;
  int emergencySaleUpgradeLevel = 0;
  int unlockedStageCount = 1;
  final Map<int, int> bestRoundsByStage = {};
  final Set<int> clearedStageNumbers = {};
  final Map<ResearchType, int> researchLevels = {};
  final List<ResearchProgress> activeResearches = [];

  int get initialGold =>
      baseInitialGold +
      _cappedStartingGoldUpgradeLevel * startingGoldPerUpgradeLevel;
  int get maxNexusHp => baseNexusHp + _cappedNexusHpUpgradeLevel;
  int get startingGoldUpgradeCost =>
      startingGoldUpgradeBaseCost +
      _cappedStartingGoldUpgradeLevel * startingGoldUpgradeCostPerLevel;
  int get nexusHpUpgradeCost =>
      nexusHpUpgradeBaseCost +
      _cappedNexusHpUpgradeLevel * nexusHpUpgradeCostPerLevel;
  int get supplyUpgradeCost =>
      supplyUpgradeBaseCost +
      _cappedSupplyUpgradeLevel * supplyUpgradeCostPerLevel;
  int get fireTrainingUpgradeCost =>
      fireTrainingUpgradeBaseCost +
      _cappedFireTrainingUpgradeLevel * fireTrainingUpgradeCostPerLevel;
  int get killGoldUpgradeCost =>
      killGoldUpgradeBaseCost +
      _cappedKillGoldUpgradeLevel * killGoldUpgradeCostPerLevel;
  int get emergencySaleUpgradeCost =>
      emergencySaleUpgradeCosts[math.min(
        _cappedEmergencySaleUpgradeLevel,
        emergencySaleUpgradeCosts.length - 1,
      )];
  int get waveClearGoldBonus =>
      _cappedSupplyUpgradeLevel * supplyGoldPerUpgradeLevel;
  double get fireTrainingDamageBonusRate =>
      _cappedFireTrainingUpgradeLevel * fireTrainingDamagePerUpgradeLevel;
  double get killGoldBonusRate =>
      _cappedKillGoldUpgradeLevel * killGoldBonusPerUpgradeLevel;
  int get turretRefundPercent =>
      baseTurretRefundPercent +
      _cappedEmergencySaleUpgradeLevel * emergencySaleRefundPercentPerLevel;
  int get startingGemShards =>
      researchLevel(ResearchType.gemAttunement) *
      gemShardsPerGemAttunementLevel;
  int get maxTurretLinkSlots =>
      isResearchComplete(ResearchType.linkExpansionOne) ? 2 : 1;
  double get researchEfficiencyRate =>
      researchLevel(ResearchType.researchEfficiency) *
      researchEfficiencyPerLevel;
  double get researchCostEfficiencyRate =>
      researchLevel(ResearchType.researchCostEfficiency) *
      researchCostEfficiencyPerLevel;
  bool get canUpgradeStartingGold =>
      _cappedStartingGoldUpgradeLevel < maxStartingGoldUpgradeLevel &&
      runes >= startingGoldUpgradeCost;
  bool get canUpgradeNexusHp =>
      _cappedNexusHpUpgradeLevel < maxNexusHpUpgradeLevel &&
      runes >= nexusHpUpgradeCost;
  bool get canUpgradeSupply =>
      _cappedSupplyUpgradeLevel < maxSupplyUpgradeLevel &&
      runes >= supplyUpgradeCost;
  bool get canUpgradeFireTraining =>
      _cappedFireTrainingUpgradeLevel < maxFireTrainingUpgradeLevel &&
      runes >= fireTrainingUpgradeCost;
  bool get canUpgradeKillGold =>
      _cappedKillGoldUpgradeLevel < maxKillGoldUpgradeLevel &&
      runes >= killGoldUpgradeCost;
  bool get canUpgradeEmergencySale =>
      _cappedEmergencySaleUpgradeLevel < maxEmergencySaleUpgradeLevel &&
      runes >= emergencySaleUpgradeCost;

  int get _cappedStartingGoldUpgradeLevel =>
      startingGoldUpgradeLevel.clamp(0, maxStartingGoldUpgradeLevel).toInt();
  int get _cappedNexusHpUpgradeLevel =>
      nexusHpUpgradeLevel.clamp(0, maxNexusHpUpgradeLevel).toInt();
  int get _cappedSupplyUpgradeLevel =>
      supplyUpgradeLevel.clamp(0, maxSupplyUpgradeLevel).toInt();
  int get _cappedFireTrainingUpgradeLevel =>
      fireTrainingUpgradeLevel.clamp(0, maxFireTrainingUpgradeLevel).toInt();
  int get _cappedKillGoldUpgradeLevel =>
      killGoldUpgradeLevel.clamp(0, maxKillGoldUpgradeLevel).toInt();
  int get _cappedEmergencySaleUpgradeLevel =>
      emergencySaleUpgradeLevel.clamp(0, maxEmergencySaleUpgradeLevel).toInt();

  static double stageRuneRewardBonusRateFor(int stageNumber) {
    final index = stageNumber.clamp(1, maxStageCount).toInt() - 1;
    return _stageRuneRewardBonusRates[index];
  }

  static int applyResearchEfficiency(
    int durationMillis,
    double efficiencyRate,
  ) {
    return math.max(1, (durationMillis / (1 + efficiencyRate)).round());
  }

  static int applyResearchCostEfficiency(int cost, double efficiencyRate) {
    return math.max(1, (cost / (1 + efficiencyRate)).round());
  }

  int researchLevel(ResearchType type) {
    final definition = demoResearchDefinitions[type];
    final maxLevel = definition?.maxLevel ?? 0;
    return (researchLevels[type] ?? 0).clamp(0, maxLevel).toInt();
  }

  bool isResearchActive(ResearchType type) {
    return activeResearches.any((research) => research.type == type);
  }

  bool isResearchComplete(ResearchType type) {
    final definition = demoResearchDefinitions[type];
    if (definition == null) {
      return false;
    }
    return researchLevel(type) >= definition.maxLevel;
  }

  bool isResearchUnlocked(ResearchType type) {
    final definition = demoResearchDefinitions[type];
    if (definition == null) {
      return false;
    }
    if (definition.requiredClearedStage <= 0) {
      return true;
    }
    return isStageCleared(definition.requiredClearedStage);
  }

  int researchCostForCurrentLevel(ResearchType type) {
    final definition = demoResearchDefinitions[type];
    if (definition == null) {
      return 0;
    }
    final baseCost = definition.costForCurrentLevel(researchLevel(type));
    return applyResearchCostEfficiency(baseCost, researchCostEfficiencyRate);
  }

  int researchDurationForCurrentLevel(ResearchType type) {
    final definition = demoResearchDefinitions[type];
    if (definition == null) {
      return 0;
    }
    final baseDuration = definition.durationForCurrentLevel(
      researchLevel(type),
    );
    return applyResearchEfficiency(baseDuration, researchEfficiencyRate);
  }

  bool canStartResearch(ResearchType type) {
    final definition = demoResearchDefinitions[type];
    if (definition == null ||
        !isResearchUnlocked(type) ||
        isResearchComplete(type) ||
        isResearchActive(type) ||
        activeResearches.length >= researchSlotCount) {
      return false;
    }
    return runes >= researchCostForCurrentLevel(type);
  }

  bool startResearch(ResearchType type, {required int nowMillis}) {
    final definition = demoResearchDefinitions[type];
    if (definition == null || !canStartResearch(type)) {
      return false;
    }

    final currentLevel = researchLevel(type);
    runes -= researchCostForCurrentLevel(type);
    activeResearches.add(
      ResearchProgress(
        type: type,
        targetLevel: currentLevel + 1,
        startedAtMillis: nowMillis,
        durationMillis: researchDurationForCurrentLevel(type),
      ),
    );
    return true;
  }

  bool completeFinishedResearches({required int nowMillis}) {
    var changed = false;
    for (final research in activeResearches.toList()) {
      if (!research.isCompleteAt(nowMillis)) {
        continue;
      }
      final definition = demoResearchDefinitions[research.type];
      if (definition == null) {
        activeResearches.remove(research);
        changed = true;
        continue;
      }
      researchLevels[research.type] = research.targetLevel
          .clamp(0, definition.maxLevel)
          .toInt();
      activeResearches.remove(research);
      changed = true;
    }
    return changed;
  }

  SavedProgression toSaveData() {
    return SavedProgression(
      runes: runes,
      lastRunRuneReward: lastRunRuneReward,
      startingGoldUpgradeLevel: _cappedStartingGoldUpgradeLevel,
      nexusHpUpgradeLevel: _cappedNexusHpUpgradeLevel,
      supplyUpgradeLevel: _cappedSupplyUpgradeLevel,
      fireTrainingUpgradeLevel: _cappedFireTrainingUpgradeLevel,
      killGoldUpgradeLevel: _cappedKillGoldUpgradeLevel,
      emergencySaleUpgradeLevel: _cappedEmergencySaleUpgradeLevel,
      unlockedStageCount: unlockedStageCount,
      bestRoundsByStage: Map.unmodifiable(bestRoundsByStage),
      clearedStageNumbers: Set.unmodifiable(clearedStageNumbers),
      researchLevels: Map.unmodifiable(
        researchLevels.map((key, value) => MapEntry(key, researchLevel(key))),
      ),
      activeResearches: List.unmodifiable(
        activeResearches.map(
          (research) => SavedActiveResearch(
            type: research.type,
            targetLevel: research.targetLevel,
            startedAtMillis: research.startedAtMillis,
            durationMillis: research.durationMillis,
          ),
        ),
      ),
    );
  }

  void restoreFromSaveData(SavedProgression data) {
    runes = math.max(0, data.runes);
    lastRunRuneReward = math.max(0, data.lastRunRuneReward);
    startingGoldUpgradeLevel = data.startingGoldUpgradeLevel
        .clamp(0, maxStartingGoldUpgradeLevel)
        .toInt();
    nexusHpUpgradeLevel = data.nexusHpUpgradeLevel
        .clamp(0, maxNexusHpUpgradeLevel)
        .toInt();
    supplyUpgradeLevel = data.supplyUpgradeLevel
        .clamp(0, maxSupplyUpgradeLevel)
        .toInt();
    fireTrainingUpgradeLevel = data.fireTrainingUpgradeLevel
        .clamp(0, maxFireTrainingUpgradeLevel)
        .toInt();
    killGoldUpgradeLevel = data.killGoldUpgradeLevel
        .clamp(0, maxKillGoldUpgradeLevel)
        .toInt();
    emergencySaleUpgradeLevel = data.emergencySaleUpgradeLevel
        .clamp(0, maxEmergencySaleUpgradeLevel)
        .toInt();
    unlockedStageCount = data.unlockedStageCount
        .clamp(1, maxStageCount)
        .toInt();
    bestRoundsByStage
      ..clear()
      ..addEntries(
        data.bestRoundsByStage.entries
            .where((entry) => entry.key > 0 && entry.value > 0)
            .map((entry) => MapEntry(entry.key, entry.value)),
      );
    clearedStageNumbers
      ..clear()
      ..addAll(data.clearedStageNumbers.where((stage) => stage > 0));
    researchLevels
      ..clear()
      ..addEntries(
        data.researchLevels.entries
            .where((entry) {
              final definition = demoResearchDefinitions[entry.key];
              return definition != null && entry.value > 0;
            })
            .map((entry) {
              final definition = demoResearchDefinitions[entry.key]!;
              return MapEntry(
                entry.key,
                entry.value.clamp(0, definition.maxLevel).toInt(),
              );
            }),
      );
    activeResearches
      ..clear()
      ..addAll(
        data.activeResearches
            .where((research) {
              final definition = demoResearchDefinitions[research.type];
              return definition != null &&
                  research.durationMillis > 0 &&
                  research.targetLevel > researchLevel(research.type) &&
                  research.targetLevel <= definition.maxLevel;
            })
            .map(
              (research) => ResearchProgress(
                type: research.type,
                targetLevel: research.targetLevel,
                startedAtMillis: research.startedAtMillis,
                durationMillis: research.durationMillis,
              ),
            ),
      );
  }

  bool upgradeStartingGold() {
    if (!canUpgradeStartingGold) {
      return false;
    }

    runes -= startingGoldUpgradeCost;
    startingGoldUpgradeLevel++;
    return true;
  }

  bool upgradeNexusHp() {
    if (!canUpgradeNexusHp) {
      return false;
    }

    runes -= nexusHpUpgradeCost;
    nexusHpUpgradeLevel++;
    return true;
  }

  bool upgradeSupply() {
    if (!canUpgradeSupply) {
      return false;
    }

    runes -= supplyUpgradeCost;
    supplyUpgradeLevel++;
    return true;
  }

  bool upgradeFireTraining() {
    if (!canUpgradeFireTraining) {
      return false;
    }

    runes -= fireTrainingUpgradeCost;
    fireTrainingUpgradeLevel++;
    return true;
  }

  bool upgradeKillGold() {
    if (!canUpgradeKillGold) {
      return false;
    }

    runes -= killGoldUpgradeCost;
    killGoldUpgradeLevel++;
    return true;
  }

  bool upgradeEmergencySale() {
    if (!canUpgradeEmergencySale) {
      return false;
    }

    runes -= emergencySaleUpgradeCost;
    emergencySaleUpgradeLevel++;
    return true;
  }

  void finishRun({
    required int completedRounds,
    required bool success,
    required int stageNumber,
  }) {
    lastRunRuneReward = runeRewardFor(
      completedRounds,
      success: success,
      stageNumber: stageNumber,
    );
    runes += lastRunRuneReward;
    _recordStageProgress(
      stageNumber: stageNumber,
      completedRounds: completedRounds,
      success: success,
    );
    if (success &&
        stageNumber >= unlockedStageCount &&
        unlockedStageCount < maxStageCount) {
      unlockedStageCount = math.min(maxStageCount, stageNumber + 1);
    }
  }

  int bestRoundForStage(int stageNumber) {
    return bestRoundsByStage[stageNumber] ?? 0;
  }

  bool isStageCleared(int stageNumber) {
    return clearedStageNumbers.contains(stageNumber);
  }

  void _recordStageProgress({
    required int stageNumber,
    required int completedRounds,
    required bool success,
  }) {
    if (stageNumber <= 0) {
      return;
    }
    if (completedRounds > 0) {
      final previousBest = bestRoundsByStage[stageNumber] ?? 0;
      bestRoundsByStage[stageNumber] = math.max(previousBest, completedRounds);
    }
    if (success) {
      clearedStageNumbers.add(stageNumber);
    }
  }

  int runeRewardFor(
    int completedRounds, {
    required bool success,
    int stageNumber = 1,
  }) {
    final baseReward = math.max(1, completedRounds * 2 + (success ? 40 : 0));
    final bonusRate = stageRuneRewardBonusRateFor(stageNumber);
    return math.max(1, (baseReward * (1 + bonusRate)).round());
  }

  void resetLastRunReward() {
    lastRunRuneReward = 0;
  }
}
