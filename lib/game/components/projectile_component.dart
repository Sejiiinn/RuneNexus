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
         size: Vector2.all(
           _visualSize(owner.definition.type) * owner.game.boardDistanceScale,
         ),
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
    if (_trail.length > 9) {
      _trail.removeRange(9, _trail.length);
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
    final projectileRadius = _hitRadius;
    for (final enemy in game.enemies) {
      final dx = enemy.position.x - position.x;
      final dy = enemy.position.y - position.y;
      final hitRadius = projectileRadius + enemy.collisionRadius;
      if (enemy.isMounted &&
          !enemy.isDead &&
          dx * dx + dy * dy <= hitRadius * hitRadius) {
        return enemy;
      }
    }
    return null;
  }

  double get _hitRadius {
    final baseRadius = switch (owner.definition.type) {
      TurretType.arrow => 3.5,
      TurretType.cannon => 7,
      TurretType.magic => 4,
      TurretType.frost => 5,
      TurretType.sniper => 3.5,
    };
    return baseRadius * owner.game.boardDistanceScale;
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
      final alpha = (0.46 * (1 - i / _trail.length)).clamp(0.0, 0.46);
      final radius = switch (owner.definition.type) {
        TurretType.arrow => 2.2 - i * 0.16,
        TurretType.cannon => 4.2 - i * 0.22,
        TurretType.magic => 3.5 - i * 0.18,
        TurretType.frost => 3.0 - i * 0.16,
        TurretType.sniper => 2.2 - i * 0.16,
      };
      if (owner.definition.type == TurretType.arrow && i < _trail.length - 1) {
        final next = _trail[i + 1];
        final nextLocal = Offset(
          next.x - position.x + size.x / 2,
          next.y - position.y + size.y / 2,
        );
        canvas.drawLine(
          local,
          nextLocal,
          Paint()
            ..color = color.withValues(alpha: alpha * 0.86)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
      if (owner.definition.type == TurretType.magic) {
        canvas.drawCircle(
          local,
          radius * 2.4,
          Paint()..color = color.withValues(alpha: alpha * 0.16),
        );
      }
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
          center.translate(-2, 1),
          6.0,
          Paint()..color = color.withValues(alpha: 0.18),
        );
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
      case TurretType.frost:
        canvas.drawCircle(
          center,
          3.6,
          Paint()..color = color.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          center,
          1.5,
          Paint()..color = const Color(0xFFE8FBFF),
        );
      case TurretType.sniper:
        canvas.drawCircle(center, 2.4, Paint()..color = color);
        canvas.drawCircle(
          center,
          1.0,
          Paint()..color = const Color(0xFFFFFFFF),
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
      TurretType.frost => 10,
      TurretType.sniper => 8,
    };
  }
}
