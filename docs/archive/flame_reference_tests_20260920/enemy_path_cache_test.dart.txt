import 'dart:math' as math;

import 'helpers/game_balance_test_helpers.dart';

void main() {
  EnemyComponent enemyOn(List<Vector2> path) => EnemyComponent(
    definition: gameEnemies[EnemyType.normal]!,
    maxHp: 100,
    laneOffsetRatio: 0.12,
    path: path,
    game: RuneNexusGame(),
  );

  void restoreDistance(EnemyComponent enemy, double distance) {
    final json = enemy.toSaveData().toJson();
    json['distanceTravelled'] = distance;
    enemy.restoreFromSaveData(SavedEnemy.fromJson(json)!);
  }

  void expectPoint(Vector2 actual, Vector2 expected) {
    expect(actual.x, closeTo(expected.x, 1e-5));
    expect(actual.y, closeTo(expected.y, 1e-5));
  }

  test('복원 후 코너 양쪽 표본과 끝점 감쇠가 기존 경로 위치를 유지한다', () {
    final enemy = enemyOn([Vector2.zero(), Vector2(100, 0), Vector2(100, 100)]);
    for (final distance in [
      0.0,
      5.0,
      80.8,
      90.0,
      100.0,
      110.0,
      195.0,
      200.0,
      250.0,
    ]) {
      restoreDistance(enemy, distance);
      Vector2 pointAt(double value) {
        final d = value.clamp(0.0, 200.0);
        return d <= 100 ? Vector2(d, 0) : Vector2(100, d - 100);
      }

      final center = pointAt(distance);
      final tangent = pointAt(distance + 19.2) - pointAt(distance - 19.2);
      final fade = (math.min(distance, 200 - distance) / (48 * 0.55)).clamp(
        0.0,
        1.0,
      );
      final offset = tangent.length2 <= 0.001
          ? Vector2.zero()
          : (Vector2(-tangent.y, tangent.x)..normalize()) * 5.76 * fade;
      expectPoint(enemy.position, center);
      expectPoint(enemy.visualPosition, center + offset);
    }
  });

  test('중복 좌표를 끼운 경로도 복원과 시각 표본 및 경계 다음 이동이 같다', () {
    final plain = enemyOn([Vector2.zero(), Vector2(100, 0), Vector2(100, 100)]);
    final duplicate = enemyOn([
      Vector2.zero(),
      Vector2.zero(),
      Vector2(100, 0),
      Vector2(100, 0),
      Vector2(100, 100),
      Vector2(100, 100),
    ]);
    for (final distance in [0.0, 50.0, 100.0, 150.0, 200.0, 220.0]) {
      restoreDistance(plain, distance);
      restoreDistance(duplicate, distance);
      expectPoint(duplicate.position, plain.position);
      expectPoint(duplicate.visualPosition, plain.visualPosition);
    }
    restoreDistance(duplicate, 100);
    duplicate.update(0);
    expectPoint(duplicate.position, Vector2(100, 0));
  });

  test('모든 좌표가 같거나 한 점뿐인 경로는 끝점에 머문다', () {
    for (final path in [
      [Vector2(7, 11)],
      [Vector2(7, 11), Vector2(7, 11), Vector2(7, 11)],
    ]) {
      final enemy = enemyOn(path);
      for (final distance in [0.0, 10.0]) {
        restoreDistance(enemy, distance);
        expectPoint(enemy.position, Vector2(7, 11));
        expectPoint(enemy.visualPosition, Vector2(7, 11));
      }
      enemy.updatePath([Vector2.zero(), Vector2(200, 0)]);
      expect(enemy.distanceTravelled, 0);
      expectPoint(enemy.position, Vector2.zero());
    }
  });

  test('공개 path 대입도 새 경로로 복원 및 시각 표본을 계산한다', () {
    final enemy = enemyOn([Vector2.zero(), Vector2(100, 0)]);
    enemy.path = [Vector2.zero(), Vector2(0, 200)];
    restoreDistance(enemy, 100);
    expectPoint(enemy.position, Vector2(0, 100));
    expectPoint(enemy.visualPosition, Vector2(-5.76, 100));
  });

  test('경로 교체와 레이아웃 확대에서 캐시가 갱신된다', () {
    final enemy = enemyOn([Vector2.zero(), Vector2(100, 0), Vector2(100, 100)]);
    restoreDistance(enemy, 150);
    final resized = [Vector2.zero(), Vector2(200, 0), Vector2(200, 200)];
    enemy.updateLayout(tileSize: 96, newPath: resized);
    expect(enemy.distanceTravelled, 300);
    expectPoint(enemy.position, Vector2(200, 100));
    enemy.updatePath([Vector2.zero(), Vector2(200, 0), Vector2(200, 600)]);
    expect(enemy.distanceTravelled, 600);
    expectPoint(enemy.position, Vector2(200, 400));
    enemy.updatePath([Vector2(1, 1)]);
    expectPoint(enemy.position, Vector2(200, 400));
  });
}
