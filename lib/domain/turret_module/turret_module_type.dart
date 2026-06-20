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

enum TurretModuleGrade { normal, magic, rare }

extension TurretModuleGradeLabel on TurretModuleGrade {
  String get label {
    return switch (this) {
      TurretModuleGrade.normal => '일반',
      TurretModuleGrade.magic => '마법',
      TurretModuleGrade.rare => '희귀',
    };
  }

  int get order => TurretModuleGrade.values.indexOf(this);

  TurretModuleGrade? get nextGrade {
    final nextIndex = order + 1;
    if (nextIndex >= TurretModuleGrade.values.length) {
      return null;
    }
    return TurretModuleGrade.values[nextIndex];
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

class TurretModuleEffect {
  const TurretModuleEffect({
    this.damageIncreaseRate = 0,
    this.attackRateIncreaseRate = 0,
    this.levelUpCostDiscountRate = 0,
    this.splashRadiusIncreaseRate = 0,
    this.damageOverTimeIncreaseRate = 0,
    this.slowDurationIncreaseRate = 0,
    this.criticalDamageBonusRate = 0,
    this.lightningChainDamageIncreaseRate = 0,
  });

  static const zero = TurretModuleEffect();

  final double damageIncreaseRate;
  final double attackRateIncreaseRate;
  final double levelUpCostDiscountRate;
  final double splashRadiusIncreaseRate;
  final double damageOverTimeIncreaseRate;
  final double slowDurationIncreaseRate;
  final double criticalDamageBonusRate;
  final double lightningChainDamageIncreaseRate;

  TurretModuleEffect operator +(TurretModuleEffect other) {
    return TurretModuleEffect(
      damageIncreaseRate: damageIncreaseRate + other.damageIncreaseRate,
      attackRateIncreaseRate:
          attackRateIncreaseRate + other.attackRateIncreaseRate,
      levelUpCostDiscountRate:
          levelUpCostDiscountRate + other.levelUpCostDiscountRate,
      splashRadiusIncreaseRate:
          splashRadiusIncreaseRate + other.splashRadiusIncreaseRate,
      damageOverTimeIncreaseRate:
          damageOverTimeIncreaseRate + other.damageOverTimeIncreaseRate,
      slowDurationIncreaseRate:
          slowDurationIncreaseRate + other.slowDurationIncreaseRate,
      criticalDamageBonusRate:
          criticalDamageBonusRate + other.criticalDamageBonusRate,
      lightningChainDamageIncreaseRate:
          lightningChainDamageIncreaseRate +
          other.lightningChainDamageIncreaseRate,
    );
  }

  TurretModuleEffect scaledBy(double multiplier) {
    return TurretModuleEffect(
      damageIncreaseRate: damageIncreaseRate * multiplier,
      attackRateIncreaseRate: attackRateIncreaseRate * multiplier,
      levelUpCostDiscountRate: levelUpCostDiscountRate * multiplier,
      splashRadiusIncreaseRate: splashRadiusIncreaseRate * multiplier,
      damageOverTimeIncreaseRate: damageOverTimeIncreaseRate * multiplier,
      slowDurationIncreaseRate: slowDurationIncreaseRate * multiplier,
      criticalDamageBonusRate: criticalDamageBonusRate * multiplier,
      lightningChainDamageIncreaseRate:
          lightningChainDamageIncreaseRate * multiplier,
    );
  }
}

class TurretModuleInventoryItem {
  const TurretModuleInventoryItem({
    required this.key,
    required this.stars,
    required this.shards,
    required this.equipped,
  });

  final TurretModuleKey key;
  final int stars;
  final int shards;
  final bool equipped;

  TurretModuleInventoryItem copyWith({
    int? stars,
    int? shards,
    bool? equipped,
  }) {
    return TurretModuleInventoryItem(
      key: key,
      stars: stars ?? this.stars,
      shards: shards ?? this.shards,
      equipped: equipped ?? this.equipped,
    );
  }
}
