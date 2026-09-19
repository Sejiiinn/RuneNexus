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
    this.runeCosts,
    this.legacyCostLevelsPerRank = 1,
  });

  final List<int>? runeCosts;
  final int legacyCostLevelsPerRank;
  final ResearchType type;
  final int maxLevel;
  final int requiredClearedStage;
  final int baseRuneCost;
  final double costMultiplier;
  final int durationMillis;
  final double durationMultiplier;

  int costForCurrentLevel(int currentLevel) {
    if (runeCosts != null) {
      return runeCosts![currentLevel.clamp(0, runeCosts!.length - 1)];
    }
    var cost = 0;
    for (var offset = 0; offset < legacyCostLevelsPerRank; offset++) {
      cost +=
          (baseRuneCost *
                  math.pow(
                    costMultiplier,
                    currentLevel * legacyCostLevelsPerRank + offset,
                  ))
              .round();
    }
    return cost;
  }

  int durationForCurrentLevel(int currentLevel) {
    return (durationMillis * math.pow(durationMultiplier, currentLevel))
        .round();
  }
}
