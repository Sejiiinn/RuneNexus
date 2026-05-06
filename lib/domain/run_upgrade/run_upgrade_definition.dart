import 'dart:math' as math;

import 'run_upgrade_type.dart';

class RunUpgradeDefinition {
  const RunUpgradeDefinition({
    required this.type,
    required this.name,
    required this.description,
    required this.effectLabel,
    required this.maxLevel,
    required this.baseCost,
    required this.costMultiplier,
    required this.effectPerLevel,
  });

  final RunUpgradeType type;
  final String name;
  final String description;
  final String effectLabel;
  final int maxLevel;
  final int baseCost;
  final double costMultiplier;
  final double effectPerLevel;

  int costForLevel(int currentLevel) {
    if (currentLevel >= maxLevel) {
      return 0;
    }
    return (baseCost * math.pow(costMultiplier, currentLevel)).round();
  }
}
