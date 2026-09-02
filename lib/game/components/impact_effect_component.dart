import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

enum ImpactEffectStyle {
  spark,
  blast,
  sniperBlast,
  flame,
  frost,
  lightning,
  lightningBlast,
}

class ImpactEffectComponent extends PositionComponent {
  ImpactEffectComponent({
    required Vector2 position,
    required Color color,
    required this.style,
    required this.radius,
    this.cannonBlastSpriteSheet,
    int randomSeed = 0,
  }) : _color = color,
       _cannonShockArcs = _createCannonShockArcs(randomSeed),
       super(
         position: position,
         size: Vector2.all(radius * (_isBlastStyle(style) ? 2.45 : 2)),
         anchor: Anchor.center,
       );

  static const int cannonBlastFrameCount = 12;
  static const int _cannonBlastAtlasColumns = 4;
  static const int _cannonBlastAtlasRows = 3;

  final Color _color;
  final Image? cannonBlastSpriteSheet;
  final List<_CannonShockArc> _cannonShockArcs;
  final ImpactEffectStyle style;
  final double radius;
  final Paint _cannonBlastSpritePaint = Paint()
    ..filterQuality = FilterQuality.medium;
  double _age = 0;
  double get _lifeTime => style == ImpactEffectStyle.blast
      ? 0.42
      : _isBlastStyle(style)
      ? 0.36
      : 0.28;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _lifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / _lifeTime).clamp(0.0, 1.0);
    final alpha = 1 - progress;
    final center = Offset(size.x / 2, size.y / 2);

    switch (style) {
      case ImpactEffectStyle.spark:
        final paint = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.square;
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + progress * 0.55;
          final from = Offset(
            center.dx + radius * 0.12 * math.cos(angle),
            center.dy + radius * 0.12 * math.sin(angle),
          );
          final to = Offset(
            center.dx + radius * (0.48 + progress * 0.34) * math.cos(angle),
            center.dy + radius * (0.48 + progress * 0.34) * math.sin(angle),
          );
          paint.color = (i.isEven ? const Color(0xFFFFFFFF) : _color)
              .withValues(alpha: alpha * 0.9);
          canvas.drawLine(from, to, paint);
        }
        canvas.drawCircle(
          center,
          radius * (0.14 + progress * 0.08),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
        );
      case ImpactEffectStyle.blast:
        _drawCannonBlast(canvas, center, progress, alpha);
      case ImpactEffectStyle.sniperBlast:
        _drawBlast(
          canvas: canvas,
          center: center,
          progress: progress,
          alpha: alpha,
          shockColor: const Color(0xFFE8FBFF),
          flashColor: const Color(0xFFF7FDFF),
          coreColor: const Color(0xFF7FD8FF),
          shardAltColor: const Color(0xFF58C7F2),
          dustColor: const Color(0xFFA9D6E8),
        );
      case ImpactEffectStyle.flame:
        final flame = Paint()..color = _color.withValues(alpha: alpha * 0.7);
        for (var i = 0; i < 3; i++) {
          final xOffset = (i - 1) * radius * 0.16;
          final lift = radius * progress * (0.32 + i * 0.08);
          canvas.drawOval(
            Rect.fromCenter(
              center: center.translate(xOffset, -lift),
              width: radius * (0.22 + progress * 0.12),
              height: radius * (0.5 + progress * 0.18),
            ),
            flame,
          );
        }
        canvas.drawCircle(
          center,
          radius * (0.12 + progress * 0.1),
          Paint()
            ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.7),
        );
        for (var i = 0; i < 4; i++) {
          final angle = -math.pi * 0.8 + i * math.pi * 0.42;
          canvas.drawCircle(
            Offset(
              center.dx + math.cos(angle) * radius * (0.22 + progress * 0.38),
              center.dy + math.sin(angle) * radius * (0.2 + progress * 0.24),
            ),
            radius * 0.035,
            Paint()
              ..color = const Color(0xFFFFD45A).withValues(alpha: alpha * 0.9),
          );
        }
      case ImpactEffectStyle.frost:
        final ring = Paint()
          ..color = _color.withValues(alpha: alpha * 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(center, radius * (0.18 + progress * 0.82), ring);
        canvas.drawCircle(
          center,
          radius * (0.12 + progress * 0.36),
          Paint()..color = _color.withValues(alpha: alpha * 0.12),
        );
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + progress * 0.22;
          final inner = radius * (0.16 + progress * 0.2);
          final outer = radius * (0.42 + progress * 0.28);
          canvas.drawLine(
            Offset(
              center.dx + inner * math.cos(angle),
              center.dy + inner * math.sin(angle),
            ),
            Offset(
              center.dx + outer * math.cos(angle),
              center.dy + outer * math.sin(angle),
            ),
            ring,
          );
        }
        final shardPaint = Paint()
          ..color = const Color(0xFFE8FBFF).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5 + progress * 0.35;
          final shardCenter = Offset(
            center.dx + math.cos(angle) * radius * (0.34 + progress * 0.38),
            center.dy + math.sin(angle) * radius * (0.34 + progress * 0.38),
          );
          final shardSize = radius * 0.05;
          canvas.drawLine(
            shardCenter.translate(-shardSize, 0),
            shardCenter.translate(shardSize, 0),
            shardPaint,
          );
          canvas.drawLine(
            shardCenter.translate(0, -shardSize),
            shardCenter.translate(0, shardSize),
            shardPaint,
          );
        }
      case ImpactEffectStyle.lightning:
        _drawLightning(canvas, center, progress, alpha, radius);
      case ImpactEffectStyle.lightningBlast:
        _drawLightningBlast(canvas, center, progress, alpha);
    }
  }

  void _drawLightning(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
    double radius,
  ) {
    final ring = Paint()
      ..color = _color.withValues(alpha: alpha * 0.66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * (0.22 + progress * 0.62), ring);
    canvas.drawCircle(
      center,
      radius * (0.1 + progress * 0.12),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.8),
    );
    final spark = Paint()
      ..color = const Color(0xFF8CFFF3).withValues(alpha: alpha)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 + progress * 0.48;
      final inner = radius * (0.16 + progress * 0.12);
      final mid = radius * (0.36 + progress * 0.22);
      final outer = radius * (0.52 + progress * 0.28);
      final start = Offset(
        center.dx + math.cos(angle) * inner,
        center.dy + math.sin(angle) * inner,
      );
      final bend = Offset(
        center.dx + math.cos(angle + 0.22) * mid,
        center.dy + math.sin(angle + 0.22) * mid,
      );
      final end = Offset(
        center.dx + math.cos(angle - 0.18) * outer,
        center.dy + math.sin(angle - 0.18) * outer,
      );
      canvas.drawLine(start, bend, spark);
      canvas.drawLine(bend, end, spark);
    }
  }

  void _drawLightningBlast(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    _drawBlast(
      canvas: canvas,
      center: center,
      progress: progress,
      alpha: alpha,
      shockColor: const Color(0xFFE8FBFF),
      flashColor: const Color(0xFFFFFFFF),
      coreColor: const Color(0xFFCFA7FF),
      shardAltColor: const Color(0xFF8CFFF3),
      dustColor: const Color(0xFF9DDDEA),
    );
  }

  void _drawCannonBlast(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    _drawIrregularCannonShockwave(canvas, center, progress, alpha);
    _drawCannonBlastSprite(canvas, center, progress);
  }

  void _drawIrregularCannonShockwave(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    final easedProgress = progress * progress * (3 - 2 * progress);
    final baseRadius = radius * (0.18 + easedProgress * 0.94);
    final baseStrokeWidth =
        math.max(1.1, radius * 0.045) * (1 - progress * 0.4);
    final shockColor = Color.lerp(const Color(0xFFFFF0B0), _color, 0.48)!;

    for (final arc in _cannonShockArcs) {
      // 폭발별로 고정된 반경 요철
      final path = Path();
      for (var i = 0; i < arc.radialOffsets.length; i++) {
        final sampleProgress = i / (arc.radialOffsets.length - 1);
        final angle =
            arc.startAngle +
            arc.sweepAngle * sampleProgress +
            progress * arc.rotationSpeed;
        final ripple =
            arc.radialOffsets[i] * (0.035 + progress * 0.055) +
            math.sin(angle * 3 + arc.phase + progress * 2.2) * 0.025;
        final arcRadius = baseRadius * arc.radiusScale * (1 + ripple);
        final point = Offset(
          center.dx + math.cos(angle) * arcRadius,
          center.dy + math.sin(angle) * arcRadius,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = _color.withValues(alpha: alpha * 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseStrokeWidth * arc.widthScale * 2.35
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = shockColor.withValues(alpha: alpha * arc.alphaScale * 0.82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseStrokeWidth * arc.widthScale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawCannonBlastSprite(Canvas canvas, Offset center, double progress) {
    final spriteSheet = cannonBlastSpriteSheet;
    if (spriteSheet == null) {
      return;
    }
    final frameIndex = (progress * cannonBlastFrameCount)
        .floor()
        .clamp(0, cannonBlastFrameCount - 1)
        .toInt();
    final frameWidth = spriteSheet.width / _cannonBlastAtlasColumns;
    final frameHeight = spriteSheet.height / _cannonBlastAtlasRows;
    final source = Rect.fromLTWH(
      (frameIndex % _cannonBlastAtlasColumns) * frameWidth,
      (frameIndex ~/ _cannonBlastAtlasColumns) * frameHeight,
      frameWidth,
      frameHeight,
    );
    final spriteExtent = radius * 2.04;
    final destination = Rect.fromCenter(
      center: center,
      width: spriteExtent,
      height: spriteExtent,
    );
    canvas.drawImageRect(
      spriteSheet,
      source,
      destination,
      _cannonBlastSpritePaint,
    );
  }

  void _drawBlast({
    required Canvas canvas,
    required Offset center,
    required double progress,
    required double alpha,
    required Color shockColor,
    required Color flashColor,
    required Color coreColor,
    required Color shardAltColor,
    required Color dustColor,
  }) {
    final shockRing = Paint()
      ..color = shockColor.withValues(alpha: alpha * 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.1;
    final outerRing = Paint()
      ..color = _color.withValues(alpha: alpha * 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, radius * (0.24 + progress * 0.9), shockRing);
    canvas.drawCircle(center, radius * (0.38 + progress * 0.58), outerRing);
    final flash = Paint()
      ..color = flashColor.withValues(
        alpha: (1 - progress * 1.4).clamp(0.0, 1.0),
      );
    canvas.drawCircle(center, radius * (0.22 + progress * 0.12), flash);
    canvas.drawCircle(
      center,
      radius * (0.2 + progress * 0.2),
      Paint()..color = coreColor.withValues(alpha: alpha * 0.65),
    );
    final shard = Paint()
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi * 2 / 8 + 0.2;
      final inner = radius * (0.18 + progress * 0.18);
      final outer = radius * (0.42 + progress * 0.42);
      shard.color = (i.isEven ? flashColor : shardAltColor).withValues(
        alpha: alpha * 0.74,
      );
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * inner,
          center.dy + math.sin(angle) * inner,
        ),
        Offset(
          center.dx + math.cos(angle) * outer,
          center.dy + math.sin(angle) * outer,
        ),
        shard,
      );
    }
    final dust = Paint()..color = dustColor;
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7 + 0.28;
      final distance = radius * (0.28 + progress * 0.76);
      dust.color = dust.color.withValues(alpha: alpha * 0.38);
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance * 0.72,
        ),
        radius * (0.08 + progress * 0.05),
        dust,
      );
    }
  }
}

