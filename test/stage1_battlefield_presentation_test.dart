import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'helpers/game_balance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '3D frame reads combat state without changing progress or saving',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(saveRepository: repository);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      addTearDown(game.disposeAppResources);
      game.tryBuildTurret(const GridPoint(2, 0));
      await game.saveNow();
      final saved = repository.data!.toJson();
      final first = game.battlefieldFrame!;
      final turret = first.turrets.single;
      expect(turret.position.dx, closeTo(2.5, 0.00001));
      expect(turret.position.dy, closeTo(0.5, 0.00001));
      for (var i = 0; i < 30; i++) {
        expect(game.battlefieldFrame!.turrets.single.id, turret.id);
      }
      expect(repository.data!.toJson(), saved);
      expect(game.battlefieldFrame!.turrets, hasLength(1));
    },
  );

  test(
    '3D tile taps use the inverse projection and preserve 2D fallback',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      addTearDown(game.disposeAppResources);
      const projection = BattlefieldProjection(
        origin: Offset(32, 130),
        xAxis: Offset(38, 8),
        yAxis: Offset(-3, 31),
        heightAxis: Offset(0, -19),
      );
      game.battlefieldProjection = projection;
      final screen = projection.gridToScreen(const Offset(2.5, 0.5));
      final event = TapDownEvent(
        1,
        game,
        TapDownDetails(globalPosition: screen),
      )..renderingTrace.add(Vector2(screen.dx, screen.dy));
      game.onTapDown(event);
      expect(
        game.snapshotNotifier.value.selectedBuildPoint,
        const GridPoint(2, 0),
      );
      // 네이티브 3D 전장 위에 수치·선택 표시만 투명 합성.
      expect(game.backgroundColor().a, 0);
      game.battlefieldProjection = null;
      tapBuildTile(game, const GridPoint(3, 0));
      expect(
        game.snapshotNotifier.value.selectedBuildPoint,
        const GridPoint(3, 0),
      );
      expect(game.backgroundColor().a, 1);
    },
  );
}
