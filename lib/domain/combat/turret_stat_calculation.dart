import 'dart:math' as math;
import 'attack_rules.dart';
import 'turret_stat_input.dart';
import '../gem/gem_type.dart';
import 'attack_calculation.dart';
import '../turret/turret_type.dart';
import '../turret/turret_trait_type.dart';
import '../turret_module/turret_module_type.dart';

/// Pure arithmetic over read-only inputs. Individual getters calculate only
/// their requested stat; firing captures an immutable input once.
class TurretStatCalculation {
  final TurretStatSource source;
  TurretStatCalculation(this.source);
  TurretStatDefinition get definition => source.definition;
  TurretModuleEffect get _moduleEffect => source.moduleEffect;
  TurretTraitType? get _primaryTrait => source.primaryTrait;
  TurretTraitType? get _secondaryTrait => source.secondaryTrait;
  int get _level => source.level;
  static const int maxLevel = 10;
  static const double _damageGrowthPerLevel = 0.2;
  static const double _rangeGrowthPerLevel = 0.033;
  static const double _attackRateGrowthPerLevel = 0.05;
  static const double _aimSpeedGrowthPerLevel = 0.08;
  static const double _slowStrengthGrowthPerLevel = 0.02;
  double get _numericGemEffectMultiplier =>
      (1 + _moduleEffect.gemEffectIncreaseRate) *
      source.passiveNumericGemEffectMultiplier;

  double get damage => damageAtLevel(_level);

  int get projectileCount =>
      definition.projectileCount +
      (hasGem(GemType.multipleProjectiles) ? 2 : 0);

  double damageAtLevel(int level) {
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final moduleEffect = _moduleEffect;
    final gemEffectMultiplier = _numericGemEffectMultiplier;
    var levelDamage =
        definition.damage *
        math.pow(1 + _damageGrowthPerLevel, targetLevel - 1).toDouble();
    if (definition.damageFamily == AttackDamageFamily.physical &&
        hasGem(GemType.physicalDamage)) {
      levelDamage *= 1 + 0.4 * gemEffectMultiplier;
    }
    if (definition.damageFamily == AttackDamageFamily.elemental &&
        hasGem(GemType.elementalDamage)) {
      levelDamage *= 1 + 0.4 * gemEffectMultiplier;
    }
    if (definition.attackTags.contains('light') &&
        hasGem(GemType.lightWeapon)) {
      levelDamage *= 1 + 0.2 * gemEffectMultiplier;
    }
    if (definition.attackTags.contains('heavy') &&
        hasGem(GemType.heavyWeapon)) {
      levelDamage *= 1 + 0.3 * gemEffectMultiplier;
    }
    if (_primaryTrait == TurretTraitType.spreadingChill) {
      levelDamage *= 0.9;
    }
    if (hasGem(GemType.damageAmplifier)) {
      levelDamage *= 1 + 0.25 * gemEffectMultiplier;
    }

    return levelDamage *
        (1 + moduleEffect.damageIncreaseRate) *
        source.towerDamageMultiplier *
        source.corePassiveTurretDamageMultiplier *
        (hasGem(GemType.multipleProjectiles) ? 0.5 : 1);
  }

  double get range => rangeAtLevel(_level);

  double rangeAtLevel(int level) {
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final levelMultiplier = 1 + (targetLevel - 1) * _rangeGrowthPerLevel;
    final moduleEffect = _moduleEffect;
    return definition.range *
        levelMultiplier *
        (hasGem(GemType.range) ? 1 + 0.2 * _numericGemEffectMultiplier : 1) *
        (_primaryTrait == TurretTraitType.spreadingChill ? 1.15 : 1) *
        (1 + moduleEffect.rangeIncreaseRate) *
        source.boardDistanceScale;
  }

  double get attackRate => attackRateAtLevel(_level);

