import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';

import 'helpers/game_balance_test_helpers.dart';

const _projection = BattlefieldProjection(
  origin: Offset(32, 130),
  xAxis: Offset(38, 8),
  yAxis: Offset(-3, 31),
  heightAxis: Offset(0, -19),
);

class _ProjectileVisualGame extends RuneNexusGame {
  _ProjectileVisualGame({required super.saveRepository});

  bool firing = false;
  Vector2? hitPosition;
  int hitCount = 0;

  @override
  bool get isWaveRunning => firing;

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
    this.hitPosition = hitPosition.clone();
    hitCount++;
    super.resolveProjectileHit(
      owner: owner,
      attack: attack,
      target: target,
      hitPosition: hitPosition,
      remainingChainCount: remainingChainCount,
      directHitEnemies: directHitEnemies,
      isChain: isChain,
    );
  }
}

Future<
  ({
    _ProjectileVisualGame game,
    TurretComponent turret,
    MemorySaveRepository repository,
  })
>
_fixture({TurretType type = TurretType.arrow}) async {
  final repository = MemorySaveRepository();
  final game = _ProjectileVisualGame(saveRepository: repository);
  game.onGameResize(Vector2(400, 800));
  // GameWidget의 로드·마운트 순서를 자동 렌더 루프 없이 재현.
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  addTearDown(game.disposeAppResources);
  game.battlefieldProjection = _projection;
  game.selectTurretType(type);
  game.tryBuildTurret(const GridPoint(2, 0));
  await game.ready();
  return (
    game: game,
    turret: game.children.whereType<TurretComponent>().single,
    repository: repository,
  );
}

