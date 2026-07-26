import 'helpers/game_balance_test_helpers.dart';

void main() {
  test(
    'nexus core beam periodically damages enemies from turret DPS',
    () async {
      final game = RuneNexusGame(
        saveRepository: MemorySaveRepository(),
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.tryBuildTurret(const GridPoint(2, 0));

      final arrow = gameTurrets[TurretType.arrow]!;
      final expectedBeamDamage = arrow.damage * arrow.attackRate * 5 * 0.08;
      expect(
        game.snapshotNotifier.value.nexusCoreBeamDamage,
        closeTo(expectedBeamDamage, 0.001),
      );

      final backEnemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(200, 0)],
        game: game,
      )..distanceTravelled = 10;
      final frontEnemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(200, 0)],
        game: game,
      )..distanceTravelled = 80;
      await game.add(backEnemy);
      await game.add(frontEnemy);
      game.update(0);
      game.startNextWave();
      game.enemies.addAll([backEnemy, frontEnemy]);

      game.update(5);

      expect(game.nexusCoreBeamActive, isTrue);
      expect(game.nexusCoreBeamCooldownSeconds, 0);
      expect(frontEnemy.hp, lessThan(frontEnemy.maxHp));
      expect(backEnemy.hp, backEnemy.maxHp);
      expect(game.coreCombatSkillActivationCount, 1);
      expect(game.coreCombatSkillDirectDamageDealt, greaterThan(0));
      expect(game.coreCombatSkillBonusDamageDealt, 0);
    },
  );

  test(
    'attack haste increases guardian beam cooldown recovery speed',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 0,
          unlockedStageCount: 3,
          clearedStageNumbers: const {1, 2},
          totalCorePoints: 20,
          corePassiveNodeRanks: const {CorePassiveNodeId.attackHaste: 5},
        );
      final game = RuneNexusGame(
        saveRepository: repository,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.tryBuildTurret(const GridPoint(2, 0));

      final arrow = gameTurrets[TurretType.arrow]!;
      final expectedBeamDamage = arrow.damage * arrow.attackRate * 5 * 0.08;
      expect(game.nexusCoreBeamIntervalSeconds, closeTo(5 / 1.1, 0.001));
      expect(
        game.snapshotNotifier.value.nexusCoreBeamDamage,
        closeTo(expectedBeamDamage, 0.001),
      );

      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(200, 0)],
        game: game,
      )..distanceTravelled = 80;
      await game.add(enemy);
      game.update(0);
      game.startNextWave();
      game.enemies.add(enemy);

      game.update(4.54);

      expect(game.nexusCoreBeamActive, isFalse);
      expect(enemy.hp, enemy.maxHp);

      game.update(0.02);

      expect(game.nexusCoreBeamActive, isTrue);
      expect(enemy.hp, lessThan(enemy.maxHp));
    },
  );

  test('core output passives amplify guardian beam power', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        phase: GamePhase.wave,
        totalCorePoints: 100,
        corePassiveNodeRanks: const {
          CorePassiveNodeId.attackOutput: 5,
          CorePassiveNodeId.attackFocus: 3,
          CorePassiveNodeId.attackRiftMark: 3,
          CorePassiveNodeId.attackOverclock: 1,
        },
        coreCombatSkillStats: const SavedCoreCombatSkillStats(
          directDamageDealt: 0,
          bonusDamageDealt: 0,
          activationCount: 2,
        ),
      );
    final game = RuneNexusGame(
      saveRepository: repository,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.continueRestoredRun();
    game.tryBuildTurret(const GridPoint(2, 0));

    final arrow = gameTurrets[TurretType.arrow]!;
    final baseBeamDamage = arrow.damage * arrow.attackRate * 5 * 0.08;
    expect(game.nexusCoreBeamDamage, closeTo(baseBeamDamage * 2.1875, 0.001));

    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 10000,
      path: [Vector2.zero(), Vector2(200, 0)],
      game: game,
    )..distanceTravelled = 80;
    await game.add(enemy);
    game.enemies.add(enemy);
    game.update(5);

    expect(game.coreCombatSkillActivationCount, 3);
    expect(game.nexusCoreBeamActive, isTrue);
    expect(game.nexusCoreBeamDamage, closeTo(baseBeamDamage * 2.1875, 0.001));
  });

  testWidgets('core skill activation amplifies turret stats for two seconds', (
    tester,
  ) async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        phase: GamePhase.wave,
        totalCorePoints: 100,
        corePassiveNodeRanks: const {
          CorePassiveNodeId.attackHaste: 3,
          CorePassiveNodeId.attackPrecompute: 5,
          CorePassiveNodeId.attackOutput: 3,
          CorePassiveNodeId.attackFocus: 5,
        },
      );
    final game = RuneNexusGame(
      saveRepository: repository,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.runAsync(game.ready);
    game.continueRestoredRun();
    game.tryBuildTurret(const GridPoint(2, 0));
    await tester.runAsync(game.ready);
    final turret = game.children.whereType<TurretComponent>().single;
    final baseDamage = turret.damage;
    final baseAttackRate = turret.attackRate;

    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 10000,
      path: [Vector2.zero(), Vector2(200, 0)],
      game: game,
    )..distanceTravelled = 80;
    await game.add(enemy);
    await tester.runAsync(game.ready);
    game.enemies.add(enemy);
    game.update(5 / 1.06 + 0.001);

    expect(turret.damage, closeTo(baseDamage * 1.20, 0.001));
    expect(turret.attackRate, closeTo(baseAttackRate * 1.15, 0.001));

    game.update(1.99);
    expect(turret.damage, closeTo(baseDamage * 1.20, 0.001));
    expect(turret.attackRate, closeTo(baseAttackRate * 1.15, 0.001));

    game.update(0.02);
    expect(turret.damage, closeTo(baseDamage, 0.001));
    expect(turret.attackRate, closeTo(baseAttackRate, 0.001));
    game.disposeAppResources();
  });

  test(
    'efficiency build and upgrade discounts follow dynamic turret diversity',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 1,
          gold: 10000,
          unlockedStageCount: 7,
          clearedStageNumbers: const {1, 2, 3, 4, 5, 6},
          totalCorePoints: 100,
          corePassiveNodeRanks: maxEfficiencyPassiveRanks,
        );
      final game = EfficiencyModuleGame(saveRepository: repository);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      // 모듈 건설 할인 하한 적용 후 절약 설계를 별도 곱연산.
      expect(game.turretBuildCost(TurretType.arrow), 41);
      game.tryBuildTurret(const GridPoint(2, 0));
      game.selectTurretType(TurretType.cannon);
      game.tryBuildTurret(const GridPoint(3, 0));
      game.selectTurretType(TurretType.magic);
      game.tryBuildTurret(const GridPoint(0, 1));

      final beforeFourthTypeCost = game.turretBuildCost(TurretType.arrow);
      final fourthTypeCost = game.turretBuildCost(TurretType.frost);
      final goldBeforeFourthType = game.snapshotNotifier.value.gold;
      game.selectTurretType(TurretType.frost);
      game.tryBuildTurret(const GridPoint(2, 1));

      expect(beforeFourthTypeCost, 41);
      expect(
        goldBeforeFourthType - game.snapshotNotifier.value.gold,
        fourthTypeCost,
      );
      // 네 번째 종류 자체에는 미적용, 배치 완료 후 통합 전선 활성화.
      expect(game.turretBuildCost(TurretType.arrow), 35);

      game.refundSelectedTurret();
      expect(game.turretBuildCost(TurretType.arrow), 41);
      game.selectTurretType(TurretType.frost);
      game.tryBuildTurret(const GridPoint(2, 1));
      expect(game.turretBuildCost(TurretType.arrow), 35);

      game.selectTurretType(TurretType.sniper);
      game.tryBuildTurret(const GridPoint(3, 1));
      final arrow = game.children.whereType<TurretComponent>().singleWhere(
        (turret) => turret.definition.type == TurretType.arrow,
      );
      expect(arrow.levelUpCost, 31);
      expect(arrow.linkUpgradeCost, 51);

      tapBuildTile(game, const GridPoint(2, 0));
      final goldBeforeUpgrades = game.snapshotNotifier.value.gold;
      game.levelUpSelectedTurret();
      game.upgradeSelectedTurretLink();

      expect(game.snapshotNotifier.value.gold, goldBeforeUpgrades - 31 - 51);
      expect(arrow.investedGold, 41 + 31 + 51);
      expect(game.snapshotNotifier.value.selectedTurretRefundGold, 92);

      var expectedInvestedGold = arrow.investedGold;
      while (arrow.level < 5) {
        expectedInvestedGold += arrow.levelUpCost;
        game.levelUpSelectedTurret();
      }
      expect(arrow.linkUpgradeCost, 129);
      expectedInvestedGold += arrow.linkUpgradeCost;
      game.upgradeSelectedTurretLink();
      expect(arrow.investedGold, expectedInvestedGold);
      expect(arrow.slotLimit, 3);
    },
  );

  test(
    'trait engineering updates displayed and paid Gem Shard costs',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 1,
          gold: 10000,
          gemShards: 100,
          totalCorePoints: 100,
          corePassiveNodeRanks: maxEfficiencyPassiveRanks,
        );
      final game = RuneNexusGame(saveRepository: repository);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.tryBuildTurret(const GridPoint(2, 0));
      game.levelUpSelectedTurret();
      game.levelUpSelectedTurret();

      var snapshot = game.snapshotNotifier.value;
      expect(snapshot.selectedTurretPrimaryTraitCost, 9);
      game.chooseSelectedTurretPrimaryTrait(TurretTraitType.lightweightBarrel);
      snapshot = game.snapshotNotifier.value;
      expect(snapshot.gemShards, 91);

      while (snapshot.selectedTurretLevel < 7) {
        game.levelUpSelectedTurret();
        snapshot = game.snapshotNotifier.value;
      }
      expect(snapshot.selectedTurretSecondaryTraitCost, 18);
      game.chooseSelectedTurretSecondaryTrait(
        snapshot.selectedTurretSecondaryTraitChoices.first,
      );

      expect(game.snapshotNotifier.value.gemShards, 73);
    },
  );

  test(
    'supply recovery multiplies the complete round clear Gold reward',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 0,
          supplyUpgradeLevel: 2,
          runUpgradeLevels: const {RunUpgradeType.waveGold: 1},
          totalCorePoints: 20,
          corePassiveNodeRanks: const {
            CorePassiveNodeId.efficiencySaving: 3,
            CorePassiveNodeId.efficiencySupplyRecovery: 5,
          },
        );
      final game = RuneNexusGame(
        saveRepository: repository,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 10,
          ),
        ],
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      game.startNextWave();
      game.update(0);

      // (기본 10 + 영구 2 + 런 4) * 1.15 = 18.4 -> 18
      expect(game.snapshotNotifier.value.gold, 188);

      final lowRankRepository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 1,
          totalCorePoints: 10,
          corePassiveNodeRanks: const {
            CorePassiveNodeId.efficiencySaving: 3,
            CorePassiveNodeId.efficiencySupplyRecovery: 1,
          },
        );
      final lowRankGame = RuneNexusGame(
        saveRepository: lowRankRepository,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 23,
          ),
        ],
      );
      lowRankGame.onGameResize(Vector2(400, 800));
      await lowRankGame.onLoad();
      lowRankGame.startNextWave();
      lowRankGame.update(0);

      expect(lowRankGame.snapshotNotifier.value.gold, 194);
    },
  );

  test(
    'gem spectrum uses equipped types and multiplies module Gem effects',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 1,
          gold: 10000,
          unlockedStageCount: 7,
          clearedStageNumbers: const {1, 2, 3, 4, 5, 6},
          totalCorePoints: 100,
          corePassiveNodeRanks: maxEfficiencyPassiveRanks,
        );
      final game = EfficiencyModuleGame(saveRepository: repository);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      void buildWithGem(TurretType turretType, GridPoint point, GemType gem) {
        game.selectTurretType(turretType);
        game.tryBuildTurret(point);
        game.grantGem(gem);
        game.equipSelectedTurret(gem);
      }

      buildWithGem(TurretType.arrow, const GridPoint(2, 0), GemType.range);
      buildWithGem(
        TurretType.cannon,
        const GridPoint(3, 0),
        GemType.armorPiercing,
      );
      buildWithGem(
        TurretType.magic,
        const GridPoint(0, 1),
        GemType.elementalDamage,
      );
      final arrow = game.children.whereType<TurretComponent>().singleWhere(
        (turret) => turret.definition.type == TurretType.arrow,
      );
      final cannon = game.children.whereType<TurretComponent>().singleWhere(
        (turret) => turret.definition.type == TurretType.cannon,
      );

      expect(
        arrow.range,
        closeTo(
          gameTurrets[TurretType.arrow]!.range *
              (1 + 0.2 * 1.2 * 1.09) *
              game.boardDistanceScale,
          0.001,
        ),
      );
      expect(cannon.ignoresArmorReduction, isTrue);

      game.removeSelectedTurretGemSlot();
      expect(
        arrow.range,
        closeTo(
          gameTurrets[TurretType.arrow]!.range *
              (1 + 0.2 * 1.2) *
              game.boardDistanceScale,
          0.001,
        ),
      );
      game.equipSelectedTurret(GemType.elementalDamage);

      buildWithGem(
        TurretType.frost,
        const GridPoint(2, 1),
        GemType.attackSpeed,
      );
      expect(
        arrow.range,
        closeTo(
          gameTurrets[TurretType.arrow]!.range *
              (1 + 0.2 * 1.2 * 1.12) *
              game.boardDistanceScale,
          0.001,
        ),
      );

      buildWithGem(
        TurretType.sniper,
        const GridPoint(3, 1),
        GemType.criticalChance,
      );
      buildWithGem(TurretType.lightning, const GridPoint(4, 1), GemType.chain);
      final lightning = game.children.whereType<TurretComponent>().singleWhere(
        (turret) => turret.definition.type == TurretType.lightning,
      );
      expect(
        arrow.range,
        closeTo(
          gameTurrets[TurretType.arrow]!.range *
              (1 + 0.2 * 1.2 * 1.18) *
              game.boardDistanceScale,
          0.001,
        ),
      );
      expect(lightning.lightningChainMaxJumps, 4);
    },
  );

  test('rift mark core skill unlocks with chapter two', () {
    final earlyProgression = RunProgression();
    expect(
      earlyProgression.equipCoreCombatSkill(CoreCombatSkill.riftMark),
      isFalse,
    );
    expect(earlyProgression.coreCombatSkill, CoreCombatSkill.guardianBeam);

    final chapterTwoProgression = RunProgression()
      ..restoreFromSaveData(
        const SavedProgression(
          runes: 0,
          lastRunRuneReward: 0,
          startingGoldUpgradeLevel: 0,
          nexusHpUpgradeLevel: 0,
          supplyUpgradeLevel: 0,
          fireTrainingUpgradeLevel: 0,
          criticalChanceUpgradeLevel: 0,
          criticalDamageUpgradeLevel: 0,
          killGoldUpgradeLevel: 0,
          emergencySaleUpgradeLevel: 0,
          unlockedStageCount: 6,
          bestRoundsByStage: {},
          clearedStageNumbers: {1, 2, 3, 4, 5},
          researchLevels: {},
          researchElapsedMillis: {},
          activeResearches: [],
        ),
      );

    expect(
      chapterTwoProgression.equipCoreCombatSkill(CoreCombatSkill.riftMark),
      isTrue,
    );
    expect(chapterTwoProgression.coreCombatSkill, CoreCombatSkill.riftMark);
  });

  test(
    'rift mark targets highest durability enemies and refreshes mark',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 0,
          unlockedStageCount: 6,
          clearedStageNumbers: const {1, 2, 3, 4, 5},
        );
      final game = RuneNexusGame(
        saveRepository: repository,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      expect(game.equipCoreCombatSkill(CoreCombatSkill.riftMark), isTrue);
      game.restartRun();
      game.startNextWave();

      final enemies = [
        durabilityEnemy(game, hp: 10, progress: 10),
        durabilityEnemy(game, hp: 80, progress: 20),
        durabilityEnemy(game, hp: 40, armor: 30, progress: 30),
        durabilityEnemy(game, hp: 80, progress: 40),
        durabilityEnemy(game, hp: 60, progress: 50),
      ];
      for (final enemy in enemies) {
        await game.add(enemy);
      }
      game.enemies.addAll(enemies);

      game.update(10);

      expect(enemies[0].hasRiftMark, isFalse);
      expect(enemies.skip(1).every((enemy) => enemy.hasRiftMark), isTrue);
      game.update(0);
      expect(game.children.whereType<RiftMarkPulseComponent>(), hasLength(1));
      expect(enemies[3].riftMarkRemaining, closeTo(5, 0.001));

      enemies[3].update(2);
      expect(enemies[3].riftMarkRemaining, closeTo(3, 0.001));
      enemies[3].applyRiftMark(damageAmplification: 0.25, duration: 5);
      expect(enemies[3].riftMarkRemaining, closeTo(5, 0.001));
      expect(enemies[3].riftMarkDamageAmplification, closeTo(0.25, 0.001));
    },
  );

  test('rift mark amplifies final damage before durability tiers', () {
    final game = RuneNexusGame();
    final normal = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyRiftMark(damageAmplification: 0.25, duration: 5);
    final boss = EnemyComponent(
      definition: gameEnemies[EnemyType.boss]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyRiftMark(damageAmplification: 0.125, duration: 5);
    final armored = EnemyComponent(
      definition: gameEnemies[EnemyType.armored]!,
      maxHp: 100,
      maxArmor: 20,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyRiftMark(damageAmplification: 0.25, duration: 5);

    normal.receiveDamage(10);
    boss.receiveDamage(10);
    armored.receiveDamage(10);

    expect(normal.hp, closeTo(87.5, 0.001));
    expect(boss.hp, closeTo(88.75, 0.001));
    expect(armored.armor, lessThan(20));
    expect(armored.hp, 100);
  });

  test('rift mark records actual bonus damage without direct skill damage', () {
    final game = RuneNexusGame();
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyRiftMark(damageAmplification: 0.25, duration: 5);

    expect(enemy.receiveDamage(20), closeTo(25, 0.001));

    expect(game.coreCombatSkillBonusDamageDealt, closeTo(5, 0.001));
    expect(game.coreCombatSkillDirectDamageDealt, 0);
  });

  test('attack haste increases rift mark cooldown recovery speed', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        unlockedStageCount: 6,
        clearedStageNumbers: const {1, 2, 3, 4, 5},
        totalCorePoints: 20,
        corePassiveNodeRanks: const {CorePassiveNodeId.attackHaste: 5},
        coreCombatSkill: CoreCombatSkill.riftMark,
      );
    final game = RuneNexusGame(
      saveRepository: repository,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();

    final enemy = durabilityEnemy(game, hp: 100, progress: 10);
    await game.add(enemy);
    game.enemies.add(enemy);

    expect(game.nexusCoreBeamIntervalSeconds, closeTo(10 / 1.1, 0.001));
    game.update(9.08);
    expect(enemy.hasRiftMark, isFalse);

    game.update(0.02);
    expect(enemy.hasRiftMark, isTrue);
    expect(game.coreCombatSkillActivationCount, 1);
  });

  test('third rift mark activation uses saved critical output count', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        phase: GamePhase.wave,
        unlockedStageCount: 6,
        clearedStageNumbers: const {1, 2, 3, 4, 5},
        coreCombatSkill: CoreCombatSkill.riftMark,
        totalCorePoints: 100,
        corePassiveNodeRanks: const {
          CorePassiveNodeId.attackOutput: 5,
          CorePassiveNodeId.attackFocus: 3,
          CorePassiveNodeId.attackRiftMark: 3,
          CorePassiveNodeId.attackOverclock: 1,
        },
        coreCombatSkillStats: const SavedCoreCombatSkillStats(
          directDamageDealt: 0,
          bonusDamageDealt: 0,
          activationCount: 2,
        ),
      );
    final game = RuneNexusGame(
      saveRepository: repository,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.continueRestoredRun();

    final enemy = durabilityEnemy(game, hp: 1000, progress: 10);
    await game.add(enemy);
    game.enemies.add(enemy);
    game.update(10);

    expect(game.coreCombatSkillActivationCount, 3);
    expect(enemy.riftMarkDamageAmplification, closeTo(0.25 * 2.1875, 0.001));
  });

  test('rift mark state is saved and restored', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        unlockedStageCount: 6,
        clearedStageNumbers: const {1, 2, 3, 4, 5},
        coreCombatSkill: CoreCombatSkill.riftMark,
      );
    final game = RuneNexusGame(
      saveRepository: repository,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();

    final enemy = durabilityEnemy(game, hp: 100, progress: 10)
      ..applyRiftMark(damageAmplification: 0.25, duration: 5);
    await game.add(enemy);
    game.enemies.add(enemy);
    await game.saveNow();

    final saved = repository.data!;
    expect(saved.runCoreCombatSkill, CoreCombatSkill.riftMark);
    expect(saved.enemies.single.riftMarkRemaining, closeTo(5, 0.001));

    final restoredRepository = MemorySaveRepository()..data = saved;
    final restored = RuneNexusGame(
      saveRepository: restoredRepository,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();
    expect(restored.enemies.single.hasRiftMark, isTrue);
    expect(restored.enemies.single.riftMarkDamageAmplification, 0.25);
  });

  test(
    'core combat skill stats are saved and restored with legacy fallback',
    () {
      final saved = saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 1,
        completedRounds: 1,
        coreCombatSkillStats: const SavedCoreCombatSkillStats(
          directDamageDealt: 12.5,
          bonusDamageDealt: 7.25,
          activationCount: 3,
        ),
      );

      final restored = GameSaveData.fromJson(saved.toJson())!;
      expect(restored.runCoreCombatSkillStats.directDamageDealt, 12.5);
      expect(restored.runCoreCombatSkillStats.bonusDamageDealt, 7.25);
      expect(restored.runCoreCombatSkillStats.activationCount, 3);

      final legacyJson = Map<String, Object?>.of(saved.toJson())
        ..remove('runCoreCombatSkillStats');
      final legacy = GameSaveData.fromJson(legacyJson)!;
      expect(legacy.runCoreCombatSkillStats.directDamageDealt, 0);
      expect(legacy.runCoreCombatSkillStats.bonusDamageDealt, 0);
      expect(legacy.runCoreCombatSkillStats.activationCount, 0);
    },
  );

  test(
    'nexus core beam stays inactive when combat skill is unequipped',
    () async {
      final game = RuneNexusGame(
        saveRepository: MemorySaveRepository(),
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      expect(game.unequipCoreCombatSkill(), isTrue);
      game.restartRun();
      game.tryBuildTurret(const GridPoint(2, 0));

      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(200, 0)],
        game: game,
      )..distanceTravelled = 80;
      await game.add(enemy);
      game.update(0);
      game.startNextWave();
      game.enemies.add(enemy);

      game.update(5);

      expect(game.snapshotNotifier.value.nexusCoreBeamAvailable, isFalse);
      expect(game.nexusCoreBeamActive, isFalse);
      expect(game.nexusCoreBeamCooldownSeconds, 0);
      expect(enemy.hp, enemy.maxHp);
    },
  );

  test(
    'core combat changes after run start do not affect active run beam',
    () async {
      final game = RuneNexusGame(
        saveRepository: MemorySaveRepository(),
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.restartRun();
      game.tryBuildTurret(const GridPoint(2, 0));
      game.startNextWave();

      expect(game.unequipCoreCombatSkill(), isTrue);
      expect(game.snapshotNotifier.value.coreCombatSkill, isNull);

      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(200, 0)],
        game: game,
      )..distanceTravelled = 80;
      await game.add(enemy);
      game.enemies.add(enemy);

      game.update(5);

      expect(game.nexusCoreBeamActive, isTrue);
      expect(enemy.hp, lessThan(enemy.maxHp));
    },
  );

  test(
    'active run core loadout is saved separately from core preset',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(
        saveRepository: repository,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.restartRun();
      game.tryBuildTurret(const GridPoint(2, 0));
      game.startNextWave();
      expect(game.unequipCoreCombatSkill(), isTrue);
      await game.saveNow();

      final saved = repository.data!;
      expect(saved.progression.coreCombatSkill, isNull);
      expect(saved.runCoreCombatSkill, CoreCombatSkill.guardianBeam);

      final restoredRepository = MemorySaveRepository()..data = saved;
      final restored = RuneNexusGame(
        saveRepository: restoredRepository,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
      );
      restored.onGameResize(Vector2(400, 800));
      await restored.onLoad();
      restored.continueRestoredRun();

      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(200, 0)],
        game: restored,
      )..distanceTravelled = 80;
      await restored.add(enemy);
      restored.enemies.add(enemy);

      restored.update(5);

      expect(restored.snapshotNotifier.value.coreCombatSkill, isNull);
      expect(restored.nexusCoreBeamActive, isTrue);
      expect(enemy.hp, lessThan(enemy.maxHp));
    },
  );

  test(
    'core progression defaults to guardian beam with empty passive tree',
    () {
      final saved = SavedProgression.fromJson(const <String, Object?>{
        'unlockedStageCount': 1,
      });
      final progression = RunProgression()..restoreFromSaveData(saved);

      expect(progression.coreCombatSkill, CoreCombatSkill.guardianBeam);
      expect(progression.totalCorePoints, 0);
      expect(progression.corePassiveNodeRanks, isEmpty);
      expect(
        progression.toSaveData().coreCombatSkill,
        CoreCombatSkill.guardianBeam,
      );
    },
  );

  test('core combat equipment can be saved and restored as empty', () {
    final saved = SavedProgression.fromJson(const <String, Object?>{
      'unlockedStageCount': 1,
      'coreCombatSkill': null,
    });
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.coreCombatSkill, isNull);
    expect(progression.toSaveData().coreCombatSkill, isNull);
    expect(progression.toSaveData().toJson()['coreCombatSkill'], isNull);
    expect(
      progression.equipCoreCombatSkill(CoreCombatSkill.guardianBeam),
      isTrue,
    );
    expect(progression.coreCombatSkill, CoreCombatSkill.guardianBeam);
    expect(progression.unequipCoreCombatSkill(), isTrue);
    expect(progression.coreCombatSkill, isNull);
  });

  test('legacy passive slot JSON is ignored without compensation', () {
    final saved = SavedProgression.fromJson(const <String, Object?>{
      'corePassiveSlotTwoUnlocked': true,
      'corePassiveSlots': ['selfRepair', 'costSavingDesign'],
      'totalCorePoints': 0,
    });
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.totalCorePoints, 0);
    expect(progression.corePassiveNodeRanks, isEmpty);
    expect(
      progression.toSaveData().toJson(),
      isNot(contains('corePassiveSlots')),
    );
  });

  test('core passive ranks are saved and restored', () {
    final progression = RunProgression()..grantCorePoints(20);
    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackHaste, 3),
      isTrue,
    );
    expect(
      progression.setCorePassiveNodeRank(CorePassiveNodeId.attackPrecompute, 2),
      isTrue,
    );

    final restored = RunProgression()
      ..restoreFromSaveData(progression.toSaveData());

    expect(restored.totalCorePoints, 20);
    expect(restored.spentCorePoints, 6);
    expect(restored.availableCorePoints, 14);
    expect(restored.corePassiveNodeRanks, progression.corePassiveNodeRanks);
  });

  test('core passive revision mismatch resets ranks but preserves points', () {
    final saved = SavedProgression.fromJson(<String, Object?>{
      'totalCorePoints': 20,
      'corePassiveTreeRevision': corePassiveTreeRevision + 1,
      'corePassiveNodeRanks': const {'attackHaste': 3},
      'claimedCorePointStageRewards': const [1, 2],
    });
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.totalCorePoints, 20);
    expect(progression.corePassiveNodeRanks, isEmpty);
    expect(progression.claimedCorePointStageRewards, {1, 2});
  });

  test('Nexus HP save accepts legacy integers and preserves fractions', () {
    final fractionalSave = saveWithCorePassiveRun(
      nexusHp: 19.25,
      roundIndex: 1,
      completedRounds: 1,
      roundNexusHpLost: 1.75,
      emergencyChargeUsedThisRound: true,
      finalDefenseUsedThisRound: true,
    );
    final fractionalRestored = GameSaveData.fromJson(fractionalSave.toJson())!;

    expect(fractionalRestored.nexusHp, closeTo(19.25, 0.0001));
    expect(fractionalRestored.roundNexusHpLost, closeTo(1.75, 0.0001));
    expect(fractionalRestored.emergencyChargeUsedThisRound, isTrue);
    expect(fractionalRestored.finalDefenseUsedThisRound, isTrue);

    final legacyJson = fractionalSave.toJson()..['nexusHp'] = 19;
    final legacyRestored = GameSaveData.fromJson(legacyJson)!;
    expect(legacyRestored.nexusHp, closeTo(19, 0.0001));
  });

  test('stage core point rewards total twenty and only grant once', () {
    expect(
      gameStages.fold<int>(
        0,
        (sum, stage) => sum + stage.firstClearCorePointReward,
      ),
      20,
    );
    expect(gameStages[4].firstClearCorePointReward, 2);
    expect(gameStages[9].firstClearCorePointReward, 3);
    expect(gameStages[14].firstClearCorePointReward, 3);

    final progression = RunProgression();
    progression.finishRun(
      completedRounds: 40,
      success: true,
      stageNumber: 5,
      firstClearCorePointReward: 2,
    );
    expect(progression.totalCorePoints, 2);
    expect(progression.lastRunCorePointReward, 2);

    progression.finishRun(
      completedRounds: 40,
      success: true,
      stageNumber: 5,
      firstClearCorePointReward: 2,
    );
    expect(progression.totalCorePoints, 2);
    expect(progression.lastRunCorePointReward, 0);

    progression.finishRun(
      completedRounds: 10,
      success: false,
      stageNumber: 10,
      firstClearCorePointReward: 3,
    );
    expect(progression.totalCorePoints, 2);
    expect(progression.lastRunCorePointReward, 0);
  });

  test('only stage eleven first clear grants five module tickets', () {
    final rewardsByStage = {
      for (final stage in gameStages)
        if (stage.firstClearTurretModuleTicketReward > 0)
          stage.id: stage.firstClearTurretModuleTicketReward,
    };
    expect(rewardsByStage, {11: 5});

    final progression = RunProgression();
    progression.finishRun(
      completedRounds: 40,
      success: true,
      stageNumber: 11,
      firstClearTurretModuleTicketReward: 5,
    );
    expect(progression.turretModuleTickets, 5);
    expect(progression.lastRunTurretModuleTicketReward, 5);

    final saved = SavedProgression.fromJson(progression.toSaveData().toJson());
    final restored = RunProgression()..restoreFromSaveData(saved);
    expect(restored.turretModuleTickets, 5);
    expect(restored.lastRunTurretModuleTicketReward, 5);

    restored.finishRun(
      completedRounds: 40,
      success: true,
      stageNumber: 11,
      firstClearTurretModuleTicketReward: 5,
    );
    expect(restored.turretModuleTickets, 5);
    expect(restored.lastRunTurretModuleTicketReward, 0);

    restored.finishRun(
      completedRounds: 40,
      success: true,
      stageNumber: 12,
    );
    expect(restored.turretModuleTickets, 5);
    expect(restored.lastRunTurretModuleTicketReward, 0);
  });

  test('legacy clears receive retroactive core points only once', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        unlockedStageCount: 6,
        clearedStageNumbers: const {1, 5},
      );
    final game = RuneNexusGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    await game.saveNow();

    expect(game.snapshotNotifier.value.totalCorePoints, 3);
    expect(game.snapshotNotifier.value.lastRunCorePointReward, 0);
    expect(repository.data!.progression.claimedCorePointStageRewards, {1, 5});

    final restored = RuneNexusGame(saveRepository: repository);
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();
    expect(restored.snapshotNotifier.value.totalCorePoints, 3);
    expect(restored.snapshotNotifier.value.lastRunCorePointReward, 0);
  });

  test(
    'defense passives increase maximum HP and recover fractional HP',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 19,
          roundIndex: 4,
          completedRounds: 4,
          totalCorePoints: 30,
          corePassiveNodeRanks: const {
            CorePassiveNodeId.controlSelfRepair: 5,
            CorePassiveNodeId.controlRetarget: 5,
          },
        );
      final game = RuneNexusGame(
        waves: emptyWaves(5),
        saveRepository: repository,
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      expect(game.turretBuildCost(TurretType.arrow), 60);
      expect(game.snapshotNotifier.value.maxNexusHp, closeTo(25, 0.0001));
      game.startNextWave();
      game.update(0.016);
      expect(game.snapshotNotifier.value.nexusHp, closeTo(19.75, 0.0001));
    },
  );

  test('damage restoration uses actual HP lost during the round', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 10,
        roundIndex: 0,
        completedRounds: 0,
        phase: GamePhase.wave,
        totalCorePoints: 30,
        corePassiveNodeRanks: const {
          CorePassiveNodeId.controlSelfRepair: 3,
          CorePassiveNodeId.controlRetarget: 3,
          CorePassiveNodeId.controlBufferShell: 3,
        },
      );
    final game = RuneNexusGame(
      waves: emptyWaves(1),
      saveRepository: repository,
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.continueRestoredRun();

    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: EnemyDefinition(
        type: EnemyType.normal,
        name: 'Damage Restorer Test',
        maxHp: 100,
        speed: normal.speed,
        rewardGold: 0,
        coreDamage: 2,
        color: normal.color,
        resistanceProfile: normal.resistanceProfile,
      ),
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    game.enemies.add(enemy);
    await game.add(enemy);

    game.enemyReachedCore(enemy);
    expect(game.snapshotNotifier.value.nexusHp, closeTo(8, 0.0001));

    game.update(0.016);

    expect(game.snapshotNotifier.value.maxNexusHp, closeTo(23, 0.0001));
    expect(game.snapshotNotifier.value.nexusHp, closeTo(9.16, 0.0001));
  });

  test(
    'damage reduction is multiplicative and emergency charge is once per round',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 0,
          totalCorePoints: 30,
          corePassiveNodeRanks: const {
            CorePassiveNodeId.controlThreatSense: 5,
            CorePassiveNodeId.controlRearLock: 5,
            CorePassiveNodeId.controlEmergencyCharge: 3,
          },
        );
      final game = RuneNexusGame(
        waves: emptyWaves(1),
        saveRepository: repository,
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.startNextWave();

      EnemyComponent halfDurabilityEnemy() {
        final enemy = EnemyComponent(
          definition: gameEnemies[EnemyType.normal]!,
          maxHp: 100,
          path: [Vector2.zero(), Vector2(500, 0)],
          game: game,
        )..hp = 50;
        game.enemies.add(enemy);
        return enemy;
      }

      final firstEnemy = halfDurabilityEnemy();
      await game.add(firstEnemy);
      game.enemyReachedCore(firstEnemy);

      expect(game.snapshotNotifier.value.nexusHp, closeTo(19.25625, 0.0001));
      expect(game.nexusCoreBeamCooldownSeconds, closeTo(3.25, 0.0001));
      await game.saveNow();
      expect(repository.data!.roundNexusHpLost, closeTo(0.74375, 0.0001));
      expect(repository.data!.emergencyChargeUsedThisRound, isTrue);

      final secondEnemy = halfDurabilityEnemy();
      await game.add(secondEnemy);
      game.enemyReachedCore(secondEnemy);

      expect(game.snapshotNotifier.value.nexusHp, closeTo(18.5125, 0.0001));
      expect(game.nexusCoreBeamCooldownSeconds, closeTo(3.25, 0.0001));
    },
  );

  test(
    'final defense ignores bosses without consuming its round use',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 0,
          totalCorePoints: 30,
          corePassiveNodeRanks: const {
            CorePassiveNodeId.controlThreatSense: 3,
            CorePassiveNodeId.controlRearLock: 3,
            CorePassiveNodeId.controlEmergencyCharge: 3,
            CorePassiveNodeId.controlFinalLine: 1,
          },
        );
      final game = RuneNexusGame(
        waves: emptyWaves(1),
        saveRepository: repository,
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.startNextWave();

      Future<void> reachCore(EnemyType type) async {
        final enemy = EnemyComponent(
          definition: gameEnemies[type]!,
          maxHp: 100,
          path: [Vector2.zero(), Vector2(500, 0)],
          game: game,
        );
        game.enemies.add(enemy);
        await game.add(enemy);
        game.enemyReachedCore(enemy);
      }

      await reachCore(EnemyType.boss);
      expect(game.snapshotNotifier.value.nexusHp, closeTo(12.72, 0.0001));

      await reachCore(EnemyType.normal);
      expect(game.snapshotNotifier.value.nexusHp, closeTo(12.72, 0.0001));
      await game.saveNow();
      expect(repository.data!.finalDefenseUsedThisRound, isTrue);

      await reachCore(EnemyType.normal);
      expect(game.snapshotNotifier.value.nexusHp, closeTo(11.81, 0.0001));
    },
  );

  test('restored defense round state persists and resets next round', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithCorePassiveRun(
        nexusHp: 15,
        roundIndex: 0,
        completedRounds: 0,
        phase: GamePhase.wave,
        totalCorePoints: 50,
        corePassiveNodeRanks: const {
          CorePassiveNodeId.controlSelfRepair: 3,
          CorePassiveNodeId.controlRetarget: 3,
          CorePassiveNodeId.controlBufferShell: 3,
          CorePassiveNodeId.controlThreatSense: 3,
          CorePassiveNodeId.controlRearLock: 3,
          CorePassiveNodeId.controlEmergencyCharge: 3,
          CorePassiveNodeId.controlFinalLine: 1,
        },
        roundNexusHpLost: 2,
        emergencyChargeUsedThisRound: true,
        finalDefenseUsedThisRound: true,
      );
    final game = RuneNexusGame(
      waves: emptyWaves(2),
      saveRepository: repository,
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    expect(game.snapshotNotifier.value.phase, GamePhase.restored);
    game.continueRestoredRun();

    Future<void> reachCore() async {
      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(500, 0)],
        game: game,
      );
      game.enemies.add(enemy);
      await game.add(enemy);
      game.enemyReachedCore(enemy);
    }

    await reachCore();

    // 복원된 사용 상태로 무효화와 충전이 중복 적용되지 않는다.
    expect(game.snapshotNotifier.value.nexusHp, closeTo(14.09, 0.0001));
    expect(game.nexusCoreBeamCooldownSeconds, closeTo(5, 0.0001));
    await game.saveNow();
    expect(repository.data!.roundNexusHpLost, closeTo(2.91, 0.0001));
    expect(repository.data!.emergencyChargeUsedThisRound, isTrue);
    expect(repository.data!.finalDefenseUsedThisRound, isTrue);

    game.update(0.016);

    // 복원된 손실량까지 손상 복원에 포함한 뒤 라운드 상태를 초기화한다.
    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.nexusHp, closeTo(15.5685, 0.0001));
    game.startNextWave();

    await reachCore();
    expect(game.snapshotNotifier.value.nexusHp, closeTo(15.5685, 0.0001));
    expect(game.nexusCoreBeamCooldownSeconds, closeTo(5, 0.0001));

    await reachCore();
    expect(game.snapshotNotifier.value.nexusHp, closeTo(14.6585, 0.0001));
    expect(game.nexusCoreBeamCooldownSeconds, closeTo(3.25, 0.0001));
    await game.saveNow();
    expect(repository.data!.roundNexusHpLost, closeTo(0.91, 0.0001));
    expect(repository.data!.emergencyChargeUsedThisRound, isTrue);
    expect(repository.data!.finalDefenseUsedThisRound, isTrue);
  });
}
