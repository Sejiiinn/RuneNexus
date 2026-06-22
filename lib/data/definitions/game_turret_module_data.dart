import 'dart:math' as math;

import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';

final gameTurretModuleDefinitions = <TurretModuleKey, TurretModuleDefinition>{
  for (final turretType in TurretType.values)
    for (final part in TurretModulePart.values)
      for (final grade in TurretModuleGrade.values)
        TurretModuleKey(
          turretType: turretType,
          part: part,
          family: turretModuleFamilyFor(turretType, part),
          grade: grade,
        ): TurretModuleDefinition(
          name: turretModuleBaseNameFor(turretType, part),
        ),
};

class TurretModuleDefinition {
  const TurretModuleDefinition({required this.name});

  final String name;
}

class TurretModuleOptionRange {
  const TurretModuleOptionRange(this.min, this.max);

  final int min;
  final int max;

  int roll(math.Random random) {
    if (max <= min) {
      return min;
    }
    return min + random.nextInt(max - min + 1);
  }
}

const Map<TurretModuleGrade, int> turretModuleDisassembleDiamonds = {
  TurretModuleGrade.normal: 2,
  TurretModuleGrade.magic: 5,
  TurretModuleGrade.rare: 20,
  TurretModuleGrade.unique: 50,
};

const Map<TurretModuleGrade, List<int>> turretModuleOptionCountWeights = {
  TurretModuleGrade.normal: [85, 15, 0],
  TurretModuleGrade.magic: [40, 60, 0],
  TurretModuleGrade.rare: [10, 55, 35],
  TurretModuleGrade.unique: [0, 40, 60],
};

const Map<
  TurretModuleOptionType,
  Map<TurretModuleGrade, TurretModuleOptionRange>
