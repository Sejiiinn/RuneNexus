import 'enemy_definition.dart';
import 'dart:math' as math;

const double stageEnemyDurabilityGrowth = 1.20;

double enemyHpMultiplierForRound(int round) {
  return math.pow(2, ((round - 1).clamp(0, 49)) / 10).toDouble();
}

double enemyHpMultiplierForStage(int stageNumber) {
  return math
      .pow(stageEnemyDurabilityGrowth, (stageNumber - 1).clamp(0, 14))
      .toDouble();
}

double scaledEnemyMaxHp(
  EnemyDefinition definition,
  int round, {
  int stageNumber = 1,
}) {
  return definition.maxHp *
      enemyHpMultiplierForRound(round) *
      enemyHpMultiplierForStage(stageNumber);
}

double scaledEnemyMaxShield(
  EnemyDefinition definition,
  int round, {
  int stageNumber = 1,
}) {
  return definition.maxShield *
      enemyHpMultiplierForRound(round) *
      enemyHpMultiplierForStage(stageNumber);
}

double scaledEnemyMaxArmor(
  EnemyDefinition definition,
  int round, {
  int stageNumber = 1,
}) {
  return definition.maxArmor *
      enemyHpMultiplierForRound(round) *
      enemyHpMultiplierForStage(stageNumber);
}
