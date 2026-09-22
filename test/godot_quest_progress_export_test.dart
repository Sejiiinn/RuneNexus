import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';
import 'package:rune_nexus/domain/daily_quest/daily_quest_type.dart';
import 'package:rune_nexus/domain/research/research_type.dart';

void main() {
  test('Godot quest and settlement fixtures match Dart progression', () {
    final cases = <Map<String, Object?>>[];
    final p = RunProgression();
    void capture(
      String name,
      Map<String, Object?> action,
      void Function() run,
    ) {
      final before = {
        ...p.toSaveData().toJson(),
        'turretModules': p.toTurretModuleSaveData().toJson(),
      };
      run();
      cases.add({
        'name': name,
        'action': action,
        'before': before,
        'after': {
          ...p.toSaveData().toJson(),
          'turretModules': p.toTurretModuleSaveData().toJson(),
        },
      });
    }

    var now = DateTime.utc(2026, 9, 20, 19, 59).millisecondsSinceEpoch;
    void refresh(String name, int time) => capture(name, {
      'kind': 'refresh',
      'now': time,
    }, () => p.refreshDailyQuests(nowMillis: time));
    void record(String name, DailyQuestType type, int amount) => capture(name, {
      'kind': 'record',
      'type': type.name,
      'amount': amount,
      'now': now,
    }, () => p.recordDailyQuestProgress(type, amount: amount, nowMillis: now));
    refresh('Sunday before KST 05:00', now);
    for (final type in DailyQuestType.values) {
      record('cap ${type.name}', type, 1000);
    }
    record('zero ignored', DailyQuestType.killEnemies, 0);
    record('negative ignored', DailyQuestType.killEnemies, -5);
    now += 60000;
    refresh('Monday daily and weekly reset', now);
    record('enemy', DailyQuestType.killEnemies, 1);
    now += 600000;
    refresh('checkpoint', now);
    refresh('same-day rollback', now - 360000);
    refresh('rollback remains after recovery', now + 60000);
    now += 86400000;
    refresh('next-day clears rollback', now);
    for (var i = 0; i < 6; i++) {
      now += 86400000;
      refresh('attendance day $i', now);
    }
    for (final delta in [0.0004, 0.0004, 0.0004, 1.23, 0.0, -1.0]) {
      capture('play time $delta', {
        'kind': 'playTime',
        'seconds': delta,
      }, () => p.recordPlayTime(delta));
    }
    p.researchLevels[ResearchType.runeResonance] = 4;
    for (final input in [
      [1, 7, false, 3, 2, false],
      [1, 40, true, 3, 2, false],
      [1, 40, true, 3, 2, false],
      [2, 0, false, 0, 0, false],
      [2, 40, true, 0, 2, true],
      [15, 60, true, 5, 4, false],
      [0, 2, true, 3, 2, false],
      [3, 40, true, -1, -1, false],
      [3, 40, true, 3, 2, false],
    ]) {
      final event = {
        'stageNumber': input[0],
        'completedRounds': input[1],
        'success': input[2],
        'firstClearCorePointReward': input[3],
        'firstClearTurretModuleTicketReward': input[4],
        'grantEconomyRewardsLocally': input[5],
      };
      capture(
        'finish ${cases.length}',
        {'kind': 'finish', 'event': event},
        () => p.finishRun(
          stageNumber: input[0] as int,
          completedRounds: input[1] as int,
          success: input[2] as bool,
          firstClearCorePointReward: input[3] as int,
          firstClearTurretModuleTicketReward: input[4] as int,
          grantEconomyRewardsLocally: input[5] as bool,
        ),
      );
    }
    for (final type in DailyQuestType.values) {
      record('complete for receipts ${type.name}', type, 1000);
    }
    void receipt(String name, Map<String, Object?> r, bool Function() apply) {
      capture(name, {'kind': 'receipt', 'receipt': r}, () {
        apply();
      });
    }

    for (var i = 0; i < 2; i++) {
      for (final type in DailyQuestType.values) {
        receipt(
          'daily quest receipt $i ${type.name}',
          {
            'period': 'daily',
            'rewardType': 'quest',
            'questType': type.name,
            'dayKey': p.dailyQuestDayKey,
          },
          () =>
              p.applyDailyQuestRewardReceipt(type, dayKey: p.dailyQuestDayKey),
        );
        receipt(
          'weekly quest receipt $i ${type.name}',
          {
            'period': 'weekly',
            'rewardType': 'quest',
            'questType': type.name,
            'weekKey': p.weeklyQuestWeekKey,
            'rewardDiamonds': 40,
          },
          () => p.applyWeeklyQuestRewardReceipt(
            type,
            weekKey: p.weeklyQuestWeekKey,
            rewardDiamonds: 40,
            grantEconomyRewardsLocally: false,
          ),
        );
      }
      receipt(
        'daily all receipt $i',
        {
          'period': 'daily',
          'rewardType': 'all_complete',
          'dayKey': p.dailyQuestDayKey,
        },
        () => p.applyDailyQuestAllCompleteRewardReceipt(
          dayKey: p.dailyQuestDayKey,
        ),
      );
      receipt('daily attendance receipt $i', {
        'period': 'daily',
        'rewardType': 'attendance',
        'dayKey': p.dailyQuestDayKey,
      }, () => p.applyDailyAttendanceRewardReceipt(dayKey: p.dailyQuestDayKey));
      receipt(
        'weekly all receipt $i',
        {
          'period': 'weekly',
          'rewardType': 'all_complete',
          'weekKey': p.weeklyQuestWeekKey,
          'rewardDiamonds': 100,
          'rewardModuleTickets': 4,
        },
        () => p.applyWeeklyQuestAllCompleteRewardReceipt(
          weekKey: p.weeklyQuestWeekKey,
          rewardDiamonds: 100,
          rewardModuleTickets: 4,
          grantEconomyRewardsLocally: false,
        ),
      );
      receipt(
        'weekly attendance insufficient $i',
        {
          'period': 'weekly',
          'rewardType': 'attendance',
          'weekKey': p.weeklyQuestWeekKey,
          'rewardDiamonds': 40,
        },
        () => p.applyWeeklyAttendanceRewardReceipt(
          weekKey: p.weeklyQuestWeekKey,
          rewardDiamonds: 40,
          grantEconomyRewardsLocally: false,
        ),
      );
    }
    final encoded =
        '${const JsonEncoder.withIndent('  ').convert({'cases': cases})}\n';
    final file = File('test/fixtures/quest_progress_cases.json');
    if (Platform.environment['UPDATE_GODOT_QUEST'] == '1') {
      file.writeAsStringSync(encoded);
    }
    expect(file.readAsStringSync(), encoded);
  });
}
