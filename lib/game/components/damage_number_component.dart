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
       super(position: position, size: Vector2(64, 24), anchor: Anchor.center);

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
        position.x += _arcDirection * 24 * dt;
        position.y += (-18 + 74 * progress) * dt;
    }

    if (_age >= _lifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / _lifeTime).clamp(0.0, 1.0);
    final alpha = 1 - progress;
    final scale = switch (_motion) {
      DamageNumberMotion.rise => 1.0,
      DamageNumberMotion.fallArc => 1 - progress * 0.48,
    };
    final text = switch (_feedback) {
      DamageNumberFeedback.weak => '↑$_text',
      DamageNumberFeedback.resisted => '↓$_text',
      DamageNumberFeedback.neutral => _text,
    };
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _baseColor.withValues(alpha: alpha),
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
      Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2),
    );
  }
}
