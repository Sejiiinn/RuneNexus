import 'dart:math' as math;

import '../../data/definitions/game_core_passive_tree_data.dart' as core_tree;
import '../../data/definitions/game_daily_quest_data.dart';
import '../../data/definitions/game_research_data.dart';
import '../../data/definitions/game_turret_module_data.dart';
import '../../data/definitions/game_weekly_quest_data.dart';
import '../../data/save/game_save_data.dart';
import '../../domain/core/core_ability.dart';
import '../../domain/core/core_passive_tree.dart';
import '../../domain/currency/diamond_wallet.dart';
import '../../domain/daily_quest/daily_quest_type.dart';
import '../../domain/research/research_progress.dart';
import '../../domain/research/research_type.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';

part 'run_progression/core.dart';
part 'run_progression/permanent_upgrades.dart';
part 'run_progression/quests.dart';
part 'run_progression/research.dart';
part 'run_progression/turret_modules.dart';

class RunProgression
    with
        _PermanentUpgradeProgression,
        _ResearchProgression,
        _TurretModuleProgression,
        _QuestProgression,
        _CoreProgression {
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
  static const int researchSlotTwoUnlockRequiredStage = 10;
  static const int researchSlotTwoUnlockCost = 600;
  static const int gemShardsPerGemAttunementLevel = 2;
  static const int turretModuleTicketDiamondCost = 40;
  static const int diamondMillisPerResearchMinute = 60000;
  static const int uninitializedDailyQuestDayKey = -1;
  static const int uninitializedWeeklyQuestWeekKey = -1;
  static const int dailyQuestResetHourKst = 5;
  static const int dailyQuestClockRollbackGraceMillis = 5 * 60 * 1000;
  static const int _dailyQuestSeenCheckpointIntervalMillis = 60 * 1000;
  static const int _hourMillis = 60 * 60 * 1000;
  static const int _dayMillis = 24 * _hourMillis;
  static const int _kstOffsetHours = 9;
  static const double researchEfficiencyPerLevel = 0.05;
  static const double researchCostEfficiencyPerLevel = 0.05;
  static const double bossBountyBonusPerLevel = 0.025;
  static const double linkMaintenanceDiscountPerLevel = 0.02;
  static const double runeResonanceBonusPerLevel = 0.02;
  static const double runUpgradeCostDiscountPerLevel = 0.02;
  static const int runUpgradeLimitExpansionMaxLevelPerLevel = 1;
  static const int bossGemShardsPerCrystalRecoveryLevel = 1;
  static const int runeRewardFullClearRoundCount = 40;
  static const int baseStageOneFullClearRuneReward = 150;
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

  @override
  int runes = 0;
  final DiamondWallet _diamondWallet = DiamondWallet();
  int lastRunRuneReward = 0;
  @override
  int unlockedStageCount = 1;
  final Map<int, int> bestRoundsByStage = {};
  @override
  final Set<int> clearedStageNumbers = {};
  final Set<String> claimedEventIds = {};
  int get freeDiamonds => _diamondWallet.free;
  set freeDiamonds(int value) {
    _diamondWallet.free = value;
  }

  int get paidDiamonds => _diamondWallet.paid;
  set paidDiamonds(int value) {
    _diamondWallet.paid = value;
  }

  int get diamonds => _diamondWallet.total;

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

  static int weeklyQuestWeekKeyFor(int nowMillis) {
    final dayKey = dailyQuestDayKeyFor(nowMillis);
    // 1970-01-01은 목요일이므로 월요일 시작 주차에 맞춘 보정.
    return (dayKey + 3) ~/ 7;
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

  @override
  void addFreeDiamonds(int amount) {
    if (amount <= 0) {
      return;
    }
    _diamondWallet.addFree(amount);
  }

  @override
  bool canSpendDiamonds(int amount) {
    return _diamondWallet.canSpend(amount);
  }

  @override
  DiamondSpendResult? spendDiamonds(int amount) {
    return _diamondWallet.spend(amount);
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
      dailyAttendanceRewardClaimed: dailyAttendanceRewardClaimed,
      dailyQuestAllCompleteClaimed: dailyQuestAllCompleteClaimed,
      weeklyQuestWeekKey: weeklyQuestWeekKey,
      weeklyQuestProgress: Map.unmodifiable(weeklyQuestProgress),
      claimedWeeklyQuestRewards: Set.unmodifiable(claimedWeeklyQuestRewards),
      weeklyQuestAllCompleteClaimed: weeklyQuestAllCompleteClaimed,
      weeklyAttendanceDayKeys: Set.unmodifiable(weeklyAttendanceDayKeys),
      weeklyAttendanceRewardClaimed: weeklyAttendanceRewardClaimed,
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
      researchSlotTwoUnlocked: researchSlotTwoUnlocked,
      turretModuleTickets: turretModuleTickets,
      turretModuleDrawCount: turretModuleDrawCount,
      turretModuleTicketPurchaseCount: turretModuleTicketPurchaseCount,
      turretModuleItemSequence: turretModuleItemSequence,
      ownedTurretModules: List.unmodifiable(
        ownedTurretModules.map(
          (module) => SavedTurretModule(
            id: module.id,
            turretType: module.key.turretType,
            part: module.key.part,
            family: module.key.family,
            grade: module.key.grade,
            options: List.unmodifiable(
              module.options.map(
                (option) => SavedTurretModuleOption(
                  type: option.type,
                  value: option.value,
                ),
              ),
            ),
            acquiredOrder: module.acquiredOrder,
            equipped: module.equipped,
          ),
        ),
      ),
      coreCombatSkill: coreCombatSkill,
      totalCorePoints: totalCorePoints,
      lastRunCorePointReward: lastRunCorePointReward,
      lastRunTurretModuleTicketReward: lastRunTurretModuleTicketReward,
      corePassiveTreeRevision: corePassiveTreeRevision,
      corePassiveNodeRanks: Map.unmodifiable(corePassiveNodeRanks),
      claimedCorePointStageRewards: Set.unmodifiable(
        claimedCorePointStageRewards,
      ),
      claimedEventIds: Set.unmodifiable(claimedEventIds),
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
    dailyAttendanceRewardClaimed = data.dailyAttendanceRewardClaimed;
    dailyQuestAllCompleteClaimed = data.dailyQuestAllCompleteClaimed;
    weeklyQuestWeekKey = data.weeklyQuestWeekKey;
    weeklyQuestProgress
      ..clear()
      ..addEntries(
        data.weeklyQuestProgress.entries
            .where((entry) => gameWeeklyQuestDefinitions.containsKey(entry.key))
            .map((entry) {
              final target = gameWeeklyQuestDefinitions[entry.key]!.targetCount;
              return MapEntry(entry.key, entry.value.clamp(0, target).toInt());
            }),
      );
    claimedWeeklyQuestRewards
      ..clear()
      ..addAll(
        data.claimedWeeklyQuestRewards.where(
          gameWeeklyQuestDefinitions.containsKey,
        ),
      );
    weeklyQuestAllCompleteClaimed = data.weeklyQuestAllCompleteClaimed;
    weeklyAttendanceDayKeys
      ..clear()
      ..addAll(data.weeklyAttendanceDayKeys.where((dayKey) => dayKey >= 0));
    weeklyAttendanceRewardClaimed = data.weeklyAttendanceRewardClaimed;
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
    researchSlotTwoUnlocked =
        data.researchSlotTwoUnlocked || activeResearches.length > 1;
    turretModuleTickets = math.max(0, data.turretModuleTickets);
    turretModuleDrawCount = math.max(0, data.turretModuleDrawCount);
    turretModuleTicketPurchaseCount = math.max(
      0,
      data.turretModuleTicketPurchaseCount,
    );
    turretModuleItemSequence = math.max(0, data.turretModuleItemSequence);
    turretModules
      ..clear()
      ..addEntries(
        data.ownedTurretModules
            .where(
              (module) => gameTurretModuleDefinitions.containsKey(module.key),
            )
            .map(
              (module) => MapEntry(
                module.id,
                TurretModuleInventoryItem(
                  id: module.id,
                  key: module.key,
                  options: List.unmodifiable(
                    _sanitizeTurretModuleOptions(
                      module.key,
                      module.options.map(
                        (option) => TurretModuleOptionRoll(
                          type: option.type,
                          value: option.value,
                        ),
                      ),
                    ),
                  ),
                  acquiredOrder: math.max(0, module.acquiredOrder),
                  equipped: module.equipped,
                ),
              ),
            ),
      );
    _sanitizeTurretModules();
    coreCombatSkill = data.coreCombatSkill;
    totalCorePoints = math.max(0, data.totalCorePoints);
    lastRunCorePointReward = math.max(0, data.lastRunCorePointReward);
    lastRunTurretModuleTicketReward = math.max(
      0,
      data.lastRunTurretModuleTicketReward,
    );
    corePassiveTreeRevision = core_tree.corePassiveTreeRevision;
    claimedCorePointStageRewards
      ..clear()
      ..addAll(data.claimedCorePointStageRewards.where((stage) => stage > 0));
    claimedEventIds
      ..clear()
      ..addAll(data.claimedEventIds.where((id) => id.isNotEmpty));
    final restoredRanks = <CorePassiveNodeId, int>{
      for (final entry in data.corePassiveNodeRanks.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    final validRestoredTree =
        data.corePassiveTreeRevision == core_tree.corePassiveTreeRevision &&
        core_tree.isValidCorePassiveAllocation(restoredRanks) &&
        core_tree.corePassiveSpentPoints(restoredRanks) <= totalCorePoints;
    corePassiveNodeRanks
      ..clear()
      ..addAll(validRestoredTree ? restoredRanks : const {});
    _sanitizeCoreCombatSkill();
  }

  void finishRun({
    required int completedRounds,
    required bool success,
    required int stageNumber,
    int firstClearCorePointReward = 0,
    int firstClearTurretModuleTicketReward = 0,
  }) {
    final isFirstStageClear =
        success && stageNumber > 0 && !isStageCleared(stageNumber);
    lastRunRuneReward = runeRewardFor(
      completedRounds,
      success: success,
      stageNumber: stageNumber,
    );
    runes += lastRunRuneReward;
    lastRunCorePointReward = success
        ? grantFirstClearCorePoints(
            stageNumber: stageNumber,
            reward: firstClearCorePointReward,
          )
        : 0;
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
    lastRunTurretModuleTicketReward =
        isFirstStageClear && firstClearTurretModuleTicketReward > 0
        ? firstClearTurretModuleTicketReward
        : 0;
    turretModuleTickets += lastRunTurretModuleTicketReward;
  }

  int bestRoundForStage(int stageNumber) {
    return bestRoundsByStage[stageNumber] ?? 0;
  }

  @override
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
    final cappedRounds = completedRounds
        .clamp(0, runeRewardFullClearRoundCount)
        .toInt();
    final rewardProgress =
        (math.pow(runeRewardGrowthPerRound, cappedRounds) - 1) /
        (math.pow(runeRewardGrowthPerRound, runeRewardFullClearRoundCount) - 1);
    final baseReward = baseStageOneFullClearRuneReward * rewardProgress;
    final bonusRate = stageRuneRewardBonusRateFor(stageNumber);
    final resonanceMultiplier = 1 + runeResonanceBonusRate;
    return math.max(
      1,
      (baseReward * (1 + bonusRate) * resonanceMultiplier).round(),
    );
  }

  void resetLastRunReward() {
    lastRunRuneReward = 0;
    lastRunCorePointReward = 0;
    lastRunTurretModuleTicketReward = 0;
  }
}
