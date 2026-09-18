import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';

import 'helpers/game_balance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stageId in [11, 12, 13, 14, 15]) {
    test('스테이지 $stageId는 원래 대장간 맵과 건설·저장 상태를 3D로 전달한다', () async {
      final repository = MemorySaveRepository();
      final stage = gameStages[stageId - 1];
      final game = RuneNexusGame(
        stage: stage,
        stages: gameStages,
        saveRepository: repository,
      );
      game.onGameResize(Vector2(400, 800));
      // ignore: invalid_use_of_internal_member
      await game.load();
      // ignore: invalid_use_of_internal_member
      game.mount();
      addTearDown(game.disposeAppResources);
      await game.ready();
      expect(game.supportsNativeBattlefield, isTrue);
      expect(game.battlefieldFrame!.map, same(stage.map));
      expect(stage.map.columns, {11: 8, 12: 11, 13: 8, 14: 9, 15: 9}[stageId]);
      expect(stage.map.rows, {11: 10, 12: 7, 13: 8, 14: 10, 15: 9}[stageId]);
      final build = [
        for (var y = 0; y < stage.map.rows; y++)
          for (var x = 0; x < stage.map.columns; x++)
            if (stage.map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
      ].first;
      game.tryBuildTurret(build);
      await game.ready();
      final turret = game.battlefieldFrame!.turrets.single;
      expect(turret.position.dx, closeTo(build.x + .5, 1e-5));
      expect(turret.position.dy, closeTo(build.y + .5, 1e-5));
      await game.saveNow();
      final saved = repository.data!.toJson();
      final encoded = encodeGodotBattlefieldFrame(
        game.battlefieldFrame!,
        sequence: 1,
      );
      expect(encoded['map'], {
        'theme': 'chapterThreeForge',
        'columns': stage.map.columns,
        'rows': stage.map.rows,
        'tiles': [
          for (final row in stage.map.tiles)
            for (final tile in row) tile.name,
        ],
      });
      expect(repository.data!.toJson(), saved);
      game.debugSetClearedStageCount(15);
      game.startStage(1);
      expect(game.supportsNativeBattlefield, isTrue);
      expect(game.battlefieldFrame!.map, same(gameStages.first.map));
      game.startStage(stageId);
      expect(game.supportsNativeBattlefield, isTrue);
      expect(game.battlefieldFrame!.map, same(stage.map));
    });
  }
}
