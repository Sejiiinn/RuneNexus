import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/demo_enemy_data.dart';
import 'package:rune_nexus/data/definitions/demo_stage_data.dart';
import 'package:rune_nexus/data/definitions/demo_turret_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/enemy/enemy_scaling.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/stage/stage_definition.dart';
import 'package:rune_nexus/domain/turret/attack_tag.dart';
import 'package:rune_nexus/domain/turret/damage_family.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/wave/wave_definition.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

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

  test('projectiles are faster for straight-shot combat', () {
    expect(demoTurrets[TurretType.arrow]!.projectileSpeed, 620);
    expect(demoTurrets[TurretType.cannon]!.projectileSpeed, 340);
    expect(demoTurrets[TurretType.magic]!.projectileSpeed, 420);
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

  test('turret fire rate is represented as shots per second', () {
    expect(demoTurrets[TurretType.arrow]!.attackRate, 2.27);
    expect(demoTurrets[TurretType.cannon]!.attackRate, 0.4);
    expect(demoTurrets[TurretType.magic]!.attackRate, 0.59);
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
    expect(turret.range, closeTo(116.25, 0.001));
    expect(turret.damage, closeTo(36.118, 0.001));
    expect(turret.attackRate, closeTo(3.5215, 0.001));
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

  test('enemy kill rewards are reduced to about 60 percent', () {
    expect(demoEnemies[EnemyType.normal]!.rewardGold, 4);
    expect(demoEnemies[EnemyType.fast]!.rewardGold, 5);
    expect(demoEnemies[EnemyType.tank]!.rewardGold, 9);
    expect(demoEnemies[EnemyType.boss]!.rewardGold, 36);
  });

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
    expect(cannon.damage, closeTo(28, 0.001));
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
    expect(cannon.damage, closeTo(36.4, 0.001));
    expect(cannon.splashRadius, closeTo(50.4, 0.001));
  });

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
    expect(turret.equippedGems, [GemType.chain]);
  });

  test(
    'mixed waves delay later enemy groups until earlier groups are fully spawned',
    () {
      double lastSpawnDelay(SpawnGroup group) =>
          group.startDelay + group.interval * (group.count - 1);

      final wave4 = demoWaves[3];
      final normal = wave4.groups[0];
      final fast = wave4.groups[1];

      expect(
        fast.startDelay,
        greaterThanOrEqualTo(lastSpawnDelay(normal) + 0.75),
      );

      final wave11 = demoWaves[10];
      final wave11Normal = wave11.groups[0];
      final wave11Fast = wave11.groups[1];
      final wave11Tank = wave11.groups[2];

      expect(
        wave11Fast.startDelay,
        greaterThanOrEqualTo(lastSpawnDelay(wave11Normal) + 0.75),
      );
      expect(
        wave11Tank.startDelay,
        greaterThanOrEqualTo(lastSpawnDelay(wave11Fast) + 0.75),
      );

      final wave30 = demoWaves[29];
      final wave30Boss = wave30.groups[0];
      final wave30Tank = wave30.groups[1];
      final wave30Fast = wave30.groups[2];

      expect(
        wave30Tank.startDelay,
        greaterThanOrEqualTo(lastSpawnDelay(wave30Boss) + 1.5),
      );
      expect(
        wave30Fast.startDelay,
        greaterThanOrEqualTo(lastSpawnDelay(wave30Tank) + 0.75),
      );
    },
  );

  test('normal enemy groups use a slower spawn cadence', () {
    expect(demoWaves[0].groups.single.interval, greaterThanOrEqualTo(1.6));
    expect(demoWaves[3].groups[0].interval, greaterThanOrEqualTo(1.35));
    expect(demoWaves[10].groups[0].interval, greaterThanOrEqualTo(1.1));
    expect(demoWaves[25].groups[0].interval, greaterThanOrEqualTo(1.0));
    expect(demoWaves[4].groups[1].interval, greaterThanOrEqualTo(1.2));
  });

  test('special enemy groups keep readable spawn gaps', () {
    expect(demoWaves[3].groups[1].interval, greaterThanOrEqualTo(0.75));
    expect(demoWaves[10].groups[1].interval, greaterThanOrEqualTo(0.65));
    expect(demoWaves[25].groups[1].interval, greaterThanOrEqualTo(0.6));
    expect(demoWaves[4].groups[0].interval, greaterThanOrEqualTo(1.5));
    expect(demoWaves[10].groups[2].interval, greaterThanOrEqualTo(1.5));
    expect(demoWaves[29].groups[0].interval, greaterThanOrEqualTo(2.0));
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

  test('chain hit from fire turret applies scaled burn', () {
    final game = RuneNexusGame();
    final fireTurret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.magic]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..equipGem(GemType.chain, 0);
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
    expect(fireTurret.damageDealt, closeTo(8, 0.001));
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
    game.update(0.25);
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
}
