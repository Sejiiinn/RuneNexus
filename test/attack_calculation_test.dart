import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/combat/calculation_fixture.dart';

void main() {
  final fixtures =
      jsonDecode(
            File('test/fixtures/combat_calculation.json').readAsStringSync(),
          )
          as List;
  for (final fixture in fixtures) {
    test(fixture['name'] as String, () {
      compareValues(
        evaluateFixture(fixture['input'] as Map<String, dynamic>),
        fixture['expected'],
        fixture['name'] as String,
      );
    });
  }

  for (final entry in <double, double>{
    1: 50,
    1.5: 62.5,
    2: 75,
    3: 100,
  }.entries) {
    test('burn mirrors half of critical bonus at ${entry.key}x', () {
      final result = evaluateFixture({
        'resistance': {'family': 'elemental'},
        'baseDamage': 300,
        'traitMultiplier': 2,
        'status': {
          'damage': 100,
          'burnDamagePerSecondScale': .5,
          'burnDurationSeconds': 2,
          'hasDamageOverTime': true,
          'criticalMultiplier': entry.key,
        },
      });
      final effects = result['effects'] as List<Map<String, Object?>>;
      expect(result['damage'], 600);
      expect(effects.single['damagePerSecond'], entry.value);
      expect(effects.single['duration'], 2);
      expect(effects.single['damageMultiplier'], 1);
    });
  }
}
