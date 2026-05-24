import 'dart:ui';

import 'package:flame/components.dart';

import '../rune_nexus_game.dart';
import 'enemy_component.dart';
import 'turret_component.dart';

class ChainProjectileComponent extends PositionComponent {
  ChainProjectileComponent({
    required Vector2 origin,
    required this.target,
    required this.owner,
    required this.attack,
    required this.damage,
    required this.game,
  }) : super(position: origin, size: Vector2.all(7), anchor: Anchor.center);

  final EnemyComponent target;
  final TurretComponent owner;
  final TurretAttackSnapshot attack;
  final double damage;
  final RuneNexusGame game;
  final List<Vector2> _points = [];

  @override
  void update(double dt) {
    super.update(dt);
    if (!target.isMounted || target.isDead) {
      removeFromParent();
      return;
    }

    final direction = target.position - position;
    final distance = direction.length;
    final step = attack.projectileSpeed * 1.25 * dt;

    if (distance <= step) {
      game.resolveChainHit(
        owner: owner,
        attack: attack,
        target: target,
        damage: damage,
      );
      removeFromParent();
      return;
    }

    position += direction.normalized() * step;
    _points.insert(0, position.clone());
    if (_points.length > 8) {
      _points.removeRange(8, _points.length);
    }
  }

  @override
  void render(Canvas canvas) {
    final color = game.chainColorFor(owner);
    final trailPaint = Paint();
    for (var i = 0; i < _points.length; i++) {
      final point = _points[i];
      final local = Offset(
        point.x - position.x + size.x / 2,
        point.y - position.y + size.y / 2,
      );
      trailPaint.color = color.withValues(
        alpha: (0.8 * (1 - i / (_points.length + 1))).clamp(0.0, 0.8),
      );
      canvas.drawCircle(local, 2.2 - i * 0.18, trailPaint);
      canvas.drawCircle(
        local,
        4.4 - i * 0.22,
        Paint()
          ..color = color.withValues(
            alpha: (0.18 * (1 - i / (_points.length + 1))).clamp(0.0, 0.18),
          ),
      );
    }

    final headPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      5.2,
      Paint()..color = color.withValues(alpha: 0.24),
    );
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 2.8, headPaint);
  }
}
