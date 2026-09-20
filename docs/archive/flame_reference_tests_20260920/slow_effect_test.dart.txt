import 'helpers/game_balance_test_helpers.dart';

EnemyComponent _enemy() => EnemyComponent(
  definition: gameEnemies[EnemyType.normal]!,
  maxHp: 1000,
  path: [Vector2.zero(), Vector2(10000, 0)],
  game: RuneNexusGame(saveRepository: MemorySaveRepository()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy save restores enemy safely without old slow state', () {
    final json = _enemy().toSaveData().toJson()
      ..remove('slowInstances')
      ..['slowRemaining'] = 5.0
      ..['slowMultiplier'] = 0.5
      ..['hp'] = 750.0
      ..['distanceTravelled'] = 30.0;
    final restored = _enemy()..restoreFromSaveData(SavedEnemy.fromJson(json)!);
    expect(restored.hp, 750);
    expect(restored.distanceTravelled, 30);
    expect(restored.isSlowed, isFalse);
    expect(restored.slowMultiplier, 1);
    expect(() => restored.update(0.1), returnsNormally);
  });

  for (final reverse in [false, true]) {
    test('strong slow expires before weaker slow, reverse=$reverse', () {
      final enemy = _enemy();
      if (reverse) enemy.applySlow(multiplier: 0.8, duration: 5);
      enemy.applySlow(multiplier: 0.5, duration: 1);
      if (!reverse) enemy.applySlow(multiplier: 0.8, duration: 5);
      expect(enemy.slowMultiplier, 0.5);
      expect(enemy.slowRemaining, 1);
      enemy.update(1);
      expect(enemy.slowMultiplier, 0.8);
      expect(enemy.slowRemaining, 4);
      enemy.update(4);
      expect(enemy.isSlowed, isFalse);
      expect(enemy.slowMultiplier, 1);
    });
  }

  test('repeated weak hits cannot refresh the strong slow', () {
    final enemy = _enemy()..applySlow(multiplier: 0.5, duration: 1);
    enemy.update(0.5);
    enemy.applySlow(multiplier: 0.8, duration: 5);
    enemy.applySlow(multiplier: 0.8, duration: 2);
    enemy.update(0.5);
    expect(enemy.slowMultiplier, 0.8);
    expect(enemy.slowRemaining, 4.5);
    expect(enemy.toSaveData().slowInstances, hasLength(1));
    enemy.applySlow(multiplier: 0.8, duration: 6);
    expect(enemy.slowRemaining, 6);
  });

  test('save round trip preserves independent slow expiration', () {
    final enemy = _enemy()
      ..applySlow(multiplier: 0.5, duration: 1)
      ..applySlow(multiplier: 0.8, duration: 5);
    final saved = SavedEnemy.fromJson(enemy.toSaveData().toJson())!;
    final restored = _enemy()..restoreFromSaveData(saved);
    expect(restored.slowMultiplier, 0.5);
    restored.update(1);
    expect(restored.slowMultiplier, 0.8);
    expect(restored.slowRemaining, 4);
    restored.update(4);
    expect(restored.isSlowed, isFalse);
  });

  test(
    'expired weaker effects do not return and invalid effects are ignored',
    () {
      final enemy = _enemy()
        ..applySlow(multiplier: 0.5, duration: 5)
        ..applySlow(multiplier: 0.8, duration: 1)
        ..applySlow(multiplier: -1, duration: 10)
        ..applySlow(multiplier: 0.1, duration: double.nan);
      enemy.update(2);
      expect(enemy.slowMultiplier, 0.5);
      expect(enemy.toSaveData().slowInstances, hasLength(1));
      enemy.update(3);
      expect(enemy.isSlowed, isFalse);
    },
  );
}
