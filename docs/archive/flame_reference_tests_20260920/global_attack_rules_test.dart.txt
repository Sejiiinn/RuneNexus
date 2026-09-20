import 'helpers/game_balance_test_helpers.dart';

TurretComponent _tower(RuneNexusGame game, TurretType type) => TurretComponent(
  gridPoint: const GridPoint(0, 0),
  definition: gameTurrets[type]!,
  game: game,
  center: Vector2.zero(),
  tileSize: 48,
);

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
    'successive explosions can hit prior direct and splash victims again',
    () {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      final turret = _tower(game, TurretType.cannon)
        ..equipGem(GemType.explosion, 0);
      final attack = turret.createAttackSnapshot();
      final first = _enemy(game, 0);
      final second = _enemy(game, 20);
      final third = _enemy(game, 30);
      final edge = _enemy(game, 50);

      game.resolveProjectileHit(
        owner: turret,
        attack: attack,
        target: first,
        hitPosition: first.position.clone(),
        remainingChainCount: 0,
      );
      expect(first.hp, 975);
      expect(second.hp, 987.5);
      expect(third.hp, 987.5);
      expect(edge.hp, 987.5);

      game.resolveProjectileHit(
        owner: turret,
        attack: attack,
        target: second,
        hitPosition: second.position.clone(),
        isChain: true,
        directHitEnemies: {first},
        remainingChainCount: 0,
      );
      // 과거 직접 명중한 적도 새 폭발은 받되, 현재 직접 대상은 폭발 중복 제외.
      expect(first.hp, 968.75);
      expect(second.hp, 975);
      expect(third.hp, 981.25);
      expect(edge.hp, 987.5, reason: '후속 폭발 반경 밖');

      game.resolveProjectileHit(
        owner: turret,
        attack: attack,
        target: third,
        hitPosition: third.position.clone(),
        isChain: true,
        directHitEnemies: {first, second},
        remainingChainCount: 0,
      );
      expect(third.hp, 968.75, reason: '두 번째 후속도 원본 피해의 50%');
      expect(second.hp, 968.75);
      expect(edge.hp, 981.25);
      expect(first.hp, 968.75);
    },
  );

  test('critical launch damage preserves splash and chain proportions', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final turret = _tower(game, TurretType.cannon);
    final attack = turret.createAttackSnapshot(criticalMultiplier: 2);
    final first = _enemy(game, 0);
    final nearby = _enemy(game, 10);
    game.resolveProjectileHit(
      owner: turret,
      attack: attack,
      target: first,
      hitPosition: first.position.clone(),
      remainingChainCount: 0,
    );
    expect(first.hp, 950);
    expect(nearby.hp, 975);
    game.resolveProjectileHit(
      owner: turret,
      attack: attack,
      target: nearby,
      hitPosition: nearby.position.clone(),
      isChain: true,
      directHitEnemies: {first},
      remainingChainCount: 0,
    );
    expect(nearby.hp, 950);
    expect(first.hp, 937.5);
  });

  test(
    'chain explosion scales inherited fire damage without shortening burn',
    () {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      final turret = _tower(game, TurretType.magic)
        ..equipGem(GemType.explosion, 0);
      final direct = _enemy(game, 0);
      final splash = _enemy(game, 10);
      game.resolveProjectileHit(
        owner: turret,
        attack: turret.createAttackSnapshot(),
        target: direct,
        hitPosition: direct.position.clone(),
        isChain: true,
        remainingChainCount: 0,
      );
      expect(direct.hp, 992);
      expect(splash.hp, 996);
      expect(direct.totalBurnDamagePerSecond, 4);
      expect(splash.totalBurnDamagePerSecond, 2);
      direct.update(1);
      splash.update(1);
      expect(direct.hp, 988);
      expect(splash.hp, 994);
    },
  );

  test(
    'frost hits in increased effect area without enlarging attack range',
    () {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      final turret = _tower(game, TurretType.frost)
        ..equipGem(GemType.explosion, 0);
      final inside = _enemy(game, turret.range * 1.2);
      final outside = _enemy(game, turret.range * 1.5);
      game.resolveCenteredAreaAttack(
        owner: turret,
        // 범위 검증이 무작위 치명타에 영향받지 않도록 일반 공격을 고정한다.
        attack: turret.createAttackSnapshot(),
        targets: [inside, outside],
      );
      expect(inside.hp, 996);
      expect(inside.isSlowed, isTrue);
      expect(outside.hp, 1000);
      expect(turret.range, 76);
    },
  );

  testWidgets(
    'projectile follows two sequential jumps with the launch snapshot',
    (tester) async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump();
      final turret = _tower(game, TurretType.arrow)..equipGem(GemType.chain, 0);
      final attack = turret.createAttackSnapshot();
      final scale = game.boardDistanceScale;
      final first = _enemy(game, 40 * scale);
      final second = _enemy(game, 120 * scale);
      final third = _enemy(game, 200 * scale);
      final fourth = _enemy(game, 280 * scale);
      final projectile = ProjectileComponent(
        origin: Vector2.zero(),
        targetPosition: first.position.clone(),
        owner: turret,
        attack: attack,
        game: game,
      );
      await game.add(projectile);
      await tester.pump();
      projectile.update(60 * scale / attack.projectileSpeed);
      game.update(0);
      expect(first.hp, 993);
      expect(second.hp, 1000);
      var next = game.children
          .whereType<ProjectileComponent>()
          .where((p) => p.isChain && !p.isRemoving)
          .single;
      expect(next.remainingChainCount, 1);
      // 비행 중 젬 교체가 이미 발사된 연쇄에 영향을 주지 않음.
      turret.removeGemAt(0);
      turret.equipGem(GemType.damageAmplifier, 0);
      next.update(100 * scale / attack.projectileSpeed);
      game.update(0);
      expect(second.hp, 996.5);
      next = game.children
          .whereType<ProjectileComponent>()
          .where((p) => p.isChain && !p.isRemoving)
          .single;
      expect(next.remainingChainCount, 0);
      next.update(100 * scale / attack.projectileSpeed);
      game.update(0);
      expect(third.hp, 996.5);
      expect(fourth.hp, 1000);
      expect(
        game.children.whereType<ProjectileComponent>().where(
          (p) => !p.isRemoving,
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'lightning can chain into a splash victim and splash its previous target',
    (tester) async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump();
      final turret = _tower(game, TurretType.lightning)
        ..equipGem(GemType.explosion, 0);
      final scale = game.boardDistanceScale;
      final first = _enemy(game, 20 * scale);
      final second = _enemy(game, 30 * scale);
      final third = _enemy(game, 40 * scale);
      game.resolveLightningChainAttack(owner: turret, target: first);
      game.update(0);
      final sequence = game.children
          .whereType<SequentialLightningChainComponent>()
          .single;
      expect(first.hp, 976);
      expect(second.hp, 988);
      expect(third.hp, 988);
      sequence.update(0.07);
      expect(first.hp, 970);
      expect(second.hp, 976);
      expect(third.hp, 982);
      sequence.update(0.07);
      expect(first.hp, 964);
      expect(second.hp, 970);
      expect(third.hp, 970);
    },
  );
}
