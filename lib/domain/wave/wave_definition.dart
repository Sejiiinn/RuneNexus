import '../enemy/enemy_type.dart';

class WaveDefinition {
  const WaveDefinition({
    required this.round,
    required this.previewText,
    required this.groups,
    required this.clearRewardGold,
  });

  final int round;
  final String previewText;
  final List<SpawnGroup> groups;
  final int clearRewardGold;
}

class SpawnGroup {
  const SpawnGroup({
    required this.enemyType,
    required this.count,
    required this.interval,
    this.startDelay = 0,
    this.startAfterPrevious = false,
    this.followDelay = 0.7,
  });

  final EnemyType enemyType;
  final int count;
  final double interval;
  final double startDelay;
  final bool startAfterPrevious;
  final double followDelay;
}