  double attackRateAtLevel(int level) {
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final levelMultiplier = math
        .pow(1 + _attackRateGrowthPerLevel, targetLevel - 1)
        .toDouble();
    final moduleEffect = _moduleEffect;
    final gemEffectMultiplier = _numericGemEffectMultiplier;
    var rate =
        definition.attackRate *
        levelMultiplier *
        (hasGem(GemType.attackSpeed) ? 1 + 0.4 * gemEffectMultiplier : 1) *
        (definition.attackTags.contains('light') && hasGem(GemType.lightWeapon)
            ? 1 + 0.2 * gemEffectMultiplier
            : 1) *
        (_primaryTrait == TurretTraitType.lightweightBarrel ? 1.1 : 1) *
        (_primaryTrait == TurretTraitType.compressedCharge ? 0.9 : 1) *
        (_primaryTrait == TurretTraitType.coolingCycle ? 1.2 : 1) *
        (1 + moduleEffect.attackRateIncreaseRate);
    if (source.chainCleanupActive) {
      rate *= 1.4;
    }
    return rate * source.corePassiveTurretAttackRateMultiplier;
  }

  double get projectileSpeed =>
      definition.projectileSpeed *
      (_primaryTrait == TurretTraitType.lightweightBarrel ? 1.3 : 1) *
      (1 + _moduleEffect.projectileSpeedIncreaseRate) *
      source.boardDistanceScale;

  double get damageOverTimeDamageMultiplier {
    if (!definition.attackTags.contains('damageOverTime')) {
      return 1;
    }
    var bonus = 0.0;
    if (hasGem(GemType.damageOverTime)) {
      bonus += 0.3 * _numericGemEffectMultiplier;
    }
    if (_primaryTrait == TurretTraitType.highHeatBurn) {
      bonus += 0.25;
    }
    bonus += _moduleEffect.damageOverTimeIncreaseRate;
    return 1 + bonus;
  }

  double get damageOverTimeDurationMultiplier {
    if (!definition.attackTags.contains('damageOverTime')) {
      return 1;
    }
    var bonus = 0.0;
    if (hasGem(GemType.damageOverTime)) {
      bonus += 0.3 * _numericGemEffectMultiplier;
    }
    if (_primaryTrait == TurretTraitType.lingeringEmbers) {
      bonus += 0.4;
    }
    bonus += _moduleEffect.burnDurationIncreaseRate;
    return 1 + bonus;
  }

  double get slowMultiplier => slowMultiplierAtLevel(_level);

  double slowMultiplierAtLevel(int level) {
    final strengthBonus = _moduleEffect.slowStrengthBonusRate;
    final base = definition.slowMultiplier;
    if (base <= 0) {
      return base;
    }
    final levelBonus = definition.type == TurretType.frost
        ? (level.clamp(1, maxLevel) - 1) * _slowStrengthGrowthPerLevel
        : 0.0;
    // 둔화 강도 변화량은 레벨·특성·모듈끼리 %p 합산
    final traitBonus = _secondaryTrait == TurretTraitType.rapidCooling
        ? 0.08
        : 0.0;
    return (base - levelBonus - traitBonus - strengthBonus)
        .clamp(0.1, 1.0)
        .toDouble();
  }

  double get slowDuration =>
      definition.slowDuration *
      (_primaryTrait == TurretTraitType.coolingCycle ? 0.85 : 1) *
      (1 + _moduleEffect.slowDurationIncreaseRate);

  bool get appliesFrostCrack => _secondaryTrait == TurretTraitType.frostCrack;
  bool get appliesIgnitionBurst =>
      _secondaryTrait == TurretTraitType.ignitionBurst;
  bool get spreadsChainIgnition =>
      _secondaryTrait == TurretTraitType.chainIgnition;
  double get physicalResistanceReduction =>
      _secondaryTrait == TurretTraitType.fractureImpact ? 0.2 : 0;

  double get effectAreaMultiplier =>
      1 +
      (hasGem(GemType.explosion) ? 0.25 * _numericGemEffectMultiplier : 0) +
      (definition.attackTags.contains('heavy') && hasGem(GemType.heavyWeapon)
          ? 0.2 * _numericGemEffectMultiplier
          : 0);

  double get centeredAreaRadius => range * effectAreaMultiplier;

  double get splashSecondaryDamageMultiplier =>
      AttackRules.splashDamageMultiplier +
      (_secondaryTrait == TurretTraitType.expandedBlastCore ? 0.1 : 0) +
      _moduleEffect.splashSecondaryDamageBonusRate;

