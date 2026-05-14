import 'dart:math' as math;
import 'dart:ui';

import '../../domain/turret/turret_type.dart';

void drawTurretShape(
  Canvas canvas, {
  required Size size,
  required TurretType type,
  required Color color,
  double aimAngle = -math.pi / 2,
  double fireFeedback = 0,
  double strokeWidth = 2,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final scale = size.shortestSide;
  final base = Paint()..color = const Color(0xFF1A2533);
  final accent = Paint()..color = color;
  final outline = Paint()
    ..color = const Color(0xFF050A12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  final foot = Rect.fromCenter(
    center: Offset(center.dx, center.dy + scale * 0.17),
    width: scale * 0.68,
    height: scale * 0.24,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(foot, Radius.circular(scale * 0.05)),
    base,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(foot, Radius.circular(scale * 0.05)),
    outline,
  );
  canvas.drawCircle(center, scale * 0.38, base);
  canvas.drawCircle(center, scale * 0.38, outline);
  canvas.drawCircle(
    center,
    scale * 0.18,
    Paint()..color = color.withValues(alpha: 0.26),
  );

  if (type == TurretType.magic) {
    _drawFireHead(canvas, center, scale, accent, outline, fireFeedback);
    return;
  }
  if (type == TurretType.frost) {
    _drawFrostHead(canvas, center, scale, accent, outline, fireFeedback);
    return;
  }

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(aimAngle);
  canvas.translate(-scale * 0.08 * fireFeedback, 0);
  switch (type) {
    case TurretType.arrow:
      _drawMachineGunHead(canvas, scale, accent, outline, fireFeedback);
    case TurretType.cannon:
      _drawCannonHead(canvas, scale, accent, outline, fireFeedback);
    case TurretType.sniper:
      _drawSniperHead(canvas, scale, accent, outline, fireFeedback);
    case TurretType.magic:
      break;
    case TurretType.frost:
      break;
  }
  canvas.restore();
}

Offset fireballOriginForTurret({required Offset center, required double size}) {
  return center.translate(0, -size * 0.2);
}

void _drawMachineGunHead(
  Canvas canvas,
  double scale,
  Paint accent,
  Paint outline,
  double fireFeedback,
) {
  for (final y in [-scale * 0.1, scale * 0.1]) {
    final barrel = RRect.fromRectAndRadius(
      Rect.fromLTWH(-scale * 0.04, y - scale * 0.05, scale * 0.58, scale * 0.1),
      Radius.circular(scale * 0.03),
    );
    canvas.drawRRect(barrel, accent);
    canvas.drawRRect(barrel, outline);
  }
  canvas.drawCircle(Offset.zero, scale * 0.15, accent);
  canvas.drawCircle(Offset.zero, scale * 0.15, outline);
  if (fireFeedback > 0) {
    _drawMuzzleFlash(
      canvas,
      Offset(scale * 0.58, 0),
      scale,
      fireFeedback,
      0.18,
    );
  }
}

void _drawSniperHead(
  Canvas canvas,
  double scale,
  Paint accent,
  Paint outline,
  double fireFeedback,
) {
  final barrel = RRect.fromRectAndRadius(
    Rect.fromLTWH(-scale * 0.12, -scale * 0.055, scale * 0.78, scale * 0.11),
    Radius.circular(scale * 0.025),
  );
  final stock = Path()
    ..moveTo(-scale * 0.24, -scale * 0.13)
    ..lineTo(scale * 0.08, -scale * 0.08)
    ..lineTo(scale * 0.08, scale * 0.08)
    ..lineTo(-scale * 0.24, scale * 0.13)
    ..close();
  final lens = Rect.fromCenter(
    center: Offset(scale * 0.14, -scale * 0.13),
    width: scale * 0.28,
    height: scale * 0.08,
  );
  canvas.drawPath(stock, Paint()..color = const Color(0xFF223347));
  canvas.drawPath(stock, outline);
  canvas.drawRRect(barrel, accent);
  canvas.drawRRect(barrel, outline);
  canvas.drawOval(lens, Paint()..color = const Color(0xFFE8FBFF));
  canvas.drawOval(lens, outline);
  canvas.drawCircle(Offset.zero, scale * 0.14, accent);
  canvas.drawCircle(Offset.zero, scale * 0.14, outline);
  if (fireFeedback > 0) {
    canvas.drawLine(
      Offset(scale * 0.66, 0),
      Offset(scale * (0.9 + fireFeedback * 0.25), 0),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: fireFeedback)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = scale * 0.045,
    );
  }
}

void _drawCannonHead(
  Canvas canvas,
  double scale,
  Paint accent,
  Paint outline,
  double fireFeedback,
) {
  final barrel = RRect.fromRectAndRadius(
    Rect.fromLTWH(-scale * 0.08, -scale * 0.14, scale * 0.66, scale * 0.28),
    Radius.circular(scale * 0.06),
  );
  final muzzle = RRect.fromRectAndRadius(
    Rect.fromLTWH(scale * 0.38, -scale * 0.18, scale * 0.24, scale * 0.36),
    Radius.circular(scale * 0.05),
  );
  canvas.drawRRect(barrel, accent);
  canvas.drawRRect(barrel, outline);
  canvas.drawRRect(muzzle, Paint()..color = const Color(0xFF2D1E18));
  canvas.drawRRect(muzzle, outline);
  canvas.drawCircle(Offset.zero, scale * 0.17, accent);
  canvas.drawCircle(Offset.zero, scale * 0.17, outline);
  if (fireFeedback > 0) {
    _drawMuzzleFlash(
      canvas,
      Offset(scale * 0.66, 0),
      scale,
      fireFeedback,
      0.28,
    );
    canvas.drawCircle(
      Offset(scale * 0.76, scale * 0.08),
      scale * 0.18 * fireFeedback,
      Paint()
        ..color = const Color(
          0xFFB8B8A8,
        ).withValues(alpha: 0.22 * fireFeedback),
    );
  }
}

void _drawFireHead(
  Canvas canvas,
  Offset center,
  double scale,
  Paint accent,
  Paint outline,
  double fireFeedback,
) {
  final brazierCenter = center.translate(0, scale * 0.04);
  final brazier = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: brazierCenter,
      width: scale * 0.44,
      height: scale * 0.25,
    ),
    Radius.circular(scale * 0.06),
  );
  canvas.drawRRect(brazier, Paint()..color = const Color(0xFF2A2530));
  canvas.drawRRect(brazier, outline);

  final lift = scale * 0.08 * fireFeedback;
  final flameScale = 1 + fireFeedback * 0.18;
  final flame = Path()
    ..moveTo(
      center.dx + scale * 0.05,
      center.dy - scale * 0.45 * flameScale - lift,
    )
    ..quadraticBezierTo(
      center.dx + scale * 0.28,
      center.dy - scale * 0.03,
      center.dx + scale * 0.03,
      center.dy + scale * 0.15,
    )
    ..quadraticBezierTo(
      center.dx - scale * 0.24,
      center.dy - scale * 0.03,
      center.dx + scale * 0.05,
      center.dy - scale * 0.45,
    )
    ..close();
  canvas.drawPath(flame, accent);
  canvas.drawPath(flame, outline);
  canvas.drawCircle(
    center.translate(scale * 0.04, -scale * 0.07),
    scale * (0.1 + fireFeedback * 0.05),
    Paint()..color = const Color(0xFFFFD45A).withValues(alpha: 0.9),
  );
  if (fireFeedback > 0) {
    canvas.drawCircle(
      center.translate(0, -scale * 0.16),
      scale * (0.26 + fireFeedback * 0.18),
      Paint()
        ..color = accent.color.withValues(alpha: 0.18 * fireFeedback)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.035,
    );
  }
}

