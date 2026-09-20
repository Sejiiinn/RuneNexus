import 'dart:math' as math;

import 'package:flame/components.dart' show Component;

import 'helpers/game_balance_test_helpers.dart';

class _ProjectileCaptureGame extends RuneNexusGame {
  _ProjectileCaptureGame() : super(saveRepository: MemorySaveRepository());

  final projectiles = <ProjectileComponent>[];

  @override
  bool get isWaveRunning => true;

  @override
  int get maxTurretLinkSlotLimit => 4;

  @override
  Future<void> add(Component component) async {
    if (component is ProjectileComponent) projectiles.add(component);
  }
}

TurretComponent _turret(RuneNexusGame game, {int projectileCount = 1}) {
  return TurretComponent(
    definition: TurretDefinition(
      type: TurretType.arrow,
      name: '다중 투사체 검증',
      cost: 60,
      damage: 100,
      range: 200,
      attackRate: 1,
      projectileSpeed: 500,
      projectileCount: projectileCount,
      description: 'test',
      damageFamily: DamageFamily.physical,
      attackTags: const {AttackTag.light},
      color: const Color(0xFFFFFFFF),
      criticalChance: 0,
    ),
    gridPoint: const GridPoint(0, 0),
    center: Vector2.zero(),
    tileSize: 48,
    game: game,
  );
}

