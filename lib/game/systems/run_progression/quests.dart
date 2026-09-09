part of '../run_progression.dart';

mixin _QuestProgression {
  abstract int turretModuleTickets;

  void addFreeDiamonds(int amount);

  int dailyQuestDayKey = RunProgression.uninitializedDailyQuestDayKey;
  int lastDailyQuestSeenMillis = 0;
  bool dailyQuestClockRollbackDetected = false;
  final Map<DailyQuestType, int> dailyQuestProgress = {};
  final Set<DailyQuestType> claimedDailyQuestRewards = {};
  bool dailyAttendanceRewardClaimed = false;
  bool dailyQuestAllCompleteClaimed = false;
  int weeklyQuestWeekKey = RunProgression.uninitializedWeeklyQuestWeekKey;
  final Map<DailyQuestType, int> weeklyQuestProgress = {};
  final Set<DailyQuestType> claimedWeeklyQuestRewards = {};
  bool weeklyQuestAllCompleteClaimed = false;
  final Set<int> weeklyAttendanceDayKeys = {};
  bool weeklyAttendanceRewardClaimed = false;

  int get completedDailyQuestCount =>
      gameDailyQuestDefinitions.keys.where(isDailyQuestComplete).length;
  bool get allDailyQuestsComplete =>
      completedDailyQuestCount == gameDailyQuestDefinitions.length;
  int get completedWeeklyQuestCount =>
      gameWeeklyQuestDefinitions.keys.where(isWeeklyQuestComplete).length;
  bool get allWeeklyQuestsComplete =>
      completedWeeklyQuestCount == gameWeeklyQuestDefinitions.length;

  bool refreshDailyQuests({required int nowMillis}) {
    var changed = false;
    final currentDayKey = RunProgression.dailyQuestDayKeyFor(nowMillis);
    final dayChanged = dailyQuestDayKey != currentDayKey;
    if (dayChanged) {
      dailyQuestDayKey = currentDayKey;
      dailyQuestProgress.clear();
      claimedDailyQuestRewards.clear();
      dailyAttendanceRewardClaimed = false;
      dailyQuestAllCompleteClaimed = false;
      dailyQuestClockRollbackDetected = false;
      changed = true;
    } else if (lastDailyQuestSeenMillis > 0 &&
        nowMillis + RunProgression.dailyQuestClockRollbackGraceMillis <
            lastDailyQuestSeenMillis) {
      if (!dailyQuestClockRollbackDetected) {
        dailyQuestClockRollbackDetected = true;
        changed = true;
      }
    }

    // 롤백 감지 기준 시각의 분 단위 체크포인트.
    if (dayChanged ||
        lastDailyQuestSeenMillis == 0 ||
        nowMillis - lastDailyQuestSeenMillis >=
            RunProgression._dailyQuestSeenCheckpointIntervalMillis) {
      lastDailyQuestSeenMillis = nowMillis;
    }
    if (_refreshWeeklyQuests(currentDayKey: currentDayKey)) {
      changed = true;
    }
    return changed;
  }

  bool _refreshWeeklyQuests({required int currentDayKey}) {
    var changed = false;
    final currentWeekKey = (currentDayKey + 3) ~/ 7;
    if (weeklyQuestWeekKey != currentWeekKey) {
      weeklyQuestWeekKey = currentWeekKey;
      weeklyQuestProgress.clear();
      claimedWeeklyQuestRewards.clear();
      weeklyQuestAllCompleteClaimed = false;
      weeklyAttendanceDayKeys.clear();
      weeklyAttendanceRewardClaimed = false;
      changed = true;
    }
    if (weeklyAttendanceDayKeys.add(currentDayKey)) {
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
    final weeklyDefinition = gameWeeklyQuestDefinitions[type];
    if (weeklyDefinition != null) {
      final weeklyCurrent = weeklyQuestProgress[type] ?? 0;
      weeklyQuestProgress[type] = math.min(
        weeklyDefinition.targetCount,
        weeklyCurrent + amount,
      );
    }
  }

  bool isDailyQuestComplete(DailyQuestType type) {
    return QuestRewardRules.isComplete(
      definition: gameDailyQuestDefinitions[type],
      progress: dailyQuestProgress[type] ?? 0,
    );
  }

  bool canClaimDailyQuestReward(DailyQuestType type, {required int nowMillis}) {
    refreshDailyQuests(nowMillis: nowMillis);
    return QuestRewardRules.canClaim(
      definition: gameDailyQuestDefinitions[type],
      progress: dailyQuestProgress[type] ?? 0,
      claimed: claimedDailyQuestRewards.contains(type),
      clockRollbackDetected: dailyQuestClockRollbackDetected,
    );
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

  bool applyDailyQuestRewardReceipt(
    DailyQuestType type, {
    required int dayKey,
  }) {
    if (dailyQuestDayKey != dayKey ||
        !QuestRewardRules.canClaim(
          definition: gameDailyQuestDefinitions[type],
          progress: dailyQuestProgress[type] ?? 0,
          claimed: claimedDailyQuestRewards.contains(type),
          clockRollbackDetected: dailyQuestClockRollbackDetected,
        )) {
      return false;
    }
    claimedDailyQuestRewards.add(type);
    return true;
  }

  bool canClaimDailyQuestAllCompleteReward({required int nowMillis}) {
    refreshDailyQuests(nowMillis: nowMillis);
    return QuestRewardRules.canClaimAllComplete(
      completedCount: completedDailyQuestCount,
      questCount: gameDailyQuestDefinitions.length,
      claimed: dailyQuestAllCompleteClaimed,
      clockRollbackDetected: dailyQuestClockRollbackDetected,
    );
  }

  bool claimDailyQuestAllCompleteReward({required int nowMillis}) {
    if (!canClaimDailyQuestAllCompleteReward(nowMillis: nowMillis)) {
      return false;
    }
    addFreeDiamonds(dailyQuestAllCompleteRewardDiamonds);
    dailyQuestAllCompleteClaimed = true;
    return true;
  }

  bool applyDailyQuestAllCompleteRewardReceipt({required int dayKey}) {
    if (dailyQuestDayKey != dayKey ||
        !QuestRewardRules.canClaimAllComplete(
          completedCount: completedDailyQuestCount,
          questCount: gameDailyQuestDefinitions.length,
          claimed: dailyQuestAllCompleteClaimed,
          clockRollbackDetected: dailyQuestClockRollbackDetected,
        )) {
      return false;
    }
    dailyQuestAllCompleteClaimed = true;
    return true;
  }

  bool claimDailyAttendanceReward({required int nowMillis}) {
    refreshDailyQuests(nowMillis: nowMillis);
    if (dailyQuestClockRollbackDetected || dailyAttendanceRewardClaimed) {
      return false;
    }
    addFreeDiamonds(dailyAttendanceRewardDiamonds);
    dailyAttendanceRewardClaimed = true;
    return true;
  }

  bool applyDailyAttendanceRewardReceipt({required int dayKey}) {
    if (dailyQuestDayKey != dayKey ||
        dailyQuestClockRollbackDetected ||
        dailyAttendanceRewardClaimed) {
      return false;
    }
    dailyAttendanceRewardClaimed = true;
    return true;
  }

  bool isWeeklyQuestComplete(DailyQuestType type) {
    return QuestRewardRules.isComplete(
      definition: gameWeeklyQuestDefinitions[type],
      progress: weeklyQuestProgress[type] ?? 0,
    );
  }

  bool canClaimWeeklyQuestReward(
    DailyQuestType type, {
    required int nowMillis,
  }) {
    refreshDailyQuests(nowMillis: nowMillis);
    return QuestRewardRules.canClaim(
      definition: gameWeeklyQuestDefinitions[type],
      progress: weeklyQuestProgress[type] ?? 0,
      claimed: claimedWeeklyQuestRewards.contains(type),
      clockRollbackDetected: dailyQuestClockRollbackDetected,
    );
  }

  bool applyWeeklyQuestRewardReceipt(
    DailyQuestType type, {
    required int weekKey,
    required int rewardDiamonds,
    bool grantEconomyRewardsLocally = true,
  }) {
    final definition = gameWeeklyQuestDefinitions[type];
    if (definition == null ||
        rewardDiamonds <= 0 ||
        weeklyQuestWeekKey != weekKey ||
        !QuestRewardRules.canClaim(
          definition: definition,
          progress: weeklyQuestProgress[type] ?? 0,
          claimed: claimedWeeklyQuestRewards.contains(type),
          clockRollbackDetected: dailyQuestClockRollbackDetected,
        )) {
      return false;
    }
    if (grantEconomyRewardsLocally) {
      addFreeDiamonds(rewardDiamonds);
    }
    claimedWeeklyQuestRewards.add(type);
    return true;
  }

  bool applyWeeklyQuestAllCompleteRewardReceipt({
    required int weekKey,
    required int rewardDiamonds,
    required int rewardModuleTickets,
    bool grantEconomyRewardsLocally = true,
  }) {
    if (rewardDiamonds <= 0 ||
        rewardModuleTickets < 0 ||
        weeklyQuestWeekKey != weekKey ||
        !QuestRewardRules.canClaimAllComplete(
          completedCount: completedWeeklyQuestCount,
          questCount: gameWeeklyQuestDefinitions.length,
          claimed: weeklyQuestAllCompleteClaimed,
          clockRollbackDetected: dailyQuestClockRollbackDetected,
        )) {
      return false;
    }
    if (grantEconomyRewardsLocally) {
      addFreeDiamonds(rewardDiamonds);
      turretModuleTickets += rewardModuleTickets;
    }
    weeklyQuestAllCompleteClaimed = true;
    return true;
  }

  bool applyWeeklyAttendanceRewardReceipt({
    required int weekKey,
    required int rewardDiamonds,
    bool grantEconomyRewardsLocally = true,
  }) {
    if (rewardDiamonds <= 0 ||
        weeklyQuestWeekKey != weekKey ||
        dailyQuestClockRollbackDetected ||
        weeklyAttendanceDayKeys.length < weeklyAttendanceTargetDays ||
        weeklyAttendanceRewardClaimed) {
      return false;
    }
    if (grantEconomyRewardsLocally) {
      addFreeDiamonds(rewardDiamonds);
    }
    weeklyAttendanceRewardClaimed = true;
    return true;
  }
}
