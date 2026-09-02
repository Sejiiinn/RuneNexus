import 'dart:ui' show Canvas, Color, PictureRecorder;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/components/impact_effect_component.dart';

void main() {
  test('impact effect component renders every style during its lifetime', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    for (final style in ImpactEffectStyle.values) {
      final effect = ImpactEffectComponent(
        position: Vector2.zero(),
        color: const Color(0xFFFF7B2F),
        style: style,
        radius: 42,
      );

      effect.render(canvas);
      effect.update(0.12);
      effect.render(canvas);
    }

    recorder.endRecording();
  });
}
