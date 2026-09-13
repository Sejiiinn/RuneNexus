import 'dart:ui';

/// 전투·저장 객체를 소유하지 않는 객체 부착 표시 스냅샷.
class BattlefieldLabels {
  BattlefieldLabels({
    required this.logicalTileSize,
    required List<BattlefieldEnemyLabel> enemies,
    this.core,
  }) : enemies = List.unmodifiable(enemies);

  final double logicalTileSize;
  final List<BattlefieldEnemyLabel> enemies;
  final BattlefieldCoreLabel? core;

  Map<String, Object?> toJson() => {
    'logicalTileSize': logicalTileSize,
    'enemies': [for (final enemy in enemies) enemy.toJson()],
    'core': core?.toJson(),
  };
}

class BattlefieldEnemyLabel {
  const BattlefieldEnemyLabel({
    required this.id,
    required this.position,
    required this.size,
    required this.hp,
    required this.maxHp,
    required this.armor,
    required this.maxArmor,
    required this.shield,
    required this.maxShield,
    required this.effectTime,
    required this.enemyCount,
    required this.burning,
    required this.slowed,
    required this.poisoned,
    required this.riftMarked,
    required this.diamondCarrier,
  });

  final int id;
  final Offset position;

  /// 기존 EnemyRenderer의 논리 픽셀 크기. tileSize와 함께 스케일한다.
  final Size size;
  final double hp, maxHp, armor, maxArmor, shield, maxShield, effectTime;
  final int enemyCount;
  final bool burning, slowed, poisoned, riftMarked, diamondCarrier;

  Map<String, Object?> toJson() => {
    'id': id,
    'position': [position.dx, position.dy],
    'size': [size.width, size.height],
    'hp': hp,
    'maxHp': maxHp,
    'armor': armor,
    'maxArmor': maxArmor,
    'shield': shield,
    'maxShield': maxShield,
    'effectTime': effectTime,
    'enemyCount': enemyCount,
    'burning': burning,
    'slowed': slowed,
    'poisoned': poisoned,
    'riftMarked': riftMarked,
    'diamondCarrier': diamondCarrier,
  };
}

class BattlefieldCoreLabel {
  const BattlefieldCoreLabel({
    required this.position,
    required this.progress,
    required this.accent,
    required this.active,
  });
  final Offset position;
  final double progress;
  final Color accent;
  final bool active;

  Map<String, Object?> toJson() => {
    'position': [position.dx, position.dy],
    'progress': progress,
    'accent': accent.toARGB32(),
    'active': active,
  };
}
