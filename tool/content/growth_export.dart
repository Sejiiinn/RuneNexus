// Build-time only: all exported values are read from live Dart gameplay APIs.
import 'dart:convert';
import '../godot_growth_core_export.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/data/definitions/game_research_data.dart';
import 'package:rune_nexus/data/definitions/game_run_upgrade_data.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';
import 'package:rune_nexus/game/systems/turret_action_controller.dart';
import 'package:rune_nexus/game/systems/gem_reward_generator.dart';

const growthContentPath = 'godot/content/growth_content.json';
String encodeGrowth(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';
TurretComponent growthTurret(TurretType type) => TurretComponent(
  gridPoint: const GridPoint(1, 1),
  definition: gameTurrets[type]!,
  game: RuneNexusGame(),
  center: Vector2(48, 48),
  tileSize: 48,
);
Map<String, Object?> exportGrowthContent() {
  final progression = RunProgression()..runes = 1 << 60;
  final permanent = <String, Object?>{};
  progression.bossBountyUpgradeLevel = 0;
  permanent['bossBounty'] = {
    'field': 'bossBountyUpgradeLevel',
    'maxLevel': RunProgression.maxBossBountyUpgradeLevel,
    'enabled': progression.canUpgradeBossBounty,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxBossBountyUpgradeLevel;
        level++
      )
        (() {
          progression.bossBountyUpgradeLevel = level;
          return progression.bossBountyUpgradeCost;
        })(),
    ],
  };
  progression.bossBountyUpgradeLevel = 0;
  progression.startingGoldUpgradeLevel = 0;
  permanent['startingGold'] = {
    'field': 'startingGoldUpgradeLevel',
    'maxLevel': RunProgression.maxStartingGoldUpgradeLevel,
    'enabled': progression.canUpgradeStartingGold,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxStartingGoldUpgradeLevel;
        level++
      )
        (() {
          progression.startingGoldUpgradeLevel = level;
          return progression.startingGoldUpgradeCost;
        })(),
    ],
  };
  progression.startingGoldUpgradeLevel = 0;
  progression.nexusHpUpgradeLevel = 0;
  permanent['nexusHp'] = {
    'field': 'nexusHpUpgradeLevel',
    'maxLevel': RunProgression.maxNexusHpUpgradeLevel,
    'enabled': progression.canUpgradeNexusHp,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxNexusHpUpgradeLevel;
        level++
      )
        (() {
          progression.nexusHpUpgradeLevel = level;
          return progression.nexusHpUpgradeCost;
        })(),
    ],
  };
  progression.nexusHpUpgradeLevel = 0;
  progression.supplyUpgradeLevel = 0;
  permanent['supply'] = {
    'field': 'supplyUpgradeLevel',
    'maxLevel': RunProgression.maxSupplyUpgradeLevel,
    'enabled': progression.canUpgradeSupply,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxSupplyUpgradeLevel;
        level++
      )
        (() {
          progression.supplyUpgradeLevel = level;
          return progression.supplyUpgradeCost;
        })(),
    ],
  };
  progression.supplyUpgradeLevel = 0;
  progression.fireTrainingUpgradeLevel = 0;
  permanent['fireTraining'] = {
    'field': 'fireTrainingUpgradeLevel',
    'maxLevel': RunProgression.maxFireTrainingUpgradeLevel,
    'enabled': progression.canUpgradeFireTraining,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxFireTrainingUpgradeLevel;
        level++
      )
        (() {
          progression.fireTrainingUpgradeLevel = level;
          return progression.fireTrainingUpgradeCost;
        })(),
    ],
  };
  progression.fireTrainingUpgradeLevel = 0;
  progression.physicalDamageTrainingUpgradeLevel = 0;
  permanent['physicalDamageTraining'] = {
    'field': 'physicalDamageTrainingUpgradeLevel',
    'maxLevel': RunProgression.maxPhysicalDamageTrainingUpgradeLevel,
    'enabled': progression.canUpgradePhysicalDamageTraining,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxPhysicalDamageTrainingUpgradeLevel;
        level++
      )
        (() {
          progression.physicalDamageTrainingUpgradeLevel = level;
          return progression.physicalDamageTrainingUpgradeCost;
        })(),
    ],
  };
  progression.physicalDamageTrainingUpgradeLevel = 0;
  progression.elementalDamageTrainingUpgradeLevel = 0;
  permanent['elementalDamageTraining'] = {
    'field': 'elementalDamageTrainingUpgradeLevel',
    'maxLevel': RunProgression.maxElementalDamageTrainingUpgradeLevel,
    'enabled': progression.canUpgradeElementalDamageTraining,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxElementalDamageTrainingUpgradeLevel;
        level++
      )
        (() {
          progression.elementalDamageTrainingUpgradeLevel = level;
          return progression.elementalDamageTrainingUpgradeCost;
        })(),
    ],
  };
  progression.elementalDamageTrainingUpgradeLevel = 0;
  progression.criticalChanceUpgradeLevel = 0;
  permanent['criticalChance'] = {
    'field': 'criticalChanceUpgradeLevel',
    'maxLevel': RunProgression.maxCriticalChanceUpgradeLevel,
    'enabled': progression.canUpgradeCriticalChance,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxCriticalChanceUpgradeLevel;
        level++
      )
        (() {
          progression.criticalChanceUpgradeLevel = level;
          return progression.criticalChanceUpgradeCost;
        })(),
    ],
  };
  progression.criticalChanceUpgradeLevel = 0;
  progression.criticalDamageUpgradeLevel = 0;
  permanent['criticalDamage'] = {
    'field': 'criticalDamageUpgradeLevel',
    'maxLevel': RunProgression.maxCriticalDamageUpgradeLevel,
    'enabled': progression.canUpgradeCriticalDamage,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxCriticalDamageUpgradeLevel;
        level++
      )
        (() {
          progression.criticalDamageUpgradeLevel = level;
          return progression.criticalDamageUpgradeCost;
        })(),
    ],
  };
  progression.criticalDamageUpgradeLevel = 0;
  progression.killGoldUpgradeLevel = 0;
  permanent['killGold'] = {
    'field': 'killGoldUpgradeLevel',
    'maxLevel': RunProgression.maxKillGoldUpgradeLevel,
    'enabled': progression.canUpgradeKillGold,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxKillGoldUpgradeLevel;
        level++
      )
        (() {
          progression.killGoldUpgradeLevel = level;
          return progression.killGoldUpgradeCost;
        })(),
    ],
  };
  progression.killGoldUpgradeLevel = 0;
  progression.emergencySaleUpgradeLevel = 0;
  permanent['emergencySale'] = {
    'field': 'emergencySaleUpgradeLevel',
    'maxLevel': RunProgression.maxEmergencySaleUpgradeLevel,
    'enabled': progression.canUpgradeEmergencySale,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxEmergencySaleUpgradeLevel;
        level++
      )
        (() {
          progression.emergencySaleUpgradeLevel = level;
          return progression.emergencySaleUpgradeCost;
        })(),
    ],
  };
  progression.emergencySaleUpgradeLevel = 0;
  progression.linkCostOptimizationUpgradeLevel = 0;
  permanent['linkCostOptimization'] = {
    'field': 'linkCostOptimizationUpgradeLevel',
    'maxLevel': RunProgression.maxLinkCostOptimizationUpgradeLevel,
    'enabled': progression.canUpgradeLinkCostOptimization,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxLinkCostOptimizationUpgradeLevel;
        level++
      )
        (() {
          progression.linkCostOptimizationUpgradeLevel = level;
          return progression.linkCostOptimizationUpgradeCost;
        })(),
    ],
  };
  progression.linkCostOptimizationUpgradeLevel = 0;
  progression.turretLevelUpOptimizationUpgradeLevel = 0;
  permanent['turretLevelUpOptimization'] = {
    'field': 'turretLevelUpOptimizationUpgradeLevel',
    'maxLevel': RunProgression.maxTurretLevelUpOptimizationUpgradeLevel,
    'enabled': progression.canUpgradeTurretLevelUpOptimization,
    'costs': [
      for (
        var level = 0;
        level <= RunProgression.maxTurretLevelUpOptimizationUpgradeLevel;
        level++
      )
        (() {
          progression.turretLevelUpOptimizationUpgradeLevel = level;
          return progression.turretLevelUpOptimizationUpgradeCost;
        })(),
    ],
  };
  progression.turretLevelUpOptimizationUpgradeLevel = 0;
  return {
    'schemaVersion': 1,
    'constants': {
      'currentGrowthVersion': RunProgression.currentGrowthVersion,
      'maxBossBountyUpgradeLevel': RunProgression.maxBossBountyUpgradeLevel,
      'bossBountyUpgradeBaseCost': RunProgression.bossBountyUpgradeBaseCost,
      'bossBountyUpgradeCostMultiplier':
          RunProgression.bossBountyUpgradeCostMultiplier,
      'bossBountyBonusPerUpgradeLevel':
          RunProgression.bossBountyBonusPerUpgradeLevel,
      'criticalChanceBonusPerResearchLevel':
          RunProgression.criticalChanceBonusPerResearchLevel,
      'baseInitialGold': RunProgression.baseInitialGold,
      'baseNexusHp': RunProgression.baseNexusHp,
      'maxStageCount': RunProgression.maxStageCount,
      'maxStartingGoldUpgradeLevel': RunProgression.maxStartingGoldUpgradeLevel,
      'maxNexusHpUpgradeLevel': RunProgression.maxNexusHpUpgradeLevel,
      'maxSupplyUpgradeLevel': RunProgression.maxSupplyUpgradeLevel,
      'maxFireTrainingUpgradeLevel': RunProgression.maxFireTrainingUpgradeLevel,
      'maxPhysicalDamageTrainingUpgradeLevel':
          RunProgression.maxPhysicalDamageTrainingUpgradeLevel,
      'maxElementalDamageTrainingUpgradeLevel':
          RunProgression.maxElementalDamageTrainingUpgradeLevel,
      'maxCriticalChanceUpgradeLevel':
          RunProgression.maxCriticalChanceUpgradeLevel,
      'maxCriticalDamageUpgradeLevel':
          RunProgression.maxCriticalDamageUpgradeLevel,
      'maxKillGoldUpgradeLevel': RunProgression.maxKillGoldUpgradeLevel,
      'maxEmergencySaleUpgradeLevel':
          RunProgression.maxEmergencySaleUpgradeLevel,
      'maxLinkCostOptimizationUpgradeLevel':
          RunProgression.maxLinkCostOptimizationUpgradeLevel,
      'maxTurretLevelUpOptimizationUpgradeLevel':
          RunProgression.maxTurretLevelUpOptimizationUpgradeLevel,
      'researchSlotCount': RunProgression.researchSlotCount,
      'researchSlotTwoUnlockRequiredStage':
          RunProgression.researchSlotTwoUnlockRequiredStage,
      'researchSlotTwoUnlockCost': RunProgression.researchSlotTwoUnlockCost,
      'gemShardsPerGemAttunementLevel':
          RunProgression.gemShardsPerGemAttunementLevel,
      'turretModuleTicketDiamondCost':
          RunProgression.turretModuleTicketDiamondCost,
      'diamondMillisPerResearchMinute':
          RunProgression.diamondMillisPerResearchMinute,
      'uninitializedDailyQuestDayKey':
          RunProgression.uninitializedDailyQuestDayKey,
      'uninitializedWeeklyQuestWeekKey':
          RunProgression.uninitializedWeeklyQuestWeekKey,
      'dailyQuestResetHourKst': RunProgression.dailyQuestResetHourKst,
      'dailyQuestClockRollbackGraceMillis':
          RunProgression.dailyQuestClockRollbackGraceMillis,
      'researchEfficiencyPerLevel': RunProgression.researchEfficiencyPerLevel,
      'researchCostEfficiencyPerLevel':
          RunProgression.researchCostEfficiencyPerLevel,
      'bossBountyBonusPerLevel': RunProgression.bossBountyBonusPerLevel,
      'linkMaintenanceDiscountPerLevel':
          RunProgression.linkMaintenanceDiscountPerLevel,
      'runeResonanceBonusPerLevel': RunProgression.runeResonanceBonusPerLevel,
      'runUpgradeCostDiscountPerLevel':
          RunProgression.runUpgradeCostDiscountPerLevel,
      'runUpgradeLimitExpansionMaxLevelPerLevel':
          RunProgression.runUpgradeLimitExpansionMaxLevelPerLevel,
      'bossGemShardsPerCrystalRecoveryLevel':
          RunProgression.bossGemShardsPerCrystalRecoveryLevel,
      'runeRewardFullClearRoundCount':
          RunProgression.runeRewardFullClearRoundCount,
      'baseStageOneFullClearRuneReward':
          RunProgression.baseStageOneFullClearRuneReward,
      'runeRewardGrowthPerRound': RunProgression.runeRewardGrowthPerRound,
      'stageRuneRewardGrowthPerStage':
          RunProgression.stageRuneRewardGrowthPerStage,
      'baseTurretRefundPercent': RunProgression.baseTurretRefundPercent,
      'startingGoldUpgradeBaseCost': RunProgression.startingGoldUpgradeBaseCost,
      'startingGoldUpgradeCostPerLevel':
          RunProgression.startingGoldUpgradeCostPerLevel,
      'startingGoldUpgradeCostMultiplier':
          RunProgression.startingGoldUpgradeCostMultiplier,
      'startingGoldPerUpgradeLevel': RunProgression.startingGoldPerUpgradeLevel,
      'nexusHpUpgradeBaseCost': RunProgression.nexusHpUpgradeBaseCost,
      'nexusHpUpgradeCostPerLevel': RunProgression.nexusHpUpgradeCostPerLevel,
      'nexusHpUpgradeCostMultiplier':
          RunProgression.nexusHpUpgradeCostMultiplier,
      'supplyUpgradeBaseCost': RunProgression.supplyUpgradeBaseCost,
      'supplyUpgradeCostPerLevel': RunProgression.supplyUpgradeCostPerLevel,
      'supplyUpgradeCostMultiplier': RunProgression.supplyUpgradeCostMultiplier,
      'supplyGoldPerUpgradeLevel': RunProgression.supplyGoldPerUpgradeLevel,
      'fireTrainingUpgradeBaseCost': RunProgression.fireTrainingUpgradeBaseCost,
      'fireTrainingUpgradeCostPerLevel':
          RunProgression.fireTrainingUpgradeCostPerLevel,
      'fireTrainingUpgradeCostMultiplier':
          RunProgression.fireTrainingUpgradeCostMultiplier,
      'fireTrainingDamagePerUpgradeLevel':
          RunProgression.fireTrainingDamagePerUpgradeLevel,
      'familyDamageTrainingUpgradeBaseCost':
          RunProgression.familyDamageTrainingUpgradeBaseCost,
      'familyDamageTrainingUpgradeCostPerLevel':
          RunProgression.familyDamageTrainingUpgradeCostPerLevel,
      'familyDamageTrainingUpgradeCostMultiplier':
          RunProgression.familyDamageTrainingUpgradeCostMultiplier,
      'familyDamageTrainingBonusPerUpgradeLevel':
          RunProgression.familyDamageTrainingBonusPerUpgradeLevel,
      'criticalChanceUpgradeBaseCost':
          RunProgression.criticalChanceUpgradeBaseCost,
      'criticalChanceUpgradeCostMultiplier':
          RunProgression.criticalChanceUpgradeCostMultiplier,
      'criticalChanceBonusPerUpgradeLevel':
          RunProgression.criticalChanceBonusPerUpgradeLevel,
      'criticalDamageUpgradeBaseCost':
          RunProgression.criticalDamageUpgradeBaseCost,
      'criticalDamageUpgradeCostMultiplier':
          RunProgression.criticalDamageUpgradeCostMultiplier,
      'criticalDamageBonusPerUpgradeLevel':
          RunProgression.criticalDamageBonusPerUpgradeLevel,
      'killGoldUpgradeBaseCost': RunProgression.killGoldUpgradeBaseCost,
      'killGoldUpgradeCostPerLevel': RunProgression.killGoldUpgradeCostPerLevel,
      'killGoldUpgradeCostMultiplier':
          RunProgression.killGoldUpgradeCostMultiplier,
      'killGoldBonusPerUpgradeLevel':
          RunProgression.killGoldBonusPerUpgradeLevel,
      'emergencySaleUpgradeBaseCost':
          RunProgression.emergencySaleUpgradeBaseCost,
      'emergencySaleRefundPercentPerLevel':
          RunProgression.emergencySaleRefundPercentPerLevel,
      'linkCostOptimizationUpgradeBaseCost':
          RunProgression.linkCostOptimizationUpgradeBaseCost,
      'linkCostOptimizationUpgradeCostPerLevel':
          RunProgression.linkCostOptimizationUpgradeCostPerLevel,
      'linkCostOptimizationUpgradeCostMultiplier':
          RunProgression.linkCostOptimizationUpgradeCostMultiplier,
      'turretLevelUpOptimizationUpgradeBaseCost':
          RunProgression.turretLevelUpOptimizationUpgradeBaseCost,
      'turretLevelUpOptimizationUpgradeCostPerLevel':
          RunProgression.turretLevelUpOptimizationUpgradeCostPerLevel,
      'turretLevelUpOptimizationUpgradeCostMultiplier':
          RunProgression.turretLevelUpOptimizationUpgradeCostMultiplier,
      'permanentCostReductionPerUpgradeLevel':
          RunProgression.permanentCostReductionPerUpgradeLevel,

      'economyUpgradeUnlockStage': RuneNexusGame.economyUpgradeUnlockStage,
      'sniperUnlockStage': RuneNexusGame.sniperUnlockStage,
      'aimSpeedGemUnlockStage': RuneNexusGame.aimSpeedGemUnlockStage,
      'armorPiercingGemUnlockStage': RuneNexusGame.armorPiercingGemUnlockStage,
      'primaryTraitCost': RuneNexusGame.primaryTraitCost,
      'secondaryTraitCost': RuneNexusGame.secondaryTraitCost,
      'gemChoicePurchaseCost': RuneNexusGame.gemChoicePurchaseCost,
      'gemShardRewardFallbackAmount':
          RuneNexusGame.gemShardRewardFallbackAmount,
    },
    'defaultProgression': RunProgression().toSaveData().toJson(),
    'core': exportCoreGrowth(),
    'module': exportModuleGrowth(),
    'permanentUpgrades': permanent,
    'research': {
      for (final e in gameResearchDefinitions.entries)
        e.key.name: {
          'maxLevel': e.value.maxLevel,
          'requiredClearedStage': e.value.requiredClearedStage,
          'costs': [
            for (var n = 0; n <= e.value.maxLevel; n++)
              e.value.costForCurrentLevel(n),
          ],
          'durations': [
            for (var n = 0; n <= e.value.maxLevel; n++)
              e.value.durationForCurrentLevel(n),
          ],
        },
    },
    'runUpgrades': {
      for (final e in gameRunUpgrades.entries)
        e.key.name: {
          'maxLevel': e.value.maxLevel,
          'baseCost': e.value.baseCost,
          'costMultiplier': e.value.costMultiplier,
          'effectPerLevel': e.value.effectPerLevel,
          'costs': [
            for (var n = 0; n <= 40; n++) e.value.costForLevel(n, maxLevel: 40),
          ],
          'effects': [
            for (var n = 0; n <= 40; n++)
              e.value.effectForLevel(n, maxLevel: 40),
          ],
        },
    },
    'gems': GemType.values.map((g) => g.name).toList(),
    'roundShardRewards': [
      for (var n = 0; n <= 60; n++)
        RuneNexusGame.roundClearGemShardRewardFor(n),
    ],
    'rewardRounds': [
      for (var n = 1; n <= 60; n++)
        if (GemRewardGenerator().shouldOfferReward(n)) n,
    ],
    'turretRules': {
      for (final type in gameTurrets.keys) type.name: _turretRules(type),
    },
  };
}