>
turretModuleOptionRollRanges = {
  TurretModuleOptionType.damageIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(4, 7),
    TurretModuleGrade.magic: TurretModuleOptionRange(8, 13),
    TurretModuleGrade.rare: TurretModuleOptionRange(14, 21),
    TurretModuleGrade.unique: TurretModuleOptionRange(22, 30),
  },
  TurretModuleOptionType.attackRateIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(1, 3),
    TurretModuleGrade.magic: TurretModuleOptionRange(4, 6),
    TurretModuleGrade.rare: TurretModuleOptionRange(7, 10),
    TurretModuleGrade.unique: TurretModuleOptionRange(11, 14),
  },
  TurretModuleOptionType.criticalChanceBonus: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 4),
    TurretModuleGrade.magic: TurretModuleOptionRange(5, 7),
    TurretModuleGrade.rare: TurretModuleOptionRange(8, 11),
    TurretModuleGrade.unique: TurretModuleOptionRange(12, 16),
  },
  TurretModuleOptionType.criticalDamageBonus: {
    TurretModuleGrade.normal: TurretModuleOptionRange(8, 14),
    TurretModuleGrade.magic: TurretModuleOptionRange(15, 24),
    TurretModuleGrade.rare: TurretModuleOptionRange(25, 38),
    TurretModuleGrade.unique: TurretModuleOptionRange(39, 55),
  },
  TurretModuleOptionType.rangeIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 4),
    TurretModuleGrade.magic: TurretModuleOptionRange(5, 7),
    TurretModuleGrade.rare: TurretModuleOptionRange(8, 11),
    TurretModuleGrade.unique: TurretModuleOptionRange(12, 15),
  },
  TurretModuleOptionType.levelUpCostDiscount: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 4),
    TurretModuleGrade.magic: TurretModuleOptionRange(5, 7),
    TurretModuleGrade.rare: TurretModuleOptionRange(8, 11),
    TurretModuleGrade.unique: TurretModuleOptionRange(12, 16),
  },
  TurretModuleOptionType.linkUpgradeCostDiscount: {
    TurretModuleGrade.normal: TurretModuleOptionRange(3, 6),
    TurretModuleGrade.magic: TurretModuleOptionRange(7, 10),
    TurretModuleGrade.rare: TurretModuleOptionRange(11, 16),
    TurretModuleGrade.unique: TurretModuleOptionRange(17, 24),
  },
  TurretModuleOptionType.buildCostDiscount: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 4),
    TurretModuleGrade.magic: TurretModuleOptionRange(6, 8),
    TurretModuleGrade.rare: TurretModuleOptionRange(10, 12),
    TurretModuleGrade.unique: TurretModuleOptionRange(14, 16),
  },
  TurretModuleOptionType.highLevelUpgradeCostDiscount: {
    TurretModuleGrade.normal: TurretModuleOptionRange(3, 5),
    TurretModuleGrade.magic: TurretModuleOptionRange(6, 9),
    TurretModuleGrade.rare: TurretModuleOptionRange(10, 15),
    TurretModuleGrade.unique: TurretModuleOptionRange(16, 22),
  },
  TurretModuleOptionType.gemEffectIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 3),
    TurretModuleGrade.magic: TurretModuleOptionRange(4, 5),
    TurretModuleGrade.rare: TurretModuleOptionRange(6, 8),
    TurretModuleGrade.unique: TurretModuleOptionRange(9, 12),
  },
  TurretModuleOptionType.splashRadiusIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(3, 5),
    TurretModuleGrade.magic: TurretModuleOptionRange(6, 9),
    TurretModuleGrade.rare: TurretModuleOptionRange(10, 14),
    TurretModuleGrade.unique: TurretModuleOptionRange(15, 22),
  },
  TurretModuleOptionType.damageOverTimeIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(5, 8),
    TurretModuleGrade.magic: TurretModuleOptionRange(9, 15),
    TurretModuleGrade.rare: TurretModuleOptionRange(16, 24),
    TurretModuleGrade.unique: TurretModuleOptionRange(25, 36),
  },
  TurretModuleOptionType.burnDurationIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(4, 8),
    TurretModuleGrade.magic: TurretModuleOptionRange(9, 14),
    TurretModuleGrade.rare: TurretModuleOptionRange(15, 22),
    TurretModuleGrade.unique: TurretModuleOptionRange(23, 34),
  },
  TurretModuleOptionType.slowDurationIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(4, 8),
    TurretModuleGrade.magic: TurretModuleOptionRange(9, 14),
    TurretModuleGrade.rare: TurretModuleOptionRange(15, 22),
    TurretModuleGrade.unique: TurretModuleOptionRange(23, 34),
  },
  TurretModuleOptionType.slowStrengthBonus: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 4),
    TurretModuleGrade.magic: TurretModuleOptionRange(5, 7),
    TurretModuleGrade.rare: TurretModuleOptionRange(8, 10),
    TurretModuleGrade.unique: TurretModuleOptionRange(11, 14),
  },
  TurretModuleOptionType.lightningChainDamageIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(5, 8),
    TurretModuleGrade.magic: TurretModuleOptionRange(9, 15),
    TurretModuleGrade.rare: TurretModuleOptionRange(16, 24),
    TurretModuleGrade.unique: TurretModuleOptionRange(25, 36),
  },
  TurretModuleOptionType.projectileSpeedIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 4),
    TurretModuleGrade.magic: TurretModuleOptionRange(5, 7),
    TurretModuleGrade.rare: TurretModuleOptionRange(8, 11),
    TurretModuleGrade.unique: TurretModuleOptionRange(12, 16),
  },
  TurretModuleOptionType.splashSecondaryDamageBonus: {
    TurretModuleGrade.normal: TurretModuleOptionRange(3, 5),
    TurretModuleGrade.magic: TurretModuleOptionRange(6, 9),
    TurretModuleGrade.rare: TurretModuleOptionRange(10, 14),
    TurretModuleGrade.unique: TurretModuleOptionRange(15, 20),
  },
  TurretModuleOptionType.lightningChainRangeIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(3, 5),
    TurretModuleGrade.magic: TurretModuleOptionRange(6, 9),
    TurretModuleGrade.rare: TurretModuleOptionRange(10, 14),
    TurretModuleGrade.unique: TurretModuleOptionRange(15, 22),
  },
  TurretModuleOptionType.aimSpeedIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(2, 4),
    TurretModuleGrade.magic: TurretModuleOptionRange(5, 7),
    TurretModuleGrade.rare: TurretModuleOptionRange(8, 11),
    TurretModuleGrade.unique: TurretModuleOptionRange(12, 16),
  },
};

