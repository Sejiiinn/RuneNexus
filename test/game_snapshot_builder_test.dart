import 'helpers/game_balance_test_helpers.dart';

void main() {
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
