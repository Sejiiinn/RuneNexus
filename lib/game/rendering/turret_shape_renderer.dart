import 'dart:math' as math;
import 'dart:ui';

import '../../domain/turret/turret_type.dart';

const double _turretShapeCoordinateSize = 112;

void drawTurretShape(
  Canvas canvas, {
  required Size size,
  required TurretType type,
  required Color color,
  double aimAngle = -math.pi / 2,
  double fireFeedback = 0,
  double animationTime = 0,
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

  if (type == TurretType.lightning) {
    _drawLightningTurretShape(
      canvas,
      center,
      scale,
      accent,
      outline,
      aimAngle,
      fireFeedback,
    );
    return;
  }

  if (type == TurretType.arrow) {
    _drawMachineGunTurretShape(
      canvas,
      center,
      scale,
      accent,
      outline,
      aimAngle,
      fireFeedback,
    );
    return;
  }

  if (type == TurretType.cannon) {
    _drawCannonTurretShape(
      canvas,
      center,
      scale,
      accent,
      outline,
      aimAngle,
      fireFeedback,
    );
    return;
  }

  if (type == TurretType.magic) {
    _drawFireTurretShape(
      canvas,
      center,
      scale * 1.06,
      accent,
      outline,
      aimAngle,
      fireFeedback,
      animationTime,
    );
    return;
  }

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
      break;
    case TurretType.cannon:
      break;
    case TurretType.sniper:
      _drawSniperHead(canvas, scale, accent, outline, fireFeedback);
    case TurretType.magic:
      break;
    case TurretType.frost:
      break;
    case TurretType.lightning:
      break;
  }
  canvas.restore();
}

Offset fireballOriginForTurret({
  required Offset center,
  required double size,
  double aimAngle = -math.pi / 2,
}) {
  return center.translate(
    math.cos(aimAngle) * size * 0.2,
    math.sin(aimAngle) * size * 0.2,
  );
}

void _drawMachineGunTurretShape(
  Canvas canvas,
  Offset center,
  double scale,
  Paint accent,
  Paint outline,
  double aimAngle,
  double fireFeedback,
) {
  final base = Paint()..color = const Color(0xFF121B25);
  final mount = Paint()..color = const Color(0xFF314653);
  final armor = Paint()..color = const Color(0xFF858E93);
  final receiver = Paint()..color = const Color(0xFF606B72);
  final receiverPanel = Paint()..color = const Color(0xFF26343E);
  final magazine = Paint()..color = const Color(0xFF283129);
  final muzzle = Paint()..color = const Color(0xFFD6CFAD);
  final innerOutline = Paint()
    ..color = outline.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = outline.strokeWidth * 0.68;
  final panelLine = Paint()
    ..color = const Color(0xFFFFF0A6).withValues(alpha: 0.72)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.015
    ..strokeCap = StrokeCap.round;

  canvas.save();
  canvas.translate(center.dx, center.dy);

  canvas.drawCircle(Offset.zero, scale * 0.38, base);
  canvas.drawCircle(Offset.zero, scale * 0.38, outline);
  canvas.drawCircle(Offset.zero, scale * 0.3, mount);
  canvas.drawCircle(Offset.zero, scale * 0.3, outline);
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-41, 7),
      Offset(-30, 22),
      Offset(-17, 35),
      Offset(-30, 31),
      Offset(-43, 18),
    ],
    armor,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(41, 7),
      Offset(30, 22),
      Offset(17, 35),
      Offset(30, 31),
      Offset(43, 18),
    ],
    armor,
    outline,
  );

  canvas.save();
  canvas.rotate(aimAngle + math.pi / 2);
  canvas.translate(0, scale * 0.06 * fireFeedback);

  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-19, 14),
      Offset(-16, -17),
      Offset(-8, -26),
      Offset(8, -26),
      Offset(16, -17),
      Offset(19, 14),
      Offset(8, 24),
      Offset(-8, 24),
    ],
    receiver,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-11, 11),
      Offset(-9, -13),
      Offset(9, -13),
      Offset(11, 11),
      Offset(4, 18),
      Offset(-4, 18),
    ],
    receiverPanel,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(-13, 14), Offset(13, 14), Offset(9, 29), Offset(-9, 29)],
    magazine,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(-11, -8), Offset(-11, -47), Offset(-2, -47), Offset(-2, -5)],
    accent,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(2, -5), Offset(2, -47), Offset(11, -47), Offset(11, -8)],
    accent,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-13, -44),
      Offset(-11, -53),
      Offset(-2, -53),
      Offset(-1, -44),
    ],
    muzzle,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(1, -44), Offset(2, -53), Offset(11, -53), Offset(13, -44)],
    muzzle,
    innerOutline,
  );
  for (final y in const [-35.0, -26.0]) {
    _drawLocalLine(canvas, scale, Offset(-10, y), Offset(-3, y), panelLine);
    _drawLocalLine(canvas, scale, Offset(3, y), Offset(10, y), panelLine);
  }
  canvas.drawCircle(Offset.zero, scale * 0.1, accent);
  canvas.drawCircle(Offset.zero, scale * 0.1, innerOutline);

  if (fireFeedback > 0) {
    final unit = scale / _turretShapeCoordinateSize;
    final flash = Path()
      ..moveTo(-7 * unit, -49 * unit)
      ..lineTo(-11 * unit, -55 * unit)
      ..lineTo(-3 * unit, -52 * unit)
      ..lineTo(0, -56 * unit)
      ..lineTo(3 * unit, -52 * unit)
      ..lineTo(11 * unit, -55 * unit)
      ..lineTo(7 * unit, -49 * unit)
      ..close();
    canvas.drawPath(
      flash,
      Paint()..color = const Color(0xFFFFF0A6).withValues(alpha: fireFeedback),
    );
  }

  canvas.restore();
  canvas.restore();
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

