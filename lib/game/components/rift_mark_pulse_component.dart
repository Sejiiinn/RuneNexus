import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../rune_nexus_game.dart';
import 'enemy_component.dart';

class RiftMarkPulseComponent extends PositionComponent {
  RiftMarkPulseComponent({
    required Vector2 source,
    required Iterable<EnemyComponent> targets,
    required this.color,
    required this.game,
    double duration = 0.42,
  }) : _source = source.clone(),
       _targets = targets.toList(growable: false),
       _duration = duration,
       super(position: Vector2.zero(), size: Vector2.zero());

  final Vector2 _source;
  final List<EnemyComponent> _targets;
  final Color color;
  final RuneNexusGame game;
  final double _duration;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0).toDouble();
    final alpha = 1 - progress;
    final scale = game.boardDistanceScale;
    final source = Offset(_source.x, _source.y);

    _drawCorePulse(canvas, source, progress, alpha, scale);
    _drawTargetLinks(canvas, source, progress, alpha, scale);
  }

  void _drawCorePulse(
    Canvas canvas,
    Offset source,
    double progress,
    double alpha,
    double scale,
  ) {
    final pulseRadius = 10 * scale + 24 * scale * progress;
    final ringPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * scale;

    canvas.drawCircle(source, pulseRadius, glowPaint);
    for (var i = 0; i < 4; i++) {
      final start = progress * math.pi * 2 + i * math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: source, radius: pulseRadius),
        start,
        math.pi * 0.34,
        false,
        ringPaint,
      );
    }
    canvas.drawCircle(
      source,
      (3.4 + 3.2 * alpha) * scale,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.9),
    );
  }

  void _drawTargetLinks(
    Canvas canvas,
    Offset source,
    double progress,
    double alpha,
    double scale,
  ) {
    final linkAlpha = alpha * (1 - (progress - 0.25).clamp(0.0, 0.75) / 0.75);
    if (linkAlpha <= 0) {
      return;
    }

    final linkPaint = Paint()
      ..color = color.withValues(alpha: linkAlpha * 0.5)
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round;
    final corePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: linkAlpha * 0.72)
      ..strokeWidth = 0.8 * scale
      ..strokeCap = StrokeCap.round;

    for (final target in _targets) {
      if (!target.isMounted || target.isDead) {
        continue;
      }
      final end = Offset(target.position.x, target.position.y);
      canvas.drawLine(source, end, linkPaint);
      canvas.drawLine(source, end, corePaint);
      canvas.drawCircle(
        end,
        4.2 * scale,
        Paint()..color = color.withValues(alpha: linkAlpha * 0.32),
      );
    }
  }
}
