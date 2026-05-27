import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_enemy_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/turret_trait_type.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/components/enemy_component.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

void main() {
  test('machine gun primary trait requires level three and locks choice', () {
    final game = RuneNexusGame();
    final turret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(turret.supportsTraits, isTrue);
    expect(turret.primaryTraitChoices, [
      TurretTraitType.overheatMagazine,
      TurretTraitType.lightweightBarrel,
    ]);
    expect(turret.secondaryTraitChoices, [
      TurretTraitType.suppressiveFire,
      TurretTraitType.chainCleanup,
    ]);
    expect(turret.canChoosePrimaryTrait, isFalse);

    turret
      ..upgradeLevel()
      ..upgradeLevel();

    expect(turret.canChoosePrimaryTrait, isTrue);
    expect(
      turret.choosePrimaryTrait(TurretTraitType.lightweightBarrel),
      isTrue,
    );
    expect(turret.primaryTrait, TurretTraitType.lightweightBarrel);
    expect(turret.canChoosePrimaryTrait, isFalse);
    expect(
      turret.choosePrimaryTrait(TurretTraitType.overheatMagazine),
      isFalse,
    );
  });

  test('fire primary traits expose burn damage and duration paths', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.magic]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    expect(turret.supportsTraits, isTrue);
    expect(turret.primaryTraitChoices, [
      TurretTraitType.highHeatBurn,
      TurretTraitType.lingeringEmbers,
    ]);
    expect(turret.secondaryTraitChoices, [
      TurretTraitType.ignitionBurst,
      TurretTraitType.chainIgnition,
    ]);
    expect(turret.canChoosePrimaryTrait, isTrue);
  });

  test('frost traits expose control and magic support paths', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.frost]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    expect(turret.supportsTraits, isTrue);
    expect(turret.primaryTraitChoices, [
      TurretTraitType.coolingCycle,
      TurretTraitType.spreadingChill,
    ]);
    expect(turret.secondaryTraitChoices, [
      TurretTraitType.frostCrack,
      TurretTraitType.rapidCooling,
    ]);
    expect(turret.canChoosePrimaryTrait, isTrue);
  });

  test('cannon primary traits expose splash and direct damage paths', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.cannon]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    expect(turret.primaryTraitChoices, [
      TurretTraitType.shrapnelShell,
      TurretTraitType.compressedCharge,
    ]);
    expect(turret.secondaryTraitChoices, [
      TurretTraitType.expandedBlastCore,
      TurretTraitType.fractureImpact,
    ]);
    expect(turret.canChoosePrimaryTrait, isTrue);
  });

  test('sniper traits split burst aiming and tactical follow-up paths', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.sniper]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    expect(turret.supportsTraits, isTrue);
    expect(turret.primaryTraitChoices, [
      TurretTraitType.deadeyeFocus,
      TurretTraitType.quickScope,
    ]);
    expect(turret.secondaryTraitChoices, [
      TurretTraitType.exposedMark,
      TurretTraitType.finishingShot,
    ]);
    expect(turret.canChoosePrimaryTrait, isTrue);
  });

  test('chain lightning traits expose length and reload paths', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.lightning]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    expect(turret.supportsTraits, isTrue);
    expect(turret.primaryTraitChoices, [
      TurretTraitType.branchCurrent,
      TurretTraitType.focusedLightning,
    ]);
    expect(turret.secondaryTraitChoices, [
      TurretTraitType.lightningRecovery,
      TurretTraitType.currentAmplification,
    ]);
    expect(turret.lightningChainMaxTargets, 3);
    expect(turret.canChoosePrimaryTrait, isTrue);
  });

  test('shrapnel shell improves cannon splash coverage', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.cannon]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();
    final baseSplashRadius = turret.splashRadius;

    turret.choosePrimaryTrait(TurretTraitType.shrapnelShell);

    expect(turret.splashRadius, closeTo(baseSplashRadius * 1.3, 0.001));
    expect(turret.splashSecondaryDamageMultiplier, closeTo(0.5, 0.001));

    turret.equipGem(GemType.heavyWeapon, 0);
    expect(turret.splashRadius, closeTo(baseSplashRadius * 1.5, 0.001));
  });

  test('compressed charge trades cannon speed for direct damage', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.cannon]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();
    final baseAttackRate = turret.attackRate;
    final enemy = _enemy(game);

    turret.choosePrimaryTrait(TurretTraitType.compressedCharge);

    expect(turret.attackRate, closeTo(baseAttackRate * 0.9, 0.001));
    expect(turret.registerDirectHitTraits(enemy), closeTo(1.35, 0.001));
  });

  test('expanded blast core improves cannon splash as a secondary trait', () {
    final game = _LinkResearchUnlockedGame();
    final turret = _levelSevenCannon(game)
      ..choosePrimaryTrait(TurretTraitType.shrapnelShell);
    final baseSplashRadius = gameTurrets[TurretType.cannon]!.splashRadius;

    expect(
      turret.chooseSecondaryTrait(TurretTraitType.expandedBlastCore),
      isTrue,
    );

    expect(turret.splashRadius, closeTo(baseSplashRadius * 1.7, 0.001));
    expect(turret.splashSecondaryDamageMultiplier, closeTo(0.6, 0.001));

    turret.equipGem(GemType.heavyWeapon, 0);
    expect(turret.splashRadius, closeTo(baseSplashRadius * 1.9, 0.001));
    expect(turret.upgradeLink(), isTrue);
    turret.equipGem(GemType.explosion, 1);
    expect(turret.splashRadius, closeTo(baseSplashRadius * 2.375, 0.001));
  });

  test('fracture impact improves cannon hit damage multiplier', () {
    final game = RuneNexusGame();
    final turret = _levelSevenCannon(game)
      ..choosePrimaryTrait(TurretTraitType.shrapnelShell);
    final directEnemy = _boss(game)..position = Vector2.zero();
    final splashEnemy = _boss(game)..position = Vector2(1, 0);
    game.enemies.addAll([directEnemy, splashEnemy]);

    expect(turret.chooseSecondaryTrait(TurretTraitType.fractureImpact), isTrue);

    game.resolveProjectileHit(
      owner: turret,
      target: directEnemy,
      hitPosition: directEnemy.position.clone(),
    );

    expect(directEnemy.hp, closeTo(100 - turret.damage * 1.1, 0.001));
    expect(
      splashEnemy.hp,
      closeTo(
        100 - turret.damage * turret.splashSecondaryDamageMultiplier * 1.1,
        0.001,
      ),
    );
    expect(directEnemy.physicalResistanceReduction, 0);
    expect(splashEnemy.physicalResistanceReduction, 0);
  });

  test('lightweight barrel improves machine gun speed stats', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.arrow]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();
    final baseAttackRate = turret.attackRate;
    final baseProjectileSpeed = turret.projectileSpeed;

    turret.choosePrimaryTrait(TurretTraitType.lightweightBarrel);

    expect(turret.attackRate, closeTo(baseAttackRate * 1.1, 0.001));
    expect(turret.projectileSpeed, closeTo(baseProjectileSpeed * 1.3, 0.001));
    expect(turret.toSaveData().primaryTrait, TurretTraitType.lightweightBarrel);
  });

  test('overheat magazine stacks on the same target only', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.arrow]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();
    turret.choosePrimaryTrait(TurretTraitType.overheatMagazine);
    final enemyA = _enemy(game);
    final enemyB = _enemy(game);

    expect(turret.registerDirectHitTraits(enemyA), closeTo(1.02, 0.001));
    expect(turret.registerDirectHitTraits(enemyA), closeTo(1.04, 0.001));
    expect(turret.registerDirectHitTraits(enemyB), closeTo(1.02, 0.001));
  });

  test('high heat burn improves fire burn damage', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.magic]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    turret.choosePrimaryTrait(TurretTraitType.highHeatBurn);

    expect(turret.damageOverTimeDamageMultiplier, closeTo(1.25, 0.001));
    expect(turret.damageOverTimeDurationMultiplier, closeTo(1, 0.001));
  });

  test('high heat burn stacks additively with damage over time gem', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.magic]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel()
          ..equipGem(GemType.damageOverTime, 0);

    turret.choosePrimaryTrait(TurretTraitType.highHeatBurn);

    expect(turret.damageOverTimeDamageMultiplier, closeTo(1.55, 0.001));
    expect(turret.damageOverTimeDurationMultiplier, closeTo(1.3, 0.001));
  });

  test('lingering embers improves fire burn duration', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.magic]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    turret.choosePrimaryTrait(TurretTraitType.lingeringEmbers);

    expect(turret.damageOverTimeDamageMultiplier, closeTo(1, 0.001));
    expect(turret.damageOverTimeDurationMultiplier, closeTo(1.4, 0.001));
  });

  test('lingering embers stacks additively with damage over time gem', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.magic]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel()
          ..equipGem(GemType.damageOverTime, 0);

    turret.choosePrimaryTrait(TurretTraitType.lingeringEmbers);

    expect(turret.damageOverTimeDamageMultiplier, closeTo(1.3, 0.001));
    expect(turret.damageOverTimeDurationMultiplier, closeTo(1.7, 0.001));
  });

  test('rapid cooling improves frost slow strength as a secondary trait', () {
    final game = RuneNexusGame();
    final turret = _levelSevenFrost(game)
      ..choosePrimaryTrait(TurretTraitType.spreadingChill);

    expect(turret.chooseSecondaryTrait(TurretTraitType.rapidCooling), isTrue);

    expect(turret.slowMultiplier, closeTo(0.62, 0.001));
    expect(turret.slowDuration, closeTo(1, 0.001));
  });

  test('spreading chill trades frost damage for range', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.frost]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();
    final baseDamage = turret.damage;
    final baseRange = turret.range;

    turret.choosePrimaryTrait(TurretTraitType.spreadingChill);

    expect(turret.damage, closeTo(baseDamage * 0.9, 0.001));
    expect(turret.range, closeTo(baseRange * 1.15, 0.001));
  });

  test('frost crack reduces slowed enemy magical resistance', () {
    final game = RuneNexusGame();
    final turret = _levelSevenFrost(game)
      ..choosePrimaryTrait(TurretTraitType.coolingCycle);
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );

    expect(turret.chooseSecondaryTrait(TurretTraitType.frostCrack), isTrue);
    expect(turret.appliesFrostCrack, isTrue);

    game.resolveCenteredAreaAttack(owner: turret, targets: [enemy]);

    expect(enemy.magicalResistanceReduction, closeTo(0.15, 0.001));
  });

  test(
    'cooling cycle trades frost slow duration for attack speed as a primary trait',
    () {
      final game = RuneNexusGame();
      final turret =
          TurretComponent(
              gridPoint: const GridPoint(0, 0),
              definition: gameTurrets[TurretType.frost]!,
              game: game,
              center: Vector2.zero(),
              tileSize: 32,
            )
            ..upgradeLevel()
            ..upgradeLevel();
      final baseAttackRate = turret.attackRate;
      final baseSlowDuration = turret.slowDuration;

      expect(turret.choosePrimaryTrait(TurretTraitType.coolingCycle), isTrue);

      expect(turret.attackRate, closeTo(baseAttackRate * 1.2, 0.001));
      expect(turret.slowDuration, closeTo(baseSlowDuration * 0.85, 0.001));
    },
  );

  test('suppressive fire reduces physical resistance every five hits', () {
    final game = RuneNexusGame();
    final turret = _levelSevenMachineGun(game)
      ..choosePrimaryTrait(TurretTraitType.lightweightBarrel);
    expect(
      turret.chooseSecondaryTrait(TurretTraitType.suppressiveFire),
      isTrue,
    );
    final enemy = _enemy(game);

    for (var i = 0; i < 4; i++) {
      turret.registerDirectHitTraits(enemy);
    }

    expect(enemy.physicalResistanceReduction, 0);

    turret.registerDirectHitTraits(enemy);

    expect(enemy.physicalResistanceReduction, closeTo(0.2, 0.001));
    expect(turret.toSaveData().secondaryTrait, TurretTraitType.suppressiveFire);
  });

  test('chain cleanup grants temporary attack speed after assisted kill', () {
    final game = RuneNexusGame();
    final turret = _levelSevenMachineGun(game)
      ..choosePrimaryTrait(TurretTraitType.lightweightBarrel);
    turret.chooseSecondaryTrait(TurretTraitType.chainCleanup);
    final baseAttackRate = turret.attackRate;
    final enemy = _enemy(game);

    turret.registerDirectHitTraits(enemy);
    turret.handleEnemyKilled(enemy);

    expect(turret.attackRate, closeTo(baseAttackRate * 1.4, 0.001));

    turret.update(3.1);

    expect(turret.attackRate, closeTo(baseAttackRate, 0.001));
  });

  test('deadeye focus trades sniper aim speed for critical chance', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.sniper]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();
    final baseAimDuration = turret.aimDuration;
    final baseCriticalChance = turret.criticalChance;

    expect(turret.choosePrimaryTrait(TurretTraitType.deadeyeFocus), isTrue);

    expect(turret.aimDuration, closeTo(1 / 0.96, 0.001));
    expect(turret.aimDuration, greaterThan(baseAimDuration));
    expect(turret.criticalChance, closeTo(baseCriticalChance + 0.2, 0.001));
  });

  test('quick scope trades critical chance for sniper aim speed', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: gameTurrets[TurretType.sniper]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();
    final baseAimDuration = turret.aimDuration;
    final baseCriticalChance = turret.criticalChance;

    expect(turret.choosePrimaryTrait(TurretTraitType.quickScope), isTrue);

    expect(turret.aimDuration, closeTo(1 / 1.56, 0.001));
    expect(turret.aimDuration, lessThan(baseAimDuration));
    expect(turret.criticalChance, closeTo(baseCriticalChance - 0.05, 0.001));
  });

  test('exposed mark lets sniper direct hits apply physical vulnerability', () {
    final game = RuneNexusGame();
    final turret = _levelSevenSniper(game)
      ..choosePrimaryTrait(TurretTraitType.quickScope);
    final enemy = _enemy(game);

    expect(turret.chooseSecondaryTrait(TurretTraitType.exposedMark), isTrue);
    expect(turret.registerDirectHitTraits(enemy), closeTo(1, 0.001));

    expect(enemy.physicalResistanceReduction, closeTo(0.15, 0.001));
  });

  test('finishing shot improves sniper damage against weakened durability', () {
    final game = RuneNexusGame();
    final turret = _levelSevenSniper(game)
      ..choosePrimaryTrait(TurretTraitType.deadeyeFocus);
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.armored]!,
      maxHp: 100,
      maxArmor: 40,
      maxShield: 20,
      path: [Vector2.zero(), Vector2(1, 0)],
      game: game,
    );

    expect(turret.chooseSecondaryTrait(TurretTraitType.finishingShot), isTrue);
    expect(turret.registerDirectHitTraits(enemy), closeTo(1, 0.001));

    enemy
      ..hp = 30
      ..armor = 15
      ..shield = 10;

    expect(turret.registerDirectHitTraits(enemy), closeTo(1.45, 0.001));
  });

  test('chain lightning primary traits adjust chain length and first hit', () {
    final game = RuneNexusGame();
    final branchTurret = _levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent);
    final focusedTurret = _levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.focusedLightning);
    final enemy = _enemy(game);

    expect(branchTurret.lightningChainMaxTargets, 4);
    expect(branchTurret.registerDirectHitTraits(enemy), closeTo(1, 0.001));
    expect(focusedTurret.lightningChainMaxTargets, 2);
    expect(focusedTurret.registerDirectHitTraits(enemy), closeTo(1.3, 0.001));
  });

  test('chain lightning secondary traits amplify chain or recover reload', () {
    final game = RuneNexusGame();
    final amplified = _levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent)
      ..chooseSecondaryTrait(TurretTraitType.currentAmplification);
    final recovery = _levelSevenLightning(game)
      ..choosePrimaryTrait(TurretTraitType.branchCurrent)
      ..chooseSecondaryTrait(TurretTraitType.lightningRecovery);

    expect(amplified.lightningChainDamageMultiplier, closeTo(0.7, 0.001));
    expect(recovery.lightningChainDamageMultiplier, closeTo(0.5, 0.001));
    recovery.recordLightningChainCompletion(usedJumps: 1, maxJumps: 3);
    expect(recovery.cooldown, closeTo(0, 0.001));
  });

  test('primary and secondary traits are restored from save data', () {
    final game = RuneNexusGame();
    final turret = _levelSevenMachineGun(game)
      ..choosePrimaryTrait(TurretTraitType.overheatMagazine)
      ..chooseSecondaryTrait(TurretTraitType.chainCleanup);
    final restored = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..restoreFromSaveData(turret.toSaveData());

    expect(restored.primaryTrait, TurretTraitType.overheatMagazine);
    expect(restored.secondaryTrait, TurretTraitType.chainCleanup);
  });

  test('turret does not restore unsupported trait choices from save data', () {
    final game = RuneNexusGame();
    final source = _levelSevenMachineGun(game)
      ..choosePrimaryTrait(TurretTraitType.overheatMagazine)
      ..chooseSecondaryTrait(TurretTraitType.chainCleanup);
    final restored = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.cannon]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..restoreFromSaveData(source.toSaveData());

    expect(restored.supportsTraits, isTrue);
    expect(restored.primaryTrait, isNull);
    expect(restored.secondaryTrait, isNull);
  });
}

