import 'dart:math' as math;

import 'package:flutter/painting.dart';

void drawTurretAimBeam(
  Canvas canvas, {
  required Offset center,
  required Offset target,
  required Color color,
  required double tileSize,
  required double progress,
  required double animationPhase,
}) {
  if (progress <= 0) {
    return;
  }

  final pulse = 0.55 + math.sin(animationPhase * 8) * 0.18;
  final beamColor = color.withValues(alpha: (0.16 + progress * 0.42) * pulse);
  canvas.drawLine(
    center,
    target,
    Paint()
      ..color = beamColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = tileSize * (0.018 + progress * 0.014),
  );
  final chargeRadius = tileSize * (0.08 + progress * 0.07);
  canvas.drawCircle(
    center,
    chargeRadius,
    Paint()
      ..color = color.withValues(alpha: 0.16 + progress * 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.025,
  );
}

void drawTurretGemReactionRing(
  Canvas canvas, {
  required Offset center,
  required double tileSize,
  required double animationPhase,
  required List<Color> gemColors,
}) {
  if (gemColors.isEmpty) {
    return;
  }

  final ringRect = Rect.fromCircle(center: center, radius: tileSize * 0.43);
  final pulse = 0.88 + math.sin(animationPhase * 2.4) * 0.12;
  final baseStroke = tileSize * 0.03;
  final glowStroke = tileSize * 0.1;
  canvas.drawOval(
    ringRect,
    Paint()
      ..color = const Color(0xFF020812).withValues(alpha: 0.76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStroke * 2.1,
  );

  final count = gemColors.length;
  final gap = count == 1 ? 0.0 : 0.22;
  final segmentSweep = count == 1
      ? math.pi * 1.64
      : (math.pi * 2 / count) - gap;
  final startOffset =
      -math.pi / 2 - (count == 1 ? segmentSweep / 2 : 0) + animationPhase;
  for (var i = 0; i < count; i++) {
    final ringColor = Color.lerp(gemColors[i], const Color(0xFFFFFFFF), 0.12)!;
    final start = count == 1
        ? startOffset
        : startOffset + i * math.pi * 2 / count + gap / 2;

    canvas.drawArc(
      ringRect,
      start,
      segmentSweep,
      false,
      Paint()
        ..color = ringColor.withValues(alpha: 0.34 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = glowStroke,
    );
    canvas.drawArc(
      ringRect,
      start,
      segmentSweep,
      false,
      Paint()
        ..color = ringColor.withValues(alpha: 0.96 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = baseStroke,
    );
    final midAngle = start + segmentSweep / 2;
    final tickStart = Offset(
      center.dx + math.cos(midAngle) * tileSize * 0.39,
      center.dy + math.sin(midAngle) * tileSize * 0.39,
    );
    final tickEnd = Offset(
      center.dx + math.cos(midAngle) * tileSize * 0.47,
      center.dy + math.sin(midAngle) * tileSize * 0.47,
    );
    canvas.drawLine(
      tickStart,
      tickEnd,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.72 * pulse)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = tileSize * 0.011,
    );
  }
}

void drawTurretSelectionHighlight(
  Canvas canvas, {
  required Offset center,
  required double tileSize,
  required Color color,
}) {
  final tileRect = Rect.fromCenter(
    center: center,
    width: tileSize - 4,
    height: tileSize - 4,
  );
  final radius = Radius.circular(tileSize * 0.09);
  final outerPaint = Paint()
    ..color = color.withValues(alpha: 0.95)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2;
  final glowPaint = Paint()
    ..color = color.withValues(alpha: 0.2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8;
  final innerPaint = Paint()
    ..color = const Color(0xEEFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

  canvas.drawRRect(RRect.fromRectAndRadius(tileRect, radius), glowPaint);
  canvas.drawRRect(RRect.fromRectAndRadius(tileRect, radius), outerPaint);
  canvas.drawCircle(center, tileSize * 0.42, outerPaint);
  canvas.drawCircle(center, tileSize * 0.32, innerPaint);
}
