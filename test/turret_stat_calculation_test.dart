import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/combat/turret_stat_calculation.dart';
import 'package:rune_nexus/domain/combat/turret_stat_input.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';

import '../tool/combat/turret_stat_fixture.dart';
import '../tool/verify_turret_stat_calculation.dart' as parity;
import 'helpers/turret_stat_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = [
    for (final path in [
      'test/fixtures/turret_stat_calculation.json',
      'test/fixtures/turret_stat_critical_boundaries.json',
    ])
      ...(jsonDecode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>(),
  ];

  for (final fixture in fixtures) {
    test('fixed original turret output ${fixture['name']}', () {
      final built = buildFixture(fixture['config'] as Map<String, dynamic>);
      final input = fixture['input'] as Map<String, dynamic>;
      compareCriticalChanceRegion(
        built.turret.criticalChance,
        fixture['expected']['criticalChance'],
        '${fixture['name']} real critical clamp branch',
      );
      // The runtime adapter is tested against the independently captured input,
      // not only against another invocation of the extracted calculator.
      compareValues(
        fixtureInput(built.turret, built.game, built.cleanup).toJson(),
        input,
        '${fixture['name']} real input',
      );
      compareValues(
        componentOutput(built.turret),
        fixture['expected'],
        '${fixture['name']} component vs original',
      );
      compareValues(
        evaluateTurretFixture(input),
        fixture['expected'],
        '${fixture['name']} pure vs original',
      );
    });
  }

  for (final type in [
    'arrow',
    'cannon',
    'magic',
    'frost',
    'sniper',
    'lightning',
  ]) {
    test('$type firing snapshot survives producer changes', () {
      final fixture = fixtures.firstWhere((f) {
        final config = f['config'] as Map;
        return config['type'] == type &&
            config['level'] == 7 &&
            config['boost'] == 1;
      });
      final built = buildFixture(fixture['config'] as Map<String, dynamic>);
      final turret = built.turret;
      final attack = turret.createAttackSnapshot(criticalMultiplier: 2.15);
      final saved = snapshotOutput(attack);
      final original = turret.damage;
      turret.upgradeLevel();
      expect(turret.damage, isNot(original));
      compareValues(snapshotOutput(attack), saved, 'after level change');
      turret.removeGemAt(0);
      turret.equipGem(GemType.damageAmplifier, 0);
      compareValues(snapshotOutput(attack), saved, 'after gem change');
      final beforeResearch = turret.damage;
      built.game.boost =
          2; // Changes already-resolved module and research inputs.
      built.game.critBonus = .8;
      expect(turret.damage, isNot(beforeResearch));
      compareValues(
        snapshotOutput(attack),
        saved,
        'after module/research change',
      );
      final beforeScale = turret.range;
      built.game.scale *= .65;
      expect(turret.range, isNot(beforeScale));
      compareValues(snapshotOutput(attack), saved, 'after board scale change');
      final next = turret.createAttackSnapshot();
      expect(next.damage, turret.damage);
      expect(next.range, turret.range);
      expect(next.damage, isNot(attack.damage));
      expect(next.criticalMultiplier, 1);
    });
  }

  test('capture freezes collections and caller owns critical result', () {
    final original = fixtures.first['input'] as Map<String, dynamic>;
    final json = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    final input = TurretStatInput.fromJson(json);
    final captured = TurretStatInput.capture(input);
    final calculator = TurretStatCalculation(captured);
    final expected = calculator.damage;
    (json['gems'] as List).add('damageAmplifier');
    (json['definition']['attackTags'] as List).clear();
    expect(calculator.damage, expected);
    expect(
      () => captured.gems.add(GemType.damageAmplifier),
      throwsUnsupportedError,
    );
    expect(
      () => captured.definition.attackTags.clear(),
      throwsUnsupportedError,
    );
    for (final critical in [-2.0, 0.0, 1.0, 2.15]) {
      expect(
        calculator
            .createFiringStats(criticalMultiplier: critical)
            .criticalMultiplier,
        critical,
      );
    }
  });

  test('cleanup expiry immediately changes live attack rate', () {
    final fixture = fixtures.firstWhere((f) => f['config']['cleanup'] == true);
    final built = buildFixture(fixture['config'] as Map<String, dynamic>);
    final boosted = built.turret.attackRate;
    final snapshot = built.turret.createAttackSnapshot();
    final saved = snapshotOutput(snapshot);
    built.turret.update(3.1);
    expect(built.turret.attackRate, closeTo(boosted / 1.4, 1e-10));
    compareValues(snapshotOutput(snapshot), saved, 'cleanup expiry');
  });

  test('Godot agrees with every fixed original turret output', () async {
    final godot =
        Platform.environment['GODOT_BIN'] ??
        '${Directory.current.path}/build/godot-preview/tools/Godot.app/Contents/MacOS/Godot';
    if (!File(godot).existsSync()) {
      markTestSkipped('Set GODOT_BIN to run Godot parity');
      return;
    }
    await parity.main([godot]);
  });
}
