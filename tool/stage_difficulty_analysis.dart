import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/data/definitions/game_research_data.dart';
import 'package:rune_nexus/data/definitions/game_stage_data.dart';
import 'package:rune_nexus/domain/enemy/enemy_scaling.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

// 실행:
// C:\Users\rlatp\develop\flutter\bin\flutter.bat test tool/stage_difficulty_analysis.dart --reporter expanded
void main() {
  test('stage difficulty analysis', () {
    final report = StageDifficultyAnalyzer().buildReport();
    // ignore: avoid_print
    print(report);
  });
}

class StageDifficultyAnalyzer {
  StageDifficultyAnalyzer({this.model = const StageDifficultyModel()});

  final StageDifficultyModel model;

  String buildReport() {
    final base = _stageTotals(1);
    final basePowerValue = RunProgression.baseInitialGold + base.rawGold;
    final rows = <StageDifficultyRow>[];

    var cumulativeRunesBeforeStage = 0;
    var previousNetDifficulty = 1.0;

    for (final stage in gameStages) {
      final totals = _stageTotals(stage.id);
      final profile = _greedyUpgradeProfile(
        cumulativeRunesBeforeStage,
        targetStage: stage.id,
      );
      final goldValue = _modeledGoldValue(totals, profile, stage.id);
      final damageMultiplier = _modeledDamageMultiplier(profile);
      final modeledPowerRatio = goldValue / basePowerValue * damageMultiplier;
      final durabilityRatio = totals.durability / base.durability;
      final netDifficulty = durabilityRatio / modeledPowerRatio;
      final stepDifficulty = stage.id == 1
          ? 1.0
          : netDifficulty / previousNetDifficulty;

      rows.add(
        StageDifficultyRow(
          stage: stage.id,
          stageHpMultiplier: enemyHpMultiplierForStage(stage.id),
          durabilityRatio: durabilityRatio,
          rawGoldRatio: totals.rawGold / base.rawGold,
          cumulativeRunesBeforeStage: cumulativeRunesBeforeStage,
          modeledGoldRatio: goldValue / basePowerValue,
          modeledDamageMultiplier: damageMultiplier,
          modeledPowerRatio: modeledPowerRatio,
          netDifficultyRatio: netDifficulty,
          stepDifficultyRatio: stepDifficulty,
          upgradeProfile: profile,
          enemyCounts: totals.enemyCounts,
        ),
      );

      previousNetDifficulty = netDifficulty;
      cumulativeRunesBeforeStage += _fullClearRuneReward(stage.id);
    }

    return _formatReport(rows);
  }

  StageTotals _stageTotals(int stageNumber) {
    final stage = gameStages[stageNumber - 1];
    var durability = 0.0;
    var rawGold = 0.0;
    var killGold = 0.0;
    var clearGold = 0.0;
    var bossGold = 0.0;
    final enemyCounts = <EnemyType, int>{
      for (final type in EnemyType.values) type: 0,
    };

    for (final wave in stage.waves) {
      clearGold += wave.clearRewardGold;
      rawGold += wave.clearRewardGold;

      for (final group in wave.groups) {
        final enemy = gameEnemies[group.enemyType]!;
        final scaledDurability =
            scaledEnemyMaxHp(enemy, wave.round, stageNumber: stageNumber) +
            scaledEnemyMaxArmor(enemy, wave.round, stageNumber: stageNumber) +
            scaledEnemyMaxShield(enemy, wave.round, stageNumber: stageNumber);

        durability += scaledDurability * group.count;
        final rewardGold = enemy.rewardGold * group.count;
        rawGold += rewardGold;
        killGold += rewardGold;
        if (group.enemyType == EnemyType.boss) {
          bossGold += rewardGold;
        }
        enemyCounts[group.enemyType] =
            (enemyCounts[group.enemyType] ?? 0) + group.count;
      }
    }

    return StageTotals(
      durability: durability,
      rawGold: rawGold,
      killGold: killGold,
      clearGold: clearGold,
      bossGold: bossGold,
      enemyCounts: enemyCounts,
    );
  }

