import 'package:flutter/material.dart';

import '../../domain/gem/gem_type.dart';
import '../../game/rendering/diamond_currency_renderer.dart';

/// 젬과 재화의 공용 아이콘 위젯 모음.

// 색을 밝게(amt>0)/어둡게(amt<0) 보정.
Color _adj(Color c, double amt) {
  double ch(double v) => amt >= 0 ? v + (1 - v) * amt : v * (1 + amt);
  return Color.from(
    alpha: c.a,
    red: ch(c.r).clamp(0.0, 1.0),
    green: ch(c.g).clamp(0.0, 1.0),
    blue: ch(c.b).clamp(0.0, 1.0),
  );
}

void _poly(Canvas c, List<Offset> pts, Paint p, {bool close = false}) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx, pts[i].dy);
  }
  if (close) path.close();
  c.drawPath(path, p);
}

Path _pathOf(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx, pts[i].dy);
  }
  return path..close();
}

/// 기능별 원석 형태를 유지하는 투명 이미지 아이콘.
class GemIcon extends StatelessWidget {
  const GemIcon(this.type, {this.size = 16, this.color, super.key});

  final GemType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image(
    image: gemIconImageProvider(type),
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    color: color,
    colorBlendMode: color == null ? null : BlendMode.modulate,
    excludeFromSemantics: true,
  );
}

ImageProvider<Object> gemIconImageProvider(GemType type) {
  // 작은 HUD와 보상 아이콘이 동일한 축소 디코딩 캐시 공유.
  return ResizeImage.resizeIfNeeded(
    128,
    128,
    AssetImage('assets/images/gems/${type.name}.png'),
  );
}

// ===== 재화 아이콘 =====

/// 다이아(프리미엄 재화) — 청록빛 룬 각인 보석.
class DiamondCurrencyIcon extends StatelessWidget {
  const DiamondCurrencyIcon({this.size = 16, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    diamondCurrencyImageAsset,
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

/// 룬(메타 재화) — 골드 룬석 타블렛 + 발광 시질.
class RuneCurrencyIcon extends StatelessWidget {
  const RuneCurrencyIcon({this.size = 16, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _RuneCurrencyPainter()),
  );
}

class _RuneCurrencyPainter extends CustomPainter {
  static const _sigil = Color(0xFFFFD78A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48.0, size.height / 48.0);
    final outline = const [
      Offset(24, 2),
      Offset(42, 12),
      Offset(42, 36),
      Offset(24, 46),
      Offset(6, 36),
      Offset(6, 12),
    ];
    final path = _pathOf(outline);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE7C66A).withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.3),
    );
    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2B2414), Color(0xFF15100A)],
    ).createShader(const Rect.fromLTWH(0, 0, 48, 48));
    canvas.drawPath(path, Paint()..shader = shader);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF6E5A32)
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    // 발광 시질(다이아 + 십자).
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..color = _sigil.withValues(alpha: 0.5)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.9);
    final sig = Paint()
      ..style = PaintingStyle.stroke
      ..color = _sigil
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in [glow, sig]) {
      _poly(
        canvas,
        const [Offset(24, 9), Offset(35, 24), Offset(24, 39), Offset(13, 24)],
        p,
        close: true,
      );
      canvas.drawLine(const Offset(24, 13), const Offset(24, 35), p);
      canvas.drawLine(const Offset(16, 24), const Offset(32, 24), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 골드(전투 중 재화) — 밝은 골드 코인.
class GoldCurrencyIcon extends StatelessWidget {
  const GoldCurrencyIcon({this.size = 16, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _GoldCurrencyPainter()),
  );
}

class _GoldCurrencyPainter extends CustomPainter {
  static const _gold = Color(0xFFFFD166);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48.0, size.height / 48.0);
    const center = Offset(24, 24);
    final edge = _adj(_gold, 0.7);
    final dark = _adj(_gold, -0.4);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = _gold.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    final shader = RadialGradient(
      center: const Alignment(-0.2, -0.36),
      radius: 0.72,
      colors: [edge, _gold, dark],
      stops: const [0, 0.6, 1],
    ).createShader(Rect.fromCircle(center: center, radius: 20));
    canvas.drawCircle(center, 20, Paint()..shader = shader);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = edge
        ..strokeWidth = 1.5,
    );
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..color = dark.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    canvas.drawCircle(center, 15.5, inner);
    // 중앙 룬 각인(다이아 핍).
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..color = dark.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    _poly(
      canvas,
      const [Offset(24, 15), Offset(31, 24), Offset(24, 33), Offset(17, 24)],
      mark,
      close: true,
    );
    // 상단 글린트.
    final glint = Path()
      ..moveTo(14, 18)
      ..arcToPoint(const Offset(26, 12), radius: const Radius.circular(12));
    canvas.drawPath(
      glint,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
