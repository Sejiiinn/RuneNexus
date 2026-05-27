import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'enemy_component.dart';

class LightningChainBeamComponent extends PositionComponent {
  LightningChainBeamComponent({
    required Vector2 sourcePosition,
    required this.target,
    this.source,
    required this.color,
    double duration = 0.16,
  }) : _sourcePosition = sourcePosition.clone(),
       _targetPosition = target.position.clone(),
       _duration = duration,
       _seed = sourcePosition.x * 17.0 + sourcePosition.y * 31.0,
       super(position: Vector2.zero(), size: Vector2.zero());

  final EnemyComponent? source;
  final EnemyComponent target;
  final Color color;
  final double _duration;
  final double _seed;
  Vector2 _sourcePosition;
  Vector2 _targetPosition;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
      return;
    }

    final liveSource = source;
    if (liveSource != null && liveSource.isMounted && !liveSource.isDead) {
      _sourcePosition = liveSource.position.clone();
    }
    if (target.isMounted && !target.isDead) {
      _targetPosition = target.position.clone();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0).toDouble();
    final alpha = (1 - progress) * 0.95;
    final start = Offset(_sourcePosition.x, _sourcePosition.y);
    final end = Offset(_targetPosition.x, _targetPosition.y);
    final points = _boltPoints(start, end);

    _drawPath(
      canvas,
      points,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    _drawPath(
      canvas,
      points,
      Paint()
        ..color = const Color(0xFF8CFFF3).withValues(alpha: alpha * 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    _drawPath(
      canvas,
      points,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawSpark(canvas, start, alpha);
    _drawSpark(canvas, end, alpha);
  }

  List<Offset> _boltPoints(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0) {
      return [start, end];
    }
    final normal = Offset(-dy / length, dx / length);
    return List<Offset>.generate(6, (index) {
      if (index == 0) {
        return start;
      }
      if (index == 5) {
        return end;
      }
      final t = index / 5;
      final wave = math.sin(_seed + index * 1.7) * 0.5 + 0.5;
      final offset = (wave - 0.5) * math.min(18.0, length * 0.16);
      return Offset(start.dx + dx * t, start.dy + dy * t) + normal * offset;
    });
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawSpark(Canvas canvas, Offset center, double alpha) {
    canvas.drawCircle(
      center,
      6.2,
      Paint()..color = color.withValues(alpha: alpha * 0.22),
    );
    canvas.drawCircle(
      center,
      2.4,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.9),
    );
  }
}
