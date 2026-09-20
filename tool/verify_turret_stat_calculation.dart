import 'dart:convert';
import 'dart:io';
import 'combat/turret_stat_fixture.dart';

/// Run from the repository root through scripts/in_app_server_macos.sh dart.
/// Optional arguments override the Godot executable and fixture JSON paths.
Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  var fixturesPath = args.length > 1
      ? args[1]
      : '$root/test/fixtures/turret_stat_calculation.json';
  final fixtures = jsonDecode(File(fixturesPath).readAsStringSync()) as List;
  if (args.length < 2) {
    fixtures.addAll(
      jsonDecode(
            File(
              '$root/test/fixtures/turret_stat_critical_boundaries.json',
            ).readAsStringSync(),
          )
          as List,
    );
  }
  final godot = args.isNotEmpty
      ? args.first
      : '$root/build/godot-preview/tools/Godot.app/Contents/MacOS/Godot';
  final temp = Directory.systemTemp.createTempSync('rune-combat-');
  try {
    if (args.length < 2) {
      fixturesPath = '${temp.path}/fixtures.json';
      File(fixturesPath).writeAsStringSync(jsonEncode(fixtures));
    }
    // An isolated project avoids loading game autoloads, importing assets, or
    // touching the live editor's project/cache. Only the pure rules are copied.
    Directory('${temp.path}/combat').createSync();
    File('${temp.path}/project.godot').writeAsStringSync('config_version=5\n');
    File(
      '$root/godot/combat/turret_stat_calculation.gd',
    ).copySync('${temp.path}/combat/turret_stat_calculation.gd');
    File(
      '$root/godot/verify_turret_stat_calculation.gd',
    ).copySync('${temp.path}/verify_turret_stat_calculation.gd');
    final output = '${temp.path}/results.json';
    final process = await Process.run(godot, [
      '--headless',
      '--path',
      temp.path,
      '--script',
      'res://verify_turret_stat_calculation.gd',
      '--',
      fixturesPath,
      output,
    ]);
    if (process.exitCode != 0 || !File(output).existsSync()) {
      throw StateError(
        'Godot comparison failed: ${process.stdout}\n${process.stderr}',
      );
    }
    final results = jsonDecode(File(output).readAsStringSync()) as List;
    if (results.length != fixtures.length) {
      throw StateError('Fixture count mismatch');
    }
    for (var i = 0; i < fixtures.length; i++) {
      final fixture = fixtures[i] as Map<String, dynamic>;
      final name = fixture['name'] as String;
      final dart = evaluateTurretFixture(
        fixture['input'] as Map<String, dynamic>,
      );
      compareValues(
        dart,
        fixture['expected'],
        '$name Dart vs fixed expectation',
      );
      compareValues(results[i]['name'], name, '$name identity');
      compareValues(
        results[i]['result'],
        fixture['expected'],
        '$name Godot vs fixed expectation',
      );
      compareValues(results[i]['result'], dart, '$name Godot vs Dart');
      for (final result in [dart, results[i]['result'] as Map]) {
        compareCriticalChanceRegion(
          result['criticalChance'],
          fixture['expected']['criticalChance'],
          '$name critical clamp branch',
        );
      }
    }
    stdout.writeln(
      'PASS: ${fixtures.length} cases agree in Dart and Godot (numeric tolerance 1e-10; structure exact).',
    );
  } finally {
    temp.deleteSync(recursive: true);
  }
}
