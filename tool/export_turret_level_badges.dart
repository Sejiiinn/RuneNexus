// Run with flutter test; this is an asset exporter, not a production test suite.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rune_nexus/game/rendering/turret_level_renderer.dart';

const _logicalTileSize = 48.0; // RuneNexusGame._designTileSize.
const _pixelsPerTile = 256;
const _frameWidth = 256;
const _frameHeight = 144;
const _levels = 10;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export original turret level badges', () async {
    const fontPath = String.fromEnvironment('BADGE_FONT_PATH');
    if (fontPath.isEmpty) {
      throw StateError(
        'Pass --dart-define=BADGE_FONT_PATH=/path/to/Roboto.ttf',
      );
    }
    final font = ByteData.sublistView(await File(fontPath).readAsBytes());
    // Explicit family avoids flutter_test's forced Ahem fallback.
    await (FontLoader('BadgeRoboto')..addFont(Future.value(font))).load();
    final originalDisableShadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final renderer = TurretLevelRenderer(fontFamily: 'BadgeRoboto');
      const scale = _pixelsPerTile / _logicalTileSize;
      for (var level = 1; level <= _levels; level++) {
        canvas.save();
        canvas.translate((level - 1) * _frameWidth.toDouble(), 0);
        canvas.clipRect(
          const Rect.fromLTWH(0, 0, _frameWidth * 1.0, _frameHeight * 1.0),
        );
        canvas.scale(scale);
        renderer.drawBadge(
          canvas,
          // Remove drawBadge's +0.3 tile anchor offset, not any ornament.
          center: const Offset(
            _frameWidth / (2 * scale),
            _frameHeight / (2 * scale) - _logicalTileSize * 0.3,
          ),
          tileSize: _logicalTileSize,
          level: level,
        );
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(_frameWidth * _levels, _frameHeight);
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final bounds = <List<int>>[];
      for (var frame = 0; frame < _levels; frame++) {
        var left = _frameWidth;
        var top = _frameHeight;
        var right = -1;
        var bottom = -1;
        for (var y = 0; y < _frameHeight; y++) {
          for (var x = 0; x < _frameWidth; x++) {
            final offset =
                (y * _frameWidth * _levels + frame * _frameWidth + x) * 4;
            if (rgba.getUint8(offset + 3) == 0) continue;
            left = x < left ? x : left;
            top = y < top ? y : top;
            right = x > right ? x : right;
            bottom = y > bottom ? y : bottom;
          }
        }
        expect(left, greaterThanOrEqualTo(8));
        expect(top, greaterThanOrEqualTo(8));
        expect(right, lessThan(_frameWidth - 8));
        expect(bottom, lessThan(_frameHeight - 8));
        bounds.add([left, top, right + 1, bottom + 1]);
      }
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final output = File('assets/images/stage1_3d/ui/turret_levels.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png.buffer.asUint8List());
      // Metadata is printed for the consuming Godot implementation and README.
      stdout.writeln(
        jsonEncode({
          'file': output.path,
          'atlasSize': [_frameWidth * _levels, _frameHeight],
          'frameSize': [_frameWidth, _frameHeight],
          'frameCount': _levels,
          'frameIndex': 'level - 1',
          'badgeCenterPx': [_frameWidth / 2, _frameHeight / 2],
          'logicalTileSize': _logicalTileSize,
          'pixelsPerTile': _pixelsPerTile,
          'removedTileCenterOffset': [0, 0.3],
          'frameOpaqueBoundsExclusive': bounds,
          'pngBytes': png.lengthInBytes,
        }),
      );
      image.dispose();
      picture.dispose();
    } finally {
      debugDisableShadows = originalDisableShadows;
    }
  });
}
