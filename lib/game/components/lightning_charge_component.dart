import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

class LightningChargeComponent extends PositionComponent {
  LightningChargeComponent({
    required this.chargePosition,
    required this.isActive,
    required this.onRelease,
    required this.color,
    this.duration = 0.3,
    this.visualScale = 1,
  }) : super(position: Vector2.zero(), size: Vector2.zero());

  final Vector2 Function() chargePosition;
  final bool Function() isActive;
  final void Function() onRelease;
  final Color color;
  final double duration;
  final double visualScale;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (!isActive()) {
      removeFromParent();
      return;
    }

    _elapsed += dt;
    if (_elapsed >= duration) {
      onRelease();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / duration).clamp(0.0, 1.0).toDouble();
    final center = chargePosition();
    final offset = Offset(center.x, center.y);
    final pulse = math.sin(progress * math.pi);
    final radius = (3.15 + progress * 3.85) * visualScale;

    canvas.drawCircle(
      offset,
      radius * 2.4,
      Paint()..color = color.withValues(alpha: 0.12 + pulse * 0.16),
    );
    canvas.drawCircle(
      offset,
      radius * 1.35,
      Paint()
        ..color = const Color(0xFF8CFFF3).withValues(alpha: 0.28 + pulse * 0.3),
    );
    canvas.drawCircle(
      offset,
      radius * 0.58,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.72),
    );

    final arcPaint = Paint()
      ..color = const Color(0xFFBFFBFF).withValues(alpha: 0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 * visualScale
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final angle = progress * math.pi * 5 + i * math.pi * 2 / 3;
      final from = Offset(
        offset.dx + math.cos(angle) * radius * 0.95,
        offset.dy + math.sin(angle) * radius * 0.95,
      );
      final to = Offset(
        offset.dx + math.cos(angle + 0.55) * radius * 1.55,
        offset.dy + math.sin(angle + 0.55) * radius * 1.55,
      );
      canvas.drawLine(from, to, arcPaint);
    }
  }
}
