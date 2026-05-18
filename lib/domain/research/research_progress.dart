import 'research_type.dart';

class ResearchProgress {
  const ResearchProgress({
    required this.type,
    required this.targetLevel,
    required this.startedAtMillis,
    required this.durationMillis,
  });

  final ResearchType type;
  final int targetLevel;
  final int startedAtMillis;
  final int durationMillis;

  int get finishesAtMillis => startedAtMillis + durationMillis;

  bool isCompleteAt(int nowMillis) {
    return nowMillis >= finishesAtMillis;
  }

  int remainingMillisAt(int nowMillis) {
    return (finishesAtMillis - nowMillis).clamp(0, durationMillis).toInt();
  }
}
