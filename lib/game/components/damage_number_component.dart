import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum DamageNumberMotion { rise, fallArc }

enum DamageNumberFeedback { neutral, weak, resisted }

class DamageNumberImageCache {
  final Map<_DamageNumberImageKey, ui.Image> _images = {};

  ui.Image imageFor({
    required String text,
    required Color color,
    required DamageNumberFeedback feedback,
    required Vector2 size,
  }) {
    final key = _DamageNumberImageKey(
      text: text,
      color: color,
      feedback: feedback,
      width: size.x.ceil(),
      height: size.y.ceil(),
    );
    return _images.putIfAbsent(
      key,
      () => _renderTextImage(
        text: text,
        color: color,
        feedback: feedback,
        width: key.width,
        height: key.height,
      ),
    );
  }

  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }

  ui.Image _renderTextImage({
    required String text,
    required Color color,
    required DamageNumberFeedback feedback,
    required int width,
    required int height,
  }) {
    final textColor = switch (feedback) {
      DamageNumberFeedback.weak => Color.lerp(
        color,
        const Color(0xFFFFFFFF),
        0.35,
      )!,
      DamageNumberFeedback.resisted => Color.lerp(
        color,
        const Color(0xFF7E8B96),
        0.72,
      )!,
      DamageNumberFeedback.neutral => color,
    };
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: const Color(0xFF02070D).withValues(alpha: 0.42),
              blurRadius: 3,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width.toDouble());

    final recorder = ui.PictureRecorder();
    final imageCanvas = Canvas(recorder);
    painter.paint(
      imageCanvas,
      Offset((width - painter.width) / 2, (height - painter.height) / 2),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }
}

class _DamageNumberImageKey {
  const _DamageNumberImageKey({
    required this.text,
    required this.color,
    required this.feedback,
    required this.width,
    required this.height,
  });

  final String text;
  final Color color;
  final DamageNumberFeedback feedback;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) {
    return other is _DamageNumberImageKey &&
        other.text == text &&
        other.color == color &&
        other.feedback == feedback &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(text, color, feedback, width, height);
}

class DamageNumberComponent extends PositionComponent {
  DamageNumberComponent({
    required Vector2 position,
    required ui.Image textImage,
    DamageNumberMotion motion = DamageNumberMotion.rise,
    DamageNumberFeedback feedback = DamageNumberFeedback.neutral,
  }) : _motion = motion,
       _feedback = feedback,
       _arcDirection = position.x.round().isEven ? -1 : 1,
       _textImage = textImage,
       super(position: position, size: Vector2(78, 28), anchor: Anchor.center);

  final DamageNumberMotion _motion;
  final DamageNumberFeedback _feedback;
  final int _arcDirection;
  final ui.Image _textImage;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.none;
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
    final scale = motionScale * feedbackScale;
    _drawFeedbackEffect(canvas, progress, alpha);
    _imagePaint.colorFilter = ColorFilter.mode(
      const Color(0xFFFFFFFF).withValues(alpha: alpha),
      BlendMode.modulate,
    );
    canvas.save();
    canvas.translate(
      size.x / 2,
      size.y / 2 +
          (_feedback == DamageNumberFeedback.resisted ? progress * 5 : 0),
    );
    canvas.scale(scale);
    canvas.drawImage(
      _textImage,
      Offset(-_textImage.width / 2, -_textImage.height / 2),
      _imagePaint,
    );
    canvas.restore();
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
