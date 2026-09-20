import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';

Map<String, String> numericTypes(Object? value, [String path = '']) {
  if (value is num) return {path: value is int ? 'int' : 'float'};
  final result = <String, String>{};
  if (value is Map) {
    for (final key in value.keys) {
      result.addAll(numericTypes(value[key], '$path/$key'));
    }
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      result.addAll(numericTypes(value[i], '$path/$i'));
    }
  }
  return result;
}

void main() {
  test('Godot save fixtures retain the real Dart codec results', () {
    final inputs =
        jsonDecode(
              File(
                'test/fixtures/godot_save_codec_inputs.json',
              ).readAsStringSync(),
            )
            as List;
    final actual = inputs.map((input) {
      final decoded = GameSaveData.fromJson(input)?.toJson();
      return {
        'canonical': GameSaveData.isCanonicalVersion2Envelope(input),
        'decoded': decoded,
        'numericTypes': numericTypes(decoded),
      };
    }).toList();
    final file = File('test/fixtures/godot_save_codec_expected.json');
    if (Platform.environment['UPDATE_GODOT_SAVE_FIXTURES'] == '1') {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(actual)}\n',
      );
    }
    expect(jsonDecode(file.readAsStringSync()), actual);
  });

  test(
    'Dart to Godot file save and back preserves values and numeric types',
    () async {
      final executable =
          Platform.environment['GODOT_BIN'] ??
          '${Directory.current.path}/build/godot-preview/tools/Godot.app/Contents/MacOS/Godot';
      if (!File(executable).existsSync()) {
        markTestSkipped(
          'Set GODOT_BIN to validate the cross-engine file roundtrip.',
        );
        return;
      }
      final temporary = await Directory.systemTemp.createTemp(
        'save-roundtrip-',
      );
      try {
        final root = temporary.path;
        await Directory('$root/app').create();
        await Directory('$root/fixtures').create();
        for (final source in Directory(
          'godot/app',
        ).listSync().whereType<File>()) {
          if (source.path.endsWith('.gd')) {
            await source.copy('$root/app/${source.uri.pathSegments.last}');
          }
        }
        await File(
          'test/fixtures/godot_save_codec_inputs.json',
        ).copy('$root/fixtures/godot_save_codec_inputs.json');
        await File(
          'godot/verify_save_roundtrip.gd',
        ).copy('$root/verify_save_roundtrip.gd');
        await File('$root/project.godot').writeAsString(
          '[application]\nconfig/name="Save roundtrip"\n'
          '[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
        );
        final imported = await Process.run(executable, [
          '--headless',
          '--editor',
          '--import',
          '--path',
          root,
          '--quit',
        ]);
        expect(
          imported.exitCode,
          0,
          reason: '${imported.stdout}\n${imported.stderr}',
        );
        final process = await Process.start(executable, [
          '--headless',
          '--path',
          root,
          '--script',
          'verify_save_roundtrip.gd',
        ]);
        final stdout = process.stdout.transform(utf8.decoder).join();
        final stderr = process.stderr.transform(utf8.decoder).join();
        int code;
        try {
          code = await process.exitCode.timeout(const Duration(seconds: 30));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
          fail('Godot roundtrip timed out: ${await stdout} ${await stderr}');
        }
        final output = '${await stdout}\n${await stderr}';
        expect(code, 0, reason: output);
        expect(output, isNot(contains('SCRIPT ERROR')), reason: output);
        final actual =
            jsonDecode(File('$root/roundtrip-results.json').readAsStringSync())
                as List;
        final expected =
            jsonDecode(
                  File(
                    'test/fixtures/godot_save_codec_expected.json',
                  ).readAsStringSync(),
                )
                as List;
        expect(actual, hasLength(expected.length));
        for (var index = 0; index < actual.length; index++) {
          expect(
            actual[index],
            expected[index]['decoded'],
            reason: 'serialized value fixture $index',
          );
          final canonical = GameSaveData.fromJson(actual[index])?.toJson();
          expect(
            numericTypes(actual[index]),
            expected[index]['numericTypes'],
            reason: 'serialized numeric types fixture $index',
          );
          expect(
            canonical,
            expected[index]['decoded'],
            reason: 'file roundtrip fixture $index',
          );
          expect(
            numericTypes(canonical),
            expected[index]['numericTypes'],
            reason: 'file roundtrip types $index',
          );
        }
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
