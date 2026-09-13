// One-time export of existing Flutter status sprites; run with flutter test.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/status_effect_sprite_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export existing battlefield status sprites', () async {
    final cache = StatusEffectSpriteCache.create();
    final directory = Directory('assets/images/stage1_3d/ui/labels');
    directory.createSync(recursive: true);
    final sprites = {
      'burn_ember': cache.burnEmber,
      'burn_glow': cache.burnGlow,
      'burn_smoke': cache.burnSmoke,
      'slow_shard': cache.slowShard,
    };
    for (final entry in sprites.entries) {
      final data = await entry.value.toByteData(format: ImageByteFormat.png);
      await File('${directory.path}/${entry.key}.png').writeAsBytes(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    cache.dispose();
    await File(
      'assets/images/diamond_currency.png',
    ).copy('${directory.path}/diamond_currency.png');
  });
}
