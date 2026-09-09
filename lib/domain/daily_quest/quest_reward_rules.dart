import 'daily_quest_definition.dart';

/// 날짜 갱신·서버 영수증 검증과 분리한 현재 임무 상태의 순수 판정.
abstract final class QuestRewardRules {
  static bool isComplete({
    required DailyQuestDefinition? definition,
    required int progress,
  }) => definition != null && progress >= definition.targetCount;

  static bool canClaim({
    required DailyQuestDefinition? definition,
    required int progress,
    required bool claimed,
    required bool clockRollbackDetected,
  }) =>
      !clockRollbackDetected &&
      !claimed &&
      isComplete(definition: definition, progress: progress);

  static bool canClaimAllComplete({
    required int completedCount,
    required int questCount,
    required bool claimed,
    required bool clockRollbackDetected,
  }) => !clockRollbackDetected && !claimed && completedCount == questCount;
}
