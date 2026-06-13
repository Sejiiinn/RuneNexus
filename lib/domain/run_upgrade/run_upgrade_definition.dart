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

  int costForLevel(int currentLevel, {int? maxLevel}) {
    final effectiveMaxLevel = maxLevel ?? this.maxLevel;
    if (currentLevel >= effectiveMaxLevel) {
      return 0;
    }
    return (baseCost * math.pow(costMultiplier, currentLevel)).round();
  }

  double effectForLevel(int currentLevel, {int? maxLevel}) {
    final effectiveMaxLevel = maxLevel ?? this.maxLevel;
    final level = currentLevel.clamp(0, effectiveMaxLevel).toInt();
    if (type != RunUpgradeType.waveGold) {
      return effectPerLevel * level;
    }

    var total = 0.0;
    for (var step = 1; step <= level; step++) {
      total += switch (step) {
        <= 5 => 4,
        <= 10 => 5,
        <= 15 => 6,
        _ => 7,
      };
    }
    return total;
  }
}
