import 'dart:ui' as ui;

import 'package:rune_nexus/game/rendering/status_effect_sprite_cache.dart';

import 'helpers/game_balance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('enemy rendering preserves position, saved state and canvas', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.statusEffectSprites = StatusEffectSpriteCache.create();
    addTearDown(game.statusEffectSprites.dispose);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const cellSize = 96.0;
    var row = 0;

    // 열: 적 8종. 행: 초기/변경 레이아웃 × 밀도 경계 × 일반/상태 효과/피격.
    for (final tileSize in [null, 72.0]) {
      for (final enemyCount in [59, 60, 79, 80]) {
        for (var effect = 0; effect < 3; effect++) {
          for (final (column, type) in EnemyType.values.indexed) {
            final enemy = EnemyComponent(
              definition: gameEnemies[type]!,
              maxHp: 1000,
              maxShield: 300,
              maxArmor: 200,
              diamondReward: effect == 0 ? 0 : 3,
              laneOffsetRatio: 0.2,
              visualPhase: 0.7,
              path: [Vector2.zero(), Vector2(300, 100)],
              game: game,
            );
            game.enemies
              ..clear()
              ..addAll(List.filled(enemyCount, enemy));
            enemy.update(0.13);
            enemy.hp = 670;
            enemy.shield = 180;
            enemy.armor = 90;
            if (tileSize != null) {
              enemy.updateLayout(
                tileSize: tileSize,
                newPath: [Vector2.zero(), Vector2(500, 200)],
              );
            }
            if (effect > 0) {
              enemy
                ..applyBurn(damagePerSecond: 3, duration: 4)
                ..applySlow(multiplier: 0.6, duration: 4)
                ..applyPoison(damagePerSecond: 2, duration: 4, maxStacks: 3)
                ..applyRiftMark(damageAmplification: 0.2, duration: 4);
            }
            if (effect == 2) {
              enemy.showHitFlash(const Color(0xFFFFC47A));
            }
            final saved = enemy.toSaveData().toJson();
            final position = enemy.position.clone();
            final visualPosition = enemy.visualPosition.clone();
            final canvasDepth = canvas.getSaveCount();
            canvas.save();
            canvas.translate(
              column * cellSize + (cellSize - enemy.size.x) / 2,
              row * cellSize + (cellSize - enemy.size.y) / 2,
            );
            enemy.render(canvas);
            canvas.restore();
            expect(canvas.getSaveCount(), canvasDepth);
            expect(enemy.toSaveData().toJson(), saved);
            expect(enemy.position, position);
            expect(enemy.visualPosition, visualPosition);
          }
          row++;
        }
      }
    }
    final picture = recorder.endRecording();
    picture.dispose();
  });

  test('ordinary enemy renders before status sprite initialization', () {
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    final enemy = EnemyComponent(
      definition: gameEnemies[EnemyType.normal]!,
      maxHp: 100,
      path: [Vector2.zero(), Vector2(100, 0)],
      game: game,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    enemy.render(canvas);
    recorder.endRecording().dispose();
  });
}
