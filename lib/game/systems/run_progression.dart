import 'dart:math' as math;

import '../../data/definitions/game_research_data.dart';
import '../../data/save/game_save_data.dart';
import '../../domain/core/core_ability.dart';
import '../../domain/research/research_progress.dart';
import '../../domain/research/research_type.dart';

class RunProgression {
  static const int baseInitialGold = 170;
  static const int baseNexusHp = 20;
  static const int maxStageCount = 10;
  static const int maxStartingGoldUpgradeLevel = 20;
  static const int maxNexusHpUpgradeLevel = 10;
  static const int maxSupplyUpgradeLevel = 20;
  static const int maxFireTrainingUpgradeLevel = 20;
  static const int maxCriticalChanceUpgradeLevel = 20;
  static const int maxCriticalDamageUpgradeLevel = 20;
  static const int maxKillGoldUpgradeLevel = 20;
  static const int maxEmergencySaleUpgradeLevel = 5;
  static const int researchSlotCount = 1;
  static const int gemShardsPerGemAttunementLevel = 2;
  static const int corePassiveSlotUnlockCost = 500;
  static const double researchEfficiencyPerLevel = 0.05;
  static const double researchCostEfficiencyPerLevel = 0.05;
  static const double bossBountyBonusPerLevel = 0.025;
  static const int baseStageOneFullClearRuneReward = 200;
  static const double runeRewardGrowthPerRound = 1.04;
  static const int baseTurretRefundPercent = 75;
  static const int startingGoldUpgradeBaseCost = 4;
  static const int startingGoldUpgradeCostPerLevel = 3;
  static const double startingGoldUpgradeCostMultiplier = 1.08;
  static const int startingGoldPerUpgradeLevel = 10;
  static const int nexusHpUpgradeBaseCost = 14;
  static const int nexusHpUpgradeCostPerLevel = 5;
  static const double nexusHpUpgradeCostMultiplier = 1.10;
  static const int supplyUpgradeBaseCost = 7;
  static const int supplyUpgradeCostPerLevel = 2;
  static const double supplyUpgradeCostMultiplier = 1.10;
  static const int supplyGoldPerUpgradeLevel = 1;
  static const int fireTrainingUpgradeBaseCost = 7;
  static const int fireTrainingUpgradeCostPerLevel = 2;
  static const double fireTrainingUpgradeCostMultiplier = 1.10;
  static const double fireTrainingDamagePerUpgradeLevel = 0.015;
  static const int criticalChanceUpgradeBaseCost = 70;
  static const double criticalChanceUpgradeCostMultiplier = 1.2;
  static const double criticalChanceBonusPerUpgradeLevel = 0.01;
  static const int criticalDamageUpgradeBaseCost = 60;
  static const double criticalDamageUpgradeCostMultiplier = 1.1;
  static const double criticalDamageBonusPerUpgradeLevel = 0.01;
  static const int killGoldUpgradeBaseCost = 7;
  static const int killGoldUpgradeCostPerLevel = 2;
  static const double killGoldUpgradeCostMultiplier = 1.10;
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
    1.50,
    1.95,
    2.45,
    3.00,
    3.60,
  ];

  int runes = 0;
  int lastRunRuneReward = 0;
  int startingGoldUpgradeLevel = 0;
  int nexusHpUpgradeLevel = 0;
  int supplyUpgradeLevel = 0;
  int fireTrainingUpgradeLevel = 0;
  int criticalChanceUpgradeLevel = 0;
  int criticalDamageUpgradeLevel = 0;
  int killGoldUpgradeLevel = 0;
  int emergencySaleUpgradeLevel = 0;
  int unlockedStageCount = 1;
  final Map<int, int> bestRoundsByStage = {};
  final Set<int> clearedStageNumbers = {};
  final Map<ResearchType, int> researchLevels = {};
  final Map<ResearchType, int> researchElapsedMillis = {};
  final List<ResearchProgress> activeResearches = [];
  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam;
  bool corePassiveSlotTwoUnlocked = false;
  final List<CorePassiveAbility?> corePassiveSlots = [null, null];

  int get initialGold =>
      baseInitialGold +
      _cappedStartingGoldUpgradeLevel * startingGoldPerUpgradeLevel;
  int get maxNexusHp => baseNexusHp + _cappedNexusHpUpgradeLevel;
  int get startingGoldUpgradeCost => _hybridUpgradeCost(
    baseCost: startingGoldUpgradeBaseCost,
    costPerLevel: startingGoldUpgradeCostPerLevel,
    multiplier: startingGoldUpgradeCostMultiplier,
    level: _cappedStartingGoldUpgradeLevel,
  );
  int get nexusHpUpgradeCost => _hybridUpgradeCost(
    baseCost: nexusHpUpgradeBaseCost,
    costPerLevel: nexusHpUpgradeCostPerLevel,
    multiplier: nexusHpUpgradeCostMultiplier,
    level: _cappedNexusHpUpgradeLevel,
  );
  int get supplyUpgradeCost => _hybridUpgradeCost(
    baseCost: supplyUpgradeBaseCost,
    costPerLevel: supplyUpgradeCostPerLevel,
    multiplier: supplyUpgradeCostMultiplier,
    level: _cappedSupplyUpgradeLevel,
  );
  int get fireTrainingUpgradeCost => _hybridUpgradeCost(
    baseCost: fireTrainingUpgradeBaseCost,
    costPerLevel: fireTrainingUpgradeCostPerLevel,
    multiplier: fireTrainingUpgradeCostMultiplier,
    level: _cappedFireTrainingUpgradeLevel,
  );
  int get criticalChanceUpgradeCost =>
      (criticalChanceUpgradeBaseCost *
              math.pow(
                criticalChanceUpgradeCostMultiplier,
                _cappedCriticalChanceUpgradeLevel,
              ))
          .round();
  int get criticalDamageUpgradeCost =>
      (criticalDamageUpgradeBaseCost *
              math.pow(
                criticalDamageUpgradeCostMultiplier,
                _cappedCriticalDamageUpgradeLevel,
              ))
          .round();
  int get killGoldUpgradeCost => _hybridUpgradeCost(
    baseCost: killGoldUpgradeBaseCost,
    costPerLevel: killGoldUpgradeCostPerLevel,
    multiplier: killGoldUpgradeCostMultiplier,
    level: _cappedKillGoldUpgradeLevel,
  );
  int get emergencySaleUpgradeCost =>
      emergencySaleUpgradeCosts[math.min(
        _cappedEmergencySaleUpgradeLevel,
        emergencySaleUpgradeCosts.length - 1,
      )];
  int get waveClearGoldBonus =>
      _cappedSupplyUpgradeLevel * supplyGoldPerUpgradeLevel;
  double get fireTrainingDamageBonusRate =>
      _cappedFireTrainingUpgradeLevel * fireTrainingDamagePerUpgradeLevel;
  double get criticalChanceBonusRate =>
      _cappedCriticalChanceUpgradeLevel * criticalChanceBonusPerUpgradeLevel;
  double get criticalDamageBonusRate =>
      _cappedCriticalDamageUpgradeLevel * criticalDamageBonusPerUpgradeLevel;
  double get killGoldBonusRate =>
      _cappedKillGoldUpgradeLevel * killGoldBonusPerUpgradeLevel;
  int get turretRefundPercent =>
      baseTurretRefundPercent +
      _cappedEmergencySaleUpgradeLevel * emergencySaleRefundPercentPerLevel;
  int get startingGemShards =>
      researchLevel(ResearchType.gemAttunement) *
      gemShardsPerGemAttunementLevel;
  int get maxTurretLinkSlots =>
      isResearchComplete(ResearchType.linkExpansionOne) ? 4 : 3;
  bool get canSetTurretTargetPriority =>
      isResearchComplete(ResearchType.turretTargetPriority);
  int get corePassiveSlotCount => corePassiveSlotTwoUnlocked ? 2 : 1;
  bool get canUnlockCorePassiveSlot =>
      !corePassiveSlotTwoUnlocked && runes >= corePassiveSlotUnlockCost;
  Set<CorePassiveAbility> get unlockedCorePassiveAbilities {
    return {
      CorePassiveAbility.selfRepair,
      if (isStageCleared(1)) CorePassiveAbility.costSavingDesign,
    };
  }

  double get researchEfficiencyRate =>
      researchLevel(ResearchType.researchEfficiency) *
      researchEfficiencyPerLevel;
  double get researchCostEfficiencyRate =>
      researchLevel(ResearchType.researchCostEfficiency) *
      researchCostEfficiencyPerLevel;
  double get bossBountyBonusRate =>
      researchLevel(ResearchType.bossBounty) * bossBountyBonusPerLevel;
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
  bool get canUpgradeCriticalChance =>
      _cappedCriticalChanceUpgradeLevel < maxCriticalChanceUpgradeLevel &&
      runes >= criticalChanceUpgradeCost;
  bool get canUpgradeCriticalDamage =>
      _cappedCriticalDamageUpgradeLevel < maxCriticalDamageUpgradeLevel &&
      runes >= criticalDamageUpgradeCost;
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
  int get _cappedCriticalChanceUpgradeLevel => criticalChanceUpgradeLevel
      .clamp(0, maxCriticalChanceUpgradeLevel)
      .toInt();
  int get _cappedCriticalDamageUpgradeLevel => criticalDamageUpgradeLevel
      .clamp(0, maxCriticalDamageUpgradeLevel)
      .toInt();
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

  static int _hybridUpgradeCost({
    required int baseCost,
    required int costPerLevel,
    required double multiplier,
    required int level,
  }) {
    final linearCost = baseCost + costPerLevel * level;
    return math.max(1, (linearCost * math.pow(multiplier, level)).round());
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
    return applyResearchCostEfficiency(baseCost, researchCostEfficiencyRate);
  }

  int researchDurationForCurrentLevel(ResearchType type) {
    final definition = gameResearchDefinitions[type];
    if (definition == null) {
      return 0;
    }
    final baseDuration = definition.durationForCurrentLevel(
      researchLevel(type),
    );
    return applyResearchEfficiency(baseDuration, researchEfficiencyRate);
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
        activeResearches.length >= researchSlotCount) {
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

  SavedProgression toSaveData() {
    return SavedProgression(
      runes: runes,
      lastRunRuneReward: lastRunRuneReward,
      startingGoldUpgradeLevel: _cappedStartingGoldUpgradeLevel,
      nexusHpUpgradeLevel: _cappedNexusHpUpgradeLevel,
      supplyUpgradeLevel: _cappedSupplyUpgradeLevel,
      fireTrainingUpgradeLevel: _cappedFireTrainingUpgradeLevel,
      criticalChanceUpgradeLevel: _cappedCriticalChanceUpgradeLevel,
      criticalDamageUpgradeLevel: _cappedCriticalDamageUpgradeLevel,
      killGoldUpgradeLevel: _cappedKillGoldUpgradeLevel,
      emergencySaleUpgradeLevel: _cappedEmergencySaleUpgradeLevel,
      unlockedStageCount: unlockedStageCount,
      bestRoundsByStage: Map.unmodifiable(bestRoundsByStage),
      clearedStageNumbers: Set.unmodifiable(clearedStageNumbers),
      researchLevels: Map.unmodifiable(
        researchLevels.map((key, value) => MapEntry(key, researchLevel(key))),
      ),
      researchElapsedMillis: Map.unmodifiable(researchElapsedMillis),
      activeResearches: List.unmodifiable(
        activeResearches.map(
          (research) => SavedActiveResearch(
            type: research.type,
            targetLevel: research.targetLevel,
            startedAtMillis: research.startedAtMillis,
            durationMillis: research.durationMillis,
            initialElapsedMillis: research.initialElapsedMillis,
          ),
        ),
      ),
      coreCombatSkill: coreCombatSkill,
      corePassiveSlotTwoUnlocked: corePassiveSlotTwoUnlocked,
      corePassiveSlots: List<CorePassiveAbility?>.unmodifiable(
        _sanitizedCorePassiveSlots(),
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
    criticalChanceUpgradeLevel = data.criticalChanceUpgradeLevel
        .clamp(0, maxCriticalChanceUpgradeLevel)
        .toInt();
    criticalDamageUpgradeLevel = data.criticalDamageUpgradeLevel
        .clamp(0, maxCriticalDamageUpgradeLevel)
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
              final definition = gameResearchDefinitions[entry.key];
              return definition != null && entry.value > 0;
            })
            .map((entry) {
              final definition = gameResearchDefinitions[entry.key]!;
              return MapEntry(
                entry.key,
                entry.value.clamp(0, definition.maxLevel).toInt(),
              );
            }),
      );
    researchElapsedMillis
      ..clear()
      ..addEntries(
        data.researchElapsedMillis.entries
            .where((entry) {
              final definition = gameResearchDefinitions[entry.key];
              final fullDuration = researchDurationForCurrentLevel(entry.key);
              return definition != null &&
                  entry.value > 0 &&
                  entry.value < fullDuration &&
                  researchLevel(entry.key) < definition.maxLevel;
            })
            .map((entry) => MapEntry(entry.key, entry.value)),
      );
    activeResearches
      ..clear()
      ..addAll(
        data.activeResearches
            .where((research) {
              final definition = gameResearchDefinitions[research.type];
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
                initialElapsedMillis: research.initialElapsedMillis,
              ),
            ),
      );
    coreCombatSkill = data.coreCombatSkill;
    corePassiveSlotTwoUnlocked = data.corePassiveSlotTwoUnlocked;
    final restoredSlots = data.corePassiveSlots;
    for (var i = 0; i < corePassiveSlots.length; i++) {
      corePassiveSlots[i] = i < restoredSlots.length ? restoredSlots[i] : null;
    }
    _sanitizeCorePassiveSlotsInPlace();
  }

  bool equipCoreCombatSkill(CoreCombatSkill skill) {
    if (skill != CoreCombatSkill.guardianBeam || coreCombatSkill == skill) {
      return skill == CoreCombatSkill.guardianBeam;
    }
    coreCombatSkill = skill;
    return true;
  }

  bool unequipCoreCombatSkill() {
    if (coreCombatSkill == null) {
      return false;
    }
    coreCombatSkill = null;
    return true;
  }

  bool equipCorePassiveAbility(CorePassiveAbility ability, int slotIndex) {
    if (slotIndex < 0 ||
        slotIndex >= corePassiveSlotCount ||
        !unlockedCorePassiveAbilities.contains(ability)) {
      return false;
    }
    final existingIndex = corePassiveSlots.indexOf(ability);
    if (existingIndex >= 0 && existingIndex != slotIndex) {
      return false;
    }
    corePassiveSlots[slotIndex] = ability;
    _sanitizeCorePassiveSlotsInPlace();
    return true;
  }

  bool unlockCorePassiveSlot() {
    if (!canUnlockCorePassiveSlot) {
      return false;
    }
    runes -= corePassiveSlotUnlockCost;
    corePassiveSlotTwoUnlocked = true;
    return true;
  }

  bool unequipCorePassiveAbility(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= corePassiveSlotCount) {
      return false;
    }
    if (corePassiveSlots[slotIndex] == null) {
      return false;
    }
    corePassiveSlots[slotIndex] = null;
    return true;
  }

  List<CorePassiveAbility?> _sanitizedCorePassiveSlots() {
    final slots = List<CorePassiveAbility?>.of(corePassiveSlots);
    final unlocked = unlockedCorePassiveAbilities;
    final seen = <CorePassiveAbility>{};
    for (var i = 0; i < slots.length; i++) {
      final ability = slots[i];
      if (i >= corePassiveSlotCount ||
          ability == null ||
          !unlocked.contains(ability) ||
          seen.contains(ability)) {
        slots[i] = null;
        continue;
      }
      seen.add(ability);
    }
    return slots;
  }

  void _sanitizeCorePassiveSlotsInPlace() {
    final slots = _sanitizedCorePassiveSlots();
    for (var i = 0; i < corePassiveSlots.length; i++) {
      corePassiveSlots[i] = slots[i];
    }
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

  bool upgradeCriticalChance() {
    if (!canUpgradeCriticalChance) {
      return false;
    }

    runes -= criticalChanceUpgradeCost;
    criticalChanceUpgradeLevel++;
    return true;
  }

  bool upgradeCriticalDamage() {
    if (!canUpgradeCriticalDamage) {
      return false;
    }

    runes -= criticalDamageUpgradeCost;
    criticalDamageUpgradeLevel++;
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
    if (completedRounds <= 0) {
      return 0;
    }
    final cappedRounds = completedRounds.clamp(0, 50).toInt();
    final rewardProgress =
        (math.pow(runeRewardGrowthPerRound, cappedRounds) - 1) /
        (math.pow(runeRewardGrowthPerRound, 50) - 1);
    final baseReward = baseStageOneFullClearRuneReward * rewardProgress;
    final bonusRate = stageRuneRewardBonusRateFor(stageNumber);
    return math.max(1, (baseReward * (1 + bonusRate)).round());
  }

  void resetLastRunReward() {
    lastRunRuneReward = 0;
  }
}
