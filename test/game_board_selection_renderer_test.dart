import 'dart:ui' show Canvas, Offset, PictureRecorder;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/rendering/game_board_selection_renderer.dart';

void main() {
  test('game board selection renderer draws every selection type', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    drawGameBoardSelection(
      canvas,
      origin: const Offset(20, 12),
      tileSize: 48,
      boardDistanceScale: 1,
      buildPoint: const GridPoint(2, 1),
      portalPoint: const GridPoint(0, 1),
      corePoint: const GridPoint(4, 1),
      buildTurret: gameTurrets[TurretType.arrow],
    );

    recorder.endRecording();
  });

  test('game board selection renderer accepts empty selection', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    drawGameBoardSelection(
      canvas,
      origin: Offset.zero,
      tileSize: 48,
      boardDistanceScale: 1,
      buildPoint: null,
      portalPoint: null,
      corePoint: null,
      buildTurret: null,
    );

    recorder.endRecording();
  });
}
