import 'dart:math' as math;

import 'package:flutter/painting.dart';

void drawCoreSkillCooldownBar(
  Canvas canvas, {
  required Offset center,
  required double tileSize,
  required double progress,
  required Color accent,
  required bool active,
}) {
  final barWidth = tileSize * 0.86;
  final barHeight = math.max(4.0, tileSize * 0.11);
  final topLeft = Offset(center.dx - barWidth / 2, center.dy + tileSize * 0.56);
  final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, barWidth, barHeight);
  final radius = Radius.circular(barHeight / 2);
  final background = RRect.fromRectAndRadius(rect, radius);
  final fillWidth = (barWidth * progress).clamp(0.0, barWidth).toDouble();
  final fillRect = Rect.fromLTWH(rect.left, rect.top, fillWidth, rect.height);
  final activeGlow = active ? 1.0 : 0.0;

  canvas.drawRRect(
    background.inflate(1.8),
    Paint()..color = const Color(0xEE02070D),
  );
  canvas.drawRRect(background, Paint()..color = const Color(0xAA102434));
  if (fillWidth > 0) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, radius),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(accent, const Color(0xFF02070D), 0.35)!,
            Color.lerp(accent, const Color(0xFFFFFFFF), activeGlow * 0.55)!,
          ],
        ).createShader(rect),
    );
  }
  canvas.drawRRect(
    background,
    Paint()
      ..color = accent.withValues(alpha: 0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
}