  UpgradeProfile _greedyUpgradeProfile(int runes, {required int targetStage}) {
    final profile = UpgradeProfile();

    while (true) {
      final candidates = <UpgradeCandidate>[
        if (profile.startingGoldLevel <
            RunProgression.maxStartingGoldUpgradeLevel)
          UpgradeCandidate(
            key: UpgradeKey.startingGold,
            cost: _hybridCost(
              baseCost: RunProgression.startingGoldUpgradeBaseCost,
              costPerLevel: RunProgression.startingGoldUpgradeCostPerLevel,
              multiplier: RunProgression.startingGoldUpgradeCostMultiplier,
              level: profile.startingGoldLevel,
            ),
            modeledValue: model.startingGoldValuePerLevel,
          ),
        if (profile.supplyLevel < RunProgression.maxSupplyUpgradeLevel)
          UpgradeCandidate(
            key: UpgradeKey.supply,
            cost: _hybridCost(
              baseCost: RunProgression.supplyUpgradeBaseCost,
              costPerLevel: RunProgression.supplyUpgradeCostPerLevel,
              multiplier: RunProgression.supplyUpgradeCostMultiplier,
              level: profile.supplyLevel,
            ),
            modeledValue: model.supplyValuePerLevel,
          ),
        if (profile.fireTrainingLevel <
            RunProgression.maxFireTrainingUpgradeLevel)
          UpgradeCandidate(
            key: UpgradeKey.fireTraining,
            cost: _hybridCost(
              baseCost: RunProgression.fireTrainingUpgradeBaseCost,
              costPerLevel: RunProgression.fireTrainingUpgradeCostPerLevel,
              multiplier: RunProgression.fireTrainingUpgradeCostMultiplier,
              level: profile.fireTrainingLevel,
            ),
            modeledValue:
                RunProgression.fireTrainingDamagePerUpgradeLevel *
                model.referenceGoldValue,
          ),
        if (targetStage >= 3 &&
            profile.killGoldLevel < RunProgression.maxKillGoldUpgradeLevel)
          UpgradeCandidate(
            key: UpgradeKey.killGold,
            cost: _hybridCost(
              baseCost: RunProgression.killGoldUpgradeBaseCost,
              costPerLevel: RunProgression.killGoldUpgradeCostPerLevel,
              multiplier: RunProgression.killGoldUpgradeCostMultiplier,
              level: profile.killGoldLevel,
            ),
            modeledValue:
                RunProgression.killGoldBonusPerUpgradeLevel *
                model.referenceKillGold,
          ),
        if (targetStage >= 5 &&
            profile.criticalChanceLevel <
                RunProgression.maxCriticalChanceUpgradeLevel)
          UpgradeCandidate(
            key: UpgradeKey.criticalChance,
            cost: _exponentialCost(
              baseCost: RunProgression.criticalChanceUpgradeBaseCost,
              multiplier: RunProgression.criticalChanceUpgradeCostMultiplier,
              level: profile.criticalChanceLevel,
            ),
            modeledValue:
                RunProgression.criticalChanceBonusPerUpgradeLevel *
                model.baseCriticalExtraDamage *
                model.referenceGoldValue,
          ),
        if (targetStage >= 5 &&
            profile.criticalDamageLevel <
                RunProgression.maxCriticalDamageUpgradeLevel)
          UpgradeCandidate(
            key: UpgradeKey.criticalDamage,
            cost: _exponentialCost(
              baseCost: RunProgression.criticalDamageUpgradeBaseCost,
              multiplier: RunProgression.criticalDamageUpgradeCostMultiplier,
              level: profile.criticalDamageLevel,
            ),
            modeledValue:
                profile.criticalChanceLevel *
                RunProgression.criticalChanceBonusPerUpgradeLevel *
                RunProgression.criticalDamageBonusPerUpgradeLevel *
                model.referenceGoldValue,
          ),
        if (profile.bossBountyLevel <
            gameResearchDefinitions[ResearchType.bossBounty]!.maxLevel)
          UpgradeCandidate(
            key: UpgradeKey.bossBounty,
            cost: _researchCost(
              ResearchType.bossBounty,
              profile.bossBountyLevel,
            ),
            modeledValue:
                RunProgression.bossBountyBonusPerLevel *
                model.referenceBossGold,
          ),
        if (profile.linkMaintenanceLevel <
            gameResearchDefinitions[ResearchType.linkMaintenance]!.maxLevel)
          UpgradeCandidate(
            key: UpgradeKey.linkMaintenance,
            cost: _researchCost(
              ResearchType.linkMaintenance,
              profile.linkMaintenanceLevel,
            ),
            modeledValue:
                RunProgression.linkMaintenanceDiscountPerLevel *
                model.referenceFirstLinkSpend,
          ),
      ]..removeWhere((candidate) => candidate.cost > runes);

      if (candidates.isEmpty) {
        break;
      }

      candidates.sort(
        (left, right) => right.valuePerRune.compareTo(left.valuePerRune),
      );
      final selected = candidates.first;
      runes -= selected.cost;
      profile.apply(selected.key);
    }

    return profile;
  }

