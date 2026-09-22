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
    'verify_native_session.gd': 'PASS native session:',
    'verify_native_wave_core.gd': 'PASS native wave/core:',
    'verify_native_core_defense.gd': 'PASS native core defense:',
    'verify_native_enemy_state.gd': null,
    'verify_save_codec.gd': 'SAVE_CODEC_FIXTURES count=',
    'verify_local_save_store.gd': null,
    'verify_run_save_adapter.gd': 'failures=[]',
    'verify_content_run_save.gd': 'CONTENT_RUN_SAVE failures=0',
    'verify_quest_progress.gd': 'quest progression Dart parity PASS:',
    'verify_reward_snapshot.gd': 'authoritative snapshot Dart parity PASS:',
    'verify_reward_settlement.gd': '"ok":true',
    'verify_run_commands.gd': 'failures=[]',
    'verify_battle_hud.gd': 'PASS battle HUD:',
    'verify_battle_rewards.gd': 'PASS battle rewards:',
    'verify_lobby.gd': 'LOBBY_SMOKE_OK',
    'verify_lobby_growth.gd': 'PASS growth pages:',
    'verify_lobby_core.gd': 'PASS lobby core:',
    'verify_lobby_collection.gd': 'PASS lobby_collection:',
    'verify_lobby_stages.gd': 'PASS stage restoration:',
    'verify_app_selection.gd': 'PASS app selection:',
    'verify_app_presentation.gd': 'PASS independent presentation:',
  };

  setUpAll(() async {
    if (!available) return;
    temporary = await Directory.systemTemp.createTemp('native-regressions-');
    final root = temporary!.path;
    await Directory('$root/godot/combat').create(recursive: true);
    await Directory('$root/godot/app').create(recursive: true);
    await Directory('$root/godot/fixtures').create(recursive: true);
    await Directory('$root/godot/content').create(recursive: true);
    for (final folder in ['session', 'ui']) {
      await Directory('$root/godot/$folder').create(recursive: true);
      if (!Directory('godot/$folder').existsSync()) continue;
      for (final source in Directory(
        'godot/$folder',
      ).listSync().whereType<File>()) {
        if (source.path.endsWith('.gd') || source.path.endsWith('.json')) {
          await source.copy(
            '$root/godot/$folder/${source.uri.pathSegments.last}',
          );
        }
      }
    }
    for (final source in Directory(
      'godot/content',
    ).listSync().whereType<File>()) {
      if (source.path.endsWith('.gd') || source.path.endsWith('.json')) {
        await source.copy(
          '$root/godot/content/${source.uri.pathSegments.last}',
        );
      }
    }
    for (final source in Directory('godot/app').listSync().whereType<File>()) {
      if (source.path.endsWith('.gd')) {
        await source.copy('$root/godot/app/${source.uri.pathSegments.last}');
      }
    }
    for (final name in ['inputs', 'expected']) {
      await File(
        'test/fixtures/godot_save_codec_$name.json',
      ).copy('$root/godot/fixtures/godot_save_codec_$name.json');
    }
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
      'quest_progress_cases.json',
      'reward_snapshot_cases.json',
      'growth_cases.json',
      'growth_game_cases.json',
    ]) {
      await File('test/fixtures/$fixture').copy('$root/test/fixtures/$fixture');
    }
    await File('$root/godot/project.godot').writeAsString(
      '[application]\nconfig/name="Native regression tests"\n'
      '[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
    );
    final imported = await Process.run(executable, [
      '--headless',
      '--editor',
      '--import',
      '--path',
      '$root/godot',
      '--quit',
    ]);
    expect(
      imported.exitCode,
      0,
      reason: '${imported.stdout}\n${imported.stderr}',
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
      final process = await Process.start(
        executable,
        [
          '--headless',
          '--path',
          '${temporary!.path}/godot',
          '--script',
          'res://${entry.key}',
        ],
        environment: {'TMPDIR': temporary!.path},
      );
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
