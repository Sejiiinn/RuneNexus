import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show TextPainter, TextSpan, TextStyle;

import '../rendering/diamond_currency_renderer.dart';

class DiamondRewardEffectComponent extends PositionComponent {
  DiamondRewardEffectComponent({
    required Vector2 position,
    required int reward,
    double visualScale = 1,
  }) : _reward = reward,
       _visualScale = visualScale,
       super(
         position: position,
         size: Vector2(94, 56) * visualScale,
         anchor: Anchor.center,
         priority: 20,
       );

  final int _reward;
  final double _visualScale;
  double _age = 0;
  static const double _lifeTime = 1.05;

  late final TextPainter _textPainter = TextPainter(
    text: TextSpan(
      text: '+$_reward',
      style: TextStyle(
        color: const Color(0xFFEAFBFF),
        fontSize: 22 * _visualScale,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            color: const Color(0xFF02070D).withValues(alpha: 0.9),
            blurRadius: 4 * _visualScale,
            offset: Offset(1 * _visualScale, 1.5 * _visualScale),
          ),
          Shadow(
            color: const Color(0xFF58CFFF).withValues(alpha: 0.75),
            blurRadius: 8 * _visualScale,
          ),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= 24 * _visualScale * dt;
    if (_age >= _lifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / _lifeTime).clamp(0.0, 1.0).toDouble();
    final appear = (progress / 0.16).clamp(0.0, 1.0).toDouble();
    final alpha = (1 - math.pow(progress, 2.4)).toDouble();
    final scale = 0.78 + appear * 0.3 - progress * 0.08;
    final center = Offset(size.x / 2, size.y / 2);

    canvas.saveLayer(
      Offset.zero & Size(size.x, size.y),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-22 * _visualScale, 0),
        width: 40 * _visualScale,
        height: 30 * _visualScale,
      ),
      Paint()
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.28 * appear)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * _visualScale),
    );
    canvas.save();
    canvas.translate(
      center.dx - 34 * _visualScale,
      center.dy - 16 * _visualScale,
    );
    canvas.scale(scale);
    drawDiamondCurrencyGlyph(
      canvas,
      Size(30 * _visualScale, 30 * _visualScale),
    );
    canvas.restore();

    for (var index = 0; index < 5; index++) {
      final angle = index * math.pi * 2 / 5 - math.pi / 2;
      final distance = (12 + progress * 18) * _visualScale;
      final shardCenter = center.translate(
        -20 * _visualScale + math.cos(angle) * distance,
        math.sin(angle) * distance,
      );
      canvas.drawCircle(
        shardCenter,
        (1.7 - progress * 0.7) * _visualScale,
        Paint()
          ..color = const Color(0xFFCFF4FF).withValues(alpha: 0.85 * alpha),
      );
    }

    _textPainter.paint(
      canvas,
      Offset(center.dx - 4 * _visualScale, center.dy - _textPainter.height / 2),
    );
    canvas.restore();
  }
}
