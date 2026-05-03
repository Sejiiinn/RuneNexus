import 'dart:math' as math;
import 'dart:ui';

import '../../domain/turret/turret_type.dart';

void drawTurretShape(
  Canvas canvas, {
  required Size size,
  required TurretType type,
  required Color color,
  double aimAngle = -math.pi / 2,
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
    _drawFireHead(canvas, center, scale, accent, outline);
    return;
  }

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(aimAngle);
  switch (type) {
    case TurretType.arrow:
      _drawMachineGunHead(canvas, scale, accent, outline);
    case TurretType.cannon:
      _drawCannonHead(canvas, scale, accent, outline);
    case TurretType.magic:
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
}

void _drawCannonHead(Canvas canvas, double scale, Paint accent, Paint outline) {
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
}

void _drawFireHead(
  Canvas canvas,
  Offset center,
  double scale,
  Paint accent,
  Paint outline,
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

  final flame = Path()
    ..moveTo(center.dx + scale * 0.05, center.dy - scale * 0.45)
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
    scale * 0.1,
    Paint()..color = const Color(0xFFFFD45A),
  );
}
