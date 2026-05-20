import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/enemy/enemy_type.dart';

class DeathBurstEffectComponent extends PositionComponent {
  DeathBurstEffectComponent({
    required Vector2 position,
    required Color color,
    required EnemyType type,
    required double radius,
  }) : _color = color,
       _type = type,
       _radius = radius,
       super(
         position: position,
         size: Vector2.all(radius * 4),
         anchor: Anchor.center,
       );

  final Color _color;
  final EnemyType _type;
  final double _radius;
  double _age = 0;

  double get _lifeTime => switch (_type) {
    EnemyType.boss => 0.46,
    EnemyType.tank => 0.36,
    EnemyType.shielded => 0.32,
    EnemyType.normal || EnemyType.armored || EnemyType.fast => 0.28,
  };

  int get _shardCount => switch (_type) {
    EnemyType.boss => 10,
    EnemyType.tank => 7,
    EnemyType.fast => 6,
    EnemyType.shielded => 6,
    EnemyType.armored => 6,
    EnemyType.normal => 5,
  };

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _lifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / _lifeTime).clamp(0.0, 1.0);
    final alpha = 1 - progress;
    final center = Offset(size.x / 2, size.y / 2);
    final ringRadius = _radius * (0.38 + progress * 1.45);
    final ringPaint = Paint()
      ..color = _color.withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _type == EnemyType.tank ? 2.6 : 2.0;

    canvas.drawCircle(center, ringRadius, ringPaint);
    if (_type == EnemyType.boss) {
      canvas.drawCircle(
        center,
        _radius * (0.18 + progress * 1.9),
        Paint()
          ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    final shardPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _shardCount; i++) {
      final angle = i * math.pi * 2 / _shardCount;
      final fastBias = _type == EnemyType.fast
          ? math.cos(angle).abs() * 0.35
          : 0;
      final distance = _radius * (0.32 + progress * (1.45 + fastBias));
      final shardCenter = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final shardRadius =
          _radius *
          switch (_type) {
            EnemyType.tank => 0.14,
            EnemyType.boss => 0.12,
            EnemyType.fast => 0.08,
            EnemyType.shielded => 0.1,
            EnemyType.armored => 0.1,
            EnemyType.normal => 0.1,
          } *
          (1 - progress * 0.35);
      shardPaint.color = (i.isEven ? _color : const Color(0xFFE8FBFF))
          .withValues(alpha: alpha * 0.82);
      canvas.drawCircle(shardCenter, shardRadius, shardPaint);
    }
  }
}
