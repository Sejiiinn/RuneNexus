part of '../run_progression.dart';

mixin _ResearchProgression {
  abstract int runes;

  bool isStageCleared(int stageNumber);
  bool canSpendDiamonds(int amount);
  DiamondSpendResult? spendDiamonds(int amount);

  final Map<ResearchType, int> researchLevels = {};
  final Map<ResearchType, int> researchElapsedMillis = {};
  final List<ResearchProgress> activeResearches = [];
  bool researchSlotTwoUnlocked = false;

  int get startingGemShards =>
      researchLevel(ResearchType.gemAttunement) *
      RunProgression.gemShardsPerGemAttunementLevel;
  int get maxTurretLinkSlots =>
      isResearchComplete(ResearchType.linkExpansionOne) ? 4 : 3;
  bool get canSetTurretTargetPriority =>
      isResearchComplete(ResearchType.turretTargetPriority);
  int get availableResearchSlotCount => researchSlotTwoUnlocked ? 2 : 1;
  bool get researchSlotTwoPurchaseUnlocked =>
      isStageCleared(RunProgression.researchSlotTwoUnlockRequiredStage);
  bool get canUnlockResearchSlotTwo =>
      researchSlotTwoPurchaseUnlocked &&
      !researchSlotTwoUnlocked &&
      canSpendDiamonds(RunProgression.researchSlotTwoUnlockCost);

  double get researchEfficiencyRate =>
      researchLevel(ResearchType.researchEfficiency) *
      RunProgression.researchEfficiencyPerLevel;
  double get researchCostEfficiencyRate =>
      researchLevel(ResearchType.researchCostEfficiency) *
      RunProgression.researchCostEfficiencyPerLevel;
  double get bossBountyBonusRate =>
      researchLevel(ResearchType.bossBounty) *
      RunProgression.bossBountyBonusPerLevel;
  double get firstLinkUpgradeDiscountRate =>
      researchLevel(ResearchType.linkMaintenance) *
      RunProgression.linkMaintenanceDiscountPerLevel;
  int get bossKillGemShardBonus =>
      researchLevel(ResearchType.crystalRecovery) *
      RunProgression.bossGemShardsPerCrystalRecoveryLevel;
  double get runeResonanceBonusRate =>
      researchLevel(ResearchType.runeResonance) *
      RunProgression.runeResonanceBonusPerLevel;
  double get runUpgradeCostMultiplier =>
      1 -
      researchLevel(ResearchType.runUpgradeCostOptimization) *
          RunProgression.runUpgradeCostDiscountPerLevel;

  int runUpgradeMaxLevelBonusFor(RunUpgradeType type) {
    final researchType = switch (type) {
      RunUpgradeType.towerDamage => ResearchType.towerDamageLimitExpansion,
      RunUpgradeType.killGold => ResearchType.killGoldLimitExpansion,
      RunUpgradeType.waveGold => ResearchType.waveGoldLimitExpansion,
    };
    return researchLevel(researchType) *
        RunProgression.runUpgradeLimitExpansionMaxLevelPerLevel;
  }

  int researchLevel(ResearchType type) {
    final definition = gameResearchDefinitions[type];
    final maxLevel = definition?.maxLevel ?? 0;
    return (researchLevels[type] ?? 0).clamp(0, maxLevel).toInt();
  }

  bool isResearchActive(ResearchType type) {
    return activeResearches.any((research) => research.type == type);
  }

  bool isResearchComplete(ResearchType type) {
    final definition = gameResearchDefinitions[type];
    if (definition == null) {
      return false;
    }
    return researchLevel(type) >= definition.maxLevel;
  }

  bool isResearchUnlocked(ResearchType type) {
    final definition = gameResearchDefinitions[type];
    if (definition == null) {
      return false;
    }
    if (definition.requiredClearedStage <= 0) {
      return true;
    }
    return isStageCleared(definition.requiredClearedStage);
  }

  int researchCostForCurrentLevel(ResearchType type) {
    final definition = gameResearchDefinitions[type];
    if (definition == null) {
      return 0;
    }
    final baseCost = definition.costForCurrentLevel(researchLevel(type));
    return RunProgression.applyResearchCostEfficiency(
      baseCost,
      researchCostEfficiencyRate,
    );
  }

  int researchDurationForCurrentLevel(ResearchType type) {
    final definition = gameResearchDefinitions[type];
    if (definition == null) {
      return 0;
    }
    final baseDuration = definition.durationForCurrentLevel(
      researchLevel(type),
    );
    return RunProgression.applyResearchEfficiency(
      baseDuration,
      researchEfficiencyRate,
    );
  }

  int researchRemainingDurationForCurrentLevel(ResearchType type) {
    final duration = researchDurationForCurrentLevel(type);
    if (duration <= 0) {
      return 0;
    }
    final elapsed = (researchElapsedMillis[type] ?? 0)
        .clamp(0, duration - 1)
        .toInt();
    return duration - elapsed;
  }

  bool canStartResearch(ResearchType type) {
    final definition = gameResearchDefinitions[type];
    if (definition == null ||
        !isResearchUnlocked(type) ||
        isResearchComplete(type) ||
        isResearchActive(type) ||
        activeResearches.length >= availableResearchSlotCount) {
      return false;
    }
    return runes >= researchCostForCurrentLevel(type);
  }

  bool startResearch(ResearchType type, {required int nowMillis}) {
    final definition = gameResearchDefinitions[type];
    if (definition == null || !canStartResearch(type)) {
      return false;
    }

    final currentLevel = researchLevel(type);
    final elapsed = researchElapsedMillis[type] ?? 0;
    runes -= researchCostForCurrentLevel(type);
    activeResearches.add(
      ResearchProgress(
        type: type,
        targetLevel: currentLevel + 1,
        startedAtMillis: nowMillis,
        durationMillis: researchRemainingDurationForCurrentLevel(type),
        initialElapsedMillis: elapsed,
      ),
    );
    return true;
  }

  bool cancelResearch(ResearchType type, {required int nowMillis}) {
    final activeIndex = activeResearches.indexWhere(
      (research) => research.type == type,
    );
    if (activeIndex < 0) {
      return false;
    }
    final active = activeResearches[activeIndex];
    if (active.isCompleteAt(nowMillis)) {
      return completeFinishedResearches(nowMillis: nowMillis);
    }
    activeResearches.removeAt(activeIndex);
    runes += researchCostForCurrentLevel(type);
    final fullDuration = researchDurationForCurrentLevel(type);
    if (fullDuration <= 0) {
      researchElapsedMillis.remove(type);
      return true;
    }

    final previousElapsed = active.initialElapsedMillis;
    final elapsedThisRun =
        active.durationMillis - active.remainingMillisAt(nowMillis);
    final elapsed = (previousElapsed + elapsedThisRun)
        .clamp(0, fullDuration - 1)
        .toInt();
    if (elapsed > 0) {
      researchElapsedMillis[type] = elapsed;
    } else {
      researchElapsedMillis.remove(type);
    }
    return true;
  }

  bool completeResearchWithDiamonds(
    ResearchType type, {
    required int nowMillis,
  }) {
    final activeIndex = activeResearches.indexWhere(
      (research) => research.type == type,
    );
    if (activeIndex < 0) {
      return false;
    }
    final active = activeResearches[activeIndex];
    final definition = gameResearchDefinitions[type];
    if (definition == null) {
      return false;
    }
    final cost = RunProgression.researchInstantCompleteCostFor(
      active,
      nowMillis: nowMillis,
    );
    if (spendDiamonds(cost) == null) {
      return false;
    }
    researchLevels[type] = active.targetLevel
        .clamp(0, definition.maxLevel)
        .toInt();
    activeResearches.removeAt(activeIndex);
    researchElapsedMillis.remove(type);
    return true;
  }

  bool applyResearchCompletionEffect(ResearchType type, int targetLevel) {
    final definition = gameResearchDefinitions[type];
    if (definition == null || targetLevel <= 0) {
      return false;
    }
    final resolvedLevel = targetLevel.clamp(0, definition.maxLevel).toInt();
    final changed = (researchLevels[type] ?? 0) < resolvedLevel;
    researchLevels[type] = math.max(researchLevels[type] ?? 0, resolvedLevel);
    activeResearches.removeWhere(
      (research) =>
          research.type == type && research.targetLevel <= resolvedLevel,
    );
    researchElapsedMillis.remove(type);
    return changed;
  }

  bool unlockResearchSlotTwo() {
    if (!canUnlockResearchSlotTwo ||
        spendDiamonds(RunProgression.researchSlotTwoUnlockCost) == null) {
      return false;
    }
    researchSlotTwoUnlocked = true;
    return true;
  }

  bool completeFinishedResearches({required int nowMillis}) {
    var changed = false;
    for (final research in activeResearches.toList()) {
      if (!research.isCompleteAt(nowMillis)) {
        continue;
      }
      final definition = gameResearchDefinitions[research.type];
      if (definition == null) {
        activeResearches.remove(research);
        changed = true;
        continue;
      }
      researchLevels[research.type] = research.targetLevel
          .clamp(0, definition.maxLevel)
          .toInt();
      activeResearches.remove(research);
      researchElapsedMillis.remove(research.type);
      changed = true;
    }
    return changed;
  }
}
