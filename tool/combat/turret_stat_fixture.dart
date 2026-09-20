import 'package:rune_nexus/domain/combat/turret_stat_input.dart';
import 'package:rune_nexus/domain/combat/turret_stat_calculation.dart';
import 'calculation_fixture.dart' show compareValues;
export 'calculation_fixture.dart' show compareValues;

Map<String, Object?> evaluateTurretFixture(Map<String, dynamic> input) {
  final c = TurretStatCalculation(TurretStatInput.fromJson(input));
  final a = c.createFiringStats(criticalMultiplier: 1.65);
  return {
    'damage': c.damage,
    'range': c.range,
    'attackRate': c.attackRate,
    'projectileSpeed': c.projectileSpeed,
    'projectileCount': c.projectileCount,
    'damageOverTimeDamageMultiplier': c.damageOverTimeDamageMultiplier,
    'damageOverTimeDurationMultiplier': c.damageOverTimeDurationMultiplier,
    'slowMultiplier': c.slowMultiplier,
    'slowDuration': c.slowDuration,
    'appliesFrostCrack': c.appliesFrostCrack,
    'appliesIgnitionBurst': c.appliesIgnitionBurst,
    'spreadsChainIgnition': c.spreadsChainIgnition,
    'physicalResistanceReduction': c.physicalResistanceReduction,
    'effectAreaMultiplier': c.effectAreaMultiplier,
    'centeredAreaRadius': c.centeredAreaRadius,
    'splashSecondaryDamageMultiplier': c.splashSecondaryDamageMultiplier,
    'splashRadius': c.splashRadius,
    'chainCount': c.chainCount,
    'ignoresArmorReduction': c.ignoresArmorReduction,
    'lightningChainMaxJumps': c.lightningChainMaxJumps,
    'lightningChainDamageMultiplier': c.lightningChainDamageMultiplier,
    'appliesLightningRecovery': c.appliesLightningRecovery,
    'criticalChance': c.criticalChance,
    'criticalDamageMultiplier': c.criticalDamageMultiplier,
    'aimDuration': c.aimDuration,
    'levels': {
      for (final level in [-4, 1, 3, 7, 10, 99])
        '$level': {
          'damage': c.damageAtLevel(level),
          'range': c.rangeAtLevel(level),
          'attackRate': c.attackRateAtLevel(level),
          'slowMultiplier': c.slowMultiplierAtLevel(level),
          'aimDuration': c.aimDurationAtLevel(level),
        },
    },
    'snapshot': {
      'damage': a.damage,
      'range': a.range,
      'effectAreaMultiplier': a.effectAreaMultiplier,
      'centeredAreaRadius': a.centeredAreaRadius,
      'chainCount': a.chainCount,
      'splashRadius': a.splashRadius,
      'splashSecondaryDamageMultiplier': a.splashSecondaryDamageMultiplier,
      'projectileSpeed': a.projectileSpeed,
      'criticalMultiplier': a.criticalMultiplier,
      'physicalResistanceReduction': a.physicalResistanceReduction,
      'ignoresArmorReduction': a.ignoresArmorReduction,
      'damageOverTimeDamageMultiplier': a.damageOverTimeDamageMultiplier,
      'damageOverTimeDurationMultiplier': a.damageOverTimeDurationMultiplier,
      'slowDuration': a.slowDuration,
      'slowMultiplier': a.slowMultiplier,
      'hasChain': a.hasChain,
      'appliesFrostCrack': a.appliesFrostCrack,
      'appliesIgnitionBurst': a.appliesIgnitionBurst,
      'spreadsChainIgnition': a.spreadsChainIgnition,
      'appliesChainCleanup': a.appliesChainCleanup,
      'appliesSuppressiveFire': a.appliesSuppressiveFire,
      'appliesExposedMark': a.appliesExposedMark,
      'appliesOverheatMagazine': a.appliesOverheatMagazine,
      'appliesCompressedCharge': a.appliesCompressedCharge,
      'appliesFinishingShot': a.appliesFinishingShot,
      'appliesFocusedLightning': a.appliesFocusedLightning,
      'lightningChainMaxJumps': a.lightningChainMaxJumps,
      'lightningChainDamageMultiplier': a.lightningChainDamageMultiplier,
      'lightningChainJumpRange': a.lightningChainJumpRange,
      'hasDamageOverTime': a.hasDamageOverTime,
    },
  };
}

/// Numeric tolerance must not hide a wrong clamp branch at 0 or 1.
void compareCriticalChanceRegion(
  Object? actual,
  Object? expected,
  String path,
) {
  String region(Object? value) {
    final chance = value as num;
    if (chance == 0) return 'zero';
    if (chance == 1) return 'one';
    if (chance > 0 && chance < 1) return 'interior';
    return 'outside';
  }

  compareValues(region(actual), region(expected), path);
}
