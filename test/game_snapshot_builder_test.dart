import 'helpers/game_balance_test_helpers.dart';

void main() {
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