bool _isBlastStyle(ImpactEffectStyle style) {
  return style == ImpactEffectStyle.blast ||
      style == ImpactEffectStyle.sniperBlast ||
      style == ImpactEffectStyle.lightningBlast;
}

List<_CannonShockArc> _createCannonShockArcs(int seed) {
  final random = math.Random(seed);
  var cursor = random.nextDouble() * math.pi * 2;
  return List.generate(4, (_) {
    cursor += 0.16 + random.nextDouble() * 0.28;
    final sweepAngle = 0.68 + random.nextDouble() * 0.34;
    final arc = _CannonShockArc(
      startAngle: cursor,
      sweepAngle: sweepAngle,
      radiusScale: 0.91 + random.nextDouble() * 0.18,
      widthScale: 0.78 + random.nextDouble() * 0.5,
      alphaScale: 0.72 + random.nextDouble() * 0.28,
      phase: random.nextDouble() * math.pi * 2,
      rotationSpeed: (random.nextDouble() - 0.5) * 0.22,
      radialOffsets: List.generate(9, (_) => random.nextDouble() * 2 - 1),
    );
    cursor += sweepAngle;
    return arc;
  });
}

class _CannonShockArc {
  const _CannonShockArc({
    required this.startAngle,
    required this.sweepAngle,
    required this.radiusScale,
    required this.widthScale,
    required this.alphaScale,
    required this.phase,
    required this.rotationSpeed,
    required this.radialOffsets,
  });

  final double startAngle;
  final double sweepAngle;
  final double radiusScale;
  final double widthScale;
  final double alphaScale;
  final double phase;
  final double rotationSpeed;
  final List<double> radialOffsets;
}
