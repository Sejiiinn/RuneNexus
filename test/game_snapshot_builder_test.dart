import 'helpers/game_balance_test_helpers.dart';

void main() {
  test('range selection follows tile taps and completed placement', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    const firstPoint = GridPoint(2, 0);
    const secondPoint = GridPoint(3, 0);
    expect(game.isTurretPlacementActive, isFalse);
    expect(game.snapshotNotifier.value.selectedTurretPoint, isNull);

    game.tryBuildTurret(firstPoint);
    expect(game.isTurretSelected(firstPoint), isTrue);
    expect(game.snapshotNotifier.value.selectedTurretPoint, firstPoint);
    expect(game.isTurretPlacementActive, isFalse);

    tapBuildTile(game, secondPoint);
    expect(game.isTurretPlacementActive, isTrue);
    expect(game.snapshotNotifier.value.selectedBuildPoint, secondPoint);
    expect(game.isTurretSelected(firstPoint), isFalse);
    expect(game.snapshotNotifier.value.selectedTurretPoint, isNull);

    game.previewOrBuildSelectedTile(TurretType.arrow);
    expect(game.isTurretPlacementActive, isTrue);
    expect(
      game.snapshotNotifier.value.selectedBuildTurretType,
      TurretType.arrow,
    );
    game.confirmBuildSelectedTile();
    expect(game.snapshotNotifier.value.placedTurretCount, 2);
    expect(game.isTurretPlacementActive, isFalse);
    expect(game.snapshotNotifier.value.selectedBuildPoint, isNull);
    expect(game.isTurretSelected(secondPoint), isTrue);
    expect(game.snapshotNotifier.value.selectedTurretPoint, secondPoint);

    tapBuildTile(game, firstPoint);
    expect(game.isTurretSelected(firstPoint), isTrue);
    expect(game.isTurretSelected(secondPoint), isFalse);
    expect(game.snapshotNotifier.value.selectedTurretPoint, firstPoint);
    expect(game.isTurretPlacementActive, isFalse);

    tapBuildTile(game, const GridPoint(-1, -1));
    expect(game.isTurretSelected(firstPoint), isFalse);
    expect(game.isTurretPlacementActive, isFalse);
    expect(game.snapshotNotifier.value.selectedTurretPoint, isNull);
    expect(game.snapshotNotifier.value.selectedBuildPoint, isNull);
  });

  test(
    'snapshot projects wave and stage progress without changing state',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();

      final initial = game.snapshotNotifier.value;
      expect(initial.hasStageProgress, isFalse);
      expect(initial.placedTurretCount, 0);
      expect(initial.round, 1);
      expect(initial.nextWaveEnemyTypes, isNotEmpty);
      expect(
        initial.nextWaveEnemyCounts.values.reduce((a, b) => a + b),
        greaterThan(0),
      );

      const point = GridPoint(2, 0);
      game.tryBuildTurret(point);

      final withTurret = game.snapshotNotifier.value;
      expect(withTurret.hasStageProgress, isTrue);
      expect(withTurret.placedTurretCount, 1);
      expect(withTurret.selectedTurretPoint, point);
      expect(
        withTurret.selectedTurretName,
        gameTurrets[TurretType.arrow]!.name,
      );
      expect(withTurret.nextWaveEnemyTypes, initial.nextWaveEnemyTypes);
      expect(withTurret.nextWaveEnemyCounts, initial.nextWaveEnemyCounts);
    },
  );

  test(
    'snapshot publish permanently clears unaffordable level-up preview',
    () async {
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());

      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      const point = GridPoint(2, 0);
      game.tryBuildTurret(point);

      game.previewOrLevelUpSelectedTurret();
      expect(
        game.snapshotNotifier.value.selectedTurretLevelUpPreviewActive,
        isTrue,
      );

      game.buyRunUpgrade(RunUpgradeType.towerDamage);
      expect(
        game.snapshotNotifier.value.selectedTurretLevelUpPreviewActive,
        isTrue,
      );
      game.buyRunUpgrade(RunUpgradeType.towerDamage);

      final invalidated = game.snapshotNotifier.value;
      expect(invalidated.gold, lessThan(invalidated.selectedTurretLevelUpCost));
      expect(invalidated.selectedTurretLevelUpPreviewActive, isFalse);
      expect(game.levelUpPreviewRangeFor(point), isNull);

      game.debugAddGold(100);
      expect(
        game.snapshotNotifier.value.selectedTurretLevelUpPreviewActive,
        isFalse,
      );
      expect(game.levelUpPreviewRangeFor(point), isNull);
    },
  );
}
