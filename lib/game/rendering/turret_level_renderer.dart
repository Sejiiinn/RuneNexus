import 'dart:math' as math;

import 'package:flutter/painting.dart';

class TurretLevelRenderer {
  TextPainter? _levelLabelPainter;
  int _levelLabelPainterLevel = 0;
  double _levelLabelPainterTileSize = 0;
  int _level = 1;
  double _tileSize = 0;

  void drawPowerAura(
    Canvas canvas, {
    required Offset center,
    required double tileSize,
    required int level,
  }) {
    _syncContext(tileSize: tileSize, level: level);
    _drawLevelPowerAura(canvas, center);
  }

  void drawBadge(
    Canvas canvas, {
    required Offset center,
    required double tileSize,
    required int level,
  }) {
    _syncContext(tileSize: tileSize, level: level);
    _drawLevelBadge(canvas, center);
  }

  void _syncContext({required double tileSize, required int level}) {
    _tileSize = tileSize;
    _level = level;
  }

  void _drawLevelPowerAura(Canvas canvas, Offset center) {
    if (_level <= 1) {
      return;
    }

    final tier = _levelVisualTier;
    final ringRadius = _tileSize * (0.28 + tier * 0.015);
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD45A).withValues(alpha: 0.045 + tier * 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tileSize * (0.034 + tier * 0.004);
    final ringPaint = Paint()
      ..color = const Color(0xFFFFE78C).withValues(alpha: 0.16 + tier * 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + tier * 0.25;

    canvas.drawCircle(center, ringRadius, glowPaint);
    canvas.drawCircle(center, ringRadius, ringPaint);

    if (tier < 3) {
      return;
    }

    final sparkPaint = Paint()
      ..color = const Color(
        0xFFFFF0B0,
      ).withValues(alpha: tier >= 4 ? 0.92 : 0.7)
      ..strokeWidth = tier >= 4 ? 1.8 : 1.45
      ..strokeCap = StrokeCap.round;
    for (final angle in const [-math.pi / 2, 0.0, math.pi / 2, math.pi]) {
      final start = Offset(
        center.dx + math.cos(angle) * ringRadius,
        center.dy + math.sin(angle) * ringRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * (ringRadius + _tileSize * 0.035),
        center.dy + math.sin(angle) * (ringRadius + _tileSize * 0.035),
      );
      canvas.drawLine(start, end, sparkPaint);
    }
  }

  void _drawLevelBadge(Canvas canvas, Offset center) {
    final tier = _levelVisualTier;
    final badgeCenter = center.translate(0, _tileSize * 0.3);
    final badgeWidth = _tileSize * (_level >= 10 ? 0.54 : 0.49);
    final badgeHeight = _tileSize * 0.21;
    final badgeRect = Rect.fromCenter(
      center: badgeCenter,
      width: badgeWidth,
      height: badgeHeight,
    );
    final badgeRadius = Radius.circular(badgeHeight * 0.34);
    final frameColor = _levelFrameColor;
    final backgroundColor = tier >= 4
        ? const Color(0xF02B2106)
        : const Color(0xEC050A12);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        badgeRect
            .shift(Offset(0, _tileSize * 0.018))
            .inflate(_tileSize * 0.016),
        badgeRadius,
      ),
      Paint()..color = const Color(0xB0000000),
    );