const Map<
  TurretModuleOptionType,
  Map<TurretModuleGrade, TurretModuleOptionRange>
>
_coreTurretModuleOptionRollRangeOverrides = {
  TurretModuleOptionType.damageIncrease: {
    TurretModuleGrade.normal: TurretModuleOptionRange(5, 8),
    TurretModuleGrade.magic: TurretModuleOptionRange(9, 15),
    TurretModuleGrade.rare: TurretModuleOptionRange(16, 24),
    TurretModuleGrade.unique: TurretModuleOptionRange(25, 36),
  },
};

TurretModuleFamily turretModuleFamilyFor(
  TurretType turretType,
  TurretModulePart part,
) {
  return switch ((turretType, part)) {
    (TurretType.arrow, TurretModulePart.core) => TurretModuleFamily.rapidCore,
    (TurretType.arrow, TurretModulePart.barrel) =>
      TurretModuleFamily.balancedBarrel,
    (TurretType.arrow, TurretModulePart.frame) =>
      TurretModuleFamily.stableFrame,
    (TurretType.cannon, TurretModulePart.core) => TurretModuleFamily.blastCore,
    (TurretType.cannon, TurretModulePart.barrel) =>
      TurretModuleFamily.heavyBarrel,
    (TurretType.cannon, TurretModulePart.frame) =>
      TurretModuleFamily.reinforcedFrame,
    (TurretType.magic, TurretModulePart.core) =>
      TurretModuleFamily.ignitionCore,
    (TurretType.magic, TurretModulePart.barrel) =>
      TurretModuleFamily.emberBarrel,
    (TurretType.magic, TurretModulePart.frame) =>
      TurretModuleFamily.heatSinkFrame,
    (TurretType.frost, TurretModulePart.core) => TurretModuleFamily.frostCore,
    (TurretType.frost, TurretModulePart.barrel) =>
      TurretModuleFamily.coldBarrel,
    (TurretType.frost, TurretModulePart.frame) =>
      TurretModuleFamily.coolingFrame,
    (TurretType.sniper, TurretModulePart.core) => TurretModuleFamily.scopeCore,
    (TurretType.sniper, TurretModulePart.barrel) =>
      TurretModuleFamily.precisionBarrel,
    (TurretType.sniper, TurretModulePart.frame) =>
      TurretModuleFamily.anchorFrame,
    (TurretType.lightning, TurretModulePart.core) =>
      TurretModuleFamily.currentCore,
    (TurretType.lightning, TurretModulePart.barrel) =>
      TurretModuleFamily.coilBarrel,
    (TurretType.lightning, TurretModulePart.frame) =>
      TurretModuleFamily.insulatedFrame,
  };
}

