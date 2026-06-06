import 'daily_quest_type.dart';

class DailyQuestDefinition {
  const DailyQuestDefinition({
    required this.type,
    required this.title,
    required this.targetCount,
    required this.rewardDiamonds,
  });

  final DailyQuestType type;
  final String title;
  final int targetCount;
  final int rewardDiamonds;
}
