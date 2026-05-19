import 'research_type.dart';

class ResearchProgress {
  const ResearchProgress({
    required this.type,
    required this.targetLevel,
    required this.startedAtMillis,
    required this.durationMillis,
    this.initialElapsedMillis = 0,
  });

  final ResearchType type;
  final int targetLevel;
  final int startedAtMillis;
  final int durationMillis;
  final int initialElapsedMillis;

  int get finishesAtMillis => startedAtMillis + durationMillis;
  int get totalDurationMillis => initialElapsedMillis + durationMillis;

  bool isCompleteAt(int nowMillis) {
    return nowMillis >= finishesAtMillis;
  }

  int remainingMillisAt(int nowMillis) {
    return (finishesAtMillis - nowMillis).clamp(0, durationMillis).toInt();
  }

  double progressRatioAt(int nowMillis) {
    if (totalDurationMillis <= 0) {
      return 0;
    }
    final elapsedThisRun = durationMillis - remainingMillisAt(nowMillis);
    return ((initialElapsedMillis + elapsedThisRun) / totalDurationMillis)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}
