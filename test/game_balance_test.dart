import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/data/definitions/game_daily_quest_data.dart';
import 'package:rune_nexus/data/definitions/game_run_upgrade_data.dart';
import 'package:rune_nexus/data/definitions/game_stage_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/core/core_ability.dart';
import 'package:rune_nexus/domain/daily_quest/daily_quest_type.dart';
import 'package:rune_nexus/domain/enemy/enemy_definition.dart';
import 'package:rune_nexus/domain/enemy/enemy_resistance_profile.dart';
import 'package:rune_nexus/domain/enemy/enemy_scaling.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/domain/map/map_tile_theme.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/domain/research/research_progress.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/domain/run_upgrade/run_upgrade_type.dart';
import 'package:rune_nexus/domain/stage/stage_definition.dart';
import 'package:rune_nexus/domain/turret/attack_tag.dart';
import 'package:rune_nexus/domain/turret/damage_family.dart';
import 'package:rune_nexus/domain/turret/turret_definition.dart';
import 'package:rune_nexus/domain/turret/turret_target_priority.dart';
import 'package:rune_nexus/domain/turret/turret_trait_type.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/wave/wave_definition.dart';
import 'package:rune_nexus/game/components/chain_projectile_component.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/gem_equip_effect_component.dart';
import 'package:rune_nexus/game/components/lightning_charge_component.dart';
import 'package:rune_nexus/game/components/lightning_chain_beam_component.dart';
import 'package:rune_nexus/game/components/projectile_component.dart';
import 'package:rune_nexus/game/components/rift_mark_pulse_component.dart';
import 'package:rune_nexus/game/components/sequential_lightning_chain_component.dart';
import 'package:rune_nexus/game/components/sniper_chain_beam_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/game_save_adapter.dart';
import 'package:rune_nexus/game/systems/gem_reward_generator.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';
import 'package:rune_nexus/game/systems/wave_spawner.dart';

