import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';

const double turretModuleStarEffectStepRate = 0.15;
const int turretModuleFusionShardCost = 5;
const int turretModuleMaxStars = 3;

final gameTurretModuleDefinitions = <TurretModuleKey, TurretModuleDefinition>{
  TurretModuleKey(
    turretType: TurretType.arrow,
    part: TurretModulePart.core,
    family: TurretModuleFamily.rapidCore,
    grade: TurretModuleGrade.normal,
  ): TurretModuleDefinition(
    name: '과열 연산 코어',
    effect: TurretModuleEffect(damageIncreaseRate: 0.03),
  ),
  TurretModuleKey(
    turretType: TurretType.arrow,
    part: TurretModulePart.core,
    family: TurretModuleFamily.rapidCore,
    grade: TurretModuleGrade.magic,
  ): TurretModuleDefinition(
    name: '과열 연산 코어',
    effect: TurretModuleEffect(damageIncreaseRate: 0.05),
  ),
  TurretModuleKey(
    turretType: TurretType.arrow,
    part: TurretModulePart.core,
    family: TurretModuleFamily.rapidCore,
    grade: TurretModuleGrade.rare,
  ): TurretModuleDefinition(
    name: '과열 연산 코어',
    effect: TurretModuleEffect(damageIncreaseRate: 0.08),
  ),
  ..._barrelDefinitions(
    TurretType.arrow,
    TurretModuleFamily.balancedBarrel,
    '경량 총열',
  ),
  ..._frameDefinitions(
    TurretType.arrow,
    TurretModuleFamily.stableFrame,
    '안정 프레임',
  ),
  ..._coreDefinitions(
    turretType: TurretType.cannon,
    family: TurretModuleFamily.blastCore,
    name: '폭심 제어 코어',
    effectByGrade: const {
      TurretModuleGrade.normal: TurretModuleEffect(
        splashRadiusIncreaseRate: 0.03,
      ),
      TurretModuleGrade.magic: TurretModuleEffect(
        splashRadiusIncreaseRate: 0.05,
      ),
      TurretModuleGrade.rare: TurretModuleEffect(
        splashRadiusIncreaseRate: 0.08,
      ),
    },
  ),
  ..._barrelDefinitions(
    TurretType.cannon,
    TurretModuleFamily.heavyBarrel,
    '중장 포신',
  ),
  ..._frameDefinitions(
    TurretType.cannon,
    TurretModuleFamily.reinforcedFrame,
    '보강 포가',
  ),
  ..._coreDefinitions(
    turretType: TurretType.magic,
    family: TurretModuleFamily.ignitionCore,
    name: '점화 증폭 코어',
    effectByGrade: const {
      TurretModuleGrade.normal: TurretModuleEffect(
        damageOverTimeIncreaseRate: 0.03,
      ),
      TurretModuleGrade.magic: TurretModuleEffect(
        damageOverTimeIncreaseRate: 0.05,
      ),
      TurretModuleGrade.rare: TurretModuleEffect(
        damageOverTimeIncreaseRate: 0.08,
      ),
    },
  ),
  ..._barrelDefinitions(
    TurretType.magic,
    TurretModuleFamily.emberBarrel,
    '잔열 포신',
  ),
  ..._frameDefinitions(
    TurretType.magic,
    TurretModuleFamily.heatSinkFrame,
    '방열 프레임',
  ),
  ..._coreDefinitions(
    turretType: TurretType.frost,
    family: TurretModuleFamily.frostCore,
    name: '냉기 순환 코어',
    effectByGrade: const {
      TurretModuleGrade.normal: TurretModuleEffect(
        slowDurationIncreaseRate: 0.03,
      ),
      TurretModuleGrade.magic: TurretModuleEffect(
        slowDurationIncreaseRate: 0.05,
      ),
      TurretModuleGrade.rare: TurretModuleEffect(
        slowDurationIncreaseRate: 0.08,
      ),
    },
  ),
  ..._barrelDefinitions(
    TurretType.frost,
    TurretModuleFamily.coldBarrel,
    '냉각 포신',
  ),
  ..._frameDefinitions(
    TurretType.frost,
    TurretModuleFamily.coolingFrame,
    '냉매 프레임',
  ),
  ..._coreDefinitions(
    turretType: TurretType.sniper,
    family: TurretModuleFamily.scopeCore,
    name: '정밀 조준 코어',
    effectByGrade: const {
      TurretModuleGrade.normal: TurretModuleEffect(
        criticalDamageBonusRate: 0.05,
      ),
      TurretModuleGrade.magic: TurretModuleEffect(
        criticalDamageBonusRate: 0.08,
      ),
      TurretModuleGrade.rare: TurretModuleEffect(criticalDamageBonusRate: 0.12),
    },
  ),
  ..._barrelDefinitions(
    TurretType.sniper,
    TurretModuleFamily.precisionBarrel,
    '정밀 포신',
  ),
  ..._frameDefinitions(
    TurretType.sniper,
    TurretModuleFamily.anchorFrame,
    '고정 프레임',
  ),
  ..._coreDefinitions(
    turretType: TurretType.lightning,
    family: TurretModuleFamily.currentCore,
    name: '전류 증폭 코어',
    effectByGrade: const {
      TurretModuleGrade.normal: TurretModuleEffect(
        lightningChainDamageIncreaseRate: 0.04,
      ),
      TurretModuleGrade.magic: TurretModuleEffect(
        lightningChainDamageIncreaseRate: 0.06,
      ),
      TurretModuleGrade.rare: TurretModuleEffect(
        lightningChainDamageIncreaseRate: 0.10,
      ),
    },
  ),
  ..._barrelDefinitions(
    TurretType.lightning,
    TurretModuleFamily.coilBarrel,
    '코일 포신',
  ),
  ..._frameDefinitions(
    TurretType.lightning,
    TurretModuleFamily.insulatedFrame,
    '절연 프레임',
  ),
};

