import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_core_passive_tree_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/core/core_passive_tree.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test('core passive graph contains the complete valid catalog', () {
    expect(corePassiveNodeDefinitions, hasLength(27));
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

  test('one rank-three branch opens a hybrid node', () {
    final oneSideReady = <CorePassiveNodeId, int>{
      CorePassiveNodeId.attackHaste: 3,
    };
    expect(
      accessibleCorePassiveNodeIds(oneSideReady),
      contains(CorePassiveNodeId.hybridEmergencyCompute),
    );

    final bothBelowThreshold = <CorePassiveNodeId, int>{
      CorePassiveNodeId.attackHaste: 2,
      CorePassiveNodeId.controlThreatSense: 2,
    };
    expect(
      accessibleCorePassiveNodeIds(bothBelowThreshold),
      isNot(contains(CorePassiveNodeId.hybridEmergencyCompute)),
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
      progression.setCorePassiveNodeRank(
        CorePassiveNodeId.hybridEmergencyCompute,
        1,
      ),
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
      progression.corePassiveNodeRank(CorePassiveNodeId.hybridEmergencyCompute),
      1,
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