void main() {
  test('game stage uses 50 survival rounds', () {
    expect(gameStages, hasLength(15));
    expect(gameStages.first.id, 1);
    expect(gameStages.last.id, 15);
    expect(gameWaves, hasLength(50));
    expect(gameWaves.first.round, 1);
    expect(gameWaves.last.round, 50);
    expect(gameStage2Waves, hasLength(50));
    expect(gameStage2Waves.first.round, 1);
    expect(gameStage2Waves.last.round, 50);
    expect(gameChapter2Waves, hasLength(50));
    expect(gameChapter2Waves.first.round, 1);
    expect(gameChapter2Waves.last.round, 50);
    expect(gameChapter2Stage7Waves, hasLength(50));
    expect(gameChapter2Stage8Waves, hasLength(50));
    expect(gameChapter2Stage9Waves, hasLength(50));
    expect(gameChapter2Stage10Waves, hasLength(50));
    expect(gameChapter3Waves, hasLength(50));
    expect(gameChapter3Stage12Waves, hasLength(50));
    expect(gameChapter3Stage13Waves, hasLength(50));
    expect(gameChapter3Stage14Waves, hasLength(50));
    expect(gameChapter3Stage15Waves, hasLength(50));
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
      _expectValidMapPath(chapterTwo);
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
      _expectValidMapPath(chapterThree);
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
    expect(game.snapshotNotifier.value.lastRunRuneReward, 1);
    expect(game.snapshotNotifier.value.runes, 1);
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

    while (game.snapshotNotifier.value.gemShards <
        RuneNexusGame.gemChoicePurchaseCost) {
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

    while (game.snapshotNotifier.value.gemShards <
        RuneNexusGame.gemChoicePurchaseCost) {
      game.startNextWave();
      game.update(0.016);
      final snapshot = game.snapshotNotifier.value;
      if (snapshot.phase == GamePhase.reward) {
        game.selectRewardGem(snapshot.rewardOptions.first);
      }
    }

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
      ..data = _saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        gemShards: RuneNexusGame.gemChoicePurchaseCost,
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
    final previousDistance = enemy.distanceTravelled;

    expect(game.purchaseGemChoice(), isTrue);
    await game.saveNow();
    game.update(1);

    expect(game.snapshotNotifier.value.phase, GamePhase.reward);
    expect(repository.data!.rewardReturnPhase, GamePhase.wave);
    expect(enemy.distanceTravelled, previousDistance);
  });

  test('combat gem reward restore resumes wave after selection', () async {
    final repository = MemorySaveRepository()
      ..data = _saveWithResearch(
        clearedStageNumbers: const {},
        researchLevels: const {},
        gemShards: RuneNexusGame.gemChoicePurchaseCost,
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
    expect(saved.phase, GamePhase.reward);
    expect(saved.rewardReturnPhase, GamePhase.wave);
    expect(saved.enemies, isNotEmpty);

    final legacyJson = Map<String, Object?>.of(saved.toJson())
      ..remove('rewardReturnPhase');
    final parsedLegacySave = GameSaveData.fromJson(legacyJson)!;
    expect(parsedLegacySave.rewardReturnPhase, GamePhase.wave);

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
    expect(game.snapshotNotifier.value.lastRunRuneReward, 1);
    expect(game.snapshotNotifier.value.runes, 1);
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

  test('nexus defeat plays core destruction before failure panel', () async {
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
    expect(repository.data?.phase, isNot(GamePhase.coreDestruction));
    expect(game.enemies, contains(lingeringEnemy));

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
    final expectedScale = 41.9 / 48;

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
        definition: _targetPriorityTestTurret,
        game: game,
        center: Vector2(100, 100),
        tileSize: 32,
      )..setTargetPriority(entry.key);
      final enemies = {
        'front': _targetPriorityEnemy(
          game: game,
          hp: 100,
          progress: 90,
          position: turret.position + Vector2(70, 0),
        ),
        'back': _targetPriorityEnemy(
          game: game,
          hp: 100,
          progress: 10,
          position: turret.position + Vector2(65, 0),
        ),
        'strong': _targetPriorityEnemy(
          game: game,
          hp: 200,
          progress: 50,
          position: turret.position + Vector2(60, 0),
        ),
        'weak': _targetPriorityEnemy(
          game: game,
          hp: 20,
          progress: 50,
          position: turret.position + Vector2(55, 0),
        ),
        'near': _targetPriorityEnemy(
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
            ? enemyEntry.value.maxHp - _targetPriorityTestTurret.damage
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
      ..data = _saveWithResearch(
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
      definition: gameTurrets[saved!.turrets.single.type]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..restoreFromSaveData(saved.turrets.single);

    expect(
      game.snapshotNotifier.value.selectedTurretTargetPriority,
      TurretTargetPriority.strongest,
    );
    expect(saved.turrets.single.targetPriority, TurretTargetPriority.strongest);
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
    final unlockedGame = _LinkResearchUnlockedGame();
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
    final discountedGame = _FirstLinkDiscountGame();
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
  });

  test('daily quests grant free diamonds once and persist state', () {
    const nowMillis = 1780675200000;
    final progression = RunProgression();

    progression.recordDailyQuestProgress(
      DailyQuestType.clearWaves,
      amount: 30,
      nowMillis: nowMillis,
    );

    expect(
      progression.claimDailyQuestReward(
        DailyQuestType.clearWaves,
        nowMillis: nowMillis,
      ),
      isTrue,
    );
    expect(
      progression.claimDailyQuestReward(
        DailyQuestType.clearWaves,
        nowMillis: nowMillis,
      ),
      isFalse,
    );
    expect(progression.freeDiamonds, 10);
    expect(progression.paidDiamonds, 0);

    final saved = SavedProgression.fromJson(progression.toSaveData().toJson());
    final restored = RunProgression()..restoreFromSaveData(saved);

    expect(restored.dailyQuestDayKey, progression.dailyQuestDayKey);
    expect(restored.dailyQuestProgress[DailyQuestType.clearWaves], 30);
    expect(
      restored.claimedDailyQuestRewards,
      contains(DailyQuestType.clearWaves),
    );
    expect(restored.freeDiamonds, 10);
  });

  test('daily all complete reward grants twenty free diamonds once', () {
    const nowMillis = 1780675200000;
    final progression = RunProgression();

    for (final entry in gameDailyQuestDefinitions.entries) {
      progression.recordDailyQuestProgress(
        entry.key,
        amount: entry.value.targetCount,
        nowMillis: nowMillis,
      );
    }

    expect(progression.completedDailyQuestCount, 4);
    expect(
      progression.claimDailyQuestAllCompleteReward(nowMillis: nowMillis),
      isTrue,
    );
    expect(
      progression.claimDailyQuestAllCompleteReward(nowMillis: nowMillis),
      isFalse,
    );
    expect(progression.freeDiamonds, 20);
  });

  test('daily quests reset at KST five and block clock rollback claims', () {
    final beforeReset = DateTime.utc(2026, 6, 5, 19, 59).millisecondsSinceEpoch;
    final afterReset = DateTime.utc(2026, 6, 5, 20).millisecondsSinceEpoch;
    final progression = RunProgression();

    progression.recordDailyQuestProgress(
      DailyQuestType.killEnemies,
      amount: 100,
      nowMillis: beforeReset,
    );
    final previousDayKey = progression.dailyQuestDayKey;

    expect(progression.refreshDailyQuests(nowMillis: afterReset), isTrue);
    expect(progression.dailyQuestDayKey, isNot(previousDayKey));
    expect(progression.dailyQuestProgress, isEmpty);
    expect(progression.dailyQuestClockRollbackDetected, isFalse);

    progression.refreshDailyQuests(nowMillis: afterReset + 3600000);
    progression.recordDailyQuestProgress(
      DailyQuestType.killEnemies,
      amount: 100,
      nowMillis: afterReset,
    );

    expect(progression.dailyQuestClockRollbackDetected, isTrue);
    expect(
      progression.claimDailyQuestReward(
        DailyQuestType.killEnemies,
        nowMillis: afterReset,
      ),
      isFalse,
    );
    expect(progression.freeDiamonds, 0);
  });

  test('daily quests track wave, boss, enemy, and run upgrades', () async {
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

    game.buyRunUpgrade(RunUpgradeType.towerDamage);
    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType
          .buyRunUpgrades],
      1,
    );

    final normal = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(normal);
    normal.receiveDamage(999);

    final boss = EnemyComponent(
      definition: gameEnemies[EnemyType.boss]!,
      maxHp: 1,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );
    game.enemies.add(boss);
    boss.receiveDamage(999);

    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType
          .killEnemies],
      2,
    );
    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType.killBosses],
      1,
    );

    game.startNextWave();
    game.update(0.016);

    expect(
      game.snapshotNotifier.value.dailyQuestProgress[DailyQuestType.clearWaves],
      1,
    );
  });

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

  test('run upgrade limit researches unlock after stage eight clear', () {
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

  test('debug round control jumps to requested preparation round', () {
    final game = RuneNexusGame();

    game.debugSetRound(25);

    expect(game.snapshotNotifier.value.round, 25);
    expect(game.snapshotNotifier.value.previewText, gameWaves[24].previewText);

    game.debugSetRound(999);

    expect(game.snapshotNotifier.value.round, 50);
  });

  test('debug force victory completes current stage', () {
    final game = RuneNexusGame();

    game.debugSetRound(25);
    game.debugForceVictory();

    final snapshot = game.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.success);
    expect(snapshot.completedRounds, 50);
    expect(snapshot.lastRunRuneReward, 200);
    expect(snapshot.lastRunWasNewBestRound, isTrue);
    expect(snapshot.lastRunUnlockedStageNumber, 2);
    expect(snapshot.unlockedStageCount, 2);
    expect(snapshot.clearedStageNumbers, contains(1));
  });

  test('debug force defeat starts core destruction sequence', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.debugSetRound(25);
    game.debugForceDefeat();

    expect(game.snapshotNotifier.value.nexusHp, 0);
    expect(game.snapshotNotifier.value.phase, GamePhase.coreDestruction);

    game.update(1.6);

    expect(game.snapshotNotifier.value.phase, GamePhase.coreDestruction);

    game.update(1.7);

    expect(game.snapshotNotifier.value.phase, GamePhase.failure);
    expect(game.snapshotNotifier.value.completedRounds, 24);
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
    expect(game.snapshotNotifier.value.bestRoundsByStage[5], 50);
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
    expect(game.snapshotNotifier.value.corePassiveSlotCount, 1);

    game.debugAddDiamonds(200);
    expect(game.unlockCorePassiveSlot(), isTrue);
    expect(
      game.equipCorePassiveAbility(CorePassiveAbility.selfRepair, 1),
      isTrue,
    );
    expect(game.snapshotNotifier.value.corePassiveSlotCount, 2);
    expect(
      game.snapshotNotifier.value.corePassiveSlots[1],
      CorePassiveAbility.selfRepair,
    );

    game.debugResetCorePassiveProgress();
    expect(game.snapshotNotifier.value.corePassiveSlotCount, 1);
    expect(game.snapshotNotifier.value.corePassiveSlots, const [null, null]);

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
    'skill acceleration core passive reduces combat skill cooldown only',
    () async {
      final repository = MemorySaveRepository()
        ..data = _saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 0,
          unlockedStageCount: 3,
          clearedStageNumbers: const {1, 2},
          passiveSlots: const [CorePassiveAbility.skillAcceleration, null],
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
      expect(game.nexusCoreBeamIntervalSeconds, closeTo(4.5, 0.001));
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

      game.update(4.49);

      expect(game.nexusCoreBeamActive, isFalse);
      expect(enemy.hp, enemy.maxHp);

      game.update(0.02);

      expect(game.nexusCoreBeamActive, isTrue);
      expect(enemy.hp, lessThan(enemy.maxHp));
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
        ..data = _saveWithCorePassiveRun(
          nexusHp: 20,
          roundIndex: 0,
          completedRounds: 0,
          unlockedStageCount: 6,
          clearedStageNumbers: const {1, 2, 3, 4, 5},
          passiveSlots: const [],
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
        _durabilityEnemy(game, hp: 10, progress: 10),
        _durabilityEnemy(game, hp: 80, progress: 20),
        _durabilityEnemy(game, hp: 40, armor: 30, progress: 30),
        _durabilityEnemy(game, hp: 80, progress: 40),
        _durabilityEnemy(game, hp: 60, progress: 50),
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

  test('rift mark cooldown is reduced by skill acceleration', () async {
    final repository = MemorySaveRepository()
      ..data = _saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        unlockedStageCount: 6,
        clearedStageNumbers: const {1, 2, 3, 4, 5},
        passiveSlots: const [CorePassiveAbility.skillAcceleration, null],
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

    final enemy = _durabilityEnemy(game, hp: 100, progress: 10);
    await game.add(enemy);
    game.enemies.add(enemy);

    expect(game.nexusCoreBeamIntervalSeconds, closeTo(9, 0.001));
    game.update(8.99);
    expect(enemy.hasRiftMark, isFalse);

    game.update(0.02);
    expect(enemy.hasRiftMark, isTrue);
    expect(game.coreCombatSkillActivationCount, 1);
  });

  test('rift mark state is saved and restored', () async {
    final repository = MemorySaveRepository()
      ..data = _saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        unlockedStageCount: 6,
        clearedStageNumbers: const {1, 2, 3, 4, 5},
        passiveSlots: const [],
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

    final enemy = _durabilityEnemy(game, hp: 100, progress: 10)
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
      final saved = _saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 1,
        completedRounds: 1,
        passiveSlots: const [],
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
    'core progression defaults to guardian beam with empty passive slots',
    () {
      final saved = SavedProgression.fromJson(const <String, Object?>{
        'unlockedStageCount': 1,
      });
      final progression = RunProgression()..restoreFromSaveData(saved);

      expect(progression.coreCombatSkill, CoreCombatSkill.guardianBeam);
      expect(progression.corePassiveSlots, const [null, null]);
      expect(
        progression.toSaveData().coreCombatSkill,
        CoreCombatSkill.guardianBeam,
      );
      expect(
        progression.unlockedCorePassiveAbilities,
        containsAll({
          CorePassiveAbility.selfRepair,
          CorePassiveAbility.costSavingDesign,
          CorePassiveAbility.skillAcceleration,
        }),
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

  test('core passive equipment is saved and restored when unlocked', () {
    const saved = SavedProgression(
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
      corePassiveSlotTwoUnlocked: true,
      corePassiveSlots: [
        CorePassiveAbility.selfRepair,
        CorePassiveAbility.costSavingDesign,
      ],
    );
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.corePassiveSlots, saved.corePassiveSlots);
    expect(
      progression.unlockedCorePassiveAbilities,
      contains(CorePassiveAbility.skillAcceleration),
    );
    final savedAgain = progression.toSaveData();
    expect(savedAgain.corePassiveSlots, saved.corePassiveSlots);
  });

  test('second core passive slot unlock spends diamonds', () {
    final progression = RunProgression()
      ..runes = 500
      ..freeDiamonds = 120
      ..paidDiamonds = 80;

    expect(progression.corePassiveSlotCount, 1);
    expect(progression.canUnlockCorePassiveSlot, isTrue);
    expect(progression.unlockCorePassiveSlot(), isTrue);
    expect(progression.runes, 500);
    expect(progression.freeDiamonds, 0);
    expect(progression.paidDiamonds, 0);
    expect(progression.corePassiveSlotCount, 2);
    expect(progression.toSaveData().corePassiveSlotTwoUnlocked, isTrue);
    expect(progression.unlockCorePassiveSlot(), isFalse);
  });

  test('core passive equipment can be unequipped by slot', () {
    const saved = SavedProgression(
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
      corePassiveSlots: [CorePassiveAbility.selfRepair, null],
    );
    final progression = RunProgression()..restoreFromSaveData(saved);

    expect(progression.unequipCorePassiveAbility(0), isTrue);
    expect(progression.corePassiveSlots, const [null, null]);
    expect(progression.toSaveData().corePassiveSlots, const [null, null]);
  });

  test(
    'self repair core passive restores nexus hp every fifth round',
    () async {
      final repository = MemorySaveRepository()
        ..data = _saveWithCorePassiveRun(
          nexusHp: 19,
          roundIndex: 4,
          completedRounds: 4,
          passiveSlots: const [CorePassiveAbility.selfRepair, null],
        );
      final game = RuneNexusGame(
        waves: _emptyWaves(5),
        saveRepository: repository,
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      expect(game.snapshotNotifier.value.nexusHp, 19);

      game.startNextWave();
      game.update(0.016);

      expect(game.snapshotNotifier.value.completedRounds, 5);
      expect(game.snapshotNotifier.value.phase, GamePhase.success);
      expect(game.snapshotNotifier.value.nexusHp, 20);
    },
  );

  test('self repair core passive does not exceed max nexus hp', () async {
    final repository = MemorySaveRepository()
      ..data = _saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 4,
        completedRounds: 4,
        passiveSlots: const [CorePassiveAbility.selfRepair, null],
      );
    final game = RuneNexusGame(
      waves: _emptyWaves(5),
      saveRepository: repository,
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.nexusHp, 20);
    expect(game.snapshotNotifier.value.maxNexusHp, 20);
  });

  test('cost saving design only discounts turret construction', () async {
    final repository = MemorySaveRepository()
      ..data = _saveWithCorePassiveRun(
        nexusHp: 20,
        roundIndex: 0,
        completedRounds: 0,
        unlockedStageCount: 2,
        clearedStageNumbers: const {1},
        passiveSlots: const [CorePassiveAbility.costSavingDesign, null],
      );
    final game = RuneNexusGame(saveRepository: repository);
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    expect(game.turretBuildCost(TurretType.arrow), 51);

    game.tryBuildTurret(const GridPoint(2, 0));

    expect(game.snapshotNotifier.value.gold, 119);
    expect(game.snapshotNotifier.value.selectedTurretRefundGold, 38);
    expect(game.snapshotNotifier.value.selectedTurretLevelUpCost, 42);

    game.levelUpSelectedTurret();

    expect(game.snapshotNotifier.value.gold, 77);
    expect(game.snapshotNotifier.value.selectedTurretRefundGold, 69);

    game.refundSelectedTurret();

    expect(game.snapshotNotifier.value.gold, 146);
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
    expect(countType(gameChapter2Stage10Waves, 50, EnemyType.shieldBoss), 1);
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
    expect(countType(gameChapter3Stage15Waves, 50, EnemyType.forgeBoss), 1);
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
      42,
      54,
      70,
      91,
      119,
      154,
      201,
      261,
      339,
      441,
      573,
      746,
      969,
      1260,
      1638,
      2129,
      2768,
      3599,
      4678,
    ];

    expect(definition.maxLevel, 20);
    expect(definition.costMultiplier, 1.3);
    for (var level = 0; level < costs.length; level++) {
      expect(definition.costForLevel(level), costs[level]);
    }
    expect(definition.costForLevel(costs.length), 0);
  });

  test(
    'run upgrade limit research lets only matching upgrade exceed base cap',
    () async {
      final definition = gameRunUpgrades[RunUpgradeType.towerDamage]!;
      final costAtBaseCap = definition.costForLevel(20, maxLevel: 30);
      final repository = MemorySaveRepository()
        ..data = _saveWithResearch(
          clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7, 8},
          researchLevels: const {ResearchType.towerDamageLimitExpansion: 10},
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
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

  test('stage rune reward bonus scales repeat rewards', () {
    final progression = RunProgression();

    expect(progression.runeRewardFor(0, success: false), 0);
    expect(progression.runeRewardFor(0, success: true), 0);
    expect(progression.runeRewardFor(1, success: false), 1);
    expect(progression.runeRewardFor(10, success: false), 16);
    expect(progression.runeRewardFor(20, success: false), 39);
    expect(progression.runeRewardFor(30, success: false), 73);
    expect(progression.runeRewardFor(40, success: false), 124);
    expect(progression.runeRewardFor(50, success: true), 200);
    expect(progression.runeRewardFor(50, success: true, stageNumber: 2), 240);
    expect(progression.runeRewardFor(50, success: true, stageNumber: 3), 290);
    expect(progression.runeRewardFor(50, success: true, stageNumber: 4), 350);
    expect(progression.runeRewardFor(50, success: true, stageNumber: 5), 420);
    expect(progression.runeRewardFor(50, success: true, stageNumber: 15), 1670);
    expect(progression.runeRewardFor(50, success: true, stageNumber: 16), 1670);

    progression.researchLevels[ResearchType.runeResonance] = 20;
    expect(progression.runeRewardFor(50, success: true), 280);
    expect(progression.runeRewardFor(50, success: true, stageNumber: 8), 966);
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
      ..data = _saveWithResearch(
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
      ..data = _saveWithResearch(
        clearedStageNumbers: const {1, 2},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 3,
      );
    final game = _LinkResearchUnlockedGame(
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
      ..data = _saveWithResearch(
        clearedStageNumbers: const {1, 2, 3, 4, 5, 6, 7},
        researchLevels: const {},
        runes: 1000,
        unlockedStageCount: 8,
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

  test('physical damage gem boosts physical turrets only', () {
    final game = _LinkResearchUnlockedGame();
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
    final game = _LinkResearchUnlockedGame();
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
    final game = _LinkResearchUnlockedGame(
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
    final game = _LinkResearchUnlockedGame(
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
    final game = _LinkResearchUnlockedGame(saveRepository: repository);
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
    expect(repository.data!.turrets.single.equippedGemSlots, [
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
        countType(gameChapter2Stage10Waves, 50, EnemyType.shieldBoss),
        countType(gameChapter2Waves, 50, EnemyType.shieldBoss),
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
    expect(countType(gameChapter3Stage15Waves, 50, EnemyType.forgeBoss), 1);
  });

  test('late wave enemy counts stay within the planned pressure range', () {
    int totalCount(WaveDefinition wave) =>
        wave.groups.fold(0, (total, group) => total + group.count);

    final round6Count = totalCount(gameWaves[5]);
    final round49Count = totalCount(gameWaves[48]);
    final round50Count = totalCount(gameWaves[49]);

    expect(round6Count, inInclusiveRange(16, 18));
    expect(round49Count, lessThanOrEqualTo(round6Count * 2));
    expect(round50Count, lessThanOrEqualTo(round6Count * 2));
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
      final game = RuneNexusGame();

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
    game.debugSetClearedStageCount(1);
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
      ..data = _saveWithResearch(
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
    final first = _chainEnemy(game, turret.position + Vector2(20, 0), 30);
    final second = _chainEnemy(game, first.position + Vector2(20, 0), 20);
    final third = _chainEnemy(game, second.position + Vector2(20, 0), 10);
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
    final target = _chainEnemy(game, turret.position + Vector2(20, 0), 30);
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
    final game = _LinkResearchUnlockedGame();
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
    final branched = _levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent);
    final focused = _levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.focusedLightning);

    expect(base.lightningChainMaxTargets, 3);
    expect(gemmed.lightningChainMaxTargets, 5);
    expect(branched.lightningChainMaxTargets, 4);
    expect(focused.lightningChainMaxTargets, 2);
  });

  test('current amplification only improves follow-up lightning damage', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = _levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent)
      ..chooseSecondaryTrait(TurretTraitType.currentAmplification);
    final first = _chainEnemy(game, Vector2(20, 0), 10);
    final second = _chainEnemy(game, Vector2(40, 0), 20);
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
    final turret = _levelSevenLightning(game)
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
    final first = _chainEnemy(game, Vector2(20, 0), 30);
    final splash = _chainEnemy(game, first.position + Vector2(1, 0), 20);
    final chainTarget = _chainEnemy(game, first.position + Vector2(50, 0), 10);
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
    final game = _LinkResearchUnlockedGame(saveRepository: repository);

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
    expect(saved!.turrets, hasLength(1));
    expect(saved.turrets.single.level, 2);
    expect(saved.turrets.single.slotLimit, 2);
    expect(saved.turrets.single.equippedGems, [GemType.range]);
    expect(saved.turrets.single.equippedGemSlots, [GemType.range, null]);
    expect(saved.turrets.single.investedGold, 192);
    expect(saved.turrets.single.damageDealt, closeTo(123, 0.001));
    expect(saved.turrets.single.directDamageDealt, closeTo(123, 0.001));

    final restoredRepository = MemorySaveRepository()..data = saved;
    final restored = _LinkResearchUnlockedGame(
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
    expect(resumed!.turrets.single.level, 2);
    expect(resumed.turrets.single.slotLimit, 2);
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
      expect(repository.data!.turrets, hasLength(1));

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
      ..data = _saveWithResearch(
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
        ..data = _saveWithResearch(
          clearedStageNumbers: const {},
          researchLevels: const {},
          gemShards: RuneNexusGame.gemChoicePurchaseCost,
          mapSignature: const GameSaveAdapter().mapSignature(gameMap),
        );
      final game = RuneNexusGame(saveRepository: repository);

      await game.prepareSavedStateForMenu();
      game.purchaseGemChoice();
      await game.saveNow();

      final savedOptions = repository.data!.rewardOptions;
      expect(repository.data!.phase, GamePhase.reward);
      expect(savedOptions, isNotEmpty);

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      final snapshot = game.snapshotNotifier.value;
      expect(snapshot.phase, GamePhase.reward);
      expect(snapshot.isPurchasedGemReward, isTrue);
      expect(snapshot.rewardOptions, savedOptions);
      expect(repository.data!.rewardOptions, savedOptions);
    },
  );

  test(
    'empty purchased reward save is recovered with stable options',
    () async {
      final repository = MemorySaveRepository()
        ..data = _saveWithResearch(
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
      expect(repository.data!.phase, GamePhase.reward);
      expect(repository.data!.isPurchasedGemReward, isTrue);
      expect(repository.data!.rewardOptions, snapshot.rewardOptions);
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
      expect(saved!.phase, GamePhase.wave);
      expect(saved.enemies, isNotEmpty);
      expect(
        saved.enemies.first.hp,
        lessThan(scaledEnemyMaxHp(enemy.definition, 1)),
      );
      expect(saved.enemies.first.distanceTravelled, greaterThan(0));
      expect(saved.spawnQueue, isNotEmpty);

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
        restoredRepository.data!.enemies.first.distanceTravelled,
        closeTo(saved.enemies.first.distanceTravelled, 0.001),
      );
      expect(
        restoredRepository.data!.enemies.first.armor,
        closeTo(saved.enemies.first.armor, 0.001),
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
    expect(saved!.phase, GamePhase.wave);

    final restoredRepository = MemorySaveRepository()..data = saved;
    final restored = RuneNexusGame(saveRepository: restoredRepository);
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();

    expect(restored.snapshotNotifier.value.phase, GamePhase.restored);

    await restored.discardRestoredRun();

    final snapshot = restored.snapshotNotifier.value;
    expect(snapshot.phase, GamePhase.preparation);
    expect(snapshot.runes, 1);
    expect(snapshot.bestRoundsByStage[1], 1);
  });

  test('turrets can be built and leveled while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = _LinkResearchUnlockedGame(saveRepository: repository);

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();

    game.tryBuildTurret(const GridPoint(2, 0));
    game.levelUpSelectedTurret();
    await game.saveNow();

    final saved = repository.data;
    expect(game.snapshotNotifier.value.phase, GamePhase.wave);
    expect(saved, isNotNull);
    expect(saved!.phase, GamePhase.wave);
    expect(saved.turrets, hasLength(1));
    expect(saved.turrets.single.level, 2);
  });

  test('turret link can be upgraded while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = _LinkResearchUnlockedGame(saveRepository: repository);

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
    expect(repository.data!.turrets.single.slotLimit, 2);
  });

  test(
    'gem can be equipped into an empty socket while a round is running',
    () async {
      final repository = MemorySaveRepository();
      final game = _LinkResearchUnlockedGame(saveRepository: repository);

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
      expect(repository.data!.turrets.single.equippedGemSlots, [GemType.range]);
    },
  );

  test('gem can be replaced and removed while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = _LinkResearchUnlockedGame(saveRepository: repository);

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
      final game = _LinkResearchUnlockedGame(
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
    final game = _LinkResearchUnlockedGame(saveRepository: repository);

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
    expect(repository.data!.turrets, isEmpty);
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
    expect(repository.data!.turrets, isEmpty);
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

class _LinkResearchUnlockedGame extends RuneNexusGame {
  _LinkResearchUnlockedGame({super.waves, super.saveRepository});

  @override
  int get maxTurretLinkSlotLimit => 4;
}

class _FirstLinkDiscountGame extends RuneNexusGame {
  @override
  double get firstLinkUpgradeDiscountRate => 0.2;
}

const _targetPriorityTestTurret = TurretDefinition(
  type: TurretType.sniper,
  name: 'Target Priority Test',
  cost: 0,
  damage: 10,
  range: 220,
  attackRate: 10,
  projectileSpeed: 0,
  description: 'test',
  damageFamily: DamageFamily.physical,
  attackTags: {AttackTag.heavy},
  color: Color(0xFFFFFFFF),
  instantHit: true,
);

EnemyComponent _targetPriorityEnemy({
  required RuneNexusGame game,
  required double hp,
  required double progress,
  required Vector2 position,
}) {
  return EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: hp,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    )
    ..position = position
    ..distanceTravelled = progress;
}

EnemyComponent _durabilityEnemy(
  RuneNexusGame game, {
  required double hp,
  double armor = 0,
  required double progress,
}) {
  return EnemyComponent(
      definition: armor > 0
          ? gameEnemies[EnemyType.armored]!
          : gameEnemies[EnemyType.normal]!,
      maxHp: math.max(100, hp),
      maxArmor: armor,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    )
    ..hp = hp
    ..armor = armor
    ..distanceTravelled = progress;
}

EnemyComponent _chainEnemy(
  RuneNexusGame game,
  Vector2 position,
  double progress,
) {
  return EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    )
    ..position = position
    ..distanceTravelled = progress;
}

TurretComponent _levelSevenLightning(RuneNexusGame game) {
  final turret = TurretComponent(
    gridPoint: const GridPoint(0, 0),
    definition: gameTurrets[TurretType.lightning]!,
    game: game,
    center: Vector2.zero(),
    tileSize: 32,
  );
  for (var i = 0; i < 6; i++) {
    turret.upgradeLevel();
  }
  return turret;
}

void _expectValidMapPath(MapDefinition map) {
  expect(map.path, isNotEmpty);
  expect(map.tileAt(map.path.first), TileType.spawn);
  expect(map.tileAt(map.path.last), TileType.core);
  for (var i = 0; i < map.path.length; i++) {
    final point = map.path[i];
    expect(map.contains(point), isTrue);
    expect(
      map.tileAt(point),
      isIn(const [TileType.path, TileType.spawn, TileType.core]),
    );
    if (i == 0) {
      continue;
    }
    final previous = map.path[i - 1];
    final distance =
        (point.x - previous.x).abs() + (point.y - previous.y).abs();
    expect(distance, 1);
  }
}

GameSaveData _saveWithResearch({
  required Set<int> clearedStageNumbers,
  required Map<ResearchType, int> researchLevels,
  int runes = 0,
  int gold = 170,
  int unlockedStageCount = 4,
  int gemShards = 0,
  Map<RunUpgradeType, int> runUpgradeLevels = const {},
  GamePhase phase = GamePhase.preparation,
  bool isPurchasedGemReward = false,
  GamePhase? rewardReturnPhase,
  List<GemType> rewardOptions = const [],
  String? mapSignature,
}) {
  return GameSaveData(
    version: GameSaveData.currentVersion,
    savedAtMillis: 0,
    gold: gold,
    gemShards: gemShards,
    nexusHp: 20,
    stageNumber: 1,
    mapSignature: mapSignature,
    roundIndex: 0,
    completedRounds: 0,
    phase: phase,
    autoStartMode: AutoStartMode.pauseEachRound,
    progression: SavedProgression(
      runes: runes,
      lastRunRuneReward: 0,
      startingGoldUpgradeLevel: 0,
      nexusHpUpgradeLevel: 0,
      supplyUpgradeLevel: 0,
      fireTrainingUpgradeLevel: 0,
      criticalChanceUpgradeLevel: 0,
      criticalDamageUpgradeLevel: 0,
      killGoldUpgradeLevel: 0,
      emergencySaleUpgradeLevel: 0,
      unlockedStageCount: unlockedStageCount,
      bestRoundsByStage: const {},
      clearedStageNumbers: clearedStageNumbers,
      researchLevels: researchLevels,
      researchElapsedMillis: const {},
      activeResearches: const [],
    ),
    runUpgradeLevels: runUpgradeLevels,
    killGoldFractionWallet: 0,
    gemInventory: const {},
    rewardOptions: rewardOptions,
    isPurchasedGemReward: isPurchasedGemReward,
    rewardReturnPhase: rewardReturnPhase,
    turrets: const [],
    enemies: const [],
    spawnQueue: const [],
  );
}

List<WaveDefinition> _emptyWaves(int count) {
  return List<WaveDefinition>.generate(
    count,
    (index) => WaveDefinition(
      round: index + 1,
      previewText: 'empty ${index + 1}',
      groups: const [],
      clearRewardGold: 0,
    ),
  );
}

GameSaveData _saveWithCorePassiveRun({
  required int nexusHp,
  required int roundIndex,
  required int completedRounds,
  required List<CorePassiveAbility?> passiveSlots,
  int unlockedStageCount = 1,
  Set<int> clearedStageNumbers = const {},
  CoreCombatSkill? coreCombatSkill = CoreCombatSkill.guardianBeam,
  SavedCoreCombatSkillStats coreCombatSkillStats =
      SavedCoreCombatSkillStats.empty,
}) {
  return GameSaveData(
    version: GameSaveData.currentVersion,
    savedAtMillis: 0,
    gold: 170,
    gemShards: 0,
    nexusHp: nexusHp,
    stageNumber: 1,
    mapSignature: const GameSaveAdapter().mapSignature(gameMap),
    roundIndex: roundIndex,
    completedRounds: completedRounds,
    phase: GamePhase.preparation,
    autoStartMode: AutoStartMode.pauseEachRound,
    progression: SavedProgression(
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
      unlockedStageCount: unlockedStageCount,
      bestRoundsByStage: const {},
      clearedStageNumbers: clearedStageNumbers,
      researchLevels: const {},
      researchElapsedMillis: const {},
      activeResearches: const [],
      coreCombatSkill: coreCombatSkill,
      corePassiveSlots: passiveSlots,
    ),
    runUpgradeLevels: const {},
    killGoldFractionWallet: 0,
    gemInventory: const {},
    rewardOptions: const [],
    isPurchasedGemReward: false,
    runCoreCombatSkill: coreCombatSkill,
    runCorePassiveSlots: passiveSlots,
    runCoreCombatSkillStats: coreCombatSkillStats,
    turrets: const [],
    enemies: const [],
    spawnQueue: const [],
  );
}
