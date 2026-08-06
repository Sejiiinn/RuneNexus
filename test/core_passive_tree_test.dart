import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/core/core_passive_tree.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test('core passive graph contains the complete valid catalog', () {
    expect(corePassiveTreeRevision, 4);
    expect(corePassiveNodeDefinitions, hasLength(21));
    expect(corePassiveStartingNodeIds, hasLength(6));
    expect(corePassiveTreeValidationErrors(), isEmpty);
    for (final definition in corePassiveNodeDefinitions.values) {
      expect(definition.rankCosts, hasLength(definition.maxRank));
      expect(definition.displayValues, hasLength(definition.maxRank));
      expect(definition.neighbors, isNot(contains(definition.id)));
      for (final neighbor in definition.neighbors) {
        expect(
          corePassiveNodeById(neighbor).neighbors,
          contains(definition.id),
        );
      }
    }
  });

  test('normal rank costs accumulate according to the shared table', () {
    expect(corePassiveCumulativeCost(CorePassiveNodeId.attackHaste, 0), 0);
    expect(corePassiveCumulativeCost(CorePassiveNodeId.attackHaste, 3), 4);
    expect(corePassiveCumulativeCost(CorePassiveNodeId.attackHaste, 5), 9);
  });

  test('attack passive rates follow the finalized balance values', () {
    const ranks = <CorePassiveNodeId, int>{
      CorePassiveNodeId.attackHaste: 5,
      CorePassiveNodeId.attackOutput: 5,
      CorePassiveNodeId.attackPrecompute: 5,
      CorePassiveNodeId.attackFocus: 5,
      CorePassiveNodeId.attackGuardianBeam: 3,
      CorePassiveNodeId.attackRiftMark: 3,
      CorePassiveNodeId.attackOverclock: 1,
    };

    expect(corePassiveAttackSyncDurationSeconds, 2);
    expect(corePassiveCooldownRecoveryRate(ranks), closeTo(0.25, 0.0001));
    expect(
      corePassiveTurretAttackRateAmplification(ranks),
      closeTo(0.15, 0.0001),
    );
    expect(corePassiveTurretDamageAmplification(ranks), closeTo(0.20, 0.0001));
    expect(
      corePassiveCoreSkillPowerMultiplier(ranks, activationNumber: 1),
      closeTo(1.5625, 0.0001),
    );
    expect(
      corePassiveCoreSkillPowerMultiplier(ranks, activationNumber: 3),
      closeTo(2.1875, 0.0001),
    );
  });

  test('defense passive rates follow the finalized balance values', () {
    const ranks = <CorePassiveNodeId, int>{
      CorePassiveNodeId.controlSelfRepair: 5,
      CorePassiveNodeId.controlRetarget: 5,
      CorePassiveNodeId.controlBufferShell: 3,
      CorePassiveNodeId.controlThreatSense: 5,
      CorePassiveNodeId.controlRearLock: 5,
      CorePassiveNodeId.controlEmergencyCharge: 3,
      CorePassiveNodeId.controlFinalLine: 1,
    };

    expect(corePassiveNexusMaxHpMultiplier(ranks), closeTo(1.25, 0.0001));
    expect(corePassiveRoundRecoveryRate(ranks), closeTo(0.03, 0.0001));
    expect(corePassiveDamageRestorationRate(ranks), closeTo(0.35, 0.0001));
    expect(
      corePassiveNexusDamageMultiplier(ranks, lostDurabilityRatio: 1),
      closeTo(0.6375, 0.0001),
    );
    expect(
      corePassiveEmergencyChargeRecoveryRate(ranks),
      closeTo(0.35, 0.0001),
    );
    expect(corePassiveHasFinalDefense(ranks), isTrue);
  });

  test(
    'efficiency passive rates and dynamic thresholds follow balance values',
    () {
      const ranks = <CorePassiveNodeId, int>{
        CorePassiveNodeId.efficiencySaving: 5,
        CorePassiveNodeId.efficiencySupplyRecovery: 5,
        CorePassiveNodeId.efficiencyFirstDeploy: 3,
        CorePassiveNodeId.efficiencyDiversity: 5,
        CorePassiveNodeId.efficiencyGemSpectrum: 5,
        CorePassiveNodeId.efficiencyFirstLink: 3,
        CorePassiveNodeId.efficiencyCombinedFront: 1,
      };

      expect(
        corePassiveTurretBuildCostMultiplier(ranks, distinctTurretTypeCount: 3),
        closeTo(0.85, 0.0001),
      );
      expect(
        corePassiveTurretBuildCostMultiplier(ranks, distinctTurretTypeCount: 4),
        closeTo(0.7225, 0.0001),
      );
      expect(corePassiveRoundClearGoldMultiplier(ranks), closeTo(1.15, 0.0001));
      expect(corePassiveTraitShardCostMultiplier(ranks), closeTo(0.76, 0.0001));
      expect(
        corePassiveTurretLevelUpCostMultiplier(
          ranks,
          distinctTurretTypeCount: 6,
        ),
        closeTo(0.748, 0.0001),
      );
      expect(
        corePassiveNumericGemEffectMultiplier(
          ranks,
          distinctEquippedGemTypeCount: 2,
        ),
        1,
      );
      expect(
        corePassiveNumericGemEffectMultiplier(
          ranks,
          distinctEquippedGemTypeCount: 3,
        ),
        closeTo(1.09, 0.0001),
      );
      expect(
        corePassiveNumericGemEffectMultiplier(
          ranks,
          distinctEquippedGemTypeCount: 4,
        ),
        closeTo(1.12, 0.0001),
      );
      expect(
        corePassiveNumericGemEffectMultiplier(
          ranks,
          distinctEquippedGemTypeCount: 8,
        ),
        closeTo(1.18, 0.0001),
      );
      expect(
        corePassiveTurretLinkCostMultiplier(ranks, distinctTurretTypeCount: 4),
        closeTo(0.714, 0.0001),
      );
    },
  );

  test('efficiency tree uses finalized grades and branch order', () {
    expect(
      corePassiveNodeById(CorePassiveNodeId.efficiencySupplyRecovery).grade,
      CorePassiveNodeGrade.normal,
    );
    expect(
      corePassiveNodeById(CorePassiveNodeId.efficiencyGemSpectrum).grade,
      CorePassiveNodeGrade.normal,
    );
    expect(
      corePassiveNodeById(CorePassiveNodeId.efficiencyFirstDeploy).grade,
      CorePassiveNodeGrade.notable,
    );
    expect(
      corePassiveNodeById(CorePassiveNodeId.efficiencyFirstLink).grade,
      CorePassiveNodeGrade.notable,
    );
    expect(
      corePassiveNodeById(CorePassiveNodeId.efficiencySaving).neighbors,
      contains(CorePassiveNodeId.efficiencySupplyRecovery),
    );
    expect(
      corePassiveNodeById(CorePassiveNodeId.efficiencyDiversity).neighbors,
      contains(CorePassiveNodeId.efficiencyGemSpectrum),
    );
  });

  test('isolated mutually supporting ranks are invalid', () {
    const isolated = <CorePassiveNodeId, int>{
      CorePassiveNodeId.attackPrecompute: 3,
      CorePassiveNodeId.attackGuardianBeam: 3,
      CorePassiveNodeId.attackOverclock: 1,
      CorePassiveNodeId.attackRiftMark: 3,
      CorePassiveNodeId.attackFocus: 3,
    };
    expect(isValidCorePassiveAllocation(isolated), isFalse);
  });

  test('rank changes are atomic and reject path-breaking refunds', () {
    final progression = RunProgression()..grantCorePoints(20);
    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackHaste, 3),
      isTrue,
    );
    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackPrecompute, 1),
      isTrue,
    );
    expect(progression.spentCorePoints, 5);
    expect(progression.availableCorePoints, 15);

    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackHaste, 2),
      isFalse,
    );
    expect(progression.corePassiveNodeRank(CorePassiveNodeId.attackHaste), 3);
    expect(
      progression.corePassiveNodeRank(CorePassiveNodeId.attackPrecompute),
      1,
    );
  });

  test('multiple connected paths are applied as one allocation', () {
    final progression = RunProgression()..grantCorePoints(20);
    const ranks = <CorePassiveNodeId, int>{
      CorePassiveNodeId.attackHaste: 3,
      CorePassiveNodeId.attackPrecompute: 2,
      CorePassiveNodeId.efficiencySaving: 3,
      CorePassiveNodeId.efficiencySupplyRecovery: 1,
    };

    expect(progression.setCorePassiveNodeRanks(ranks), isTrue);
    expect(progression.corePassiveNodeRanks, ranks);
    expect(progression.spentCorePoints, 11);
    expect(progression.availableCorePoints, 9);
    expect(progression.setCorePassiveNodeRanks(ranks), isFalse);
  });

  test('invalid batch allocations leave all existing ranks unchanged', () {
    final progression = RunProgression()..grantCorePoints(6);
    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackHaste, 3),
      isTrue,
    );
    final before = Map<CorePassiveNodeId, int>.of(
      progression.corePassiveNodeRanks,
    );

    expect(
      progression.setCorePassiveNodeRanks(const {
        CorePassiveNodeId.attackHaste: 5,
      }),
      isFalse,
    );
    expect(progression.corePassiveNodeRanks, before);

    expect(
      progression.setCorePassiveNodeRanks(const {
        CorePassiveNodeId.attackHaste: 3,
        CorePassiveNodeId.attackGuardianBeam: 1,
      }),
      isFalse,
    );
    expect(progression.corePassiveNodeRanks, before);

    expect(
      progression.setCorePassiveNodeRanks(const {
        CorePassiveNodeId.attackHaste: 6,
      }),
      isFalse,
    );
    expect(progression.corePassiveNodeRanks, before);
  });

  test('single-node rank API still delegates to atomic allocation', () {
    final progression = RunProgression()..grantCorePoints(10);

    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackHaste, 3),
      isTrue,
    );
    expect(progression.corePassiveNodeRanks, {
      CorePassiveNodeId.attackHaste: 3,
    });
    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackHaste, 3),
      isFalse,
    );
  });

  test('free reset preserves earned points', () {
    final progression = RunProgression()..grantCorePoints(20);
    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackHaste, 5),
      isTrue,
    );
    expect(progression.spentCorePoints, 9);

    expect(progression.resetCorePassiveTree(), isTrue);
    expect(progression.totalCorePoints, 20);
    expect(progression.spentCorePoints, 0);
    expect(progression.availableCorePoints, 20);
  });

  test('revision three allocation resets while preserving earned points', () {
    final saved = SavedProgression.fromJson(<String, Object?>{
      'totalCorePoints': 20,
      'corePassiveTreeRevision': 3,
      'corePassiveNodeRanks': const {
        'attackHaste': 3,
        'hybridEmergencyCompute': 1,
      },
    });
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.totalCorePoints, 20);
    expect(progression.corePassiveNodeRanks, isEmpty);
    expect(progression.availableCorePoints, 20);
  });

  test('unsafe saved ranks are sanitized before progression restore', () {
    final saved = SavedProgression.fromJson(<String, Object?>{
      'totalCorePoints': 20,
      'corePassiveTreeRevision': corePassiveTreeRevision,
      'corePassiveNodeRanks': const {
        'attackHaste': 99,
        'attackPrecompute': -2,
        'unknownNode': 3,
      },
      'claimedCorePointStageRewards': const [-1, 0, 1],
    });
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.corePassiveNodeRanks, {
      CorePassiveNodeId.attackHaste: 5,
    });
    expect(progression.claimedCorePointStageRewards, {1});
  });

  test('overspent saved allocation resets ranks but preserves earnings', () {
    final saved = SavedProgression.fromJson(<String, Object?>{
      'totalCorePoints': 2,
      'corePassiveTreeRevision': corePassiveTreeRevision,
      'corePassiveNodeRanks': const {'attackHaste': 5},
    });
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.totalCorePoints, 2);
    expect(progression.corePassiveNodeRanks, isEmpty);
  });
}
