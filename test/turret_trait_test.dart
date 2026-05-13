import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/demo_enemy_data.dart';
import 'package:rune_nexus/data/definitions/demo_turret_data.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
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
      definition: demoTurrets[TurretType.arrow]!,
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

  test('turrets without trait choices do not expose trait selection', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: demoTurrets[TurretType.cannon]!,
            game: game,
            center: Vector2.zero(),
            tileSize: 32,
          )
          ..upgradeLevel()
          ..upgradeLevel();

    expect(turret.supportsTraits, isFalse);
    expect(turret.primaryTraitChoices, isEmpty);
    expect(turret.secondaryTraitChoices, isEmpty);
    expect(turret.canChoosePrimaryTrait, isFalse);
    expect(
      turret.choosePrimaryTrait(TurretTraitType.lightweightBarrel),
      isFalse,
    );
  });

  test('lightweight barrel improves machine gun speed stats', () {
    final game = RuneNexusGame();
    final turret =
        TurretComponent(
            gridPoint: const GridPoint(0, 0),
            definition: demoTurrets[TurretType.arrow]!,
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
            definition: demoTurrets[TurretType.arrow]!,
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

  test('suppressive fire applies physical vulnerability every five hits', () {
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

    expect(enemy.physicalDamageTakenBonus, 0);

    turret.registerDirectHitTraits(enemy);

    expect(enemy.physicalDamageTakenBonus, closeTo(0.2, 0.001));
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

  test('primary and secondary traits are restored from save data', () {
    final game = RuneNexusGame();
    final turret = _levelSevenMachineGun(game)
      ..choosePrimaryTrait(TurretTraitType.overheatMagazine)
      ..chooseSecondaryTrait(TurretTraitType.chainCleanup);
    final restored = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.arrow]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..restoreFromSaveData(turret.toSaveData());

    expect(restored.primaryTrait, TurretTraitType.overheatMagazine);
    expect(restored.secondaryTrait, TurretTraitType.chainCleanup);
  });

  test('unsupported turret does not restore traits from save data', () {
    final game = RuneNexusGame();
    final source = _levelSevenMachineGun(game)
      ..choosePrimaryTrait(TurretTraitType.overheatMagazine)
      ..chooseSecondaryTrait(TurretTraitType.chainCleanup);
    final restored = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: demoTurrets[TurretType.cannon]!,
      game: game,
      center: Vector2.zero(),
      tileSize: 32,
    )..restoreFromSaveData(source.toSaveData());

    expect(restored.supportsTraits, isFalse);
    expect(restored.primaryTrait, isNull);
    expect(restored.secondaryTrait, isNull);
  });
}

TurretComponent _levelSevenMachineGun(RuneNexusGame game) {
  final turret = TurretComponent(
    gridPoint: const GridPoint(0, 0),
    definition: demoTurrets[TurretType.arrow]!,
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
    definition: demoEnemies[EnemyType.normal]!,
    maxHp: 10,
    path: [Vector2.zero(), Vector2(1, 0)],
    game: game,
  );
}
