import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/map/grid_point.dart';
import '../../domain/map/map_definition.dart';
import '../../domain/map/tile_type.dart';

class GridComponent extends Component {
  GridComponent({
    required this.map,
    required this.origin,
    required this.tileSize,
  });

  final MapDefinition map;
  Vector2 origin;
  double tileSize;

  final _stroke = Paint()
    ..color = const Color(0x6633C8FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  void updateLayout({required Vector2 origin, required double tileSize}) {
    this.origin = origin;
    this.tileSize = tileSize;
  }

  @override
  void render(Canvas canvas) {
    for (var y = 0; y < map.rows; y++) {
      for (var x = 0; x < map.columns; x++) {
        final point = GridPoint(x, y);
        final rect = Rect.fromLTWH(
          origin.x + x * tileSize,
          origin.y + y * tileSize,
          tileSize,
          tileSize,
        );

        final tileType = map.tileAt(point);
        _drawTile(canvas, rect, point, tileType);
        canvas.drawRect(rect.deflate(1), _stroke);
        switch (tileType) {
          case TileType.spawn:
            _drawPortal(canvas, rect);
          case TileType.core:
            _drawNexus(canvas, rect);
          case TileType.path:
          case TileType.build:
          case TileType.blocked:
            break;
        }
      }
    }
  }

  void _drawTile(Canvas canvas, Rect rect, GridPoint point, TileType tileType) {
    final inner = rect.deflate(1);
    canvas.drawRect(inner, _paintFor(tileType));

    switch (tileType) {
      case TileType.path:
      case TileType.spawn:
      case TileType.core:
        _drawStoneDetails(canvas, inner, point);
      case TileType.build:
        _drawGrassDetails(canvas, inner, point);
      case TileType.blocked:
        _drawRuinDetails(canvas, inner, point);
    }
  }

  void _drawStoneDetails(Canvas canvas, Rect rect, GridPoint point) {
    final mortar = Paint()
      ..color = const Color(0x33271618)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final highlight = Paint()
      ..color = const Color(0x227FF3FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final inset = tileSize * 0.12;
    final slab = RRect.fromRectAndRadius(
      rect.deflate(inset),
      Radius.circular(tileSize * 0.04),
    );
    canvas.drawRRect(slab, mortar);
    canvas.drawLine(
      Offset(rect.left + tileSize * 0.16, rect.top + tileSize * 0.24),
      Offset(rect.right - tileSize * 0.16, rect.top + tileSize * 0.19),
      highlight,
    );
    if ((point.x + point.y).isEven) {
      canvas.drawLine(
        Offset(rect.left + tileSize * 0.2, rect.bottom - tileSize * 0.22),
        Offset(rect.left + tileSize * 0.55, rect.bottom - tileSize * 0.18),
        mortar,
      );
    }
  }

  void _drawGrassDetails(Canvas canvas, Rect rect, GridPoint point) {
    final bladePaint = Paint()
      ..color = const Color(0x555DCC76)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.square;
    final shadowPatch = Paint()..color = const Color(0x17101116);

    if ((point.x * 3 + point.y).isEven) {
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + tileSize * 0.08,
          rect.top + tileSize * 0.08,
          tileSize * 0.22,
          tileSize * 0.16,
        ),
        shadowPatch,
      );
    }
    for (var i = 0; i < 3; i++) {
      final x = rect.left + tileSize * (0.22 + i * 0.19);
      final y = rect.top + tileSize * (0.72 - ((point.x + i) % 2) * 0.18);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + tileSize * 0.05, y - 4),
        bladePaint,
      );
    }
  }

  void _drawRuinDetails(Canvas canvas, Rect rect, GridPoint point) {
    final stone = Paint()..color = const Color(0xFF243342);
    final crack = Paint()
      ..color = const Color(0x8807111D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rubble = Rect.fromLTWH(
      rect.left + tileSize * (0.16 + (point.x % 2) * 0.14),
      rect.top + tileSize * 0.22,
      tileSize * 0.26,
      tileSize * 0.18,
    );
    canvas.drawRect(rubble, stone);
    canvas.drawLine(
      Offset(rect.left + tileSize * 0.62, rect.top + tileSize * 0.18),
      Offset(rect.left + tileSize * 0.45, rect.top + tileSize * 0.62),
      crack,
    );
    canvas.drawLine(
      Offset(rect.left + tileSize * 0.45, rect.top + tileSize * 0.62),
      Offset(rect.left + tileSize * 0.56, rect.bottom - tileSize * 0.14),
      crack,
    );
  }

  void _drawPortal(Canvas canvas, Rect rect) {
    final center = rect.center;
    final radius = tileSize * 0.3;
    final outer = Paint()
      ..color = const Color(0xFFB16DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.07;
    final inner = Paint()..color = const Color(0xFF2B0D44);
    final base = Paint()
      ..color = const Color(0xFF190826)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 1.08, base);
    canvas.drawCircle(center, radius, inner);
    canvas.drawCircle(center, radius, outer);
    canvas.drawCircle(
      Offset(center.dx, center.dy),
      radius * 0.42,
      Paint()..color = const Color(0xAAE3B7FF),
    );
  }

  void _drawNexus(Canvas canvas, Rect rect) {
    final center = rect.center;
    final basePaint = Paint()..color = const Color(0xFF26384A);
    final shadowPaint = Paint()..color = const Color(0xFF07111D);

    final pedestal = Rect.fromCenter(
      center: Offset(center.dx, center.dy + tileSize * 0.18),
      width: tileSize * 0.58,
      height: tileSize * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pedestal, Radius.circular(tileSize * 0.04)),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        pedestal.deflate(tileSize * 0.035),
        Radius.circular(tileSize * 0.03),
      ),
      basePaint,
    );

    final pillar = Path()
      ..moveTo(center.dx - tileSize * 0.22, center.dy + tileSize * 0.15)
      ..lineTo(center.dx - tileSize * 0.16, center.dy - tileSize * 0.2)
      ..lineTo(center.dx + tileSize * 0.16, center.dy - tileSize * 0.2)
      ..lineTo(center.dx + tileSize * 0.22, center.dy + tileSize * 0.15)
      ..close();
    canvas.drawPath(pillar, shadowPaint);
    canvas.drawPath(pillar.shift(Offset(0, -tileSize * 0.025)), basePaint);

    final gem = Path()
      ..moveTo(center.dx, center.dy - tileSize * 0.34)
      ..lineTo(center.dx + tileSize * 0.16, center.dy - tileSize * 0.08)
      ..lineTo(center.dx, center.dy + tileSize * 0.16)
      ..lineTo(center.dx - tileSize * 0.16, center.dy - tileSize * 0.08)
      ..close();
    canvas.drawPath(gem, Paint()..color = const Color(0xFFB9F7FF));
    canvas.drawPath(
      gem,
      Paint()
        ..color = const Color(0xFF70DFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileSize * 0.035,
    );
  }

  Paint _paintFor(TileType type) {
    return Paint()
      ..color = switch (type) {
        TileType.path => const Color(0xFF786C58),
        TileType.build => const Color(0xFF1C4737),
        TileType.blocked => const Color(0xFF172634),
        TileType.spawn => const Color(0xFF4B245F),
        TileType.core => const Color(0xFF0B86B8),
      };
  }
}
