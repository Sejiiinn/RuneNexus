import 'enemy_definition.dart';
import 'dart:math' as math;

double enemyHpMultiplierForRound(int round) {
  return math.pow(2, ((round - 1).clamp(0, 49)) / 10).toDouble();
}

double enemyHpMultiplierForStage(int stageNumber) {
  return math.pow(1.3, (stageNumber - 1).clamp(0, 4)).toDouble();
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
