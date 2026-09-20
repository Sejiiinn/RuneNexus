import 'package:flame/components.dart';

import '../../domain/combat/attack_calculation.dart';

import '../../domain/map/grid_point.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../components/enemy_component.dart';
import '../components/turret_component.dart';

export '../../domain/combat/attack_calculation.dart' show ResolvedAttackDamage;

class CombatResolver {
  const CombatResolver({
    required this.chainJumpRange,
    this.chainIgnitionRange = 88,
    required this.burnDamagePerSecondScale,
    required this.burnDurationSeconds,
  });

  final double chainJumpRange;
  final double chainIgnitionRange;
  final double burnDamagePerSecondScale;
  final double burnDurationSeconds;

  ResolvedAttackDamage resolveAttackDamage({
    required TurretAttackSnapshot attack,
    required EnemyComponent enemy,
    required double baseDamage,
    double traitMultiplier = 1,
    Set<AttackTag> extraTags = const {},
  }) {
    return AttackCalculation.resolveDamage(
      resistance: _resistanceInput(attack, enemy, extraTags: extraTags),
      baseDamage: baseDamage,
      traitMultiplier: traitMultiplier,
    );
  }

  AttackResistanceInput _resistanceInput(
    TurretAttackSnapshot attack,
    EnemyComponent enemy, {
    Set<AttackTag> extraTags = const {},
  }) {
    final profile = enemy.definition.resistanceProfile;
    return AttackResistanceInput(
      family: switch (attack.definition.damageFamily) {
        DamageFamily.physical => AttackDamageFamily.physical,
        DamageFamily.elemental => AttackDamageFamily.elemental,
      },
      familyResistance: profile.familyResistance(
        attack.definition.damageFamily,
      ),
      tags: attack.definition.attackTags.map((tag) => tag.name),
      extraTags: extraTags.map((tag) => tag.name),
      tagResistances: profile.tagResistances.isEmpty
          ? const {}
          : {
              for (final tag in attack.definition.attackTags)
                tag.name: profile.tagResistance(tag),
              for (final tag in extraTags) tag.name: profile.tagResistance(tag),
            },
      enemyPhysicalReduction: enemy.physicalResistanceReduction,
      attackPhysicalReduction: attack.physicalResistanceReduction,
      enemyElementalReduction: enemy.elementalResistanceReduction,
    );
  }

  double damageMultiplier(
    TurretAttackSnapshot attack,
    EnemyComponent enemy, {
    Set<AttackTag> extraTags = const {},
  }) => AttackCalculation.damageMultiplier(
    _resistanceInput(attack, enemy, extraTags: extraTags),
  );

  void applyAttackStatuses({
    required TurretAttackSnapshot attack,
    required EnemyComponent enemy,
    double damageScale = 1,
    GridPoint? activeSourceTurretPoint,
  }) {
    if (!attack.hasDamageOverTime &&
        !(attack.slowDuration > 0 && attack.slowMultiplier < 1)) {
      return;
    }
    final effects = AttackCalculation.resolveStatuses(
      AttackStatusInput(
        damage: attack.damage,
        resistance: _resistanceInput(attack, enemy),
        burnDamagePerSecondScale: burnDamagePerSecondScale,
        burnDurationSeconds: burnDurationSeconds,
        hasDamageOverTime: attack.hasDamageOverTime,
        damageScale: damageScale,
        damageOverTimeDamageMultiplier: attack.damageOverTimeDamageMultiplier,
        damageOverTimeDurationMultiplier:
            attack.damageOverTimeDurationMultiplier,
        ignoresArmorReduction: attack.ignoresArmorReduction,
        slowDuration: attack.slowDuration,
        slowMultiplier: attack.slowMultiplier,
        appliesFrostCrack: attack.appliesFrostCrack,
      ),
    );
    for (final effect in effects) {
      switch (effect) {
        case AttackBurnEffect():
          enemy.applyBurn(
            damagePerSecond: effect.damagePerSecond,
            duration: effect.duration,
            damageMultiplier: effect.damageMultiplier,
            sourceTurretPoint: activeSourceTurretPoint,
            ignoreArmorReduction: effect.ignoreArmorReduction,
          );
        case AttackSlowEffect():
          enemy.applySlow(
            multiplier: effect.multiplier,
            duration: effect.duration,
          );
        case AttackElementalVulnerabilityEffect():
          enemy.applyElementalVulnerability(
            bonus: effect.bonus,
            duration: effect.duration,
          );
      }
    }
  }

  EnemyComponent? nextChainProjectileTarget({
    required Iterable<EnemyComponent> enemies,
    required Vector2 sourcePosition,
    required Set<EnemyComponent> excluded,
    required double boardDistanceScale,
  }) {
    final jumpRange = chainJumpRange * boardDistanceScale;
    final jumpRangeSquared = jumpRange * jumpRange;
    EnemyComponent? target;
    var nearestDistanceSquared = double.infinity;
    for (final enemy in enemies) {
      if (enemy.isDead || excluded.contains(enemy)) continue;
      final distanceSquared = enemy.position.distanceToSquared(sourcePosition);
      if (distanceSquared <= jumpRangeSquared &&
          distanceSquared < nearestDistanceSquared) {
        target = enemy;
        nearestDistanceSquared = distanceSquared;
      }
    }
    return target;
  }

  EnemyComponent? chainIgnitionTarget({
    required Iterable<EnemyComponent> enemies,
    required EnemyComponent source,
    required double boardDistanceScale,
  }) {
    final liveEnemies = enemies.toList();
    final jumpRange = chainIgnitionRange * boardDistanceScale;
    final jumpRangeSquared = jumpRange * jumpRange;
    EnemyComponent? target;
    var targetDistanceTravelled = -double.infinity;
    var targetDistanceSquared = double.infinity;
    for (final enemy in liveEnemies) {
      if (identical(enemy, source) || enemy.isDead) {
        continue;
      }
      final dx = enemy.position.x - source.position.x;
      final dy = enemy.position.y - source.position.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > jumpRangeSquared) {
        continue;
      }
      final isFurtherAhead = enemy.distanceTravelled > targetDistanceTravelled;
      final isTieButCloser =
          enemy.distanceTravelled == targetDistanceTravelled &&
          distanceSquared < targetDistanceSquared;
      if (isFurtherAhead || isTieButCloser) {
        target = enemy;
        targetDistanceTravelled = enemy.distanceTravelled;
        targetDistanceSquared = distanceSquared;
      }
    }
    return target;
  }
}
