import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final executable =
      Platform.environment['GODOT_BIN'] ??
      '${Directory.current.path}/build/godot-preview/tools/Godot.app/Contents/MacOS/Godot';
  final available = File(executable).existsSync();
  Directory? temporary;
  const scripts = {
    'verify_legacy_combat_regressions.gd': 'PASS legacy combat replacements:',
    'verify_native_combat_runtime.gd': 'PASS native combat runtime:',
    'verify_native_wave_core.gd': 'PASS native wave/core:',
    'verify_native_core_defense.gd': 'PASS native core defense:',
    'verify_native_enemy_state.gd': null,
  };

  setUpAll(() async {
    if (!available) return;
    temporary = await Directory.systemTemp.createTemp('native-regressions-');
    final root = temporary!.path;
    await Directory('$root/godot/combat').create(recursive: true);
    await Directory('$root/test/fixtures').create(recursive: true);
    // Keep fixture paths identical while isolating caches from editor/builds.
    for (final source in Directory(
      'godot/combat',
    ).listSync().whereType<File>()) {
      if (source.path.endsWith('.gd')) {
        await source.copy('$root/godot/combat/${source.uri.pathSegments.last}');
      }
    }
    for (final script in scripts.keys) {
      await File('godot/$script').copy('$root/godot/$script');
    }
    for (final fixture in [
      'turret_stat_calculation.json',
      'native_wave_core_timing.json',
    ]) {
      await File('test/fixtures/$fixture').copy('$root/test/fixtures/$fixture');
    }
    await File('$root/godot/project.godot').writeAsString(
      '[application]\nconfig/name="Native regression tests"\n'
      '[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
    );
  });

  tearDownAll(() async {
    await temporary?.delete(recursive: true);
  });

  for (final entry in scripts.entries) {
    test('Godot authoritative regression: ${entry.key}', () async {
      if (!available) {
        markTestSkipped(
          'Godot executable unavailable at $executable; set GODOT_BIN to run '
          'the native combat regression suite.',
        );
        return;
      }
      final process = await Process.start(executable, [
        '--headless',
        '--path',
        '${temporary!.path}/godot',
        '--script',
        'res://${entry.key}',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(const Duration(seconds: 20));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        fail(
          '${entry.key} timed out after 20s\n${await stdout}\n${await stderr}',
        );
      }
      final output = '${await stdout}\n${await stderr}';
      expect(exitCode, 0, reason: output);
      // Godot may exit 0 despite parser/runtime errors, so exit code alone is
      // insufficient. Assertions can also leave SceneTree running until timeout.
      expect(
        RegExp(
          r'(^|\n)\s*(?:SCRIPT ERROR:|ERROR:|Parse Error|Assertion failed)',
          caseSensitive: false,
        ).hasMatch(output),
        isFalse,
        reason: output,
      );
      if (entry.value != null) {
        expect(output, contains(entry.value!), reason: output);
      } else {
        final summary = output
            .split('\n')
            .where((line) => line.startsWith('{'));
        expect(summary, hasLength(1), reason: output);
        final result = jsonDecode(summary.single) as Map<String, dynamic>;
        expect(result['checks'], greaterThan(0), reason: output);
        expect(result['failures'], isEmpty, reason: output);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  }
}
