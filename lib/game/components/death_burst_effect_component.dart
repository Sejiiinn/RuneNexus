import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/enemy/enemy_type.dart';
import '../rendering/enemy_shape_renderer.dart';

class DeathBurstEffectComponent extends PositionComponent {
  DeathBurstEffectComponent({
    required Vector2 position,
    required Color color,
    required EnemyType type,
    required double radius,
  }) : _color = color,
       _type = type,
       _radius = radius,
       super(
         position: position,
         size: Vector2.all(radius * 4),
         anchor: Anchor.center,
       );

  final Color _color;
  final EnemyType _type;
  final double _radius;
  double _age = 0;

  double get _lifeTime => switch (_type) {
    EnemyType.boss => 0.68,
    EnemyType.tank => 0.54,
    EnemyType.shielded => 0.48,
    EnemyType.normal || EnemyType.armored || EnemyType.fast => 0.42,
  };

  int get _pixelCount => switch (_type) {
    EnemyType.boss => 18,
    EnemyType.tank => 13,
    EnemyType.fast => 10,
    EnemyType.shielded => 11,
    EnemyType.armored => 12,
    EnemyType.normal => 9,
  };

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
    final alpha = math.pow(1 - progress, 0.72).toDouble();
    final center = Offset(size.x / 2, size.y / 2);

    _drawFadingSilhouette(canvas, center, progress, alpha);
    _drawPixelFragments(canvas, center, progress, alpha);
  }

  void _drawFadingSilhouette(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    final silhouetteSize = _radius * (1 - progress * 0.14);
    final lift = _radius * progress * 0.18;
    final bounds = Rect.fromCenter(
      center: center.translate(0, -lift),
      width: silhouetteSize * 1.25,
      height: silhouetteSize * 1.25,
    );

    canvas.saveLayer(
      bounds,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.5),
    );
    canvas.translate(
      center.dx - silhouetteSize / 2,
      center.dy - silhouetteSize / 2 - lift,
    );
    drawEnemyShape(
      canvas,
      size: Size(silhouetteSize, silhouetteSize),
      type: _type,
      color: _color,
      strokeWidth: 1.2,
    );
    canvas.restore();
  }

  void _drawPixelFragments(
    Canvas canvas,
    Offset center,
    double progress,
    double alpha,
  ) {
    final pixelPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _pixelCount; i++) {
      final seed = math.sin((i + 1) * 12.9898 + _type.index * 78.233);
      final originAngle = i * 2.399963229728653;
      final angle = originAngle + seed * 0.45;
      final origin = Offset(
        math.cos(originAngle) * _radius * 0.2,
        math.sin(originAngle) * _radius * 0.16,
      );
      final fastBias = _type == EnemyType.fast
          ? math.cos(angle).abs() * 0.32
          : 0.0;
      final drift =
          _radius *
          switch (_type) {
            EnemyType.boss => 0.96,
            EnemyType.tank => 0.82,
            EnemyType.fast => 0.92,
            EnemyType.shielded => 0.78,
            EnemyType.armored => 0.76,
            EnemyType.normal => 0.68,
          };
      final distance = progress * (drift + _radius * fastBias);
      final rise = _radius * progress * (0.2 + seed.abs() * 0.28);
      final pixelCenter = Offset(
        center.dx + origin.dx + math.cos(angle) * distance,
        center.dy + origin.dy + math.sin(angle) * distance + rise * 0.08,
      );
      final pixelSize =
          _radius *
          switch (_type) {
            EnemyType.boss => 0.3,
            EnemyType.tank => 0.28,
            EnemyType.fast => 0.2,
            EnemyType.shielded => 0.24,
            EnemyType.armored => 0.25,
            EnemyType.normal => 0.22,
          } *
          (1 - progress * 0.34);

      pixelPaint.color = (i.isEven ? _color : const Color(0xFFE8FBFF))
          .withValues(alpha: alpha * 0.74);
      canvas.save();
      canvas.translate(pixelCenter.dx, pixelCenter.dy);
      canvas.rotate(angle + progress * (seed > 0 ? 0.6 : -0.6));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: pixelSize,
            height: pixelSize * (0.72 + seed.abs() * 0.42),
          ),
          Radius.circular(pixelSize * 0.18),
        ),
        pixelPaint,
      );
      canvas.restore();
    }
  }
}
