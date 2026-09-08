import 'dart:math' as math;

import 'package:flutter/painting.dart';

void drawGemRewardTargetHighlight(
  Canvas canvas, {
  required Rect tileRect,
  required bool requiresReplacement,
  required double animationTime,
  required double visualScale,
}) {
  if (tileRect.isEmpty || visualScale <= 0) {
    return;
  }

  const edgeColor = Color(0xFFFFE989);
  const glowColor = Color(0xFFFFD95C);
  final scale = math.min(visualScale, tileRect.shortestSide / 24);
  final boundary = tileRect.deflate(2 * scale);
  final cornerRadius = Radius.circular(3 * scale);
  final outline = RRect.fromRectAndRadius(boundary, cornerRadius);
  // 타일 주변에만 머무르는 느린 밝기 변화.
  final pulse = 0.9 + math.sin(animationTime * math.pi / 1.8) * 0.1;
  canvas.drawRRect(
    outline,
    Paint()
      ..color = glowColor.withValues(alpha: 0.11 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * scale,
  );
  canvas.drawRRect(
    outline,
    Paint()
      ..color = glowColor.withValues(alpha: 0.22 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * scale,
  );
  canvas.drawRRect(
    outline,
    Paint()
      ..color = edgeColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 * scale,
  );

  if (!requiresReplacement) {
    return;
  }

  // 만석 대상의 이중 테두리와 교체 표식.
  canvas.drawRRect(
    RRect.fromRectAndRadius(boundary.deflate(3 * scale), cornerRadius),
    Paint()
      ..color = edgeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * scale,
  );
  final badgeRadius = 7.5 * scale;
  final badgeCenter = Offset(
    boundary.right - 2 * scale,
    boundary.top + 2 * scale,
  );
  canvas.drawCircle(
    badgeCenter,
    badgeRadius + 1.5 * scale,
    Paint()..color = glowColor.withValues(alpha: 0.15 * pulse),
  );
  canvas.drawCircle(
    badgeCenter,
    badgeRadius,
    Paint()..color = const Color(0xFF101A20),
  );
  final badgeStroke = Paint()
    ..color = edgeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.15 * scale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawCircle(badgeCenter, badgeRadius, badgeStroke);

  final arrowRadius = badgeRadius * 0.48;
  final arrowRect = Rect.fromCircle(center: badgeCenter, radius: arrowRadius);
  for (final startAngle in [-math.pi * 0.85, math.pi * 0.15]) {
    final endAngle = startAngle + math.pi * 0.7;
    canvas.drawArc(arrowRect, startAngle, math.pi * 0.7, false, badgeStroke);
    final tip = Offset(
      badgeCenter.dx + math.cos(endAngle) * arrowRadius,
      badgeCenter.dy + math.sin(endAngle) * arrowRadius,
    );
    final tangent = Offset(-math.sin(endAngle), math.cos(endAngle));
    final radial = Offset(math.cos(endAngle), math.sin(endAngle));
    final arrowhead = Path()
      ..moveTo(
        tip.dx - tangent.dx * 2.2 * scale + radial.dx * 1.6 * scale,
        tip.dy - tangent.dy * 2.2 * scale + radial.dy * 1.6 * scale,
      )
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - tangent.dx * 2.2 * scale - radial.dx * 1.6 * scale,
        tip.dy - tangent.dy * 2.2 * scale - radial.dy * 1.6 * scale,
      );
    canvas.drawPath(arrowhead, badgeStroke);
  }
}