  double get splashRadius {
    // 이미 광역인 냉기 공격에는 별도 폭발을 부여하지 않음.
    if (definition.centeredAreaAttack) {
      return 0;
    }
    final nativeRadius = definition.splashRadius;
    final baseRadius = nativeRadius > 0
        ? nativeRadius
        : (hasGem(GemType.explosion) ? source.explosionGemValue : 0.0);
    final nativeIncrease =
        (_primaryTrait == TurretTraitType.shrapnelShell ? 0.3 : 0.0) +
        (_secondaryTrait == TurretTraitType.expandedBlastCore ? 0.4 : 0.0) +
        _moduleEffect.splashRadiusIncreaseRate;
    // 기존 폭발 전용 보정의 대상은 유지하고 같은 증가 계층에서 합산.
    return (baseRadius * effectAreaMultiplier + nativeRadius * nativeIncrease) *
        source.boardDistanceScale;
  }

  int get chainCount => definition.type == TurretType.lightning
      ? lightningChainMaxJumps
      : (hasGem(GemType.chain) && definition.firesProjectile ? 2 : 0);

  bool hasGem(GemType type) => source.hasGem(type);
  bool get ignoresArmorReduction => hasGem(GemType.armorPiercing);
  int get lightningChainMaxTargets => lightningChainMaxJumps + 1;
  int get lightningChainMaxJumps {
    if (definition.type != TurretType.lightning) {
      return 0;
    }
    var jumps = 2;
    if (hasGem(GemType.chain)) {
      jumps += 2;
    }
    if (_primaryTrait == TurretTraitType.branchCurrent) {
      jumps += 1;
    }
    if (_primaryTrait == TurretTraitType.focusedLightning) {
      jumps -= 1;
    }
    return math.max(0, jumps);
  }

  double get lightningChainDamageMultiplier {
    final base = _secondaryTrait == TurretTraitType.currentAmplification
        ? 0.7
        : AttackRules.chainDamageMultiplier;
    return base * (1 + _moduleEffect.lightningChainDamageIncreaseRate);
  }

  bool get appliesLightningRecovery =>
      _secondaryTrait == TurretTraitType.lightningRecovery;

  double get criticalChance {
    final bonus =
        (hasGem(GemType.criticalChance)
            ? source.criticalChanceGemValue * _numericGemEffectMultiplier
            : 0.0) +
        source.criticalChanceProgressionBonusRate +
        _moduleEffect.criticalChanceBonusRate +
        (_primaryTrait == TurretTraitType.deadeyeFocus ? 0.2 : 0.0) -
        (_primaryTrait == TurretTraitType.quickScope ? 0.05 : 0.0);
    return (definition.criticalChance + bonus).clamp(0.0, 1.0).toDouble();
  }

  double get criticalDamageMultiplier =>
      definition.criticalDamageMultiplier +
      source.criticalDamageProgressionBonusRate +
      _moduleEffect.criticalDamageBonusRate;

  double get aimDuration {
    return aimDurationAtLevel(_level);
  }

  double aimDurationAtLevel(int level) {
    if (!definition.instantHit || definition.aimDuration <= 0) {
      return definition.aimDuration;
    }
    final targetLevel = level.clamp(1, maxLevel).toInt();
    final gemAimSpeedMultiplier = hasGem(GemType.aimSpeed)
        ? 1 + source.aimSpeedGemValue * _numericGemEffectMultiplier
        : 1.0;
    final traitAimSpeedBonus = switch (_primaryTrait) {
      TurretTraitType.deadeyeFocus => -0.2,
      TurretTraitType.quickScope => 0.4,
      _ => 0.0,
    };
    final aimSpeedMultiplier =
        1 +
        (targetLevel - 1) * _aimSpeedGrowthPerLevel +
        _moduleEffect.aimSpeedIncreaseRate +
        traitAimSpeedBonus;
    // 레벨·특성·모듈 증가 합산 후 젬의 별도 증폭 적용.
    return definition.aimDuration /
        (math.max(0.1, aimSpeedMultiplier) * gemAimSpeedMultiplier);
  }

