import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';

import 'helpers/game_balance_test_helpers.dart';

const _projection = BattlefieldProjection(
  origin: Offset(32, 130),
  xAxis: Offset(38, 8),
  yAxis: Offset(-3, 31),
  heightAxis: Offset(0, -19),
);

Future<RuneNexusGame> _game(
  int stageNumber,
  MemorySaveRepository repository,
) async {
  final game = RuneNexusGame(
    stage: gameStages[stageNumber - 1],
    stages: gameStages,
    saveRepository: repository,
    enableDebugEnemySpawnForTesting: true,
  );
  game.onGameResize(Vector2(400, 800));
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  addTearDown(game.disposeAppResources);
  await game.ready();
  return game;
}

int _effect(RuneNexusGame game) => game.emitBattlefieldEffect(
  kind: 'impact',
  position: Vector2(100, 150),
  duration: .28,
  color: const Color(0xff5cf9e9),
  style: 'spark',
  radius: 16,
)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stage in gameStages.where(
    (stage) => stage.id >= 6 && stage.id <= 10,
  )) {
    test('스테이지 ${stage.id} 균열 맵·건설 선택·적·짧은 효과를 원본 상태대로 전달한다', () async {
      final repository = MemorySaveRepository();
      final game = await _game(stage.id, repository);
      expect(game.supportsNativeBattlefield, isTrue);
      expect(game.battlefieldFrame!.map, same(stage.map));
      expect(stage.map.tileTheme.kind, MapTileThemeKind.chapterTwoRift);
      game.nativeBattlefieldSceneEpoch = stage.id;
      game.battlefieldProjection = _projection;
      final buildPoint = [
        for (var y = 0; y < stage.map.rows; y++)
          for (var x = 0; x < stage.map.columns; x++)
            if (stage.map.canBuildAt(GridPoint(x, y))) GridPoint(x, y),
      ].first;
      final screen = _projection.gridToScreen(
        Offset(buildPoint.x + .5, buildPoint.y + .5),
      );
      game.onBoardTapDown(Vector2(screen.dx, screen.dy));
      expect(game.snapshotNotifier.value.selectedBuildPoint, buildPoint);
      game.tryBuildTurret(buildPoint);
      await game.ready();
      expect(game.battlefieldFrame!.selection!.turrets.single.selected, isTrue);
      final selected =
          game.battlefieldFrame!.selection!.turrets.single.position;
      expect(selected.dx, closeTo(buildPoint.x + .5, 1e-5));
      expect(selected.dy, closeTo(buildPoint.y + .5, 1e-5));
      final enemyTypes = stage.waves
          .expand((wave) => wave.groups)
          .map((group) => group.enemyType)
          .toSet();
      for (final type in enemyTypes) {
        game.debugSpawnEnemy(type);
      }
      await game.ready();
      expect(
        game.enemies.map((enemy) => enemy.definition.type).toSet(),
        enemyTypes,
      );
      final effectId = _effect(game);
      game.update(1);
      final frame = game.battlefieldFrame!;
      expect(frame.effects!.items, isEmpty);
      expect(frame.effects!.events, hasLength(1));
      expect(frame.effects!.events.single['id'], effectId);
      await game.saveNow();
      final saved = repository.data!.toJson();
      final encoded = encodeGodotBattlefieldFrame(
        frame,
        sequence: 3,
        sceneEpoch: stage.id,
      );
      expect(encoded['map'], {
        'theme': 'chapterTwoRift',
        'columns': stage.map.columns,
        'rows': stage.map.rows,
        'tiles': [
          for (final row in stage.map.tiles)
            for (final tile in row) tile.name,
        ],
      });
      final presentation = encoded['presentation']! as Map;
      expect((presentation['effects'] as Map)['events'], hasLength(1));
      // Godot constructs actors from authoritative state; Flutter sends no
      // duplicate actor list. Model availability is checked headlessly.
      expect(encoded['enemies'], isEmpty);
      expect(repository.data!.toJson(), saved);
      game.markNativeBattlefieldEffectsSubmitted(stage.id, 3, [effectId]);
      game.acknowledgeNativeBattlefieldEffects(stage.id, 3);
      expect(game.battlefieldFrame!.effects!.events, isEmpty);
    });
  }

  test('10→15→1 전환은 이전 장 투영·효과를 버리고 새 3D 테마를 전달한다', () async {
    final game = await _game(10, MemorySaveRepository());
    game.debugSetClearedStageCount(15);
    game.nativeBattlefieldSceneEpoch = 100;
    game.battlefieldProjection = _projection;
    game.nativeBattlefieldGroups = {'labels', 'selection', 'effects'};
    game.nativeBattlefieldTurretLevels = true;
    _effect(game);
    game.update(1);
    expect(game.battlefieldFrame!.effects!.events, hasLength(1));
    game.startStage(15);
    expect(game.snapshotNotifier.value.currentStageNumber, 15);
    expect(game.supportsNativeBattlefield, isTrue);
    expect(game.battlefieldFrame!.map, same(gameStages.last.map));
    expect(game.battlefieldProjection, isNull);
    expect(game.nativeBattlefieldSceneEpoch, 0);
    expect(game.nativeBattlefieldGroups, isEmpty);
    expect(game.nativeBattlefieldTurretLevels, isFalse);
    expect(game.nativeBattlefieldLoading, isTrue);

    game.startStage(1);
    expect(game.supportsNativeBattlefield, isTrue);
    expect(game.battlefieldProjection, isNull);
    expect(game.battlefieldFrame!.effects!.events, isEmpty);
    final map =
        encodeGodotBattlefieldFrame(game.battlefieldFrame!, sequence: 0)['map']!
            as Map;
    expect(map['theme'], 'chapterOne');
    expect(game.battlefieldFrame!.map, same(gameStages.first.map));
  });
}
