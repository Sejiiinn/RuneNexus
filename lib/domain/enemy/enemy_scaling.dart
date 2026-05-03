import 'enemy_definition.dart';
import 'dart:math' as math;

double enemyHpMultiplierForRound(int round) {
  return math.pow(2, ((round - 1).clamp(0, 49)) / 10).toDouble();
}

double scaledEnemyMaxHp(EnemyDefinition definition, int round) {
  return definition.maxHp * enemyHpMultiplierForRound(round);
}