void _drawCannonTurretShape(
  Canvas canvas,
  Offset center,
  double scale,
  Paint accent,
  Paint outline,
  double aimAngle,
  double fireFeedback,
) {
  final base = Paint()..color = const Color(0xFF151B22);
  final mount = Paint()..color = const Color(0xFF344650);
  final armor = Paint()..color = const Color(0xFF7A8388);
  final carriage = Paint()..color = const Color(0xFF615B57);
  final carriagePanel = Paint()..color = const Color(0xFF302A27);
  final barrel = Paint()..color = accent.color.withValues(alpha: 0.78);
  final muzzle = Paint()..color = accent.color;
  final innerOutline = Paint()
    ..color = outline.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = outline.strokeWidth * 0.72;
  final panelLine = Paint()
    ..color = const Color(0xFFD8B08E).withValues(alpha: 0.62)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.018
    ..strokeCap = StrokeCap.round;
  final boreLine = Paint()
    ..color = const Color(0xFF160D0A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.055
    ..strokeCap = StrokeCap.round;

  canvas.save();
  canvas.translate(center.dx, center.dy);

  canvas.drawCircle(Offset.zero, scale * 0.38, base);
  canvas.drawCircle(Offset.zero, scale * 0.38, outline);
  canvas.drawCircle(Offset.zero, scale * 0.3, mount);
  canvas.drawCircle(Offset.zero, scale * 0.3, outline);
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-43, 4),
      Offset(-34, 25),
      Offset(-19, 39),
      Offset(-34, 34),
      Offset(-46, 17),
    ],
    armor,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(43, 4),
      Offset(34, 25),
      Offset(19, 39),
      Offset(34, 34),
      Offset(46, 17),
    ],
    armor,
    outline,
  );

  canvas.save();
  canvas.rotate(aimAngle + math.pi / 2);
  canvas.translate(0, scale * 0.08 * fireFeedback);

  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-24, 19),
      Offset(-17, -10),
      Offset(-10, -20),
      Offset(10, -20),
      Offset(17, -10),
      Offset(24, 19),
      Offset(8, 29),
      Offset(-8, 29),
    ],
    carriage,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-15, 16),
      Offset(-10, -3),
      Offset(10, -3),
      Offset(15, 16),
      Offset(5, 23),
      Offset(-5, 23),
    ],
    carriagePanel,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-17, -5),
      Offset(-17, -40),
      Offset(-10, -49),
      Offset(10, -49),
      Offset(17, -40),
      Offset(17, -5),
      Offset(8, 6),
      Offset(-8, 6),
    ],
    barrel,
    innerOutline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-23, -40),
      Offset(-19, -53),
      Offset(19, -53),
      Offset(23, -40),
      Offset(16, -33),
      Offset(-16, -33),
    ],
    muzzle,
    innerOutline,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(-13, -49),
    const Offset(13, -49),
    boreLine,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(-13, -15),
    const Offset(13, -15),
    panelLine,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(-14, -4),
    const Offset(14, -4),
    panelLine,
  );
  canvas.drawCircle(Offset(0, scale * 0.11), scale * 0.095, accent);
  canvas.drawCircle(Offset(0, scale * 0.11), scale * 0.095, innerOutline);

  if (fireFeedback > 0) {
    final unit = scale / _turretShapeCoordinateSize;
    final flash = Path()
      ..moveTo(0, -56 * unit)
      ..lineTo(7 * unit, -49 * unit)
      ..lineTo(15 * unit, -52 * unit)
      ..lineTo(10 * unit, -44 * unit)
      ..lineTo(18 * unit, -39 * unit)
      ..lineTo(6 * unit, -40 * unit)
      ..lineTo(0, -33 * unit)
      ..lineTo(-6 * unit, -40 * unit)
      ..lineTo(-18 * unit, -39 * unit)
      ..lineTo(-10 * unit, -44 * unit)
      ..lineTo(-15 * unit, -52 * unit)
      ..lineTo(-7 * unit, -49 * unit)
      ..close();
    canvas.drawPath(
      flash,
      Paint()..color = const Color(0xFFFFE4A3).withValues(alpha: fireFeedback),
    );
    canvas.drawCircle(
      Offset(scale * 0.17, -scale * 0.38),
      scale * 0.16 * fireFeedback,
      Paint()
        ..color = const Color(
          0xFFB8B8A8,
        ).withValues(alpha: 0.22 * fireFeedback),
    );
  }

  canvas.restore();
  canvas.restore();
}

