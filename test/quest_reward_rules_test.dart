import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_daily_quest_data.dart';
import 'package:rune_nexus/data/definitions/game_weekly_quest_data.dart';
import 'package:rune_nexus/domain/daily_quest/daily_quest_type.dart';
import 'package:rune_nexus/domain/daily_quest/quest_reward_rules.dart';

void main() {
  test('daily and weekly claims use their own completion thresholds', () {
    for (final type in gameDailyQuestDefinitions.keys) {
      final daily = gameDailyQuestDefinitions[type]!;
      final weekly = gameWeeklyQuestDefinitions[type]!;
      expect(
        QuestRewardRules.canClaim(
          definition: daily,
          progress: daily.targetCount,
          claimed: false,
          clockRollbackDetected: false,
        ),
        isTrue,
      );
      expect(weekly.targetCount, greaterThan(daily.targetCount));
      expect(
        QuestRewardRules.canClaim(
          definition: weekly,
          progress: daily.targetCount,
          claimed: false,
          clockRollbackDetected: false,
        ),
        isFalse,
      );
    }
  });

  test('completed quests reject duplicate claims and clock rollback', () {
    final definition = gameDailyQuestDefinitions[DailyQuestType.clearWaves]!;
    for (final claimed in [false, true]) {
      for (final rollback in [false, true]) {
        expect(
          QuestRewardRules.canClaim(
            definition: definition,
            progress: definition.targetCount + 1,
            claimed: claimed,
            clockRollbackDetected: rollback,
          ),
          !claimed && !rollback,
        );
        expect(
          QuestRewardRules.canClaimAllComplete(
            completedCount: gameDailyQuestDefinitions.length,
            questCount: gameDailyQuestDefinitions.length,
            claimed: claimed,
            clockRollbackDetected: rollback,
          ),
          !claimed && !rollback,
        );
      }
    }
  });

  test(
    'missing or incomplete quests cannot grant individual or total reward',
    () {
      final definition = gameDailyQuestDefinitions[DailyQuestType.clearWaves]!;
      for (final candidate in [null, definition]) {
        expect(
          QuestRewardRules.canClaim(
            definition: candidate,
            progress: definition.targetCount - 1,
            claimed: false,
            clockRollbackDetected: false,
          ),
          isFalse,
        );
      }
      expect(
        QuestRewardRules.canClaimAllComplete(
          completedCount: gameDailyQuestDefinitions.length - 1,
          questCount: gameDailyQuestDefinitions.length,
          claimed: false,
          clockRollbackDetected: false,
        ),
        isFalse,
      );
    },
  );
}
