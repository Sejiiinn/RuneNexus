import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

enum ImpactEffectStyle { spark, blast, flame, frost }

class ImpactEffectComponent extends PositionComponent {
  ImpactEffectComponent({
    required Vector2 position,
    required Color color,
    required this.style,
    required this.radius,
  }) : _color = color,
       super(
         position: position,
         size: Vector2.all(radius * 2),
         anchor: Anchor.center,
       );

  final Color _color;
  final ImpactEffectStyle style;
  final double radius;
  double _age = 0;
  final double _lifeTime = 0.28;

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

    switch (style) {
      case ImpactEffectStyle.spark:
        final paint = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.square;
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + progress * 0.55;
          final from = Offset(
            center.dx + radius * 0.12 * math.cos(angle),
            center.dy + radius * 0.12 * math.sin(angle),
          );
          final to = Offset(
            center.dx + radius * (0.48 + progress * 0.34) * math.cos(angle),
            center.dy + radius * (0.48 + progress * 0.34) * math.sin(angle),
          );
          paint.color = (i.isEven ? const Color(0xFFFFFFFF) : _color)
              .withValues(alpha: alpha * 0.9);
          canvas.drawLine(from, to, paint);
        }
        canvas.drawCircle(
          center,
          radius * (0.14 + progress * 0.08),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
        );
      case ImpactEffectStyle.blast:
        final ring = Paint()
          ..color = _color.withValues(alpha: alpha * 0.66)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawCircle(center, radius * (0.3 + progress * 0.7), ring);
        canvas.drawCircle(
          center,
          radius * (0.18 + progress * 0.16),
          Paint()
            ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.55),
        );
        final dust = Paint()..color = const Color(0xFFB8B8A8);
        for (var i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5 + 0.28;
          final distance = radius * (0.2 + progress * 0.62);
          dust.color = dust.color.withValues(alpha: alpha * 0.34);
          canvas.drawCircle(
            Offset(
              center.dx + math.cos(angle) * distance,
              center.dy + math.sin(angle) * distance * 0.72,
            ),
            radius * (0.08 + progress * 0.05),
            dust,
          );
        }
      case ImpactEffectStyle.flame:
        final flame = Paint()..color = _color.withValues(alpha: alpha * 0.7);
        for (var i = 0; i < 3; i++) {
          final xOffset = (i - 1) * radius * 0.16;
          final lift = radius * progress * (0.32 + i * 0.08);
          canvas.drawOval(
            Rect.fromCenter(
              center: center.translate(xOffset, -lift),
              width: radius * (0.22 + progress * 0.12),
              height: radius * (0.5 + progress * 0.18),
            ),
            flame,
          );
        }
        canvas.drawCircle(
          center,
          radius * (0.12 + progress * 0.1),
          Paint()
            ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.7),
        );
        for (var i = 0; i < 4; i++) {
          final angle = -math.pi * 0.8 + i * math.pi * 0.42;
          canvas.drawCircle(
            Offset(
              center.dx + math.cos(angle) * radius * (0.22 + progress * 0.38),
              center.dy + math.sin(angle) * radius * (0.2 + progress * 0.24),
            ),
            radius * 0.035,
            Paint()
              ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.9),
          );
        }
      case ImpactEffectStyle.frost:
        final ring = Paint()
          ..color = _color.withValues(alpha: alpha * 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(center, radius * (0.18 + progress * 0.82), ring);
        canvas.drawCircle(
          center,
          radius * (0.12 + progress * 0.36),
          Paint()..color = _color.withValues(alpha: alpha * 0.12),
        );
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + progress * 0.22;
          final inner = radius * (0.16 + progress * 0.2);
          final outer = radius * (0.42 + progress * 0.28);
          canvas.drawLine(
            Offset(
              center.dx + inner * math.cos(angle),
              center.dy + inner * math.sin(angle),
            ),
            Offset(
              center.dx + outer * math.cos(angle),
              center.dy + outer * math.sin(angle),
            ),
            ring,
          );
        }
        final shardPaint = Paint()
          ..color = const Color(0xFFE8FBFF).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5 + progress * 0.35;
          final shardCenter = Offset(
            center.dx + math.cos(angle) * radius * (0.34 + progress * 0.38),
            center.dy + math.sin(angle) * radius * (0.34 + progress * 0.38),
          );
          final shardSize = radius * 0.05;
          canvas.drawLine(
            shardCenter.translate(-shardSize, 0),
            shardCenter.translate(shardSize, 0),
            shardPaint,
          );
          canvas.drawLine(
            shardCenter.translate(0, -shardSize),
            shardCenter.translate(0, shardSize),
            shardPaint,
          );
        }
    }
  }
}
