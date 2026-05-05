import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/turret/turret_type.dart';
import '../rune_nexus_game.dart';
import 'enemy_component.dart';
import 'turret_component.dart';

class ProjectileComponent extends PositionComponent {
  ProjectileComponent({
    required Vector2 origin,
    required Vector2 targetPosition,
    required this.owner,
    required this.game,
  }) : _direction = _safeDirection(origin, targetPosition),
       _maxDistance = owner.range + 64 * owner.game.boardDistanceScale,
       super(
         position: origin,
         size: Vector2.all(_visualSize(owner.definition.type)),
         anchor: Anchor.center,
       );

  final TurretComponent owner;
  final RuneNexusGame game;
  final Vector2 _direction;
  final double _maxDistance;
  double _travelled = 0;
  final List<Vector2> _trail = [];

  @override
  void update(double dt) {
    super.update(dt);
    final step = owner.projectileSpeed * dt;
    position += _direction * step;
    _travelled += step;
    _trail.insert(0, position.clone());
    if (_trail.length > 6) {
      _trail.removeRange(6, _trail.length);
    }

    final target = _findHitEnemy();
    if (target != null) {
      game.resolveProjectileHit(
        owner: owner,
        target: target,
        hitPosition: position.clone(),
      );
      removeFromParent();
      return;
    }

    if (_travelled >= _maxDistance) {
      removeFromParent();
    }
  }

  EnemyComponent? _findHitEnemy() {
    final hitRadius = _hitRadius;
    for (final enemy in game.enemies) {
      if (enemy.isMounted &&
          !enemy.isDead &&
          enemy.position.distanceTo(position) <= hitRadius) {
        return enemy;
      }
    }
    return null;
  }

  double get _hitRadius {
    return switch (owner.definition.type) {
      TurretType.arrow => 12,
      TurretType.cannon => 18,
      TurretType.magic => 13,
    };
  }

  @override
  void render(Canvas canvas) {
    final color = owner.definition.color;
    for (var i = 0; i < _trail.length; i++) {
      final point = _trail[i];
      final local = Offset(
        point.x - position.x + size.x / 2,
        point.y - position.y + size.y / 2,
      );
      final alpha = (0.28 * (1 - i / _trail.length)).clamp(0.0, 0.28);
      final radius = switch (owner.definition.type) {
        TurretType.arrow => 1.9 - i * 0.18,
        TurretType.cannon => 3.4 - i * 0.24,
        TurretType.magic => 2.8 - i * 0.2,
      };
      canvas.drawCircle(
        local,
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    final center = Offset(size.x / 2, size.y / 2);
    switch (owner.definition.type) {
      case TurretType.arrow:
        canvas.drawCircle(center, 2.4, Paint()..color = color);
        canvas.drawCircle(
          center,
          1.0,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      case TurretType.cannon:
        canvas.drawCircle(
          center,
          4.0,
          Paint()..color = const Color(0xFF2D1E18),
        );
        canvas.drawCircle(center, 2.8, Paint()..color = color);
      case TurretType.magic:
        final flame = Path()
          ..moveTo(center.dx + 1, center.dy - 4)
          ..quadraticBezierTo(
            center.dx + 5,
            center.dy,
            center.dx,
            center.dy + 4,
          )
          ..quadraticBezierTo(
            center.dx - 4,
            center.dy,
            center.dx + 1,
            center.dy - 4,
          )
          ..close();
        canvas.drawPath(flame, Paint()..color = color);
        canvas.drawCircle(
          center,
          1.4,
          Paint()..color = const Color(0xFFFFD45A),
        );
    }
  }

  static Vector2 _safeDirection(Vector2 origin, Vector2 target) {
    final direction = target - origin;
    if (direction.length2 == 0) {
      return Vector2(1, 0);
    }
    return direction.normalized();
  }

  static double _visualSize(TurretType type) {
    return switch (type) {
      TurretType.arrow => 8,
      TurretType.cannon => 12,
      TurretType.magic => 10,
    };
  }
}
