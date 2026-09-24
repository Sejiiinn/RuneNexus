/// Engine-independent inputs for the resolver's existing numeric rules.
/// Damage is already adjusted by the firing snapshot's upgrades/gems/research.
enum AttackDamageFamily { physical, elemental }

class AttackResistanceInput {
  const AttackResistanceInput({
    required this.family,
    this.familyResistance = 0,
    this.tags = const [],
    this.extraTags = const [],
    this.tagResistances = const {},
    this.enemyPhysicalReduction = 0,
    this.attackPhysicalReduction = 0,
    this.enemyElementalReduction = 0,
  });

  final AttackDamageFamily family;
  final double familyResistance;
  final Iterable<String> tags;
  final Iterable<String> extraTags;
  final Map<String, double> tagResistances;
  final double enemyPhysicalReduction;
  final double attackPhysicalReduction;
  final double enemyElementalReduction;
}

class ResolvedAttackDamage {
  const ResolvedAttackDamage({
    required this.damage,
    required this.resistanceMultiplier,
  });
  final double damage;
  final double resistanceMultiplier;
}

class AttackStatusInput {
  const AttackStatusInput({
    required this.damage,
    required this.resistance,
    required this.burnDamagePerSecondScale,
    required this.burnDurationSeconds,
    this.hasDamageOverTime = false,
    this.damageScale = 1,
    this.criticalMultiplier = 1,
    this.damageOverTimeDamageMultiplier = 1,
    this.damageOverTimeDurationMultiplier = 1,
    this.ignoresArmorReduction = false,
    this.slowDuration = 0,
    this.slowMultiplier = 1,
    this.appliesFrostCrack = false,
  });
  final double damage;
  final AttackResistanceInput resistance;
  final double burnDamagePerSecondScale;
  final double burnDurationSeconds;
  final bool hasDamageOverTime;
  final double damageScale;
  final double criticalMultiplier;
  final double damageOverTimeDamageMultiplier;
  final double damageOverTimeDurationMultiplier;
  final bool ignoresArmorReduction;
  final double slowDuration;
  final double slowMultiplier;
  final bool appliesFrostCrack;
}

/// Application requests in original order. Enemy state owns validation,
/// stacking, lifetime, source attribution and actual damage application.
sealed class AttackStatusEffect {
  const AttackStatusEffect();
}

class AttackBurnEffect extends AttackStatusEffect {
  const AttackBurnEffect({
    required this.damagePerSecond,
    required this.duration,
    required this.damageMultiplier,
    required this.ignoreArmorReduction,
  });
  final double damagePerSecond;
  final double duration;
  final double damageMultiplier;
  final bool ignoreArmorReduction;
}

class AttackSlowEffect extends AttackStatusEffect {
  const AttackSlowEffect({required this.multiplier, required this.duration});
  final double multiplier;
  final double duration;
}

class AttackElementalVulnerabilityEffect extends AttackStatusEffect {
  const AttackElementalVulnerabilityEffect({
    required this.bonus,
    required this.duration,
  });
  final double bonus;
  final double duration;
}

abstract final class AttackCalculation {
  static double _resistanceMultiplier(double resistance) =>
      1 - (resistance > 0.9 ? 0.9 : resistance);

  static double damageMultiplier(
    AttackResistanceInput input, {
    bool includeExtraTags = true,
  }) {
    var familyResistance = input.familyResistance;
    switch (input.family) {
      case AttackDamageFamily.physical:
        familyResistance -=
            input.enemyPhysicalReduction + input.attackPhysicalReduction;
      case AttackDamageFamily.elemental:
        familyResistance -= input.enemyElementalReduction;
    }
    var multiplier = _resistanceMultiplier(familyResistance);
    final tags = <String>{
      ...input.tags,
      if (includeExtraTags) ...input.extraTags,
    };
    for (final tag in tags) {
      multiplier *= _resistanceMultiplier(input.tagResistances[tag] ?? 0);
    }
    return multiplier;
  }

  static ResolvedAttackDamage resolveDamage({
    required AttackResistanceInput resistance,
    required double baseDamage,
    double traitMultiplier = 1,
  }) {
    final multiplier = damageMultiplier(resistance);
    return ResolvedAttackDamage(
      damage: baseDamage * traitMultiplier * multiplier,
      resistanceMultiplier: multiplier,
    );
  }

  static List<AttackStatusEffect> resolveStatuses(AttackStatusInput input) {
    final effects = <AttackStatusEffect>[];
    if (input.hasDamageOverTime) {
      // Burn snapshots resistance before this attack applies frost crack, and
      // uses only base tags (never the direct hit's extra tags/trait).
      // Half of the firing critical bonus also applies to burn damage.
      final multiplier = damageMultiplier(
        input.resistance,
        includeExtraTags: false,
      );
      final burnCriticalMultiplier = 1 + (input.criticalMultiplier - 1) * 0.5;
      effects.add(
        AttackBurnEffect(
          damagePerSecond:
              input.damage *
              input.burnDamagePerSecondScale *
              input.damageScale *
              multiplier *
              input.damageOverTimeDamageMultiplier *
              burnCriticalMultiplier,
          duration:
              input.burnDurationSeconds *
              input.damageOverTimeDurationMultiplier,
          damageMultiplier: multiplier,
          ignoreArmorReduction: input.ignoresArmorReduction,
        ),
      );
    }
    if (input.slowDuration > 0 && input.slowMultiplier < 1) {
      effects.add(
        AttackSlowEffect(
          multiplier: input.slowMultiplier,
          duration: input.slowDuration,
        ),
      );
      if (input.appliesFrostCrack) {
        effects.add(
          AttackElementalVulnerabilityEffect(
            bonus: 0.15,
            duration: input.slowDuration,
          ),
        );
      }
    }
    return effects;
  }
}