  double _modeledGoldValue(
    StageTotals totals,
    UpgradeProfile profile,
    int stageNumber,
  ) {
    final startingGold =
        RunProgression.baseInitialGold +
        profile.startingGoldLevel * RunProgression.startingGoldPerUpgradeLevel;
    final supplyGold = profile.supplyLevel * model.supplyValuePerLevel;
    final killGoldRate = stageNumber >= 3
        ? profile.killGoldLevel * RunProgression.killGoldBonusPerUpgradeLevel
        : 0.0;
    final bossBountyRate =
        profile.bossBountyLevel * RunProgression.bossBountyBonusPerLevel;
    final normalKillGold = totals.killGold - totals.bossGold;
    final bonusKillGold =
        normalKillGold * killGoldRate +
        totals.bossGold * (killGoldRate + bossBountyRate);
    final linkSavings =
        profile.linkMaintenanceLevel *
        RunProgression.linkMaintenanceDiscountPerLevel *
        model.referenceFirstLinkSpend;

    return startingGold +
        totals.rawGold +
        supplyGold +
        bonusKillGold +
        linkSavings;
  }

  double _modeledDamageMultiplier(UpgradeProfile profile) {
    final fireTraining =
        profile.fireTrainingLevel *
        RunProgression.fireTrainingDamagePerUpgradeLevel;
    final criticalChance =
        profile.criticalChanceLevel *
        RunProgression.criticalChanceBonusPerUpgradeLevel;
    final criticalExtraDamage =
        model.baseCriticalExtraDamage +
        profile.criticalDamageLevel *
            RunProgression.criticalDamageBonusPerUpgradeLevel;

    return (1 + fireTraining) * (1 + criticalChance * criticalExtraDamage);
  }

  String _formatReport(List<StageDifficultyRow> rows) {
    final buffer = StringBuffer()
      ..writeln('Stage Difficulty Analysis')
      ..writeln()
      ..writeln('Assumptions')
      ..writeln('- Durability = scaled HP + scaled armor + scaled shield.')
      ..writeln('- Power = modeled gold value * permanent damage multiplier.')
      ..writeln(
        '- Good gems are assumed to be selected correctly for the carry plan.',
      )
      ..writeln('- Rune budget assumes one full clear of each previous stage.')
      ..writeln(
        '- Gem RNG, map pathing, overkill, shield regen, armor reduction,',
      )
      ..writeln(
        '  target switching loss, and actual play sequencing are not simulated.',
      )
      ..writeln()
      ..writeln(
        'stage | hpMul | durability | rawGold | runesBefore | gold | damage | power | net | step',
      )
      ..writeln(
        '---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:',
      );

    for (final row in rows) {
      buffer.writeln(
        [
          row.stage,
          _fixed(row.stageHpMultiplier),
          '${_fixed(row.durabilityRatio)}x',
          '${_fixed(row.rawGoldRatio)}x',
          row.cumulativeRunesBeforeStage,
          '${_fixed(row.modeledGoldRatio)}x',
          '${_fixed(row.modeledDamageMultiplier)}x',
          '${_fixed(row.modeledPowerRatio)}x',
          '${_fixed(row.netDifficultyRatio)}x',
          '${_fixed(row.stepDifficultyRatio)}x',
        ].join(' | '),
      );
    }

    _writeGemAndRuneScenarios(buffer, rows);

    buffer
      ..writeln()
      ..writeln('Upgrade Profile Before Stage')
      ..writeln(
        'stage | startGold | supply | fire | killGold | critChance | critDamage | bossBounty | linkMaint',
      )
      ..writeln('---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:');

    for (final row in rows) {
      final profile = row.upgradeProfile;
      buffer.writeln(
        [
          row.stage,
          profile.startingGoldLevel,
          profile.supplyLevel,
          profile.fireTrainingLevel,
          profile.killGoldLevel,
          profile.criticalChanceLevel,
          profile.criticalDamageLevel,
          profile.bossBountyLevel,
          profile.linkMaintenanceLevel,
        ].join(' | '),
      );
    }

    buffer
      ..writeln()
      ..writeln('Enemy Counts')
      ..writeln('stage | normal | armored | shielded | fast | tank | boss')
      ..writeln('---: | ---: | ---: | ---: | ---: | ---: | ---:');

    for (final row in rows) {
      buffer.writeln(
        [
          row.stage,
          row.enemyCounts[EnemyType.normal] ?? 0,
          row.enemyCounts[EnemyType.armored] ?? 0,
          row.enemyCounts[EnemyType.shielded] ?? 0,
          row.enemyCounts[EnemyType.fast] ?? 0,
          row.enemyCounts[EnemyType.tank] ?? 0,
          row.enemyCounts[EnemyType.boss] ?? 0,
        ].join(' | '),
      );
    }

    return buffer.toString();
  }