String turretModuleBaseNameFor(TurretType turretType, TurretModulePart part) {
  return switch ((turretType, part)) {
    (TurretType.arrow, TurretModulePart.core) => '과열 연산 코어',
    (TurretType.arrow, TurretModulePart.barrel) => '경량 총열',
    (TurretType.arrow, TurretModulePart.frame) => '안정 프레임',
    (TurretType.cannon, TurretModulePart.core) => '폭심 제어 코어',
    (TurretType.cannon, TurretModulePart.barrel) => '중장 포신',
    (TurretType.cannon, TurretModulePart.frame) => '보강 포가',
    (TurretType.magic, TurretModulePart.core) => '점화 증폭 코어',
    (TurretType.magic, TurretModulePart.barrel) => '잔열 포신',
    (TurretType.magic, TurretModulePart.frame) => '방열 프레임',
    (TurretType.frost, TurretModulePart.core) => '냉기 순환 코어',
    (TurretType.frost, TurretModulePart.barrel) => '냉각 포신',
    (TurretType.frost, TurretModulePart.frame) => '냉매 프레임',
    (TurretType.sniper, TurretModulePart.core) => '정밀 조준 코어',
    (TurretType.sniper, TurretModulePart.barrel) => '정밀 포신',
    (TurretType.sniper, TurretModulePart.frame) => '고정 프레임',
    (TurretType.lightning, TurretModulePart.core) => '전류 증폭 코어',
    (TurretType.lightning, TurretModulePart.barrel) => '코일 포신',
    (TurretType.lightning, TurretModulePart.frame) => '절연 프레임',
  };
}

List<TurretModuleOptionType> turretModuleOptionPoolFor(
  TurretType turretType,
  TurretModulePart part,
) {
  if (part == TurretModulePart.barrel) {
    return const [
      TurretModuleOptionType.damageIncrease,
      TurretModuleOptionType.attackRateIncrease,
      TurretModuleOptionType.criticalChanceBonus,
      TurretModuleOptionType.criticalDamageBonus,
      TurretModuleOptionType.rangeIncrease,
    ];
  }
  if (part == TurretModulePart.frame) {
    return const [
      TurretModuleOptionType.levelUpCostDiscount,
      TurretModuleOptionType.linkUpgradeCostDiscount,
      TurretModuleOptionType.buildCostDiscount,
      TurretModuleOptionType.highLevelUpgradeCostDiscount,
      TurretModuleOptionType.gemEffectIncrease,
    ];
  }
  return switch (turretType) {
    TurretType.arrow => const [
      TurretModuleOptionType.damageIncrease,
      TurretModuleOptionType.attackRateIncrease,
      TurretModuleOptionType.criticalChanceBonus,
      TurretModuleOptionType.projectileSpeedIncrease,
    ],
    TurretType.cannon => const [
      TurretModuleOptionType.damageIncrease,
      TurretModuleOptionType.splashRadiusIncrease,
      TurretModuleOptionType.splashSecondaryDamageBonus,
      TurretModuleOptionType.attackRateIncrease,
    ],
    TurretType.magic => const [
      TurretModuleOptionType.damageIncrease,
      TurretModuleOptionType.damageOverTimeIncrease,
      TurretModuleOptionType.burnDurationIncrease,
      TurretModuleOptionType.attackRateIncrease,
    ],
    TurretType.frost => const [
      TurretModuleOptionType.damageIncrease,
      TurretModuleOptionType.slowDurationIncrease,
      TurretModuleOptionType.slowStrengthBonus,
      TurretModuleOptionType.rangeIncrease,
    ],
    TurretType.sniper => const [
      TurretModuleOptionType.damageIncrease,
      TurretModuleOptionType.criticalChanceBonus,
      TurretModuleOptionType.criticalDamageBonus,
      TurretModuleOptionType.aimSpeedIncrease,
    ],
    TurretType.lightning => const [
      TurretModuleOptionType.damageIncrease,
      TurretModuleOptionType.lightningChainDamageIncrease,
      TurretModuleOptionType.lightningChainRangeIncrease,
      TurretModuleOptionType.attackRateIncrease,
    ],
  };
}

int rollTurretModuleOptionCount(TurretModuleGrade grade, math.Random random) {
  final weights = turretModuleOptionCountWeights[grade]!;
  final roll = random.nextInt(100);
  var cursor = 0;
  for (var index = 0; index < weights.length; index++) {
    cursor += weights[index];
    if (roll < cursor) {
      return index + 1;
    }
  }
  return weights.length;
}