void _drawFrostHead(
  Canvas canvas,
  Offset center,
  double scale,
  Paint accent,
  Paint outline,
  double fireFeedback,
) {
  final core = Path()
    ..moveTo(center.dx, center.dy - scale * 0.35)
    ..lineTo(center.dx + scale * 0.24, center.dy)
    ..lineTo(center.dx, center.dy + scale * 0.35)
    ..lineTo(center.dx - scale * 0.24, center.dy)
    ..close();
  canvas.drawPath(core, accent);
  canvas.drawPath(core, outline);

  final rayPaint = Paint()
    ..color = accent.color.withValues(alpha: 0.88)
    ..strokeWidth = scale * 0.055
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3;
    final inner = Offset(
      center.dx + scale * 0.14 * math.cos(angle),
      center.dy + scale * 0.14 * math.sin(angle),
    );
    final outer = Offset(
      center.dx + scale * 0.34 * math.cos(angle),
      center.dy + scale * 0.34 * math.sin(angle),
    );
    canvas.drawLine(inner, outer, rayPaint);
  }
  canvas.drawCircle(
    center,
    scale * (0.1 + fireFeedback * 0.09),
    Paint()..color = const Color(0xFFE8FBFF),
  );
  if (fireFeedback > 0) {
    canvas.drawCircle(
      center,
      scale * (0.22 + fireFeedback * 0.16),
      Paint()
        ..color = const Color(
          0xFFE8FBFF,
        ).withValues(alpha: 0.34 * fireFeedback),
    );
    canvas.drawCircle(
      center,
      scale * (0.42 + fireFeedback * 0.2),
      Paint()
        ..color = accent.color.withValues(alpha: 0.5 * fireFeedback)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.035,
    );
  }
}

void _drawMuzzleFlash(
  Canvas canvas,
  Offset center,
  double scale,
  double fireFeedback,
  double sizeScale,
) {
  final length = scale * sizeScale * (0.75 + fireFeedback * 0.45);
  final width = scale * sizeScale * 0.42;
  final flash = Path()
    ..moveTo(center.dx + length, center.dy)
    ..lineTo(center.dx, center.dy - width)
    ..lineTo(center.dx - length * 0.24, center.dy)
    ..lineTo(center.dx, center.dy + width)
    ..close();
  canvas.drawPath(
    flash,
    Paint()..color = const Color(0xFFFFF0A6).withValues(alpha: fireFeedback),
  );
  canvas.drawCircle(
    center,
    width * 0.6,
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: fireFeedback),
  );
}