  TurretFiringStats createFiringStats({double criticalMultiplier = 1}) =>
      TurretStatCalculation(
        TurretStatInput.capture(source),
      )._firingStats(criticalMultiplier: criticalMultiplier);
  TurretFiringStats _firingStats({double criticalMultiplier = 1}) {
    return TurretFiringStats(
      hasDamageOverTime: definition.attackTags.contains('damageOverTime'),
      damage: damage,
      range: range,
      effectAreaMultiplier: effectAreaMultiplier,
      centeredAreaRadius: centeredAreaRadius,
      chainCount: chainCount,
      splashRadius: splashRadius,
      splashSecondaryDamageMultiplier: splashSecondaryDamageMultiplier,
      projectileSpeed: projectileSpeed,
      criticalMultiplier: criticalMultiplier,
      physicalResistanceReduction: physicalResistanceReduction,
      ignoresArmorReduction: ignoresArmorReduction,
      damageOverTimeDamageMultiplier: damageOverTimeDamageMultiplier,
      damageOverTimeDurationMultiplier: damageOverTimeDurationMultiplier,
      slowDuration: slowDuration,
      slowMultiplier: slowMultiplier,
      hasChain: hasGem(GemType.chain),
      appliesFrostCrack: appliesFrostCrack,
      appliesIgnitionBurst: appliesIgnitionBurst,
      spreadsChainIgnition: spreadsChainIgnition,
      appliesChainCleanup: _secondaryTrait == TurretTraitType.chainCleanup,
      appliesSuppressiveFire:
          _secondaryTrait == TurretTraitType.suppressiveFire,
      appliesExposedMark: _secondaryTrait == TurretTraitType.exposedMark,
      appliesOverheatMagazine:
          _primaryTrait == TurretTraitType.overheatMagazine,
      appliesCompressedCharge:
          _primaryTrait == TurretTraitType.compressedCharge,
      appliesFinishingShot: _secondaryTrait == TurretTraitType.finishingShot,
      appliesFocusedLightning:
          _primaryTrait == TurretTraitType.focusedLightning,
      lightningChainMaxJumps: lightningChainMaxJumps,
      lightningChainDamageMultiplier: lightningChainDamageMultiplier,
      lightningChainJumpRange:
          source.lightningChainJumpRange *
          (1 + _moduleEffect.lightningChainRangeIncreaseRate),
    );
  }
}

class TurretFiringStats {
  const TurretFiringStats({
    required this.damage,
    required this.range,
    required this.effectAreaMultiplier,
    required this.centeredAreaRadius,
    required this.chainCount,
    required this.splashRadius,
    required this.splashSecondaryDamageMultiplier,
    required this.projectileSpeed,
    required this.criticalMultiplier,
    required this.physicalResistanceReduction,
    required this.ignoresArmorReduction,
    required this.damageOverTimeDamageMultiplier,
    required this.damageOverTimeDurationMultiplier,
    required this.slowDuration,
    required this.slowMultiplier,
    required this.hasChain,
    required this.appliesFrostCrack,
    required this.appliesIgnitionBurst,
    required this.spreadsChainIgnition,
    required this.appliesChainCleanup,
    required this.appliesSuppressiveFire,
    required this.appliesExposedMark,
    required this.appliesOverheatMagazine,
    required this.appliesCompressedCharge,
    required this.appliesFinishingShot,
    required this.appliesFocusedLightning,
    required this.lightningChainMaxJumps,
    required this.lightningChainDamageMultiplier,
    required this.lightningChainJumpRange,
    required this.hasDamageOverTime,
  });
  final double damage;
  final double range;
  final double effectAreaMultiplier;
  final double centeredAreaRadius;
  final int chainCount;
  final double splashRadius;
  final double splashSecondaryDamageMultiplier;
  final double projectileSpeed;
  final double criticalMultiplier;
  final double physicalResistanceReduction;
  final bool ignoresArmorReduction;
  final double damageOverTimeDamageMultiplier;
  final double damageOverTimeDurationMultiplier;
  final double slowDuration;
  final double slowMultiplier;
  final bool hasChain;
  final bool appliesFrostCrack;
  final bool appliesIgnitionBurst;
  final bool spreadsChainIgnition;
  final bool appliesChainCleanup;
  final bool appliesSuppressiveFire;
  final bool appliesExposedMark;
  final bool appliesOverheatMagazine;
  final bool appliesCompressedCharge;
  final bool appliesFinishingShot;
  final bool appliesFocusedLightning;
  final int lightningChainMaxJumps;
  final double lightningChainDamageMultiplier;
  final double lightningChainJumpRange;
  final bool hasDamageOverTime;
}
