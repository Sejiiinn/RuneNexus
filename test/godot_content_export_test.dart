import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_stage_data.dart';
import '../tool/content/game_content_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generated Godot content exactly matches all live Dart definitions', () {
    final actual = exportGameContent();
    final encoded = encodeContent(actual);
    if (Platform.environment['UPDATE_GODOT_CONTENT'] == '1') {
      File(contentOutputPath).writeAsStringSync(encoded);
    }
    final cases = exportContentCases();
    final casesPath = 'test/fixtures/game_content_cases.json';
    if (Platform.environment['UPDATE_GODOT_CONTENT'] == '1') {
      File(casesPath).writeAsStringSync(encodeContent(cases));
    }
    expect(File(casesPath).readAsStringSync(), encodeContent(cases));
    expectTypes(jsonDecode(encodeContent(cases)), cases, r'$.cases');
    expect(
      File(contentOutputPath).readAsStringSync(),
      encoded,
      reason:
          r'Regenerate: UPDATE_GODOT_CONTENT=1 WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/godot_content_export_test.dart',
    );
    final decoded = jsonDecode(encoded);
    expectTypes(decoded, actual, r'$');
    final stages = actual['stages'] as List;
    expect(stages.length, gameStages.length);
    expect(stages.map((s) => (s as Map)['id']).toSet().length, stages.length);
    for (final stage in stages.cast<Map>()) {
      final waves = stage['waves'] as List;
      expect(
        waves.map((w) => (w as Map)['round']).toSet().length,
        waves.length,
      );
      final map = stage['map'] as Map;
      expect(
        (map['tiles'] as List).length,
        (map['columns'] as int) * (map['rows'] as int),
      );
    }
  });
}

// Equality alone treats 1 == 1.0; the interchange contract does not.
void expectTypes(Object? actual, Object? expected, String path) {
  if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    for (final key in expected.keys) {
      expectTypes((actual as Map)[key], expected[key], '$path.$key');
    }
  } else if (expected is List) {
    expect(actual, isA<List>(), reason: path);
    for (var i = 0; i < expected.length; i++) {
      expectTypes((actual as List)[i], expected[i], '$path[$i]');
    }
  } else if (expected is num) {
    expect(actual.runtimeType, expected.runtimeType, reason: path);
  }
}