class TurretModuleDefinition {
  const TurretModuleDefinition({required this.name, required this.effect});

  final String name;
  final TurretModuleEffect effect;
}

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

TurretModuleEffect effectiveTurretModuleEffect(TurretModuleInventoryItem item) {
  final definition = gameTurretModuleDefinitions[item.key];
  if (definition == null) {
    return TurretModuleEffect.zero;
  }
  final clampedStars = item.stars.clamp(0, turretModuleMaxStars).toInt();
  return definition.effect.scaledBy(
    1 + clampedStars * turretModuleStarEffectStepRate,
  );
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
  if (effect.levelUpCostDiscountRate > 0) {
    parts.add('레벨업 비용 -${_formatPercent(effect.levelUpCostDiscountRate)}');
  }
  addPercent('폭발 반경', effect.splashRadiusIncreaseRate);
  addPercent('지속피해', effect.damageOverTimeIncreaseRate);
  addPercent('둔화 지속시간', effect.slowDurationIncreaseRate);
  if (effect.criticalDamageBonusRate > 0) {
    parts.add('치명타 추가 피해 +${_formatPercent(effect.criticalDamageBonusRate)}p');
  }
  addPercent('연쇄 피해', effect.lightningChainDamageIncreaseRate);
  return parts.join(' · ');
}

Map<TurretModuleKey, TurretModuleDefinition> _coreDefinitions({
  required TurretType turretType,
  required TurretModuleFamily family,
  required String name,
  required Map<TurretModuleGrade, TurretModuleEffect> effectByGrade,
}) {
  return {
    for (final entry in effectByGrade.entries)
      TurretModuleKey(
        turretType: turretType,
        part: TurretModulePart.core,
        family: family,
        grade: entry.key,
      ): TurretModuleDefinition(
        name: name,
        effect: entry.value,
      ),
  };
}

Map<TurretModuleKey, TurretModuleDefinition> _barrelDefinitions(
  TurretType turretType,
  TurretModuleFamily family,
  String name,
) {
  const effects = {
    TurretModuleGrade.normal: TurretModuleEffect(damageIncreaseRate: 0.02),
    TurretModuleGrade.magic: TurretModuleEffect(
      damageIncreaseRate: 0.04,
      attackRateIncreaseRate: 0.01,
    ),
    TurretModuleGrade.rare: TurretModuleEffect(
      damageIncreaseRate: 0.06,
      attackRateIncreaseRate: 0.02,
    ),
  };
  return {
    for (final entry in effects.entries)
      TurretModuleKey(
        turretType: turretType,
        part: TurretModulePart.barrel,
        family: family,
        grade: entry.key,
      ): TurretModuleDefinition(
        name: name,
        effect: entry.value,
      ),
  };
}

Map<TurretModuleKey, TurretModuleDefinition> _frameDefinitions(
  TurretType turretType,
  TurretModuleFamily family,
  String name,
) {
  const effects = {
    TurretModuleGrade.normal: TurretModuleEffect(levelUpCostDiscountRate: 0.01),
    TurretModuleGrade.magic: TurretModuleEffect(levelUpCostDiscountRate: 0.02),
    TurretModuleGrade.rare: TurretModuleEffect(levelUpCostDiscountRate: 0.035),
  };
  return {
    for (final entry in effects.entries)
      TurretModuleKey(
        turretType: turretType,
        part: TurretModulePart.frame,
        family: family,
        grade: entry.key,
      ): TurretModuleDefinition(
        name: name,
        effect: entry.value,
      ),
  };
}

String _formatPercent(double rate) {
  final percent = rate * 100;
  if ((percent - percent.round()).abs() < 0.001) {
    return '${percent.round()}%';
  }
  return '${percent.toStringAsFixed(1)}%';
}
