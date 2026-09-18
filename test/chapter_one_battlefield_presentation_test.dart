import 'dart:io';

import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';

import 'helpers/game_balance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stage in gameStages.where((stage) => stage.id <= 5)) {
    test('스테이지 ${stage.id} 실제 맵과 경로를 3D로 전달하고 투영 입력을 유지한다', () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(stage: stage, saveRepository: repository);
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      addTearDown(game.disposeAppResources);
      expect(game.supportsNativeBattlefield, isTrue);
      final frame = game.battlefieldFrame!;
      expect(frame.map, same(stage.map));
      expect(frame.map.path, stage.map.path);
      final payload = encodeGodotBattlefieldFrame(frame, sequence: 0);
      expect(payload['map'], {
        'theme': 'chapterOne',
        'columns': stage.map.columns,
        'rows': stage.map.rows,
        'tiles': [
          for (final row in stage.map.tiles)
            for (final tile in row) tile.name,
        ],
      });
      const projection = BattlefieldProjection(
        origin: Offset(32, 130),
        xAxis: Offset(38, 8),
        yAxis: Offset(-3, 31),
        heightAxis: Offset(0, -19),
      );
      game.battlefieldProjection = projection;
      for (final point in stage.map.path) {
        final center = Offset(point.x + .5, point.y + .5);
        final inverse = projection.screenToGrid(
          projection.gridToScreen(center),
        )!;
        expect(inverse.dx, closeTo(center.dx, 1e-9));
        expect(inverse.dy, closeTo(center.dy, 1e-9));
      }
      final buildPoint = [
        for (var y = 0; y < stage.map.rows; y++)
          for (var x = 0; x < stage.map.columns; x++)
            if (stage.map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
      ].first;
      final screen = projection.gridToScreen(
        Offset(buildPoint.x + .5, buildPoint.y + .5),
      );
      final event = TapDownEvent(
        1,
        game,
        TapDownDetails(globalPosition: screen),
      )..renderingTrace.add(Vector2(screen.dx, screen.dy));
      game.onTapDown(event);
      expect(game.snapshotNotifier.value.selectedBuildPoint, buildPoint);
      expect(game.backgroundColor().a, 0);
      await game.saveNow();
      final saved = repository.data!.toJson();
      for (var i = 0; i < 3; i++) {
        expect(game.battlefieldFrame!.map, same(stage.map));
      }
      expect(repository.data!.toJson(), saved);
    });
  }

  test('같은 게임의 2→5→6 전환은 이전 투영을 즉시 무효화하고 새 3D 전장을 기다린다', () async {
    final game = RuneNexusGame(
      stage: gameStages[1],
      stages: gameStages,
      saveRepository: MemorySaveRepository(),
    );
    game.onGameResize(Vector2(400, 800));
    // ignore: invalid_use_of_internal_member
    await game.load();
    // ignore: invalid_use_of_internal_member
    game.mount();
    addTearDown(game.disposeAppResources);
    await game.ready();
    game.debugSetClearedStageCount(5);
    expect(game.snapshotNotifier.value.currentStageNumber, 2);
    const projection = BattlefieldProjection(
      origin: Offset(32, 130),
      xAxis: Offset(38, 8),
      yAxis: Offset(-3, 31),
      heightAxis: Offset(0, -19),
    );
    void installPresentation(int epoch) {
      game.nativeBattlefieldSceneEpoch = epoch;
      game.battlefieldProjection = projection;
      game.nativeBattlefieldGroups = {'labels', 'selection', 'effects'};
      game.nativeBattlefieldTurretLevels = true;
      game.nativeBattlefieldLoading = false;
    }

    installPresentation(10);
    game.startStage(5);
    expect(game.snapshotNotifier.value.currentStageNumber, 5);
    expect(game.nativeBattlefieldSceneEpoch, 0);
    expect(game.battlefieldProjection, isNull);
    expect(game.nativeBattlefieldGroups, isEmpty);
    expect(game.nativeBattlefieldTurretLevels, isFalse);
    expect(game.nativeBattlefieldLoading, isTrue);
    expect(game.battlefieldFrame!.map, same(gameStages[4].map));
    installPresentation(11);
    game.startStage(6);
    expect(game.snapshotNotifier.value.currentStageNumber, 6);
    expect(game.nativeBattlefieldSceneEpoch, 0);
    expect(game.battlefieldProjection, isNull);
    expect(game.nativeBattlefieldGroups, isEmpty);
    expect(game.nativeBattlefieldTurretLevels, isFalse);
    expect(game.nativeBattlefieldLoading, isTrue);
    expect(game.battlefieldFrame!.map, same(gameStages[5].map));
    expect(
      game.battlefieldFrame!.map.tileTheme.kind,
      MapTileThemeKind.chapterTwoRift,
    );
  });

  test('스테이지 1~15 모든 웨이브 적은 기존 Godot 모델로 표시할 수 있다', () {
    final source = File('godot/main.gd').readAsStringSync();
    final modelBlock = RegExp(
      r'const ENEMY_MODELS := \{([^}]+)\}',
      dotAll: true,
    ).firstMatch(source)!.group(1)!;
    final supported = RegExp(
      r'"([a-zA-Z_]+)": preload',
    ).allMatches(modelBlock).map((match) => match.group(1)!).toSet();
    for (final stage in gameStages.where((stage) => stage.id <= 15)) {
      final required = stage.waves
          .expand((wave) => wave.groups)
          .map((group) => group.enemyType.name)
          .toSet();
      expect(
        required.difference(supported),
        isEmpty,
        reason: '스테이지 ${stage.id}의 모든 웨이브 모델이 필요합니다.',
      );
    }
  });

  for (final stage in [
    StageDefinition(
      id: 16,
      name: 'Unsupported stage',
      firstClearCorePointReward: 0,
      map: gameStages.last.map,
      waves: gameStages.last.waves,
    ),
  ]) {
    test('스테이지 ${stage.id}는 기존 2D 전장을 유지한다', () async {
      final game = RuneNexusGame(
        stage: stage,
        saveRepository: MemorySaveRepository(),
      );
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      addTearDown(game.disposeAppResources);
      expect(game.readyNotifier.value, isTrue);
      expect(game.supportsNativeBattlefield, isFalse);
      expect(game.battlefieldFrame, isNull);
      expect(game.backgroundColor().a, 1);
    });
  }
}
