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

  test(
    'native collectors forward live statuses and current selection without mutating saves',
    () async {
      final repository = MemorySaveRepository();
      final game = RuneNexusGame(
        saveRepository: repository,
        enableDebugEnemySpawnForTesting: true,
      );
      game.onGameResize(Vector2(400, 800));
      // Mount real components so this exercises the game's collectors, not DTO fixtures.
      // ignore: invalid_use_of_internal_member
      await game.load();
      // ignore: invalid_use_of_internal_member
      game.mount();
      addTearDown(game.disposeAppResources);
      game.debugAddGold(1000);
      game.selectTurretType(TurretType.frost);
      const point = GridPoint(2, 0);
      game.tryBuildTurret(point);
      await game.ready();
      final turret = game.children.whereType<TurretComponent>().single;
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
        enemy.applyBurn(damagePerSecond: 2, duration: 3);
        enemy.applyPoison(damagePerSecond: 1, duration: 4, maxStacks: 2);
        enemy.applySlow(multiplier: 0.7, duration: 2);
        enemy.applyRiftMark(damageAmplification: 0.2, duration: 5);
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
      final origin = game.debugBoardOrigin();
      final labels = first.labels!;
      expect(labels.enemies, hasLength(3));
      expect(labels.logicalTileSize, first.pixelsPerTile);
      for (var i = 0; i < game.enemies.length; i++) {
        final enemy = game.enemies.elementAt(i);
        final visual = enemy.visualRenderState;
        final label = labels.enemies[i];
        expect(label.id, first.enemies[i].id);
        expect(
          label.position.dx,
          closeTo(
            (enemy.position.x - origin.x + visual.visualOffset.dx) /
                first.pixelsPerTile,
            1e-6,
          ),
        );
        expect(
          label.position.dy,
          closeTo(
            (enemy.position.y - origin.y + visual.visualOffset.dy) /
                first.pixelsPerTile,
            1e-6,
          ),
        );
        expect(label.size, visual.size);
        expect(
          [
            label.hp,
            label.maxHp,
            label.armor,
            label.maxArmor,
            label.shield,
            label.maxShield,
          ],
          [
            visual.hp,
            visual.maxHp,
            visual.armor,
            visual.maxArmor,
            visual.shield,
            visual.maxShield,
          ],
        );
        expect(
          [label.burning, label.poisoned, label.slowed, label.riftMarked],
          [true, true, true, true],
        );
        expect(
          [label.burning, label.poisoned, label.slowed, label.riftMarked],
          [
            visual.isBurning,
            visual.isPoisoned,
            visual.isSlowed,
            visual.hasRiftMark,
          ],
        );
        expect(label.diamondCarrier, visual.isDiamondCarrier);
        expect(label.effectTime, visual.effectTime);
        expect(label.enemyCount, visual.enemyCount);
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
