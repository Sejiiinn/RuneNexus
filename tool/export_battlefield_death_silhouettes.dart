// Run with flutter test: bakes the original renderer, without redrawing its shapes.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/game/rendering/enemy_shape_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export original death silhouettes', () async {
    const cell = 192;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final type in EnemyType.values) {
      canvas.save();
      canvas.translate(type.index * cell.toDouble() + 32, 32);
      canvas.scale(4);
      drawEnemyShape(
        canvas,
        size: const ui.Size(32, 32),
        type: type,
        color: gameEnemies[type]!.color,
        strokeWidth: 1.2,
      );
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(cell * EnemyType.values.length, cell);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final output = File('assets/images/stage1_3d/ui/death_silhouettes.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(png.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
