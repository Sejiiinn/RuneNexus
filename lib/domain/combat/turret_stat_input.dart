import '../gem/gem_type.dart';
import 'attack_calculation.dart';
import '../turret/turret_type.dart';
import '../turret/turret_trait_type.dart';
import '../turret_module/turret_module_type.dart';

class TurretStatDefinition {
  TurretStatDefinition({
    required this.type,
    required this.damageFamily,
    required Set<String> attackTags,
    required this.damage,
    required this.range,
    required this.attackRate,
    required this.projectileSpeed,
    required this.projectileCount,
    required this.splashRadius,
    required this.centeredAreaAttack,
    required this.instantHit,
    required this.aimDuration,
    required this.criticalChance,
    required this.criticalDamageMultiplier,
    required this.slowMultiplier,
    required this.slowDuration,
  }) : attackTags = Set.unmodifiable(attackTags);
  final TurretType type;
  final AttackDamageFamily damageFamily;
  final Set<String> attackTags;
  final double damage;
  final double range;
  final double attackRate;
  final double projectileSpeed;
  final int projectileCount;
  final double splashRadius;
  final bool centeredAreaAttack;
  final bool instantHit;
  final double aimDuration;
  final double criticalChance;
  final double criticalDamageMultiplier;
  final double slowMultiplier;
  final double slowDuration;
  factory TurretStatDefinition.fromJson(Map<String, dynamic> json) =>
      TurretStatDefinition(
        type: TurretType.values.byName(json['type'] as String),
        damageFamily: AttackDamageFamily.values.byName(
          json['damageFamily'] as String,
        ),
        attackTags: (json['attackTags'] as List)
            .map((v) => v as String)
            .toSet(),
        damage: (json['damage'] as num).toDouble(),
        range: (json['range'] as num).toDouble(),
        attackRate: (json['attackRate'] as num).toDouble(),
        projectileSpeed: (json['projectileSpeed'] as num).toDouble(),
        projectileCount: (json['projectileCount'] as num).toInt(),
        splashRadius: (json['splashRadius'] as num).toDouble(),
        centeredAreaAttack: json['centeredAreaAttack'] as bool,
        instantHit: json['instantHit'] as bool,
        aimDuration: (json['aimDuration'] as num).toDouble(),
        criticalChance: (json['criticalChance'] as num).toDouble(),
        criticalDamageMultiplier: (json['criticalDamageMultiplier'] as num)
            .toDouble(),
        slowMultiplier: (json['slowMultiplier'] as num).toDouble(),
        slowDuration: (json['slowDuration'] as num).toDouble(),
      );
  Map<String, Object?> toJson() => {
    'type': type.name,
    'damageFamily': damageFamily.name,
    'attackTags': attackTags.toList(),
    'damage': damage,
    'range': range,
    'attackRate': attackRate,
    'projectileSpeed': projectileSpeed,
    'projectileCount': projectileCount,
    'splashRadius': splashRadius,
    'centeredAreaAttack': centeredAreaAttack,
    'instantHit': instantHit,
    'aimDuration': aimDuration,
    'criticalChance': criticalChance,
    'criticalDamageMultiplier': criticalDamageMultiplier,
    'slowMultiplier': slowMultiplier,
    'slowDuration': slowDuration,
  };
  bool get firesProjectile =>
      !instantHit && !centeredAreaAttack && type != TurretType.lightning;
}

/// Read-only inputs. Runtime adapters may read live state; capture before firing.
abstract interface class TurretStatSource {
  bool hasGem(GemType type);
  TurretStatDefinition get definition;
  TurretModuleEffect get moduleEffect;
  Set<GemType> get gems;
  TurretTraitType? get primaryTrait;
  TurretTraitType? get secondaryTrait;
  int get level;
  bool get chainCleanupActive;
  double get passiveNumericGemEffectMultiplier;
  double get towerDamageMultiplier;
  double get corePassiveTurretDamageMultiplier;
  double get corePassiveTurretAttackRateMultiplier;
  double get boardDistanceScale;
  double get lightningChainJumpRange;
  double get criticalChanceProgressionBonusRate;
  double get criticalDamageProgressionBonusRate;
  double get criticalChanceGemValue;
  double get aimSpeedGemValue;
  double get explosionGemValue;
}