void _drawFireTurretShape(
  Canvas canvas,
  Offset center,
  double scale,
  Paint accent,
  Paint outline,
  double aimAngle,
  double fireFeedback,
  double animationTime,
) {
  final base = Paint()..color = const Color(0xFF171D24);
  final armor = Paint()..color = const Color(0xFF555D64);
  final dark = Paint()..color = const Color(0xFF282D33);
  final chamber = Paint()..color = const Color(0xFF3A2926);
  final vent = Paint()..color = const Color(0xFF767C80);
  final panelLine = Paint()
    ..color = const Color(0xFFAEB5BA).withValues(alpha: 0.45)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.014
    ..strokeCap = StrokeCap.round;

  canvas.save();
  canvas.translate(center.dx, center.dy);

  canvas.drawCircle(
    Offset.zero,
    scale * (0.38 + fireFeedback * 0.03),
    Paint()..color = accent.color.withValues(alpha: 0.1 + fireFeedback * 0.08),
  );

  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-35, 27),
      Offset(-41, 5),
      Offset(-32, -26),
      Offset(-10, -39),
      Offset(18, -36),
      Offset(38, -19),
      Offset(42, 10),
      Offset(29, 33),
      Offset(2, 40),
      Offset(-24, 35),
    ],
    base,
    outline,
  );
  canvas.drawCircle(Offset.zero, scale * 0.3, armor);
  canvas.drawCircle(Offset.zero, scale * 0.3, outline);
  canvas.drawCircle(Offset.zero, scale * 0.235, dark);
  canvas.drawCircle(Offset.zero, scale * 0.235, outline);

  canvas.save();
  canvas.rotate(aimAngle + math.pi / 2);
  canvas.translate(0, scale * 0.025 * fireFeedback);

  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-26, 27),
      Offset(-26, -16),
      Offset(-14, -33),
      Offset(14, -33),
      Offset(26, -16),
      Offset(26, 27),
      Offset(14, 39),
      Offset(-14, 39),
    ],
    chamber,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-20, -24),
      Offset(-20, -50),
      Offset(-7, -50),
      Offset(-7, -25),
    ],
    vent,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(7, -25), Offset(7, -50), Offset(20, -50), Offset(20, -24)],
    vent,
    outline,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(-19, -40),
    const Offset(-8, -40),
    panelLine,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(8, -40),
    const Offset(19, -40),
    panelLine,
  );

  canvas.restore();

  // 회전 프레임 후방을 따르되 불꽃 자체는 화면 위쪽을 유지하는 노심 결합부
  final coreAnchorDistance = -scale * (0.085 + fireFeedback * 0.025);
  final coreAnchor = Offset(
    math.cos(aimAngle) * coreAnchorDistance,
    math.sin(aimAngle) * coreAnchorDistance,
  );
  canvas.save();
  canvas.translate(coreAnchor.dx, coreAnchor.dy);

  canvas.drawCircle(Offset.zero, scale * (0.19 + fireFeedback * 0.025), accent);
  canvas.drawCircle(Offset.zero, scale * 0.19, outline);

  // 중앙 노심에서 위로 뻗는 서로 다른 위상의 3겹 불꽃
  final outerSway = math.sin(animationTime * 5.1);
  final middleSway = math.sin(animationTime * 7.2 + 1.3);
  final innerSway = math.sin(animationTime * 9.4 + 2.1);
  _drawAnimatedFlameLayer(
    canvas,
    scale,
    bottomY: 12,
    halfWidth: 18,
    height: 45 + math.sin(animationTime * 6.2) * 2.2 + fireFeedback * 6,
    sway: outerSway * 3.6,
    paint: accent,
    outline: outline,
  );
  _drawAnimatedFlameLayer(
    canvas,
    scale,
    bottomY: 10,
    halfWidth: 12,
    height: 34 + math.sin(animationTime * 8.1 + 0.8) * 1.8 + fireFeedback * 4,
    sway: middleSway * 2.8,
    paint: Paint()..color = const Color(0xFFFFA13A),
  );
  _drawAnimatedFlameLayer(
    canvas,
    scale,
    bottomY: 8,
    halfWidth: 6,
    height: 23 + math.sin(animationTime * 10.7 + 1.7) * 1.4 + fireFeedback * 2,
    sway: innerSway * 1.8,
    paint: Paint()..color = const Color(0xFFFFE7A0),
  );

  if (fireFeedback > 0) {
    canvas.drawCircle(
      Offset(0, -scale * 0.1),
      scale * (0.29 + fireFeedback * 0.1),
      Paint()
        ..color = accent.color.withValues(alpha: 0.18 * fireFeedback)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.035,
    );
  }

  canvas.restore();
  canvas.restore();
}

