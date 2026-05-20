import 'dart:ui';

import 'package:flame/components.dart';

import '../rune_nexus_game.dart';
import 'enemy_component.dart';
import 'turret_component.dart';

class SniperChainBeamComponent extends PositionComponent {
  SniperChainBeamComponent({
    required EnemyComponent source,
    required this.target,
    required this.owner,
    required this.damage,
    required this.game,
    double duration = 0.16,
  }) : _source = source,
       _duration = duration,
       _sourcePosition = source.position.clone(),
       _targetPosition = target.position.clone(),
       super(position: Vector2.zero(), size: Vector2.zero()) {
    game.resolveChainHit(owner: owner, target: target, damage: damage);
  }

  final EnemyComponent _source;
  final EnemyComponent target;
  final TurretComponent owner;
  final double damage;
  final RuneNexusGame game;
  final double _duration;
  Vector2 _sourcePosition;
  Vector2 _targetPosition;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
      return;
    }

    if (_source.isMounted && !_source.isDead) {
      _sourcePosition = _source.position.clone();
    }
    if (target.isMounted && !target.isDead) {
      _targetPosition = target.position.clone();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0).toDouble();
    final alpha = (1 - progress) * 0.9;
    final start = Offset(_sourcePosition.x, _sourcePosition.y);
    final end = Offset(_targetPosition.x, _targetPosition.y);
    final scale = owner.game.boardDistanceScale;

    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xFF3FE7FF).withValues(alpha: alpha * 0.24)
        ..strokeWidth = 8.0 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xFF8CFFF3).withValues(alpha: alpha * 0.38)
        ..strokeWidth = 4.4 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xFFEFFBFF).withValues(alpha: alpha)
        ..strokeWidth = 1.5 * scale
        ..strokeCap = StrokeCap.round,
    );

    _drawSpark(canvas, start, alpha, scale);
    _drawSpark(canvas, end, alpha, scale);
  }

  void _drawSpark(Canvas canvas, Offset center, double alpha, double scale) {
    canvas.drawCircle(
      center,
      5.6 * scale,
      Paint()..color = const Color(0xFF4DEAFF).withValues(alpha: alpha * 0.24),
    );
    canvas.drawCircle(
      center,
      2.4 * scale,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.86),
    );
  }
}
