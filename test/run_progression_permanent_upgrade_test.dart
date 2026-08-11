import 'helpers/game_balance_test_helpers.dart';

void main() {
  test('run completion grants runes and progression applies next run', () {
    final game = RuneNexusGame(
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
    );

    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.success);
    expect(game.snapshotNotifier.value.completedRounds, 1);
    expect(game.snapshotNotifier.value.lastRunRuneReward, 2);
    expect(game.snapshotNotifier.value.runes, 2);
    expect(game.snapshotNotifier.value.unlockedStageCount, 2);
    expect(game.snapshotNotifier.value.bestRoundsByStage[1], 1);
    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(1));
    expect(game.snapshotNotifier.value.lastRunPreviousBestRound, 0);
    expect(game.snapshotNotifier.value.lastRunWasNewBestRound, isTrue);
    expect(game.snapshotNotifier.value.lastRunUnlockedStageNumber, 2);

    game.upgradeStartingGoldProgression();
    game.upgradeNexusHpProgression();
    game.restartRun();

    expect(game.snapshotNotifier.value.gold, 170);
    expect(game.snapshotNotifier.value.nexusHp, 20);
    expect(game.snapshotNotifier.value.maxNexusHp, 20);
    expect(game.snapshotNotifier.value.unlockedStageCount, 2);

    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.unlockedStageCount, 2);
    expect(game.snapshotNotifier.value.lastRunWasNewBestRound, isFalse);
    expect(game.snapshotNotifier.value.lastRunUnlockedStageNumber, isNull);

    game.startStage(2);
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.currentStageNumber, 2);
    expect(game.snapshotNotifier.value.lastRunRuneReward, 2);
    expect(game.snapshotNotifier.value.unlockedStageCount, 3);
    expect(game.snapshotNotifier.value.bestRoundsByStage[2], 1);
    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(2));
    expect(game.snapshotNotifier.value.lastRunWasNewBestRound, isTrue);
    expect(game.snapshotNotifier.value.lastRunUnlockedStageNumber, 3);
  });

  test('permanent starting gold and nexus hp upgrades respect max levels', () {
    final progression = RunProgression()..runes = 10000;

    for (var i = 0; i < 25; i++) {
      progression.upgradeStartingGold();
      progression.upgradeNexusHp();
    }

    expect(
      progression.startingGoldUpgradeLevel,
      RunProgression.maxStartingGoldUpgradeLevel,
    );
    expect(
      progression.nexusHpUpgradeLevel,
      RunProgression.maxNexusHpUpgradeLevel,
    );
    expect(progression.initialGold, 370);
    expect(progression.maxNexusHp, 30);
    expect(progression.runes, 7530);

    progression.startingGoldUpgradeLevel = 99;
    progression.nexusHpUpgradeLevel = 99;

    expect(progression.initialGold, 370);
    expect(progression.maxNexusHp, 30);
  });

  test('run tower damage upgrade boosts all turret damage', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    game.buyRunUpgrade(RunUpgradeType.towerDamage);

    expect(turret.damage, closeTo(7.21, 0.001));
    expect(game.snapshotNotifier.value.gold, 138);
    expect(
      game.snapshotNotifier.value.runUpgradeLevels[RunUpgradeType.towerDamage],
      1,
    );
  });

  test('run tower damage upgrade uses softened twenty-level cost curve', () {
    final definition = gameRunUpgrades[RunUpgradeType.towerDamage]!;
    const costs = [
      32,
      38,
      46,
      55,
      66,
      80,
      96,
      115,
      138,
      165,
      198,
      238,
      285,
      342,
      411,
      493,
      592,
      710,
      852,
      1022,
    ];

    expect(definition.maxLevel, 20);
    expect(definition.costMultiplier, 1.2);
    for (var level = 0; level < costs.length; level++) {
      expect(definition.costForLevel(level), costs[level]);
    }
    expect(definition.costForLevel(costs.length), 0);
  });

  test('run upgrade cost optimization discounts every run upgrade', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
        researchLevels: const {ResearchType.runUpgradeCostOptimization: 10},
        gold: 1000,
      );
    final game = RuneNexusGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    expect(game.runUpgradeCostFor(RunUpgradeType.towerDamage, 0), 26);
    expect(game.runUpgradeCostFor(RunUpgradeType.killGold, 0), 16);
    expect(game.runUpgradeCostFor(RunUpgradeType.waveGold, 0), 8);
  });

  test(
    'run upgrade limit research lets only matching upgrade exceed base cap',
    () async {
      final definition = gameRunUpgrades[RunUpgradeType.towerDamage]!;
      final costAtBaseCap = (definition.costForLevel(20, maxLevel: 30) * 0.8)
          .round();
      final repository = MemorySaveRepository()
        ..data = saveWithResearch(
          clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
          researchLevels: const {
            ResearchType.runUpgradeCostOptimization: 10,
            ResearchType.towerDamageLimitExpansion: 10,
          },
          gold: costAtBaseCap,
          runUpgradeLevels: const {RunUpgradeType.towerDamage: 20},
        );
      final game = RuneNexusGame(saveRepository: repository);

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      final snapshot = game.snapshotNotifier.value;
      expect(game.runUpgradeMaxLevelFor(RunUpgradeType.towerDamage), 30);
      expect(game.runUpgradeMaxLevelFor(RunUpgradeType.killGold), 20);
      expect(game.runUpgradeMaxLevelFor(RunUpgradeType.waveGold), 20);
      expect(snapshot.runUpgradeLevels[RunUpgradeType.towerDamage], 20);
      expect(game.runUpgradeCostFor(RunUpgradeType.towerDamage, 20), 982);

      game.buyRunUpgrade(RunUpgradeType.towerDamage);

      expect(game.snapshotNotifier.value.gold, 0);
      expect(
        game.snapshotNotifier.value.runUpgradeLevels[RunUpgradeType
            .towerDamage],
        21,
      );
      expect(
        game.snapshotNotifier.value.towerDamageRunBonusRate,
        closeTo(0.63, 0.001),
      );
    },
  );

  test('run kill gold upgrade accumulates fractional rewards', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.buyRunUpgrade(RunUpgradeType.killGold);

    for (var i = 0; i < 17; i++) {
      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 1,
        path: [Vector2.zero(), Vector2(1, 0)],
        game: game,
      );
      game.enemies.add(enemy);
      enemy.receiveDamage(999);
    }

    expect(game.snapshotNotifier.value.gold, 236);
    expect(
      game.snapshotNotifier.value.killGoldFractionWallet,
      closeTo(0.7, 0.001),
    );
  });

  test('run wave gold upgrade adds clear reward gold', () {
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

    game.buyRunUpgrade(RunUpgradeType.waveGold);
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.success);
    expect(game.snapshotNotifier.value.gold, 164);
  });

  test('run wave gold upgrade uses stepped flat reward growth', () {
    final definition = gameRunUpgrades[RunUpgradeType.waveGold]!;
    const expectedBonuses = {
      0: 0,
      1: 4,
      5: 20,
      6: 25,
      10: 45,
      11: 51,
      15: 75,
      16: 82,
      20: 110,
    };

    expect(definition.maxLevel, 20);
    expect(definition.costMultiplier, 1.2);
    for (final entry in expectedBonuses.entries) {
      expect(definition.effectForLevel(entry.key), entry.value);
    }
  });

  test('permanent supply upgrade adds one gold per cleared wave', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 2,
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
    game.upgradeSupplyProgression();
    game.restartRun();
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.success);
    expect(game.snapshotNotifier.value.gold, 171);
    expect(game.snapshotNotifier.value.waveClearGoldProgressionBonus, 1);
  });

  test('permanent kill reward upgrade boosts enemy gold rewards', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 3,
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
    game.upgradeKillGoldProgression();
    game.restartRun();

    for (var i = 0; i < 20; i++) {
      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 1,
        path: [Vector2.zero(), Vector2(1, 0)],
        game: game,
      );
      game.enemies.add(enemy);
      enemy.receiveDamage(999);
    }

    expect(game.snapshotNotifier.value.gold, 271);
    expect(game.snapshotNotifier.value.killGoldUpgradeLevel, 1);
    expect(
      game.snapshotNotifier.value.killGoldProgressionBonusRate,
      closeTo(0.01, 0.001),
    );
  });

  test('boss bounty research boosts only boss kill rewards', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {ResearchType.bossBounty: 20},
        runes: 0,
        unlockedStageCount: 1,
      );
    final game = RuneNexusGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    final normal = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(normal);
    normal.receiveDamage(999);

    expect(game.snapshotNotifier.value.gold, 175);
    expect(game.snapshotNotifier.value.killGoldFractionWallet, 0);

    final boss = EnemyComponent(
      definition: gameEnemies[EnemyType.boss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(boss);
    boss.receiveDamage(999);

    expect(game.snapshotNotifier.value.gold, 227);
    expect(
      game.snapshotNotifier.value.killGoldFractionWallet,
      closeTo(0.5, 0.001),
    );

    final shieldBoss = EnemyComponent(
      definition: gameEnemies[EnemyType.shieldBoss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(shieldBoss);
    shieldBoss.receiveDamage(999);

    expect(game.snapshotNotifier.value.gold, 299);
    expect(
      game.snapshotNotifier.value.killGoldFractionWallet,
      closeTo(0.5, 0.001),
    );

    final forgeBoss = EnemyComponent(
      definition: gameEnemies[EnemyType.forgeBoss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(forgeBoss);
    forgeBoss.receiveDamage(999);

    expect(game.snapshotNotifier.value.gold, 386);
    expect(
      game.snapshotNotifier.value.killGoldFractionWallet,
      closeTo(0.5, 0.001),
    );
  });

  test('crystal recovery research boosts only boss kill gem shards', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2, 3, 4, 5},
        researchLevels: const {ResearchType.crystalRecovery: 5},
        runes: 0,
        unlockedStageCount: 6,
      );
    final game = RuneNexusGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    final normal = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(normal);
    normal.receiveDamage(999);

    expect(game.snapshotNotifier.value.gemShards, 0);

    final boss = EnemyComponent(
      definition: gameEnemies[EnemyType.boss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(boss);
    boss.receiveDamage(999);

    expect(game.snapshotNotifier.value.gemShards, 5);

    final shieldBoss = EnemyComponent(
      definition: gameEnemies[EnemyType.shieldBoss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(shieldBoss);
    shieldBoss.receiveDamage(999);

    expect(game.snapshotNotifier.value.gemShards, 10);

    final forgeBoss = EnemyComponent(
      definition: gameEnemies[EnemyType.forgeBoss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(forgeBoss);
    forgeBoss.receiveDamage(999);

    expect(game.snapshotNotifier.value.gemShards, 15);
  });

  test('permanent kill reward unlocks after stage one clear', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 1,
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
    game.upgradeKillGoldProgression();

    expect(game.snapshotNotifier.value.clearedStageNumbers, isNot(contains(1)));
    expect(game.snapshotNotifier.value.killGoldUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.canUpgradeKillGold, isFalse);

    game.startStage(1);
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(1));
    expect(game.snapshotNotifier.value.canUpgradeKillGold, isTrue);
  });

  test('permanent fire training boosts turret damage', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        runes: 1000,
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
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.upgradeFireTrainingProgression();

    expect(turret.damage, closeTo(7.105, 0.001));
    expect(game.snapshotNotifier.value.fireTrainingUpgradeLevel, 1);
    expect(
      game.snapshotNotifier.value.fireTrainingDamageBonusRate,
      closeTo(0.015, 0.001),
    );
  });

  test('fire training uses hybrid 20 level progression', () {
    final progression = RunProgression()..runes = 10000;

    expect(RunProgression.maxFireTrainingUpgradeLevel, 20);
    expect(progression.fireTrainingUpgradeCost, 7);

    for (var i = 0; i < 20; i++) {
      expect(progression.upgradeFireTraining(), isTrue);
    }

    expect(progression.fireTrainingUpgradeLevel, 20);
    expect(progression.fireTrainingDamageBonusRate, closeTo(0.30, 0.001));
    expect(progression.fireTrainingUpgradeCost, 316);
    expect(progression.canUpgradeFireTraining, isFalse);
    expect(progression.upgradeFireTraining(), isFalse);
  });

  test('family damage training uses stage seven long term cost curve', () {
    final progression = RunProgression()..runes = 20000;
    const costs = [
      55,
      65,
      77,
      89,
      104,
      119,
      137,
      156,
      177,
      200,
      226,
      255,
      286,
      321,
      358,
      400,
      446,
      496,
      551,
      611,
    ];

    expect(RunProgression.maxPhysicalDamageTrainingUpgradeLevel, 20);
    expect(RunProgression.maxElementalDamageTrainingUpgradeLevel, 20);
    expect(costs.reduce((value, cost) => value + cost), 5129);

    for (final cost in costs) {
      expect(progression.physicalDamageTrainingUpgradeCost, cost);
      expect(progression.upgradePhysicalDamageTraining(), isTrue);
    }
    for (final cost in costs) {
      expect(progression.elementalDamageTrainingUpgradeCost, cost);
      expect(progression.upgradeElementalDamageTraining(), isTrue);
    }

    expect(progression.physicalDamageTrainingUpgradeLevel, 20);
    expect(progression.physicalDamageTrainingBonusRate, closeTo(0.40, 0.001));
    expect(progression.canUpgradePhysicalDamageTraining, isFalse);
    expect(progression.upgradePhysicalDamageTraining(), isFalse);
    expect(progression.elementalDamageTrainingUpgradeLevel, 20);
    expect(progression.elementalDamageTrainingBonusRate, closeTo(0.40, 0.001));
    expect(progression.canUpgradeElementalDamageTraining, isFalse);
    expect(progression.upgradeElementalDamageTraining(), isFalse);
  });

  test('family damage training unlocks after stage seven clear', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2, 3, 4, 5, 6},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 7,
      );
    final game = RuneNexusGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.upgradePhysicalDamageTrainingProgression();
    game.upgradeElementalDamageTrainingProgression();

    expect(
      game.snapshotNotifier.value.canUpgradePhysicalDamageTraining,
      isFalse,
    );
    expect(
      game.snapshotNotifier.value.canUpgradeElementalDamageTraining,
      isFalse,
    );
    expect(game.snapshotNotifier.value.physicalDamageTrainingUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.elementalDamageTrainingUpgradeLevel, 0);

    game.debugSetClearedStageCount(7);
    game.upgradePhysicalDamageTrainingProgression();
    game.upgradeElementalDamageTrainingProgression();

    expect(
      game.snapshotNotifier.value.canUpgradePhysicalDamageTraining,
      isTrue,
    );
    expect(
      game.snapshotNotifier.value.canUpgradeElementalDamageTraining,
      isTrue,
    );
    expect(game.snapshotNotifier.value.physicalDamageTrainingUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.elementalDamageTrainingUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.runes, 890);
  });

  test('family damage training boosts only matching damage family', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 8,
      );
    final game = RuneNexusGame(saveRepository: repository);
    final arrow = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final fire = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.magic]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.upgradeFireTrainingProgression();
    game.upgradePhysicalDamageTrainingProgression();

    expect(arrow.damage, closeTo(7.245, 0.001));
    expect(fire.damage, closeTo(16.24, 0.001));

    game.upgradeElementalDamageTrainingProgression();

    expect(arrow.damage, closeTo(7.245, 0.001));
    expect(fire.damage, closeTo(16.56, 0.001));
  });

  test('critical progression uses requested level caps and scaling', () {
    final progression = RunProgression()..runes = 20000;
    const chanceCosts = [
      70,
      84,
      101,
      121,
      145,
      174,
      209,
      251,
      301,
      361,
      433,
      520,
      624,
      749,
      899,
      1078,
      1294,
      1553,
      1864,
      2236,
    ];
    const damageCosts = [
      60,
      66,
      73,
      80,
      88,
      97,
      106,
      117,
      129,
      141,
      156,
      171,
      188,
      207,
      228,
      251,
      276,
      303,
      334,
      367,
    ];

    expect(RunProgression.maxCriticalChanceUpgradeLevel, 20);
    expect(RunProgression.maxCriticalDamageUpgradeLevel, 20);
    for (final cost in chanceCosts) {
      expect(progression.criticalChanceUpgradeCost, cost);
      expect(progression.upgradeCriticalChance(), isTrue);
    }
    for (final cost in damageCosts) {
      expect(progression.criticalDamageUpgradeCost, cost);
      expect(progression.upgradeCriticalDamage(), isTrue);
    }

    expect(progression.criticalChanceUpgradeLevel, 20);
    expect(progression.criticalChanceBonusRate, closeTo(0.20, 0.001));
    expect(progression.canUpgradeCriticalChance, isFalse);
    expect(progression.criticalDamageUpgradeLevel, 20);
    expect(progression.criticalDamageBonusRate, closeTo(0.20, 0.001));
    expect(progression.canUpgradeCriticalDamage, isFalse);
  });

  test('critical progression unlocks after stage four clear', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 4,
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
    final arrow = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final sniper = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.sniper]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.upgradeCriticalChanceProgression();
    game.upgradeCriticalDamageProgression();

    expect(game.snapshotNotifier.value.canUpgradeCriticalChance, isFalse);
    expect(game.snapshotNotifier.value.canUpgradeCriticalDamage, isFalse);
    expect(game.snapshotNotifier.value.criticalChanceUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.criticalDamageUpgradeLevel, 0);

    for (final stageNumber in [1, 2, 3, 4, 4]) {
      game.startStage(stageNumber);
      game.startNextWave();
      game.update(0.016);
    }
    game.upgradeCriticalChanceProgression();
    game.upgradeCriticalDamageProgression();

    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(4));
    expect(game.snapshotNotifier.value.criticalChanceUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.criticalDamageUpgradeLevel, 1);
    expect(arrow.criticalChance, closeTo(0.06, 0.001));
    expect(arrow.criticalDamageMultiplier, closeTo(1.51, 0.001));
    expect(sniper.criticalChance, closeTo(0.16, 0.001));
    expect(sniper.criticalDamageMultiplier, closeTo(2.01, 0.001));
  });

  test('supply and kill reward use 20 level progression', () {
    final progression = RunProgression()..runes = 10000;

    expect(RunProgression.maxSupplyUpgradeLevel, 20);
    expect(RunProgression.maxKillGoldUpgradeLevel, 20);
    expect(progression.supplyUpgradeCost, 7);
    expect(progression.killGoldUpgradeCost, 7);

    for (var i = 0; i < 20; i++) {
      expect(progression.upgradeSupply(), isTrue);
      expect(progression.upgradeKillGold(), isTrue);
    }

    expect(progression.supplyUpgradeLevel, 20);
    expect(progression.waveClearGoldBonus, 20);
    expect(progression.supplyUpgradeCost, 316);
    expect(progression.canUpgradeSupply, isFalse);
    expect(progression.upgradeSupply(), isFalse);
    expect(progression.killGoldUpgradeLevel, 20);
    expect(progression.killGoldBonusRate, closeTo(0.20, 0.001));
    expect(progression.killGoldUpgradeCost, 316);
    expect(progression.canUpgradeKillGold, isFalse);
    expect(progression.upgradeKillGold(), isFalse);
  });

  test('advanced economy upgrades use 20 level progression', () {
    final progression = RunProgression()..runes = 20000;
    const expectedCosts = [
      70,
      81,
      94,
      108,
      123,
      140,
      159,
      180,
      203,
      228,
      256,
      286,
      320,
      357,
      397,
      441,
      490,
      543,
      602,
      665,
    ];

    expect(expectedCosts.reduce((total, cost) => total + cost), 5743);
    for (final cost in expectedCosts) {
      expect(progression.linkCostOptimizationUpgradeCost, cost);
      expect(progression.upgradeLinkCostOptimization(), isTrue);
      expect(progression.turretLevelUpOptimizationUpgradeCost, cost);
      expect(progression.upgradeTurretLevelUpOptimization(), isTrue);
    }

    expect(progression.linkCostOptimizationUpgradeLevel, 20);
    expect(progression.permanentLinkCostMultiplier, closeTo(0.8, 0.001));
    expect(progression.canUpgradeLinkCostOptimization, isFalse);
    expect(progression.upgradeLinkCostOptimization(), isFalse);
    expect(progression.turretLevelUpOptimizationUpgradeLevel, 20);
    expect(
      progression.permanentTurretLevelUpCostMultiplier,
      closeTo(0.8, 0.001),
    );
    expect(progression.canUpgradeTurretLevelUpOptimization, isFalse);
    expect(progression.upgradeTurretLevelUpOptimization(), isFalse);
  });

  test(
    'advanced economy upgrades unlock at stage nine and multiply existing discounts',
    () async {
      final lockedRepository = MemorySaveRepository()
        ..data = saveWithResearch(
          clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
          researchLevels: const {},
          runes: 1000,
          unlockedStageCount: 9,
        );
      final lockedGame = RuneNexusGame(saveRepository: lockedRepository);
      lockedGame.onGameResize(Vector2(400, 800));
      await lockedGame.onLoad();

      lockedGame.upgradeLinkCostOptimizationProgression();
      lockedGame.upgradeTurretLevelUpOptimizationProgression();

      expect(
        lockedGame.snapshotNotifier.value.linkCostOptimizationUpgradeLevel,
        0,
      );
      expect(
        lockedGame.snapshotNotifier.value.turretLevelUpOptimizationUpgradeLevel,
        0,
      );

      final repository = MemorySaveRepository()
        ..data = saveWithResearch(
          clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9},
          researchLevels: const {ResearchType.linkMaintenance: 10},
          runes: 1000,
          unlockedStageCount: 10,
          linkCostOptimizationUpgradeLevel: 10,
          turretLevelUpOptimizationUpgradeLevel: 10,
        );
      final game = RuneNexusGame(saveRepository: repository);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      final turret = TurretComponent(
        gridPoint: const GridPoint(0, 0),
        definition: gameTurrets[TurretType.arrow]!,
        game: game,
        center: Vector2.zero(),
        tileSize: 32,
      );

      expect(turret.levelUpCost, 38);
      expect(turret.linkUpgradeCost, 65);
      expect(game.snapshotNotifier.value.linkCostOptimizationUpgradeLevel, 10);
      expect(
        game.snapshotNotifier.value.turretLevelUpOptimizationUpgradeLevel,
        10,
      );
    },
  );

  test('stage rune reward bonus scales repeat rewards', () {
    final progression = RunProgression();

    expect(progression.runeRewardFor(0, success: false), 0);
    expect(progression.runeRewardFor(0, success: true), 0);
    expect(progression.runeRewardFor(1, success: false), 2);
    expect(progression.runeRewardFor(10, success: false), 19);
    expect(progression.runeRewardFor(20, success: false), 47);
    expect(progression.runeRewardFor(30, success: false), 89);
    expect(progression.runeRewardFor(40, success: true), 150);
    expect(progression.runeRewardFor(50, success: true), 150);
    expect(progression.runeRewardFor(40, success: true, stageNumber: 2), 180);
    expect(progression.runeRewardFor(40, success: true, stageNumber: 3), 218);
    expect(progression.runeRewardFor(40, success: true, stageNumber: 4), 263);
    expect(progression.runeRewardFor(40, success: true, stageNumber: 5), 315);
    expect(progression.runeRewardFor(40, success: true, stageNumber: 15), 1253);
    expect(progression.runeRewardFor(40, success: true, stageNumber: 16), 1253);

    progression.researchLevels[ResearchType.runeResonance] = 20;
    expect(progression.runeRewardFor(40, success: true), 210);
    expect(progression.runeRewardFor(40, success: true, stageNumber: 8), 725);
  });

  test('stage rune reward bonus applies to first clear rewards', () {
    final progression = RunProgression();

    progression.finishRun(completedRounds: 1, success: true, stageNumber: 2);
    expect(progression.lastRunRuneReward, 2);

    progression.finishRun(completedRounds: 1, success: true, stageNumber: 2);
    expect(progression.lastRunRuneReward, 2);
  });

  test('emergency sale uses five level refund progression', () {
    final progression = RunProgression()..runes = 10000;
    const expectedCosts = [80, 120, 180, 260, 360];

    expect(RunProgression.maxEmergencySaleUpgradeLevel, 5);
    expect(progression.emergencySaleUpgradeCost, expectedCosts.first);

    for (final cost in expectedCosts) {
      expect(progression.emergencySaleUpgradeCost, cost);
      expect(progression.upgradeEmergencySale(), isTrue);
    }

    expect(progression.emergencySaleUpgradeLevel, 5);
    expect(progression.turretRefundPercent, 80);
    expect(progression.emergencySaleUpgradeCost, 360);
    expect(progression.canUpgradeEmergencySale, isFalse);
    expect(progression.upgradeEmergencySale(), isFalse);
  });

  test('permanent emergency sale unlocks after stage one clear', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 1,
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
    game.upgradeEmergencySaleProgression();

    expect(game.snapshotNotifier.value.clearedStageNumbers, isNot(contains(1)));
    expect(game.snapshotNotifier.value.emergencySaleUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.canUpgradeEmergencySale, isFalse);
    expect(game.snapshotNotifier.value.turretRefundPercent, 75);

    game.startStage(1);
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(1));
    expect(game.snapshotNotifier.value.canUpgradeEmergencySale, isTrue);
  });

  test('emergency sale upgrade increases turret refund gold', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 3,
      );
    final game = LinkResearchUnlockedGame(
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
    game.upgradeEmergencySaleProgression();
    game.restartRun();

    game.tryBuildTurret(const GridPoint(2, 0));
    game.levelUpSelectedTurret();
    game.debugAddGold(100);
    game.upgradeSelectedTurretLink();

    expect(game.snapshotNotifier.value.turretRefundPercent, 76);
    expect(game.snapshotNotifier.value.selectedTurretRefundGold, 145);
    game.refundSelectedTurret();

    expect(game.snapshotNotifier.value.gold, 223);
  });

  test('new permanent upgrades are saved and restored', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8, 9},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 10,
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
    game.upgradeSupplyProgression();
    game.upgradeFireTrainingProgression();
    game.upgradePhysicalDamageTrainingProgression();
    game.upgradeElementalDamageTrainingProgression();
    game.upgradeCriticalChanceProgression();
    game.upgradeCriticalDamageProgression();
    game.upgradeKillGoldProgression();
    game.upgradeEmergencySaleProgression();
    game.upgradeLinkCostOptimizationProgression();
    game.upgradeTurretLevelUpOptimizationProgression();
    expect(game.snapshotNotifier.value.linkCostOptimizationUpgradeLevel, 1);
    expect(
      game.snapshotNotifier.value.turretLevelUpOptimizationUpgradeLevel,
      1,
    );
    await game.saveNow();

    final restoredRepository = MemorySaveRepository()..data = repository.data;
    final restored = RuneNexusGame(saveRepository: restoredRepository);
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();

    final snapshot = restored.snapshotNotifier.value;
    expect(snapshot.supplyUpgradeLevel, 1);
    expect(snapshot.waveClearGoldProgressionBonus, 1);
    expect(snapshot.fireTrainingUpgradeLevel, 1);
    expect(snapshot.fireTrainingDamageBonusRate, closeTo(0.015, 0.001));
    expect(snapshot.physicalDamageTrainingUpgradeLevel, 1);
    expect(snapshot.physicalDamageTrainingBonusRate, closeTo(0.02, 0.001));
    expect(snapshot.elementalDamageTrainingUpgradeLevel, 1);
    expect(snapshot.elementalDamageTrainingBonusRate, closeTo(0.02, 0.001));
    expect(snapshot.criticalChanceUpgradeLevel, 1);
    expect(snapshot.criticalChanceProgressionBonusRate, closeTo(0.01, 0.001));
    expect(snapshot.criticalDamageUpgradeLevel, 1);
    expect(snapshot.criticalDamageProgressionBonusRate, closeTo(0.01, 0.001));
    expect(snapshot.killGoldUpgradeLevel, 1);
    expect(snapshot.killGoldProgressionBonusRate, closeTo(0.01, 0.001));
    expect(snapshot.emergencySaleUpgradeLevel, 1);
    expect(snapshot.turretRefundPercent, 76);
    expect(snapshot.linkCostOptimizationUpgradeLevel, 1);
    expect(snapshot.turretLevelUpOptimizationUpgradeLevel, 1);
  });

  test(
    'run upgrades and fractional gold wallet are saved and restored',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(saveRepository: repository);

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.buyRunUpgrade(RunUpgradeType.towerDamage);
      game.buyRunUpgrade(RunUpgradeType.killGold);
      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 1,
        path: [Vector2.zero(), Vector2(1, 0)],
        game: game,
      );
      game.enemies.add(enemy);
      enemy.receiveDamage(999);
      await game.saveNow();

      final restoredRepository = MemorySaveRepository()..data = repository.data;
      final restored = RuneNexusGame(saveRepository: restoredRepository);
      restored.onGameResize(Vector2(400, 800));
      await restored.onLoad();

      final snapshot = restored.snapshotNotifier.value;
      expect(snapshot.phase, GamePhase.preparation);
      expect(snapshot.runUpgradeLevels[RunUpgradeType.towerDamage], 1);
      expect(snapshot.runUpgradeLevels[RunUpgradeType.killGold], 1);
      expect(snapshot.killGoldFractionWallet, closeTo(0.1, 0.001));
      expect(snapshot.towerDamageRunBonusRate, closeTo(0.03, 0.001));
    },
  );
}
