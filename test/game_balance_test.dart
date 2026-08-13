import 'dart:math' as math;

import 'helpers/game_balance_test_helpers.dart';

void main() {
  test('game stage uses 40 survival rounds', () {
    expect(gameStages, hasLength(15));
    expect(gameStages.first.id, 1);
    expect(gameStages.last.id, 15);
    expect(gameWaves, hasLength(40));
    expect(gameWaves.first.round, 1);
    expect(gameWaves.last.round, 40);
    expect(gameStage2Waves, hasLength(40));
    expect(gameStage2Waves.first.round, 1);
    expect(gameStage2Waves.last.round, 40);
    expect(gameChapter2Waves, hasLength(40));
    expect(gameChapter2Waves.first.round, 1);
    expect(gameChapter2Waves.last.round, 40);
    expect(gameChapter2Stage7Waves, hasLength(40));
    expect(gameChapter2Stage8Waves, hasLength(40));
    expect(gameChapter2Stage9Waves, hasLength(40));
    expect(gameChapter2Stage10Waves, hasLength(40));
    expect(gameChapter3Waves, hasLength(40));
    expect(gameChapter3Stage12Waves, hasLength(40));
    expect(gameChapter3Stage13Waves, hasLength(40));
    expect(gameChapter3Stage14Waves, hasLength(40));
    expect(gameChapter3Stage15Waves, hasLength(40));
    expect(gameStages.first.map.tileTheme.kind, MapTileThemeKind.chapterOne);
    expect(gameStages[1].map.tileTheme.kind, MapTileThemeKind.chapterOne);
    expect(gameStages[1].waves, same(gameStage2Waves));
    expect(gameStages[2].waves, same(gameStage2Waves));
    expect(gameStages[3].waves, same(gameStage2Waves));
    expect(gameStages[4].waves, same(gameStage2Waves));
    expect(gameStages[5].waves, same(gameChapter2Waves));
    expect(gameStages[6].waves, same(gameChapter2Stage7Waves));
    expect(gameStages[7].waves, same(gameChapter2Stage8Waves));
    expect(gameStages[8].waves, same(gameChapter2Stage9Waves));
    expect(gameStages[9].waves, same(gameChapter2Stage10Waves));
    expect(gameStages[10].waves, same(gameChapter3Waves));
    expect(gameStages[11].waves, same(gameChapter3Stage12Waves));
    expect(gameStages[12].waves, same(gameChapter3Stage13Waves));
    expect(gameStages[13].waves, same(gameChapter3Stage14Waves));
    expect(gameStages[14].waves, same(gameChapter3Stage15Waves));
    expect(gameStages[5].map.tileTheme.kind, MapTileThemeKind.chapterTwoRift);
    expect(gameStages[9].map.tileTheme.kind, MapTileThemeKind.chapterTwoRift);
    expect(
      gameStages[10].map.tileTheme.kind,
      MapTileThemeKind.chapterThreeForge,
    );
    expect(
      gameStages[14].map.tileTheme.kind,
      MapTileThemeKind.chapterThreeForge,
    );
  });

  test('boss waves spawn exactly one boss in every stage', () {
    for (final stage in gameStages) {
      for (final wave in stage.waves.where((wave) => wave.round % 10 == 0)) {
        final bossCount = wave.groups
            .where((group) => group.enemyType.isBoss)
            .fold<int>(0, (total, group) => total + group.count);

        expect(bossCount, 1, reason: 'Stage ${stage.id} round ${wave.round}');
      }
    }
  });

  test('chapter two maps use altered paths with rift theme', () {
    final chapterOneMaps = [
      gameMap,
      gameStage2Map,
      stage3Map,
      stage4Map,
      stage5Map,
    ];
    final chapterTwoMaps = [
      chapterTwoStage6Map,
      chapterTwoStage7Map,
      chapterTwoStage8Map,
      chapterTwoStage9Map,
      chapterTwoStage10Map,
    ];

    for (var i = 0; i < chapterTwoMaps.length; i++) {
      final source = chapterOneMaps[i];
      final chapterTwo = chapterTwoMaps[i];
      expect(chapterTwo.columns, source.columns);
      expect(chapterTwo.rows, source.rows);
      expect(chapterTwo.tileTheme.kind, MapTileThemeKind.chapterTwoRift);
      expect(chapterTwo.path, isNot(orderedEquals(source.path)));
      expectValidMapPath(chapterTwo);
    }
  });

  test('chapter three maps use forge theme and distinct layouts', () {
    final chapterTwoMaps = [
      chapterTwoStage6Map,
      chapterTwoStage7Map,
      chapterTwoStage8Map,
      chapterTwoStage9Map,
      chapterTwoStage10Map,
    ];
    final chapterThreeMaps = [
      chapterThreeStage11Map,
      chapterThreeStage12Map,
      chapterThreeStage13Map,
      chapterThreeStage14Map,
      chapterThreeStage15Map,
    ];

    for (var i = 0; i < chapterThreeMaps.length; i++) {
      final source = chapterTwoMaps[i];
      final chapterThree = chapterThreeMaps[i];
      expect(chapterThree.columns, source.columns);
      expect(chapterThree.rows, source.rows);
      expect(chapterThree.tileTheme.kind, MapTileThemeKind.chapterThreeForge);
      expect(chapterThree.path, isNot(orderedEquals(source.path)));
      expectValidMapPath(chapterThree);
    }
  });

  test('stage definitions select their own wave data', () {
    final stage1 = StageDefinition(
      id: 1,
      name: 'Stage 1',
      map: gameMap,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'stage one',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
      firstClearCorePointReward: 1,
    );
    final stage2 = StageDefinition(
      id: 2,
      name: 'Stage 2',
      map: gameMap,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'stage two first',
          groups: [],
          clearRewardGold: 0,
        ),
        WaveDefinition(
          round: 2,
          previewText: 'stage two second',
          groups: [],
          clearRewardGold: 0,
        ),
      ],
      firstClearCorePointReward: 1,
    );
    final game = RuneNexusGame(stages: [stage1, stage2]);

    expect(game.snapshotNotifier.value.currentStageNumber, 1);
    expect(game.snapshotNotifier.value.maxRound, 1);
    expect(game.snapshotNotifier.value.previewText, 'stage one');

    game.startNextWave();
    game.update(0.016);
    game.startStage(2);

    expect(game.snapshotNotifier.value.currentStageNumber, 2);
    expect(game.snapshotNotifier.value.maxRound, 2);
    expect(game.snapshotNotifier.value.previewText, 'stage two first');
  });

  test('initial gold supports machine gun and cannon setup', () {
    final game = RuneNexusGame();

    expect(game.snapshotNotifier.value.gold, 170);
  });

  test('gem reward appears every five completed rounds', () {
    final game = RuneNexusGame(
      waves: List<WaveDefinition>.generate(
        6,
        (index) => WaveDefinition(
          round: index + 1,
          previewText: 'test',
          groups: const [],
          clearRewardGold: 0,
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      game.startNextWave();
      game.update(0.016);
      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    }

    game.startNextWave();
    game.update(0.016);

    final rewardSnapshot = game.snapshotNotifier.value;
    expect(rewardSnapshot.phase, GamePhase.reward);
    expect(rewardSnapshot.completedRounds, 5);
    expect(rewardSnapshot.rewardOptions, hasLength(3));

    game.selectRewardGem(rewardSnapshot.rewardOptions.first);

    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.gemInventory.values.single, 1);
  });

  test('purchased gem choice spends shards immediately', () {
    final game = RuneNexusGame(
      waves: List<WaveDefinition>.generate(
        21,
        (index) => WaveDefinition(
          round: index + 1,
          previewText: 'test',
          groups: const [],
          clearRewardGold: 0,
        ),
      ),
    );

    for (
      var completedRound = 0;
      game.snapshotNotifier.value.gemShards <
              RuneNexusGame.gemChoicePurchaseCost &&
          completedRound < game.snapshotNotifier.value.maxRound;
      completedRound++
    ) {
      game.startNextWave();
      game.update(0.016);
      final snapshot = game.snapshotNotifier.value;
      if (snapshot.phase == GamePhase.reward) {
        game.selectRewardGem(snapshot.rewardOptions.first);
      }
    }

    expect(
      game.snapshotNotifier.value.gemShards,
      RuneNexusGame.gemChoicePurchaseCost,
    );

    game.purchaseGemChoice();

    final purchaseSnapshot = game.snapshotNotifier.value;
    expect(purchaseSnapshot.phase, GamePhase.reward);
    expect(purchaseSnapshot.isPurchasedGemReward, isTrue);
    expect(purchaseSnapshot.gemShards, 0);

    final selectedGem = purchaseSnapshot.rewardOptions.first;
    final beforeSelectedGemCount =
        purchaseSnapshot.gemInventory[selectedGem] ?? 0;

    game.selectRewardGem(selectedGem);

    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.gemShards, 0);
    expect(
      game.snapshotNotifier.value.gemInventory[selectedGem],
      beforeSelectedGemCount + 1,
    );
  });

  test('purchased gem choice can be selected during combat', () {
    final game = RuneNexusGame(
      waves: List<WaveDefinition>.generate(
        21,
        (index) => WaveDefinition(
          round: index + 1,
          previewText: 'test',
          groups: const [],
          clearRewardGold: 0,
        ),
      ),
    );

    for (
      var completedRound = 0;
      game.snapshotNotifier.value.gemShards <
              RuneNexusGame.gemChoicePurchaseCost &&
          completedRound < game.snapshotNotifier.value.maxRound;
      completedRound++
    ) {
      game.startNextWave();
      game.update(0.016);
      final snapshot = game.snapshotNotifier.value;
      if (snapshot.phase == GamePhase.reward) {
        game.selectRewardGem(snapshot.rewardOptions.first);
      }
    }

    expect(
      game.snapshotNotifier.value.gemShards,
      RuneNexusGame.gemChoicePurchaseCost,
    );

    game.startNextWave();
    expect(game.snapshotNotifier.value.phase, GamePhase.wave);

    expect(game.purchaseGemChoice(), isTrue);

    final purchaseSnapshot = game.snapshotNotifier.value;
    expect(purchaseSnapshot.phase, GamePhase.reward);
    expect(purchaseSnapshot.isPurchasedGemReward, isTrue);

    final selectedGem = purchaseSnapshot.rewardOptions.first;
    game.selectRewardGem(selectedGem);

    expect(game.snapshotNotifier.value.phase, GamePhase.wave);
    expect(game.snapshotNotifier.value.gemInventory[selectedGem], isNotNull);
  });

  test('purchased gem reward pauses active combat updates', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        gemShards: RuneNexusGame.gemChoicePurchaseCost,
        phase: GamePhase.wave,
        mapSignature: const GameSaveAdapter().mapSignature(gameMap),
      );
    final game = RuneNexusGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.continueRestoredRun();

    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    game.enemies.add(enemy);
    await game.add(enemy);
    final previousDistance = enemy.distanceTravelled;

    expect(game.purchaseGemChoice(), isTrue);
    await game.saveNow();
    game.update(1);

    expect(game.snapshotNotifier.value.phase, GamePhase.reward);
    expect(repository.data!.activeRun!.rewardReturnPhase, GamePhase.wave);
    expect(enemy.distanceTravelled, previousDistance);
  });

  test('combat gem reward restore resumes wave after selection', () async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        gemShards: RuneNexusGame.gemChoicePurchaseCost,
        roundIndex: 1,
        mapSignature: const GameSaveAdapter().mapSignature(gameMap),
      );
    final game = RuneNexusGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();

    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    game.enemies.add(enemy);
    await game.add(enemy);

    expect(game.purchaseGemChoice(), isTrue);
    await game.saveNow();

    final saved = repository.data!;
    expect(saved.activeRun!.phase, GamePhase.reward);
    expect(saved.activeRun!.rewardReturnPhase, GamePhase.wave);
    expect(saved.activeRun!.enemies, isNotEmpty);

    final legacyJson = Map<String, Object?>.of(saved.toJson());
    final legacyRunJson = Map<String, Object?>.of(
      legacyJson['activeRun']! as Map<String, Object?>,
    )..remove('rewardReturnPhase');
    legacyJson['activeRun'] = legacyRunJson;
    final parsedLegacySave = GameSaveData.fromJson(legacyJson)!;
    expect(parsedLegacySave.activeRun!.rewardReturnPhase, GamePhase.wave);

    final restoredRepository = MemorySaveRepository()..data = parsedLegacySave;
    final restored = RuneNexusGame(saveRepository: restoredRepository);
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();

    final rewardSnapshot = restored.snapshotNotifier.value;
    expect(rewardSnapshot.phase, GamePhase.reward);
    expect(rewardSnapshot.isPurchasedGemReward, isTrue);
    expect(restored.enemies, hasLength(1));

    final restoredEnemy = restored.enemies.single;
    final pausedDistance = restoredEnemy.distanceTravelled;
    restored.update(1);
    expect(restoredEnemy.distanceTravelled, pausedDistance);

    restored.selectRewardGem(rewardSnapshot.rewardOptions.first);
    expect(restored.snapshotNotifier.value.phase, GamePhase.wave);
    restored.update(1);
    expect(restoredEnemy.distanceTravelled, greaterThan(pausedDistance));
  });

  test('auto start can continue non-boss preparation rounds', () {
    final game = RuneNexusGame(
      waves: List<WaveDefinition>.generate(
        2,
        (index) => WaveDefinition(
          round: index + 1,
          previewText: 'test',
          groups: const [],
          clearRewardGold: 0,
        ),
      ),
    );

    game.setAutoStartMode(AutoStartMode.fullAuto);

    expect(game.snapshotNotifier.value.autoStartMode, AutoStartMode.fullAuto);
    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.round, 1);

    game.update(0.016);
    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);

    game.startNextWave();
    expect(game.snapshotNotifier.value.phase, GamePhase.wave);

    game.update(0.016);
    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.round, 2);

    game.update(0.016);
    expect(game.snapshotNotifier.value.phase, GamePhase.wave);
  });

  test('auto start keeps selected turret upgrade panel open', () async {
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      waves: List<WaveDefinition>.generate(
        2,
        (index) => WaveDefinition(
          round: index + 1,
          previewText: 'test',
          groups: const [],
          clearRewardGold: 0,
        ),
      ),
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    const selectedPoint = GridPoint(2, 0);
    game.tryBuildTurret(selectedPoint);
    game.debugAddGold(200);
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.round, 2);
    game.previewOrLevelUpSelectedTurret();
    expect(
      game.snapshotNotifier.value.selectedTurretLevelUpPreviewActive,
      isTrue,
    );

    game.setAutoStartMode(AutoStartMode.fullAuto);

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.wave);
    expect(snapshot.selectedTurretPoint, selectedPoint);
    expect(snapshot.selectedTurretLevelUpPreviewActive, isTrue);
  });

  test('auto start keeps turret placement panel open', () async {
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      waves: List<WaveDefinition>.generate(
        2,
        (index) => WaveDefinition(
          round: index + 1,
          previewText: 'test',
          groups: const [],
          clearRewardGold: 0,
        ),
      ),
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    const buildPoint = GridPoint(2, 0);
    game.tryBuildTurret(buildPoint);
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.round, 2);
    game.previewOrBuildSelectedTile(TurretType.cannon);
    expect(
      game.snapshotNotifier.value.selectedBuildTurretType,
      TurretType.cannon,
    );

    game.setAutoStartMode(AutoStartMode.fullAuto);

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.wave);
    expect(snapshot.selectedBuildTurretType, TurretType.cannon);
    expect(snapshot.selectedTurretPoint, isNull);
  });

  test('auto start can pause before boss rounds', () {
    final game = RuneNexusGame(
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'normal',
          groups: [],
          clearRewardGold: 0,
        ),
        WaveDefinition(
          round: 2,
          previewText: 'boss',
          groups: [
            SpawnGroup(enemyType: EnemyType.boss, count: 1, interval: 1),
          ],
          clearRewardGold: 0,
        ),
      ],
    );

    game.setAutoStartMode(AutoStartMode.skipBossRounds);

    expect(
      game.snapshotNotifier.value.autoStartMode,
      AutoStartMode.skipBossRounds,
    );
    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.round, 1);

    game.startNextWave();
    game.update(0.016);
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.round, 2);
  });

  test('abandoning an active run settles failure rewards', () async {
    final game = RuneNexusGame(
      waves: List<WaveDefinition>.generate(
        3,
        (index) => WaveDefinition(
          round: index + 1,
          previewText: 'test',
          groups: const [],
          clearRewardGold: 0,
        ),
      ),
    );

    game.startNextWave();
    game.update(0.016);
    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.completedRounds, 1);

    await game.settleCurrentRunAsFailure();

    expect(game.snapshotNotifier.value.phase, GamePhase.failure);
    expect(game.snapshotNotifier.value.completedRounds, 1);
    expect(game.snapshotNotifier.value.lastRunRuneReward, 2);
    expect(game.snapshotNotifier.value.runes, 2);
    expect(game.snapshotNotifier.value.bestRoundsByStage[1], 1);
    expect(game.snapshotNotifier.value.clearedStageNumbers, isNot(contains(1)));
  });

  test('abandoning before clearing any round grants no runes', () async {
    final game = RuneNexusGame(
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [
            SpawnGroup(enemyType: EnemyType.normal, count: 1, interval: 1),
          ],
          clearRewardGold: 0,
        ),
      ],
    );

    game.startNextWave();

    expect(game.snapshotNotifier.value.phase, GamePhase.wave);
    expect(game.snapshotNotifier.value.completedRounds, 0);
    expect(game.snapshotNotifier.value.projectedFailureRuneReward, 0);

    await game.settleCurrentRunAsFailure();

    expect(game.snapshotNotifier.value.phase, GamePhase.failure);
    expect(game.snapshotNotifier.value.completedRounds, 0);
    expect(game.snapshotNotifier.value.lastRunRuneReward, 0);
    expect(game.snapshotNotifier.value.runes, 0);
    expect(game.snapshotNotifier.value.bestRoundsByStage[1], isNull);
    expect(game.snapshotNotifier.value.clearedStageNumbers, isNot(contains(1)));
  });

  testWidgets('nexus defeat plays core destruction before failure panel', (
    tester,
  ) async {
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
    await tester.pumpWidget(GameWidget(game: game));
    await tester.runAsync(game.ready);
    game.startNextWave();

    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: EnemyDefinition(
        type: EnemyType.normal,
        name: 'Core Breaker',
        maxHp: 100,
        speed: normal.speed,
        rewardGold: 0,
        coreDamage: 20,
        color: normal.color,
        resistanceProfile: normal.resistanceProfile,
      ),
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    final lingeringEnemy = EnemyComponent(
      definition: EnemyDefinition(
        type: EnemyType.normal,
        name: 'Lingering Invader',
        maxHp: 100,
        speed: normal.speed,
        rewardGold: 0,
        coreDamage: 1,
        color: normal.color,
        resistanceProfile: normal.resistanceProfile,
      ),
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    game.enemies.add(enemy);
    game.enemies.add(lingeringEnemy);
    await game.add(enemy);
    await game.add(lingeringEnemy);
    game.update(0);

    game.enemyReachedCore(enemy);

    expect(game.snapshotNotifier.value.nexusHp, 0);
    expect(game.snapshotNotifier.value.phase, GamePhase.coreDestruction);
    await game.saveNow();
    expect(repository.data?.activeRun?.phase, GamePhase.failure);
    expect(game.enemies, contains(lingeringEnemy));

    final restoredGame = RuneNexusGame(saveRepository: repository);
    restoredGame.onGameResize(Vector2(400, 800));
    await restoredGame.onLoad();
    restoredGame.continueRestoredRun();

    expect(restoredGame.snapshotNotifier.value.phase, GamePhase.failure);

    game.update(1.6);

    expect(game.snapshotNotifier.value.phase, GamePhase.coreDestruction);
    expect(game.debugBoardZoom(), greaterThan(1));
    expect(game.enemies, contains(lingeringEnemy));

    game.update(1.7);

    expect(game.snapshotNotifier.value.phase, GamePhase.failure);
    expect(game.snapshotNotifier.value.completedRounds, 0);
    expect(game.snapshotNotifier.value.lastRunRuneReward, 0);
    expect(game.debugBoardZoom(), greaterThan(1));
    expect(game.enemies, isNot(contains(lingeringEnemy)));

    game.restartRun();

    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.debugBoardZoom(), 1);
    expect(game.debugBoardOffset().length2, 0);
  });

  test('enemy hp scaling grows by round', () {
    final normal = gameEnemies[EnemyType.normal]!;
    final round1Hp = scaledEnemyMaxHp(normal, 1);
    final round25Hp = scaledEnemyMaxHp(normal, 25);
    final round50Hp = scaledEnemyMaxHp(normal, 50);

    expect(round25Hp, greaterThan(round1Hp));
    expect(round50Hp, greaterThan(round25Hp));
  });

  test('enemy hp roughly doubles every 10 rounds', () {
    expect(enemyHpMultiplierForRound(1), closeTo(1, 0.001));
    expect(enemyHpMultiplierForRound(11), closeTo(2, 0.001));
    expect(enemyHpMultiplierForRound(21), closeTo(4, 0.001));
  });

  test('enemy hp scales by stage', () {
    final normal = gameEnemies[EnemyType.normal]!;

    expect(enemyHpMultiplierForStage(1), closeTo(1, 0.001));
    expect(enemyHpMultiplierForStage(2), closeTo(1.2, 0.001));
    expect(enemyHpMultiplierForStage(5), closeTo(2.0736, 0.001));
    expect(enemyHpMultiplierForStage(10), closeTo(5.1598, 0.001));
    expect(enemyHpMultiplierForStage(15), closeTo(12.8392, 0.001));
    expect(enemyHpMultiplierForStage(16), closeTo(12.8392, 0.001));
    expect(scaledEnemyMaxHp(normal, 1, stageNumber: 2), closeTo(42, 0.001));
  });

  test('projectiles are faster for straight-shot combat', () {
    expect(gameTurrets[TurretType.arrow]!.projectileSpeed, 620);
    expect(gameTurrets[TurretType.cannon]!.projectileSpeed, 340);
    expect(gameTurrets[TurretType.magic]!.projectileSpeed, 420);
    expect(gameTurrets[TurretType.frost]!.projectileSpeed, 0);
    expect(gameTurrets[TurretType.sniper]!.projectileSpeed, 0);
    expect(gameTurrets[TurretType.lightning]!.projectileSpeed, 0);
  });

  test('enemy movement speeds are tuned down for readable combat', () {
    expect(gameEnemies[EnemyType.normal]!.speed, 31.5);
    expect(gameEnemies[EnemyType.armored]!.speed, 28);
    expect(gameEnemies[EnemyType.shielded]!.speed, 29);
    expect(gameEnemies[EnemyType.fast]!.speed, 54.6);
    expect(gameEnemies[EnemyType.tank]!.speed, 21);
    expect(gameEnemies[EnemyType.boss]!.speed, 16.8);
    expect(gameEnemies[EnemyType.forgeBoss]!.speed, 13.5);
  });

  test('turret base ranges are reduced to tighten placement choices', () {
    expect(gameTurrets[TurretType.arrow]!.range, 96);
    expect(gameTurrets[TurretType.cannon]!.range, 84);
    expect(gameTurrets[TurretType.magic]!.range, 108);
    expect(gameTurrets[TurretType.frost]!.range, 76);
    expect(gameTurrets[TurretType.sniper]!.range, 150);
    expect(gameTurrets[TurretType.lightning]!.range, 112);
  });

  test('runtime combat distances scale with board tile size', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.tryBuildTurret(const GridPoint(2, 0));
    final turret = game.children.whereType<TurretComponent>().single;
    final expectedTileSize = game.debugBoardSize().x / gameMap.columns;
    final expectedScale = expectedTileSize / 48;

    expect(game.boardDistanceScale, closeTo(expectedScale, 0.001));
    expect(turret.range, closeTo(96 * expectedScale, 0.001));
  });

  test('enemy movement speed scales with board tile size', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final normal = gameEnemies[EnemyType.normal]!;

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(200, 0)],
      game: game,
    );

    enemy.update(1);

    expect(enemy.position.x, closeTo(31.5 * game.boardDistanceScale, 0.001));
  });

  test('spawned enemies use type-specific board size immediately', () async {
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [
            SpawnGroup(enemyType: EnemyType.tank, count: 1, interval: 1),
          ],
          clearRewardGold: 0,
        ),
      ],
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.setSpeedMultiplier(0);
    game.startNextWave();
    game.update(0.016);

    expect(game.enemies, hasLength(1));
    expect(
      game.enemies.single.size.x,
      closeTo(48 * game.boardDistanceScale * 0.65, 0.001),
    );
  });

  test('board pan room scales with wide map size', () async {
    final game = RuneNexusGame(
      stage: gameStages[1],
      saveRepository: MemorySaveRepository(),
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    final tileSize = game.boardDistanceScale * 48;
    final panLimit = game.debugBoardPanLimit();

    expect(panLimit.x, closeTo(70.4, 0.001));
    expect(panLimit.x, greaterThan(tileSize * 1.5));
  });

  test('wide maps frame active board area with horizontal padding', () async {
    final game = RuneNexusGame(
      stage: gameStages[1],
      saveRepository: MemorySaveRepository(),
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    final origin = game.debugActiveBoardOrigin();
    final boardSize = game.debugActiveBoardSize();

    expect(origin.x, closeTo(24, 0.001));
    expect(origin.x + boardSize.x, closeTo(376, 0.001));
  });

  test('stage start resets board pan offset', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.handleBoardPointerDown(
      const PointerDownEvent(pointer: 1, position: Offset(200, 200)),
    );
    game.handleBoardPointerMove(
      const PointerMoveEvent(pointer: 1, position: Offset(235, 200)),
    );
    game.handleBoardPointerUp(
      const PointerUpEvent(pointer: 1, position: Offset(235, 200)),
    );

    expect(game.debugBoardOffset().x, greaterThan(0));

    game.startStage(1);

    expect(game.debugBoardZoom(), 1);
    expect(game.debugBoardOffset().length2, 0);
  });

  test('turret fire rate is represented as shots per second', () {
    expect(gameTurrets[TurretType.arrow]!.attackRate, 2.27);
    expect(gameTurrets[TurretType.cannon]!.attackRate, 0.4);
    expect(gameTurrets[TurretType.magic]!.attackRate, 0.59);
    expect(gameTurrets[TurretType.frost]!.attackRate, 0.4);
    expect(gameTurrets[TurretType.sniper]!.attackRate, 0.625);
    expect(gameTurrets[TurretType.lightning]!.attackRate, 0.55);
  });

  test('sniper turret unlocks after stage three clear', () {
    final game = RuneNexusGame(
      stage: StageDefinition(
        id: 3,
        name: 'Stage 3',
        map: gameMap,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
        firstClearCorePointReward: 0,
      ),
    );

    expect(
      game.snapshotNotifier.value.availableTurretTypes,
      isNot(contains(TurretType.sniper)),
    );

    game.selectTurretType(TurretType.sniper);
    expect(game.snapshotNotifier.value.selectedTurretType, TurretType.arrow);

    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.success);
    expect(game.snapshotNotifier.value.lastRunUnlockedSniperTurret, isTrue);
    expect(
      game.snapshotNotifier.value.availableTurretTypes,
      contains(TurretType.sniper),
    );
  });

  test('chain lightning turret unlocks after stage six clear', () {
    final game = RuneNexusGame(
      stage: StageDefinition(
        id: 6,
        name: 'Stage 6',
        map: gameMap,
        waves: const [
          WaveDefinition(
            round: 1,
            previewText: 'test',
            groups: [],
            clearRewardGold: 0,
          ),
        ],
        firstClearCorePointReward: 0,
      ),
    );

    expect(
      game.snapshotNotifier.value.availableTurretTypes,
      isNot(contains(TurretType.lightning)),
    );
    expect(gameTurrets[TurretType.lightning]!.cost, 140);
    expect(gameTurrets[TurretType.lightning]!.damage, 24);
    expect(
      gameTurrets[TurretType.lightning]!.damageFamily,
      DamageFamily.elemental,
    );
    expect(
      gameTurrets[TurretType.lightning]!.attackTags,
      contains(AttackTag.heavy),
    );

    game.selectTurretType(TurretType.lightning);
    expect(game.snapshotNotifier.value.selectedTurretType, TurretType.arrow);

    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.success);
    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(6));
    expect(
      game.snapshotNotifier.value.availableTurretTypes,
      contains(TurretType.lightning),
    );
  });

  test('turrets use base critical stats and sniper bonus', () {
    for (final entry in gameTurrets.entries) {
      final expectedChance = entry.key == TurretType.sniper ? 0.15 : 0.05;
      final expectedMultiplier = entry.key == TurretType.sniper ? 2.0 : 1.5;
      expect(entry.value.criticalChance, closeTo(expectedChance, 0.001));
      expect(
        entry.value.criticalDamageMultiplier,
        closeTo(expectedMultiplier, 0.001),
      );
    }
  });

  test('sniper turret uses aim time and critical instant hit stats', () {
    final sniper = gameTurrets[TurretType.sniper]!;

    expect(sniper.instantHit, isTrue);
    expect(sniper.damage, closeTo(40, 0.001));
    expect(sniper.aimDuration, closeTo(1, 0.001));
    expect(sniper.criticalChance, closeTo(0.15, 0.001));
    expect(sniper.criticalDamageMultiplier, closeTo(2.0, 0.001));
  });

  test('sniper aim speed grows additively by level', () {
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.sniper]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(turret.aimDuration, closeTo(1, 0.001));

    turret.upgradeLevel();
    turret.upgradeLevel();

    expect(turret.level, 3);
    expect(turret.aimDuration, closeTo(1 / 1.16, 0.001));

    turret.equipGem(GemType.aimSpeed, 0);

    expect(turret.aimDuration, closeTo(1 / 1.91, 0.001));
  });

  test('turret target priority selects the configured combat target', () async {
    final expectedTargets = {
      TurretTargetPriority.first: 'front',
      TurretTargetPriority.last: 'back',
      TurretTargetPriority.strongest: 'strong',
      TurretTargetPriority.weakest: 'weak',
      TurretTargetPriority.nearest: 'near',
    };

    for (final entry in expectedTargets.entries) {
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
      final turret = TurretComponent(
        gridPoint: const GridPoint(0, 0),
        definition: targetPriorityTestTurret,
        game: game,
        center: Vector2(100, 100),
        tileSize: 32,
      )..setTargetPriority(entry.key);
      final enemies = {
        'front': targetPriorityEnemy(
          game: game,
          hp: 100,
          progress: 90,
          position: turret.position + Vector2(70, 0),
        ),
        'back': targetPriorityEnemy(
          game: game,
          hp: 100,
          progress: 10,
          position: turret.position + Vector2(65, 0),
        ),
        'strong': targetPriorityEnemy(
          game: game,
          hp: 200,
          progress: 50,
          position: turret.position + Vector2(60, 0),
        ),
        'weak': targetPriorityEnemy(
          game: game,
          hp: 20,
          progress: 50,
          position: turret.position + Vector2(55, 0),
        ),
        'near': targetPriorityEnemy(
          game: game,
          hp: 100,
          progress: 50,
          position: turret.position + Vector2(20, 0),
        ),
      };

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      await game.add(turret);
      for (final enemy in enemies.values) {
        await game.add(enemy);
      }
      game.update(0);
      game.enemies.addAll(enemies.values);
      game.startNextWave();

      turret.update(0.016);

      for (final enemyEntry in enemies.entries) {
        final expectedHp = enemyEntry.key == entry.value
            ? enemyEntry.value.maxHp - targetPriorityTestTurret.damage
            : enemyEntry.value.maxHp;
        expect(
          enemyEntry.value.hp,
          closeTo(expectedHp, 0.001),
          reason: '${entry.key.name} should hit ${entry.value}',
        );
      }
    }
  });

  test('selected turret target priority requires completed research', () async {
    final lockedRepository = MemorySaveRepository();
    final lockedGame = RuneNexusGame(saveRepository: lockedRepository);

    lockedGame.onGameResize(Vector2(400, 800));
    await lockedGame.onLoad();
    lockedGame.tryBuildTurret(const GridPoint(2, 0));

    expect(
      lockedGame.snapshotNotifier.value.canSetTurretTargetPriority,
      isFalse,
    );
    expect(
      lockedGame.snapshotNotifier.value.selectedTurretTargetPriority,
      TurretTargetPriority.first,
    );

    lockedGame.setSelectedTurretTargetPriority(TurretTargetPriority.strongest);

    expect(
      lockedGame.snapshotNotifier.value.selectedTurretTargetPriority,
      TurretTargetPriority.first,
    );

    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {3},
        researchLevels: const {ResearchType.turretTargetPriority: 1},
      );
    final game = RuneNexusGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.tryBuildTurret(const GridPoint(2, 0));

    expect(game.snapshotNotifier.value.canSetTurretTargetPriority, isTrue);

    game.setSelectedTurretTargetPriority(TurretTargetPriority.strongest);
    await game.saveNow();

    final saved = repository.data;
    final restoredTurret = TurretComponent(
      gridPoint: const GridPoint(2, 0),
      definition: gameTurrets[saved!.activeRun!.turrets.single.type]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..restoreFromSaveData(saved.activeRun!.turrets.single);

    expect(
      game.snapshotNotifier.value.selectedTurretTargetPriority,
      TurretTargetPriority.strongest,
    );
    expect(
      saved.activeRun!.turrets.single.targetPriority,
      TurretTargetPriority.strongest,
    );
    expect(restoredTurret.targetPriority, TurretTargetPriority.strongest);
  });

  test('turret level cap grows to 10 without excessive range gain', () {
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    while (turret.canLevelUp) {
      expect(turret.upgradeLevel(), isTrue);
    }

    expect(turret.level, 10);
    expect(turret.maxLevel, 10);
    expect(turret.range, closeTo(124.512, 0.001));
    expect(turret.damage, closeTo(36.118, 0.001));
    expect(turret.attackRate, closeTo(3.5215, 0.001));
  });

  test('range gem amplifies turret range by percent', () {
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    turret.equipGem(GemType.range, 0);

    expect(turret.range, closeTo(115.2, 0.001));
  });

  test('turret range check includes rough enemy body radius', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(300, 0)],
      game: game,
    );

    enemy.position = Vector2(turret.range + enemy.size.x / 2 - 0.1, 0);
    expect(turret.isEnemyBodyInRange(enemy), isTrue);

    enemy.position = Vector2(turret.range + enemy.size.x / 2 + 0.1, 0);
    expect(turret.isEnemyBodyInRange(enemy), isFalse);
  });

  test('turret level up costs scale with turret price', () {
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.cannon]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(machineGun.levelUpCost, 42);
    expect(cannon.levelUpCost, 63);
    expect(machineGun.upgradeLevel(), isTrue);
    expect(cannon.upgradeLevel(), isTrue);
    expect(machineGun.levelUpCost, 69);
    expect(cannon.levelUpCost, 104);
  });

  test('turret level up button previews before spending gold', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.tryBuildTurret(const GridPoint(2, 0));
    game.debugAddGold(200);

    final beforePreview = game.snapshotNotifier.value;
    final beforeGold = beforePreview.gold;
    final beforeCost = beforePreview.selectedTurretLevelUpCost;

    game.previewOrLevelUpSelectedTurret();

    final preview = game.snapshotNotifier.value;
    expect(preview.selectedTurretLevelUpPreviewActive, isTrue);
    expect(preview.selectedTurretLevel, 1);
    expect(preview.selectedTurretNextLevel, 2);
    expect(preview.gold, beforeGold);
    expect(
      preview.selectedTurretNextDamage,
      greaterThan(preview.selectedTurretDamage),
    );
    expect(
      preview.selectedTurretNextRange,
      greaterThan(preview.selectedTurretRange),
    );
    expect(
      game.levelUpPreviewRangeFor(const GridPoint(2, 0)),
      closeTo(preview.selectedTurretNextRange, 0.001),
    );

    game.previewOrLevelUpSelectedTurret();

    final upgraded = game.snapshotNotifier.value;
    expect(upgraded.selectedTurretLevel, 2);
    expect(upgraded.gold, beforeGold - beforeCost);
    expect(upgraded.selectedTurretLevelUpPreviewActive, isTrue);
    expect(upgraded.selectedTurretNextLevel, 3);
  });

  test('turret link upgrade opens three links before link research', () {
    final baseGame = RuneNexusGame();
    final baseTurret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: baseGame,
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(baseTurret.maxSlotLimit, 3);
    expect(baseTurret.linkUpgradeCost, 90);
    expect(baseTurret.upgradeLink(), isTrue);
    expect(baseTurret.slotLimit, 2);
    expect(baseTurret.linkUpgradeRequiredLevel, 5);
    expect(baseTurret.upgradeLink(), isFalse);

    while (baseTurret.level < 5) {
      expect(baseTurret.upgradeLevel(), isTrue);
    }

    expect(baseTurret.linkUpgradeCost, 180);
    expect(baseTurret.upgradeLink(), isTrue);
    expect(baseTurret.slotLimit, 3);
    expect(baseTurret.hasNextLinkUpgrade, isFalse);
  });

  test('link expansion research raises turret link limit to four', () {
    final unlockedGame = LinkResearchUnlockedGame();
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: unlockedGame,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.cannon]!,
      game: unlockedGame,
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(machineGun.linkUpgradeCost, 90);
    expect(cannon.linkUpgradeCost, 135);
    expect(machineGun.upgradeLink(), isTrue);
    expect(cannon.upgradeLink(), isTrue);
    expect(machineGun.slotLimit, 2);
    expect(cannon.slotLimit, 2);
    while (machineGun.level < 5) {
      expect(machineGun.upgradeLevel(), isTrue);
    }
    expect(machineGun.upgradeLink(), isTrue);
    expect(machineGun.slotLimit, 3);
    expect(machineGun.linkUpgradeCost, 180);
    expect(machineGun.upgradeLink(), isTrue);
    expect(machineGun.slotLimit, 4);
    expect(machineGun.hasNextLinkUpgrade, isFalse);
  });

  test('basic link engineering only discounts the first link upgrade', () {
    final discountedGame = FirstLinkDiscountGame();
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: discountedGame,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.cannon]!,
      game: discountedGame,
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(machineGun.linkUpgradeCost, 72);
    expect(cannon.linkUpgradeCost, 108);
    expect(machineGun.upgradeLink(), isTrue);

    while (machineGun.level < 5) {
      expect(machineGun.upgradeLevel(), isTrue);
    }

    expect(machineGun.linkUpgradeCost, 180);
  });

  test('debug round control jumps to requested preparation round', () {
    final game = RuneNexusGame();

    game.debugSetRound(25);

    expect(game.snapshotNotifier.value.round, 25);
    expect(game.snapshotNotifier.value.previewText, gameWaves[24].previewText);

    game.debugSetRound(999);

    expect(game.snapshotNotifier.value.round, 40);
  });

  test('debug force victory completes current stage', () {
    final game = RuneNexusGame();

    game.debugSetRound(25);
    game.debugForceVictory();

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.success);
    expect(snapshot.completedRounds, 40);
    expect(snapshot.lastRunRuneReward, 150);
    expect(snapshot.lastRunWasNewBestRound, isTrue);
    expect(snapshot.lastRunUnlockedStageNumber, 2);
    expect(snapshot.unlockedStageCount, 2);
    expect(snapshot.clearedStageNumbers, contains(1));
  });

  test('debug force defeat starts core destruction sequence', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.debugSetRound(25);
    game.debugForceDefeat();

    expect(game.snapshotNotifier.value.nexusHp, 0);
    expect(game.snapshotNotifier.value.phase, GamePhase.coreDestruction);
    expect(game.snapshotNotifier.value.completedRounds, 24);
    final settledRunes = game.snapshotNotifier.value.runes;
    final settledReward = game.snapshotNotifier.value.lastRunRuneReward;
    expect(settledReward, greaterThan(0));

    await game.saveNow();

    expect(repository.data?.activeRun?.phase, GamePhase.failure);
    expect(repository.data?.progression.runes, settledRunes);
    expect(repository.data?.progression.lastRunRuneReward, settledReward);

    game.update(1.6);

    expect(game.snapshotNotifier.value.phase, GamePhase.coreDestruction);

    game.update(1.7);

    expect(game.snapshotNotifier.value.phase, GamePhase.failure);
    expect(game.snapshotNotifier.value.completedRounds, 24);
    expect(game.snapshotNotifier.value.runes, settledRunes);
    expect(game.snapshotNotifier.value.lastRunRuneReward, settledReward);
  });

  test('debug gold control adds gold without accepting negative values', () {
    final game = RuneNexusGame();

    game.debugAddGold(500);
    expect(game.snapshotNotifier.value.gold, 670);

    game.debugAddGold(-100);
    expect(game.snapshotNotifier.value.gold, 670);
  });

  test('menu debug controls update progression state', () {
    final game = RuneNexusGame();

    game.debugAddRunes(1000);
    expect(game.snapshotNotifier.value.runes, 1000);

    game.debugSetRunes(25);
    expect(game.snapshotNotifier.value.runes, 25);

    game.debugSetClearedStageCount(5);
    expect(game.snapshotNotifier.value.unlockedStageCount, 6);
    expect(
      game.snapshotNotifier.value.clearedStageNumbers,
      containsAll([1, 5]),
    );
    expect(game.snapshotNotifier.value.bestRoundsByStage[5], 40);
    expect(
      game.snapshotNotifier.value.availableTurretTypes,
      contains(TurretType.sniper),
    );

    game.debugSetClearedStageCount(0);
    expect(game.snapshotNotifier.value.unlockedStageCount, 1);
    expect(game.snapshotNotifier.value.clearedStageNumbers, isEmpty);
    expect(game.snapshotNotifier.value.bestRoundsByStage, isEmpty);

    game.debugAddRunes(1000);
    game.startResearch(ResearchType.researchEfficiency);
    expect(game.snapshotNotifier.value.activeResearches, isNotEmpty);

    game.debugResetResearchProgress();
    expect(game.snapshotNotifier.value.activeResearches, isEmpty);
    expect(game.snapshotNotifier.value.researchLevels, isEmpty);
    expect(game.snapshotNotifier.value.researchElapsedMillis, isEmpty);
    expect(game.snapshotNotifier.value.totalCorePoints, 0);
    expect(game.snapshotNotifier.value.corePassiveNodeRanks, isEmpty);

    game.debugSetInstantResearchCompletion(true);
    expect(game.debugInstantResearchCompletion, isTrue);
    game.startResearch(ResearchType.researchEfficiency);
    expect(game.snapshotNotifier.value.activeResearches, isEmpty);
    expect(
      game.snapshotNotifier.value.researchLevels[ResearchType
          .researchEfficiency],
      1,
    );

    game.debugSetInstantResearchCompletion(false);
    expect(game.debugInstantResearchCompletion, isFalse);

    game.debugSetClearedStageCount(5);
    game.debugAddRunes(10000);
    game.upgradeStartingGoldProgression();
    game.upgradeNexusHpProgression();
    game.upgradeSupplyProgression();
    game.upgradeFireTrainingProgression();
    game.upgradeCriticalChanceProgression();
    game.upgradeCriticalDamageProgression();
    game.upgradeKillGoldProgression();
    game.upgradeEmergencySaleProgression();
    expect(game.snapshotNotifier.value.startingGoldUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.nexusHpUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.supplyUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.fireTrainingUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.criticalChanceUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.criticalDamageUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.killGoldUpgradeLevel, 1);
    expect(game.snapshotNotifier.value.emergencySaleUpgradeLevel, 1);

    final runesBeforeUpgradeReset = game.snapshotNotifier.value.runes;
    game.debugResetUpgradeProgress();
    expect(game.snapshotNotifier.value.startingGoldUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.nexusHpUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.supplyUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.fireTrainingUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.criticalChanceUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.criticalDamageUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.killGoldUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.emergencySaleUpgradeLevel, 0);
    expect(game.snapshotNotifier.value.runes, runesBeforeUpgradeReset);
    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(5));
  });

  test('restart run resets debug-modified stage state', () {
    final game = RuneNexusGame();

    game.debugSetRound(25);
    game.debugAddGold(500);
    game.grantGem(GemType.range);

    game.restartRun();

    expect(game.snapshotNotifier.value.round, 1);
    expect(game.snapshotNotifier.value.gold, 170);
    expect(game.snapshotNotifier.value.gemInventory, isEmpty);
  });

  test('turret buttons can select a preview without a build tile', () {
    final game = RuneNexusGame();

    game.previewOrBuildSelectedTile(TurretType.cannon);

    expect(game.snapshotNotifier.value.selectedTurretType, TurretType.cannon);
    expect(
      game.snapshotNotifier.value.selectedBuildTurretType,
      TurretType.cannon,
    );
    expect(game.snapshotNotifier.value.selectedBuildPoint, isNull);
    expect(game.snapshotNotifier.value.placedTurretCount, 0);
    expect(game.snapshotNotifier.value.gold, 170);
  });

  test('same turret button confirms the selected build tile', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    const buildPoint = GridPoint(2, 0);
    tapBuildTile(game, buildPoint);

    expect(game.snapshotNotifier.value.selectedBuildPoint, buildPoint);

    final buildCost = game.turretBuildCost(TurretType.cannon);
    game.previewOrBuildSelectedTile(TurretType.cannon);

    var snapshot = game.snapshotNotifier.value;
    expect(snapshot.selectedBuildPoint, buildPoint);
    expect(snapshot.selectedBuildTurretType, TurretType.cannon);
    expect(snapshot.placedTurretCount, 0);
    expect(snapshot.gold, 170);

    game.previewOrBuildSelectedTile(TurretType.cannon);

    snapshot = game.snapshotNotifier.value;
    expect(snapshot.placedTurretCount, 1);
    expect(snapshot.gold, 170 - buildCost);
    expect(snapshot.selectedBuildPoint, isNull);
    expect(snapshot.selectedBuildTurretType, isNull);
    expect(snapshot.selectedTurretPoint, buildPoint);
  });

  test(
    'different turret button switches build preview without installing',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      const buildPoint = GridPoint(2, 0);
      tapBuildTile(game, buildPoint);

      game.previewOrBuildSelectedTile(TurretType.cannon);
      game.previewOrBuildSelectedTile(TurretType.magic);

      final snapshot = game.snapshotNotifier.value;
      expect(snapshot.selectedBuildPoint, buildPoint);
      expect(snapshot.selectedBuildTurretType, TurretType.magic);
      expect(snapshot.placedTurretCount, 0);
      expect(snapshot.gold, 170);
    },
  );

  test('run panel tab can be toggled closed', () {
    final game = RuneNexusGame();

    expect(
      game.snapshotNotifier.value.selectedRunPanelTab,
      RunPanelTab.turrets,
    );

    game.selectRunPanelTab(RunPanelTab.turrets);

    expect(game.snapshotNotifier.value.selectedRunPanelTab, RunPanelTab.closed);

    game.selectRunPanelTab(RunPanelTab.gems);

    expect(game.snapshotNotifier.value.selectedRunPanelTab, RunPanelTab.gems);
  });

  test('snapshot sums placed turret DPS for combat power', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    expect(game.snapshotNotifier.value.totalTurretDps, 0);

    game.tryBuildTurret(const GridPoint(2, 0));

    final arrow = gameTurrets[TurretType.arrow]!;
    final arrowDps = arrow.damage * arrow.attackRate;
    expect(
      game.snapshotNotifier.value.totalTurretDps,
      closeTo(arrowDps, 0.001),
    );

    game.previewOrBuildSelectedTile(TurretType.cannon);
    game.tryBuildTurret(const GridPoint(3, 0));

    final cannon = gameTurrets[TurretType.cannon]!;
    final cannonDps = cannon.damage * cannon.attackRate;
    expect(
      game.snapshotNotifier.value.totalTurretDps,
      closeTo(arrowDps + cannonDps, 0.001),
    );
  });

  test('status gems are removed from the reward pool', () {
    final gemNames = GemType.values.map((type) => type.name);

    expect(gemNames, isNot(contains('poison')));
    expect(gemNames, isNot(contains('slow')));
    expect(GemType.values, contains(GemType.physicalDamage));
    expect(GemType.values, contains(GemType.elementalDamage));
    expect(GemType.values, contains(GemType.lightWeapon));
    expect(GemType.values, contains(GemType.heavyWeapon));
    expect(GemType.values, contains(GemType.damageOverTime));
    expect(GemType.values, contains(GemType.criticalChance));
    expect(GemType.values, contains(GemType.aimSpeed));
    expect(GemType.values, contains(GemType.damageAmplifier));
    expect(GemType.values, contains(GemType.armorPiercing));
  });

  test('staged reward gems are gated by the provided reward pool', () {
    final generator = GemRewardGenerator();
    final lockedPool = GemType.values.where(
      (type) => type != GemType.aimSpeed && type != GemType.armorPiercing,
    );

    for (var i = 0; i < 20; i++) {
      final options = generator.generateOptions(availableGems: lockedPool);
      expect(options, isNot(contains(GemType.aimSpeed)));
      expect(options, isNot(contains(GemType.armorPiercing)));
    }
    expect(
      generator.generateOptions(
        availableGems: const [GemType.aimSpeed, GemType.armorPiercing],
      ),
      containsAll([GemType.aimSpeed, GemType.armorPiercing]),
    );
  });

  test('enemy kill rewards limit late-wave gold snowballing', () {
    expect(gameEnemies[EnemyType.normal]!.rewardGold, 5);
    expect(gameEnemies[EnemyType.armored]!.rewardGold, 7);
    expect(gameEnemies[EnemyType.shielded]!.rewardGold, 8);
    expect(gameEnemies[EnemyType.fast]!.rewardGold, 5);
    expect(gameEnemies[EnemyType.tank]!.rewardGold, 9);
    expect(gameEnemies[EnemyType.boss]!.rewardGold, 35);
    expect(gameEnemies[EnemyType.shieldBoss]!.rewardGold, 48);
    expect(gameEnemies[EnemyType.forgeBoss]!.rewardGold, 58);
  });

  test('shielded enemy is defined and starts appearing from chapter two', () {
    final shielded = gameEnemies[EnemyType.shielded]!;

    expect(gameEnemies.keys, containsAll(EnemyType.values));
    expect(shielded.name, '보호막병');
    expect(shielded.maxHp, 36);
    expect(shielded.maxShield, 42);
    expect(shielded.shieldRegenRate, 0.04);
    expect(shielded.maxArmor, 0);
    expect(shielded.coreDamage, 1);
    expect(shielded.resistanceProfile, EnemyResistanceProfile.neutral);

    final stageOneWaveTypes = gameWaves
        .expand((wave) => wave.groups)
        .map((group) => group.enemyType);
    final chapterOneLateWaveTypes = gameStage2Waves
        .expand((wave) => wave.groups)
        .map((group) => group.enemyType);
    final chapterTwoWaveTypes = gameChapter2Waves
        .expand((wave) => wave.groups)
        .map((group) => group.enemyType);
    final chapterTwoLaterWaveTypes = [
      ...gameChapter2Stage7Waves,
      ...gameChapter2Stage8Waves,
      ...gameChapter2Stage9Waves,
      ...gameChapter2Stage10Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType);

    expect(stageOneWaveTypes, isNot(contains(EnemyType.shielded)));
    expect(chapterOneLateWaveTypes, isNot(contains(EnemyType.shielded)));
    expect(chapterTwoWaveTypes, contains(EnemyType.shielded));
    expect(chapterTwoLaterWaveTypes, contains(EnemyType.shielded));
  });

  test('shield boss is defined and replaces boss waves in chapter two', () {
    int countType(List<WaveDefinition> waves, int round, EnemyType type) =>
        waves[round - 1].groups
            .where((group) => group.enemyType == type)
            .fold(0, (total, group) => total + group.count);

    final shieldBoss = gameEnemies[EnemyType.shieldBoss]!;
    final chapterOneTypes = [
      ...gameWaves,
      ...gameStage2Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType);
    final chapterTwoTypes = [
      ...gameChapter2Waves,
      ...gameChapter2Stage7Waves,
      ...gameChapter2Stage8Waves,
      ...gameChapter2Stage9Waves,
      ...gameChapter2Stage10Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType);

    expect(shieldBoss.name, '균열 방벽체');
    expect(shieldBoss.maxHp, 820);
    expect(shieldBoss.maxShield, 360);
    expect(shieldBoss.shieldRegenRate, 0.025);
    expect(shieldBoss.maxArmor, 0);
    expect(shieldBoss.speed, 15);
    expect(shieldBoss.coreDamage, 10);
    expect(
      shieldBoss.resistanceProfile.multiplierFor(
        family: DamageFamily.physical,
        tags: const {},
      ),
      closeTo(1, 0.001),
    );
    expect(chapterOneTypes, isNot(contains(EnemyType.shieldBoss)));
    expect(chapterTwoTypes, contains(EnemyType.shieldBoss));
    expect(
      gameChapter2Waves[9].groups.map((group) => group.enemyType),
      contains(EnemyType.shieldBoss),
    );
    expect(countType(gameChapter2Waves, 10, EnemyType.boss), 0);
    expect(countType(gameChapter2Stage10Waves, 40, EnemyType.shieldBoss), 1);
  });

  test('forge boss is defined and replaces boss waves in chapter three', () {
    int countType(List<WaveDefinition> waves, int round, EnemyType type) =>
        waves[round - 1].groups
            .where((group) => group.enemyType == type)
            .fold(0, (total, group) => total + group.count);

    final forgeBoss = gameEnemies[EnemyType.forgeBoss]!;
    final chapterOneTypes = [
      ...gameWaves,
      ...gameStage2Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType);
    final chapterTwoTypes = [
      ...gameChapter2Waves,
      ...gameChapter2Stage7Waves,
      ...gameChapter2Stage8Waves,
      ...gameChapter2Stage9Waves,
      ...gameChapter2Stage10Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType);
    final chapterThreeTypes = [
      ...gameChapter3Waves,
      ...gameChapter3Stage12Waves,
      ...gameChapter3Stage13Waves,
      ...gameChapter3Stage14Waves,
      ...gameChapter3Stage15Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType);

    expect(forgeBoss.name, '용광로 파쇄자');
    expect(forgeBoss.maxHp, 760);
    expect(forgeBoss.maxArmor, 520);
    expect(forgeBoss.maxShield, 0);
    expect(forgeBoss.speed, 13.5);
    expect(forgeBoss.coreDamage, 12);
    expect(
      forgeBoss.resistanceProfile.multiplierFor(
        family: DamageFamily.elemental,
        tags: const {},
      ),
      closeTo(1, 0.001),
    );
    expect(chapterOneTypes, isNot(contains(EnemyType.forgeBoss)));
    expect(chapterTwoTypes, isNot(contains(EnemyType.forgeBoss)));
    expect(chapterThreeTypes, contains(EnemyType.forgeBoss));
    expect(countType(gameChapter3Waves, 10, EnemyType.boss), 0);
    expect(countType(gameChapter3Waves, 10, EnemyType.forgeBoss), 1);
    expect(countType(gameChapter3Stage15Waves, 40, EnemyType.forgeBoss), 1);
  });

  test('physical damage gem boosts physical turrets only', () {
    final game = LinkResearchUnlockedGame();
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final fireTurret = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.magic]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    machineGun.equipGem(GemType.physicalDamage, 0);
    fireTurret.equipGem(GemType.physicalDamage, 0);

    expect(machineGun.damage, closeTo(9.8, 0.001));
    expect(fireTurret.damage, closeTo(16, 0.001));
  });

  test('elemental damage gem boosts elemental turrets only', () {
    final game = RuneNexusGame();
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final fireTurret = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.magic]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    machineGun.equipGem(GemType.elementalDamage, 0);
    fireTurret.equipGem(GemType.elementalDamage, 0);

    expect(machineGun.damage, closeTo(7, 0.001));
    expect(fireTurret.damage, closeTo(22.4, 0.001));
  });

  test('light weapon gem boosts light turret damage and fire rate', () {
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.cannon]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    machineGun.equipGem(GemType.lightWeapon, 0);
    cannon.equipGem(GemType.lightWeapon, 0);

    expect(machineGun.damage, closeTo(8.4, 0.001));
    expect(machineGun.attackRate, closeTo(2.724, 0.001));
    expect(cannon.damage, closeTo(25, 0.001));
    expect(cannon.attackRate, closeTo(0.4, 0.001));
  });

  test('heavy weapon gem boosts heavy turret damage and splash radius', () {
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.cannon]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    machineGun.equipGem(GemType.heavyWeapon, 0);
    cannon.equipGem(GemType.heavyWeapon, 0);

    expect(machineGun.damage, closeTo(7, 0.001));
    expect(machineGun.splashRadius, closeTo(0, 0.001));
    expect(cannon.damage, closeTo(32.5, 0.001));
    expect(cannon.splashRadius, closeTo(50.4, 0.001));
  });

  test(
    'explosion gem keeps splash damage ratio and amplifies splash radius',
    () {
      final machineGun = TurretComponent(
        gridPoint: const GridPoint(0, 0),
        definition: gameTurrets[TurretType.arrow]!,
        game: RuneNexusGame(),
        center: Vector2.zero(),
        tileSize: 32,
      );
      final cannon = TurretComponent(
        gridPoint: const GridPoint(1, 0),
        definition: gameTurrets[TurretType.cannon]!,
        game: RuneNexusGame(),
        center: Vector2.zero(),
        tileSize: 32,
      );

      machineGun.equipGem(GemType.explosion, 0);
      cannon.equipGem(GemType.explosion, 0);

      expect(machineGun.splashRadius, closeTo(34, 0.001));
      expect(machineGun.splashSecondaryDamageMultiplier, closeTo(0.35, 0.001));
      expect(cannon.splashRadius, closeTo(52.5, 0.001));
      expect(cannon.splashSecondaryDamageMultiplier, closeTo(0.5, 0.001));
    },
  );

  test('damage over time gem boosts only dot stats', () {
    final fireTurret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.magic]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    fireTurret.equipGem(GemType.damageOverTime, 0);

    expect(fireTurret.damage, closeTo(16, 0.001));
    expect(fireTurret.damageOverTimeDamageMultiplier, closeTo(1.3, 0.001));
    expect(fireTurret.damageOverTimeDurationMultiplier, closeTo(1.3, 0.001));
  });

  test('critical chance gem adds twenty percentage points', () {
    final arrow = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final sniper = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.sniper]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    arrow.equipGem(GemType.criticalChance, 0);
    sniper.equipGem(GemType.criticalChance, 0);

    expect(arrow.criticalChance, closeTo(0.25, 0.001));
    expect(sniper.criticalChance, closeTo(0.35, 0.001));
  });

  test('damage amplifier gem boosts burn through hit damage base', () {
    final arrow = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final fireTurret = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: gameTurrets[TurretType.magic]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(2, 0),
      definition: gameTurrets[TurretType.cannon]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    arrow.equipGem(GemType.damageAmplifier, 0);
    fireTurret.equipGem(GemType.damageAmplifier, 0);
    cannon.equipGem(GemType.damageAmplifier, 0);

    expect(arrow.damage, closeTo(8.75, 0.001));
    expect(fireTurret.damage, closeTo(20, 0.001));
    expect(cannon.damage, closeTo(31.25, 0.001));
    expect(
      cannon.damage * cannon.splashSecondaryDamageMultiplier,
      closeTo(15.625, 0.001),
    );
    expect(
      fireTurret.damage *
          RuneNexusGame.burnDamagePerSecondScale *
          fireTurret.damageOverTimeDamageMultiplier,
      closeTo(10, 0.001),
    );
  });

  test('scaling gems can be equipped before matching conversion exists', () {
    expect(
      canEquipGemOnTurret(
        GemType.elementalDamage,
        gameTurrets[TurretType.cannon]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(
        GemType.elementalDamage,
        gameTurrets[TurretType.magic]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.heavyWeapon, gameTurrets[TurretType.arrow]!),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.heavyWeapon, gameTurrets[TurretType.cannon]!),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(
        GemType.damageOverTime,
        gameTurrets[TurretType.magic]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(
        GemType.damageOverTime,
        gameTurrets[TurretType.cannon]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.chain, gameTurrets[TurretType.cannon]!),
      isFalse,
    );
    expect(
      canEquipGemOnTurret(GemType.chain, gameTurrets[TurretType.arrow]!),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.chain, gameTurrets[TurretType.sniper]!),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.chain, gameTurrets[TurretType.lightning]!),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.aimSpeed, gameTurrets[TurretType.arrow]!),
      isFalse,
    );
    expect(
      canEquipGemOnTurret(GemType.aimSpeed, gameTurrets[TurretType.sniper]!),
      isTrue,
    );
  });

  test('turret gems can be removed and returned by slot', () {
    final game = LinkResearchUnlockedGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.arrow]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..equipGem(GemType.range, 0)
          ..upgradeLink()
          ..equipGem(GemType.chain, 1);

    expect(turret.removeGemAt(0), GemType.range);
    expect(turret.equippedGemSlots, [null, GemType.chain]);
    expect(turret.equippedGems, [GemType.chain]);
  });

  test('gems can be equipped into the selected empty socket', () async {
    final game = LinkResearchUnlockedGame(
      saveRepository: MemorySaveRepository(),
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.tryBuildTurret(const GridPoint(2, 0));
    game.debugAddGold(1000);
    game.upgradeSelectedTurretLink();
    game.selectSelectedTurretGemSlot(1);
    game.grantGem(GemType.range);
    game.equipSelectedTurret(GemType.range);

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.selectedTurretGemSlotIndex, 1);
    expect(snapshot.selectedTurretGems, [null, GemType.range]);
    expect(snapshot.gemInventory[GemType.range], isNull);
    expect(snapshot.gemCollection[GemType.range], 1);
  });

  test('equipping a gem plays a transient socket effect on success', () async {
    final game = LinkResearchUnlockedGame(
      saveRepository: MemorySaveRepository(),
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.tryBuildTurret(const GridPoint(2, 0));
    game.grantGem(GemType.range);
    game.equipSelectedTurret(GemType.range);
    game.update(0);

    final effect = game.children.whereType<GemEquipEffectComponent>().single;
    expect(effect.gemColor, game.colorForGem(GemType.range));

    game.equipSelectedTurret(GemType.range);
    game.update(0);
    expect(game.children.whereType<GemEquipEffectComponent>(), hasLength(1));

    effect.update(1);
    expect(game.children.whereType<GemEquipEffectComponent>(), isEmpty);

    game.removeSelectedTurretGemSlot();
    game.update(0);
    expect(game.children.whereType<GemEquipEffectComponent>(), isEmpty);
  });

  test('removing a gem keeps other gem socket positions fixed', () async {
    final repository = MemorySaveRepository();
    final game = LinkResearchUnlockedGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.tryBuildTurret(const GridPoint(2, 0));
    game.debugAddGold(1000);
    game.upgradeSelectedTurretLink();
    game.grantGem(GemType.range);
    game.equipSelectedTurret(GemType.range);
    game.selectSelectedTurretGemSlot(1);
    game.grantGem(GemType.chain);
    game.equipSelectedTurret(GemType.chain);
    game.selectSelectedTurretGemSlot(0);
    game.removeSelectedTurretGemSlot();

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.selectedTurretGemSlotIndex, 0);
    expect(snapshot.selectedTurretGems, [null, GemType.chain]);
    expect(snapshot.gemInventory[GemType.range], 1);

    await game.saveNow();
    expect(repository.data!.activeRun!.turrets.single.equippedGemSlots, [
      null,
      GemType.chain,
    ]);
  });

  test('only dedicated pressure waves overlap major spawn groups', () {
    double lastSpawnDelay(SpawnGroup group) =>
        group.startDelay + group.interval * (group.count - 1);

    final wave7 = gameWaves[6];
    final wave7Normal = wave7.groups[0];
    final wave7FirstRush = wave7.groups[1];
    final wave7SecondRush = wave7.groups[2];

    expect(wave7FirstRush.startDelay, greaterThan(lastSpawnDelay(wave7Normal)));
    expect(
      wave7SecondRush.startDelay,
      greaterThan(lastSpawnDelay(wave7FirstRush)),
    );

    final wave8 = gameWaves[7];
    final wave8Normal = wave8.groups[0];
    final wave8Fast = wave8.groups[1];

    expect(wave8Fast.startDelay, greaterThan(wave8Normal.startDelay));
    expect(wave8Fast.startDelay, lessThan(lastSpawnDelay(wave8Normal)));

    final wave9 = gameWaves[8];
    final wave9Tank = wave9.groups[0];
    final wave9Normal = wave9.groups[1];
    final wave9Fast = wave9.groups[2];

    expect(wave9Normal.startDelay, greaterThan(lastSpawnDelay(wave9Tank)));
    expect(wave9Fast.startDelay, greaterThan(lastSpawnDelay(wave9Normal)));

    final wave30 = gameWaves[29];
    final wave30Tank = wave30.groups[0];
    final wave30Fast = wave30.groups[1];
    final wave30Boss = wave30.groups[2];
    final wave30RearGuard = wave30.groups[3];

    expect(wave30Fast.startDelay, greaterThan(lastSpawnDelay(wave30Tank)));
    expect(wave30Boss.startDelay, greaterThan(lastSpawnDelay(wave30Fast)));
    expect(wave30Boss.count, 1);
    expect(wave30RearGuard.startDelay, greaterThan(wave30Boss.startDelay));
    expect(wave30RearGuard.startDelay, lessThan(wave30Boss.startDelay + 1.5));
  });

  test('chapter one waves stay health-only through stage five', () {
    final chapterOneTypes = [
      ...gameWaves,
      ...gameStage2Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType);
    final stage2Round4Types = gameStage2Waves[3].groups.map(
      (group) => group.enemyType,
    );
    final stage2Round5Types = gameStage2Waves[4].groups.map(
      (group) => group.enemyType,
    );
    final stage2Round10Types = gameStage2Waves[9].groups.map(
      (group) => group.enemyType,
    );

    expect(chapterOneTypes, isNot(contains(EnemyType.armored)));
    expect(chapterOneTypes, isNot(contains(EnemyType.shielded)));
    expect(stage2Round4Types, contains(EnemyType.fast));
    expect(stage2Round5Types, contains(EnemyType.tank));
    expect(stage2Round10Types, contains(EnemyType.boss));
  });

  test('wave spawner saves remaining delays and restores cursor timing', () {
    const wave = WaveDefinition(
      round: 1,
      previewText: 'Wave spawner timing test',
      clearRewardGold: 0,
      groups: [
        SpawnGroup(
          enemyType: EnemyType.normal,
          count: 1,
          interval: 1,
          startDelay: 1,
        ),
        SpawnGroup(
          enemyType: EnemyType.fast,
          count: 1,
          interval: 1,
          startDelay: 2,
        ),
        SpawnGroup(
          enemyType: EnemyType.tank,
          count: 1,
          interval: 1,
          startDelay: 3,
        ),
      ],
    );

    final spawner = WaveSpawner()..start(wave);

    expect(spawner.update(1.5), orderedEquals([EnemyType.normal]));

    final saved = spawner.toSaveData();
    expect(
      saved.map((request) => request.enemyType),
      orderedEquals([EnemyType.fast, EnemyType.tank]),
    );
    expect(saved[0].delay, closeTo(0.5, 0.001));
    expect(saved[1].delay, closeTo(1.5, 0.001));

    final restored = WaveSpawner()..restoreFromSaveData(saved);
    expect(restored.update(0.49), isEmpty);
    expect(restored.update(0.01), orderedEquals([EnemyType.fast]));
    expect(restored.toSaveData().single.delay, closeTo(1, 0.001));
    expect(restored.update(1), orderedEquals([EnemyType.tank]));
    expect(restored.isEmpty, isTrue);
  });

  test('wave spawner returns every request ready in one large update', () {
    const wave = WaveDefinition(
      round: 1,
      previewText: 'Wave spawner batch test',
      clearRewardGold: 0,
      groups: [
        SpawnGroup(
          enemyType: EnemyType.normal,
          count: 1,
          interval: 1,
          startDelay: 0.5,
        ),
        SpawnGroup(
          enemyType: EnemyType.fast,
          count: 1,
          interval: 1,
          startDelay: 1,
        ),
        SpawnGroup(
          enemyType: EnemyType.armored,
          count: 1,
          interval: 1,
          startDelay: 1.5,
        ),
        SpawnGroup(
          enemyType: EnemyType.boss,
          count: 1,
          interval: 1,
          startDelay: 3,
        ),
      ],
    );

    final spawner = WaveSpawner()..start(wave);

    expect(
      spawner.update(1.5),
      orderedEquals([EnemyType.normal, EnemyType.fast, EnemyType.armored]),
    );
    expect(spawner.toSaveData().single.delay, closeTo(1.5, 0.001));
  });

  test(
    'chapter two waves introduce shielded enemies without changing chapter one',
    () {
      int countType(List<WaveDefinition> waves, int round, EnemyType type) =>
          waves[round - 1].groups
              .where((group) => group.enemyType == type)
              .fold(0, (total, group) => total + group.count);

      final chapterOneTypes = [
        ...gameWaves.expand((wave) => wave.groups),
        ...gameStage2Waves.expand((wave) => wave.groups),
      ].map((group) => group.enemyType);
      final chapterTwoTypes = [
        ...gameChapter2Waves,
        ...gameChapter2Stage7Waves,
        ...gameChapter2Stage8Waves,
        ...gameChapter2Stage9Waves,
        ...gameChapter2Stage10Waves,
      ].expand((wave) => wave.groups).map((group) => group.enemyType);
      final chapterTwoPreviews = [
        ...gameChapter2Waves,
        ...gameChapter2Stage7Waves,
        ...gameChapter2Stage8Waves,
        ...gameChapter2Stage9Waves,
        ...gameChapter2Stage10Waves,
      ].map((wave) => wave.previewText);
      final chapter2Round2Types = gameChapter2Waves[1].groups.map(
        (group) => group.enemyType,
      );
      final chapter2Round3Types = gameChapter2Waves[2].groups.map(
        (group) => group.enemyType,
      );
      final chapter2Round10Types = gameChapter2Waves[9].groups.map(
        (group) => group.enemyType,
      );

      expect(chapterOneTypes, isNot(contains(EnemyType.shielded)));
      expect(chapterOneTypes, isNot(contains(EnemyType.armored)));
      expect(chapterTwoTypes, isNot(contains(EnemyType.armored)));
      expect(chapterTwoPreviews.any((text) => text.contains('장갑')), isFalse);
      expect(chapter2Round2Types, contains(EnemyType.shielded));
      expect(chapter2Round3Types.first, EnemyType.shielded);
      expect(chapter2Round10Types, contains(EnemyType.shielded));
      expect(chapter2Round10Types, contains(EnemyType.shieldBoss));
      expect(
        countType(gameChapter2Stage7Waves, 7, EnemyType.fast),
        greaterThan(countType(gameChapter2Waves, 7, EnemyType.fast)),
      );
      expect(
        countType(gameChapter2Stage8Waves, 8, EnemyType.shielded),
        greaterThan(countType(gameChapter2Waves, 8, EnemyType.shielded)),
      );
      expect(
        countType(gameChapter2Stage9Waves, 8, EnemyType.shielded),
        greaterThan(countType(gameChapter2Waves, 8, EnemyType.shielded)),
      );
      expect(
        countType(gameChapter2Stage10Waves, 40, EnemyType.shieldBoss),
        countType(gameChapter2Waves, 40, EnemyType.shieldBoss),
      );
    },
  );

  test('chapter three waves reuse existing enemies with forge pressure', () {
    int countType(List<WaveDefinition> waves, int round, EnemyType type) =>
        waves[round - 1].groups
            .where((group) => group.enemyType == type)
            .fold(0, (total, group) => total + group.count);

    final chapterThreeTypes = [
      ...gameChapter3Waves,
      ...gameChapter3Stage12Waves,
      ...gameChapter3Stage13Waves,
      ...gameChapter3Stage14Waves,
      ...gameChapter3Stage15Waves,
    ].expand((wave) => wave.groups).map((group) => group.enemyType).toSet();

    expect(EnemyType.values, hasLength(8));
    expect(
      chapterThreeTypes,
      containsAll(
        EnemyType.values.where(
          (type) => type != EnemyType.boss && type != EnemyType.shieldBoss,
        ),
      ),
    );
    expect(chapterThreeTypes, isNot(contains(EnemyType.boss)));
    expect(chapterThreeTypes, isNot(contains(EnemyType.shieldBoss)));
    expect(countType(gameChapter3Waves, 6, EnemyType.armored), greaterThan(0));
    expect(countType(gameChapter3Waves, 9, EnemyType.tank), greaterThan(0));
    expect(
      countType(gameChapter3Stage15Waves, 8, EnemyType.shielded),
      greaterThan(0),
    );
    expect(countType(gameChapter3Stage15Waves, 40, EnemyType.forgeBoss), 1);
  });

  test('late wave enemy counts stay within the planned pressure range', () {
    int totalCount(WaveDefinition wave) =>
        wave.groups.fold(0, (total, group) => total + group.count);

    final round6Count = totalCount(gameWaves[5]);
    final round39Count = totalCount(gameWaves[38]);
    final round40Count = totalCount(gameWaves[39]);

    expect(round6Count, inInclusiveRange(16, 18));
    expect(round39Count, lessThanOrEqualTo(round6Count * 2));
    expect(round40Count, lessThanOrEqualTo(round6Count * 2));
  });

  test('normal enemy groups use a slower spawn cadence', () {
    expect(gameWaves[0].groups.single.interval, greaterThanOrEqualTo(1.6));
    expect(gameWaves[3].groups[0].interval, greaterThanOrEqualTo(1.35));
    expect(gameWaves[10].groups[0].interval, greaterThanOrEqualTo(1.1));
    expect(gameWaves[25].groups[0].interval, greaterThanOrEqualTo(1.0));
    expect(gameWaves[4].groups[1].interval, greaterThanOrEqualTo(1.2));
  });

  test('special enemy groups keep readable spawn gaps', () {
    expect(gameWaves[3].groups[1].interval, greaterThanOrEqualTo(0.8));
    expect(gameWaves[10].groups[1].interval, greaterThanOrEqualTo(0.65));
    expect(gameWaves[25].groups[1].interval, greaterThanOrEqualTo(0.6));
    expect(gameWaves[4].groups[0].interval, greaterThanOrEqualTo(1.5));
    expect(gameWaves[9].groups[2].interval, greaterThanOrEqualTo(2.0));
    expect(gameWaves[29].groups[2].interval, greaterThanOrEqualTo(2.0));
  });

  test('fire turret is tagged as damage over time', () {
    expect(
      gameTurrets[TurretType.magic]!.attackTags,
      contains(AttackTag.damageOverTime),
    );
  });

  test('machine gun is tagged as light weapon', () {
    expect(
      gameTurrets[TurretType.arrow]!.attackTags,
      contains(AttackTag.light),
    );
  });

  test('frost turret is a centered cooling area attack', () {
    final frost = gameTurrets[TurretType.frost]!;

    expect(frost.centeredAreaAttack, isTrue);
    expect(frost.damageFamily, DamageFamily.elemental);
    expect(frost.attackTags, contains(AttackTag.cooling));
    expect(frost.slowMultiplier, closeTo(0.7, 0.001));
    expect(frost.slowDuration, closeTo(1, 0.001));
  });

  test(
    'enemy resistance profile sums same-layer resistance and multiplies layers',
    () {
      final tank = gameEnemies[EnemyType.tank]!;

      expect(
        tank.resistanceProfile.multiplierFor(
          family: DamageFamily.physical,
          tags: const {AttackTag.light},
        ),
        closeTo(0.52, 0.001),
      );
      expect(
        tank.resistanceProfile.multiplierFor(
          family: DamageFamily.physical,
          tags: const {AttackTag.heavy},
        ),
        closeTo(0.96, 0.001),
      );
      expect(
        tank.resistanceProfile.multiplierFor(
          family: DamageFamily.elemental,
          tags: const {AttackTag.damageOverTime},
        ),
        closeTo(1, 0.001),
      );
    },
  );

  test('enemy resistance caps positive resistance but keeps vulnerability', () {
    expect(
      EnemyResistanceProfile.multiplierForResistance(1.5),
      closeTo(0.1, 0.001),
    );
    expect(
      EnemyResistanceProfile.multiplierForResistance(-1.1),
      closeTo(2.1, 0.001),
    );
  });

  test('boss enemies use neutral base resistance', () {
    final boss = gameEnemies[EnemyType.boss]!;

    expect(
      boss.resistanceProfile.multiplierFor(
        family: DamageFamily.physical,
        tags: const {AttackTag.light},
      ),
      closeTo(1, 0.001),
    );
  });

  test('boss enemies do not resist damage over time', () {
    final boss = gameEnemies[EnemyType.boss]!;

    expect(
      boss.resistanceProfile.multiplierFor(
        family: DamageFamily.elemental,
        tags: const {AttackTag.damageOverTime},
      ),
      closeTo(1, 0.001),
    );
  });

  test('fast enemies strongly favor light weapons over heavy weapons', () {
    final fast = gameEnemies[EnemyType.fast]!;

    expect(
      fast.resistanceProfile.multiplierFor(
        family: DamageFamily.physical,
        tags: const {AttackTag.light},
      ),
      closeTo(1.5, 0.001),
    );
    expect(
      fast.resistanceProfile.multiplierFor(
        family: DamageFamily.physical,
        tags: const {AttackTag.heavy},
      ),
      closeTo(0.5, 0.001),
    );
    expect(
      fast.resistanceProfile.multiplierFor(
        family: DamageFamily.elemental,
        tags: const {AttackTag.damageOverTime},
      ),
      closeTo(1, 0.001),
    );
  });

  test('burn deals short duration damage over time', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyBurn(damagePerSecond: 10, duration: 2);

    enemy.update(0.25);

    expect(enemy.hp, closeTo(97.5, 0.001));
  });

  test('enemy damage returns actual hp loss', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 12,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );

    expect(enemy.receiveDamage(5), closeTo(5, 0.001));
    expect(enemy.receiveDamage(20), closeTo(7, 0.001));
    expect(enemy.receiveDamage(20), closeTo(0, 0.001));
  });

  test('armor mitigates damage before hp and weakens as it breaks', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      maxArmor: 50,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );

    expect(enemy.receiveDamage(20), closeTo(10.940952, 0.001));
    expect(enemy.armor, closeTo(39.059048, 0.001));
    expect(enemy.hp, closeTo(100, 0.001));

    expect(enemy.receiveDamage(100), closeTo(84.599352, 0.001));
    expect(enemy.armor, closeTo(0, 0.001));
    expect(enemy.hp, closeTo(54.459696, 0.001));
  });

  test('armor 54 reduces machine gun base damage before hp', () {
    final game = RuneNexusGame();
    final armored = gameEnemies[EnemyType.armored]!;
    final enemy = EnemyComponent(
      definition: armored,
      maxHp: 100,
      maxArmor: 54,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );

    expect(enemy.receiveDamage(7), closeTo(2.324572, 0.001));
    expect(enemy.armor, closeTo(51.675428, 0.001));
    expect(enemy.hp, closeTo(100, 0.001));
  });

  test('armor piercing ignores reduction without bypassing armor layer', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      maxArmor: 50,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );

    expect(
      enemy.receiveDamage(7, ignoreArmorReduction: true),
      closeTo(7, 0.001),
    );
    expect(enemy.armor, closeTo(43, 0.001));
    expect(enemy.hp, closeTo(100, 0.001));

    expect(
      enemy.receiveDamage(50, ignoreArmorReduction: true),
      closeTo(50, 0.001),
    );
    expect(enemy.armor, closeTo(0, 0.001));
    expect(enemy.hp, closeTo(93, 0.001));
  });

  test(
    'shield overflow spills into armor and broken shield does not regen',
    () {
      final game = RuneNexusGame();
      const shielded = EnemyDefinition(
        type: EnemyType.normal,
        name: '보호막 테스트',
        maxHp: 100,
        maxShield: 100,
        shieldRegenRate: 0.1,
        maxArmor: 50,
        speed: 30,
        rewardGold: 1,
        coreDamage: 1,
        color: Color(0xFFFFFFFF),
        resistanceProfile: EnemyResistanceProfile.neutral,
      );
      final enemy = EnemyComponent(
        definition: shielded,
        maxHp: 100,
        maxShield: 100,
        maxArmor: 50,
        path: [Vector2.zero(), Vector2(100, 0)],
        game: game,
      );

      expect(enemy.receiveDamage(120), closeTo(110.940952, 0.001));
      expect(enemy.shield, closeTo(0, 0.001));
      expect(enemy.shieldBroken, isTrue);
      expect(enemy.armor, closeTo(39.059048, 0.001));
      expect(enemy.hp, closeTo(100, 0.001));

      enemy.update(1);

      expect(enemy.shield, closeTo(0, 0.001));
    },
  );

  test('enemy durability state is saved and restored', () {
    final game = RuneNexusGame();
    const shielded = EnemyDefinition(
      type: EnemyType.normal,
      name: '저장 테스트',
      maxHp: 100,
      maxShield: 100,
      shieldRegenRate: 0.1,
      maxArmor: 50,
      speed: 30,
      rewardGold: 1,
      coreDamage: 1,
      color: Color(0xFFFFFFFF),
      resistanceProfile: EnemyResistanceProfile.neutral,
    );
    final enemy = EnemyComponent(
      definition: shielded,
      maxHp: 100,
      maxShield: 100,
      maxArmor: 50,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );
    enemy.receiveDamage(120);

    final restored = EnemyComponent(
      definition: shielded,
      maxHp: 100,
      maxShield: 100,
      maxArmor: 50,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..restoreFromSaveData(enemy.toSaveData());

    expect(restored.shield, closeTo(0, 0.001));
    expect(restored.shieldBroken, isTrue);
    expect(restored.armor, closeTo(39.059048, 0.001));
    expect(restored.hp, closeTo(100, 0.001));
  });

  test(
    'fire turret exposes burn damage in the selected turret stats',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.selectTurretType(TurretType.magic);
      game.tryBuildTurret(const GridPoint(2, 0));

      final snapshot = game.snapshotNotifier.value;
      expect(snapshot.selectedTurretDamage, closeTo(16, 0.001));
      expect(snapshot.selectedTurretBurnDamagePerSecond, closeTo(8, 0.001));
      expect(snapshot.selectedTurretBurnDuration, closeTo(2, 0.001));
      expect(snapshot.selectedTurretDamageDealt, closeTo(0, 0.001));
    },
  );

  test('burn damage uses only the strongest active burn instance', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyBurn(damagePerSecond: 20, duration: 2);

    enemy.update(1);
    enemy.applyBurn(damagePerSecond: 8, duration: 2);
    enemy.update(1);

    expect(enemy.hp, closeTo(60, 0.001));

    enemy.update(1);

    expect(enemy.hp, closeTo(52, 0.001));
  });

  test('frost turret damages and slows enemies in its centered area', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.selectTurretType(TurretType.frost);
    game.tryBuildTurret(const GridPoint(2, 0));
    final frostTurret = game.children.whereType<TurretComponent>().single;
    final inRangeEnemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    final outOfRangeEnemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );

    await game.add(inRangeEnemy);
    await game.add(outOfRangeEnemy);
    inRangeEnemy.position =
        frostTurret.position + Vector2(frostTurret.range, 0);
    outOfRangeEnemy.position =
        frostTurret.position + Vector2(frostTurret.range + 80, 0);
    game.enemies.addAll([inRangeEnemy, outOfRangeEnemy]);

    game.resolveCenteredAreaAttack(
      owner: frostTurret,
      targets: [inRangeEnemy, outOfRangeEnemy],
    );

    expect(inRangeEnemy.hp, closeTo(96, 0.001));
    expect(inRangeEnemy.isSlowed, isTrue);
    expect(inRangeEnemy.slowMultiplier, closeTo(0.7, 0.001));
    expect(inRangeEnemy.slowRemaining, closeTo(1, 0.001));
    expect(outOfRangeEnemy.hp, closeTo(100, 0.001));
    expect(outOfRangeEnemy.isSlowed, isFalse);

    final previousDistance = inRangeEnemy.distanceTravelled;
    inRangeEnemy.update(0.5);

    expect(
      inRangeEnemy.distanceTravelled - previousDistance,
      closeTo(
        gameEnemies[EnemyType.normal]!.speed *
            game.boardDistanceScale *
            0.7 *
            0.5,
        0.001,
      ),
    );
  });

  test(
    'sniper instant hit applies critical direct damage without projectile',
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
      game.startNextWave();
      game.update(0.016);
      game.restartRun();
      game.debugSetClearedStageCount(RuneNexusGame.sniperUnlockStage);
      game.selectTurretType(TurretType.sniper);
      game.tryBuildTurret(const GridPoint(2, 0));

      final sniperTurret = game.children.whereType<TurretComponent>().single;
      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(500, 0)],
        game: game,
      );

      await game.add(enemy);
      game.update(0);
      enemy.position =
          sniperTurret.position + Vector2(sniperTurret.range * 0.5, 0);
      game.enemies.add(enemy);

      game.resolveInstantHit(
        owner: sniperTurret,
        target: enemy,
        criticalMultiplier: sniperTurret.criticalDamageMultiplier,
      );

      expect(enemy.hp, closeTo(20, 0.001));
      expect(sniperTurret.directDamageDealt, closeTo(80, 0.001));
      expect(game.children.whereType<ProjectileComponent>(), isEmpty);
    },
  );

  testWidgets('sniper chain gem applies instant beam chain damage', (
    tester,
  ) async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    game.debugSetClearedStageCount(RuneNexusGame.sniperUnlockStage);
    game.selectTurretType(TurretType.sniper);
    game.tryBuildTurret(const GridPoint(2, 0));
    game.update(0);

    final sniperTurret = game.children.whereType<TurretComponent>().single;
    expect(sniperTurret.definition.type, TurretType.sniper);
    sniperTurret.equipGem(GemType.chain, 0);
    expect(sniperTurret.hasGem(GemType.chain), isTrue);
    final sourceEnemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    final chainEnemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );

    await game.add(sourceEnemy);
    await game.add(chainEnemy);
    await tester.pump();
    game.update(0);
    sourceEnemy.position =
        sniperTurret.position + Vector2(sniperTurret.range * 0.5, 0);
    chainEnemy.position = sourceEnemy.position + Vector2(1, 0);
    game.enemies.addAll([sourceEnemy, chainEnemy]);

    game.resolveInstantHit(owner: sniperTurret, target: sourceEnemy);
    game.update(0);

    expect(sourceEnemy.hp, closeTo(60, 0.001));
    expect(chainEnemy.hp, closeTo(80, 0.001));
    expect(sniperTurret.chainDamageDealt, closeTo(20, 0.001));
    expect(game.children.whereType<ChainProjectileComponent>(), isEmpty);
    expect(game.children.whereType<SniperChainBeamComponent>(), hasLength(1));
  });

  testWidgets('chain lightning hits sequential targets with delayed jumps', (
    tester,
  ) async {
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {1, 2, 3, 4, 5, 6},
        researchLevels: const {},
        unlockedStageCount: 7,
      );
    final game = RuneNexusGame(saveRepository: repository);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    game.selectTurretType(TurretType.lightning);
    game.tryBuildTurret(const GridPoint(2, 0));
    game.update(0);

    final turret = game.children.whereType<TurretComponent>().single;
    final first = chainEnemy(game, turret.position + Vector2(20, 0), 30);
    final second = chainEnemy(game, first.position + Vector2(20, 0), 20);
    final third = chainEnemy(game, second.position + Vector2(20, 0), 10);
    await game.add(first);
    await game.add(second);
    await game.add(third);
    await tester.pump();
    game.enemies.addAll([first, second, third]);

    game.resolveLightningChainAttack(owner: turret, target: first);
    game.update(0);

    expect(first.hp, closeTo(76, 0.001));
    expect(second.hp, closeTo(100, 0.001));
    expect(third.hp, closeTo(100, 0.001));
    expect(
      game.children.whereType<SequentialLightningChainComponent>(),
      hasLength(1),
    );

    game.update(0.069);
    expect(second.hp, closeTo(100, 0.001));

    game.update(0.002);
    expect(second.hp, closeTo(88, 0.001));
    expect(third.hp, closeTo(100, 0.001));

    game.update(0.07);
    expect(third.hp, closeTo(88, 0.001));
    expect(turret.directDamageDealt, closeTo(24, 0.001));
    expect(turret.chainDamageDealt, closeTo(24, 0.001));
    expect(game.children.whereType<LightningChainBeamComponent>(), isNotEmpty);
  });

  test('chain lightning charges before the first strike', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = TurretComponent(
      gridPoint: const GridPoint(2, 0),
      definition: gameTurrets[TurretType.lightning]!,
      game: game,
      center: Vector2(100, 100),
      tileSize: 32,
    );
    final target = chainEnemy(game, turret.position + Vector2(20, 0), 30);
    game.enemies.add(target);
    var released = false;
    final charge = LightningChargeComponent(
      chargePosition: () => turret.lightningChargePosition,
      isActive: () => true,
      onRelease: () {
        released = true;
        turret.releaseLightningCharge(turret.createAttackSnapshot());
      },
      color: turret.definition.color,
    );

    charge.update(0.299);
    expect(target.hp, closeTo(100, 0.001));
    expect(released, isFalse);

    charge.update(0.002);
    expect(target.hp, closeTo(76, 0.001));
    expect(released, isTrue);
    expect(game.children.whereType<LightningChainBeamComponent>(), isNotEmpty);
  });

  test('chain lightning gem and traits set chain target counts', () {
    final game = LinkResearchUnlockedGame();
    final base = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.lightning]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final gemmed = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.lightning]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..equipGem(GemType.chain, 0);
    final branched = levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent);
    final focused = levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.focusedLightning);

    expect(base.lightningChainMaxTargets, 3);
    expect(gemmed.lightningChainMaxTargets, 5);
    expect(branched.lightningChainMaxTargets, 4);
    expect(focused.lightningChainMaxTargets, 2);
  });

  test('current amplification only improves follow-up lightning damage', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent)
      ..chooseSecondaryTrait(TurretTraitType.currentAmplification);
    final first = chainEnemy(game, Vector2(20, 0), 10);
    final second = chainEnemy(game, Vector2(40, 0), 20);
    game.enemies.addAll([first, second]);

    game.resolveLightningChainAttack(owner: turret, target: first);
    game.resolveLightningChainJump(
      owner: turret,
      attack: turret.createAttackSnapshot(),
      sourcePosition: first.position,
      target: second,
    );

    expect(first.hp, closeTo(100 - turret.damage, 0.001));
    expect(
      second.hp,
      closeTo(
        100 - turret.damage * turret.lightningChainDamageMultiplier,
        0.001,
      ),
    );
  });

  test('lightning recovery shortens the current reload from unused jumps', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent)
      ..chooseSecondaryTrait(TurretTraitType.lightningRecovery);

    turret.restoreFromSaveData(
      SavedTurret(
        x: 0,
        y: 0,
        type: TurretType.lightning,
        level: 7,
        slotLimit: 1,
        cooldown: 1.25,
        equippedGems: const [],
        equippedGemSlots: const [null],
        investedGold: 140,
        damageDealt: 0,
        directDamageDealt: 0,
        splashDamageDealt: 0,
        chainDamageDealt: 0,
        burnDamageDealt: 0,
        targetPriority: TurretTargetPriority.first,
        primaryTrait: TurretTraitType.branchCurrent,
        secondaryTrait: TurretTraitType.lightningRecovery,
      ),
    );

    turret.recordLightningChainCompletion(usedJumps: 1, maxJumps: 3);

    expect(turret.cooldown, closeTo(1.25 / 1.3, 0.001));
  });

  test('explosion gem only splashes the first chain lightning target', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.lightning]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..equipGem(GemType.explosion, 0);
    final first = chainEnemy(game, Vector2(20, 0), 30);
    final splash = chainEnemy(game, first.position + Vector2(1, 0), 20);
    final chainTarget = chainEnemy(game, first.position + Vector2(50, 0), 10);
    game.enemies.addAll([first, splash, chainTarget]);

    game.resolveLightningChainAttack(owner: turret, target: first);
    game.resolveLightningChainJump(
      owner: turret,
      attack: turret.createAttackSnapshot(),
      sourcePosition: first.position,
      target: chainTarget,
    );

    expect(first.hp, closeTo(76, 0.001));
    expect(splash.hp, closeTo(91.6, 0.001));
    expect(chainTarget.hp, closeTo(88, 0.001));
  });

  test('chain hit from fire turret applies scaled burn', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.selectTurretType(TurretType.magic);
    game.tryBuildTurret(const GridPoint(2, 0));
    game.grantGem(GemType.chain);
    game.equipSelectedTurret(GemType.chain);
    final fireTurret = game.children.whereType<TurretComponent>().single;
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );

    game.resolveChainHit(
      owner: fireTurret,
      target: enemy,
      damage: fireTurret.damage * 0.5,
    );
    enemy.update(1);

    expect(enemy.hp, closeTo(88, 0.001));
    expect(fireTurret.damageDealt, closeTo(12, 0.001));
  });

  test(
    'ignition burst deals direct damage against an existing source burn',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.selectTurretType(TurretType.magic);
      game.tryBuildTurret(const GridPoint(2, 0));
      final fireTurret = game.children.whereType<TurretComponent>().single;
      while (fireTurret.level < 7) {
        fireTurret.upgradeLevel();
      }
      fireTurret
        ..choosePrimaryTrait(TurretTraitType.highHeatBurn)
        ..chooseSecondaryTrait(TurretTraitType.ignitionBurst);
      final enemy =
          EnemyComponent(
              definition: gameEnemies[EnemyType.normal]!,
              maxHp: 200,
              path: [Vector2.zero(), Vector2(100, 0)],
              game: game,
            )
            ..position = fireTurret.position.clone()
            ..applyBurn(
              damagePerSecond: 10,
              duration: 2,
              sourceTurretPoint: fireTurret.gridPoint,
            );

      await game.add(enemy);
      game.enemies.add(enemy);
      game.update(0);
      game.resolveProjectileHit(
        owner: fireTurret,
        attack: fireTurret.createAttackSnapshot(),
        target: enemy,
        hitPosition: enemy.position.clone(),
      );

      final ignitionBurstDamage = 10 * RuneNexusGame.burnDurationSeconds * 0.3;
      final expectedDirectDamage = fireTurret.damage + ignitionBurstDamage;
      expect(enemy.hp, closeTo(200 - expectedDirectDamage, 0.001));
      expect(
        fireTurret.directDamageDealt,
        closeTo(expectedDirectDamage, 0.001),
      );
    },
  );

  test('chain ignition transfers a killing burn to a nearby enemy', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.selectTurretType(TurretType.magic);
    game.tryBuildTurret(const GridPoint(2, 0));
    final fireTurret = game.children.whereType<TurretComponent>().single;
    while (fireTurret.level < 7) {
      fireTurret.upgradeLevel();
    }
    fireTurret
      ..choosePrimaryTrait(TurretTraitType.lingeringEmbers)
      ..chooseSecondaryTrait(TurretTraitType.chainIgnition);
    final source =
        EnemyComponent(
            definition: gameEnemies[EnemyType.normal]!,
            maxHp: 5,
            path: [Vector2.zero(), Vector2(100, 0)],
            game: game,
          )
          ..position = fireTurret.position.clone()
          ..applyBurn(
            damagePerSecond: 10,
            duration: 2,
            sourceTurretPoint: fireTurret.gridPoint,
          );
    final target =
        EnemyComponent(
            definition: gameEnemies[EnemyType.normal]!,
            maxHp: 100,
            path: [Vector2.zero(), Vector2(100, 0)],
            game: game,
          )
          ..position = fireTurret.position + Vector2(40, 0)
          ..distanceTravelled = 1;

    await game.add(source);
    await game.add(target);
    game.enemies.addAll([source, target]);
    game.update(0);

    source.update(1);
    target.update(0.6);

    expect(source.isDead, isTrue);
    expect(target.hp, closeTo(94, 0.001));
  });

  test(
    'chain ignition transfers when direct fire damage kills a burning enemy',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.selectTurretType(TurretType.magic);
      game.tryBuildTurret(const GridPoint(2, 0));
      final fireTurret = game.children.whereType<TurretComponent>().single;
      while (fireTurret.level < 7) {
        fireTurret.upgradeLevel();
      }
      fireTurret
        ..choosePrimaryTrait(TurretTraitType.highHeatBurn)
        ..chooseSecondaryTrait(TurretTraitType.chainIgnition);
      final source =
          EnemyComponent(
              definition: gameEnemies[EnemyType.normal]!,
              maxHp: 20,
              path: [Vector2.zero(), Vector2(100, 0)],
              game: game,
            )
            ..position = fireTurret.position.clone()
            ..applyBurn(
              damagePerSecond: 10,
              duration: 2,
              sourceTurretPoint: fireTurret.gridPoint,
            );
      final target =
          EnemyComponent(
              definition: gameEnemies[EnemyType.normal]!,
              maxHp: 100,
              path: [Vector2.zero(), Vector2(100, 0)],
              game: game,
            )
            ..position = fireTurret.position + Vector2(40, 0)
            ..distanceTravelled = 1;

      await game.add(source);
      await game.add(target);
      game.enemies.addAll([source, target]);
      game.update(0);

      game.resolveProjectileHit(
        owner: fireTurret,
        attack: fireTurret.createAttackSnapshot(),
        target: source,
        hitPosition: source.position.clone(),
      );
      target.update(0.6);

      final transferredDamage =
          fireTurret.damage *
          RuneNexusGame.burnDamagePerSecondScale *
          fireTurret.damageOverTimeDamageMultiplier *
          0.6;
      expect(source.isDead, isTrue);
      expect(target.hp, closeTo(100 - transferredDamage, 0.001));
    },
  );

  test('burn damage is credited to its source turret', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.selectTurretType(TurretType.magic);
    game.tryBuildTurret(const GridPoint(2, 0));
    final fireTurret = game.children.whereType<TurretComponent>().single;
    final enemy =
        EnemyComponent(
          definition: gameEnemies[EnemyType.normal]!,
          maxHp: 100,
          path: [Vector2.zero(), Vector2(100, 0)],
          game: game,
        )..applyBurn(
          damagePerSecond: 10,
          duration: 2,
          sourceTurretPoint: fireTurret.gridPoint,
        );

    enemy.update(1);

    expect(enemy.hp, closeTo(90, 0.001));
    expect(fireTurret.damageDealt, closeTo(10, 0.001));
    expect(fireTurret.burnDamageDealt, closeTo(10, 0.001));
    expect(
      game.snapshotNotifier.value.selectedTurretDamageDealt,
      closeTo(10, 0.001),
    );
    expect(
      game.snapshotNotifier.value.selectedTurretBurnDamageDealt,
      closeTo(10, 0.001),
    );
  });

  test('burn instances are saved with their source turret point', () {
    final game = RuneNexusGame();
    final enemy =
        EnemyComponent(
          definition: gameEnemies[EnemyType.normal]!,
          maxHp: 100,
          path: [Vector2.zero(), Vector2(100, 0)],
          game: game,
        )..applyBurn(
          damagePerSecond: 12,
          duration: 2.5,
          damageMultiplier: 1.2,
          sourceTurretPoint: const GridPoint(2, 0),
        );

    final saved = enemy.toSaveData();
    expect(saved.burnInstances, hasLength(1));
    expect(saved.burnInstances.single.sourcePoint, const GridPoint(2, 0));
    expect(saved.burnInstances.single.damagePerSecond, closeTo(12, 0.001));

    final restored = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..restoreFromSaveData(saved);

    restored.update(1);

    expect(restored.hp, closeTo(88, 0.001));
  });

  test('poison stacks as long low damage over time', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy =
        EnemyComponent(
            definition: normal,
            maxHp: 100,
            path: [Vector2.zero(), Vector2(100, 0)],
            game: game,
          )
          ..applyPoison(damagePerSecond: 3, duration: 6, maxStacks: 4)
          ..applyPoison(damagePerSecond: 3, duration: 6, maxStacks: 4);

    enemy.update(1);

    expect(enemy.hp, closeTo(94, 0.001));
  });

  test('enemy keeps path progress when board path is resized', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0), Vector2(100, 100)],
      game: game,
    );

    enemy.update(1);
    enemy.updatePath([Vector2.zero(), Vector2(200, 0), Vector2(200, 200)]);

    expect(enemy.position.x, closeTo(63, 0.001));
    expect(enemy.position.y, closeTo(0, 0.001));
  });

  test('enemy lane offset changes only visual path position', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      laneOffsetRatio: 0.12,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );

    enemy.update(1);

    expect(enemy.position.x, closeTo(31.5, 0.001));
    expect(enemy.position.y, closeTo(0, 0.001));
    expect(enemy.visualPosition.x, closeTo(enemy.position.x, 0.001));
    expect(enemy.visualPosition.y, closeTo(5.76 + math.sin(3.7) * 2.1, 0.001));
  });

  test('enemy visual bob is suppressed while moving vertically', () {
    final game = RuneNexusGame();
    final normal = gameEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      laneOffsetRatio: 0.12,
      path: [Vector2.zero(), Vector2(0, 500)],
      game: game,
    );

    enemy.update(1);

    expect(enemy.position.x, closeTo(0, 0.001));
    expect(enemy.position.y, closeTo(31.5, 0.001));
    expect(enemy.visualPosition.x, closeTo(-5.76, 0.001));
    expect(enemy.visualPosition.y, closeTo(enemy.position.y, 0.001));
  });

  test('enemy lane offset is saved and restored', () {
    final saved = SavedEnemy(
      type: EnemyType.normal,
      maxHp: 100,
      hp: 90,
      shield: 0,
      shieldBroken: false,
      armor: 0,
      distanceTravelled: 10,
      burnRemaining: 0,
      burnDamagePerSecond: 0,
      burnDamageMultiplier: 1,
      burnInstances: const [],
      poisonRemaining: 0,
      poisonDamagePerSecond: 0,
      poisonDamageMultiplier: 1,
      poisonStacks: 0,
      slowRemaining: 0,
      slowMultiplier: 1,
      physicalVulnerabilityRemaining: 0,
      physicalVulnerabilityBonus: 0,
      elementalVulnerabilityRemaining: 0,
      elementalVulnerabilityBonus: 0,
      laneOffsetRatio: -0.11,
    );

    final restored = SavedEnemy.fromJson(saved.toJson());

    expect(restored, isNotNull);
    expect(restored!.laneOffsetRatio, closeTo(-0.11, 0.001));
    expect(
      SavedEnemy.fromJson(
        Map<String, Object?>.of(saved.toJson())..remove('laneOffsetRatio'),
      )!.laneOffsetRatio,
      0,
    );
  });

  test('local save restores preparation setup without resume prompt', () async {
    final repository = MemorySaveRepository();
    final game = LinkResearchUnlockedGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.tryBuildTurret(const GridPoint(2, 0));
    final turret = game.children.whereType<TurretComponent>().single;
    turret.recordDamageDealt(123, TurretDamageKind.direct);
    game.grantGem(GemType.range);
    game.equipSelectedTurret(GemType.range);
    game.levelUpSelectedTurret();
    game.debugAddGold(100);
    game.upgradeSelectedTurretLink();
    await game.saveNow();

    final saved = repository.data;
    expect(saved, isNotNull);
    expect(saved!.activeRun!.turrets, hasLength(1));
    expect(saved.activeRun!.turrets.single.level, 2);
    expect(saved.activeRun!.turrets.single.slotLimit, 2);
    expect(saved.activeRun!.turrets.single.equippedGems, [GemType.range]);
    expect(saved.activeRun!.turrets.single.equippedGemSlots, [
      GemType.range,
      null,
    ]);
    expect(saved.activeRun!.turrets.single.investedGold, 192);
    expect(saved.activeRun!.turrets.single.damageDealt, closeTo(123, 0.001));
    expect(
      saved.activeRun!.turrets.single.directDamageDealt,
      closeTo(123, 0.001),
    );

    final restoredRepository = MemorySaveRepository()..data = saved;
    final restored = LinkResearchUnlockedGame(
      saveRepository: restoredRepository,
    );
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();

    expect(restored.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(restored.snapshotNotifier.value.restoredPhase, isNull);
    expect(restored.snapshotNotifier.value.hasStageProgress, isTrue);
    expect(restored.snapshotNotifier.value.placedTurretCount, 1);
    expect(restored.snapshotNotifier.value.round, 1);
    await restored.saveNow();

    final resumed = restoredRepository.data;
    expect(restored.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(resumed!.activeRun!.turrets.single.level, 2);
    expect(resumed.activeRun!.turrets.single.slotLimit, 2);
    expect(
      restored.children.whereType<TurretComponent>().single.damageDealt,
      closeTo(123, 0.001),
    );
    expect(
      restored.children.whereType<TurretComponent>().single.directDamageDealt,
      closeTo(123, 0.001),
    );
  });

  test('preparation actions mark stage progress before first wave', () async {
    final turretGame = RuneNexusGame(saveRepository: MemorySaveRepository());
    turretGame.onGameResize(Vector2(400, 800));
    await turretGame.onLoad();

    expect(turretGame.snapshotNotifier.value.hasStageProgress, isFalse);

    turretGame.tryBuildTurret(const GridPoint(2, 0));

    expect(turretGame.snapshotNotifier.value.hasStageProgress, isTrue);

    final upgradeGame = RuneNexusGame(saveRepository: MemorySaveRepository());
    upgradeGame.onGameResize(Vector2(400, 800));
    await upgradeGame.onLoad();

    expect(upgradeGame.snapshotNotifier.value.hasStageProgress, isFalse);

    upgradeGame.buyRunUpgrade(RunUpgradeType.waveGold);

    expect(upgradeGame.snapshotNotifier.value.hasStageProgress, isTrue);
  });

  test(
    'menu preparation loads saved stage progress before game widget',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(saveRepository: repository);

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.tryBuildTurret(const GridPoint(2, 0));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await game.saveNow();
      expect(repository.data!.activeRun!.turrets, hasLength(1));

      final restoredRepository = MemorySaveRepository()..data = repository.data;
      final restored = RuneNexusGame(saveRepository: restoredRepository);
      await restored.prepareSavedStateForMenu();

      expect(restored.snapshotNotifier.value.phase, GamePhase.preparation);
      expect(restored.snapshotNotifier.value.hasStageProgress, isTrue);
      expect(restored.snapshotNotifier.value.placedTurretCount, 1);
      expect(restored.snapshotNotifier.value.round, 1);
    },
  );

  test('purchased reward options stay fixed after menu restore', () async {
    const rewardOptions = [
      GemType.chain,
      GemType.range,
      GemType.physicalDamage,
    ];
    final repository = MemorySaveRepository()
      ..data = saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        gemShards: 5,
        phase: GamePhase.reward,
        isPurchasedGemReward: true,
        rewardOptions: rewardOptions,
      );
    final restored = RuneNexusGame(saveRepository: repository);

    await restored.prepareSavedStateForMenu();

    final snapshot = restored.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.reward);
    expect(snapshot.isPurchasedGemReward, isTrue);
    expect(snapshot.rewardOptions, rewardOptions);
    expect(snapshot.gemShards, 5);
  });

  test(
    'purchased reward options are kept when full game load follows menu save',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithResearch(
          clearedStageNumbers: const {},
          researchLevels: const {},
          gemShards: RuneNexusGame.gemChoicePurchaseCost,
          roundIndex: 1,
          mapSignature: const GameSaveAdapter().mapSignature(gameMap),
        );
      final game = RuneNexusGame(saveRepository: repository);

      await game.prepareSavedStateForMenu();
      game.purchaseGemChoice();
      await game.saveNow();

      final savedOptions = repository.data!.activeRun!.rewardOptions;
      expect(repository.data!.activeRun!.phase, GamePhase.reward);
      expect(savedOptions, isNotEmpty);

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      final snapshot = game.snapshotNotifier.value;
      expect(snapshot.phase, GamePhase.reward);
      expect(snapshot.isPurchasedGemReward, isTrue);
      expect(snapshot.rewardOptions, savedOptions);
      expect(repository.data!.activeRun!.rewardOptions, savedOptions);
    },
  );

  test(
    'empty purchased reward save is recovered with stable options',
    () async {
      final repository = MemorySaveRepository()
        ..data = saveWithResearch(
          clearedStageNumbers: const {},
          researchLevels: const {},
          gemShards: 5,
          phase: GamePhase.reward,
          isPurchasedGemReward: true,
        );
      final restored = RuneNexusGame(saveRepository: repository);

      await restored.prepareSavedStateForMenu();
      await restored.saveNow();

      final snapshot = restored.snapshotNotifier.value;
      expect(snapshot.phase, GamePhase.reward);
      expect(snapshot.isPurchasedGemReward, isTrue);
      expect(snapshot.rewardOptions, const [
        GemType.attackSpeed,
        GemType.range,
        GemType.physicalDamage,
      ]);
      expect(snapshot.gemShards, 5);
      expect(repository.data!.activeRun!.phase, GamePhase.reward);
      expect(repository.data!.activeRun!.isPurchasedGemReward, isTrue);
      expect(repository.data!.activeRun!.rewardOptions, snapshot.rewardOptions);
    },
  );

  test('debug gem reward opens choices without seeding owned gems', () async {
    const debugPanelEnabled = bool.fromEnvironment('RUNE_NEXUS_DEBUG_PANEL');
    if (!debugPanelEnabled) {
      return;
    }
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.debugOpenGemReward();

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.reward);
    expect(snapshot.rewardOptions, isNotEmpty);
    expect(snapshot.gemInventory, isEmpty);
    expect(snapshot.gemCollection, isEmpty);
  });

  test(
    'local save restores active enemy durability and path progress',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(saveRepository: repository);

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.startNextWave();
      game.update(0.9);
      expect(game.enemies, isNotEmpty);

      final enemy = game.enemies.first;
      enemy.receiveDamage(5);
      game.update(0.5);
      await game.saveNow();

      final saved = repository.data;
      expect(saved, isNotNull);
      expect(saved!.activeRun!.phase, GamePhase.wave);
      expect(saved.activeRun!.enemies, isNotEmpty);
      expect(
        saved.activeRun!.enemies.first.hp,
        lessThan(scaledEnemyMaxHp(enemy.definition, 1)),
      );
      expect(saved.activeRun!.enemies.first.distanceTravelled, greaterThan(0));
      expect(saved.activeRun!.spawnQueue, isNotEmpty);

      final restoredRepository = MemorySaveRepository()..data = saved;
      final restored = RuneNexusGame(saveRepository: restoredRepository);
      restored.onGameResize(Vector2(400, 800));
      await restored.onLoad();

      expect(restored.snapshotNotifier.value.phase, GamePhase.restored);
      expect(restored.snapshotNotifier.value.restoredPhase, GamePhase.wave);
      expect(restored.snapshotNotifier.value.round, 1);
      restored.update(1);
      await restored.saveNow();

      expect(
        restoredRepository.data!.activeRun!.enemies.first.distanceTravelled,
        closeTo(saved.activeRun!.enemies.first.distanceTravelled, 0.001),
      );
      expect(
        restoredRepository.data!.activeRun!.enemies.first.armor,
        closeTo(saved.activeRun!.enemies.first.armor, 0.001),
      );

      restored.continueRestoredRun();
      expect(restored.snapshotNotifier.value.phase, GamePhase.wave);
    },
  );

  test('discarding a restored run settles failure rewards', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(
      saveRepository: repository,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'first',
          groups: [],
          clearRewardGold: 0,
        ),
        WaveDefinition(
          round: 2,
          previewText: 'second',
          groups: [
            SpawnGroup(enemyType: EnemyType.normal, count: 1, interval: 10),
          ],
          clearRewardGold: 0,
        ),
      ],
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();
    game.update(0.016);
    expect(game.snapshotNotifier.value.completedRounds, 1);

    game.startNextWave();
    await game.saveNow();

    final saved = repository.data;
    expect(saved, isNotNull);
    expect(saved!.activeRun!.phase, GamePhase.wave);

    final restoredRepository = MemorySaveRepository()..data = saved;
    final restored = RuneNexusGame(saveRepository: restoredRepository);
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();

    expect(restored.snapshotNotifier.value.phase, GamePhase.restored);

    await restored.discardRestoredRun();

    final snapshot = restored.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.preparation);
    expect(snapshot.runes, 2);
    expect(snapshot.bestRoundsByStage[1], 1);
  });

  test('turrets can be built and leveled while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = LinkResearchUnlockedGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();

    game.tryBuildTurret(const GridPoint(2, 0));
    game.levelUpSelectedTurret();
    await game.saveNow();

    final saved = repository.data;
    expect(game.snapshotNotifier.value.phase, GamePhase.wave);
    expect(saved, isNotNull);
    expect(saved!.activeRun!.phase, GamePhase.wave);
    expect(saved.activeRun!.turrets, hasLength(1));
    expect(saved.activeRun!.turrets.single.level, 2);
  });

  test('turret link can be upgraded while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = LinkResearchUnlockedGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();
    game.tryBuildTurret(const GridPoint(2, 0));
    game.debugAddGold(1000);

    game.upgradeSelectedTurretLink();
    await game.saveNow();

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.wave);
    expect(snapshot.selectedTurretSlotLimit, 2);
    expect(repository.data!.activeRun!.turrets.single.slotLimit, 2);
  });

  test(
    'gem can be equipped into an empty socket while a round is running',
    () async {
      final repository = MemorySaveRepository();
      final game = LinkResearchUnlockedGame(saveRepository: repository);

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.startNextWave();
      game.tryBuildTurret(const GridPoint(2, 0));
      game.grantGem(GemType.range);

      game.equipSelectedTurret(GemType.range);
      await game.saveNow();

      final snapshot = game.snapshotNotifier.value;
      expect(snapshot.phase, GamePhase.wave);
      expect(snapshot.selectedTurretGems, [GemType.range]);
      expect(snapshot.gemInventory[GemType.range], isNull);
      expect(repository.data!.activeRun!.turrets.single.equippedGemSlots, [
        GemType.range,
      ]);
    },
  );

  test('gem can be replaced and removed while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = LinkResearchUnlockedGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();
    game.tryBuildTurret(const GridPoint(2, 0));
    game.grantGem(GemType.range);
    game.equipSelectedTurret(GemType.range);
    game.selectSelectedTurretGemSlot(0);
    game.grantGem(GemType.chain);

    game.equipSelectedTurret(GemType.chain);
    var snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.wave);
    expect(snapshot.selectedTurretGems, [GemType.chain]);
    expect(snapshot.gemInventory[GemType.range], 1);
    expect(snapshot.gemInventory[GemType.chain], isNull);

    game.removeSelectedTurretGemSlot();

    snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.wave);
    expect(snapshot.selectedTurretGems, [null]);
    expect(snapshot.gemInventory[GemType.range], 1);
    expect(snapshot.gemInventory[GemType.chain], 1);
  });

  test(
    'projectile hit keeps launch gem profile after in-combat replacement',
    () async {
      final game = LinkResearchUnlockedGame(
        saveRepository: MemorySaveRepository(),
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      game.tryBuildTurret(const GridPoint(2, 0));
      final turret = game.children.whereType<TurretComponent>().single;
      turret.equipGem(GemType.explosion, 0);
      final launchedAttack = turret.createAttackSnapshot();
      turret
        ..removeGemAt(0)
        ..equipGem(GemType.range, 0);

      final target = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(100, 0)],
        game: game,
      )..position = turret.position + Vector2(10, 0);
      final splashTarget = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 100,
        path: [Vector2.zero(), Vector2(100, 0)],
        game: game,
      )..position = target.position + Vector2(8, 0);

      await game.add(target);
      await game.add(splashTarget);
      game.enemies.addAll([target, splashTarget]);
      game.update(0);

      game.resolveProjectileHit(
        owner: turret,
        attack: launchedAttack,
        target: target,
        hitPosition: target.position.clone(),
      );

      expect(turret.hasGem(GemType.range), isTrue);
      expect(turret.hasGem(GemType.explosion), isFalse);
      expect(target.hp, lessThan(100));
      expect(splashTarget.hp, lessThan(100));
    },
  );

  test('turret refund returns investment and equipped gems', () async {
    final repository = MemorySaveRepository();
    final game = LinkResearchUnlockedGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.tryBuildTurret(const GridPoint(2, 0));
    game.grantGem(GemType.range);
    game.equipSelectedTurret(GemType.range);
    game.levelUpSelectedTurret();
    game.debugAddGold(100);
    game.upgradeSelectedTurretLink();

    expect(game.snapshotNotifier.value.selectedTurretRefundGold, 144);
    game.refundSelectedTurret();
    await game.saveNow();

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.gold, 222);
    expect(snapshot.selectedTurretPoint, isNull);
    expect(snapshot.gemInventory[GemType.range], 1);
    expect(repository.data!.activeRun!.turrets, isEmpty);
  });

  test('turret refund is allowed while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();
    game.tryBuildTurret(const GridPoint(2, 0));

    game.refundSelectedTurret();
    await game.saveNow();

    expect(game.snapshotNotifier.value.phase, GamePhase.wave);
    expect(game.snapshotNotifier.value.gold, 155);
    expect(game.snapshotNotifier.value.selectedTurretPoint, isNull);
    expect(repository.data!.activeRun!.turrets, isEmpty);
  });

  test('turret refund stops later burn credit to a rebuilt turret', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    const point = GridPoint(2, 0);
    final normal = gameEnemies[EnemyType.normal]!;

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.selectTurretType(TurretType.magic);
    game.tryBuildTurret(point);
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 1000,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyBurn(damagePerSecond: 1, duration: 2, sourceTurretPoint: point);
    game.enemies.add(enemy);

    game.refundSelectedTurret();
    game.selectTurretType(TurretType.arrow);
    game.tryBuildTurret(point);
    enemy.update(1);

    expect(game.snapshotNotifier.value.selectedTurretDamageDealt, 0);
  });
}
