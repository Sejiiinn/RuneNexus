import 'package:rune_nexus/domain/combat/attack_calculation.dart';

double number(Map<String, dynamic> input, String key, [double fallback = 0]) =>
    (input[key] as num?)?.toDouble() ?? fallback;

Map<String, Object?> evaluateFixture(Map<String, dynamic> input) {
  final r = input['resistance'] as Map<String, dynamic>;
  final resistance = AttackResistanceInput(
    family: AttackDamageFamily.values.byName(r['family'] as String),
    familyResistance: number(r, 'familyResistance'),
    tags: (r['tags'] as List<dynamic>? ?? []).cast<String>(),
    extraTags: (r['extraTags'] as List<dynamic>? ?? []).cast<String>(),
    tagResistances: {
      for (final entry
          in (r['tagResistances'] as Map<String, dynamic>? ?? {}).entries)
        entry.key: (entry.value as num).toDouble(),
    },
    enemyPhysicalReduction: number(r, 'enemyPhysicalReduction'),
    attackPhysicalReduction: number(r, 'attackPhysicalReduction'),
    enemyElementalReduction: number(r, 'enemyElementalReduction'),
  );
  final hit = AttackCalculation.resolveDamage(
    resistance: resistance,
    baseDamage: number(input, 'baseDamage'),
    traitMultiplier: number(input, 'traitMultiplier', 1),
  );
  final s = input['status'] as Map<String, dynamic>? ?? {};
  final effects = AttackCalculation.resolveStatuses(
    AttackStatusInput(
      damage: number(s, 'damage'),
      resistance: resistance,
      burnDamagePerSecondScale: number(s, 'burnDamagePerSecondScale'),
      burnDurationSeconds: number(s, 'burnDurationSeconds'),
      hasDamageOverTime: s['hasDamageOverTime'] == true,
      damageScale: number(s, 'damageScale', 1),
      damageOverTimeDamageMultiplier: number(
        s,
        'damageOverTimeDamageMultiplier',
        1,
      ),
      damageOverTimeDurationMultiplier: number(
        s,
        'damageOverTimeDurationMultiplier',
        1,
      ),
      ignoresArmorReduction: s['ignoresArmorReduction'] == true,
      slowDuration: number(s, 'slowDuration'),
      slowMultiplier: number(s, 'slowMultiplier', 1),
      appliesFrostCrack: s['appliesFrostCrack'] == true,
    ),
  );
  return {
    'damage': hit.damage,
    'resistanceMultiplier': hit.resistanceMultiplier,
    'effects': effects
        .map(
          (effect) => switch (effect) {
            AttackBurnEffect() => {
              'type': 'burn',
              'damagePerSecond': effect.damagePerSecond,
              'duration': effect.duration,
              'damageMultiplier': effect.damageMultiplier,
              'ignoreArmorReduction': effect.ignoreArmorReduction,
            },
            AttackSlowEffect() => {
              'type': 'slow',
              'multiplier': effect.multiplier,
              'duration': effect.duration,
            },
            AttackElementalVulnerabilityEffect() => {
              'type': 'elementalVulnerability',
              'bonus': effect.bonus,
              'duration': effect.duration,
            },
          },
        )
        .toList(),
  };
}

/// Relative/absolute 1e-10 tolerance for numeric outputs only. Effect order,
/// booleans, field sets and counts remain exact, including branch boundaries.
void compareValues(Object? actual, Object? expected, String path) {
  if (actual is num && expected is num) {
    if (!actual.isFinite ||
        !expected.isFinite ||
        (actual - expected).abs() >
            1e-10 * (expected.abs() > 1 ? expected.abs() : 1)) {
      throw StateError('$path: $actual != $expected');
    }
  } else if (actual is Map && expected is Map) {
    if (actual.length != expected.length ||
        !actual.keys.every(expected.containsKey)) {
      throw StateError('$path: fields differ');
    }
    for (final key in expected.keys) {
      compareValues(actual[key], expected[key], '$path.$key');
    }
  } else if (actual is List && expected is List) {
    if (actual.length != expected.length) {
      throw StateError('$path: counts differ');
    }
    for (var i = 0; i < expected.length; i++) {
      compareValues(actual[i], expected[i], '$path[$i]');
    }
  } else if (actual != expected) {
    throw StateError('$path: $actual != $expected');
  }
}
