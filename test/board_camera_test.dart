import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/systems/board_camera.dart';

BoardCamera _camera() => BoardCamera()
  ..configure(
    center: Vector2(200, 300),
    boardSize: Vector2(320, 400),
    tileSize: 40,
  );

void main() {
  test('drawing, hit testing and popup anchors use the same transform', () {
    final camera = _camera()
      ..beginGesture(Vector2(180, 280))
      ..updateGesture(scale: 1.6, focal: Vector2(200, 310));
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    camera.applyTransform(canvas);
    final transform = canvas.getTransform();
    recorder.endRecording().dispose();

    for (final point in [
      Vector2(40, 100),
      Vector2(200, 300),
      Vector2(360, 500),
    ]) {
      final screen = camera.worldToScreen(point);
      expect(screen.x, closeTo(transform[0] * point.x + transform[12], 1e-4));
      expect(screen.y, closeTo(transform[5] * point.y + transform[13], 1e-4));
      expect((camera.screenToWorld(screen) - point).length, lessThan(1e-8));
    }
  });

  test(
    'reward viewport exposes an edge without changing the view on entry',
    () {
      final camera = _camera();
      const viewport = Rect.fromLTWH(120, 200, 160, 200);
      final before = camera.offset;
      final candidate = camera.clampOffset(
        Vector2(-1000, -1000),
        camera.zoom,
        interactionViewport: viewport,
      );
      expect(camera.offset, before);
      camera.moveBy(candidate, interactionViewport: viewport);
      final farEdge = camera.worldToScreen(Vector2(360, 500));
      expect(farEdge.x, closeTo(viewport.right, 1e-8));
      expect(farEdge.y, closeTo(viewport.bottom, 1e-8));
    },
  );

  test(
    'resize preserves an in-bounds view and resets obsolete gesture anchors',
    () {
      final camera = _camera()
        ..beginGesture(Vector2(200, 300))
        ..updateGesture(scale: 1.5, focal: Vector2(220, 330));
      final before = camera.offset;
      camera.configure(
        center: Vector2(300, 300),
        boardSize: Vector2(500, 400),
        tileSize: 40,
      );
      expect(camera.zoom, 1.5);
      expect(camera.offset, before);
      camera.updateGesture(scale: 2, focal: Vector2(100, 100));
      expect(camera.zoom, 1.5);
      expect(camera.offset, before);
    },
  );

  test('reset and exposed vectors cannot retain or mutate a previous view', () {
    final camera = _camera()
      ..beginGesture(Vector2(200, 300))
      ..updateGesture(scale: 2, focal: Vector2(250, 350));
    camera.offset.setZero();
    expect(camera.offset, Vector2(50, 50));
    camera.reset();
    camera.updateGesture(scale: 2, focal: Vector2(250, 350));
    expect(camera.zoom, 1);
    expect(camera.offset, Vector2.zero());
  });
}