void _drawAnimatedFlameLayer(
  Canvas canvas,
  double scale, {
  required double bottomY,
  required double halfWidth,
  required double height,
  required double sway,
  required Paint paint,
  Paint? outline,
}) {
  final unit = scale / _turretShapeCoordinateSize;
  final path = Path()
    ..moveTo(0, bottomY * unit)
    ..quadraticBezierTo(
      halfWidth * unit,
      (bottomY - height * 0.35) * unit,
      sway * unit,
      (bottomY - height) * unit,
    )
    ..quadraticBezierTo(
      -halfWidth * unit,
      (bottomY - height * 0.32) * unit,
      0,
      bottomY * unit,
    )
    ..close();
  canvas.drawPath(path, paint);
  if (outline != null) {
    canvas.drawPath(path, outline);
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

void _drawLightningTurretShape(
  Canvas canvas,
  Offset center,
  double scale,
  Paint accent,
  Paint outline,
  double aimAngle,
  double fireFeedback,
) {
  final base = Paint()..color = const Color(0xFF111F2B);
  final mount = Paint()..color = const Color(0xFF1C303C);
  final armor = Paint()..color = const Color(0xFF465B69);
  final dark = Paint()..color = const Color(0xFF14232E);
  final muzzle = Paint()..color = const Color(0xFF6F8792);
  final glow = Paint()..color = accent.color.withValues(alpha: 0.12);
  final glowStroke = Paint()
    ..color = accent.color.withValues(alpha: 0.32)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.012;
  final panelLine = Paint()
    ..color = const Color(0xFF83A4B4).withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.011;

  canvas.save();
  canvas.translate(center.dx, center.dy);

  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-46, 28),
      Offset(-34, -34),
      Offset(-16, -50),
      Offset(16, -50),
      Offset(34, -34),
      Offset(46, 28),
      Offset(26, 51),
      Offset(-26, 51),
    ],
    glow,
    glowStroke,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-42, 25),
      Offset(-31, -27),
      Offset(-13, -43),
      Offset(13, -43),
      Offset(31, -27),
      Offset(42, 25),
      Offset(22, 46),
      Offset(-22, 46),
    ],
    base,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-31, 18),
      Offset(-23, -18),
      Offset(0, -31),
      Offset(23, -18),
      Offset(31, 18),
      Offset(16, 34),
      Offset(-16, 34),
    ],
    mount,
    outline,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(-31, 18),
    const Offset(31, 18),
    panelLine,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(-23, -18),
    const Offset(23, -18),
    panelLine,
  );
  _drawLocalLine(
    canvas,
    scale,
    const Offset(0, -31),
    const Offset(0, 34),
    panelLine,
  );

  canvas.rotate(aimAngle + math.pi / 2);

  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(-31, 23), Offset(-25, -49), Offset(-8, -49), Offset(-8, 23)],
    armor,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(8, 23), Offset(8, -49), Offset(25, -49), Offset(31, 23)],
    armor,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-26, 17),
      Offset(-21, -42),
      Offset(-12, -42),
      Offset(-12, 17),
    ],
    dark,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(12, 17), Offset(12, -42), Offset(21, -42), Offset(26, 17)],
    dark,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-29, -47),
      Offset(-25, -60),
      Offset(-8, -60),
      Offset(-5, -47),
    ],
    muzzle,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [Offset(5, -47), Offset(8, -60), Offset(25, -60), Offset(29, -47)],
    muzzle,
    outline,
  );
  _drawLocalPolygon(
    canvas,
    scale,
    const [
      Offset(-34, 26),
      Offset(-26, 15),
      Offset(26, 15),
      Offset(34, 26),
      Offset(21, 39),
      Offset(-21, 39),
    ],
    mount,
    outline,
  );

  final coilShadow = Paint()
    ..color = const Color(0xFF030812)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.048
    ..strokeCap = StrokeCap.square;
  final coilPaint = Paint()
    ..color = accent.color.withValues(alpha: 0.92)
    ..style = PaintingStyle.stroke
    ..strokeWidth = scale * 0.029
    ..strokeCap = StrokeCap.square;
  for (final pair in const [
    [Offset(-30, -31), Offset(-7, -31)],
    [Offset(-31, -16), Offset(-8, -16)],
    [Offset(-32, -1), Offset(-8, -1)],
    [Offset(7, -31), Offset(30, -31)],
    [Offset(8, -16), Offset(31, -16)],
    [Offset(8, -1), Offset(32, -1)],
  ]) {
    _drawLocalLine(canvas, scale, pair[0], pair[1], coilShadow);
    _drawLocalLine(canvas, scale, pair[0], pair[1], coilPaint);
  }

  final coreRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset.zero,
      width: scale * 0.22,
      height: scale * 0.22,
    ),
    Radius.circular(scale * 0.012),
  );
  canvas.drawRRect(coreRect, accent);
  canvas.drawRRect(coreRect, outline);
  canvas.drawCircle(
    Offset.zero,
    scale * (0.04 + fireFeedback * 0.02),
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9),
  );

  if (fireFeedback > 0) {
    final pulsePaint = Paint()
      ..color = accent.color.withValues(alpha: 0.42 * fireFeedback)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.028
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final corePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: fireFeedback)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.012
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final spark = _localPath(const [
      Offset(-15, -57),
      Offset(0, -68),
      Offset(15, -57),
    ], scale);
    canvas.drawPath(spark, pulsePaint);
    canvas.drawPath(spark, corePaint);
    canvas.drawCircle(
      Offset.zero,
      scale * (0.28 + fireFeedback * 0.12),
      Paint()
        ..color = accent.color.withValues(alpha: 0.18 * fireFeedback)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.025,
    );
  }

  canvas.restore();
}

Path _localPath(List<Offset> points, double scale) {
  final unit = scale / _turretShapeCoordinateSize;
  final path = Path()..moveTo(points.first.dx * unit, points.first.dy * unit);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx * unit, point.dy * unit);
  }
  return path;
}

void _drawLocalPolygon(
  Canvas canvas,
  double scale,
  List<Offset> points,
  Paint fill,
  Paint outline,
) {
  final path = _localPath(points, scale)..close();
  canvas.drawPath(path, fill);
  canvas.drawPath(path, outline);
}

void _drawLocalLine(
  Canvas canvas,
  double scale,
  Offset start,
  Offset end,
  Paint paint,
) {
  final unit = scale / _turretShapeCoordinateSize;
  canvas.drawLine(start * unit, end * unit, paint);
}