EnemyComponent _enemy(RuneNexusGame game, double x, [double y = 0]) {
  final enemy = EnemyComponent(
    definition: gameEnemies[EnemyType.normal]!,
    maxHp: 1000,
    path: [Vector2(x, y), Vector2(x + 500, y)],
    game: game,
  );
  game.enemies.add(enemy);
  return enemy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'equipping multiple projectiles raises total turret DPS by half',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      game.selectTurretType(TurretType.arrow);
      game.tryBuildTurret(const GridPoint(2, 0));
      final original = game.snapshotNotifier.value;
      expect(original.placedTurretCount, 1);
      expect(original.totalTurretDps, greaterThan(0));

      game.grantGem(GemType.multipleProjectiles);
      game.equipSelectedTurret(GemType.multipleProjectiles);

      final equipped = game.snapshotNotifier.value;
      expect(equipped.selectedTurretProjectileCount, 3);
      expect(
        equipped.selectedTurretDamage,
        original.selectedTurretDamage * 0.5,
      );
      expect(
        equipped.totalTurretDps,
        closeTo(original.totalTurretDps * 1.5, 0.000001),
      );
    },
  );

  test('one shot launches three equally damaged projectiles in a fan', () {
    final game = _ProjectileCaptureGame();
    final turret = _turret(game)..equipGem(GemType.multipleProjectiles, 0);
    _enemy(game, 100);

    turret.update(0);

    expect(game.projectiles, hasLength(3));
    expect(turret.damage, 50);
    final snapshot = game.projectiles.first.attack;
    final angles = <double>[];
    for (final projectile in game.projectiles) {
      expect(projectile.attack, same(snapshot));
      expect(projectile.attack.damage, 50);
      projectile.update(10 / snapshot.projectileSpeed);
      angles.add(math.atan2(projectile.position.y, projectile.position.x));
    }
    angles.sort();
    expect(angles[0], closeTo(-math.pi / 18, 0.000001));
    expect(angles[1], closeTo(0, 0.000001));
    expect(angles[2], closeTo(math.pi / 18, 0.000001));
  });

  test('all three projectiles can hit the same large enemy', () {
    final game = _ProjectileCaptureGame();
    final turret = _turret(game)..equipGem(GemType.multipleProjectiles, 0);
    final target = _enemy(game, 100)..size = Vector2.all(100);

    turret.update(0);
    for (final projectile in game.projectiles) {
      projectile.update(150 / projectile.attack.projectileSpeed);
      expect(projectile.directHitEnemies, {target});
    }

    expect(target.hp, 850);
    expect(
      identical(
        game.projectiles[0].directHitEnemies,
        game.projectiles[1].directHitEnemies,
      ),
      isFalse,
    );
  });

  test('base three-projectile turret adds only two and halves every hit', () {
    final game = _ProjectileCaptureGame();
    final turret = _turret(game, projectileCount: 3);
    final target = _enemy(game, 70)..size = Vector2.all(100);
    expect(turret.projectileCount, 3);

    turret.equipGem(GemType.multipleProjectiles, 0);
    turret.update(0);
    expect(turret.projectileCount, 5);
    expect(game.projectiles, hasLength(5));
    for (final projectile in game.projectiles) {
      expect(projectile.attack.damage, 50);
      projectile.update(150 / projectile.attack.projectileSpeed);
    }
    expect(target.hp, 750);
  });

  test(
    'damage penalty stays a fixed multiplier with gem bonuses and levels',
    () {
      final game = EfficiencyModuleGame();
      final turret = _turret(game)
        ..upgradeLink()
        ..equipGem(GemType.damageAmplifier, 0)
        ..upgradeLevel()
        ..upgradeLevel();
      final originalDamage = turret.damage;

      turret.equipGem(GemType.multipleProjectiles, 1);

      expect(turret.projectileCount, 3);
      expect(turret.damage, closeTo(originalDamage * 0.5, 0.000001));
    },
  );

  test(
    'each projectile starts an independent chain and preserves its snapshot',
    () {
      final game = _ProjectileCaptureGame();
      final turret = _turret(game)
        ..upgradeLink()
        ..equipGem(GemType.multipleProjectiles, 0)
        ..equipGem(GemType.chain, 1);
      final first = _enemy(game, 70)..size = Vector2.all(80);
      final second = _enemy(game, 140);
      final third = _enemy(game, 210);
      turret.update(0);
      final initial = game.projectiles.toList();
      expect(initial, hasLength(3));
      final snapshot = initial.first.attack;

      // 발사 후 젬 교체에도 각 탄의 원본 피해·연쇄 유지
      turret.removeGemAt(0);
      turret.removeGemAt(1);
      for (final projectile in initial) {
        projectile.update(100 / snapshot.projectileSpeed);
      }
      expect(first.hp, 850);
      final firstChains = game.projectiles.where((p) => p.isChain).toList();
      expect(firstChains, hasLength(3));
      for (final projectile in firstChains) {
        expect(projectile.attack, same(snapshot));
        expect(projectile.remainingChainCount, 1);
        projectile.update(150 / snapshot.projectileSpeed);
      }
      expect(second.hp, 925);
      final finalChains = game.projectiles
          .where((p) => p.isChain && p.remainingChainCount == 0)
          .toList();
      expect(finalChains, hasLength(3));
      for (final projectile in finalChains) {
        expect(projectile.attack, same(snapshot));
        projectile.update(150 / snapshot.projectileSpeed);
      }
      expect(third.hp, 925, reason: '두 번째 연쇄에 감폭 중복 적용 없음');
    },
  );

  test('explosion and burn inherit the halved launch damage exactly once', () {
    final game = _ProjectileCaptureGame();
    final turret =
        TurretComponent(
            definition: gameTurrets[TurretType.magic]!,
            gridPoint: const GridPoint(0, 0),
            center: Vector2.zero(),
            tileSize: 48,
            game: game,
          )
          ..upgradeLink()
          ..equipGem(GemType.multipleProjectiles, 0)
          ..equipGem(GemType.explosion, 1);
    final attack = turret.createAttackSnapshot(criticalMultiplier: 2);
    turret.removeGemAt(0);
    turret.removeGemAt(1);
    final direct = _enemy(game, 0);
    final splash = _enemy(game, 10);
    game.resolveProjectileHit(
      owner: turret,
      attack: attack,
      target: direct,
      hitPosition: direct.position.clone(),
      remainingChainCount: 0,
    );
    expect(direct.hp, 984);
    expect(splash.hp, 992);
    expect(direct.totalBurnDamagePerSecond, 4);
    expect(splash.totalBurnDamagePerSecond, 2);

    game.enemies.clear();
    final chainDirect = _enemy(game, 0);
    final chainSplash = _enemy(game, 10);
    game.resolveProjectileHit(
      owner: turret,
      attack: attack,
      target: chainDirect,
      hitPosition: chainDirect.position.clone(),
      isChain: true,
      remainingChainCount: 0,
    );
    expect(chainDirect.hp, 992);
    expect(chainSplash.hp, 996);
    expect(chainDirect.totalBurnDamagePerSecond, 2);
    expect(chainSplash.totalBurnDamagePerSecond, 1);
    chainDirect.update(1);
    chainSplash.update(1);
    expect(chainDirect.hp, 990);
    expect(chainSplash.hp, 995);
  });
}