TurretComponent _levelSevenMachineGun(RuneNexusGame game) {
  final turret = TurretComponent(
    gridPoint: const GridPoint(0, 0),
    definition: gameTurrets[TurretType.arrow]!,
    game: game,
    center: Vector2.zero(),
    tileSize: 32,
  );
  for (var i = 0; i < 6; i++) {
    turret.upgradeLevel();
  }
  return turret;
}

TurretComponent _levelSevenCannon(RuneNexusGame game) {
  final turret = TurretComponent(
    gridPoint: const GridPoint(0, 0),
    definition: gameTurrets[TurretType.cannon]!,
    game: game,
    center: Vector2.zero(),
    tileSize: 32,
  );
  for (var i = 0; i < 6; i++) {
    turret.upgradeLevel();
  }
  return turret;
}

TurretComponent _levelSevenFrost(RuneNexusGame game) {
  final turret = TurretComponent(
    gridPoint: const GridPoint(0, 0),
    definition: gameTurrets[TurretType.frost]!,
    game: game,
    center: Vector2.zero(),
    tileSize: 32,
  );
  for (var i = 0; i < 6; i++) {
    turret.upgradeLevel();
  }
  return turret;
}

TurretComponent _levelSevenSniper(RuneNexusGame game) {
  final turret = TurretComponent(
    gridPoint: const GridPoint(0, 0),
    definition: gameTurrets[TurretType.sniper]!,
    game: game,
    center: Vector2.zero(),
    tileSize: 32,
  );
  for (var i = 0; i < 6; i++) {
    turret.upgradeLevel();
  }
  return turret;
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

EnemyComponent _enemy(RuneNexusGame game) {
  return EnemyComponent(
    definition: gameEnemies[EnemyType.normal]!,
    maxHp: 10,
    path: [Vector2.zero(), Vector2(1, 0)],
    game: game,
  );
}

EnemyComponent _boss(RuneNexusGame game) {
  return EnemyComponent(
    definition: gameEnemies[EnemyType.boss]!,
    maxHp: 100,
    path: [Vector2.zero(), Vector2(1, 0)],
    game: game,
  );
}

class _LinkResearchUnlockedGame extends RuneNexusGame {
  @override
  int get maxTurretLinkSlotLimit => 2;
}
