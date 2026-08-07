import 'dart:math' as math;

import 'package:flutter/painting.dart';

const int _spaceStarCount = 86;

void drawGameSpaceBackground(
  Canvas canvas, {
  required Size size,
  required double animationTime,
}) {
  if (size.width <= 0 || size.height <= 0) {
    return;
  }

  final bounds = Offset.zero & size;
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF040913), Color(0xFF07111D), Color(0xFF02060C)],
      ).createShader(bounds),
  );

  final hazeCenter = Offset(size.width * 0.52, size.height * 0.18);
  final hazeRadius = math.max(size.width, size.height) * 0.44;
  canvas.drawCircle(
    hazeCenter,
    hazeRadius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1A4B66).withValues(alpha: 0.16),
          const Color(0xFF1A4B66).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: hazeCenter, radius: hazeRadius)),
  );

  for (var i = 0; i < _spaceStarCount; i++) {
    final x = _starUnit(i, 1) * size.width;
    final y = _starUnit(i, 2) * size.height;
    final speed = 0.75 + _starUnit(i, 3) * 1.8;
    final phase = _starUnit(i, 4) * math.pi * 2;
    final pulse = (math.sin(animationTime * speed + phase) + 1) / 2;
    final baseAlpha = 0.16 + _starUnit(i, 5) * 0.24;
    final alpha = baseAlpha + pulse * (0.18 + _starUnit(i, 6) * 0.24);
    final radius = 0.55 + _starUnit(i, 7) * 1.05;
    final color = Color.lerp(
      const Color(0xFFC7F2FF),
      const Color(0xFFFFFFFF),
      _starUnit(i, 8),
    )!.withValues(alpha: alpha.clamp(0.0, 0.82));

    if (radius > 1.25 && pulse > 0.62) {
      canvas.drawCircle(
        Offset(x, y),
        radius * (2.2 + pulse),
        Paint()..color = color.withValues(alpha: alpha * 0.16),
      );
    }
    canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
  }
}

void drawNexusScreenAlert(
  Canvas canvas, {
  required Size size,
  required double alert,
}) {
  if (alert <= 0) {
    return;
  }

  final fadeWidth = (math.min(size.width, size.height) * 0.12)
      .clamp(26.0, 54.0)
      .toDouble();
  final edgeColor = const Color(0xFFFF3D3D).withValues(alpha: 0.22 * alert);
  const transparent = Color(0x00FF3D3D);

  void drawEdge(Rect edgeRect, Alignment begin, Alignment end) {
    canvas.drawRect(
      edgeRect,
      Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: [edgeColor, transparent],
          stops: const [0.0, 1.0],
        ).createShader(edgeRect),
    );
  }

  drawEdge(
    Rect.fromLTWH(0, 0, size.width, fadeWidth),
    Alignment.topCenter,
    Alignment.bottomCenter,
  );
  drawEdge(
    Rect.fromLTWH(0, size.height - fadeWidth, size.width, fadeWidth),
    Alignment.bottomCenter,
    Alignment.topCenter,
  );
  drawEdge(
    Rect.fromLTWH(0, 0, fadeWidth, size.height),
    Alignment.centerLeft,
    Alignment.centerRight,
  );
  drawEdge(
    Rect.fromLTWH(size.width - fadeWidth, 0, fadeWidth, size.height),
    Alignment.centerRight,
    Alignment.centerLeft,
  );
}

double _starUnit(int index, int salt) {
  final value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453;
  return value - value.floorToDouble();
}
