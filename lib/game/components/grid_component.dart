import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../domain/map/grid_point.dart';
import '../../domain/map/map_definition.dart';
import '../../domain/map/map_tile_theme.dart';
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
  double _pathGuidePhase = 0;
  double portalAlert = 0;
  double nexusHitAlert = 0;
  double nexusDestructionProgress = 0;
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
    _pathGuidePhase = (_pathGuidePhase + dt * 0.42) % 1;
  }

  @override
  void render(Canvas canvas) {
    final staticBoard = _staticBoardPicture ??= _buildStaticBoardPicture();
    canvas.drawPicture(staticBoard);
    _drawPathGuide(canvas);

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
            ..color = map.tileTheme.gridStrokeColor
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

  void _drawPathGuide(Canvas canvas) {
    if (map.path.length < 2) {
      return;
    }

    final centers = map.path
        .map((point) => _tileRect(point).center)
        .toList(growable: false);
    final guidePath = Path();
    for (var i = 0; i < centers.length; i++) {
      final center = centers[i];
      if (i == 0) {
        guidePath.moveTo(center.dx, center.dy);
      } else {
        guidePath.lineTo(center.dx, center.dy);
      }
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF8EE6FF).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSize * 0.025);
    final linePaint = Paint()
      ..color = const Color(0xFFE9FDFF).withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, tileSize * 0.05)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(guidePath, glowPaint);
    canvas.drawPath(guidePath, linePaint);
    _drawPathGuideCorners(canvas, centers);
    _drawPathGuidePulses(canvas, guidePath);
  }

  void _drawPathGuideCorners(Canvas canvas, List<Offset> centers) {
    if (centers.length < 3) {
      return;
    }

    final cornerPaint = Paint()
      ..color = const Color(0xFFBFF4FF).withValues(alpha: 0.035)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSize * 0.02);
    for (var i = 1; i < centers.length - 1; i++) {
      canvas.drawCircle(centers[i], tileSize * 0.11, cornerPaint);
    }
  }

  void _drawPathGuidePulses(Canvas canvas, Path guidePath) {
    final metrics = guidePath.computeMetrics().toList(growable: false);
    if (metrics.isEmpty) {
      return;
    }

    final metric = metrics.first;
    final totalLength = metric.length;
    if (totalLength <= 0) {
      return;
    }

    final spacing = tileSize * 1.32;
    final dashLength = tileSize * 0.36;
    final pulseCount = math.max(1, (totalLength / spacing).floor());
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, tileSize * 0.085)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSize * 0.012);
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, tileSize * 0.03)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < pulseCount; i++) {
      final center = (_pathGuidePhase * spacing + i * spacing) % totalLength;
      final wave = math.sin((i / pulseCount + _pathGuidePhase) * math.pi * 2);
      final alpha = 0.07 + (wave + 1) * 0.025;
      pulsePaint.color = const Color(0xFFBFF4FF).withValues(alpha: alpha);
      corePaint.color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.35);

      var start = center - dashLength * 0.5;
      var end = center + dashLength * 0.5;
      if (start < 0) {
        canvas.drawPath(
          metric.extractPath(totalLength + start, totalLength),
          pulsePaint,
        );
        canvas.drawPath(metric.extractPath(0, end), pulsePaint);
        canvas.drawPath(
          metric.extractPath(totalLength + start, totalLength),
          corePaint,
        );
        canvas.drawPath(metric.extractPath(0, end), corePaint);
        continue;
      }
      if (end > totalLength) {
        canvas.drawPath(metric.extractPath(start, totalLength), pulsePaint);
        canvas.drawPath(metric.extractPath(0, end - totalLength), pulsePaint);
        canvas.drawPath(metric.extractPath(start, totalLength), corePaint);
        canvas.drawPath(metric.extractPath(0, end - totalLength), corePaint);
        continue;
      }

      start = start.clamp(0.0, totalLength);
      end = end.clamp(0.0, totalLength);
      canvas.drawPath(metric.extractPath(start, end), pulsePaint);
      canvas.drawPath(metric.extractPath(start, end), corePaint);
    }
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
    final theme = map.tileTheme;
    if (theme.usesForgeHeat) {
      _drawForgePathTile(canvas, rect, tile, point, theme);
      return;
    }

    _drawPolishedTileFrame(
      canvas,
      rect,
      tile,
      topColor: theme.pathTopColor,
      midColor: theme.pathMidColor,
      bottomColor: theme.pathBottomColor,
      rimColor: theme.pathRimColor,
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
        ..color = theme.pathStainColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSize * 0.018),
    );

    final chipPaint = Paint()
      ..color = theme.pathChipColor
      ..style = PaintingStyle.fill;
    final lightChipPaint = Paint()
      ..color = theme.pathLightChipColor
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
        ..color = theme.pathInsetStrokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileSize * 0.014,
    );
    if (theme.usesRiftEnergy) {
      _drawRiftPathDetails(canvas, tile, point, theme);
    }
  }

  void _drawGrassTile(Canvas canvas, Rect rect, GridPoint point) {
    final tile = _tileFace(rect);
    final theme = map.tileTheme;
    if (theme.usesForgeHeat) {
      _drawForgeBuildTile(canvas, rect, tile, point, theme);
      return;
    }

    _drawPolishedTileFrame(
      canvas,
      rect,
      tile,
      topColor: theme.buildTopColor,
      midColor: theme.buildMidColor,
      bottomColor: theme.buildBottomColor,
      rimColor: theme.buildRimColor,
    );

    final mossPaint = Paint()
      ..color = theme.buildMossColor
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

    _drawGrassScuffs(canvas, tile, point, theme);
    if (theme.usesRiftEnergy) {
      _drawRiftBuildDetails(canvas, tile, point, theme);
    }
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

  void _drawGrassScuffs(
    Canvas canvas,
    Rect tile,
    GridPoint point,
    MapTileTheme theme,
  ) {
    final dark = Paint()
      ..color = theme.buildDarkScuffColor
      ..strokeWidth = tileSize * 0.018
      ..strokeCap = StrokeCap.square;
    final mutedLeaf = Paint()
      ..color = theme.buildMutedLeafColor
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

  void _drawRiftPathDetails(
    Canvas canvas,
    Rect tile,
    GridPoint point,
    MapTileTheme theme,
  ) {
    final crack = Paint()
      ..color = theme.energySecondaryColor.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.012
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.04
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSize * 0.018);

    final start = Offset(
      tile.left + tile.width * (0.16 + _tileUnit(point, 71) * 0.16),
      tile.top + tile.height * (0.35 + _tileUnit(point, 72) * 0.25),
    );
    final mid = Offset(
      tile.left + tile.width * (0.45 + _tileUnit(point, 73) * 0.1),
      tile.top + tile.height * (0.24 + _tileUnit(point, 74) * 0.5),
    );
    final end = Offset(
      tile.right - tile.width * (0.14 + _tileUnit(point, 75) * 0.2),
      tile.top + tile.height * (0.45 + _tileUnit(point, 76) * 0.2),
    );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, crack);

    final node = Rect.fromCenter(
      center: mid,
      width: tileSize * 0.06,
      height: tileSize * 0.06,
    );
    canvas.drawOval(
      node,
      Paint()..color = theme.energyPrimaryColor.withValues(alpha: 0.68),
    );
  }

  void _drawRiftBuildDetails(
    Canvas canvas,
    Rect tile,
    GridPoint point,
    MapTileTheme theme,
  ) {
    final runePaint = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.01
      ..strokeCap = StrokeCap.round;
    final shardPaint = Paint()
      ..color = theme.energySoftColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 2; i++) {
      final center = Offset(
        tile.left + tile.width * (0.28 + _tileUnit(point, 81 + i) * 0.42),
        tile.top + tile.height * (0.26 + _tileUnit(point, 83 + i) * 0.44),
      );
      final radius = tileSize * (0.045 + _tileUnit(point, 85 + i) * 0.018);
      canvas.drawCircle(center, radius, runePaint);
      canvas.drawLine(
        center.translate(-radius * 0.8, 0),
        center.translate(radius * 0.8, 0),
        runePaint,
      );
    }

    final shardCenter = Offset(
      tile.left + tile.width * (0.18 + _tileUnit(point, 89) * 0.64),
      tile.top + tile.height * (0.2 + _tileUnit(point, 90) * 0.58),
    );
    final shardPath = Path()
      ..moveTo(shardCenter.dx, shardCenter.dy - tileSize * 0.045)
      ..lineTo(shardCenter.dx + tileSize * 0.035, shardCenter.dy)
      ..lineTo(shardCenter.dx, shardCenter.dy + tileSize * 0.055)
      ..lineTo(shardCenter.dx - tileSize * 0.035, shardCenter.dy)
      ..close();
    canvas.drawPath(shardPath, shardPaint);
  }

  void _drawForgePathTile(
    Canvas canvas,
    Rect rect,
    Rect tile,
    GridPoint point,
    MapTileTheme theme,
  ) {
    _drawPolishedTileFrame(
      canvas,
      rect,
      tile,
      topColor: theme.pathTopColor,
      midColor: theme.pathMidColor,
      bottomColor: theme.pathBottomColor,
      rimColor: theme.pathRimColor,
    );

    final seamPaint = Paint()
      ..color = theme.energySoftColor.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.01
      ..strokeCap = StrokeCap.round;
    final inset = tile.deflate(tileSize * 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, Radius.circular(tileSize * 0.03)),
      Paint()
        ..color = theme.pathInsetStrokeColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileSize * 0.012,
    );
    canvas.drawLine(
      Offset(tile.left + tile.width * 0.18, tile.top + tile.height * 0.36),
      Offset(tile.right - tile.width * 0.18, tile.top + tile.height * 0.36),
      seamPaint,
    );
    canvas.drawLine(
      Offset(tile.left + tile.width * 0.18, tile.bottom - tile.height * 0.32),
      Offset(tile.right - tile.width * 0.18, tile.bottom - tile.height * 0.32),
      seamPaint..color = theme.energySoftColor.withValues(alpha: 0.22),
    );

    _drawForgeEdgeHeat(canvas, tile, theme, intensity: 0.78);

    final emberPaint = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(tile.left + tile.width * 0.28, tile.top + tile.height * 0.68),
      tileSize * 0.01,
      emberPaint,
    );
    canvas.drawCircle(
      Offset(tile.right - tile.width * 0.25, tile.top + tile.height * 0.3),
      tileSize * 0.008,
      emberPaint,
    );
  }

  void _drawForgeBuildTile(
    Canvas canvas,
    Rect rect,
    Rect tile,
    GridPoint point,
    MapTileTheme theme,
  ) {
    _drawPolishedTileFrame(
      canvas,
      rect,
      tile,
      topColor: theme.buildTopColor,
      midColor: theme.buildMidColor,
      bottomColor: theme.buildBottomColor,
      rimColor: theme.buildRimColor,
    );

    final socket = Rect.fromCenter(
      center: tile.center,
      width: tile.width * 0.44,
      height: tile.height * 0.44,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(socket, Radius.circular(tileSize * 0.035)),
      Paint()
        ..color = const Color(0x8A061018)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(socket, Radius.circular(tileSize * 0.035)),
      Paint()
        ..color = theme.energySecondaryColor.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileSize * 0.011,
    );

    final inner = socket.deflate(tileSize * 0.055);
    canvas.drawOval(
      inner,
      Paint()
        ..color = theme.energySoftColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );

    _drawForgeEdgeHeat(canvas, tile, theme, intensity: 0.5);

    final rivetPaint = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    final rivetShadow = Paint()
      ..color = const Color(0x99000000)
      ..style = PaintingStyle.fill;
    final rivets = [
      Offset(tile.left + tile.width * 0.2, tile.top + tile.height * 0.2),
      Offset(tile.right - tile.width * 0.2, tile.top + tile.height * 0.2),
      Offset(tile.left + tile.width * 0.2, tile.bottom - tile.height * 0.2),
      Offset(tile.right - tile.width * 0.2, tile.bottom - tile.height * 0.2),
    ];

    for (final center in rivets) {
      canvas.drawCircle(
        center.translate(0, tileSize * 0.006),
        tileSize * 0.02,
        rivetShadow,
      );
      canvas.drawCircle(center, tileSize * 0.014, rivetPaint);
    }
  }

  void _drawForgeEdgeHeat(
    Canvas canvas,
    Rect tile,
    MapTileTheme theme, {
    required double intensity,
  }) {
    final glowPaint = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.18 * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSize * 0.018);
    final heatPaint = Paint()
      ..shader = Gradient.linear(
        tile.centerLeft,
        tile.centerRight,
        [
          theme.energyPrimaryColor.withValues(alpha: 0.18 * intensity),
          const Color(0xFFFFD58A).withValues(alpha: 0.55 * intensity),
          theme.energyPrimaryColor.withValues(alpha: 0.24 * intensity),
        ],
        const [0, 0.52, 1],
      );
    final vents = [
      Rect.fromLTWH(
        tile.left + tile.width * 0.2,
        tile.bottom - tile.height * 0.18,
        tile.width * 0.2,
        tileSize * 0.018,
      ),
      Rect.fromLTWH(
        tile.right - tile.width * 0.36,
        tile.top + tile.height * 0.17,
        tile.width * 0.16,
        tileSize * 0.014,
      ),
    ];

    for (final vent in vents) {
      final slit = RRect.fromRectAndRadius(
        vent,
        Radius.circular(tileSize * 0.008),
      );
      canvas.drawRRect(slit.inflate(tileSize * 0.01), glowPaint);
      canvas.drawRRect(slit, heatPaint);
    }
  }

  double _tileUnit(GridPoint point, int salt) {
    final n = math.sin(point.x * 12.9898 + point.y * 78.233 + salt * 37.719);
    return (n * 43758.5453).abs() % 1;
  }

  void _drawStoneDetails(Canvas canvas, Rect rect, GridPoint point) {
    final theme = map.tileTheme;
    final mortar = Paint()
      ..color = theme.stoneMortarColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final highlight = Paint()
      ..color = theme.stoneHighlightColor
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
    final theme = map.tileTheme;
    final center = rect.center;
    final radius = tileSize * 0.3;
    final alert = portalAlert.clamp(0.0, 1.0);
    final outer = Paint()
      ..color = Color.lerp(
        theme.portalOuterColor,
        theme.portalOuterAlertColor,
        alert,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * (0.07 + alert * 0.035);
    final inner = Paint()
      ..color = Color.lerp(
        theme.portalInnerColor,
        theme.portalInnerAlertColor,
        alert,
      )!;
    final base = Paint()
      ..color = theme.portalBaseColor
      ..style = PaintingStyle.fill;

    if (alert > 0) {
      canvas.drawCircle(
        center,
        radius * (1.28 + alert * 0.28),
        Paint()
          ..color = theme.portalOuterColor.withValues(alpha: 0.24 * alert)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tileSize * 0.035,
      );
      canvas.drawCircle(
        center,
        radius * (1.05 + alert * 0.32),
        Paint()..color = theme.portalPulseColor.withValues(alpha: 0.2 * alert),
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
        ..color = theme.portalGlowColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileSize * 0.025,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy),
      radius * 0.42,
      Paint()..color = theme.portalCoreColor.withValues(alpha: 0.67),
    );
  }

  void _drawPortalSwirl(Canvas canvas, double radius) {
    final theme = map.tileTheme;
    final glow = Paint()
      ..color = theme.portalGlowColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize * 0.035
      ..strokeCap = StrokeCap.round;
    final spiral = Paint()
      ..color = theme.portalSpiralColor.withValues(alpha: 0.8)
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
    final theme = map.tileTheme;
    final center = rect.center;
    final hit = nexusHitAlert.clamp(0.0, 1.0);
    final destruction = nexusDestructionProgress.clamp(0.0, 1.0);
    final damage = math.max(hit, destruction);
    final unit = tileSize;
    final pulse =
        ((math.sin(_portalSpin * 2.2) + 1) / 2) * (1 - destruction * 0.45);
    final activeGemColor = Color.lerp(
      theme.nexusGemColor,
      theme.nexusGemHitColor,
      damage,
    )!;
    final gemColor = Color.lerp(
      activeGemColor,
      const Color(0xFF51616B),
      destruction * 0.55,
    )!;
    final basePaint = Paint()
      ..color = Color.lerp(
        theme.nexusBaseColor,
        const Color(0xFF365063),
        damage * 0.28,
      )!;
    final shadowPaint = Paint()
      ..color = theme.nexusShadowColor.withValues(alpha: 0.92);

    if (damage > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(unit * 0.05),
          Radius.circular(unit * 0.08),
        ),
        Paint()
          ..color = const Color(0xFFFF3D3D).withValues(alpha: 0.26 * damage),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(unit * 0.08),
          Radius.circular(unit * 0.08),
        ),
        Paint()
          ..color = const Color(0xFFFF7A59).withValues(alpha: 0.75 * damage)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.045,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + unit * 0.38),
        width: unit * 0.76,
        height: unit * 0.2,
      ),
      Paint()..color = const Color(0x99000000),
    );

    final pedestal = Rect.fromCenter(
      center: Offset(center.dx, center.dy + unit * 0.27),
      width: unit * 0.68,
      height: unit * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pedestal, Radius.circular(unit * 0.04)),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        pedestal.deflate(unit * 0.035),
        Radius.circular(unit * 0.03),
      ),
      basePaint,
    );
    canvas.drawLine(
      Offset(pedestal.left + unit * 0.1, pedestal.center.dy),
      Offset(pedestal.right - unit * 0.1, pedestal.center.dy),
      Paint()
        ..color = theme.nexusGemStrokeColor.withValues(alpha: 0.24)
        ..strokeWidth = unit * 0.022
        ..strokeCap = StrokeCap.round,
    );

    final lowerPlinth = Path()
      ..moveTo(center.dx - unit * 0.28, center.dy + unit * 0.16)
      ..lineTo(center.dx - unit * 0.18, center.dy - unit * 0.06)
      ..lineTo(center.dx + unit * 0.18, center.dy - unit * 0.06)
      ..lineTo(center.dx + unit * 0.28, center.dy + unit * 0.16)
      ..close();
    canvas.drawPath(lowerPlinth, shadowPaint);
    canvas.drawPath(
      lowerPlinth.shift(Offset(0, -unit * 0.025)),
      Paint()
        ..shader = Gradient.linear(
          Offset(center.dx, center.dy - unit * 0.08),
          Offset(center.dx, center.dy + unit * 0.17),
          [
            Color.lerp(theme.nexusBaseColor, theme.nexusGemStrokeColor, 0.18)!,
            theme.nexusBaseColor,
          ],
        ),
    );

    final leftBrace = Path()
      ..moveTo(center.dx - unit * 0.28, center.dy + unit * 0.03)
      ..lineTo(center.dx - unit * 0.35, center.dy - unit * 0.16)
      ..lineTo(center.dx - unit * 0.18, center.dy - unit * 0.28)
      ..lineTo(center.dx - unit * 0.08, center.dy + unit * 0.02)
      ..close();
    final rightBrace = Path()
      ..moveTo(center.dx + unit * 0.28, center.dy + unit * 0.03)
      ..lineTo(center.dx + unit * 0.35, center.dy - unit * 0.16)
      ..lineTo(center.dx + unit * 0.18, center.dy - unit * 0.28)
      ..lineTo(center.dx + unit * 0.08, center.dy + unit * 0.02)
      ..close();
    final bracePaint = Paint()
      ..color = Color.lerp(
        theme.nexusBaseColor,
        theme.nexusGemStrokeColor,
        0.14,
      )!.withValues(alpha: 0.82);
    canvas.drawPath(leftBrace, shadowPaint);
    canvas.drawPath(rightBrace, shadowPaint);
    canvas.drawPath(leftBrace.shift(Offset(0, -unit * 0.018)), bracePaint);
    canvas.drawPath(rightBrace.shift(Offset(0, -unit * 0.018)), bracePaint);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - unit * 0.16),
        width: unit * (0.62 + pulse * 0.04),
        height: unit * (0.42 + pulse * 0.03),
      ),
      Paint()..color = gemColor.withValues(alpha: 0.08 + pulse * 0.05),
    );

    final gem = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx - unit * 0.22, center.dy - unit * 0.08)
      ..close();
    final leftFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx - unit * 0.22, center.dy - unit * 0.08)
      ..close();
    final topFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy - unit * 0.16)
      ..close();
    final rightFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.16)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..close();
    final innerFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx - unit * 0.08, center.dy - unit * 0.07)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx + unit * 0.08, center.dy - unit * 0.07)
      ..close();

    canvas.drawPath(gem, Paint()..color = gemColor);
    canvas.drawPath(
      leftFace,
      Paint()..color = Color.lerp(gemColor, theme.nexusGemStrokeColor, 0.42)!,
    );
    canvas.drawPath(
      topFace,
      Paint()..color = Color.lerp(gemColor, const Color(0xFFFFFFFF), 0.68)!,
    );
    canvas.drawPath(
      rightFace,
      Paint()..color = Color.lerp(gemColor, const Color(0xFF0B5D7D), 0.42)!,
    );
    canvas.drawPath(
      innerFace,
      Paint()
        ..color = const Color(
          0xFFFFFFFF,
        ).withValues(alpha: 0.18 + pulse * 0.08),
    );
    canvas.drawPath(
      gem,
      Paint()
        ..color = Color.lerp(
          theme.nexusGemStrokeColor,
          const Color(0xFFFFB39C),
          damage,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.035,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - unit * 0.11, center.dy - unit * 0.05)
        ..lineTo(center.dx, center.dy - unit * 0.18)
        ..lineTo(center.dx + unit * 0.11, center.dy - unit * 0.05),
      Paint()
        ..color = theme.portalPulseColor.withValues(alpha: 0.42 + pulse * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.026
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final crack = math.max(hit, destruction);
    if (crack > 0) {
      final crackPaint = Paint()
        ..color = const Color(0xFFFFD0C6).withValues(alpha: 0.66 * crack)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.018
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx - unit * 0.05, center.dy - unit * 0.24),
        Offset(center.dx + unit * 0.03, center.dy - unit * 0.08),
        crackPaint,
      );
      canvas.drawLine(
        Offset(center.dx + unit * 0.03, center.dy - unit * 0.08),
        Offset(center.dx - unit * 0.02, center.dy + unit * 0.08),
        crackPaint,
      );
      if (destruction > 0.25) {
        canvas.drawLine(
          Offset(center.dx + unit * 0.08, center.dy - unit * 0.22),
          Offset(center.dx - unit * 0.01, center.dy - unit * 0.02),
          crackPaint,
        );
        canvas.drawLine(
          Offset(center.dx - unit * 0.1, center.dy - unit * 0.12),
          Offset(center.dx + unit * 0.09, center.dy + unit * 0.09),
          crackPaint,
        );
      }
    }

    if (destruction > 0) {
      _drawNexusDestruction(canvas, rect, destruction);
    }
  }

  void _drawNexusDestruction(Canvas canvas, Rect rect, double progress) {
    final center = rect.center;
    final unit = tileSize;
    final burst = ((progress - 0.35) / 0.45).clamp(0.0, 1.0);
    final fade = (1 - progress).clamp(0.0, 1.0);

    if (burst > 0) {
      final radius = unit * (0.28 + burst * 0.92);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFFF8A5F).withValues(alpha: 0.38 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * (0.03 + 0.02 * fade),
      );
      canvas.drawCircle(
        center,
        unit * (0.16 + burst * 0.28),
        Paint()..color = const Color(0xFFFF594A).withValues(alpha: 0.14 * fade),
      );
    }

    if (progress < 0.3) {
      return;
    }

    final fragmentProgress = ((progress - 0.3) / 0.7).clamp(0.0, 1.0);
    final fragmentAlpha = (1 - progress * 0.52).clamp(0.0, 1.0);
    final offsets = <Offset>[
      Offset(-0.36, -0.48),
      Offset(0.38, -0.31),
      Offset(-0.44, 0.18),
      Offset(0.3, 0.34),
      Offset(0.04, -0.6),
    ];
    for (var i = 0; i < offsets.length; i++) {
      final offset = offsets[i];
      final fragmentCenter = Offset(
        center.dx + offset.dx * unit * fragmentProgress,
        center.dy + offset.dy * unit * fragmentProgress,
      );
      final angle = (i * 0.9 - 0.8) + fragmentProgress * (0.7 + i * 0.11);
      _drawNexusFragment(
        canvas,
        center: fragmentCenter,
        size: unit * (0.08 + (i % 2) * 0.018),
        angle: angle,
        alpha: fragmentAlpha,
      );
    }
  }

  void _drawNexusFragment(
    Canvas canvas, {
    required Offset center,
    required double size,
    required double angle,
    required double alpha,
  }) {
    final path = Path()
      ..moveTo(0, -size)
      ..lineTo(size * 0.72, -size * 0.12)
      ..lineTo(size * 0.28, size)
      ..lineTo(-size * 0.68, size * 0.42)
      ..close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(Offset(-size, -size), Offset(size, size), [
          const Color(0xFFE9FDFF).withValues(alpha: alpha),
          const Color(0xFF38C9E6).withValues(alpha: alpha),
          const Color(0xFFFF7A59).withValues(alpha: alpha * 0.72),
        ]),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE9FDFF).withValues(alpha: alpha * 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, size * 0.16),
    );
    canvas.restore();
  }

  Paint _paintFor(TileType type) {
    return Paint()
      ..color = switch (type) {
        TileType.path => map.tileTheme.pathMidColor,
        TileType.build => map.tileTheme.buildMidColor,
        TileType.blocked => const Color(0x00000000),
        TileType.spawn => map.tileTheme.spawnTileColor,
        TileType.core => map.tileTheme.coreTileColor,
      };
  }
}
