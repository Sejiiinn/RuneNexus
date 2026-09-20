import 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart'
    as core;
import 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
import 'package:rune_nexus/domain/core/core_passive_tree.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';

Map<String, Object?> exportCoreGrowth() => {
  'revision': core.corePassiveTreeRevision,
  'verificationCases': [
    for (final offset in [0, 1, 3, 5])
      (() {
        final ranks = <CorePassiveNodeId, int>{
          for (final e in core.corePassiveNodeDefinitions.entries)
            e.key: offset.clamp(0, e.value.maxRank),
        };
        return {
          'ranks': {for (final e in ranks.entries) e.key.name: e.value},
          'effects': _coreEffects(ranks),
        };
      })(),
  ],
  'startingNodes': core.corePassiveStartingNodeIds.map((v) => v.name).toList(),
  'nodes': {
    for (final e in core.corePassiveNodeDefinitions.entries)
      e.key.name: {
        'maxRank': e.value.maxRank,
        'rankCosts': e.value.rankCosts,
        'neighbors': e.value.neighbors.map((v) => v.name).toList(),
        'effects': [
          for (var rank = 0; rank <= e.value.maxRank; rank++)
            _coreEffects({e.key: rank}),
        ],
      },
  },
};
Map<String, Object?> _coreEffects(Map<CorePassiveNodeId, int> r) => {
  'cooldownRecoveryRate': core.corePassiveCooldownRecoveryRate(r),
  'turretAttackRateAmplification': core
      .corePassiveTurretAttackRateAmplification(r),
  'turretDamageAmplification': core.corePassiveTurretDamageAmplification(r),
  'coreSkillPowerMultiplier': core.corePassiveCoreSkillPowerMultiplier(
    r,
    activationNumber: 1,
  ),
  'thirdCoreSkillPowerMultiplier': core.corePassiveCoreSkillPowerMultiplier(
    r,
    activationNumber: 3,
  ),
  'nexusMaxHpMultiplier': core.corePassiveNexusMaxHpMultiplier(r),
  'roundRecoveryRate': core.corePassiveRoundRecoveryRate(r),
  'damageRestorationRate': core.corePassiveDamageRestorationRate(r),
  'impactDispersionRate':
      1 - core.corePassiveNexusDamageMultiplier(r, lostDurabilityRatio: 0),
  'threatWeakeningRate':
      1 -
      core.corePassiveNexusDamageMultiplier(r, lostDurabilityRatio: 1) /
          core.corePassiveNexusDamageMultiplier(r, lostDurabilityRatio: 0),
  'emergencyRecoveryRate': core.corePassiveEmergencyChargeRecoveryRate(r),
  'hasFinalDefense': core.corePassiveHasFinalDefense(r),
  'hasCombinedFront': core.corePassiveHasCombinedFront(
    r,
    distinctTurretTypeCount: 4,
  ),
  'buildCostMultiplier': core.corePassiveTurretBuildCostMultiplier(
    r,
    distinctTurretTypeCount: 0,
  ),
  'combinedFrontMultiplier':
      core.corePassiveTurretBuildCostMultiplier(r, distinctTurretTypeCount: 4) /
      core.corePassiveTurretBuildCostMultiplier(r, distinctTurretTypeCount: 0),
  'roundClearGoldMultiplier': core.corePassiveRoundClearGoldMultiplier(r),
  'traitShardCostMultiplier': core.corePassiveTraitShardCostMultiplier(r),
  'diversityDiscountPerType':
      1 -
      core.corePassiveTurretLevelUpCostMultiplier(
        r,
        distinctTurretTypeCount: 2,
      ),
  'gemSpectrumPerType':
      (core.corePassiveNumericGemEffectMultiplier(
            r,
            distinctEquippedGemTypeCount: 3,
          ) -
          1) /
      3,
  'linkCostMultiplier': core.corePassiveTurretLinkCostMultiplier(
    r,
    distinctTurretTypeCount: 0,
  ),
};
Map<String, Object?> exportModuleGrowth() => {
  'pools': {
    for (final t in TurretType.values)
      t.name: {
        for (final p in TurretModulePart.values)
          p.name: turretModuleOptionPoolFor(t, p).map((v) => v.name).toList(),
      },
  },
  'ranges': {
    for (final e in turretModuleOptionRollRanges.entries)
      e.key.name: {
        for (final g in e.value.entries)
          g.key.name: {'min': g.value.min, 'max': g.value.max},
      },
  },
  'families': {
    for (final t in TurretType.values)
      t.name: {
        for (final p in TurretModulePart.values)
          p.name: turretModuleFamilyFor(t, p).name,
      },
  },
  'effects': {
    for (final t in TurretModuleOptionType.values)
      t.name: _moduleEffect(
        turretModuleEffectForOption(
          TurretModuleOptionRoll(type: t, value: 100),
        ),
      ),
  },
};
Map<String, Object?> _moduleEffect(TurretModuleEffect e) => {
  'damageIncreaseRate': e.damageIncreaseRate,
  'attackRateIncreaseRate': e.attackRateIncreaseRate,
  'criticalChanceBonusRate': e.criticalChanceBonusRate,
  'criticalDamageBonusRate': e.criticalDamageBonusRate,
  'rangeIncreaseRate': e.rangeIncreaseRate,
  'levelUpCostDiscountRate': e.levelUpCostDiscountRate,
  'linkUpgradeCostDiscountRate': e.linkUpgradeCostDiscountRate,
  'buildCostDiscountRate': e.buildCostDiscountRate,
  'highLevelUpgradeCostDiscountRate': e.highLevelUpgradeCostDiscountRate,
  'gemEffectIncreaseRate': e.gemEffectIncreaseRate,
  'splashRadiusIncreaseRate': e.splashRadiusIncreaseRate,
  'damageOverTimeIncreaseRate': e.damageOverTimeIncreaseRate,
  'burnDurationIncreaseRate': e.burnDurationIncreaseRate,
  'slowDurationIncreaseRate': e.slowDurationIncreaseRate,
  'slowStrengthBonusRate': e.slowStrengthBonusRate,
  'lightningChainDamageIncreaseRate': e.lightningChainDamageIncreaseRate,
  'projectileSpeedIncreaseRate': e.projectileSpeedIncreaseRate,
  'splashSecondaryDamageBonusRate': e.splashSecondaryDamageBonusRate,
  'lightningChainRangeIncreaseRate': e.lightningChainRangeIncreaseRate,
  'aimSpeedIncreaseRate': e.aimSpeedIncreaseRate,
};