Map<String, Object?> _turretRules(TurretType type) {
  final turret = growthTurret(type);
  final costs = <int>[];
  while (turret.canLevelUp) {
    costs.add(turret.levelUpCost);
    turret.upgradeLevel();
  }
  final links = <int>[];
  final required = <int>[];
  while (turret.canUpgradeLink) {
    links.add(turret.linkUpgradeCost);
    required.add(turret.linkUpgradeRequiredLevel);
    turret.upgradeLink();
  }
  return {
    'buildCost': turret.definition.cost,
    'maxLevel': turret.maxLevel,
    'baseMaxSlots': turret.maxSlotLimit,
    'levelUpCosts': costs,
    'linkUpgradeCosts': links,
    'linkRequiredLevels': required,
    'primaryTraits': turret.primaryTraitChoices.map((t) => t.name).toList(),
    'secondaryTraits': turret.secondaryTraitChoices.map((t) => t.name).toList(),
    'compatibleGems': [
      for (final g in GemType.values)
        if (canEquipGemOnTurret(g, turret.definition)) g.name,
    ],
  };
}

/// Each case starts fresh; no onLoad, filesystem save or platform calls.
Map<String, Object?> exportGrowthCases() {
  final cases = <Object?>[];
  for (final type in gameTurrets.keys) {
    final t = growthTurret(type);
    final controller = TurretActionController();
    final turrets = {t.gridPoint: t};
    final inventory = <GemType, int>{for (final g in GemType.values) g: 2};
    var gold = 100000;
    var shards = 1000;
    Map<String, Object?> snapshot() => {
      'gold': gold,
      'gemShards': shards,
      'gemInventory': {for (final e in inventory.entries) e.key.name: e.value},
      'turret': turrets.isEmpty ? null : t.toSaveData().toJson(),
      'statInput': turrets.isEmpty
          ? null
          : t.nativeCombatConfiguration(0)['statInput'],
    };
    void step(
      Map<String, Object?> command,
      TurretActionResult? Function() apply,
    ) {
      final before = snapshot();
      final result = apply();
      if (result != null) {
        gold = result.gold;
        shards = result.gemShards;
      }
      cases.add({
        'name': '${type.name}_${cases.length}',
        'before': before,
        'command': command,
        'ok': result != null,
        'after': snapshot(),
      });
    }

    TurretActionResult? level(bool canEdit, {int? wallet}) =>
        controller.levelUp(
          canEditBoard: canEdit,
          selectedPoint: t.gridPoint,
          turrets: turrets,
          gold: wallet ?? gold,
          gemShards: shards,
          selectedGemSlotIndex: null,
          levelUpPreviewPoint: null,
        );
    step({'type': 'levelUp', 'canEditBoard': false}, () => level(false));
    final originalGold = gold;
    gold = 0;
    step({'type': 'levelUp', 'canEditBoard': true}, () => level(true));
    gold = originalGold;
    step(
      {'type': 'upgradeLink', 'phase': 'reward'},
      () => controller.upgradeLink(
        phase: GamePhase.reward,
        selectedPoint: t.gridPoint,
        turrets: turrets,
        gold: gold,
        gemShards: shards,
        levelUpPreviewPoint: null,
      ),
    );
    step(
      {'type': 'upgradeLink', 'phase': 'preparation'},
      () => controller.upgradeLink(
        phase: GamePhase.preparation,
        selectedPoint: t.gridPoint,
        turrets: turrets,
        gold: gold,
        gemShards: shards,
        levelUpPreviewPoint: null,
      ),
    );
    step(
      {'type': 'upgradeLink', 'phase': 'wave'},
      () => controller.upgradeLink(
        phase: GamePhase.wave,
        selectedPoint: t.gridPoint,
        turrets: turrets,
        gold: gold,
        gemShards: shards,
        levelUpPreviewPoint: null,
      ),
    );
    for (var n = 0; n < 10; n++) {
      step({'type': 'levelUp', 'canEditBoard': true}, () => level(true));
    }
    step(
      {'type': 'upgradeLink', 'phase': 'wave'},
      () => controller.upgradeLink(
        phase: GamePhase.wave,
        selectedPoint: t.gridPoint,
        turrets: turrets,
        gold: gold,
        gemShards: shards,
        levelUpPreviewPoint: null,
      ),
    );
    for (final trait in t.primaryTraitChoices) {
      step(
        {
          'type': 'choosePrimaryTrait',
          'trait': trait.name,
          'canEditBoard': true,
          'cost': RuneNexusGame.primaryTraitCost,
        },
        () => controller.choosePrimaryTrait(
          canEditBoard: true,
          selectedPoint: t.gridPoint,
          turrets: turrets,
          gold: gold,
          gemShards: shards,
          selectedGemSlotIndex: null,
          levelUpPreviewPoint: null,
          primaryTraitCost: RuneNexusGame.primaryTraitCost,
          trait: trait,
        ),
      );
    }
    for (final trait in t.secondaryTraitChoices) {
      step(
        {
          'type': 'chooseSecondaryTrait',
          'trait': trait.name,
          'canEditBoard': true,
          'cost': RuneNexusGame.secondaryTraitCost,
        },
        () => controller.chooseSecondaryTrait(
          canEditBoard: true,
          selectedPoint: t.gridPoint,
          turrets: turrets,
          gold: gold,
          gemShards: shards,
          selectedGemSlotIndex: null,
          levelUpPreviewPoint: null,
          secondaryTraitCost: RuneNexusGame.secondaryTraitCost,
          trait: trait,
        ),
      );
    }
    for (final gem in GemType.values) {
      step(
        {'type': 'equipGem', 'gem': gem.name, 'slotIndex': 1, 'phase': 'wave'},
        () => controller.equipGem(
          phase: GamePhase.wave,
          selectedPoint: t.gridPoint,
          selectedSlotIndex: 1,
          turrets: turrets,
          gemInventory: inventory,
          type: gem,
          gold: gold,
          gemShards: shards,
          levelUpPreviewPoint: null,
        ),
      );
      step(
        {'type': 'equipGem', 'gem': gem.name, 'slotIndex': 0, 'phase': 'wave'},
        () => controller.equipGem(
          phase: GamePhase.wave,
          selectedPoint: t.gridPoint,
          selectedSlotIndex: 0,
          turrets: turrets,
          gemInventory: inventory,
          type: gem,
          gold: gold,
          gemShards: shards,
          levelUpPreviewPoint: null,
        ),
      );
    }
    step(
      {'type': 'removeGem', 'slotIndex': 1, 'phase': 'preparation'},
      () => controller.removeGem(
        phase: GamePhase.preparation,
        selectedPoint: t.gridPoint,
        selectedSlotIndex: 1,
        turrets: turrets,
        gemInventory: inventory,
        gold: gold,
        gemShards: shards,
        levelUpPreviewPoint: null,
      ),
    );
    step(
      {'type': 'refund', 'canEditBoard': true},
      () => controller.refund(
        canEditBoard: true,
        selectedPoint: t.gridPoint,
        turrets: turrets,
        enemies: [],
        gemInventory: inventory,
        gold: gold,
        gemShards: shards,
        levelUpPreviewPoint: null,
      ),
    );
  }
  return {'schemaVersion': 1, 'cases': cases};
}

