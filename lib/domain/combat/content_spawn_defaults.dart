import '../enemy/enemy_type.dart';

/// Shared source for Dart gameplay and the generated standalone content catalog.
const double portalAlertDuration = 0.55;
const double postPortalAlertSpawnDelay = 0.15;

double enemyLaneOffsetAmplitude(EnemyType type) => switch (type) {
  EnemyType.fast => 0.18,
  EnemyType.boss => 0.055,
  EnemyType.shieldBoss => 0.055,
  EnemyType.forgeBoss => 0.045,
  EnemyType.tank => 0.12,
  _ => 0.14,
};

double enemyLaneOffsetForRoll(EnemyType type, double roll) =>
    (roll * 2 - 1) * enemyLaneOffsetAmplitude(type);