ProjectileComponent _shortProjectile(
  RuneNexusGame game,
  TurretComponent turret, {
  bool isChain = false,
}) => ProjectileComponent(
  origin: turret.position.clone(),
  targetPosition: turret.position + Vector2(100, 0),
  owner: turret,
  attack: turret.createAttackSnapshot(),
  game: game,
  maxDistance: 5,
  isChain: isChain,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('첫 갱신에 충돌·제거된 탄환도 판정점과 별도 적 중심을 보존한다', () async {
    final fixture = await _fixture();
    final game = fixture.game;
    final turret = fixture.turret;
    final origin = turret.position.clone();
    final targetPosition = origin + Vector2(40 * game.boardDistanceScale, 0);
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 1000,
      path: [targetPosition, targetPosition + Vector2(500, 0)],
      game: game,
    );
    game.enemies.add(enemy);
    game.firing = true;
    turret.update(0);
    game.firing = false;
    await game.ready();
    final projectile = game.children.whereType<ProjectileComponent>().single;
    final shotSequence = turret.visualShotSequence;
    final hpBefore = enemy.hp;
    game.setSpeedMultiplier(4);
    game.update(1 / 60);

    expect(shotSequence, greaterThan(0));
    expect(projectile.isRemoving, isTrue);
    expect(game.hitCount, 1);
    expect(game.hitPosition!.x, lessThan(enemy.position.x));
    expect(
      enemy.hp,
      closeTo(
        hpBefore -
            projectile.attack.damage * projectile.attack.criticalMultiplier,
        0.00001,
      ),
    );
    // 이동 중 프레임을 읽지 않아도 종료 사본에 발사 정보가 남아야 함.
    final frame = game.battlefieldFrame!;
    final finished = frame.finishedProjectiles.single;
    final tileSize = frame.pixelsPerTile;
    final boardOrigin = game.debugBoardOrigin();
    expect(frame.projectiles, isEmpty);
    expect(finished.ownerId, frame.turrets.single.id);
    expect(finished.shotSequence, shotSequence);
    expect(finished.origin, frame.turrets.single.position);
    expect(finished.finishedAt, frame.time);
    expect(finished.isChain, isFalse);
    expect(
      finished.position.dx,
      closeTo((game.hitPosition!.x - boardOrigin.x) / tileSize, 0.00001),
    );
    expect(
      finished.hitTarget!.dx,
      closeTo((enemy.position.x - boardOrigin.x) / tileSize, 0.00001),
    );
    expect(finished.position.dx, lessThan(finished.hitTarget!.dx));
    expect(projectile.position.x, game.hitPosition!.x);
    expect(projectile.visualOrigin, Offset(origin.x, origin.y));
    final hitTarget = finished.hitTarget;
    enemy.position.x += 50;
    projectile.position.x += 50;
    expect(finished.hitTarget, hitTarget);
    expect(projectile.visualOrigin, Offset(origin.x, origin.y));
    game.processLifecycleEvents();
    expect(projectile.parent, isNull);
    expect(game.battlefieldFrame!.finishedProjectiles.single, same(finished));
    enemy.position = targetPosition.clone();
    game.firing = true;
    turret.update(10);
    game.firing = false;
    expect(turret.visualShotSequence, greaterThan(shotSequence));
    expect(projectile.visualShotSequence, shotSequence);
    expect(finished.shotSequence, shotSequence);
    expect(
      encodeGodotBattlefieldFrame(frame, sequence: 1)['projectiles'],
      hasLength(1),
    );
  });

  for (final speed in [1.0, 4.0]) {
    test('최대거리 종료 탄환은 $speed배속에서도 표시 시간 0.14초 뒤 만료된다', () async {
      final fixture = await _fixture(type: TurretType.cannon);
      final game = fixture.game;
      game.setSpeedMultiplier(speed);
      final projectile = _shortProjectile(game, fixture.turret, isChain: true);
      await game.add(projectile);
      await game.ready();
      final before = game.battlefieldFrame!.projectiles.single;
      projectile.update(1);
      final finished = game.battlefieldFrame!.finishedProjectiles.single;
      expect(projectile.isRemoving, isTrue);
      expect(finished.id, before.id);
      expect(finished.ownerId, before.ownerId);
      expect(finished.origin, before.origin);
      expect(finished.isChain, isTrue);
      expect(finished.hitTarget, isNull);
      expect(game.hitCount, 0);
      expect(
        projectile.position.x - projectile.visualOrigin.dx,
        closeTo(5, 0.00001),
      );
      game.update(0.139);
      expect(game.battlefieldFrame!.finishedProjectiles, hasLength(1));
      game.update(0.002);
      expect(game.battlefieldFrame!.finishedProjectiles, isEmpty);
      expect(game.hitCount, 0);
    });
  }

  test('표시 시계의 1200초 순환을 지나도 종료 탄환 수명을 유지한다', () async {
    final fixture = await _fixture();
    final game = fixture.game;
    game.update(1199.95);
    _shortProjectile(game, fixture.turret).update(1);
    expect(
      game.battlefieldFrame!.finishedProjectiles.single.finishedAt,
      1199.95,
    );
    game.update(0.1);
    expect(game.battlefieldFrame!.time, closeTo(0.05, 0.00001));
    expect(game.battlefieldFrame!.finishedProjectiles, hasLength(1));
    game.update(0.041);
    expect(game.battlefieldFrame!.finishedProjectiles, isEmpty);
  });

  test('종료 탄환은 최근 192개로 제한하고 전투 초기화에서 비운다', () async {
    final fixture = await _fixture();
    final game = fixture.game;
    _shortProjectile(game, fixture.turret).update(1);
    final firstId = game.battlefieldFrame!.finishedProjectiles.single.id;
    for (var index = 0; index < 192; index++) {
      _shortProjectile(game, fixture.turret).update(1);
    }
    final frame = game.battlefieldFrame!;
    expect(frame.finishedProjectiles, hasLength(192));
    expect(
      frame.finishedProjectiles.map((projectile) => projectile.id),
      isNot(contains(firstId)),
    );
    game.debugSetRound(1);
    expect(game.battlefieldFrame!.finishedProjectiles, isEmpty);
    expect(frame.finishedProjectiles, hasLength(192));
  });

  test('2D 표시와 기관총·대포 이외의 탄환은 종료 사본을 기록하지 않는다', () async {
    final fixture = await _fixture();
    final game = fixture.game;
    game.battlefieldProjection = null;
    _shortProjectile(game, fixture.turret).update(1);
    expect(game.battlefieldFrame!.finishedProjectiles, isEmpty);
    game.battlefieldProjection = _projection;
    expect(game.battlefieldFrame!.finishedProjectiles, isEmpty);
    final magic = TurretComponent(
      definition: gameTurrets[TurretType.magic]!,
      gridPoint: const GridPoint(3, 0),
      center: fixture.turret.position.clone(),
      tileSize: game.battlefieldFrame!.pixelsPerTile,
      game: game,
    );
    _shortProjectile(game, magic).update(1);
    expect(game.battlefieldFrame!.finishedProjectiles, isEmpty);
    _shortProjectile(game, fixture.turret).update(1);
    expect(game.battlefieldFrame!.finishedProjectiles, hasLength(1));
  });

  test('표시용 종료 사본과 프레임 읽기는 저장 내용에 들어가지 않는다', () async {
    final fixture = await _fixture();
    final game = fixture.game;
    await game.saveAccountCheckpoint();
    final before = fixture.repository.data!.toJson()..remove('savedAtMillis');
    _shortProjectile(game, fixture.turret).update(1);
    for (var index = 0; index < 3; index++) {
      final frame = game.battlefieldFrame!;
      expect(frame.projectiles, isEmpty);
      expect(frame.finishedProjectiles, hasLength(1));
      encodeGodotBattlefieldFrame(frame, sequence: index);
    }
    await game.saveAccountCheckpoint();
    final after = fixture.repository.data!.toJson()..remove('savedAtMillis');
    expect(after, before);
  });
}
