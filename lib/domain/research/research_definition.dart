import 'dart:math' as math;

import 'research_type.dart';

class ResearchDefinition {
  const ResearchDefinition({
    required this.type,
    required this.maxLevel,
    required this.requiredClearedStage,
    required this.baseRuneCost,
    required this.costMultiplier,
    required this.durationMillis,
    required this.durationMultiplier,
  });

  final ResearchType type;
  final int maxLevel;
  final int requiredClearedStage;
  final int baseRuneCost;
  final double costMultiplier;
  final int durationMillis;
  final double durationMultiplier;

  int costForCurrentLevel(int currentLevel) {
    return (baseRuneCost * math.pow(costMultiplier, currentLevel)).round();
  }

  int durationForCurrentLevel(int currentLevel) {
    return (durationMillis * math.pow(durationMultiplier, currentLevel))
        .round();
  }
}
