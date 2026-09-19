import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';

import 'helpers/game_balance_test_helpers.dart';

const _projection = BattlefieldProjection(
  origin: Offset(32, 130),
  xAxis: Offset(38, 8),
  yAxis: Offset(-3, 31),
  heightAxis: Offset(0, -19),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final type in TurretType.values) {
    test('${type.name}: 3D에서는 잔상 할당을 생략하고 2D 복귀 시 다시 쌓는다', () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      // ignore: invalid_use_of_internal_member
      await game.load();
      // ignore: invalid_use_of_internal_member
      game.mount();
      addTearDown(game.disposeAppResources);
      final turret = TurretComponent(
        definition: gameTurrets[type]!,
        gridPoint: const GridPoint(2, 0),
        center: Vector2(100, 100),
        tileSize: game.battlefieldFrame!.pixelsPerTile,
        game: game,
      );
      final projectile = ProjectileComponent(
        origin: turret.position.clone(),
        targetPosition: Vector2(1000, 100),
        owner: turret,
        attack: turret.createAttackSnapshot(),
        game: game,
        maxDistance: 100000,
      );
      for (var i = 0; i < 12; i++) {
        projectile.update(0.001);
      }
      expect(projectile.debugTrailLength, 9);
      final before3d = projectile.position.x;
      game.battlefieldProjection = _projection;
      for (var i = 0; i < 12; i++) {
        projectile.update(0.001);
        expect(projectile.debugTrailLength, 0);
      }
      expect(
        projectile.position.x - before3d,
        closeTo(projectile.attack.projectileSpeed * 0.012, 0.0001),
      );
      game.battlefieldProjection = null;
      projectile.update(0.001);
      expect(projectile.debugTrailLength, 1);
    });
  }
}
