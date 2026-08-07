import 'dart:ui' show Canvas, PictureRecorder, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/game_scene_effect_renderer.dart';

void main() {
  test('game scene effect renderer draws background and screen alert', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    drawGameSpaceBackground(
      canvas,
      size: const Size(320, 180),
      animationTime: 2.5,
    );
    drawNexusScreenAlert(canvas, size: const Size(320, 180), alert: 0.8);

    recorder.endRecording();
  });

  test('game scene effect renderer accepts inactive bounds and alert', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    drawGameSpaceBackground(canvas, size: Size.zero, animationTime: 0);
    drawNexusScreenAlert(canvas, size: Size.zero, alert: 0);

    recorder.endRecording();
  });
}
