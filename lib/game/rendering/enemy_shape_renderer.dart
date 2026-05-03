import 'dart:ui';

import '../../domain/enemy/enemy_type.dart';

void drawEnemyShape(
  Canvas canvas, {
  required Size size,
  required EnemyType type,
  required Color color,
  double strokeWidth = 2,
  double facingAngle = 0,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final body = Paint()..color = color;
  final outline = Paint()
    ..color = const Color(0xFF07111D)
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  switch (type) {
    case EnemyType.normal:
      canvas.drawCircle(center, size.width * 0.42, body);
      canvas.drawCircle(center, size.width * 0.42, outline);
      canvas.drawCircle(
        center.translate(size.width * 0.11, -size.height * 0.12),
        size.width * 0.08,
        Paint()..color = const Color(0x99FFFFFF),
      );
    case EnemyType.fast:
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(facingAngle);
      final dart = Path()
        ..moveTo(size.width * 0.46, 0)
        ..lineTo(-size.width * 0.22, -size.height * 0.34)
        ..lineTo(-size.width * 0.08, 0)
        ..lineTo(-size.width * 0.22, size.height * 0.34)
        ..close();
      canvas.drawPath(dart, body);
      canvas.drawPath(dart, outline);
      canvas.drawCircle(
        Offset(size.width * 0.1, -size.height * 0.04),
        size.width * 0.09,
        Paint()..color = const Color(0xCCFFFFFF),
      );
      canvas.restore();
    case EnemyType.tank:
      final shell = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.9,
          height: size.height * 0.72,
        ),
        Radius.circular(size.width * 0.12),
      );
      canvas.drawRRect(shell, body);
      canvas.drawRRect(shell, outline);
      canvas.drawLine(
        center.translate(-size.width * 0.28, 0),
        center.translate(size.width * 0.28, 0),
        Paint()
          ..color = const Color(0x6607111D)
          ..strokeWidth = strokeWidth,
      );
    case EnemyType.boss:
      canvas.drawCircle(center, size.width * 0.48, body);
      canvas.drawCircle(center, size.width * 0.48, outline);
      final crown = Path()
        ..moveTo(center.dx - size.width * 0.34, center.dy - size.height * 0.2)
        ..lineTo(center.dx - size.width * 0.12, center.dy - size.height * 0.52)
        ..lineTo(center.dx, center.dy - size.height * 0.28)
        ..lineTo(center.dx + size.width * 0.12, center.dy - size.height * 0.52)
        ..lineTo(center.dx + size.width * 0.34, center.dy - size.height * 0.2);
      canvas.drawPath(
        crown,
        Paint()
          ..color = const Color(0xFFFFD45A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
  }
}