  void _writeGemAndRuneScenarios(
    StringBuffer buffer,
    List<StageDifficultyRow> rows,
  ) {
    final base = _stageTotals(1);
    final basePowerValue = RunProgression.baseInitialGold + base.rawGold;
    final previousNetByGemCount = <int, double>{};

    buffer
      ..writeln()
      ..writeln('Gem And Rune Simplified Scenarios')
      ..writeln('- gemN = net difficulty after N well-matched carry gems.')
      ..writeln(
        '- reqRuneN = extra runes needed to keep step <= ${_fixed(model.targetStepDifficulty)}x',
      )
      ..writeln(
        '  and net difficulty <= ${_fixed(model.targetNetDifficulty)}x.',
      )
      ..writeln('stage | gem0 | gem1 | gem2 | gem3 | reqRune0 | reqRune3')
      ..writeln('---: | ---: | ---: | ---: | ---: | ---: | ---:');

    for (final row in rows) {
      final gemNetDifficulties = <int, double>{};
      for (final gemCount in model.gemScenarioCounts) {
        final gemNetDifficulty =
            row.netDifficultyRatio / _gemPowerMultiplier(gemCount);
        gemNetDifficulties[gemCount] = gemNetDifficulty;
      }

      final requiredRunesNoGem = _requiredAdditionalRunes(
        row: row,
        gemCount: 0,
        previousNetDifficulty: previousNetByGemCount[0],
        base: base,
        basePowerValue: basePowerValue,
      );
      final requiredRunesThreeGems = _requiredAdditionalRunes(
        row: row,
        gemCount: 3,
        previousNetDifficulty: previousNetByGemCount[3],
        base: base,
        basePowerValue: basePowerValue,
      );

      buffer.writeln(
        [
          row.stage,
          '${_fixed(gemNetDifficulties[0]!)}x',
          '${_fixed(gemNetDifficulties[1]!)}x',
          '${_fixed(gemNetDifficulties[2]!)}x',
          '${_fixed(gemNetDifficulties[3]!)}x',
          _formatRequiredRunes(requiredRunesNoGem),
          _formatRequiredRunes(requiredRunesThreeGems),
        ].join(' | '),
      );

      for (final entry in gemNetDifficulties.entries) {
        previousNetByGemCount[entry.key] = entry.value;
      }
    }
  }

  int? _requiredAdditionalRunes({
    required StageDifficultyRow row,
    required int gemCount,
    required double? previousNetDifficulty,
    required StageTotals base,
    required double basePowerValue,
  }) {
    if (row.stage == 1 || previousNetDifficulty == null) {
      return 0;
    }

    final targetNetDifficulty = math.min(
      previousNetDifficulty * model.targetStepDifficulty,
      model.targetNetDifficulty,
    );
    final totals = _stageTotals(row.stage);

    for (
      var extraRunes = 0;
      extraRunes <= model.requiredRuneSearchLimit;
      extraRunes += model.requiredRuneSearchStep
    ) {
      final profile = _greedyUpgradeProfile(
        row.cumulativeRunesBeforeStage + extraRunes,
        targetStage: row.stage,
      );
      final goldValue = _modeledGoldValue(totals, profile, row.stage);
      final damageMultiplier = _modeledDamageMultiplier(profile);
      final powerRatio =
          goldValue /
          basePowerValue *
          damageMultiplier *
          _gemPowerMultiplier(gemCount);
      final netDifficulty = totals.durability / base.durability / powerRatio;

      if (netDifficulty <= targetNetDifficulty) {
        return extraRunes;
      }
    }

    return null;
  }

  int _fullClearRuneReward(int stageNumber) {
    final stageMultiplier =
        1 + RunProgression.stageRuneRewardBonusRateFor(stageNumber);
    return (RunProgression.baseStageOneFullClearRuneReward * stageMultiplier)
        .round();
  }

  int _hybridCost({
    required int baseCost,
    required int costPerLevel,
    required double multiplier,
    required int level,
  }) {
    final linearCost = baseCost + costPerLevel * level;
    return math.max(1, (linearCost * math.pow(multiplier, level)).round());
  }

  int _exponentialCost({
    required int baseCost,
    required double multiplier,
    required int level,
  }) {
    return (baseCost * math.pow(multiplier, level)).round();
  }

  int _researchCost(ResearchType type, int level) {
    final definition = gameResearchDefinitions[type]!;
    return (definition.baseRuneCost *
            math.pow(definition.costMultiplier, level))
        .round();
  }

