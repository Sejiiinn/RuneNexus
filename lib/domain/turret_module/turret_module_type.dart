import '../turret/turret_type.dart';

enum TurretModulePart { core, barrel, frame }

extension TurretModulePartLabel on TurretModulePart {
  String get label {
    return switch (this) {
      TurretModulePart.core => '코어',
      TurretModulePart.barrel => '포신',
      TurretModulePart.frame => '프레임',
    };
  }
}

enum TurretModuleGrade { normal, magic, rare, unique }

extension TurretModuleGradeLabel on TurretModuleGrade {
  String get label {
    return switch (this) {
      TurretModuleGrade.normal => '일반',
      TurretModuleGrade.magic => '마법',
      TurretModuleGrade.rare => '희귀',
      TurretModuleGrade.unique => '유니크',
    };
  }

  int get order => TurretModuleGrade.values.indexOf(this);

  int get disassembleDiamondValue {
    return switch (this) {
      TurretModuleGrade.normal => 2,
      TurretModuleGrade.magic => 5,
      TurretModuleGrade.rare => 20,
      TurretModuleGrade.unique => 50,
    };
  }
}

enum TurretModuleFamily {
  rapidCore,
  balancedBarrel,
  stableFrame,
  blastCore,
  heavyBarrel,
  reinforcedFrame,
  ignitionCore,
  emberBarrel,
  heatSinkFrame,
  frostCore,
  coldBarrel,
  coolingFrame,
  scopeCore,
  precisionBarrel,
  anchorFrame,
  currentCore,
  coilBarrel,
  insulatedFrame,
}

enum TurretModuleOptionType {
  damageIncrease,
  attackRateIncrease,
  criticalChanceBonus,
  criticalDamageBonus,
  rangeIncrease,
  levelUpCostDiscount,
  linkUpgradeCostDiscount,
  buildCostDiscount,
  highLevelUpgradeCostDiscount,
  gemEffectIncrease,
  splashRadiusIncrease,
  damageOverTimeIncrease,
  burnDurationIncrease,
  slowDurationIncrease,
  slowStrengthBonus,
  lightningChainDamageIncrease,
  projectileSpeedIncrease,
  splashSecondaryDamageBonus,
  lightningChainRangeIncrease,
  aimSpeedIncrease,
}

extension TurretModuleOptionTypeLabel on TurretModuleOptionType {
  String get label {
    return switch (this) {
      TurretModuleOptionType.damageIncrease => '피해',
      TurretModuleOptionType.attackRateIncrease => '공격속도',
      TurretModuleOptionType.criticalChanceBonus => '치명타 확률',
      TurretModuleOptionType.criticalDamageBonus => '치명타 피해',
      TurretModuleOptionType.rangeIncrease => '사거리',
      TurretModuleOptionType.levelUpCostDiscount => '레벨업 비용',
      TurretModuleOptionType.linkUpgradeCostDiscount => '링크 확장 비용',
      TurretModuleOptionType.buildCostDiscount => '설치 비용',
      TurretModuleOptionType.highLevelUpgradeCostDiscount => '고레벨 강화 비용',
      TurretModuleOptionType.gemEffectIncrease => '장착 젬 효과',
      TurretModuleOptionType.splashRadiusIncrease => '폭발 반경',
      TurretModuleOptionType.damageOverTimeIncrease => '지속피해',
      TurretModuleOptionType.burnDurationIncrease => '화상 지속시간',
      TurretModuleOptionType.slowDurationIncrease => '둔화 지속시간',
      TurretModuleOptionType.slowStrengthBonus => '둔화 강도',
      TurretModuleOptionType.lightningChainDamageIncrease => '연쇄 피해',
      TurretModuleOptionType.projectileSpeedIncrease => '투사체 속도',
      TurretModuleOptionType.splashSecondaryDamageBonus => '광역 보조 피해',
      TurretModuleOptionType.lightningChainRangeIncrease => '연쇄 거리',
      TurretModuleOptionType.aimSpeedIncrease => '조준속도',
    };
  }

  bool get isDiscount {
    return switch (this) {
      TurretModuleOptionType.levelUpCostDiscount ||
      TurretModuleOptionType.linkUpgradeCostDiscount ||
      TurretModuleOptionType.buildCostDiscount ||
      TurretModuleOptionType.highLevelUpgradeCostDiscount => true,
      _ => false,
    };
  }

  bool get usesPointSuffix {
    return switch (this) {
      TurretModuleOptionType.criticalChanceBonus ||
      TurretModuleOptionType.criticalDamageBonus ||
      TurretModuleOptionType.slowStrengthBonus ||
      TurretModuleOptionType.splashSecondaryDamageBonus => true,
      _ => false,
    };
  }
}

class TurretModuleKey {
  const TurretModuleKey({
    required this.turretType,
    required this.part,
    required this.family,
    required this.grade,
  });

  final TurretType turretType;
  final TurretModulePart part;
  final TurretModuleFamily family;
  final TurretModuleGrade grade;

  @override
  bool operator ==(Object other) {
    return other is TurretModuleKey &&
        other.turretType == turretType &&
        other.part == part &&
        other.family == family &&
        other.grade == grade;
  }

  @override
  int get hashCode => Object.hash(turretType, part, family, grade);
}

class TurretModuleOptionRoll {
  const TurretModuleOptionRoll({required this.type, required this.value});

