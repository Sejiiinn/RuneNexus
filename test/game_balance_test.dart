import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/demo_enemy_data.dart';
import 'package:rune_nexus/data/definitions/demo_stage_data.dart';
import 'package:rune_nexus/data/definitions/demo_turret_data.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/enemy/enemy_scaling.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/attack_tag.dart';
import 'package:rune_nexus/domain/turret/damage_family.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/wave/wave_definition.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

void main() {
  test('demo stage uses 50 survival rounds', () {
    expect(demoWaves, hasLength(50));
    expect(demoWaves.first.round, 1);
    expect(demoWaves.last.round, 50);
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

    game.upgradeStartingGoldProgression();
    game.upgradeNexusHpProgression();
    game.restartDemo();

    expect(game.snapshotNotifier.value.gold, 160);
    expect(game.snapshotNotifier.value.nexusHp, 21);
    expect(game.snapshotNotifier.value.maxNexusHp, 21);
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
    expect(turret.damage, closeTo(19.6, 0.001));
    expect(turret.attackRate, closeTo(3.2915, 0.001));
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

    expect(machineGun.linkUpgradeCost, 42);
    expect(cannon.linkUpgradeCost, 63);
    expect(machineGun.upgradeLink(), isTrue);
    expect(cannon.upgradeLink(), isTrue);
    expect(machineGun.slotLimit, 2);
    expect(cannon.slotLimit, 2);
    expect(machineGun.linkUpgradeCost, 96);
    expect(cannon.linkUpgradeCost, 144);
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
    'mixed waves delay later enemy groups until earlier groups are mostly out',
    () {
      final wave4 = demoWaves[3];
      final normal = wave4.groups[0];
      final fast = wave4.groups[1];

      expect(
        fast.startDelay,
        greaterThanOrEqualTo(
          normal.startDelay + normal.interval * (normal.count - 1),
        ),
      );

      final wave11 = demoWaves[10];
      final wave11Normal = wave11.groups[0];
      final wave11Fast = wave11.groups[1];
      final wave11Tank = wave11.groups[2];

      expect(
        wave11Fast.startDelay,
        greaterThanOrEqualTo(
          wave11Normal.startDelay +
              wave11Normal.interval * (wave11Normal.count - 1),
        ),
      );
      expect(
        wave11Tank.startDelay,
        greaterThanOrEqualTo(
          wave11Fast.startDelay + wave11Fast.interval * (wave11Fast.count - 1),
        ),
      );
    },
  );

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

  test('burn keeps one active damage over time instance', () {
    final game = RuneNexusGame();
    final normal = demoEnemies[EnemyType.normal]!;
    final enemy =
        EnemyComponent(
            definition: normal,
            maxHp: 100,
            path: [Vector2.zero(), Vector2(100, 0)],
            game: game,
          )
          ..applyBurn(damagePerSecond: 10, duration: 2)
          ..applyBurn(damagePerSecond: 10, duration: 2);

    enemy.update(1);

    expect(enemy.hp, closeTo(90, 0.001));
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

    expect(enemy.hp, closeTo(89.2, 0.001));
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
}