  String _fixed(double value) => value.toStringAsFixed(3);

  double _gemPowerMultiplier(int gemCount) {
    final carryGemMultiplier = math
        .pow(1 + model.goodGemPowerPerGem, gemCount)
        .toDouble();
    return 1 + model.carryPowerShare * (carryGemMultiplier - 1);
  }

  String _formatRequiredRunes(int? runes) {
    if (runes == null) {
      return '>${model.requiredRuneSearchLimit}';
    }
    return runes.toString();
  }
}

class StageDifficultyModel {
  const StageDifficultyModel({
    this.supplyValuePerLevel = 50,
    this.startingGoldValuePerLevel = 10,
    this.referenceGoldValue = 4000,
    this.referenceKillGold = 1800,
    this.referenceBossGold = 175,
    this.referenceFirstLinkSpend = 500,
    this.baseCriticalExtraDamage = 0.5,
    this.goodGemPowerPerGem = 0.35,
    this.carryPowerShare = 0.75,
    this.targetStepDifficulty = 1.20,
    this.targetNetDifficulty = 2.00,
    this.requiredRuneSearchLimit = 5000,
    this.requiredRuneSearchStep = 50,
    this.gemScenarioCounts = const [0, 1, 2, 3],
  });

  final double supplyValuePerLevel;
  final double startingGoldValuePerLevel;
  final double referenceGoldValue;
  final double referenceKillGold;
  final double referenceBossGold;
  final double referenceFirstLinkSpend;
  final double baseCriticalExtraDamage;
  final double goodGemPowerPerGem;
  final double carryPowerShare;
  final double targetStepDifficulty;
  final double targetNetDifficulty;
  final int requiredRuneSearchLimit;
  final int requiredRuneSearchStep;
  final List<int> gemScenarioCounts;
}

class StageTotals {
  const StageTotals({
    required this.durability,
    required this.rawGold,
    required this.killGold,
    required this.clearGold,
    required this.bossGold,
    required this.enemyCounts,
  });

  final double durability;
  final double rawGold;
  final double killGold;
  final double clearGold;
  final double bossGold;
  final Map<EnemyType, int> enemyCounts;
}

class StageDifficultyRow {
  const StageDifficultyRow({
    required this.stage,
    required this.stageHpMultiplier,
    required this.durabilityRatio,
    required this.rawGoldRatio,
    required this.cumulativeRunesBeforeStage,
    required this.modeledGoldRatio,
    required this.modeledDamageMultiplier,
    required this.modeledPowerRatio,
    required this.netDifficultyRatio,
    required this.stepDifficultyRatio,
    required this.upgradeProfile,
    required this.enemyCounts,
  });

  final int stage;
  final double stageHpMultiplier;
  final double durabilityRatio;
  final double rawGoldRatio;
  final int cumulativeRunesBeforeStage;
  final double modeledGoldRatio;
  final double modeledDamageMultiplier;
  final double modeledPowerRatio;
  final double netDifficultyRatio;
  final double stepDifficultyRatio;
  final UpgradeProfile upgradeProfile;
  final Map<EnemyType, int> enemyCounts;
}

class UpgradeProfile {
  int startingGoldLevel = 0;
  int supplyLevel = 0;
  int fireTrainingLevel = 0;
  int killGoldLevel = 0;
  int criticalChanceLevel = 0;
  int criticalDamageLevel = 0;
  int bossBountyLevel = 0;
  int linkMaintenanceLevel = 0;

  void apply(UpgradeKey key) {
    switch (key) {
      case UpgradeKey.startingGold:
        startingGoldLevel++;
      case UpgradeKey.supply:
        supplyLevel++;
      case UpgradeKey.fireTraining:
        fireTrainingLevel++;
      case UpgradeKey.killGold:
        killGoldLevel++;
      case UpgradeKey.criticalChance:
        criticalChanceLevel++;
      case UpgradeKey.criticalDamage:
        criticalDamageLevel++;
      case UpgradeKey.bossBounty:
        bossBountyLevel++;
      case UpgradeKey.linkMaintenance:
        linkMaintenanceLevel++;
    }
  }
}

class UpgradeCandidate {
  const UpgradeCandidate({
    required this.key,
    required this.cost,
    required this.modeledValue,
  });

  final UpgradeKey key;
  final int cost;
  final double modeledValue;

  double get valuePerRune => modeledValue / cost;
}

enum UpgradeKey {
  startingGold,
  supply,
  fireTraining,
  killGold,
  criticalChance,
  criticalDamage,
  bossBounty,
  linkMaintenance,
}