Map<String, Object?> progressionDerived(RunProgression p) => {
  'bossBountyUpgradeCost': p.bossBountyUpgradeCost,
  'bossBountyBonusRate': p.bossBountyBonusRate,
  'canUpgradeBossBounty': p.canUpgradeBossBounty,
  'initialGold': p.initialGold,
  'maxNexusHp': p.maxNexusHp,
  'startingGoldUpgradeCost': p.startingGoldUpgradeCost,
  'nexusHpUpgradeCost': p.nexusHpUpgradeCost,
  'supplyUpgradeCost': p.supplyUpgradeCost,
  'fireTrainingUpgradeCost': p.fireTrainingUpgradeCost,
  'physicalDamageTrainingUpgradeCost': p.physicalDamageTrainingUpgradeCost,
  'elementalDamageTrainingUpgradeCost': p.elementalDamageTrainingUpgradeCost,
  'criticalChanceUpgradeCost': p.criticalChanceUpgradeCost,
  'criticalDamageUpgradeCost': p.criticalDamageUpgradeCost,
  'killGoldUpgradeCost': p.killGoldUpgradeCost,
  'emergencySaleUpgradeCost': p.emergencySaleUpgradeCost,
  'linkCostOptimizationUpgradeCost': p.linkCostOptimizationUpgradeCost,
  'turretLevelUpOptimizationUpgradeCost':
      p.turretLevelUpOptimizationUpgradeCost,
  'waveClearGoldBonus': p.waveClearGoldBonus,
  'fireTrainingDamageBonusRate': p.fireTrainingDamageBonusRate,
  'physicalDamageTrainingBonusRate': p.physicalDamageTrainingBonusRate,
  'elementalDamageTrainingBonusRate': p.elementalDamageTrainingBonusRate,
  'criticalChanceBonusRate': p.criticalChanceBonusRate,
  'criticalDamageBonusRate': p.criticalDamageBonusRate,
  'killGoldBonusRate': p.killGoldBonusRate,
  'turretRefundPercent': p.turretRefundPercent,
  'permanentLinkCostMultiplier': p.permanentLinkCostMultiplier,
  'permanentTurretLevelUpCostMultiplier':
      p.permanentTurretLevelUpCostMultiplier,
  'canUpgradeStartingGold': p.canUpgradeStartingGold,
  'canUpgradeNexusHp': p.canUpgradeNexusHp,
  'canUpgradeSupply': p.canUpgradeSupply,
  'canUpgradeFireTraining': p.canUpgradeFireTraining,
  'canUpgradePhysicalDamageTraining': p.canUpgradePhysicalDamageTraining,
  'canUpgradeElementalDamageTraining': p.canUpgradeElementalDamageTraining,
  'canUpgradeCriticalChance': p.canUpgradeCriticalChance,
  'canUpgradeCriticalDamage': p.canUpgradeCriticalDamage,
  'canUpgradeKillGold': p.canUpgradeKillGold,
  'canUpgradeEmergencySale': p.canUpgradeEmergencySale,
  'canUpgradeLinkCostOptimization': p.canUpgradeLinkCostOptimization,
  'canUpgradeTurretLevelUpOptimization': p.canUpgradeTurretLevelUpOptimization,
  'startingGemShards': p.startingGemShards,
  'maxTurretLinkSlots': p.maxTurretLinkSlots,
  'canSetTurretTargetPriority': p.canSetTurretTargetPriority,
  'availableResearchSlotCount': p.availableResearchSlotCount,
  'researchSlotTwoPurchaseUnlocked': p.researchSlotTwoPurchaseUnlocked,
  'canUnlockResearchSlotTwo': p.canUnlockResearchSlotTwo,
  'researchEfficiencyRate': p.researchEfficiencyRate,
  'researchCostEfficiencyRate': p.researchCostEfficiencyRate,
  'firstLinkUpgradeDiscountRate': p.firstLinkUpgradeDiscountRate,
  'bossKillGemShardBonus': p.bossKillGemShardBonus,
  'runeResonanceBonusRate': p.runeResonanceBonusRate,
  'runUpgradeCostMultiplier': p.runUpgradeCostMultiplier,
};
Map<String, Object?> exportProgressionCases() {
  final cases = <Object?>[];
  for (final level in [
    0,
    1,
    RunProgression.maxBossBountyUpgradeLevel - 1,
    RunProgression.maxBossBountyUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..bossBountyUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeBossBounty();
      cases.add({
        'name': 'bossBounty_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'bossBounty'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxStartingGoldUpgradeLevel - 1,
    RunProgression.maxStartingGoldUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..startingGoldUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeStartingGold();
      cases.add({
        'name': 'startingGold_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'startingGold'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxNexusHpUpgradeLevel - 1,
    RunProgression.maxNexusHpUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..nexusHpUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeNexusHp();
      cases.add({
        'name': 'nexusHp_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'nexusHp'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxSupplyUpgradeLevel - 1,
    RunProgression.maxSupplyUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..supplyUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeSupply();
      cases.add({
        'name': 'supply_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'supply'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxFireTrainingUpgradeLevel - 1,
    RunProgression.maxFireTrainingUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..fireTrainingUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeFireTraining();
      cases.add({
        'name': 'fireTraining_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'fireTraining'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxPhysicalDamageTrainingUpgradeLevel - 1,
    RunProgression.maxPhysicalDamageTrainingUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..physicalDamageTrainingUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradePhysicalDamageTraining();
      cases.add({
        'name': 'physicalDamageTraining_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {
          'kind': 'permanentUpgrade',
          'type': 'physicalDamageTraining',
        },
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxElementalDamageTrainingUpgradeLevel - 1,
    RunProgression.maxElementalDamageTrainingUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..elementalDamageTrainingUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeElementalDamageTraining();
      cases.add({
        'name': 'elementalDamageTraining_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {
          'kind': 'permanentUpgrade',
          'type': 'elementalDamageTraining',
        },
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxCriticalChanceUpgradeLevel - 1,
    RunProgression.maxCriticalChanceUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..criticalChanceUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeCriticalChance();
      cases.add({
        'name': 'criticalChance_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'criticalChance'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxCriticalDamageUpgradeLevel - 1,
    RunProgression.maxCriticalDamageUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..criticalDamageUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeCriticalDamage();
      cases.add({
        'name': 'criticalDamage_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'criticalDamage'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxKillGoldUpgradeLevel - 1,
    RunProgression.maxKillGoldUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..killGoldUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeKillGold();
      cases.add({
        'name': 'killGold_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'killGold'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxEmergencySaleUpgradeLevel - 1,
    RunProgression.maxEmergencySaleUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..emergencySaleUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeEmergencySale();
      cases.add({
        'name': 'emergencySale_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'emergencySale'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxLinkCostOptimizationUpgradeLevel - 1,
    RunProgression.maxLinkCostOptimizationUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..linkCostOptimizationUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeLinkCostOptimization();
      cases.add({
        'name': 'linkCostOptimization_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {'kind': 'permanentUpgrade', 'type': 'linkCostOptimization'},
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final level in [
    0,
    1,
    RunProgression.maxTurretLevelUpOptimizationUpgradeLevel - 1,
    RunProgression.maxTurretLevelUpOptimizationUpgradeLevel,
  ]) {
    for (final runes in [0, 100000000]) {
      final p = RunProgression()
        ..turretLevelUpOptimizationUpgradeLevel = level
        ..runes = runes;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.upgradeTurretLevelUpOptimization();
      cases.add({
        'name': 'turretLevelUpOptimization_${level}_$runes',
        'before': before,
        'derived': derived,
        'command': {
          'kind': 'permanentUpgrade',
          'type': 'turretLevelUpOptimization',
        },
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  for (final type in gameResearchDefinitions.keys) {
    final def = gameResearchDefinitions[type]!;
    for (final level in [0, def.maxLevel]) {
      final p = RunProgression()..runes = 100000000;
      p.clearedStageNumbers.addAll(List.generate(15, (i) => i + 1));
      p.researchLevels[type] = level;
      final before = p.toSaveData().toJson();
      final derived = progressionDerived(p);
      final ok = p.startResearch(type, nowMillis: 1000000);
      cases.add({
        'name': 'research_${type.name}_$level',
        'before': before,
        'derived': derived,
        'command': {
          'kind': 'startResearch',
          'type': type.name,
          'nowMillis': 1000000,
        },
        'ok': ok,
        'after': p.toSaveData().toJson(),
        'afterDerived': progressionDerived(p),
      });
    }
  }
  return {'schemaVersion': 1, 'cases': cases};
}
