import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

class GemEquipEffectComponent extends PositionComponent {
  GemEquipEffectComponent({
    required Vector2 position,
    required Color gemColor,
    required double visualScale,
  }) : _gemColor = gemColor,
       _visualScale = visualScale,
       super(
         position: position,
         size: Vector2.all(_effectExtent * visualScale),
         anchor: Anchor.center,
       );

  static const double _effectExtent = 112;
  static const double _duration = 0.78;

  final Color _gemColor;
  final double _visualScale;
  double _elapsed = 0;

  Color get gemColor => _gemColor;

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
    final alpha = math.pow(1 - progress, 0.72).toDouble();
    final center = Offset(size.x / 2, size.y / 2);

    _drawRuneSeal(canvas, center, progress, alpha);
    _drawSocketSparks(canvas, center, progress, alpha);
    _drawSocketBrackets(canvas, center, progress, alpha);
    _drawGemSnap(canvas, center, progress, alpha);
  }

  void _drawRuneSeal(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    final scale = _visualScale;
    final sealProgress = (progress / 0.62).clamp(0.0, 1.0).toDouble();
    final sealAlpha = alpha * (1 - (progress - 0.54).clamp(0.0, 0.46) / 0.46);
    if (sealAlpha <= 0) {
      return;
    }

    final eased = _easeOutCubic(sealProgress);
    final radius = (18 + 24 * eased) * scale;
    final rotation = -math.pi / 2 + progress * 0.32;
    final points = List<Offset>.generate(6, (index) {
      final angle = rotation + index * math.pi / 3;
      return Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
    });

    final glowPaint = Paint()
      ..color = _gemColor.withValues(alpha: sealAlpha * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * scale
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, radius * 0.92, glowPaint);

    final linePaint = Paint()
      ..color = _gemColor.withValues(alpha: sealAlpha * 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (var i = 0; i < points.length; i++) {
      canvas.drawLine(points[i], points[(i + 1) % points.length], linePaint);
    }

    final runePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: sealAlpha * 0.84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25 * scale
      ..strokeCap = StrokeCap.square
      ..blendMode = BlendMode.plus;
    for (var i = 0; i < points.length; i++) {
      final angle = rotation + i * math.pi / 3;
      final tangent = angle + math.pi / 2;
      final runeCenter = Offset(
        center.dx + math.cos(angle) * radius * 0.72,
        center.dy + math.sin(angle) * radius * 0.72,
      );
      final halfLength = (3.4 + (i.isEven ? 1.4 : 0)) * scale;
      canvas.drawLine(
        Offset(
          runeCenter.dx - math.cos(tangent) * halfLength,
          runeCenter.dy - math.sin(tangent) * halfLength,
        ),
        Offset(
          runeCenter.dx + math.cos(tangent) * halfLength,
          runeCenter.dy + math.sin(tangent) * halfLength,
        ),
        runePaint,
      );
    }
  }

  void _drawSocketSparks(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    final scale = _visualScale;
    final sparkProgress = (progress / 0.44).clamp(0.0, 1.0).toDouble();
    final sparkAlpha = alpha * (1 - (progress - 0.32).clamp(0.0, 0.36) / 0.36);
    if (sparkAlpha <= 0) {
      return;
    }

    final paint = Paint()
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    final eased = _easeOutCubic(sparkProgress);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + 0.18;
      final outer = (42 - 18 * eased) * scale;
      final inner = (26 - 10 * eased) * scale;
      final start = Offset(
        center.dx + math.cos(angle) * outer,
        center.dy + math.sin(angle) * outer,
      );
      final end = Offset(
        center.dx + math.cos(angle) * inner,
        center.dy + math.sin(angle) * inner,
      );
      paint.color = (i.isEven ? const Color(0xFFFFFFFF) : _gemColor).withValues(
        alpha: sparkAlpha * (i.isEven ? 0.95 : 0.72),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawSocketBrackets(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    final scale = _visualScale;
    final bracketProgress = ((progress - 0.24) / 0.34)
        .clamp(0.0, 1.0)
        .toDouble();
    if (bracketProgress <= 0) {
      return;
    }

    final eased = _easeOutCubic(bracketProgress);
    final bracketAlpha = alpha * math.sin(bracketProgress * math.pi);
    final half = (12 + 6 * (1 - eased)) * scale;
    final inset = 4.2 * scale;
    final length = 8 * scale;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: bracketAlpha * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.square
      ..blendMode = BlendMode.plus;

    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final corner = Offset(center.dx + sx * half, center.dy + sy * half);
        canvas.drawLine(corner, corner.translate(-sx * length, 0), paint);
        canvas.drawLine(corner, corner.translate(0, -sy * length), paint);
      }
    }

    final snapPaint = Paint()
      ..color = _gemColor.withValues(alpha: bracketAlpha * 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4 * scale
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, half - inset, snapPaint);
  }

  void _drawGemSnap(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    final scale = _visualScale;
    final pulse = math.sin((progress * math.pi).clamp(0.0, math.pi));
    final radius = (5.6 + 5.4 * pulse) * scale;
    final gemPath = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.84, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.84, center.dy)
      ..close();

    final glowPaint = Paint()
      ..color = _gemColor.withValues(alpha: alpha * 0.22)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, radius * 1.8, glowPaint);

    canvas.drawPath(
      gemPath,
      Paint()
        ..color = _gemColor.withValues(alpha: alpha * 0.88)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      gemPath,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.86)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale
        ..strokeJoin = StrokeJoin.round,
    );
  }

  double _easeOutCubic(double value) {
    final inverse = 1 - value;
    return 1 - inverse * inverse * inverse;
  }
}
