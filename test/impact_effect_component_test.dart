import 'dart:ui' show Canvas, Color, Paint, PictureRecorder, Rect;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/components/impact_effect_component.dart';

void main() {
  test(
    'impact effect component renders every style during its lifetime',
    () async {
      final atlasRecorder = PictureRecorder();
      Canvas(atlasRecorder).drawRect(
        const Rect.fromLTWH(0, 0, 4, 3),
        Paint()..color = const Color(0xFFFF7B2F),
      );
      final cannonBlastAtlas = await atlasRecorder.endRecording().toImage(4, 3);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      try {
        for (final style in ImpactEffectStyle.values) {
          final effect = ImpactEffectComponent(
            position: Vector2.zero(),
            color: const Color(0xFFFF7B2F),
            style: style,
            radius: 42,
            cannonBlastSpriteSheet: style == ImpactEffectStyle.blast
                ? cannonBlastAtlas
                : null,
            simulationSpeed: 4,
            randomSeed: 7,
          );

          effect.render(canvas);
          effect.update(0.48);
          effect.render(canvas);
        }
      } finally {
        cannonBlastAtlas.dispose();
        recorder.endRecording();
      }
    },
  );
}
