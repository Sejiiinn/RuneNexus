import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum DamageNumberMotion { rise, fallArc }

enum DamageNumberFeedback { neutral, weak, resisted }

class DamageNumberComponent extends PositionComponent {
  DamageNumberComponent({
    required String text,
    required Color color,
    required Vector2 position,
    DamageNumberMotion motion = DamageNumberMotion.rise,
    DamageNumberFeedback feedback = DamageNumberFeedback.neutral,
  }) : _text = text,
       _baseColor = color,
       _motion = motion,
       _feedback = feedback,
       _arcDirection = position.x.round().isEven ? -1 : 1,
       super(position: position, size: Vector2(78, 28), anchor: Anchor.center);

  final String _text;
  final Color _baseColor;
  final DamageNumberMotion _motion;
  final DamageNumberFeedback _feedback;
  final int _arcDirection;
  double _age = 0;
  final double _lifeTime = 0.75;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    final progress = (_age / _lifeTime).clamp(0.0, 1.0);
    switch (_motion) {
      case DamageNumberMotion.rise:
        position.y -= 34 * dt;
      case DamageNumberMotion.fallArc:
        position.x += _arcDirection * 42 * dt;
        position.y += (-28 + 96 * progress) * dt;
    }

    if (_age >= _lifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / _lifeTime).clamp(0.0, 1.0);
    final alpha = 1 - progress;
    final motionScale = switch (_motion) {
      DamageNumberMotion.rise => 1.0,
      DamageNumberMotion.fallArc => 1 - progress * 0.48,
    };
    final feedbackScale = switch (_feedback) {
      DamageNumberFeedback.weak => 1.14,
      DamageNumberFeedback.resisted => 0.82,
      DamageNumberFeedback.neutral => 1.0,
    };
    final textColor = switch (_feedback) {
      DamageNumberFeedback.weak => Color.lerp(
        _baseColor,
        const Color(0xFFFFFFFF),
        0.35,
      )!,
      DamageNumberFeedback.resisted => Color.lerp(
        _baseColor,
        const Color(0xFF7E8B96),
        0.72,
      )!,
      DamageNumberFeedback.neutral => _baseColor,
    };
    final scale = motionScale * feedbackScale;
    _drawFeedbackEffect(canvas, progress, alpha);
    final painter = TextPainter(
      text: TextSpan(
        text: _text,
        style: TextStyle(
          color: textColor.withValues(alpha: alpha),
          fontSize: 15 * scale,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: const Color(0xFF02070D).withValues(alpha: alpha * 0.42),
              blurRadius: 3,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);

    painter.paint(
      canvas,
      Offset(
        (size.x - painter.width) / 2,
        (size.y - painter.height) / 2 +
            (_feedback == DamageNumberFeedback.resisted ? progress * 5 : 0),
      ),
    );
  }

  void _drawFeedbackEffect(Canvas canvas, double progress, double alpha) {
    final center = Offset(size.x / 2, size.y / 2);
    switch (_feedback) {
      case DamageNumberFeedback.weak:
        final sparkPaint = Paint()
          ..color = const Color(0xFFFFF0A6).withValues(alpha: alpha * 0.72)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final angle = -math.pi * 0.72 + i * math.pi * 0.72;
          final inner = 8 + progress * 2;
          final outer = 13 + progress * 4;
          canvas.drawLine(
            Offset(
              center.dx + math.cos(angle) * inner,
              center.dy + math.sin(angle) * inner,
            ),
            Offset(
              center.dx + math.cos(angle) * outer,
              center.dy + math.sin(angle) * outer,
            ),
            sparkPaint,
          );
        }
      case DamageNumberFeedback.resisted:
        break;
      case DamageNumberFeedback.neutral:
        break;
    }
  }
}
