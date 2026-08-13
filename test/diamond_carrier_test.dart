import 'package:rune_nexus/domain/enemy/diamond_carrier_rules.dart';
import 'package:rune_nexus/game/components/diamond_reward_effect_component.dart';

import 'helpers/game_balance_test_helpers.dart';

void main() {
  group('다이아 운반체 확률', () {
    test('단일 롤 경계가 1/2/3개를 0.35%/0.10%/0.05%로 나눈다', () {
      int reward(double roll) => DiamondCarrierRules.rewardForSpawn(
        type: EnemyType.normal,
        isDirectWaveSpawn: true,
        roll: roll,
      );

      expect(reward(0), 1);
      expect(reward(0.003499999), 1);
      expect(reward(0.0035), 2);
      expect(reward(0.004499999), 2);
      expect(reward(0.0045), 3);
      expect(reward(0.004999999), 3);
      expect(reward(0.005), 0);
      expect(reward(0.999999), 0);
    });

    test('확정 운반체 보상 경계가 70%/20%/10%를 따른다', () {
      expect(DiamondCarrierRules.rewardForCarrierRoll(0), 1);
      expect(DiamondCarrierRules.rewardForCarrierRoll(0.699999), 1);
      expect(DiamondCarrierRules.rewardForCarrierRoll(0.7), 2);
      expect(DiamondCarrierRules.rewardForCarrierRoll(0.899999), 2);
      expect(DiamondCarrierRules.rewardForCarrierRoll(0.9), 3);
      expect(DiamondCarrierRules.rewardForCarrierRoll(0.999999), 3);
    });

    test('보스와 웨이브 직접 생성이 아닌 적은 항상 제외한다', () {
      for (final boss in const [
        EnemyType.boss,
        EnemyType.shieldBoss,
        EnemyType.forgeBoss,
      ]) {
        expect(
          DiamondCarrierRules.rewardForSpawn(
            type: boss,
            isDirectWaveSpawn: true,
            roll: 0,
          ),
          0,
        );
      }
      expect(
        DiamondCarrierRules.rewardForSpawn(
          type: EnemyType.normal,
          isDirectWaveSpawn: false,
          roll: 0,
        ),
        0,
      );
    });
  });

  test('debug 강제 운반체는 조건부 보상 롤을 쓰고 일반 debug 적은 제외한다', () async {
    final rolls = <double>[0.699999, 0.7, 0.9];
    var rollIndex = 0;
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      enableDebugEnemySpawnForTesting: true,
      diamondCarrierRollForTesting: () => rolls[rollIndex++],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    for (var index = 0; index < rolls.length; index++) {
      game.debugSpawnDiamondCarrier();
    }
    game.debugSpawnEnemy(EnemyType.normal);

    expect(
      game.enemies.map((enemy) => enemy.diamondReward),
      orderedEquals([1, 2, 3, 0]),
    );
    expect(rollIndex, rolls.length);
  });

  test('웨이브 직접 생성 적만 주입된 롤로 운반체가 된다', () async {
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      diamondCarrierRollForTesting: () => 0.0045,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [
            SpawnGroup(enemyType: EnemyType.normal, count: 1, interval: 1),
          ],
          clearRewardGold: 0,
        ),
      ],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.startNextWave();
    game.update(1);

    expect(game.enemies, hasLength(1));
    expect(game.enemies.single.isDiamondCarrier, isTrue);
    expect(game.enemies.single.diamondReward, 3);
  });

  test('보스 웨이브는 최저 롤에서도 운반체를 만들지 않는다', () async {
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      diamondCarrierRollForTesting: () => 0,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [
            SpawnGroup(enemyType: EnemyType.boss, count: 1, interval: 1),
          ],
          clearRewardGold: 0,
        ),
      ],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();

    game.startNextWave();
    game.update(1);

    expect(game.enemies, hasLength(1));
    expect(game.enemies.single.isDiamondCarrier, isFalse);
    expect(game.enemies.single.diamondReward, 0);
  });

  test('운반체 정상 처치는 기존 보상과 함께 무료 다이아를 지급한다', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    final before = game.snapshotNotifier.value;
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 10,
      diamondReward: 2,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    game.enemies.add(enemy);
    await game.add(enemy);

    enemy.receiveDamage(10);
    game.update(0);

    final after = game.snapshotNotifier.value;
    expect(after.diamonds, before.diamonds + 2);
    expect(after.gold, before.gold + gameEnemies[EnemyType.normal]!.rewardGold);
    expect(
      after.dailyQuestProgress[DailyQuestType.killEnemies],
      (before.dailyQuestProgress[DailyQuestType.killEnemies] ?? 0) + 1,
    );
    expect(game.children.whereType<DiamondRewardEffectComponent>(), isNotEmpty);
  });

  test('운반체가 코어에 도달하면 다이아를 지급하지 않는다', () async {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 10,
      diamondReward: 3,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    game.enemies.add(enemy);
    await game.add(enemy);
    final beforeDiamonds = game.snapshotNotifier.value.diamonds;

    game.enemyReachedCore(enemy);

    expect(game.snapshotNotifier.value.diamonds, beforeDiamonds);
    expect(game.children.whereType<DiamondRewardEffectComponent>(), isEmpty);
  });

  test('운반체 보상량은 JSON에 저장되고 구버전 누락값은 0이다', () {
    final game = RuneNexusGame();
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      diamondReward: 2,
      path: [Vector2.zero(), Vector2(500, 0)],
      game: game,
    );
    final json = enemy.toSaveData().toJson();

    expect(json['diamondReward'], 2);
    expect(SavedEnemy.fromJson(json)!.diamondReward, 2);
    expect(
      SavedEnemy.fromJson(
        Map<String, Object?>.of(json)..remove('diamondReward'),
      )!.diamondReward,
      0,
    );
    expect(
      SavedEnemy.fromJson(
        Map<String, Object?>.of(json)
          ..['type'] = EnemyType.boss.name
          ..['diamondReward'] = 3,
      )!.diamondReward,
      0,
    );
  });

  test('살아 있는 운반체는 전체 저장과 게임 복원 뒤에도 유지된다', () async {
    final repository = MemorySaveRepository();
    final game = RuneNexusGame(
      saveRepository: repository,
      diamondCarrierRollForTesting: () => 0.0035,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [
            SpawnGroup(enemyType: EnemyType.normal, count: 1, interval: 1),
          ],
          clearRewardGold: 0,
        ),
      ],
    );
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.startNextWave();
    game.update(1);
    await game.saveNow();

    expect(repository.data!.activeRun!.enemies.single.diamondReward, 2);

    final restored = RuneNexusGame(
      saveRepository: MemorySaveRepository()..data = repository.data,
      waves: const [
        WaveDefinition(
          round: 1,
          previewText: 'test',
          groups: [
            SpawnGroup(enemyType: EnemyType.normal, count: 1, interval: 1),
          ],
          clearRewardGold: 0,
        ),
      ],
    );
    restored.onGameResize(Vector2(400, 800));
    await restored.onLoad();

    expect(restored.enemies, hasLength(1));
    expect(restored.enemies.single.isDiamondCarrier, isTrue);
    expect(restored.enemies.single.diamondReward, 2);
  });
}
