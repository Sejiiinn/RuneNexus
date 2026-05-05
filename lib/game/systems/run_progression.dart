import 'dart:math' as math;

import '../../data/save/game_save_data.dart';

class RunProgression {
  static const int baseInitialGold = 150;
  static const int baseNexusHp = 20;
  static const int maxStageCount = 5;
  static const int maxProgressionLevel = 20;
  static const int startingGoldUpgradeBaseCost = 8;
  static const int startingGoldPerUpgradeLevel = 5;
  static const int nexusHpUpgradeBaseCost = 6;

  int runes = 0;
  int lastRunRuneReward = 0;
  int startingGoldUpgradeLevel = 0;
  int nexusHpUpgradeLevel = 0;
  int unlockedStageCount = 1;
  final Map<int, int> bestRoundsByStage = {};
  final Set<int> clearedStageNumbers = {};

  int get initialGold =>
      baseInitialGold + startingGoldUpgradeLevel * startingGoldPerUpgradeLevel;
  int get maxNexusHp => baseNexusHp + nexusHpUpgradeLevel;
  int get startingGoldUpgradeCost =>
      startingGoldUpgradeBaseCost + startingGoldUpgradeLevel * 5;
  int get nexusHpUpgradeCost =>
      nexusHpUpgradeBaseCost + nexusHpUpgradeLevel * 4;
  bool get canUpgradeStartingGold =>
      startingGoldUpgradeLevel < maxProgressionLevel &&
      runes >= startingGoldUpgradeCost;
  bool get canUpgradeNexusHp =>
      nexusHpUpgradeLevel < maxProgressionLevel && runes >= nexusHpUpgradeCost;

  SavedProgression toSaveData() {
    return SavedProgression(
      runes: runes,
      lastRunRuneReward: lastRunRuneReward,
      startingGoldUpgradeLevel: startingGoldUpgradeLevel,
      nexusHpUpgradeLevel: nexusHpUpgradeLevel,
      unlockedStageCount: unlockedStageCount,
      bestRoundsByStage: Map.unmodifiable(bestRoundsByStage),
      clearedStageNumbers: Set.unmodifiable(clearedStageNumbers),
    );
  }

  void restoreFromSaveData(SavedProgression data) {
    runes = math.max(0, data.runes);
    lastRunRuneReward = math.max(0, data.lastRunRuneReward);
    startingGoldUpgradeLevel = data.startingGoldUpgradeLevel
        .clamp(0, maxProgressionLevel)
        .toInt();
    nexusHpUpgradeLevel = data.nexusHpUpgradeLevel
        .clamp(0, maxProgressionLevel)
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

  void finishRun({
    required int completedRounds,
    required bool success,
    required int stageNumber,
  }) {
    lastRunRuneReward = runeRewardFor(completedRounds, success: success);
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

  int runeRewardFor(int completedRounds, {required bool success}) {
    return math.max(1, completedRounds * 2 + (success ? 40 : 0));
  }

  void resetLastRunReward() {
    lastRunRuneReward = 0;
  }
}
