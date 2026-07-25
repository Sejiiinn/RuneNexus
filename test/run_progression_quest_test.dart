import 'helpers/game_balance_test_helpers.dart';

void main() {
  test('daily quests grant free diamonds once and persist state', () {
    const nowMillis = 1780675200000;
    final progression = RunProgression();

    progression.recordDailyQuestProgress(
      DailyQuestType.clearWaves,
      amount: 30,
      nowMillis: nowMillis,
    );

    expect(
      progression.claimDailyQuestReward(
        DailyQuestType.clearWaves,
        nowMillis: nowMillis,
      ),
      isTrue,
    );
    expect(
      progression.claimDailyQuestReward(
        DailyQuestType.clearWaves,
        nowMillis: nowMillis,
      ),
      isFalse,
    );
    expect(progression.freeDiamonds, 10);
    expect(progression.paidDiamonds, 0);

    final saved = SavedProgression.fromJson(progression.toSaveData().toJson());
    final restored = RunProgression()..restoreFromSaveData(saved);

    expect(restored.dailyQuestDayKey, progression.dailyQuestDayKey);
    expect(restored.dailyQuestProgress[DailyQuestType.clearWaves], 30);
    expect(
      restored.claimedDailyQuestRewards,
      contains(DailyQuestType.clearWaves),
    );
    expect(restored.freeDiamonds, 10);
  });

  test('daily all complete reward grants twenty free diamonds once', () {
    const nowMillis = 1780675200000;
    final progression = RunProgression();

    for (final entry in gameDailyQuestDefinitions.entries) {
      progression.recordDailyQuestProgress(
        entry.key,
        amount: entry.value.targetCount,
        nowMillis: nowMillis,
      );
    }

    expect(progression.completedDailyQuestCount, 4);
    expect(
      progression.claimDailyQuestAllCompleteReward(nowMillis: nowMillis),
      isTrue,
    );
    expect(
      progression.claimDailyQuestAllCompleteReward(nowMillis: nowMillis),
      isFalse,
    );
    expect(progression.freeDiamonds, 20);
  });

  test('daily attendance grants ten free diamonds once and resets', () {
    final firstDay = DateTime.utc(2026, 6, 8).millisecondsSinceEpoch;
    final nextDay = DateTime.utc(2026, 6, 9).millisecondsSinceEpoch;
    final progression = RunProgression();

    expect(progression.claimDailyAttendanceReward(nowMillis: firstDay), isTrue);
    expect(
      progression.claimDailyAttendanceReward(nowMillis: firstDay),
      isFalse,
    );
    expect(progression.freeDiamonds, dailyAttendanceRewardDiamonds);

    final saved = SavedProgression.fromJson(progression.toSaveData().toJson());
    final restored = RunProgression()..restoreFromSaveData(saved);
    expect(restored.dailyAttendanceRewardClaimed, isTrue);
    expect(restored.claimDailyAttendanceReward(nowMillis: nextDay), isTrue);
    expect(restored.freeDiamonds, dailyAttendanceRewardDiamonds * 2);
  });

  test('weekly quests grant configured rewards once and persist state', () {
    final nowMillis = DateTime.utc(2026, 6, 8).millisecondsSinceEpoch;
    final progression = RunProgression();

    for (final entry in gameWeeklyQuestDefinitions.entries) {
      progression.recordDailyQuestProgress(
        entry.key,
        amount: entry.value.targetCount,
        nowMillis: nowMillis,
      );
      expect(
        progression.claimWeeklyQuestReward(entry.key, nowMillis: nowMillis),
        isTrue,
      );
      expect(
        progression.claimWeeklyQuestReward(entry.key, nowMillis: nowMillis),
        isFalse,
      );
    }

    expect(progression.completedWeeklyQuestCount, 4);
    expect(
      progression.claimWeeklyQuestAllCompleteReward(nowMillis: nowMillis),
      isTrue,
    );
    expect(
      progression.claimWeeklyQuestAllCompleteReward(nowMillis: nowMillis),
      isFalse,
    );
    expect(progression.freeDiamonds, 140);
    expect(progression.turretModuleTickets, 1);

    final saved = SavedProgression.fromJson(progression.toSaveData().toJson());
    final restored = RunProgression()..restoreFromSaveData(saved);
    expect(restored.weeklyQuestProgress, progression.weeklyQuestProgress);
    expect(
      restored.claimedWeeklyQuestRewards,
      progression.claimedWeeklyQuestRewards,
    );
    expect(restored.weeklyQuestAllCompleteClaimed, isTrue);
    expect(restored.freeDiamonds, 140);
    expect(restored.turretModuleTickets, 1);
  });

  test('weekly attendance counts distinct days and resets on Monday', () {
    final beforeWeeklyReset = DateTime.utc(
      2026,
      6,
      7,
      19,
      59,
    ).millisecondsSinceEpoch;
    final afterWeeklyReset = DateTime.utc(
      2026,
      6,
      7,
      20,
    ).millisecondsSinceEpoch;
    expect(
      RunProgression.weeklyQuestWeekKeyFor(beforeWeeklyReset),
      isNot(RunProgression.weeklyQuestWeekKeyFor(afterWeeklyReset)),
    );

    final monday = DateTime.utc(2026, 6, 8).millisecondsSinceEpoch;
    final progression = RunProgression();

    for (var day = 0; day < weeklyAttendanceTargetDays; day++) {
      final nowMillis = monday + day * const Duration(days: 1).inMilliseconds;
      progression.refreshDailyQuests(nowMillis: nowMillis);
      progression.refreshDailyQuests(nowMillis: nowMillis);
    }

    expect(progression.weeklyAttendanceDayKeys.length, 5);
    expect(
      progression.claimWeeklyAttendanceReward(
        nowMillis:
            monday +
            (weeklyAttendanceTargetDays - 1) *
                const Duration(days: 1).inMilliseconds,
      ),
      isTrue,
    );
    expect(
      progression.claimWeeklyAttendanceReward(
        nowMillis:
            monday +
            (weeklyAttendanceTargetDays - 1) *
                const Duration(days: 1).inMilliseconds,
      ),
      isFalse,
    );
    expect(progression.freeDiamonds, weeklyAttendanceRewardDiamonds);

    progression.refreshDailyQuests(
      nowMillis: monday + const Duration(days: 7).inMilliseconds,
    );
    expect(progression.weeklyAttendanceDayKeys.length, 1);
    expect(progression.weeklyAttendanceRewardClaimed, isFalse);
    expect(progression.weeklyQuestProgress, isEmpty);
  });

  test('daily quests reset at KST five and block clock rollback claims', () {
    final beforeReset = DateTime.utc(2026, 6, 5, 19, 59).millisecondsSinceEpoch;
    final afterReset = DateTime.utc(2026, 6, 5, 20).millisecondsSinceEpoch;
    final progression = RunProgression();

    progression.recordDailyQuestProgress(
      DailyQuestType.killEnemies,
      amount: 100,
      nowMillis: beforeReset,
    );
    final previousDayKey = progression.dailyQuestDayKey;

    expect(progression.refreshDailyQuests(nowMillis: afterReset), isTrue);
    expect(progression.dailyQuestDayKey, isNot(previousDayKey));
    expect(progression.dailyQuestProgress, isEmpty);
    expect(progression.dailyQuestClockRollbackDetected, isFalse);

    progression.refreshDailyQuests(nowMillis: afterReset + 3600000);
    progression.recordDailyQuestProgress(
      DailyQuestType.killEnemies,
      amount: 100,
      nowMillis: afterReset,
    );

    expect(progression.dailyQuestClockRollbackDetected, isTrue);
    expect(
      progression.claimDailyQuestReward(
        DailyQuestType.killEnemies,
        nowMillis: afterReset,
      ),
      isFalse,
    );
    expect(progression.freeDiamonds, 0);
  });

  test('daily quests track wave, boss, enemy, and run upgrades', () async {
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.buyRunUpgrade(RunUpgradeType.towerDamage);
    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType
          .buyRunUpgrades],
      1,
    );

    final normal = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(normal);
    normal.receiveDamage(999);

    final boss = EnemyComponent(
      definition: gameEnemies[EnemyType.boss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(boss);
    boss.receiveDamage(999);

    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType
          .killEnemies],
      2,
    );
    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType.killBosses],
      1,
    );

    game.startNextWave();
    game.update(0.016);

    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType.clearWaves],
      1,
    );
    expect(
      game.snapshotNotifier.value.weeklyQuestProgress[DailyQuestType
          .buyRunUpgrades],
      1,
    );
    expect(
      game.snapshotNotifier.value.weeklyQuestProgress[DailyQuestType
          .killEnemies],
      2,
    );
    expect(
      game.snapshotNotifier.value.weeklyQuestProgress[DailyQuestType
          .killBosses],
      1,
    );
    expect(
      game.snapshotNotifier.value.weeklyQuestProgress[DailyQuestType
          .clearWaves],
      1,
    );
  });
}
