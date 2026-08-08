import 'helpers/game_balance_test_helpers.dart';

void main() {
  test('timed research spends runes and applies effects after completion', () {
    final progression = RunProgression()
      ..runes = 1000
      ..clearedStageNumbers.addAll({1, 2, 3, 4, 5});

    expect(
      progression.startResearch(ResearchType.gemAttunement, nowMillis: 1000),
      isTrue,
    );
    expect(progression.runes, 895);
    expect(progression.researchLevel(ResearchType.gemAttunement), 0);
    expect(progression.startingGemShards, 0);
    expect(progression.activeResearches, hasLength(1));
    expect(progression.activeResearches.single.durationMillis, 3600000);

    expect(
      progression.completeFinishedResearches(nowMillis: 1000 + 3599999),
      isFalse,
    );
    expect(
      progression.completeFinishedResearches(nowMillis: 1000 + 3600000),
      isTrue,
    );
    expect(progression.researchLevel(ResearchType.gemAttunement), 1);
    expect(progression.startingGemShards, 2);
    expect(progression.activeResearches, isEmpty);

    expect(
      progression.startResearch(ResearchType.gemAttunement, nowMillis: 5000000),
      isTrue,
    );
    expect(progression.runes, 758);
    expect(progression.activeResearches.single.durationMillis, 4500000);
  });

  test('diamonds save separately and spend free balance first', () {
    final progression = RunProgression()
      ..freeDiamonds = 3
      ..paidDiamonds = 4;

    final spend = progression.spendDiamonds(5);

    expect(spend, isNotNull);
    expect(spend!.amount, 5);
    expect(spend.freeSpent, 3);
    expect(spend.paidSpent, 2);
    expect(progression.freeDiamonds, 0);
    expect(progression.paidDiamonds, 2);

    final saved = SavedProgression.fromJson(progression.toSaveData().toJson());
    final restored = RunProgression()..restoreFromSaveData(saved);

    expect(restored.freeDiamonds, 0);
    expect(restored.paidDiamonds, 2);
    expect(restored.diamonds, 2);

    final legacySaved = SavedProgression.fromJson(const <String, Object?>{
      'unlockedStageCount': 1,
    });
    final legacyProgression = RunProgression()
      ..restoreFromSaveData(legacySaved);

    expect(legacyProgression.freeDiamonds, 0);
    expect(legacyProgression.paidDiamonds, 0);
    expect(legacyProgression.diamonds, 0);
    expect(legacyProgression.researchSlotTwoUnlocked, isFalse);
    expect(legacyProgression.availableResearchSlotCount, 1);
  });

  test(
    'second research slot unlocks after stage ten and runs two researches',
    () {
      final progression = RunProgression()
        ..runes = 1000
        ..freeDiamonds = 400
        ..paidDiamonds = 300;

      expect(progression.availableResearchSlotCount, 1);
      expect(progression.canUnlockResearchSlotTwo, isFalse);
      expect(progression.unlockResearchSlotTwo(), isFalse);

      progression.clearedStageNumbers.add(10);

      expect(progression.researchSlotTwoPurchaseUnlocked, isTrue);
      expect(progression.canUnlockResearchSlotTwo, isTrue);
      expect(progression.unlockResearchSlotTwo(), isTrue);
      expect(progression.availableResearchSlotCount, 2);
      expect(progression.freeDiamonds, 0);
      expect(progression.paidDiamonds, 100);
      expect(progression.unlockResearchSlotTwo(), isFalse);

      expect(
        progression.startResearch(
          ResearchType.researchEfficiency,
          nowMillis: 1000,
        ),
        isTrue,
      );
      expect(
        progression.startResearch(ResearchType.bossBounty, nowMillis: 1000),
        isTrue,
      );
      expect(
        progression.startResearch(
          ResearchType.researchCostEfficiency,
          nowMillis: 1000,
        ),
        isFalse,
      );
      expect(progression.activeResearches, hasLength(2));

      final saved = SavedProgression.fromJson(
        progression.toSaveData().toJson(),
      );
      final restored = RunProgression()..restoreFromSaveData(saved);

      expect(restored.researchSlotTwoUnlocked, isTrue);
      expect(restored.availableResearchSlotCount, 2);
      expect(restored.activeResearches, hasLength(2));
      expect(
        restored.cancelResearch(
          ResearchType.researchEfficiency,
          nowMillis: 2000,
        ),
        isTrue,
      );
      expect(restored.activeResearches, hasLength(1));
      expect(restored.activeResearches.single.type, ResearchType.bossBounty);
      expect(
        restored.startResearch(
          ResearchType.researchCostEfficiency,
          nowMillis: 2000,
        ),
        isTrue,
      );
    },
  );

  test(
    'research instant completion costs one diamond per remaining minute',
    () {
      const sixtySeconds = ResearchProgress(
        type: ResearchType.gemAttunement,
        targetLevel: 1,
        startedAtMillis: 0,
        durationMillis: 60000,
      );
      const sixtyOneSeconds = ResearchProgress(
        type: ResearchType.gemAttunement,
        targetLevel: 1,
        startedAtMillis: 0,
        durationMillis: 61000,
      );

      expect(
        RunProgression.researchInstantCompleteCostFor(
          sixtySeconds,
          nowMillis: 0,
        ),
        1,
      );
      expect(
        RunProgression.researchInstantCompleteCostFor(
          sixtyOneSeconds,
          nowMillis: 0,
        ),
        2,
      );
    },
  );

  test(
    'research instant completion uses diamonds and only completes target',
    () {
      final progression = RunProgression()
        ..runes = 1000
        ..freeDiamonds = 1
        ..paidDiamonds = 1
        ..clearedStageNumbers.addAll({1, 2, 3});

      expect(
        progression.startResearch(ResearchType.gemAttunement, nowMillis: 1000),
        isTrue,
      );
      progression.activeResearches.add(
        const ResearchProgress(
          type: ResearchType.researchEfficiency,
          targetLevel: 1,
          startedAtMillis: 1000,
          durationMillis: 1800000,
        ),
      );

      expect(
        progression.completeResearchWithDiamonds(
          ResearchType.gemAttunement,
          nowMillis: 1000 + 3600000 - 61000,
        ),
        isTrue,
      );
      expect(progression.freeDiamonds, 0);
      expect(progression.paidDiamonds, 0);
      expect(progression.researchLevel(ResearchType.gemAttunement), 1);
      expect(progression.activeResearches, hasLength(1));
      expect(
        progression.activeResearches.single.type,
        ResearchType.researchEfficiency,
      );

      final shortProgression = RunProgression()
        ..runes = 1000
        ..freeDiamonds = 1
        ..clearedStageNumbers.addAll({1, 2, 3});
      expect(
        shortProgression.startResearch(
          ResearchType.gemAttunement,
          nowMillis: 1000,
        ),
        isTrue,
      );
      expect(
        shortProgression.completeResearchWithDiamonds(
          ResearchType.gemAttunement,
          nowMillis: 1000 + 3600000 - 61000,
        ),
        isFalse,
      );
      expect(shortProgression.freeDiamonds, 1);
      expect(shortProgression.researchLevel(ResearchType.gemAttunement), 0);
      expect(shortProgression.activeResearches, hasLength(1));
    },
  );

  test('target priority research unlocks after stage two clear', () {
    final progression = RunProgression()..runes = 100;

    expect(
      progression.isResearchUnlocked(ResearchType.turretTargetPriority),
      isFalse,
    );
    expect(progression.canSetTurretTargetPriority, isFalse);
    expect(
      progression.startResearch(
        ResearchType.turretTargetPriority,
        nowMillis: 1000,
      ),
      isFalse,
    );

    progression.clearedStageNumbers.add(2);

    expect(
      progression.isResearchUnlocked(ResearchType.turretTargetPriority),
      isTrue,
    );
    expect(
      progression.researchCostForCurrentLevel(
        ResearchType.turretTargetPriority,
      ),
      80,
    );
    expect(
      progression.researchDurationForCurrentLevel(
        ResearchType.turretTargetPriority,
      ),
      20 * 60 * 1000,
    );
    expect(
      progression.startResearch(
        ResearchType.turretTargetPriority,
        nowMillis: 1000,
      ),
      isTrue,
    );
    expect(progression.runes, 20);
    expect(progression.canSetTurretTargetPriority, isFalse);

    expect(
      progression.completeFinishedResearches(nowMillis: 1000 + 20 * 60 * 1000),
      isTrue,
    );
    expect(progression.canSetTurretTargetPriority, isTrue);
  });

  test('canceling research keeps elapsed time for the next resume', () {
    final progression = RunProgression()
      ..runes = 1000
      ..clearedStageNumbers.addAll({1, 2, 3, 4, 5});

    expect(
      progression.startResearch(ResearchType.gemAttunement, nowMillis: 1000),
      isTrue,
    );
    expect(
      progression.cancelResearch(ResearchType.gemAttunement, nowMillis: 901000),
      isTrue,
    );
    expect(progression.activeResearches, isEmpty);
    expect(
      progression.researchElapsedMillis[ResearchType.gemAttunement],
      900000,
    );
    expect(progression.runes, 1000);

    final restored = RunProgression()
      ..restoreFromSaveData(progression.toSaveData());
    expect(restored.researchElapsedMillis[ResearchType.gemAttunement], 900000);

    expect(
      restored.startResearch(ResearchType.gemAttunement, nowMillis: 5000000),
      isTrue,
    );
    expect(restored.runes, 895);
    expect(restored.activeResearches.single.durationMillis, 2700000);
    expect(restored.activeResearches.single.initialElapsedMillis, 900000);
    expect(restored.activeResearches.single.progressRatioAt(5000000), 0.25);

    expect(
      restored.completeFinishedResearches(nowMillis: 5000000 + 2699999),
      isFalse,
    );
    expect(
      restored.completeFinishedResearches(nowMillis: 5000000 + 2700000),
      isTrue,
    );
    expect(restored.researchLevel(ResearchType.gemAttunement), 1);
    expect(
      restored.researchElapsedMillis,
      isNot(contains(ResearchType.gemAttunement)),
    );
  });

  test('research efficiency and cost efficiency affect future research', () {
    final progression = RunProgression()..runes = 50;

    expect(
      progression.startResearch(
        ResearchType.researchEfficiency,
        nowMillis: 1000,
      ),
      isTrue,
    );
    expect(progression.runes, 0);
    expect(progression.activeResearches.single.durationMillis, 1800000);

    expect(
      progression.completeFinishedResearches(nowMillis: 1000 + 1800000),
      isTrue,
    );
    expect(progression.researchEfficiencyRate, 0.05);

    progression
      ..runes = 200
      ..clearedStageNumbers.addAll({1, 2, 3})
      ..researchLevels[ResearchType.researchCostEfficiency] = 20;

    expect(progression.researchCostEfficiencyRate, 1);
    expect(
      progression.startResearch(ResearchType.gemAttunement, nowMillis: 3000),
      isTrue,
    );
    expect(progression.runes, 147);
    expect(progression.activeResearches.single.durationMillis, 3428571);
  });

  test('boss bounty research is open by default with a light cost curve', () {
    final progression = RunProgression()..runes = 100;

    expect(progression.isResearchUnlocked(ResearchType.bossBounty), isTrue);
    expect(
      progression.researchCostForCurrentLevel(ResearchType.bossBounty),
      30,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.bossBounty),
      30 * 60 * 1000,
    );

    expect(
      progression.startResearch(ResearchType.bossBounty, nowMillis: 1000),
      isTrue,
    );
    expect(progression.runes, 70);
    expect(
      progression.completeFinishedResearches(nowMillis: 1000 + 30 * 60 * 1000),
      isTrue,
    );
    expect(progression.researchLevel(ResearchType.bossBounty), 1);
    expect(progression.bossBountyBonusRate, closeTo(0.025, 0.001));
    expect(
      progression.researchCostForCurrentLevel(ResearchType.bossBounty),
      34,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.bossBounty),
      33 * 60 * 1000,
    );

    progression.researchLevels[ResearchType.bossBounty] = 20;
    expect(progression.bossBountyBonusRate, closeTo(0.5, 0.001));
  });

  test('crystal recovery research unlocks after stage five clear', () {
    final progression = RunProgression()..runes = 2000;

    expect(
      progression.isResearchUnlocked(ResearchType.crystalRecovery),
      isFalse,
    );

    progression.clearedStageNumbers.add(5);

    expect(
      progression.isResearchUnlocked(ResearchType.crystalRecovery),
      isTrue,
    );
    expect(
      progression.researchCostForCurrentLevel(ResearchType.crystalRecovery),
      150,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.crystalRecovery),
      90 * 60 * 1000,
    );

    expect(
      progression.startResearch(ResearchType.crystalRecovery, nowMillis: 1000),
      isTrue,
    );
    expect(progression.runes, 1850);
    expect(
      progression.completeFinishedResearches(nowMillis: 1000 + 90 * 60 * 1000),
      isTrue,
    );
    expect(progression.researchLevel(ResearchType.crystalRecovery), 1);
    expect(progression.bossKillGemShardBonus, 1);
    expect(
      progression.researchCostForCurrentLevel(ResearchType.crystalRecovery),
      207,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.crystalRecovery),
      (90 * 60 * 1000 * 1.25).round(),
    );

    progression.researchLevels[ResearchType.crystalRecovery] = 5;
    expect(progression.bossKillGemShardBonus, 5);
  });

  test('rune resonance research unlocks after stage eight clear', () {
    final progression = RunProgression()..runes = 1000;

    expect(progression.isResearchUnlocked(ResearchType.runeResonance), isFalse);

    progression.clearedStageNumbers.add(8);

    expect(progression.isResearchUnlocked(ResearchType.runeResonance), isTrue);
    expect(
      progression.researchCostForCurrentLevel(ResearchType.runeResonance),
      180,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.runeResonance),
      3 * 60 * 60 * 1000,
    );

    expect(
      progression.startResearch(ResearchType.runeResonance, nowMillis: 1000),
      isTrue,
    );
    expect(progression.runes, 820);
    expect(
      progression.completeFinishedResearches(
        nowMillis: 1000 + 3 * 60 * 60 * 1000,
      ),
      isTrue,
    );
    expect(progression.researchLevel(ResearchType.runeResonance), 1);
    expect(progression.runeResonanceBonusRate, closeTo(0.02, 0.001));
    expect(
      progression.researchCostForCurrentLevel(ResearchType.runeResonance),
      212,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.runeResonance),
      (3 * 60 * 60 * 1000 * 1.08).round(),
    );

    progression.researchLevels[ResearchType.runeResonance] = 20;
    expect(progression.runeResonanceBonusRate, closeTo(0.4, 0.001));
  });

  test('run upgrade cost optimization unlocks after stage eight clear', () {
    final progression = RunProgression()..runes = 1000;

    expect(
      progression.isResearchUnlocked(ResearchType.runUpgradeCostOptimization),
      isFalse,
    );
    expect(progression.runUpgradeCostMultiplier, 1);

    progression.clearedStageNumbers.add(8);

    expect(
      progression.isResearchUnlocked(ResearchType.runUpgradeCostOptimization),
      isTrue,
    );
    expect(
      progression.researchCostForCurrentLevel(
        ResearchType.runUpgradeCostOptimization,
      ),
      150,
    );
    expect(
      progression.researchDurationForCurrentLevel(
        ResearchType.runUpgradeCostOptimization,
      ),
      2 * 60 * 60 * 1000,
    );

    expect(
      progression.startResearch(
        ResearchType.runUpgradeCostOptimization,
        nowMillis: 1000,
      ),
      isTrue,
    );
    expect(
      progression.completeFinishedResearches(
        nowMillis: 1000 + 2 * 60 * 60 * 1000,
      ),
      isTrue,
    );
    expect(
      progression.researchLevel(ResearchType.runUpgradeCostOptimization),
      1,
    );
    expect(progression.runUpgradeCostMultiplier, closeTo(0.98, 0.001));

    progression.researchLevels[ResearchType.runUpgradeCostOptimization] = 10;
    expect(progression.runUpgradeCostMultiplier, closeTo(0.8, 0.001));
  });

  test('run upgrade limit researches unlock after stage fifteen clear', () {
    final progression = RunProgression()..runes = 1000;
    const researchTypes = [
      ResearchType.towerDamageLimitExpansion,
      ResearchType.killGoldLimitExpansion,
      ResearchType.waveGoldLimitExpansion,
    ];

    for (final type in researchTypes) {
      expect(progression.isResearchUnlocked(type), isFalse);
    }

    progression.clearedStageNumbers.add(8);

    for (final type in researchTypes) {
      expect(progression.isResearchUnlocked(type), isFalse);
    }

    progression.clearedStageNumbers.add(12);

    for (final type in researchTypes) {
      expect(progression.isResearchUnlocked(type), isFalse);
    }

    progression.clearedStageNumbers.add(15);

    for (final type in researchTypes) {
      expect(progression.isResearchUnlocked(type), isTrue);
      expect(progression.researchCostForCurrentLevel(type), 150);
      expect(
        progression.researchDurationForCurrentLevel(type),
        2 * 60 * 60 * 1000,
      );
    }

    expect(
      progression.startResearch(
        ResearchType.towerDamageLimitExpansion,
        nowMillis: 1000,
      ),
      isTrue,
    );
    expect(progression.runes, 850);
    expect(
      progression.completeFinishedResearches(
        nowMillis: 1000 + 2 * 60 * 60 * 1000,
      ),
      isTrue,
    );
    expect(
      progression.researchLevel(ResearchType.towerDamageLimitExpansion),
      1,
    );
    expect(
      progression.researchCostForCurrentLevel(
        ResearchType.towerDamageLimitExpansion,
      ),
      177,
    );
    expect(
      progression.researchDurationForCurrentLevel(
        ResearchType.towerDamageLimitExpansion,
      ),
      (2 * 60 * 60 * 1000 * 1.08).round(),
    );

    progression.researchLevels[ResearchType.towerDamageLimitExpansion] = 10;
    expect(
      progression.runUpgradeMaxLevelBonusFor(RunUpgradeType.towerDamage),
      10,
    );
    expect(progression.runUpgradeMaxLevelBonusFor(RunUpgradeType.killGold), 0);
    expect(progression.runUpgradeMaxLevelBonusFor(RunUpgradeType.waveGold), 0);
  });

  test('basic link engineering research is open by default', () {
    final progression = RunProgression()..runes = 100;

    expect(
      progression.isResearchUnlocked(ResearchType.linkMaintenance),
      isTrue,
    );
    expect(
      progression.researchCostForCurrentLevel(ResearchType.linkMaintenance),
      30,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.linkMaintenance),
      30 * 60 * 1000,
    );

    expect(
      progression.startResearch(ResearchType.linkMaintenance, nowMillis: 1000),
      isTrue,
    );
    expect(progression.runes, 70);
    expect(
      progression.completeFinishedResearches(nowMillis: 1000 + 30 * 60 * 1000),
      isTrue,
    );
    expect(progression.researchLevel(ResearchType.linkMaintenance), 1);
    expect(progression.firstLinkUpgradeDiscountRate, closeTo(0.02, 0.001));
    expect(
      progression.researchCostForCurrentLevel(ResearchType.linkMaintenance),
      34,
    );
    expect(
      progression.researchDurationForCurrentLevel(ResearchType.linkMaintenance),
      2016000,
    );

    progression.researchLevels[ResearchType.linkMaintenance] = 10;
    expect(progression.firstLinkUpgradeDiscountRate, closeTo(0.2, 0.001));
  });
}
