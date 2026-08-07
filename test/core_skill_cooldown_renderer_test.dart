import 'dart:ui' show Canvas, Color, Offset, PictureRecorder;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/core_skill_cooldown_renderer.dart';

void main() {
  test('core skill cooldown renderer draws inactive and active states', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    drawCoreSkillCooldownBar(
      canvas,
      center: const Offset(56, 40),
      tileSize: 48,
      progress: 0,
      accent: const Color(0xFF8EE6FF),
      active: false,
    );
    drawCoreSkillCooldownBar(
      canvas,
      center: const Offset(112, 40),
      tileSize: 48,
      progress: 1,
      accent: const Color(0xFFCFA7FF),
      active: true,
    );

    recorder.endRecording();
  });
}
