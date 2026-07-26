import 'package:flutter/material.dart';

import '../../data/definitions/game_gem_data.dart';
import '../../domain/gem/gem_type.dart';
import '../../game/rendering/diamond_currency_renderer.dart';

/// 확정된 커스텀 아이콘 세트(젬 13종 + 재화)를 CustomPainter로 구현한 위젯 모음.
/// 젬은 공통 보석 컷(육각) 안에 젬별 특징을 새긴 내장 엠블럼으로 표현한다(PoE 스타일).

double _lum(Color c) => (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255;

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

// 중심(24,24) 기준 비율 축소.
List<Offset> _scaleEm(List<Offset> pts, double f) =>
    pts.map((p) => Offset(24 + (p.dx - 24) * f, 24 + (p.dy - 24) * f)).toList();

// 공용 보석 몸체(세로 육각 컷, 48 단위).
const List<Offset> _gemBody = [
  Offset(24, 3),
  Offset(40, 13),
  Offset(40, 34),
  Offset(24, 45),
  Offset(8, 34),
  Offset(8, 13),
];

// 젬 타입 → 내장 엠블럼 종류.
const Map<GemType, String> _gemEmblem = {
  GemType.attackSpeed: 'bolt',
  GemType.range: 'circle',
  GemType.physicalDamage: 'blade',
  GemType.elementalDamage: 'sparkle',
  GemType.lightWeapon: 'dart',
  GemType.heavyWeapon: 'hexbomb',
  GemType.damageOverTime: 'drop',
  GemType.explosion: 'burst',
  GemType.chain: 'chain',
  GemType.criticalChance: 'cross',
  GemType.aimSpeed: 'lens',
  GemType.damageAmplifier: 'triangle',
  GemType.armorPiercing: 'drill',
};

// 엠블럼 외곽 점(48 단위). circle/lens는 _drawEmblem에서 별도 처리.
const Map<String, List<Offset>> _emblemShapes = {
  'bolt': [
    Offset(28, 4),
    Offset(15, 26),
    Offset(23, 26),
    Offset(19, 44),
    Offset(34, 21),
    Offset(25, 21),
  ],
  'blade': [
    Offset(24, 4),
    Offset(31, 22),
    Offset(26, 30),
    Offset(24, 44),
    Offset(22, 30),
    Offset(17, 22),
  ],
  'sparkle': [
    Offset(24, 5),
    Offset(27, 21),
    Offset(43, 24),
    Offset(27, 27),
    Offset(24, 43),
    Offset(21, 27),
    Offset(5, 24),
    Offset(21, 21),
  ],
  'dart': [
    Offset(24, 4),
    Offset(32, 20),
    Offset(27, 20),
    Offset(27, 44),
    Offset(21, 44),
    Offset(21, 20),
    Offset(16, 20),
  ],
  'hexbomb': [
    Offset(24, 7),
    Offset(38, 16),
    Offset(38, 32),
    Offset(24, 41),
    Offset(10, 32),
    Offset(10, 16),
  ],
  'drop': [
    Offset(24, 4),
    Offset(31, 19),
    Offset(33, 31),
    Offset(24, 44),
    Offset(15, 31),
    Offset(17, 19),
  ],
  'burst': [
    Offset(24, 4),
    Offset(27, 16),
    Offset(37, 11),
    Offset(32, 21),
    Offset(44, 24),
    Offset(32, 27),
    Offset(37, 37),
    Offset(27, 32),
    Offset(24, 44),
    Offset(21, 32),
    Offset(11, 37),
    Offset(16, 27),
    Offset(4, 24),
    Offset(16, 21),
    Offset(11, 11),
    Offset(21, 16),
  ],
  'chain': [
    Offset(24, 5),
    Offset(33, 15),
    Offset(24, 24),
    Offset(33, 33),
    Offset(24, 43),
    Offset(15, 33),
    Offset(24, 24),
    Offset(15, 15),
  ],
  'cross': [
    Offset(22, 5),
    Offset(26, 5),
    Offset(26, 22),
    Offset(43, 22),
    Offset(43, 26),
    Offset(26, 26),
    Offset(26, 43),
    Offset(22, 43),
    Offset(22, 26),
    Offset(5, 26),
    Offset(5, 22),
    Offset(22, 22),
  ],
  'triangle': [Offset(24, 6), Offset(40, 39), Offset(8, 39)],
  'drill': [
    Offset(24, 44),
    Offset(32, 26),
    Offset(27, 26),
    Offset(27, 7),
    Offset(21, 7),
    Offset(21, 26),
    Offset(16, 26),
  ],
};

/// 젬 타입에 맞는 커스텀 보석 아이콘.
class GemIcon extends StatelessWidget {
  const GemIcon(this.type, {this.size = 16, this.color, super.key});

  final GemType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GemIconPainter(type, color ?? gameGems[type]!.color),
      ),
    );
  }
}

