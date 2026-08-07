import 'dart:math' as math;
import 'dart:ui' show Canvas, PictureRecorder;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/turret_level_renderer.dart';
import 'package:rune_nexus/game/rendering/turret_shape_renderer.dart';

void main() {
  test('fireball origin follows the turret aim angle', () {
    const center = Offset(50, 50);

    expect(
      fireballOriginForTurret(center: center, size: 100, aimAngle: 0),
      const Offset(70, 50),
    );
    final downwardOrigin = fireballOriginForTurret(
      center: center,
      size: 100,
      aimAngle: math.pi / 2,
    );
    expect(downwardOrigin.dx, closeTo(50, 1e-9));
    expect(downwardOrigin.dy, closeTo(70, 1e-9));
  });

  test('turret level renderer draws every visual tier', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final renderer = TurretLevelRenderer();

    for (final level in const [1, 5, 8, 10]) {
      renderer.drawPowerAura(
        canvas,
        center: const Offset(56, 56),
        tileSize: 112,
        level: level,
      );
      renderer.drawBadge(
        canvas,
        center: const Offset(56, 56),
        tileSize: 112,
        level: level,
      );
    }

    recorder.endRecording();
  });
}
