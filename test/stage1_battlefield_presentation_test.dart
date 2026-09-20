import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_projection.dart';
import 'helpers/game_balance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native loading freezes app clock and acknowledged enemy mirrors',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      game.onGameResize(Vector2(400, 800));
      await game.load();
      addTearDown(game.disposeAppResources);
      final enemy = targetPriorityEnemy(
        game: game,
        hp: 100,
        progress: 0,
        position: Vector2(100, 200),
      );
      game.registerEnemy(enemy);
      final position = enemy.position.clone();
      game.nativeBattlefieldLoading = true;
      final first = game.battlefieldFrame!;
      game.update(10);
      expect(game.battlefieldFrame, isNotNull);
      expect(game.battlefieldFrame!.time, first.time);
      expect(enemy.position, position);
      game.nativeBattlefieldLoading = false;
      game.update(.1);
      expect(game.battlefieldFrame!.time, greaterThan(first.time));
      // The Dart mirror cannot simulate movement even when the clock resumes.
      expect(enemy.position, position);
      enemy.applyNativeCombatState({...enemy.nativeCombatState(1), 'x': 110.0});
      expect(enemy.position.x, 110);
    },
  );

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
      final turret = first.selection!.turrets.single;
      expect(turret.position.dx, closeTo(2.5, 0.00001));
      expect(turret.position.dy, closeTo(0.5, 0.00001));
      for (var i = 0; i < 30; i++) {
        expect(
          game.battlefieldFrame!.selection!.turrets.single.position,
          turret.position,
        );
      }
      expect(repository.data!.toJson(), saved);
      expect(game.battlefieldFrame!.turrets, isEmpty);
      expect(game.turrets, hasLength(1));
    },
  );

  test(
    '3D tile taps use the inverse projection and preserve logical input before projection',
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
      game.onBoardTapDown(Vector2(screen.dx, screen.dy));
      expect(
        game.snapshotNotifier.value.selectedBuildPoint,
        const GridPoint(2, 0),
      );
      // 네이티브 3D 전장 위에 수치·선택 표시만 투명 합성.

      game.battlefieldProjection = null;
      tapBuildTile(game, const GridPoint(3, 0));
      expect(
        game.snapshotNotifier.value.selectedBuildPoint,
        const GridPoint(3, 0),
      );
    },
  );

  test(
    'native collectors forward live statuses and current selection without mutating saves',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(
        saveRepository: repository,
        enableDebugEnemySpawnForTesting: true,
      );
      game.onGameResize(Vector2(400, 800));
      // Exercise registered mirrors, native payloads and selection collectors.
      // ignore: invalid_use_of_internal_member
      await game.load();
      // ignore: invalid_use_of_internal_member
      addTearDown(game.disposeAppResources);
      game.debugAddGold(1000);
      game.selectTurretType(TurretType.frost);
      const point = GridPoint(2, 0);
      game.tryBuildTurret(point);
      await game.ready();
      final turret = game.turrets.single;
      turret.equipGem(GemType.explosion, 0);
      game.previewOrLevelUpSelectedTurret();
      expect(game.isTurretSelected(point), isTrue);
      expect(game.levelUpPreviewRangeFor(point), isNotNull);
      expect(turret.effectAreaMultiplier, greaterThan(1));

      game.debugSpawnEnemy(EnemyType.shieldBoss);
      game.debugSpawnEnemy(EnemyType.forgeBoss);
      game.debugSpawnDiamondCarrier();
      await game.ready();
      expect(game.enemies, hasLength(3));
      for (final enemy in game.enemies) {
        enemy.hp = enemy.maxHp * 0.63;
        enemy.shield = enemy.maxShield * 0.41;
        enemy.armor = enemy.maxArmor * 0.57;
        enemy.applyNativeCombatState({
          ...enemy.nativeCombatState(game.nativeCombatEntityId(enemy)),
          'burnInstances': [
            {
              'remaining': 3.0,
              'damagePerSecond': 2.0,
              'damageMultiplier': 1.0,
              'sourceX': null,
              'sourceY': null,
              'ignoreArmorReduction': false,
            },
          ],
          'poisonRemaining': 4.0,
          'poisonDamagePerSecond': 1.0,
          'poisonStacks': 1,
          'slowInstances': [
            {'multiplier': .7, 'remaining': 2.0},
          ],
          'riftMarkRemaining': 5.0,
          'riftMarkDamageAmplification': .2,
        });
      }
      expect(game.enemies.any((enemy) => enemy.shield > 0), isTrue);
      expect(game.enemies.any((enemy) => enemy.armor > 0), isTrue);
      expect(game.enemies.any((enemy) => enemy.isDiamondCarrier), isTrue);
      await game.saveNow();
      final saved = repository.data!.toJson();
      final enemySaves = [
        for (final enemy in game.enemies) enemy.toSaveData().toJson(),
      ];
      final first = game.battlefieldFrame!;
      final labels = first.labels!;
      expect(first.enemies, isEmpty);
      expect(labels.enemies, isEmpty);
      expect(labels.logicalTileSize, first.pixelsPerTile);
      for (final enemy in game.enemies) {
        final native = enemy.nativeCombatState(
          game.nativeCombatEntityId(enemy),
        );
        expect(native['burnInstances'], hasLength(1));
        expect(native['poisonRemaining'], 4);
        expect(native['slowInstances'], hasLength(1));
        expect(native['riftMarkRemaining'], 5);
        expect(native['hp'], enemy.hp);
        expect(native['shield'], enemy.shield);
        expect(native['armor'], enemy.armor);
        expect(native['diamondReward'], enemy.diamondReward);
      }
      final selection = first.selection!;
      final selected = selection.turrets.single;
      expect(selected.position.dx, closeTo(2.5, 1e-6));
      expect(selected.position.dy, closeTo(0.5, 1e-6));
      expect(selected.selected, isTrue);
      expect(selected.color, turret.definition.color);
      expect(
        selected.range,
        closeTo(
          turret.range * turret.effectAreaMultiplier / first.pixelsPerTile,
          1e-9,
        ),
      );
      expect(
        selected.previewRange,
        closeTo(
          turret.rangeAtLevel(turret.level + 1) *
              turret.effectAreaMultiplier /
              first.pixelsPerTile,
          1e-9,
        ),
      );
      expect(selected.gemColors, [game.colorForGem(GemType.explosion)]);
      expect(selected.animationPhase, turret.visualGemRingPhase);
      expect(selected.aimProgress, turret.aimProgressRatio);
      expect(selection.rewardTargeting, game.isGemRewardTargeting);
      expect(selection.visualScale, game.boardDistanceScale);
      for (var i = 0; i < 10; i++) {
        final repeated = game.battlefieldFrame!;
        expect(repeated.labels!.toJson(), labels.toJson());
        expect(repeated.selection!.toJson(), selection.toJson());
      }
      expect(repository.data!.toJson(), saved);
      expect([
        for (final enemy in game.enemies) enemy.toSaveData().toJson(),
      ], enemySaves);
    },
  );
}
