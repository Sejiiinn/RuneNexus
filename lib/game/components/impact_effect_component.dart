import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

enum ImpactEffectStyle { spark, blast, flame }

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
          ..color = _color.withValues(alpha: alpha)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.square;
        for (var i = 0; i < 4; i++) {
          final angle = i * 1.5708 + progress * 0.55;
          final from = Offset(
            center.dx + radius * 0.15 * math.cos(angle),
            center.dy + radius * 0.15 * math.sin(angle),
          );
          final to = Offset(
            center.dx + radius * (0.55 + progress * 0.25) * math.cos(angle),
            center.dy + radius * (0.55 + progress * 0.25) * math.sin(angle),
          );
          canvas.drawLine(from, to, paint);
        }
      case ImpactEffectStyle.blast:
        final ring = Paint()
          ..color = _color.withValues(alpha: alpha * 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawCircle(center, radius * (0.3 + progress * 0.7), ring);
        canvas.drawCircle(
          center,
          radius * (0.18 + progress * 0.16),
          Paint()
            ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.55),
        );
      case ImpactEffectStyle.flame:
        final flame = Paint()..color = _color.withValues(alpha: alpha * 0.72);
        canvas.drawCircle(
          Offset(center.dx, center.dy - radius * 0.16 * progress),
          radius * (0.28 + progress * 0.18),
          flame,
        );
        canvas.drawCircle(
          center,
          radius * (0.12 + progress * 0.1),
          Paint()
            ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.7),
        );
    }
  }
}
