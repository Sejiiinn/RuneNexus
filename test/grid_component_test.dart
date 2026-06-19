import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_stage_maps.dart';
import 'package:rune_nexus/game/components/grid_component.dart';

void main() {
  test('grid component renders after path guide cache invalidation', () {
    final grid = GridComponent(
      map: gameMap,
      origin: Vector2(12, 16),
      tileSize: 48,
    );

    _renderFrame(grid);

    grid.updateLayout(origin: Vector2(24, 32), tileSize: 56);

    _renderFrame(grid);
  });
}

void _renderFrame(GridComponent grid) {
  grid.update(1 / 60);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  grid.render(canvas);
  recorder.endRecording().dispose();
}