  final TurretModuleOptionType type;
  final int value;

  double get rate => value / 100;
}

class TurretModuleEffect {
  const TurretModuleEffect({
    this.damageIncreaseRate = 0,
    this.attackRateIncreaseRate = 0,
    this.criticalChanceBonusRate = 0,
    this.criticalDamageBonusRate = 0,
    this.rangeIncreaseRate = 0,
    this.levelUpCostDiscountRate = 0,
    this.linkUpgradeCostDiscountRate = 0,
    this.buildCostDiscountRate = 0,
    this.highLevelUpgradeCostDiscountRate = 0,
    this.gemEffectIncreaseRate = 0,
    this.splashRadiusIncreaseRate = 0,
    this.damageOverTimeIncreaseRate = 0,
    this.burnDurationIncreaseRate = 0,
    this.slowDurationIncreaseRate = 0,
    this.slowStrengthBonusRate = 0,
    this.lightningChainDamageIncreaseRate = 0,
    this.projectileSpeedIncreaseRate = 0,
    this.splashSecondaryDamageBonusRate = 0,
    this.lightningChainRangeIncreaseRate = 0,
    this.aimSpeedIncreaseRate = 0,
  });

  static const zero = TurretModuleEffect();

  final double damageIncreaseRate;
  final double attackRateIncreaseRate;
  final double criticalChanceBonusRate;
  final double criticalDamageBonusRate;
  final double rangeIncreaseRate;
  final double levelUpCostDiscountRate;
  final double linkUpgradeCostDiscountRate;
  final double buildCostDiscountRate;
  final double highLevelUpgradeCostDiscountRate;
  final double gemEffectIncreaseRate;
  final double splashRadiusIncreaseRate;
  final double damageOverTimeIncreaseRate;
  final double burnDurationIncreaseRate;
  final double slowDurationIncreaseRate;
  final double slowStrengthBonusRate;
  final double lightningChainDamageIncreaseRate;
  final double projectileSpeedIncreaseRate;
  final double splashSecondaryDamageBonusRate;
  final double lightningChainRangeIncreaseRate;
  final double aimSpeedIncreaseRate;

  TurretModuleEffect operator +(TurretModuleEffect other) {
    return TurretModuleEffect(
      damageIncreaseRate: damageIncreaseRate + other.damageIncreaseRate,
      attackRateIncreaseRate:
          attackRateIncreaseRate + other.attackRateIncreaseRate,
      criticalChanceBonusRate:
          criticalChanceBonusRate + other.criticalChanceBonusRate,
      criticalDamageBonusRate:
          criticalDamageBonusRate + other.criticalDamageBonusRate,
      rangeIncreaseRate: rangeIncreaseRate + other.rangeIncreaseRate,
      levelUpCostDiscountRate:
          levelUpCostDiscountRate + other.levelUpCostDiscountRate,
      linkUpgradeCostDiscountRate:
          linkUpgradeCostDiscountRate + other.linkUpgradeCostDiscountRate,
      buildCostDiscountRate:
          buildCostDiscountRate + other.buildCostDiscountRate,
      highLevelUpgradeCostDiscountRate:
          highLevelUpgradeCostDiscountRate +
          other.highLevelUpgradeCostDiscountRate,
      gemEffectIncreaseRate:
          gemEffectIncreaseRate + other.gemEffectIncreaseRate,
      splashRadiusIncreaseRate:
          splashRadiusIncreaseRate + other.splashRadiusIncreaseRate,
      damageOverTimeIncreaseRate:
          damageOverTimeIncreaseRate + other.damageOverTimeIncreaseRate,
      burnDurationIncreaseRate:
          burnDurationIncreaseRate + other.burnDurationIncreaseRate,
      slowDurationIncreaseRate:
          slowDurationIncreaseRate + other.slowDurationIncreaseRate,
      slowStrengthBonusRate:
          slowStrengthBonusRate + other.slowStrengthBonusRate,
      lightningChainDamageIncreaseRate:
          lightningChainDamageIncreaseRate +
          other.lightningChainDamageIncreaseRate,
      projectileSpeedIncreaseRate:
          projectileSpeedIncreaseRate + other.projectileSpeedIncreaseRate,
      splashSecondaryDamageBonusRate:
          splashSecondaryDamageBonusRate + other.splashSecondaryDamageBonusRate,
      lightningChainRangeIncreaseRate:
          lightningChainRangeIncreaseRate +
          other.lightningChainRangeIncreaseRate,
      aimSpeedIncreaseRate: aimSpeedIncreaseRate + other.aimSpeedIncreaseRate,
    );
  }
}

class TurretModuleInventoryItem {
  const TurretModuleInventoryItem({
    required this.id,
    required this.key,
    required this.options,
    required this.acquiredOrder,
    required this.equipped,
  });

  final String id;
  final TurretModuleKey key;
  final List<TurretModuleOptionRoll> options;
  final int acquiredOrder;
  final bool equipped;

  TurretModuleInventoryItem copyWith({
    TurretModuleKey? key,
    List<TurretModuleOptionRoll>? options,
    int? acquiredOrder,
    bool? equipped,
  }) {
    return TurretModuleInventoryItem(
      id: id,
      key: key ?? this.key,
      options: options ?? this.options,
      acquiredOrder: acquiredOrder ?? this.acquiredOrder,
      equipped: equipped ?? this.equipped,
    );
  }
}
