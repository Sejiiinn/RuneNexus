import 'helpers/game_balance_test_helpers.dart';
import 'package:rune_nexus/game/systems/combat_resolver.dart';

class _HitRecordingGame extends RuneNexusGame {
  EnemyComponent? hitEnemy;
  Vector2? hitPosition;
  int? chainsLeft;
  Set<EnemyComponent>? visited;
  bool? chainHit;

  @override
  void resolveProjectileHit({
    required TurretComponent owner,
    TurretAttackSnapshot? attack,
    required EnemyComponent target,
    required Vector2 hitPosition,
    int? remainingChainCount,
    Set<EnemyComponent>? directHitEnemies,
    bool isChain = false,
  }) {
    hitEnemy = target;
    this.hitPosition = hitPosition;
    chainsLeft = remainingChainCount;
    visited = directHitEnemies;
    chainHit = isChain;
  }
}

EnemyComponent _enemy(RuneNexusGame game, double x, [double y = 0]) {
  final enemy = EnemyComponent(
    definition: gameEnemies[EnemyType.normal]!,
    maxHp: 100,
    path: [Vector2(x, y), Vector2(x + 500, y)],
    game: game,
  );
  game.enemies.add(enemy);
  return enemy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fast projectile hits first intersected body, not list order or endpoint',
    () {
      final game = _HitRecordingGame();
      final turret = TurretComponent(
        definition: gameTurrets[TurretType.arrow]!,
        gridPoint: const GridPoint(0, 0),
        center: Vector2.zero(),
        tileSize: 48,
        game: game,
      );
      final farther = _enemy(game, 80);
      final nearer = _enemy(game, 40);
      final projectile = ProjectileComponent(
        origin: Vector2.zero(),
        targetPosition: farther.position,
        owner: turret,
        attack: turret.createAttackSnapshot(),
        game: game,
        maxDistance: 200,
        remainingChainCount: 2,
      );

      projectile.update(100 / turret.projectileSpeed);

      expect(game.hitEnemy, same(nearer));
      expect(game.hitPosition!.x, lessThan(nearer.position.x));
      expect(game.hitPosition!.x, greaterThan(0));
      expect(game.chainsLeft, 2);
      expect(game.visited, contains(nearer));
    },
  );

  test(
    'chain ignores prior direct hits and collides with an intervening enemy',
    () {
      final game = _HitRecordingGame();
      final turret = TurretComponent(
        definition: gameTurrets[TurretType.arrow]!,
        gridPoint: const GridPoint(0, 0),
        center: Vector2.zero(),
        tileSize: 48,
        game: game,
      );
      final source = _enemy(game, 0);
      final intended = _enemy(game, 90);
      final intervening = _enemy(game, 45);
      final visited = {source};
      final projectile = ProjectileComponent(
        origin: Vector2.zero(),
        targetPosition: intended.position,
        owner: turret,
        attack: turret.createAttackSnapshot(),
        game: game,
        remainingChainCount: 1,
        directHitEnemies: visited,
        isChain: true,
        maxDistance: 110,
      );
      projectile.update(100 / turret.projectileSpeed);

      expect(game.hitEnemy, same(intervening));
      expect(game.visited, containsAll([source, intervening]));
      expect(visited, {source});
      expect(game.chainsLeft, 1);
      expect(game.chainHit, isTrue);
    },
  );

  test('projectile cannot hit beyond its travel limit on a long frame', () {
    final game = _HitRecordingGame();
    final turret = TurretComponent(
      definition: gameTurrets[TurretType.arrow]!,
      gridPoint: const GridPoint(0, 0),
      center: Vector2.zero(),
      tileSize: 48,
      game: game,
    );
    _enemy(game, 100);
    final projectile = ProjectileComponent(
      origin: Vector2.zero(),
      targetPosition: Vector2(100, 0),
      owner: turret,
      attack: turret.createAttackSnapshot(),
      game: game,
      maxDistance: 20,
    );
    projectile.update(200 / turret.projectileSpeed);
    expect(game.hitEnemy, isNull);
    expect(projectile.position.x, closeTo(20, 0.001));
  });

  test('chain keeps launch direction when the intended target moves', () {
    final game = _HitRecordingGame();
    final turret = TurretComponent(
      definition: gameTurrets[TurretType.arrow]!,
      gridPoint: const GridPoint(0, 0),
      center: Vector2.zero(),
      tileSize: 48,
      game: game,
    );
    final intended = _enemy(game, 90);
    final projectile = ProjectileComponent(
      origin: Vector2.zero(),
      targetPosition: intended.position,
      owner: turret,
      attack: turret.createAttackSnapshot(),
      game: game,
      remainingChainCount: 1,
      isChain: true,
      maxDistance: 110,
    );
    intended.position.y = 100;
    projectile.update(100 / turret.projectileSpeed);
    expect(game.hitEnemy, isNull);
    expect(projectile.position.x, closeTo(100, 0.001));
    expect(projectile.position.y, 0);
  });

  test('chain selects one nearest eligible enemy within extended radius', () {
    final game = _HitRecordingGame();
    final source = _enemy(game, 0);
    final dead = _enemy(game, 20)..hp = 0;
    final outside = _enemy(game, 111);
    final eligible = _enemy(game, 105);
    const resolver = CombatResolver(
      chainJumpRange: 110,
      burnDamagePerSecondScale: 0.2,
      burnDurationSeconds: 3,
    );
    expect(
      resolver.nextChainProjectileTarget(
        enemies: [source, dead, outside, eligible],
        sourcePosition: source.position,
        excluded: {source},
        boardDistanceScale: 1,
      ),
      same(eligible),
    );
  });
}
