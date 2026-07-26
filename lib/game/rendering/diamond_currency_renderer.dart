import 'dart:ui';

void drawDiamondCurrencyGlyph(Canvas canvas, Size size) {
  canvas.save();
  canvas.scale(size.width / 48, size.height / 48);
  final outline = Path()
    ..moveTo(16, 8)
    ..lineTo(32, 8)
    ..lineTo(46, 19)
    ..lineTo(24, 45)
    ..lineTo(2, 19)
    ..close();
  canvas.drawPath(
    outline,
    Paint()
      ..color = const Color(0xFF8EE6FF).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
  );
  canvas.drawPath(
    outline,
    Paint()
      ..shader = Gradient.linear(
        const Offset(14.4, 0),
        const Offset(33.6, 48),
        const [Color(0xFFEAFBFF), Color(0xFF7FDBFF), Color(0xFF1F93C8)],
        const [0, 0.5, 1],
      ),
  );
  const edge = Color(0xFFCFF4FF);
  canvas.drawPath(
    outline,
    Paint()
      ..style = PaintingStyle.stroke
      ..color = edge
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round,
  );

  // 크라운 테이블 하이라이트
  final crown = Path()
    ..moveTo(16, 8)
    ..lineTo(32, 8)
    ..lineTo(35, 19)
    ..lineTo(13, 19)
    ..close();
  canvas.drawPath(
    crown,
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18),
  );
  final facetPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = edge.withValues(alpha: 0.65)
    ..strokeWidth = 0.85;
  canvas.drawLine(const Offset(2, 19), const Offset(46, 19), facetPaint);
  for (final segment in const [
    [Offset(16, 8), Offset(13, 19)],
    [Offset(32, 8), Offset(35, 19)],
    [Offset(16, 8), Offset(24, 45)],
    [Offset(32, 8), Offset(24, 45)],
    [Offset(13, 19), Offset(24, 45)],
    [Offset(35, 19), Offset(24, 45)],
  ]) {
    canvas.drawLine(segment[0], segment[1], facetPaint);
  }
  canvas.restore();
}