class _GemIconPainter extends CustomPainter {
  _GemIconPainter(this.type, this.color);

  final GemType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48.0, size.height / 48.0);

    final light = _lum(color) > 168;
    final rim = light ? _adj(color, -0.16) : _adj(color, 0.72);
    final bevel = _adj(color, -0.5);
    final emFill = light ? _adj(color, -0.42) : _adj(color, 0.6);
    final emRim = light ? _adj(color, -0.62) : _adj(color, -0.38);
    final emHalo = light ? _adj(color, -0.2) : _adj(color, 0.95);

    final bodyPath = _pathOf(_gemBody);

    // 외곽 발광.
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );

    // 보석 본체 그라데이션.
    final bodyShader = RadialGradient(
      center: const Alignment(-0.24, -0.44),
      radius: 0.76,
      colors: [_adj(color, 0.5), color, _adj(color, -0.46)],
      stops: const [0, 0.58, 1],
    ).createShader(const Rect.fromLTWH(0, 0, 48, 48));
    canvas.drawPath(bodyPath, Paint()..shader = bodyShader);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = rim
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );

    // 내부 베벨선.
    canvas.drawPath(
      _pathOf(_scaleEm(_gemBody, 0.84)),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = bevel.withValues(alpha: 0.45)
        ..strokeWidth = 0.8,
    );

    // 광택 하이라이트(몸체 내부로 클립).
    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(20, 15), width: 18, height: 9),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();

    _drawEmblem(canvas, _gemEmblem[type]!, emFill, emRim, emHalo);
    canvas.restore();
  }

  void _drawEmblem(
    Canvas canvas,
    String emblem,
    Color emFill,
    Color emRim,
    Color emHalo,
  ) {
    if (emblem == 'circle') {
      // 표적: 후광 + 동심 링 + 중심점.
      canvas.drawCircle(
        const Offset(24, 24),
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = emHalo.withValues(alpha: 0.5)
          ..strokeWidth = 3.4,
      );
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..color = emFill
        ..strokeWidth = 2.2;
      canvas.drawCircle(const Offset(24, 24), 8, ring);
      canvas.drawCircle(const Offset(24, 24), 3.6, ring);
      canvas.drawCircle(const Offset(24, 24), 1.5, Paint()..color = emFill);
      return;
    }
    if (emblem == 'lens') {
      // 렌즈/눈.
      final eye = Path()
        ..moveTo(9, 24)
        ..quadraticBezierTo(24, 14, 39, 24)
        ..quadraticBezierTo(24, 34, 9, 24)
        ..close();
      canvas.drawPath(
        eye,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = emHalo.withValues(alpha: 0.5)
          ..strokeWidth = 3.2,
      );
      canvas.drawPath(
        eye,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = emFill
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(const Offset(24, 24), 3, Paint()..color = emFill);
      return;
    }
    final shape = _emblemShapes[emblem]!;
    // 후광.
    canvas.drawPath(
      _pathOf(_scaleEm(shape, 0.7)),
      Paint()..color = emHalo.withValues(alpha: 0.32),
    );
    // 엠블럼 본체 + 음각 테두리.
    canvas.drawPath(_pathOf(_scaleEm(shape, 0.62)), Paint()..color = emFill);
    canvas.drawPath(
      _pathOf(_scaleEm(shape, 0.62)),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = emRim
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GemIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

// ===== 재화 아이콘 =====

/// 다이아(프리미엄 재화) — 아이스블루 브릴리언트 컷 보석.
class DiamondCurrencyIcon extends StatelessWidget {
  const DiamondCurrencyIcon({this.size = 16, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _DiamondCurrencyPainter()),
  );
}

class _DiamondCurrencyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    drawDiamondCurrencyGlyph(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
