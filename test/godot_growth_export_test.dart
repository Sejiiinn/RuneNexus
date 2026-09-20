import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/content/growth_export.dart';
import '../tool/content/growth_game_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Godot growth content and real Dart action outcomes are current',
    () async {
      final gameCases = await exportGrowthGameCases();
      final outputs = {
        'test/fixtures/growth_game_cases.json': gameCases,
        growthContentPath: {
          ...exportGrowthContent(),
          'coreConfig': gameCases['coreConfig'],
        },
        'test/fixtures/growth_progression_cases.json': exportProgressionCases(),
        'test/fixtures/growth_cases.json': exportGrowthCases(),
      };
      for (final e in outputs.entries) {
        final encoded = encodeGrowth(e.value);
        if (Platform.environment['UPDATE_GODOT_GROWTH'] == '1') {
          File(e.key).writeAsStringSync(encoded);
        }
        expect(
          File(e.key).readAsStringSync(),
          encoded,
          reason:
              'Regenerate with UPDATE_GODOT_GROWTH=1 flutter test test/godot_growth_export_test.dart',
        );
      }
    },
  );
}
