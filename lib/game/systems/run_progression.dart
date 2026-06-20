import 'dart:math' as math;

import '../../data/definitions/game_daily_quest_data.dart';
import '../../data/definitions/game_research_data.dart';
import '../../data/definitions/game_turret_module_data.dart';
import '../../data/save/game_save_data.dart';
import '../../domain/core/core_ability.dart';
import '../../domain/currency/diamond_wallet.dart';
import '../../domain/daily_quest/daily_quest_type.dart';
import '../../domain/research/research_progress.dart';
import '../../domain/research/research_type.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';

class RunProgression {
  static const int baseInitialGold = 170;
  static const int baseNexusHp = 20;
  static const int maxStageCount = 15;
  static const int maxStartingGoldUpgradeLevel = 20;
  static const int maxNexusHpUpgradeLevel = 10;
  static const int maxSupplyUpgradeLevel = 20;
  static const int maxFireTrainingUpgradeLevel = 20;
  static const int maxPhysicalDamageTrainingUpgradeLevel = 20;
  static const int maxElementalDamageTrainingUpgradeLevel = 20;
  static const int maxCriticalChanceUpgradeLevel = 20;
  static const int maxCriticalDamageUpgradeLevel = 20;
  static const int maxKillGoldUpgradeLevel = 20;
  static const int maxEmergencySaleUpgradeLevel = 5;
  static const int researchSlotCount = 1;
  static const int gemShardsPerGemAttunementLevel = 2;
  static const int corePassiveSlotUnlockCost = 200;
  static const int turretModuleTicketsPerStageClear = 1;
  static const int diamondMillisPerResearchMinute = 60000;
  static const int uninitializedDailyQuestDayKey = -1;
  static const int dailyQuestResetHourKst = 5;
  static const int dailyQuestClockRollbackGraceMillis = 5 * 60 * 1000;
  static const int _hourMillis = 60 * 60 * 1000;
  static const int _dayMillis = 24 * _hourMillis;
  static const int _kstOffsetHours = 9;
  static const double researchEfficiencyPerLevel = 0.05;
  static const double researchCostEfficiencyPerLevel = 0.05;
  static const double bossBountyBonusPerLevel = 0.025;
  static const double linkMaintenanceDiscountPerLevel = 0.02;
  static const double runeResonanceBonusPerLevel = 0.02;
  static const int runUpgradeLimitExpansionMaxLevelPerLevel = 1;
  static const int bossGemShardsPerCrystalRecoveryLevel = 1;
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
  static const int familyDamageTrainingUpgradeBaseCost = 55;
  static const int familyDamageTrainingUpgradeCostPerLevel = 6;
  static const double familyDamageTrainingUpgradeCostMultiplier = 1.07;
  static const double familyDamageTrainingBonusPerUpgradeLevel = 0.02;
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
    4.25,
    4.95,
    5.70,
    6.50,
    7.35,
  ];

  int runes = 0;
  final DiamondWallet _diamondWallet = DiamondWallet();
  int dailyQuestDayKey = uninitializedDailyQuestDayKey;
  int lastDailyQuestSeenMillis = 0;
  bool dailyQuestClockRollbackDetected = false;
  final Map<DailyQuestType, int> dailyQuestProgress = {};
  final Set<DailyQuestType> claimedDailyQuestRewards = {};
  bool dailyQuestAllCompleteClaimed = false;
  int lastRunRuneReward = 0;
  int startingGoldUpgradeLevel = 0;
  int nexusHpUpgradeLevel = 0;
  int supplyUpgradeLevel = 0;
  int fireTrainingUpgradeLevel = 0;
  int physicalDamageTrainingUpgradeLevel = 0;
  int elementalDamageTrainingUpgradeLevel = 0;
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
  int turretModuleTickets = 0;
  int turretModuleRarePityCounter = 0;
  final Map<TurretModuleKey, TurretModuleInventoryItem> turretModules = {};
  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam;
  bool corePassiveSlotTwoUnlocked = false;
  final List<CorePassiveAbility?> corePassiveSlots = [null, null];

  int get freeDiamonds => _diamondWallet.free;
  set freeDiamonds(int value) {
    _diamondWallet.free = value;
  }

  int get paidDiamonds => _diamondWallet.paid;
  set paidDiamonds(int value) {
    _diamondWallet.paid = value;
  }

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
  int get physicalDamageTrainingUpgradeCost => _hybridUpgradeCost(
    baseCost: familyDamageTrainingUpgradeBaseCost,
    costPerLevel: familyDamageTrainingUpgradeCostPerLevel,
    multiplier: familyDamageTrainingUpgradeCostMultiplier,
    level: _cappedPhysicalDamageTrainingUpgradeLevel,
  );
  int get elementalDamageTrainingUpgradeCost => _hybridUpgradeCost(
    baseCost: familyDamageTrainingUpgradeBaseCost,
    costPerLevel: familyDamageTrainingUpgradeCostPerLevel,
    multiplier: familyDamageTrainingUpgradeCostMultiplier,
    level: _cappedElementalDamageTrainingUpgradeLevel,
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
  double get physicalDamageTrainingBonusRate =>
      _cappedPhysicalDamageTrainingUpgradeLevel *
      familyDamageTrainingBonusPerUpgradeLevel;
  double get elementalDamageTrainingBonusRate =>
      _cappedElementalDamageTrainingUpgradeLevel *
      familyDamageTrainingBonusPerUpgradeLevel;
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
      !corePassiveSlotTwoUnlocked &&
      canSpendDiamonds(corePassiveSlotUnlockCost);
  Set<CorePassiveAbility> get unlockedCorePassiveAbilities {
    return {
      CorePassiveAbility.selfRepair,
      CorePassiveAbility.costSavingDesign,
      CorePassiveAbility.skillAcceleration,
    };
  }

  List<TurretModuleInventoryItem> get ownedTurretModules {
    final items = turretModules.values.toList()
      ..sort(_compareTurretModuleItems);
    return List.unmodifiable(items);
  }

  TurretModuleInventoryItem? turretModuleFor(TurretModuleKey key) {
    return turretModules[key];
  }

  TurretModuleInventoryItem? equippedTurretModuleFor(
    TurretType turretType,
    TurretModulePart part,
  ) {
    for (final item in turretModules.values) {
      if (item.equipped &&
          item.key.turretType == turretType &&
          item.key.part == part) {
        return item;
      }
    }
    return null;
  }

  TurretModuleEffect turretModuleEffectFor(TurretType turretType) {
    var effect = TurretModuleEffect.zero;
    for (final item in turretModules.values) {
      if (!item.equipped || item.key.turretType != turretType) {
        continue;
      }
      effect += effectiveTurretModuleEffect(item);
    }
    return effect;
  }

  double get researchEfficiencyRate =>
      researchLevel(ResearchType.researchEfficiency) *
      researchEfficiencyPerLevel;
  double get researchCostEfficiencyRate =>
      researchLevel(ResearchType.researchCostEfficiency) *
      researchCostEfficiencyPerLevel;
  double get bossBountyBonusRate =>
      researchLevel(ResearchType.bossBounty) * bossBountyBonusPerLevel;
  double get firstLinkUpgradeDiscountRate =>
      researchLevel(ResearchType.linkMaintenance) *
      linkMaintenanceDiscountPerLevel;
  int get bossKillGemShardBonus =>
      researchLevel(ResearchType.crystalRecovery) *
      bossGemShardsPerCrystalRecoveryLevel;
  double get runeResonanceBonusRate =>
      researchLevel(ResearchType.runeResonance) * runeResonanceBonusPerLevel;
  int runUpgradeMaxLevelBonusFor(RunUpgradeType type) {
    final researchType = switch (type) {
      RunUpgradeType.towerDamage => ResearchType.towerDamageLimitExpansion,
      RunUpgradeType.killGold => ResearchType.killGoldLimitExpansion,
      RunUpgradeType.waveGold => ResearchType.waveGoldLimitExpansion,
    };
    return researchLevel(researchType) *
        runUpgradeLimitExpansionMaxLevelPerLevel;
  }

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
  bool get canUpgradePhysicalDamageTraining =>
      _cappedPhysicalDamageTrainingUpgradeLevel <
          maxPhysicalDamageTrainingUpgradeLevel &&
      runes >= physicalDamageTrainingUpgradeCost;
  bool get canUpgradeElementalDamageTraining =>
      _cappedElementalDamageTrainingUpgradeLevel <
          maxElementalDamageTrainingUpgradeLevel &&
      runes >= elementalDamageTrainingUpgradeCost;
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
  int get diamonds => _diamondWallet.total;
  int get completedDailyQuestCount =>
      gameDailyQuestDefinitions.keys.where(isDailyQuestComplete).length;
  bool get allDailyQuestsComplete =>
      completedDailyQuestCount == gameDailyQuestDefinitions.length;

  int get _cappedStartingGoldUpgradeLevel =>
      startingGoldUpgradeLevel.clamp(0, maxStartingGoldUpgradeLevel).toInt();
  int get _cappedNexusHpUpgradeLevel =>
      nexusHpUpgradeLevel.clamp(0, maxNexusHpUpgradeLevel).toInt();
  int get _cappedSupplyUpgradeLevel =>
      supplyUpgradeLevel.clamp(0, maxSupplyUpgradeLevel).toInt();
  int get _cappedFireTrainingUpgradeLevel =>
      fireTrainingUpgradeLevel.clamp(0, maxFireTrainingUpgradeLevel).toInt();
  int get _cappedPhysicalDamageTrainingUpgradeLevel =>
      physicalDamageTrainingUpgradeLevel
          .clamp(0, maxPhysicalDamageTrainingUpgradeLevel)
          .toInt();
  int get _cappedElementalDamageTrainingUpgradeLevel =>
      elementalDamageTrainingUpgradeLevel
          .clamp(0, maxElementalDamageTrainingUpgradeLevel)
          .toInt();
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

  static int researchInstantCompleteCostFor(
    ResearchProgress research, {
    required int nowMillis,
  }) {
    final remainingMillis = research.remainingMillisAt(nowMillis);
    if (remainingMillis <= 0) {
      return 0;
    }
    return (remainingMillis + diamondMillisPerResearchMinute - 1) ~/
        diamondMillisPerResearchMinute;
  }

  static int dailyQuestDayKeyFor(int nowMillis) {
    final adjustedMillis =
        nowMillis + (_kstOffsetHours - dailyQuestResetHourKst) * _hourMillis;
    return adjustedMillis ~/ _dayMillis;
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
    final cost = researchInstantCompleteCostFor(active, nowMillis: nowMillis);
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

  List<TurretModuleInventoryItem> drawTurretModules({
    required int count,
    required List<TurretType> availableTurretTypes,
    math.Random? random,
  }) {
    if (count <= 0 || turretModuleTickets < count) {
      return const [];
    }
    final turretPool = availableTurretTypes
        .where(
          (type) => gameTurretModuleDefinitions.keys.any(
            (key) => key.turretType == type,
          ),
        )
        .toList(growable: false);
    if (turretPool.isEmpty) {
      return const [];
    }

    final rollRandom = random ?? math.Random();
    turretModuleTickets -= count;
    final results = <TurretModuleInventoryItem>[];
    for (var i = 0; i < count; i++) {
      final turretType = turretPool[rollRandom.nextInt(turretPool.length)];
      final part = TurretModulePart
          .values[rollRandom.nextInt(TurretModulePart.values.length)];
      final grade = _rollTurretModuleGrade(rollRandom);
      final key = TurretModuleKey(
        turretType: turretType,
        part: part,
        family: turretModuleFamilyFor(turretType, part),
        grade: grade,
      );
      results.add(grantTurretModule(key));
    }
    return List.unmodifiable(results);
  }

  TurretModuleInventoryItem grantTurretModule(TurretModuleKey key) {
    if (!gameTurretModuleDefinitions.containsKey(key)) {
      return TurretModuleInventoryItem(
        key: key,
        stars: 0,
        shards: 0,
        equipped: false,
      );
    }
    final existing = turretModules[key];
    final item = existing == null
        ? TurretModuleInventoryItem(
            key: key,
            stars: 0,
            shards: 0,
            equipped: false,
          )
        : existing.copyWith(shards: existing.shards + 1);
    turretModules[key] = item;
    _sanitizeTurretModules();
    return turretModules[key]!;
  }

  bool equipTurretModule(TurretModuleKey key) {
    final item = turretModules[key];
    if (item == null) {
      return false;
    }
    for (final entry in turretModules.entries.toList()) {
      final candidate = entry.value;
      if (candidate.key.turretType != key.turretType ||
          candidate.key.part != key.part) {
        continue;
      }
      turretModules[entry.key] = candidate.copyWith(
        equipped: candidate.key == key,
      );
    }
    _sanitizeTurretModules();
    return true;
  }

  bool fuseTurretModule(TurretModuleKey key) {
    final item = turretModules[key];
    if (item == null ||
        item.shards < turretModuleFusionShardCost ||
        (item.key.grade == TurretModuleGrade.rare &&
            item.stars >= turretModuleMaxStars)) {
      return false;
    }

    final remainingShards = item.shards - turretModuleFusionShardCost;
    if (item.stars < turretModuleMaxStars) {
      turretModules[key] = item.copyWith(
        stars: item.stars + 1,
        shards: remainingShards,
      );
      _sanitizeTurretModules();
      return true;
    }

    final nextGrade = item.key.grade.nextGrade;
    if (nextGrade == null) {
      return false;
    }
    final nextKey = TurretModuleKey(
      turretType: item.key.turretType,
      part: item.key.part,
      family: item.key.family,
      grade: nextGrade,
    );
    final existingNext = turretModules[nextKey];
    turretModules.remove(key);
    turretModules[nextKey] = existingNext == null
        ? TurretModuleInventoryItem(
            key: nextKey,
            stars: 0,
            shards: remainingShards,
            equipped: item.equipped,
          )
        : existingNext.copyWith(
            shards: existingNext.shards + remainingShards,
            equipped: existingNext.equipped || item.equipped,
          );
    if (item.equipped) {
      equipTurretModule(nextKey);
    } else {
      _sanitizeTurretModules();
    }
    return true;
  }

  void addFreeDiamonds(int amount) {
    if (amount <= 0) {
      return;
    }
    _diamondWallet.addFree(amount);
  }

  bool refreshDailyQuests({required int nowMillis}) {
    var changed = false;
    final currentDayKey = dailyQuestDayKeyFor(nowMillis);
    if (dailyQuestDayKey != currentDayKey) {
      dailyQuestDayKey = currentDayKey;
      dailyQuestProgress.clear();
      claimedDailyQuestRewards.clear();
      dailyQuestAllCompleteClaimed = false;
      dailyQuestClockRollbackDetected = false;
      changed = true;
    } else if (lastDailyQuestSeenMillis > 0 &&
        nowMillis + dailyQuestClockRollbackGraceMillis <
            lastDailyQuestSeenMillis) {
      if (!dailyQuestClockRollbackDetected) {
        dailyQuestClockRollbackDetected = true;
        changed = true;
      }
    }

    if (lastDailyQuestSeenMillis == 0 || nowMillis > lastDailyQuestSeenMillis) {
      lastDailyQuestSeenMillis = nowMillis;
      changed = true;
    }
    return changed;
  }

  void recordDailyQuestProgress(
    DailyQuestType type, {
    int amount = 1,
    required int nowMillis,
  }) {
    if (amount <= 0) {
      return;
    }
    refreshDailyQuests(nowMillis: nowMillis);
    final definition = gameDailyQuestDefinitions[type];
    if (definition == null) {
      return;
    }
    final current = dailyQuestProgress[type] ?? 0;
    dailyQuestProgress[type] = math.min(
      definition.targetCount,
      current + amount,
    );
  }

  bool isDailyQuestComplete(DailyQuestType type) {
    final definition = gameDailyQuestDefinitions[type];
    if (definition == null) {
      return false;
    }
    return (dailyQuestProgress[type] ?? 0) >= definition.targetCount;
  }

  bool canClaimDailyQuestReward(DailyQuestType type, {required int nowMillis}) {
    refreshDailyQuests(nowMillis: nowMillis);
    return !dailyQuestClockRollbackDetected &&
        isDailyQuestComplete(type) &&
        !claimedDailyQuestRewards.contains(type);
  }

  bool claimDailyQuestReward(DailyQuestType type, {required int nowMillis}) {
    final definition = gameDailyQuestDefinitions[type];
    if (definition == null ||
        !canClaimDailyQuestReward(type, nowMillis: nowMillis)) {
      return false;
    }
    addFreeDiamonds(definition.rewardDiamonds);
    claimedDailyQuestRewards.add(type);
    return true;
  }

  bool canClaimDailyQuestAllCompleteReward({required int nowMillis}) {
    refreshDailyQuests(nowMillis: nowMillis);
    return !dailyQuestClockRollbackDetected &&
        allDailyQuestsComplete &&
        !dailyQuestAllCompleteClaimed;
  }

  bool claimDailyQuestAllCompleteReward({required int nowMillis}) {
    if (!canClaimDailyQuestAllCompleteReward(nowMillis: nowMillis)) {
      return false;
    }
    addFreeDiamonds(dailyQuestAllCompleteRewardDiamonds);
    dailyQuestAllCompleteClaimed = true;
    return true;
  }

  bool canSpendDiamonds(int amount) {
    return _diamondWallet.canSpend(amount);
  }

  DiamondSpendResult? spendDiamonds(int amount) {
    return _diamondWallet.spend(amount);
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
      freeDiamonds: freeDiamonds,
      paidDiamonds: paidDiamonds,
      dailyQuestDayKey: dailyQuestDayKey,
      lastDailyQuestSeenMillis: lastDailyQuestSeenMillis,
      dailyQuestClockRollbackDetected: dailyQuestClockRollbackDetected,
      dailyQuestProgress: Map.unmodifiable(dailyQuestProgress),
      claimedDailyQuestRewards: Set.unmodifiable(claimedDailyQuestRewards),
      dailyQuestAllCompleteClaimed: dailyQuestAllCompleteClaimed,
      lastRunRuneReward: lastRunRuneReward,
      startingGoldUpgradeLevel: _cappedStartingGoldUpgradeLevel,
      nexusHpUpgradeLevel: _cappedNexusHpUpgradeLevel,
      supplyUpgradeLevel: _cappedSupplyUpgradeLevel,
      fireTrainingUpgradeLevel: _cappedFireTrainingUpgradeLevel,
      physicalDamageTrainingUpgradeLevel:
          _cappedPhysicalDamageTrainingUpgradeLevel,
      elementalDamageTrainingUpgradeLevel:
          _cappedElementalDamageTrainingUpgradeLevel,
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
      turretModuleTickets: turretModuleTickets,
      turretModuleRarePityCounter: turretModuleRarePityCounter,
      ownedTurretModules: List.unmodifiable(
        ownedTurretModules.map(
          (module) => SavedTurretModule(
            turretType: module.key.turretType,
            part: module.key.part,
            family: module.key.family,
            grade: module.key.grade,
            stars: module.stars,
            shards: module.shards,
            equipped: module.equipped,
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
    _diamondWallet.setBalances(
      free: data.freeDiamonds,
      paid: data.paidDiamonds,
    );
    dailyQuestDayKey = data.dailyQuestDayKey;
    lastDailyQuestSeenMillis = math.max(0, data.lastDailyQuestSeenMillis);
    dailyQuestClockRollbackDetected = data.dailyQuestClockRollbackDetected;
    dailyQuestProgress
      ..clear()
      ..addEntries(
        data.dailyQuestProgress.entries
            .where((entry) => gameDailyQuestDefinitions.containsKey(entry.key))
            .map((entry) {
              final target = gameDailyQuestDefinitions[entry.key]!.targetCount;
              return MapEntry(entry.key, entry.value.clamp(0, target).toInt());
            }),
      );
    claimedDailyQuestRewards
      ..clear()
      ..addAll(
        data.claimedDailyQuestRewards.where(
          gameDailyQuestDefinitions.containsKey,
        ),
      );
    dailyQuestAllCompleteClaimed = data.dailyQuestAllCompleteClaimed;
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
    physicalDamageTrainingUpgradeLevel = data.physicalDamageTrainingUpgradeLevel
        .clamp(0, maxPhysicalDamageTrainingUpgradeLevel)
        .toInt();
    elementalDamageTrainingUpgradeLevel = data
        .elementalDamageTrainingUpgradeLevel
        .clamp(0, maxElementalDamageTrainingUpgradeLevel)
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
    turretModuleTickets = math.max(0, data.turretModuleTickets);
    turretModuleRarePityCounter = data.turretModuleRarePityCounter
        .clamp(0, 34)
        .toInt();
    turretModules
      ..clear()
      ..addEntries(
        data.ownedTurretModules
            .where(
              (module) => gameTurretModuleDefinitions.containsKey(module.key),
            )
            .map(
              (module) => MapEntry(
                module.key,
                TurretModuleInventoryItem(
                  key: module.key,
                  stars: module.stars.clamp(0, turretModuleMaxStars).toInt(),
                  shards: math.max(0, module.shards),
                  equipped: module.equipped,
                ),
              ),
            ),
      );
    _sanitizeTurretModules();
    coreCombatSkill = data.coreCombatSkill;
    corePassiveSlotTwoUnlocked = data.corePassiveSlotTwoUnlocked;
    final restoredSlots = data.corePassiveSlots;
    for (var i = 0; i < corePassiveSlots.length; i++) {
      corePassiveSlots[i] = i < restoredSlots.length ? restoredSlots[i] : null;
    }
    _sanitizeCoreCombatSkill();
    _sanitizeCorePassiveSlotsInPlace();
  }

  bool equipCoreCombatSkill(CoreCombatSkill skill) {
    if (!_isCoreCombatSkillUnlocked(skill) || coreCombatSkill == skill) {
      return _isCoreCombatSkillUnlocked(skill);
    }
    coreCombatSkill = skill;
    return true;
  }

  bool _isCoreCombatSkillUnlocked(CoreCombatSkill skill) {
    return switch (skill) {
      CoreCombatSkill.guardianBeam => true,
      CoreCombatSkill.riftMark => unlockedStageCount >= 6,
    };
  }

  bool unequipCoreCombatSkill() {
    if (coreCombatSkill == null) {
      return false;
    }
    coreCombatSkill = null;
    return true;
  }

  void _sanitizeCoreCombatSkill() {
    final skill = coreCombatSkill;
    if (skill != null && !_isCoreCombatSkillUnlocked(skill)) {
      coreCombatSkill = CoreCombatSkill.guardianBeam;
    }
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
    if (spendDiamonds(corePassiveSlotUnlockCost) == null) {
      return false;
    }
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

  bool upgradePhysicalDamageTraining() {
    if (!canUpgradePhysicalDamageTraining) {
      return false;
    }

    runes -= physicalDamageTrainingUpgradeCost;
    physicalDamageTrainingUpgradeLevel++;
    return true;
  }

  bool upgradeElementalDamageTraining() {
    if (!canUpgradeElementalDamageTraining) {
      return false;
    }

    runes -= elementalDamageTrainingUpgradeCost;
    elementalDamageTrainingUpgradeLevel++;
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
    if (success) {
      turretModuleTickets += turretModuleTicketsPerStageClear;
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
    final resonanceMultiplier = 1 + runeResonanceBonusRate;
    return math.max(
      1,
      (baseReward * (1 + bonusRate) * resonanceMultiplier).round(),
    );
  }

  TurretModuleGrade _rollTurretModuleGrade(math.Random random) {
    final rareChance = turretModuleRarePityCounter >= 34
        ? 1.0
        : 0.05 + math.max(0, turretModuleRarePityCounter - 14) * 0.03;
    if (random.nextDouble() < rareChance.clamp(0.05, 1.0)) {
      turretModuleRarePityCounter = 0;
      return TurretModuleGrade.rare;
    }
    turretModuleRarePityCounter++;

    const normalWeight = 68;
    const magicWeight = 27;
    final roll = random.nextInt(normalWeight + magicWeight);
    return roll < normalWeight
        ? TurretModuleGrade.normal
        : TurretModuleGrade.magic;
  }

  void _sanitizeTurretModules() {
    final equippedParts = <String, TurretModuleKey>{};
    for (final entry in turretModules.entries.toList()) {
      final item = entry.value;
      if (!gameTurretModuleDefinitions.containsKey(item.key)) {
        turretModules.remove(entry.key);
        continue;
      }
      final sanitized = item.copyWith(
        stars: item.stars.clamp(0, turretModuleMaxStars).toInt(),
        shards: math.max(0, item.shards),
      );
      turretModules[entry.key] = sanitized;
      if (!sanitized.equipped) {
        continue;
      }
      final slotKey =
          '${sanitized.key.turretType.name}:${sanitized.key.part.name}';
      final previous = equippedParts[slotKey];
      if (previous != null) {
        turretModules[entry.key] = sanitized.copyWith(equipped: false);
        continue;
      }
      equippedParts[slotKey] = sanitized.key;
    }
  }

  void resetLastRunReward() {
    lastRunRuneReward = 0;
  }
}

int _compareTurretModuleItems(
  TurretModuleInventoryItem a,
  TurretModuleInventoryItem b,
) {
  final turretCompare = a.key.turretType.index.compareTo(
    b.key.turretType.index,
  );
  if (turretCompare != 0) {
    return turretCompare;
  }
  final partCompare = a.key.part.index.compareTo(b.key.part.index);
  if (partCompare != 0) {
    return partCompare;
  }
  final familyCompare = a.key.family.index.compareTo(b.key.family.index);
  if (familyCompare != 0) {
    return familyCompare;
  }
  return a.key.grade.index.compareTo(b.key.grade.index);
}