class TurretStatInput implements TurretStatSource {
  @override
  bool hasGem(GemType type) => gems.contains(type);
  TurretStatInput({
    required this.definition,
    required this.moduleEffect,
    required Set<GemType> gems,
    required this.primaryTrait,
    required this.secondaryTrait,
    required this.level,
    required this.chainCleanupActive,
    required this.passiveNumericGemEffectMultiplier,
    required this.towerDamageMultiplier,
    required this.corePassiveTurretDamageMultiplier,
    required this.corePassiveTurretAttackRateMultiplier,
    required this.boardDistanceScale,
    required this.lightningChainJumpRange,
    required this.criticalChanceProgressionBonusRate,
    required this.criticalDamageProgressionBonusRate,
    required this.criticalChanceGemValue,
    required this.aimSpeedGemValue,
    required this.explosionGemValue,
  }) : gems = Set.unmodifiable(gems);
  @override
  final TurretStatDefinition definition;
  @override
  final TurretModuleEffect moduleEffect;
  @override
  final Set<GemType> gems;
  @override
  final TurretTraitType? primaryTrait;
  @override
  final TurretTraitType? secondaryTrait;
  @override
  final int level;
  @override
  final bool chainCleanupActive;
  @override
  final double passiveNumericGemEffectMultiplier;
  @override
  final double towerDamageMultiplier;
  @override
  final double corePassiveTurretDamageMultiplier;
  @override
  final double corePassiveTurretAttackRateMultiplier;
  @override
  final double boardDistanceScale;
  @override
  final double lightningChainJumpRange;
  @override
  final double criticalChanceProgressionBonusRate;
  @override
  final double criticalDamageProgressionBonusRate;
  @override
  final double criticalChanceGemValue;
  @override
  final double aimSpeedGemValue;
  @override
  final double explosionGemValue;
  factory TurretStatInput.fromJson(
    Map<String, dynamic> json,
  ) => TurretStatInput(
    definition: TurretStatDefinition.fromJson(
      json['definition'] as Map<String, dynamic>,
    ),
    moduleEffect: TurretModuleEffect(
      damageIncreaseRate:
          ((json['moduleEffect'] as Map)['damageIncreaseRate'] as num)
              .toDouble(),
      attackRateIncreaseRate:
          ((json['moduleEffect'] as Map)['attackRateIncreaseRate'] as num)
              .toDouble(),
      criticalChanceBonusRate:
          ((json['moduleEffect'] as Map)['criticalChanceBonusRate'] as num)
              .toDouble(),
      criticalDamageBonusRate:
          ((json['moduleEffect'] as Map)['criticalDamageBonusRate'] as num)
              .toDouble(),
      rangeIncreaseRate:
          ((json['moduleEffect'] as Map)['rangeIncreaseRate'] as num)
              .toDouble(),
      gemEffectIncreaseRate:
          ((json['moduleEffect'] as Map)['gemEffectIncreaseRate'] as num)
              .toDouble(),
      splashRadiusIncreaseRate:
          ((json['moduleEffect'] as Map)['splashRadiusIncreaseRate'] as num)
              .toDouble(),
      damageOverTimeIncreaseRate:
          ((json['moduleEffect'] as Map)['damageOverTimeIncreaseRate'] as num)
              .toDouble(),
      burnDurationIncreaseRate:
          ((json['moduleEffect'] as Map)['burnDurationIncreaseRate'] as num)
              .toDouble(),
      slowDurationIncreaseRate:
          ((json['moduleEffect'] as Map)['slowDurationIncreaseRate'] as num)
              .toDouble(),
      slowStrengthBonusRate:
          ((json['moduleEffect'] as Map)['slowStrengthBonusRate'] as num)
              .toDouble(),
      lightningChainDamageIncreaseRate:
          ((json['moduleEffect'] as Map)['lightningChainDamageIncreaseRate']
                  as num)
              .toDouble(),
      projectileSpeedIncreaseRate:
          ((json['moduleEffect'] as Map)['projectileSpeedIncreaseRate'] as num)
              .toDouble(),
      splashSecondaryDamageBonusRate:
          ((json['moduleEffect'] as Map)['splashSecondaryDamageBonusRate']
                  as num)
              .toDouble(),
      lightningChainRangeIncreaseRate:
          ((json['moduleEffect'] as Map)['lightningChainRangeIncreaseRate']
                  as num)
              .toDouble(),
      aimSpeedIncreaseRate:
          ((json['moduleEffect'] as Map)['aimSpeedIncreaseRate'] as num)
              .toDouble(),
    ),
    gems: (json['gems'] as List)
        .map((v) => GemType.values.byName(v as String))
        .toSet(),
    primaryTrait: json['primaryTrait'] == null
        ? null
        : TurretTraitType.values.byName(json['primaryTrait'] as String),
    secondaryTrait: json['secondaryTrait'] == null
        ? null
        : TurretTraitType.values.byName(json['secondaryTrait'] as String),
    level: (json['level'] as num).toInt(),
    chainCleanupActive: json['chainCleanupActive'] as bool,
    passiveNumericGemEffectMultiplier:
        (json['passiveNumericGemEffectMultiplier'] as num).toDouble(),
    towerDamageMultiplier: (json['towerDamageMultiplier'] as num).toDouble(),
    corePassiveTurretDamageMultiplier:
        (json['corePassiveTurretDamageMultiplier'] as num).toDouble(),
    corePassiveTurretAttackRateMultiplier:
        (json['corePassiveTurretAttackRateMultiplier'] as num).toDouble(),
    boardDistanceScale: (json['boardDistanceScale'] as num).toDouble(),
    lightningChainJumpRange: (json['lightningChainJumpRange'] as num)
        .toDouble(),
    criticalChanceProgressionBonusRate:
        (json['criticalChanceProgressionBonusRate'] as num).toDouble(),
    criticalDamageProgressionBonusRate:
        (json['criticalDamageProgressionBonusRate'] as num).toDouble(),
    criticalChanceGemValue: (json['criticalChanceGemValue'] as num).toDouble(),
    aimSpeedGemValue: (json['aimSpeedGemValue'] as num).toDouble(),
    explosionGemValue: (json['explosionGemValue'] as num).toDouble(),
  );
  Map<String, Object?> toJson() => {
    'definition': definition.toJson(),
    'moduleEffect': {
      'damageIncreaseRate': moduleEffect.damageIncreaseRate,
      'attackRateIncreaseRate': moduleEffect.attackRateIncreaseRate,
      'criticalChanceBonusRate': moduleEffect.criticalChanceBonusRate,
      'criticalDamageBonusRate': moduleEffect.criticalDamageBonusRate,
      'rangeIncreaseRate': moduleEffect.rangeIncreaseRate,
      'gemEffectIncreaseRate': moduleEffect.gemEffectIncreaseRate,
      'splashRadiusIncreaseRate': moduleEffect.splashRadiusIncreaseRate,
      'damageOverTimeIncreaseRate': moduleEffect.damageOverTimeIncreaseRate,
      'burnDurationIncreaseRate': moduleEffect.burnDurationIncreaseRate,
      'slowDurationIncreaseRate': moduleEffect.slowDurationIncreaseRate,
      'slowStrengthBonusRate': moduleEffect.slowStrengthBonusRate,
      'lightningChainDamageIncreaseRate':
          moduleEffect.lightningChainDamageIncreaseRate,
      'projectileSpeedIncreaseRate': moduleEffect.projectileSpeedIncreaseRate,
      'splashSecondaryDamageBonusRate':
          moduleEffect.splashSecondaryDamageBonusRate,
      'lightningChainRangeIncreaseRate':
          moduleEffect.lightningChainRangeIncreaseRate,
      'aimSpeedIncreaseRate': moduleEffect.aimSpeedIncreaseRate,
    },
    'gems': gems.map((v) => v.name).toList(),
    'primaryTrait': primaryTrait?.name,
    'secondaryTrait': secondaryTrait?.name,
    'level': level,
    'chainCleanupActive': chainCleanupActive,
    'passiveNumericGemEffectMultiplier': passiveNumericGemEffectMultiplier,
    'towerDamageMultiplier': towerDamageMultiplier,
    'corePassiveTurretDamageMultiplier': corePassiveTurretDamageMultiplier,
    'corePassiveTurretAttackRateMultiplier':
        corePassiveTurretAttackRateMultiplier,
    'boardDistanceScale': boardDistanceScale,
    'lightningChainJumpRange': lightningChainJumpRange,
    'criticalChanceProgressionBonusRate': criticalChanceProgressionBonusRate,
    'criticalDamageProgressionBonusRate': criticalDamageProgressionBonusRate,
    'criticalChanceGemValue': criticalChanceGemValue,
    'aimSpeedGemValue': aimSpeedGemValue,
    'explosionGemValue': explosionGemValue,
  };
  factory TurretStatInput.capture(TurretStatSource source) => TurretStatInput(
    definition: source.definition,
    moduleEffect: source.moduleEffect,
    gems: source.gems,
    primaryTrait: source.primaryTrait,
    secondaryTrait: source.secondaryTrait,
    level: source.level,
    chainCleanupActive: source.chainCleanupActive,
    passiveNumericGemEffectMultiplier: source.passiveNumericGemEffectMultiplier,
    towerDamageMultiplier: source.towerDamageMultiplier,
    corePassiveTurretDamageMultiplier: source.corePassiveTurretDamageMultiplier,
    corePassiveTurretAttackRateMultiplier:
        source.corePassiveTurretAttackRateMultiplier,
    boardDistanceScale: source.boardDistanceScale,
    lightningChainJumpRange: source.lightningChainJumpRange,
    criticalChanceProgressionBonusRate:
        source.criticalChanceProgressionBonusRate,
    criticalDamageProgressionBonusRate:
        source.criticalDamageProgressionBonusRate,
    criticalChanceGemValue: source.criticalChanceGemValue,
    aimSpeedGemValue: source.aimSpeedGemValue,
    explosionGemValue: source.explosionGemValue,
  );
}