List<TurretModuleOptionRoll> rollTurretModuleOptions({
  required TurretType turretType,
  required TurretModulePart part,
  required TurretModuleGrade grade,
  required math.Random random,
}) {
  final pool = turretModuleOptionPoolFor(turretType, part).toList()
    ..shuffle(random);
  final count = math.min(
    rollTurretModuleOptionCount(grade, random),
    pool.length,
  );
  return List.unmodifiable(
    pool.take(count).map((type) {
      final range = turretModuleOptionRollRangeFor(
        part: part,
        grade: grade,
        type: type,
      );
      return TurretModuleOptionRoll(type: type, value: range.roll(random));
    }),
  );
}

TurretModuleOptionRange turretModuleOptionRollRangeFor({
  required TurretModulePart part,
  required TurretModuleGrade grade,
  required TurretModuleOptionType type,
}) {
  if (part == TurretModulePart.core) {
    final coreOverride = _coreTurretModuleOptionRollRangeOverrides[type];
    if (coreOverride != null) {
      return coreOverride[grade]!;
    }
  }
  return turretModuleOptionRollRanges[type]![grade]!;
}

List<TurretModuleOptionRoll> minimumTurretModuleOptionsFor(
  TurretModuleKey key,
) {
  final type = turretModuleOptionPoolFor(key.turretType, key.part).first;
  final range = turretModuleOptionRollRangeFor(
    part: key.part,
    grade: key.grade,
    type: type,
  );
  return [TurretModuleOptionRoll(type: type, value: range.min)];
}

TurretModuleEffect effectiveTurretModuleEffect(TurretModuleInventoryItem item) {
  var effect = TurretModuleEffect.zero;
  for (final option in item.options) {
    effect += turretModuleEffectForOption(option);
  }
  return effect;
}

TurretModuleEffect turretModuleEffectForOption(TurretModuleOptionRoll option) {
  final rate = option.rate;
  return switch (option.type) {
    TurretModuleOptionType.damageIncrease => TurretModuleEffect(
      damageIncreaseRate: rate,
    ),
    TurretModuleOptionType.attackRateIncrease => TurretModuleEffect(
      attackRateIncreaseRate: rate,
    ),
    TurretModuleOptionType.criticalChanceBonus => TurretModuleEffect(
      criticalChanceBonusRate: rate,
    ),
    TurretModuleOptionType.criticalDamageBonus => TurretModuleEffect(
      criticalDamageBonusRate: rate,
    ),
    TurretModuleOptionType.rangeIncrease => TurretModuleEffect(
      rangeIncreaseRate: rate,
    ),
    TurretModuleOptionType.levelUpCostDiscount => TurretModuleEffect(
      levelUpCostDiscountRate: rate,
    ),
    TurretModuleOptionType.linkUpgradeCostDiscount => TurretModuleEffect(
      linkUpgradeCostDiscountRate: rate,
    ),
    TurretModuleOptionType.buildCostDiscount => TurretModuleEffect(
      buildCostDiscountRate: rate,
    ),
    TurretModuleOptionType.highLevelUpgradeCostDiscount => TurretModuleEffect(
      highLevelUpgradeCostDiscountRate: rate,
    ),
    TurretModuleOptionType.gemEffectIncrease => TurretModuleEffect(
      gemEffectIncreaseRate: rate,
    ),
    TurretModuleOptionType.splashRadiusIncrease => TurretModuleEffect(
      splashRadiusIncreaseRate: rate,
    ),
    TurretModuleOptionType.damageOverTimeIncrease => TurretModuleEffect(
      damageOverTimeIncreaseRate: rate,
    ),
    TurretModuleOptionType.burnDurationIncrease => TurretModuleEffect(
      burnDurationIncreaseRate: rate,
    ),
    TurretModuleOptionType.slowDurationIncrease => TurretModuleEffect(
      slowDurationIncreaseRate: rate,
    ),
    TurretModuleOptionType.slowStrengthBonus => TurretModuleEffect(
      slowStrengthBonusRate: rate,
    ),
    TurretModuleOptionType.lightningChainDamageIncrease => TurretModuleEffect(
      lightningChainDamageIncreaseRate: rate,
    ),
    TurretModuleOptionType.projectileSpeedIncrease => TurretModuleEffect(
      projectileSpeedIncreaseRate: rate,
    ),
    TurretModuleOptionType.splashSecondaryDamageBonus => TurretModuleEffect(
      splashSecondaryDamageBonusRate: rate,
    ),
    TurretModuleOptionType.lightningChainRangeIncrease => TurretModuleEffect(
      lightningChainRangeIncreaseRate: rate,
    ),
    TurretModuleOptionType.aimSpeedIncrease => TurretModuleEffect(
      aimSpeedIncreaseRate: rate,
    ),
  };
}

