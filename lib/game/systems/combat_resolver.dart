import 'package:flame/components.dart';

import '../../domain/enemy/enemy_resistance_profile.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../components/enemy_component.dart';
import '../components/turret_component.dart';

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
    final multiplier = damageMultiplier(attack, enemy, extraTags: extraTags);
    return ResolvedAttackDamage(
      damage: baseDamage * traitMultiplier * multiplier,
      resistanceMultiplier: multiplier,
    );
  }

  double damageMultiplier(
    TurretAttackSnapshot attack,
    EnemyComponent enemy, {
    Set<AttackTag> extraTags = const {},
  }) {
    final resistance = enemy.definition.resistanceProfile;
    final tags = extraTags.isEmpty
        ? attack.definition.attackTags
        : {...attack.definition.attackTags, ...extraTags};
    var familyResistance = resistance.familyResistance(
      attack.definition.damageFamily,
    );
    if (attack.definition.damageFamily == DamageFamily.physical) {
      familyResistance -=
          enemy.physicalResistanceReduction +
          attack.physicalResistanceReduction;
    }
    if (attack.definition.damageFamily == DamageFamily.elemental) {
      familyResistance -= enemy.elementalResistanceReduction;
    }

    var multiplier = EnemyResistanceProfile.multiplierForResistance(
      familyResistance,
    );
    for (final tag in tags) {
      multiplier *= EnemyResistanceProfile.multiplierForResistance(
        resistance.tagResistance(tag),
      );
    }
    return multiplier;
  }

  void applyAttackStatuses({
    required TurretAttackSnapshot attack,
    required EnemyComponent enemy,
    double damageScale = 1,
    GridPoint? activeSourceTurretPoint,
  }) {
    if (attack.hasDamageOverTime) {
      final burnMultiplier = damageMultiplier(attack, enemy);
      enemy.applyBurn(
        damagePerSecond:
            attack.damage *
            burnDamagePerSecondScale *
            damageScale *
            burnMultiplier *
            attack.damageOverTimeDamageMultiplier,
        duration: burnDurationSeconds * attack.damageOverTimeDurationMultiplier,
        damageMultiplier: burnMultiplier,
        sourceTurretPoint: activeSourceTurretPoint,
        ignoreArmorReduction: attack.ignoresArmorReduction,
      );
    }
    if (attack.slowDuration > 0 && attack.slowMultiplier < 1) {
      enemy.applySlow(
        multiplier: attack.slowMultiplier,
        duration: attack.slowDuration,
      );
      if (attack.appliesFrostCrack) {
        enemy.applyElementalVulnerability(
          bonus: 0.15,
          duration: attack.slowDuration,
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

class ResolvedAttackDamage {
  const ResolvedAttackDamage({
    required this.damage,
    required this.resistanceMultiplier,
  });

  final double damage;
  final double resistanceMultiplier;
}
