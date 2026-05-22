import 'dart:ui';

import 'package:flame/components.dart';

import '../rune_nexus_game.dart';
import 'enemy_component.dart';

class NexusCoreBeamComponent extends PositionComponent {
  NexusCoreBeamComponent({
    required Vector2 start,
    required this.target,
    required this.color,
    required this.game,
    double duration = 0.14,
  }) : _start = start.clone(),
       _targetPosition = target.position.clone(),
       _duration = duration,
       super(position: Vector2.zero(), size: Vector2.zero());

  final EnemyComponent target;
  final Color color;
  final RuneNexusGame game;
  final Vector2 _start;
  final double _duration;
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
    if (target.isMounted && !target.isDead) {
      _targetPosition = target.position.clone();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0).toDouble();
    final alpha = (1 - progress) * 0.92;
    final scale = game.boardDistanceScale;
    final start = Offset(_start.x, _start.y);
    final end = Offset(_targetPosition.x, _targetPosition.y);

    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.18)
        ..strokeWidth = 10 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.42)
        ..strokeWidth = 4.8 * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
        ..strokeWidth = 1.6 * scale
        ..strokeCap = StrokeCap.round,
    );
    _drawCoreFlare(canvas, start, alpha, scale);
    _drawCoreFlare(canvas, end, alpha * 0.72, scale * 0.72);
  }

  void _drawCoreFlare(
    Canvas canvas,
    Offset center,
    double alpha,
    double scale,
  ) {
    canvas.drawCircle(
      center,
      6.4 * scale,
      Paint()..color = color.withValues(alpha: alpha * 0.26),
    );
    canvas.drawCircle(
      center,
      2.3 * scale,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.9),
    );
  }
}
