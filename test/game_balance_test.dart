import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/demo_enemy_data.dart';
import 'package:rune_nexus/data/definitions/demo_stage_data.dart';
import 'package:rune_nexus/data/definitions/demo_turret_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/combat/run_panel_tab.dart';
import 'package:rune_nexus/domain/enemy/enemy_scaling.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/run_upgrade/run_upgrade_type.dart';
import 'package:rune_nexus/domain/stage/stage_definition.dart';
import 'package:rune_nexus/domain/turret/attack_tag.dart';
import 'package:rune_nexus/domain/turret/damage_family.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/wave/wave_definition.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test('demo stage uses 50 survival rounds', () {
    expect(demoStages, hasLength(5));
    expect(demoStages.first.id, 1);
    expect(demoStages.last.id, 5);
    expect(demoWaves, hasLength(50));
    expect(demoWaves.first.round, 1);
    expect(demoWaves.last.round, 50);
  });

  test('stage definitions select their own wave data', () {
    final stage1 = StageDefinition(
      id: 1,
      name: 'Stage 1',
      map: demoMap,
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
      map: demoMap,
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

    expect(game.snapshotNotifier.value.gold, 150);
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
    expect(game.snapshotNotifier.value.lastRunRuneReward, 42);
    expect(game.snapshotNotifier.value.runes, 42);
    expect(game.snapshotNotifier.value.unlockedStageCount, 2);
    expect(game.snapshotNotifier.value.bestRoundsByStage[1], 1);
    expect(game.snapshotNotifier.value.clearedStageNumbers, contains(1));
    expect(game.snapshotNotifier.value.lastRunPreviousBestRound, 0);
    expect(game.snapshotNotifier.value.lastRunWasNewBestRound, isTrue);
    expect(game.snapshotNotifier.value.lastRunUnlockedStageNumber, 2);

    game.upgradeStartingGoldProgression();
    game.upgradeNexusHpProgression();
    game.restartDemo();

    expect(game.snapshotNotifier.value.gold, 155);
    expect(game.snapshotNotifier.value.nexusHp, 21);
    expect(game.snapshotNotifier.value.maxNexusHp, 21);
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
    expect(progression.initialGold, 250);
    expect(progression.maxNexusHp, 30);
    expect(progression.runes, 8705);

    progression.startingGoldUpgradeLevel = 99;
    progression.nexusHpUpgradeLevel = 99;

    expect(progression.initialGold, 250);
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

    expect(game.snapshotNotifier.value.phase, GamePhase.wave);

    game.update(0.016);
    expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.round, 2);

    game.update(0.016);
    expect(game.snapshotNotifier.value.phase, GamePhase.wave);
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

  test('enemy hp scaling grows by round', () {
    final normal = demoEnemies[EnemyType.normal]!;
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
    final normal = demoEnemies[EnemyType.normal]!;

    expect(enemyHpMultiplierForStage(1), closeTo(1, 0.001));
    expect(enemyHpMultiplierForStage(2), closeTo(1.3, 0.001));
    expect(enemyHpMultiplierForStage(5), closeTo(2.8561, 0.001));
    expect(scaledEnemyMaxHp(normal, 1, stageNumber: 2), closeTo(45.5, 0.001));
  });

  test('projectiles are faster for straight-shot combat', () {
    expect(demoTurrets[TurretType.arrow]!.projectileSpeed, 620);
    expect(demoTurrets[TurretType.cannon]!.projectileSpeed, 340);
    expect(demoTurrets[TurretType.magic]!.projectileSpeed, 420);
    expect(demoTurrets[TurretType.frost]!.projectileSpeed, 0);
  });

  test('enemy movement speeds are tuned down for readable combat', () {
    expect(demoEnemies[EnemyType.normal]!.speed, 31.5);
    expect(demoEnemies[EnemyType.fast]!.speed, 54.6);
    expect(demoEnemies[EnemyType.tank]!.speed, 21);
    expect(demoEnemies[EnemyType.boss]!.speed, 16.8);
  });

  test('turret base ranges are reduced to tighten placement choices', () {
    expect(demoTurrets[TurretType.arrow]!.range, 96);
    expect(demoTurrets[TurretType.cannon]!.range, 84);
    expect(demoTurrets[TurretType.magic]!.range, 108);
    expect(demoTurrets[TurretType.frost]!.range, 76);
  });

  test('runtime combat distances scale with board tile size', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.tryBuildTurret(const GridPoint(2, 0));
    final turret = game.children.whereType<TurretComponent>().single;
    final expectedScale = 40.7 / 48;

    expect(game.boardDistanceScale, closeTo(expectedScale, 0.001));
    expect(turret.range, closeTo(96 * expectedScale, 0.001));
  });

  test('enemy movement speed scales with board tile size', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final normal = demoEnemies[EnemyType.normal]!;

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

  test('board pan room scales with wide map size', () async {
    final game = RuneNexusGame(
      stage: demoStages[1],
      saveRepository: MemorySaveRepository(),
    );

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    final tileSize = game.boardDistanceScale * 48;
    final panLimit = game.debugBoardPanLimit();

    expect(panLimit.x, closeTo(80, 0.001));
    expect(panLimit.x, greaterThan(tileSize * 2));
  });

  test('turret fire rate is represented as shots per second', () {
    expect(demoTurrets[TurretType.arrow]!.attackRate, 2.27);
    expect(demoTurrets[TurretType.cannon]!.attackRate, 0.4);
    expect(demoTurrets[TurretType.magic]!.attackRate, 0.59);
    expect(demoTurrets[TurretType.frost]!.attackRate, 0.4);
  });

  test('turret level cap grows to 10 without excessive range gain', () {
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.arrow]!,
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
      definition: demoTurrets[TurretType.arrow]!,
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
      definition: demoTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final enemy = EnemyComponent(
      definition: demoEnemies[EnemyType.normal]!,
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
      definition: demoTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: demoTurrets[TurretType.cannon]!,
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

  test('turret link upgrades scale with price and gate the third link', () {
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: demoTurrets[TurretType.cannon]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(machineGun.linkUpgradeCost, 90);
    expect(cannon.linkUpgradeCost, 135);
    expect(machineGun.upgradeLink(), isTrue);
    expect(cannon.upgradeLink(), isTrue);
    expect(machineGun.slotLimit, 2);
    expect(cannon.slotLimit, 2);
    expect(machineGun.linkUpgradeCost, 180);
    expect(cannon.linkUpgradeCost, 270);
    expect(machineGun.canUpgradeLink, isFalse);
    expect(machineGun.linkUpgradeRequiredLevel, 5);

    while (machineGun.level < 5) {
      expect(machineGun.upgradeLevel(), isTrue);
    }

    expect(machineGun.canUpgradeLink, isTrue);
    expect(machineGun.upgradeLink(), isTrue);
    expect(machineGun.slotLimit, 3);
    expect(machineGun.hasNextLinkUpgrade, isFalse);
  });

  test('debug round control jumps to requested preparation round', () {
    final game = RuneNexusGame();

    game.debugSetRound(25);

    expect(game.snapshotNotifier.value.round, 25);
    expect(game.snapshotNotifier.value.previewText, demoWaves[24].previewText);

    game.debugSetRound(999);

    expect(game.snapshotNotifier.value.round, 50);
  });

  test('debug gold control adds gold without accepting negative values', () {
    final game = RuneNexusGame();

    game.debugAddGold(500);
    expect(game.snapshotNotifier.value.gold, 650);

    game.debugAddGold(-100);
    expect(game.snapshotNotifier.value.gold, 650);
  });

  test('restart demo resets debug-modified stage state', () {
    final game = RuneNexusGame();

    game.debugSetRound(25);
    game.debugAddGold(500);
    game.grantGem(GemType.range);

    game.restartDemo();

    expect(game.snapshotNotifier.value.round, 1);
    expect(game.snapshotNotifier.value.gold, 150);
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
    expect(game.snapshotNotifier.value.gold, 150);
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

  test('status gems are removed from the reward pool', () {
    final gemNames = GemType.values.map((type) => type.name);

    expect(gemNames, isNot(contains('poison')));
    expect(gemNames, isNot(contains('slow')));
    expect(GemType.values, contains(GemType.physicalDamage));
    expect(GemType.values, contains(GemType.magicalDamage));
    expect(GemType.values, contains(GemType.lightWeapon));
    expect(GemType.values, contains(GemType.heavyWeapon));
    expect(GemType.values, contains(GemType.damageOverTime));
  });

  test('enemy kill rewards limit late-wave gold snowballing', () {
    expect(demoEnemies[EnemyType.normal]!.rewardGold, 5);
    expect(demoEnemies[EnemyType.fast]!.rewardGold, 5);
    expect(demoEnemies[EnemyType.tank]!.rewardGold, 9);
    expect(demoEnemies[EnemyType.boss]!.rewardGold, 35);
  });

  test('run tower damage upgrade boosts all turret damage', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    game.buyRunUpgrade(RunUpgradeType.towerDamage);

    expect(turret.damage, closeTo(7.21, 0.001));
    expect(game.snapshotNotifier.value.gold, 118);
    expect(
      game.snapshotNotifier.value.runUpgradeLevels[RunUpgradeType.towerDamage],
      1,
    );
  });

  test('run kill gold upgrade accumulates fractional rewards', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.buyRunUpgrade(RunUpgradeType.killGold);

    for (var i = 0; i < 17; i++) {
      final enemy = EnemyComponent(
        definition: demoEnemies[EnemyType.normal]!,
        maxHp: 1,
        path: [Vector2.zero(), Vector2(1, 0)],
        game: game,
      );
      game.enemies.add(enemy);
      enemy.receiveDamage(999);
    }

    expect(game.snapshotNotifier.value.gold, 216);
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
    expect(game.snapshotNotifier.value.gold, 144);
  });

  test('permanent supply upgrade adds one gold per cleared wave', () {
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

    game.startNextWave();
    game.update(0.016);
    game.upgradeSupplyProgression();
    game.restartDemo();
    game.startNextWave();
    game.update(0.016);

    expect(game.snapshotNotifier.value.phase, GamePhase.success);
    expect(game.snapshotNotifier.value.gold, 151);
    expect(game.snapshotNotifier.value.waveClearGoldProgressionBonus, 1);
  });

  test('permanent fire training boosts turret damage', () {
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
      definition: demoTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    game.startNextWave();
    game.update(0.016);
    game.upgradeFireTrainingProgression();

    expect(turret.damage, closeTo(7.07, 0.001));
    expect(game.snapshotNotifier.value.fireTrainingUpgradeLevel, 1);
    expect(
      game.snapshotNotifier.value.fireTrainingDamageBonusRate,
      closeTo(0.01, 0.001),
    );
  });

  test('fire training uses cheaper 20 level progression', () {
    final progression = RunProgression()..runes = 10000;

    expect(RunProgression.maxFireTrainingUpgradeLevel, 20);
    expect(progression.fireTrainingUpgradeCost, 7);

    for (var i = 0; i < 20; i++) {
      expect(progression.upgradeFireTraining(), isTrue);
    }

    expect(progression.fireTrainingUpgradeLevel, 20);
    expect(progression.fireTrainingDamageBonusRate, closeTo(0.20, 0.001));
    expect(progression.fireTrainingUpgradeCost, 87);
    expect(progression.canUpgradeFireTraining, isFalse);
    expect(progression.upgradeFireTraining(), isFalse);
  });

  test('new permanent upgrades are saved and restored', () async {
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
    game.update(0.016);
    game.upgradeSupplyProgression();
    game.upgradeFireTrainingProgression();
    await game.saveNow();

    final restoredRepository = MemorySaveRepository()..data = repository.data;
    final restored = RuneNexusGame(saveRepository: restoredRepository);
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();

    final snapshot = restored.snapshotNotifier.value;
    expect(snapshot.supplyUpgradeLevel, 1);
    expect(snapshot.waveClearGoldProgressionBonus, 1);
    expect(snapshot.fireTrainingUpgradeLevel, 1);
    expect(snapshot.fireTrainingDamageBonusRate, closeTo(0.01, 0.001));
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
        definition: demoEnemies[EnemyType.normal]!,
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
      expect(snapshot.killGoldFractionWallet, closeTo(0.06, 0.001));
      expect(snapshot.towerDamageRunBonusRate, closeTo(0.03, 0.001));
    },
  );

  test('physical damage gem boosts physical turrets only', () {
    final game = RuneNexusGame();
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final fireTurret = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: demoTurrets[TurretType.magic]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    machineGun.equipGem(GemType.physicalDamage, 0);
    fireTurret.equipGem(GemType.physicalDamage, 0);

    expect(machineGun.damage, closeTo(9.8, 0.001));
    expect(fireTurret.damage, closeTo(16, 0.001));
  });

  test('magical damage gem boosts magical turrets only', () {
    final game = RuneNexusGame();
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );
    final fireTurret = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: demoTurrets[TurretType.magic]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    machineGun.equipGem(GemType.magicalDamage, 0);
    fireTurret.equipGem(GemType.magicalDamage, 0);

    expect(machineGun.damage, closeTo(7, 0.001));
    expect(fireTurret.damage, closeTo(22.4, 0.001));
  });

  test('light weapon gem boosts light turret damage and fire rate', () {
    final machineGun = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: demoTurrets[TurretType.cannon]!,
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
      definition: demoTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final cannon = TurretComponent(
      gridPoint: const GridPoint(1, 0),
      definition: demoTurrets[TurretType.cannon]!,
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
        definition: demoTurrets[TurretType.arrow]!,
        game: RuneNexusGame(),
        center: Vector2.zero(),
        tileSize: 32,
      );
      final cannon = TurretComponent(
        gridPoint: const GridPoint(1, 0),
        definition: demoTurrets[TurretType.cannon]!,
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
      definition: demoTurrets[TurretType.magic]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );

    fireTurret.equipGem(GemType.damageOverTime, 0);

    expect(fireTurret.damage, closeTo(16, 0.001));
    expect(fireTurret.damageOverTimeDamageMultiplier, closeTo(1.3, 0.001));
    expect(fireTurret.damageOverTimeDurationMultiplier, closeTo(1.3, 0.001));
  });

  test('scaling gems can be equipped before matching conversion exists', () {
    expect(
      canEquipGemOnTurret(
        GemType.magicalDamage,
        demoTurrets[TurretType.cannon]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(
        GemType.magicalDamage,
        demoTurrets[TurretType.magic]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.heavyWeapon, demoTurrets[TurretType.arrow]!),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.heavyWeapon, demoTurrets[TurretType.cannon]!),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(
        GemType.damageOverTime,
        demoTurrets[TurretType.magic]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(
        GemType.damageOverTime,
        demoTurrets[TurretType.cannon]!,
      ),
      isTrue,
    );
    expect(
      canEquipGemOnTurret(GemType.chain, demoTurrets[TurretType.cannon]!),
      isFalse,
    );
    expect(
      canEquipGemOnTurret(GemType.chain, demoTurrets[TurretType.arrow]!),
      isTrue,
    );
  });

  test('turret gems can be removed and returned by slot', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: demoTurrets[TurretType.arrow]!,
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
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
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
  });

  test('removing a gem keeps other gem socket positions fixed', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);
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

    final wave7 = demoWaves[6];
    final wave7Normal = wave7.groups[0];
    final wave7FirstRush = wave7.groups[1];
    final wave7SecondRush = wave7.groups[2];

    expect(wave7FirstRush.startDelay, greaterThan(lastSpawnDelay(wave7Normal)));
    expect(
      wave7SecondRush.startDelay,
      greaterThan(lastSpawnDelay(wave7FirstRush)),
    );

    final wave8 = demoWaves[7];
    final wave8Normal = wave8.groups[0];
    final wave8Fast = wave8.groups[1];

    expect(wave8Fast.startDelay, greaterThan(wave8Normal.startDelay));
    expect(wave8Fast.startDelay, lessThan(lastSpawnDelay(wave8Normal)));

    final wave9 = demoWaves[8];
    final wave9Tank = wave9.groups[0];
    final wave9Normal = wave9.groups[1];
    final wave9Fast = wave9.groups[2];

    expect(wave9Normal.startDelay, greaterThan(lastSpawnDelay(wave9Tank)));
    expect(wave9Fast.startDelay, greaterThan(lastSpawnDelay(wave9Normal)));

    final wave30 = demoWaves[29];
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

  test('late wave enemy counts stay within the planned pressure range', () {
    int totalCount(WaveDefinition wave) =>
        wave.groups.fold(0, (total, group) => total + group.count);

    final round6Count = totalCount(demoWaves[5]);
    final round49Count = totalCount(demoWaves[48]);
    final round50Count = totalCount(demoWaves[49]);

    expect(round6Count, inInclusiveRange(16, 18));
    expect(round49Count, lessThanOrEqualTo(round6Count * 2));
    expect(round50Count, lessThanOrEqualTo(round6Count * 2));
  });

  test('normal enemy groups use a slower spawn cadence', () {
    expect(demoWaves[0].groups.single.interval, greaterThanOrEqualTo(1.6));
    expect(demoWaves[3].groups[0].interval, greaterThanOrEqualTo(1.35));
    expect(demoWaves[10].groups[0].interval, greaterThanOrEqualTo(1.1));
    expect(demoWaves[25].groups[0].interval, greaterThanOrEqualTo(1.0));
    expect(demoWaves[4].groups[1].interval, greaterThanOrEqualTo(1.2));
  });

  test('special enemy groups keep readable spawn gaps', () {
    expect(demoWaves[3].groups[1].interval, greaterThanOrEqualTo(0.8));
    expect(demoWaves[10].groups[1].interval, greaterThanOrEqualTo(0.65));
    expect(demoWaves[25].groups[1].interval, greaterThanOrEqualTo(0.6));
    expect(demoWaves[4].groups[0].interval, greaterThanOrEqualTo(1.5));
    expect(demoWaves[9].groups[2].interval, greaterThanOrEqualTo(2.0));
    expect(demoWaves[29].groups[2].interval, greaterThanOrEqualTo(2.0));
  });

  test('fire turret is tagged as damage over time', () {
    expect(
      demoTurrets[TurretType.magic]!.attackTags,
      contains(AttackTag.damageOverTime),
    );
  });

  test('machine gun is tagged as light weapon', () {
    expect(
      demoTurrets[TurretType.arrow]!.attackTags,
      contains(AttackTag.light),
    );
  });

  test('frost turret is a centered cooling area attack', () {
    final frost = demoTurrets[TurretType.frost]!;

    expect(frost.centeredAreaAttack, isTrue);
    expect(frost.damageFamily, DamageFamily.magical);
    expect(frost.attackTags, contains(AttackTag.cooling));
    expect(frost.slowMultiplier, closeTo(0.7, 0.001));
    expect(frost.slowDuration, closeTo(1, 0.001));
  });

  test('enemy resistance profile multiplies family and tag values', () {
    final tank = demoEnemies[EnemyType.tank]!;

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
        family: DamageFamily.magical,
        tags: const {AttackTag.damageOverTime},
      ),
      closeTo(1, 0.001),
    );
  });

  test('boss enemies do not resist light weapons', () {
    final boss = demoEnemies[EnemyType.boss]!;

    expect(
      boss.resistanceProfile.multiplierFor(
        family: DamageFamily.physical,
        tags: const {AttackTag.light},
      ),
      closeTo(0.9, 0.001),
    );
  });

  test('boss enemies do not additionally resist damage over time', () {
    final boss = demoEnemies[EnemyType.boss]!;

    expect(
      boss.resistanceProfile.multiplierFor(
        family: DamageFamily.magical,
        tags: const {AttackTag.damageOverTime},
      ),
      closeTo(0.9, 0.001),
    );
  });

  test('fast enemies strongly favor light weapons over heavy weapons', () {
    final fast = demoEnemies[EnemyType.fast]!;

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
        family: DamageFamily.magical,
        tags: const {AttackTag.damageOverTime},
      ),
      closeTo(1, 0.001),
    );
  });

  test('burn deals short duration damage over time', () {
    final game = RuneNexusGame();
    final normal = demoEnemies[EnemyType.normal]!;
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
    final normal = demoEnemies[EnemyType.normal]!;
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

  test('burn instances tick independently over their own durations', () {
    final game = RuneNexusGame();
    final normal = demoEnemies[EnemyType.normal]!;
    final enemy = EnemyComponent(
      definition: normal,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..applyBurn(damagePerSecond: 20, duration: 2);

    enemy.update(1);
    enemy.applyBurn(damagePerSecond: 8, duration: 2);
    enemy.update(1);

    expect(enemy.hp, closeTo(52, 0.001));

    enemy.update(1);

    expect(enemy.hp, closeTo(44, 0.001));
  });

  test('frost turret damages and slows enemies in its centered area', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.selectTurretType(TurretType.frost);
    game.tryBuildTurret(const GridPoint(2, 0));
    final frostTurret = game.children.whereType<TurretComponent>().single;
    final inRangeEnemy = EnemyComponent(
      definition: demoEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    final outOfRangeEnemy = EnemyComponent(
      definition: demoEnemies[EnemyType.normal]!,
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
        demoEnemies[EnemyType.normal]!.speed *
            game.boardDistanceScale *
            0.7 *
            0.5,
        0.001,
      ),
    );
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
      definition: demoEnemies[EnemyType.normal]!,
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

  test('burn damage is credited to its source turret', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());

    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.selectTurretType(TurretType.magic);
    game.tryBuildTurret(const GridPoint(2, 0));
    final fireTurret = game.children.whereType<TurretComponent>().single;
    final enemy =
        EnemyComponent(
          definition: demoEnemies[EnemyType.normal]!,
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
          definition: demoEnemies[EnemyType.normal]!,
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
      definition: demoEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    )..restoreFromSaveData(saved);

    restored.update(1);

    expect(restored.hp, closeTo(88, 0.001));
  });

  test('poison stacks as long low damage over time', () {
    final game = RuneNexusGame();
    final normal = demoEnemies[EnemyType.normal]!;
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
    final normal = demoEnemies[EnemyType.normal]!;
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

  test('local save restores preparation setup without resume prompt', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);

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
    expect(saved.turrets.single.damageDealt, closeTo(123, 0.001));
    expect(saved.turrets.single.directDamageDealt, closeTo(123, 0.001));

    final restoredRepository = MemorySaveRepository()..data = saved;
    final restored = RuneNexusGame(saveRepository: restoredRepository);
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

  test('local save restores active enemy hp and path progress', () async {
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
    expect(saved.enemies.first.hp, lessThan(saved.enemies.first.maxHp));
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

    restored.continueRestoredRun();
    expect(restored.snapshotNotifier.value.phase, GamePhase.wave);
  });

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
    expect(snapshot.runes, 2);
    expect(snapshot.bestRoundsByStage[1], 1);
  });

  test('turrets can be built and leveled while a round is running', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);

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

  test('turret refund returns investment and equipped gems', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(saveRepository: repository);

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
    expect(snapshot.gold, 202);
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
    expect(game.snapshotNotifier.value.gold, 135);
    expect(game.snapshotNotifier.value.selectedTurretPoint, isNull);
    expect(repository.data!.turrets, isEmpty);
  });

  test('turret refund stops later burn credit to a rebuilt turret', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    const point = GridPoint(2, 0);
    final normal = demoEnemies[EnemyType.normal]!;

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