    if (_level > 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          badgeRect.inflate(_tileSize * 0.012),
          badgeRadius,
        ),
        Paint()
          ..color = frameColor.withValues(alpha: 0.1 + tier * 0.035)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _tileSize * (0.05 + tier * 0.006),
      );
    }

    if (tier >= 2) {
      _drawLevelFrameWings(canvas, badgeCenter, frameColor, tier);
    }

    final badge = RRect.fromRectAndRadius(badgeRect, badgeRadius);
    canvas.drawRRect(
      badge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(backgroundColor, frameColor, tier >= 3 ? 0.2 : 0.12)!,
            backgroundColor,
            const Color(0xFF02050A),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(badgeRect),
    );
    canvas.drawRRect(
      badge,
      Paint()
        ..color = frameColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + tier * 0.28,
    );
    _drawLevelFrameBevels(canvas, badgeRect, frameColor, tier);

    if (tier >= 3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          badgeRect.deflate(_tileSize * 0.025),
          Radius.circular(badgeHeight * 0.22),
        ),
        Paint()
          ..color = frameColor.withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    if (_level > 1) {
      _drawLevelFrameCrest(canvas, badgeRect, frameColor, tier);
    }

    final labelPainter = _levelTextPainter();
    labelPainter.paint(
      canvas,
      badgeCenter.translate(-labelPainter.width / 2, -labelPainter.height / 2),
    );
  }

  void _drawLevelFrameWings(
    Canvas canvas,
    Offset badgeCenter,
    Color frameColor,
    int tier,
  ) {
    final wingWidth =
        _tileSize *
        switch (tier) {
          2 => 0.61,
          3 => 0.65,
          _ => 0.69,
        };
    final wingHeight = _tileSize * 0.11;
    final wing = _levelWingPath(badgeCenter, wingWidth, wingHeight);
    final wingFill = tier >= 3
        ? const Color(0xFFFFF6DA)
        : const Color(0xFFFFEBC1);

    canvas.drawPath(
      wing.shift(Offset(0, _tileSize * 0.014)),
      Paint()..color = const Color(0xB0050A12),
    );
    canvas.drawPath(
      wing,
      Paint()
        ..color = frameColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(wing, Paint()..color = wingFill.withValues(alpha: 0.98));
    canvas.drawPath(
      wing,
      Paint()
        ..color = const Color(0xFF050A12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  Path _levelWingPath(Offset center, double width, double height) {
    final halfWidth = width / 2;
    final halfHeight = height / 2;
    final bevel = height * 0.52;
    return Path()
      ..moveTo(center.dx - halfWidth, center.dy)
      ..lineTo(center.dx - halfWidth + bevel, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth - bevel, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx + halfWidth - bevel, center.dy + halfHeight)
      ..lineTo(center.dx - halfWidth + bevel, center.dy + halfHeight)
      ..close();
  }

  void _drawLevelFrameBevels(
    Canvas canvas,
    Rect badgeRect,
    Color frameColor,
    int tier,
  ) {
    final lineLength = badgeRect.width * (tier >= 3 ? 0.17 : 0.12);
    final inset = badgeRect.width * 0.13;
    final highlightPaint = Paint()
      ..color = Color.lerp(
        frameColor,
        const Color(0xFFFFFFFF),
        0.46,
      )!.withValues(alpha: 0.7)
      ..strokeWidth = tier >= 3 ? 1.2 : 0.9
      ..strokeCap = StrokeCap.round;
    final shadePaint = Paint()
      ..color = const Color(0xFF050A12).withValues(alpha: 0.88)
      ..strokeWidth = tier >= 3 ? 1.2 : 0.9
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(badgeRect.left + inset, badgeRect.top),
      Offset(badgeRect.left + inset + lineLength, badgeRect.top),
      highlightPaint,
    );
    canvas.drawLine(
      Offset(badgeRect.right - inset - lineLength, badgeRect.top),
      Offset(badgeRect.right - inset, badgeRect.top),
      highlightPaint,
    );
    canvas.drawLine(
      Offset(badgeRect.left + inset, badgeRect.bottom),
      Offset(badgeRect.left + inset + lineLength, badgeRect.bottom),
      shadePaint,
    );
    canvas.drawLine(
      Offset(badgeRect.right - inset - lineLength, badgeRect.bottom),
      Offset(badgeRect.right - inset, badgeRect.bottom),
      shadePaint,
    );
  }

  void _drawLevelFrameCrest(
    Canvas canvas,
    Rect badgeRect,
    Color frameColor,
    int tier,
  ) {
    final crestCenter = badgeRect.topCenter.translate(
      0,
      -_tileSize * (tier >= 4 ? 0.026 : 0.012),
    );
    if (tier >= 4) {
      final star = _levelStarPath(crestCenter, _tileSize * 0.055);
      canvas.drawPath(
        star.shift(Offset(0, _tileSize * 0.01)),
        Paint()..color = const Color(0xB0050A12),
      );
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFF0B0));
      canvas.drawPath(
        star,
        Paint()
          ..color = const Color(0xFF050A12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      return;
    }

    final radius = _tileSize * (tier >= 3 ? 0.035 : 0.027);
    final diamond = Path()
      ..moveTo(crestCenter.dx, crestCenter.dy - radius)
      ..lineTo(crestCenter.dx + radius, crestCenter.dy)
      ..lineTo(crestCenter.dx, crestCenter.dy + radius)
      ..lineTo(crestCenter.dx - radius, crestCenter.dy)
      ..close();
    canvas.drawPath(
      diamond.shift(Offset(0, _tileSize * 0.008)),
      Paint()..color = const Color(0xB0050A12),
    );
    canvas.drawPath(diamond, Paint()..color = frameColor);
    canvas.drawPath(
      diamond,
      Paint()
        ..color = const Color(0xFF050A12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  TextPainter _levelTextPainter() {
    if (_levelLabelPainter == null ||
        _levelLabelPainterLevel != _level ||
        _levelLabelPainterTileSize != _tileSize) {
      _levelLabelPainterLevel = _level;
      _levelLabelPainterTileSize = _tileSize;
      _levelLabelPainter = TextPainter(
        text: TextSpan(
          text: 'Lv.$_level',
          style: TextStyle(
            color: _level <= 1
                ? const Color(0xFFE8F8FF)
                : const Color(0xFFFFF0B0),
            fontSize: _tileSize * 0.125,
            fontWeight: FontWeight.w900,
            height: 1,
            shadows: [
              const Shadow(
                color: Color(0xFF000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
              if (_level >= 5)
                Shadow(
                  color: const Color(0xFFFFD45A).withValues(alpha: 0.5),
                  blurRadius: 2.4,
                ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    return _levelLabelPainter!;
  }

  Color get _levelFrameColor {
    if (_level <= 1) {
      return const Color(0xFF607486);
    }
    if (_level <= 4) {
      return Color.lerp(
        const Color(0xFF8FA8BA),
        const Color(0xFFE7C66A),
        (_level - 1) / 3,
      )!;
    }
    if (_level <= 7) {
      return Color.lerp(
        const Color(0xFFE7C66A),
        const Color(0xFFFFD166),
        (_level - 4) / 3,
      )!;
    }
    return const Color(0xFFFFE78C);
  }

  Path _levelStarPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final pointRadius = i.isEven ? radius : radius * 0.48;
      final point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  int get _levelVisualTier {
    if (_level >= 10) {
      return 4;
    }
    if (_level >= 8) {
      return 3;
    }
    if (_level >= 5) {
      return 2;
    }
    return 1;
  }
}
