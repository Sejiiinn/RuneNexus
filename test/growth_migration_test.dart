import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_research_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test('legacy charged boss receipt applies once after migration', () {
    final progression = RunProgression()..bossBountyUpgradeLevel = 7;
    expect(
      progression.applyResearchCompletionEffect(ResearchType.bossBounty, 8),
      isTrue,
    );
    expect(progression.bossBountyUpgradeLevel, 8);
    expect(
      progression.applyResearchCompletionEffect(ResearchType.bossBounty, 8),
      isFalse,
    );
    progression.bossBountyUpgradeLevel = 25;
    expect(
      progression.applyResearchCompletionEffect(ResearchType.bossBounty, 8),
      isFalse,
    );
    expect(progression.bossBountyUpgradeLevel, 25);
    expect(
      progression.researchLevels.containsKey(ResearchType.bossBounty),
      isFalse,
    );
  });
  test(
    'legacy critical ranks round up once without refunds or duplicate effects',
    () {
      for (final level in [0, 1, 2, 3, 19, 20, 99]) {
        final old = SavedProgression.fromJson({
          'runes': 123,
          'criticalChanceUpgradeLevel': level,
          'emergencySaleUpgradeLevel': 5,
          'researchLevels': {'bossBounty': 20, 'runeResonance': 17},
        });
        final progression = RunProgression()..restoreFromSaveData(old);
        final expectedRank = (level.clamp(0, 20) + 1) ~/ 2;
        expect(
          progression.researchLevel(ResearchType.criticalChance),
          expectedRank,
        );
        expect(
          progression.criticalChanceBonusRate,
          closeTo(expectedRank * .02, 1e-9),
        );
        expect(progression.turretRefundPercent, 80);
        expect(progression.bossBountyUpgradeLevel, 20);
        expect(progression.runeResonanceBonusRate, closeTo(.34, 1e-9));
        expect(progression.runes, 123);
        final json = progression.toSaveData().toJson();
        expect(json['growthVersion'], 1);
        expect(json.containsKey('criticalChanceUpgradeLevel'), isFalse);
        expect(json.containsKey('emergencySaleUpgradeLevel'), isFalse);
        expect(
          (json['researchLevels'] as Map).containsKey('bossBounty'),
          isFalse,
        );
        for (var repeat = 0; repeat < 3; repeat++) {
          progression.restoreFromSaveData(SavedProgression.fromJson(json));
          expect(progression.toSaveData().toJson(), json);
        }
      }
    },
  );

  test(
    'paid active boss target is granted while other research remains intact',
    () {
      final progression = RunProgression()
        ..restoreFromSaveData(
          SavedProgression.fromJson({
            'runes': 77,
            'researchLevels': {'bossBounty': 8, 'researchEfficiency': 2},
            'researchElapsedMillis': {'bossBounty': 12000},
            'activeResearches': [
              {
                'type': 'bossBounty',
                'targetLevel': 9,
                'startedAtMillis': 1000,
                'durationMillis': 9999999,
              },
              {
                'type': 'researchEfficiency',
                'targetLevel': 3,
                'startedAtMillis': 1000,
                'durationMillis': 300000,
                'initialElapsedMillis': 500,
              },
            ],
            'researchSlotTwoUnlocked': true,
          }),
        );
      expect(progression.bossBountyUpgradeLevel, 9);
      expect(progression.bossBountyBonusRate, closeTo(.225, 1e-9));
      expect(progression.runes, 77);
      expect(
        progression.researchElapsedMillis.containsKey(ResearchType.bossBounty),
        isFalse,
      );
      expect(
        progression.activeResearches.single.type,
        ResearchType.researchEfficiency,
      );
      expect(progression.activeResearches.single.initialElapsedMillis, 500);
      final restored = RunProgression()
        ..restoreFromSaveData(progression.toSaveData());
      expect(restored.bossBountyUpgradeLevel, 9);
      expect(restored.activeResearches.single.durationMillis, 300000);
    },
  );

  test(
    'critical research exactly combines former costs and uses usual discounts',
    () {
      final progression = RunProgression()..runes = 100000;
      expect(
        progression.isResearchUnlocked(ResearchType.criticalChance),
        isFalse,
      );
      progression.clearedStageNumbers.add(4);
      expect(
        progression.isResearchUnlocked(ResearchType.criticalChance),
        isTrue,
      );
      for (var rank = 0; rank < 10; rank++) {
        progression.researchLevels[ResearchType.criticalChance] = rank;
        final expected =
            (70 * math.pow(1.2, rank * 2)).round() +
            (70 * math.pow(1.2, rank * 2 + 1)).round();
        expect(
          progression.researchCostForCurrentLevel(ResearchType.criticalChance),
          expected,
        );
        progression.researchLevels[ResearchType.researchCostEfficiency] = 20;
        expect(
          progression.researchCostForCurrentLevel(ResearchType.criticalChance),
          (expected / 2).round(),
        );
        progression.researchLevels.remove(ResearchType.researchCostEfficiency);
      }
      expect(
        gameResearchDefinitions[ResearchType.criticalChance]!.maxLevel,
        10,
      );
    },
  );

  test('expanded caps keep old per-level effects and boss purchase cap', () {
    final progression = RunProgression()
      ..startingGoldUpgradeLevel = 50
      ..nexusHpUpgradeLevel = 30
      ..physicalDamageTrainingUpgradeLevel = 50
      ..elementalDamageTrainingUpgradeLevel = 50
      ..criticalDamageUpgradeLevel = 50
      ..linkCostOptimizationUpgradeLevel = 30
      ..turretLevelUpOptimizationUpgradeLevel = 30
      ..runes = 1000000;
    expect(progression.initialGold, 670);
    expect(progression.maxNexusHp, 50);
    expect(progression.physicalDamageTrainingBonusRate, 1);
    expect(progression.elementalDamageTrainingBonusRate, 1);
    expect(progression.criticalDamageBonusRate, .5);
    expect(progression.permanentLinkCostMultiplier, .7);
    expect(progression.permanentTurretLevelUpCostMultiplier, .7);
    for (var level = 0; level < 40; level++) {
      expect(
        progression.bossBountyUpgradeCost,
        (30 * math.pow(1.12, level)).round(),
      );
      expect(progression.upgradeBossBounty(), isTrue);
    }
    expect(progression.bossBountyBonusRate, 1);
    expect(progression.upgradeBossBounty(), isFalse);
  });
}
