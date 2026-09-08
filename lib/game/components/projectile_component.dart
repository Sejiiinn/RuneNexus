import 'dart:math' as math;
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
    required this.attack,
    required this.game,
    int? remainingChainCount,
    Set<EnemyComponent> directHitEnemies = const {},
    this.isChain = false,
    double? maxDistance,
  }) : remainingChainCount = remainingChainCount ?? attack.chainCount,
       directHitEnemies = {...directHitEnemies},
       _direction = _safeDirection(origin, targetPosition),
       _maxDistance =
           maxDistance ?? attack.range + 64 * game.boardDistanceScale,
       super(
         position: origin,
         size: Vector2.all(
           _visualSize(owner.definition.type) * owner.game.boardDistanceScale,
         ),
         anchor: Anchor.center,
       );

  final TurretComponent owner;
  final TurretAttackSnapshot attack;
  final RuneNexusGame game;
  final int remainingChainCount;
  final Set<EnemyComponent> directHitEnemies;
  final bool isChain;
  final Vector2 _direction;
  final double _maxDistance;
  double _travelled = 0;
  final List<Vector2> _trail = [];

  @override
  void update(double dt) {
    super.update(dt);
    final step = math.min(
      math.max(0.0, attack.projectileSpeed * dt),
      math.max(0.0, _maxDistance - _travelled),
    );
    final origin = position.clone();
    final destination = origin + _direction * step;
    final hit = _findHitEnemy(origin, destination);
    position = hit == null
        ? destination
        : origin + (destination - origin) * hit.fraction;
    _travelled += step;
    _trail.insert(0, position.clone());
    if (_trail.length > 9) {
      _trail.removeRange(9, _trail.length);
    }

    if (hit != null) {
      directHitEnemies.add(hit.enemy);
      game.resolveProjectileHit(
        owner: owner,
        attack: attack,
        target: hit.enemy,
        hitPosition: position.clone(),
        remainingChainCount: remainingChainCount,
        directHitEnemies: directHitEnemies,
        isChain: isChain,
      );
      removeFromParent();
      return;
    }

    if (_travelled >= _maxDistance) {
      removeFromParent();
    }
  }

  ({EnemyComponent enemy, double fraction})? _findHitEnemy(
    Vector2 origin,
    Vector2 destination,
  ) {
    final movement = destination - origin;
    final lengthSquared = movement.length2;
    EnemyComponent? closest;
    var closestFraction = double.infinity;
    for (final enemy in game.enemies) {
      if (enemy.isDead || directHitEnemies.contains(enemy)) {
        continue;
      }
      final offset = origin - enemy.position;
      final hitRadius = _hitRadius + enemy.collisionRadius;
      final c = offset.length2 - hitRadius * hitRadius;
      double fraction;
      if (c <= 0) {
        fraction = 0;
      } else {
        if (lengthSquared == 0) continue;
        // 이동 선분과 충돌 원의 최초 교점
        final b = offset.dot(movement);
        final discriminant = b * b - lengthSquared * c;
        if (discriminant < 0) continue;
        fraction = (-b - math.sqrt(discriminant)) / lengthSquared;
        if (fraction < 0 || fraction > 1) continue;
      }
      if (fraction < closestFraction) {
        closest = enemy;
        closestFraction = fraction;
      }
    }
    return closest == null ? null : (enemy: closest, fraction: closestFraction);
  }

  double get _hitRadius {
    final baseRadius = switch (owner.definition.type) {
      TurretType.arrow => 3.5,
      TurretType.cannon => 7,
      TurretType.magic => 4,
      TurretType.frost => 5,
      TurretType.sniper => 3.5,
      TurretType.lightning => 3.5,
    };
    return baseRadius * owner.game.boardDistanceScale;
  }

  @override
  void render(Canvas canvas) {
    final color = owner.definition.color;
    final visualScale = size.x / _visualSize(owner.definition.type);
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
        TurretType.lightning => 2.2 - i * 0.16,
      };
      final scaledRadius = radius * visualScale;
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
            ..strokeWidth = 1.5 * visualScale
            ..strokeCap = StrokeCap.round,
        );
      }
      if (owner.definition.type == TurretType.magic) {
        canvas.drawCircle(
          local,
          scaledRadius * 2.4,
          Paint()..color = color.withValues(alpha: alpha * 0.16),
        );
      }
      canvas.drawCircle(
        local,
        scaledRadius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    final center = Offset(size.x / 2, size.y / 2);
    switch (owner.definition.type) {
      case TurretType.arrow:
        canvas.drawCircle(center, 2.4 * visualScale, Paint()..color = color);
        canvas.drawCircle(
          center,
          1.0 * visualScale,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      case TurretType.cannon:
        canvas.drawCircle(
          center.translate(-2 * visualScale, 1 * visualScale),
          6.0 * visualScale,
          Paint()..color = color.withValues(alpha: 0.18),
        );
        canvas.drawCircle(
          center,
          4.0 * visualScale,
          Paint()..color = const Color(0xFF2D1E18),
        );
        canvas.drawCircle(center, 2.8 * visualScale, Paint()..color = color);
      case TurretType.magic:
        final flame = Path()
          ..moveTo(center.dx + 1 * visualScale, center.dy - 4 * visualScale)
          ..quadraticBezierTo(
            center.dx + 5 * visualScale,
            center.dy,
            center.dx,
            center.dy + 4 * visualScale,
          )
          ..quadraticBezierTo(
            center.dx - 4 * visualScale,
            center.dy,
            center.dx + 1 * visualScale,
            center.dy - 4 * visualScale,
          )
          ..close();
        canvas.drawPath(flame, Paint()..color = color);
        canvas.drawCircle(
          center,
          1.4 * visualScale,
          Paint()..color = const Color(0xFFFFD45A),
        );
      case TurretType.frost:
        canvas.drawCircle(
          center,
          3.6 * visualScale,
          Paint()..color = color.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          center,
          1.5 * visualScale,
          Paint()..color = const Color(0xFFE8FBFF),
        );
      case TurretType.sniper:
        canvas.drawCircle(center, 2.4 * visualScale, Paint()..color = color);
        canvas.drawCircle(
          center,
          1.0 * visualScale,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      case TurretType.lightning:
        canvas.drawCircle(
          center,
          4.2 * visualScale,
          Paint()..color = color.withValues(alpha: 0.28),
        );
        canvas.drawCircle(center, 2.4 * visualScale, Paint()..color = color);
        canvas.drawCircle(
          center,
          1.0 * visualScale,
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
      TurretType.lightning => 8,
    };
  }
}
