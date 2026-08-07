import 'package:flutter/painting.dart';

import '../../domain/map/grid_point.dart';
import '../../domain/turret/turret_definition.dart';
import 'turret_shape_renderer.dart';

void drawGameBoardSelection(
  Canvas canvas, {
  required Offset origin,
  required double tileSize,
  required double boardDistanceScale,
  required GridPoint? buildPoint,
  required GridPoint? portalPoint,
  required GridPoint? corePoint,
  required TurretDefinition? buildTurret,
}) {
  if (portalPoint != null) {
    final rect = _tileRect(origin, portalPoint, tileSize);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xCCB16DFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  if (corePoint != null) {
    final rect = _tileRect(origin, corePoint, tileSize);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x228EE6FF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xCC8EE6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  if (buildPoint == null) {
    return;
  }

  if (buildTurret != null) {
    _drawBuildGhost(
      canvas,
      center: _tileCenter(origin, buildPoint, tileSize),
      tileSize: tileSize,
      boardDistanceScale: boardDistanceScale,
      definition: buildTurret,
    );
  }

  canvas.drawRect(
    _tileRect(origin, buildPoint, tileSize),
    Paint()
      ..color = const Color(0x668EE6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
}

Rect _tileRect(Offset origin, GridPoint point, double tileSize) {
  return Rect.fromLTWH(
    origin.dx + point.x * tileSize + 2,
    origin.dy + point.y * tileSize + 2,
    tileSize - 4,
    tileSize - 4,
  );
}

Offset _tileCenter(Offset origin, GridPoint point, double tileSize) {
  return Offset(
    origin.dx + point.x * tileSize + tileSize / 2,
    origin.dy + point.y * tileSize + tileSize / 2,
  );
}

void _drawBuildGhost(
  Canvas canvas, {
  required Offset center,
  required double tileSize,
  required double boardDistanceScale,
  required TurretDefinition definition,
}) {
  final rangeFill = Paint()
    ..color = definition.color.withValues(alpha: 0.09)
    ..style = PaintingStyle.fill;
  final rangeStroke = Paint()
    ..color = definition.color.withValues(alpha: 0.42)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  final range = definition.range * boardDistanceScale;
  canvas.drawCircle(center, range, rangeFill);
  canvas.drawCircle(center, range, rangeStroke);

  final ghostSize = tileSize * 0.72;
  final ghostBounds = Rect.fromCenter(
    center: center,
    width: ghostSize,
    height: ghostSize,
  );
  canvas.saveLayer(
    ghostBounds.inflate(tileSize * 0.16),
    Paint()..color = const Color(0xAAFFFFFF),
  );
  canvas.translate(ghostBounds.left, ghostBounds.top);
  drawTurretShape(
    canvas,
    size: Size(ghostSize, ghostSize),
    type: definition.type,
    color: definition.color,
  );
  canvas.restore();
}
