import 'dart:math' as math;
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

  double _portalSpin = 0;
  double portalAlert = 0;
  double nexusHitAlert = 0;
  Picture? _staticBoardPicture;
  late final List<GridPoint> _dynamicTilePoints = _collectDynamicTilePoints();

  void updateLayout({required Vector2 origin, required double tileSize}) {
    if (this.origin.x == origin.x &&
        this.origin.y == origin.y &&
        this.tileSize == tileSize) {
      return;
    }
    this.origin = origin;
    this.tileSize = tileSize;
    _invalidateStaticBoardPicture();
  }

  @override
  void update(double dt) {
    _portalSpin = (_portalSpin + dt * 0.75) % (math.pi * 2);
  }

  @override
  void render(Canvas canvas) {
    final staticBoard = _staticBoardPicture ??= _buildStaticBoardPicture();
    canvas.drawPicture(staticBoard);

    for (final point in _dynamicTilePoints) {
      final rect = _tileRect(point);
      switch (map.tileAt(point)) {
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

  @override
  void onRemove() {
    _invalidateStaticBoardPicture();
    super.onRemove();
  }

  Picture _buildStaticBoardPicture() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    for (var y = 0; y < map.rows; y++) {
      for (var x = 0; x < map.columns; x++) {
        final point = GridPoint(x, y);
        final rect = _tileRect(point);
        final tileType = map.tileAt(point);
        if (tileType == TileType.blocked) {
          continue;
        }
        _drawTile(canvas, rect, point, tileType);
        canvas.drawRect(
          rect.deflate(tileSize * 0.012),
          Paint()
            ..color = const Color(0x44083A42)
            ..style = PaintingStyle.stroke
            ..strokeWidth = tileSize * 0.01,
        );
      }
    }

    return recorder.endRecording();
  }

  List<GridPoint> _collectDynamicTilePoints() {
    final points = <GridPoint>[];
    for (var y = 0; y < map.rows; y++) {
      for (var x = 0; x < map.columns; x++) {
        final point = GridPoint(x, y);
        final tileType = map.tileAt(point);
        if (tileType == TileType.spawn || tileType == TileType.core) {
          points.add(point);
        }
      }
    }
    return List.unmodifiable(points);
  }

  Rect _tileRect(GridPoint point) {
    return Rect.fromLTWH(
      origin.x + point.x * tileSize,
      origin.y + point.y * tileSize,
      tileSize,
      tileSize,
    );
  }

  void _invalidateStaticBoardPicture() {
    _staticBoardPicture?.dispose();
    _staticBoardPicture = null;
  }

  void _drawTile(Canvas canvas, Rect rect, GridPoint point, TileType tileType) {
    final inner = rect.deflate(1);

    switch (tileType) {
      case TileType.path:
        _drawDirtTile(canvas, inner, point);
      case TileType.build:
        _drawGrassTile(canvas, inner, point);
      case TileType.spawn:
      case TileType.core:
        canvas.drawRect(inner, _paintFor(tileType));
        _drawStoneDetails(canvas, inner, point);
      case TileType.blocked:
        break;
    }
  }

  void _drawDirtTile(Canvas canvas, Rect rect, GridPoint point) {
    final tile = _tileFace(rect);
    _drawPolishedTileFrame(
      canvas,
      rect,
      tile,
      topColor: const Color(0xFF968875),
      midColor: const Color(0xFF796F60),
      bottomColor: const Color(0xFF5C554B),
      rimColor: const Color(0xFF193E3F),
    );

    final stain = _tileUnit(point, 1);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          tile.left + tile.width * (0.32 + stain * 0.32),
          tile.top + tile.height * (0.28 + _tileUnit(point, 2) * 0.32),
        ),
        width: tile.width * 0.42,
        height: tile.height * 0.26,
      ),
      Paint()
        ..color = const Color(0x223E3329)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSize * 0.018),
    );

    final chipPaint = Paint()
      ..color = const Color(0x66473F35)
      ..style = PaintingStyle.fill;
    final lightChipPaint = Paint()
      ..color = const Color(0x338F8575)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 5; i++) {
      final x =
          tile.left + tile.width * (0.16 + _tileUnit(point, i + 3) * 0.68);
      final y =
          tile.top + tile.height * (0.18 + _tileUnit(point, i + 9) * 0.66);
      final chip = Rect.fromCenter(
        center: Offset(x, y),
        width: tileSize * (0.03 + _tileUnit(point, i + 15) * 0.035),
        height: tileSize * 0.018,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, Radius.circular(tileSize * 0.01)),
        i.isEven ? chipPaint : lightChipPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        tile.deflate(tileSize * 0.06),
        Radius.circular(tileSize * 0.035),
      ),
      Paint()
        ..color = const Color(0x333F352B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileSize * 0.014,
    );
  }

  void _drawGrassTile(Canvas canvas, Rect rect, GridPoint point) {
    final tile = _tileFace(rect);
    _drawPolishedTileFrame(
      canvas,
      rect,
      tile,
      topColor: const Color(0xFF3D6048),
      midColor: const Color(0xFF2E5040),
      bottomColor: const Color(0xFF203B34),
      rimColor: const Color(0xFF183F3D),
    );

    final mossPaint = Paint()
      ..color = const Color(0x55304335)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final center = Offset(
        tile.left + tile.width * (0.16 + _tileUnit(point, i + 21) * 0.7),
        tile.top + tile.height * (0.16 + _tileUnit(point, i + 27) * 0.68),
      );
      canvas.drawCircle(
        center,
        tileSize * (0.018 + _tileUnit(point, i + 33) * 0.014),
        mossPaint,
      );
    }

    _drawGrassScuffs(canvas, tile, point);
  }

  Rect _tileFace(Rect rect) {
    return rect.deflate(tileSize * 0.025);
  }

  void _drawPolishedTileFrame(
    Canvas canvas,
    Rect rect,
    Rect face, {
    required Color topColor,
    required Color midColor,
    required Color bottomColor,
    required Color rimColor,
  }) {
    final radius = Radius.circular(tileSize * 0.035);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(tileSize * 0.012), radius),
      Paint()..color = rimColor.withValues(alpha: 0.65),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(tileSize * 0.03)),
      Paint()
        ..shader = Gradient.linear(
          face.topLeft,
          face.bottomRight,
          [topColor, midColor, bottomColor],
          const [0, 0.56, 1],
        ),
    );

    canvas.drawLine(
      Offset(face.left + tileSize * 0.04, face.top + tileSize * 0.05),
      Offset(face.right - tileSize * 0.08, face.top + tileSize * 0.05),
      Paint()
        ..color = const Color(0x18FFFFFF)
        ..strokeWidth = tileSize * 0.009
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(face.left + tileSize * 0.05, face.top + tileSize * 0.04),
      Offset(face.left + tileSize * 0.05, face.bottom - tileSize * 0.08),
      Paint()
        ..color = const Color(0x10FFFFFF)
        ..strokeWidth = tileSize * 0.008
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(face.left + tileSize * 0.08, face.bottom - tileSize * 0.05),
      Offset(face.right - tileSize * 0.05, face.bottom - tileSize * 0.05),
      Paint()
        ..color = const Color(0x30000000)
        ..strokeWidth = tileSize * 0.01
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(face.right - tileSize * 0.05, face.top + tileSize * 0.08),
      Offset(face.right - tileSize * 0.05, face.bottom - tileSize * 0.06),
      Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = tileSize * 0.009
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawGrassScuffs(Canvas canvas, Rect tile, GridPoint point) {
    final dark = Paint()
      ..color = const Color(0x7720322A)
      ..strokeWidth = tileSize * 0.018
      ..strokeCap = StrokeCap.square;
    final mutedLeaf = Paint()
      ..color = const Color(0x665C7F50)
      ..strokeWidth = tileSize * 0.016
      ..strokeCap = StrokeCap.square;

    for (var group = 0; group < 3; group++) {
      final base = Offset(
        tile.left + tile.width * (0.22 + _tileUnit(point, group + 44) * 0.56),
        tile.top + tile.height * (0.28 + _tileUnit(point, group + 51) * 0.5),
      );
      for (var bladeIndex = 0; bladeIndex < 3; bladeIndex++) {
        final start = base.translate(
          (bladeIndex - 1) * tileSize * 0.055,
          bladeIndex * tileSize * 0.015,
        );
        final lean =
            tileSize *
            (-0.04 + _tileUnit(point, group * 5 + bladeIndex + 58) * 0.08);
        final height =
            tileSize *
            (0.065 + _tileUnit(point, group * 5 + bladeIndex + 64) * 0.04);
        final end = Offset(start.dx + lean, start.dy - height);
        canvas.drawLine(
          start.translate(tileSize * 0.015, tileSize * 0.015),
          end,
          dark,
        );
        canvas.drawLine(start, end, bladeIndex == 1 ? mutedLeaf : dark);
      }
    }
  }

  double _tileUnit(GridPoint point, int salt) {
    final n = math.sin(point.x * 12.9898 + point.y * 78.233 + salt * 37.719);
    return (n * 43758.5453).abs() % 1;
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

  void _drawPortal(Canvas canvas, Rect rect) {
    final center = rect.center;
    final radius = tileSize * 0.3;
    final alert = portalAlert.clamp(0.0, 1.0);
    final outer = Paint()
      ..color = Color.lerp(
        const Color(0xFFB16DFF),
        const Color(0xFFE3B7FF),
        alert,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * (0.07 + alert * 0.035);
    final inner = Paint()
      ..color = Color.lerp(
        const Color(0xFF2B0D44),
        const Color(0xFF4A1478),
        alert,
      )!;
    final base = Paint()
      ..color = const Color(0xFF190826)
      ..style = PaintingStyle.fill;

    if (alert > 0) {
      canvas.drawCircle(
        center,
        radius * (1.28 + alert * 0.28),
        Paint()
          ..color = const Color(0xFFB16DFF).withValues(alpha: 0.24 * alert)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tileSize * 0.035,
      );
      canvas.drawCircle(
        center,
        radius * (1.05 + alert * 0.32),
        Paint()..color = const Color(0xFF8E46FF).withValues(alpha: 0.2 * alert),
      );
    }
    canvas.drawCircle(center, radius * (1.08 + alert * 0.08), base);
    canvas.drawCircle(center, radius, inner);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_portalSpin * (1 + alert * 0.9));
    _drawPortalSwirl(canvas, radius * (1 + alert * 0.12));
    canvas.restore();
    canvas.drawCircle(center, radius, outer);
    canvas.drawCircle(
      center,
      radius * (0.68 + math.sin(_portalSpin * 2) * 0.05),
      Paint()
        ..color = const Color(0x6650E6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileSize * 0.025,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy),
      radius * 0.42,
      Paint()..color = const Color(0xAAE3B7FF),
    );
  }

  void _drawPortalSwirl(Canvas canvas, double radius) {
    final glow = Paint()
      ..color = const Color(0x6650E6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.035
      ..strokeCap = StrokeCap.round;
    final spiral = Paint()
      ..color = const Color(0xCCB16DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.045
      ..strokeCap = StrokeCap.round;

    for (var arm = 0; arm < 3; arm++) {
      final turn = arm * math.pi * 2 / 3;
      final path = Path();
      for (var i = 0; i <= 18; i++) {
        final t = i / 18;
        final angle = turn + t * math.pi * 1.35;
        final distance = radius * (0.18 + t * 0.62);
        final point = Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, spiral);
    }
  }

  void _drawNexus(Canvas canvas, Rect rect) {
    final center = rect.center;
    final hit = nexusHitAlert.clamp(0.0, 1.0);
    final basePaint = Paint()..color = const Color(0xFF26384A);
    final shadowPaint = Paint()..color = const Color(0xFF07111D);

    if (hit > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(tileSize * 0.05),
          Radius.circular(tileSize * 0.08),
        ),
        Paint()..color = const Color(0xFFFF3D3D).withValues(alpha: 0.26 * hit),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(tileSize * 0.08),
          Radius.circular(tileSize * 0.08),
        ),
        Paint()
          ..color = const Color(0xFFFF7A59).withValues(alpha: 0.75 * hit)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tileSize * 0.045,
      );
    }

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
    canvas.drawPath(
      gem,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFB9F7FF),
          const Color(0xFFFFD0C6),
          hit,
        )!,
    );
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
        TileType.blocked => const Color(0x00000000),
        TileType.spawn => const Color(0xFF4B245F),
        TileType.core => const Color(0xFF0B86B8),
      };
  }
}
