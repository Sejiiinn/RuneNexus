import 'dart:math' as math;

import '../../data/save/game_save_data.dart';

class RunProgression {
  static const int baseInitialGold = 150;
  static const int baseNexusHp = 20;
  static const int maxProgressionLevel = 20;
  static const int startingGoldUpgradeBaseCost = 8;
  static const int nexusHpUpgradeBaseCost = 6;

  int runes = 0;
  int lastRunRuneReward = 0;
  int startingGoldUpgradeLevel = 0;
  int nexusHpUpgradeLevel = 0;

  int get initialGold => baseInitialGold + startingGoldUpgradeLevel * 10;
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

  void finishRun({required int completedRounds, required bool success}) {
    lastRunRuneReward = runeRewardFor(completedRounds, success: success);
    runes += lastRunRuneReward;
  }

  int runeRewardFor(int completedRounds, {required bool success}) {
    return math.max(1, completedRounds * 2 + (success ? 40 : 0));
  }

  void resetLastRunReward() {
    lastRunRuneReward = 0;
  }
}