String turretModuleEffectText(TurretModuleEffect effect) {
  final parts = <String>[];
  void addPercent(String label, double rate) {
    if (rate <= 0) {
      return;
    }
    parts.add('$label +${_formatPercent(rate)}');
  }

  addPercent('피해', effect.damageIncreaseRate);
  addPercent('공격속도', effect.attackRateIncreaseRate);
  if (effect.criticalChanceBonusRate > 0) {
    parts.add('치명타 확률 +${_formatPercent(effect.criticalChanceBonusRate)}p');
  }
  if (effect.criticalDamageBonusRate > 0) {
    parts.add('치명타 피해 +${_formatPercent(effect.criticalDamageBonusRate)}p');
  }
  addPercent('사거리', effect.rangeIncreaseRate);
  if (effect.levelUpCostDiscountRate > 0) {
    parts.add('레벨업 비용 -${_formatPercent(effect.levelUpCostDiscountRate)}');
  }
  if (effect.linkUpgradeCostDiscountRate > 0) {
    parts.add(
      '링크 확장 비용 -${_formatPercent(effect.linkUpgradeCostDiscountRate)}',
    );
  }
  if (effect.buildCostDiscountRate > 0) {
    parts.add('설치 비용 -${_formatPercent(effect.buildCostDiscountRate)}');
  }
  if (effect.highLevelUpgradeCostDiscountRate > 0) {
    parts.add(
      '고레벨 강화 비용 -${_formatPercent(effect.highLevelUpgradeCostDiscountRate)}',
    );
  }
  addPercent('장착 젬 효과', effect.gemEffectIncreaseRate);
  addPercent('폭발 반경', effect.splashRadiusIncreaseRate);
  addPercent('지속피해', effect.damageOverTimeIncreaseRate);
  addPercent('화상 지속시간', effect.burnDurationIncreaseRate);
  addPercent('둔화 지속시간', effect.slowDurationIncreaseRate);
  if (effect.slowStrengthBonusRate > 0) {
    parts.add('둔화 강도 +${_formatPercent(effect.slowStrengthBonusRate)}p');
  }
  addPercent('연쇄 피해', effect.lightningChainDamageIncreaseRate);
  addPercent('투사체 속도', effect.projectileSpeedIncreaseRate);
  if (effect.splashSecondaryDamageBonusRate > 0) {
    parts.add(
      '광역 보조 피해 +${_formatPercent(effect.splashSecondaryDamageBonusRate)}p',
    );
  }
  addPercent('연쇄 거리', effect.lightningChainRangeIncreaseRate);
  addPercent('조준속도', effect.aimSpeedIncreaseRate);
  return parts.join(' · ');
}

String turretModuleOptionsText(List<TurretModuleOptionRoll> options) {
  return options.map(turretModuleOptionText).join(' · ');
}

String turretModuleOptionText(TurretModuleOptionRoll option) {
  final sign = option.type.isDiscount ? '-' : '+';
  final suffix = option.type.usesPointSuffix ? '%p' : '%';
  return '${option.type.label} $sign${option.value}$suffix';
}

String _formatPercent(double rate) {
  final percent = rate * 100;
  if ((percent - percent.round()).abs() < 0.001) {
    return '${percent.round()}%';
  }
  return '${percent.toStringAsFixed(1)}%';
}
