import '../../domain/enemy/enemy_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/map/map_definition.dart';
import '../../domain/map/tile_type.dart';
import '../../domain/wave/wave_definition.dart';

const demoMap = MapDefinition(
  columns: 8,
  rows: 10,
  tiles: [
    [
      TileType.spawn,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.blocked,
      TileType.build,
    ],
    [
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.core,
      TileType.build,
    ],
  ],
  path: [
    GridPoint(0, 0),
    GridPoint(1, 0),
    GridPoint(1, 1),
    GridPoint(1, 2),
    GridPoint(2, 2),
    GridPoint(3, 2),
    GridPoint(4, 2),
    GridPoint(4, 3),
    GridPoint(4, 4),
    GridPoint(5, 4),
    GridPoint(6, 4),
    GridPoint(6, 5),
    GridPoint(6, 6),
    GridPoint(5, 6),
    GridPoint(4, 6),
    GridPoint(3, 6),
    GridPoint(2, 6),
    GridPoint(1, 6),
    GridPoint(1, 7),
    GridPoint(1, 8),
    GridPoint(1, 9),
    GridPoint(2, 9),
    GridPoint(3, 9),
    GridPoint(4, 9),
    GridPoint(5, 9),
    GridPoint(6, 9),
  ],
);

final demoWaves = List<WaveDefinition>.unmodifiable(_buildDemoWaves());

List<WaveDefinition> _buildDemoWaves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    final tier = (round - 1) ~/ 10;
    final step = round + tier * 3;
    return WaveDefinition(
      round: round,
      previewText: _previewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _groupsFor(round, step),
    );
  });
}

int _clearRewardGoldFor(int round) {
  if (round % 10 == 0) {
    return 70 + round * 3;
  }
  if (round % 5 == 0) {
    return 48 + round * 2;
  }
  return 22 + round;
}

String _previewTextFor(int round) {
  if (round % 10 == 0) {
    return '보스 압박';
  }
  if (round % 5 == 0) {
    return '탱커 돌파';
  }
  if (round >= 26) {
    return '고밀도 혼합';
  }
  if (round >= 11) {
    return '혼합 웨이브';
  }
  if (round >= 4) {
    return '빠른 적 등장';
  }
  return '일반 적 중심';
}

List<SpawnGroup> _groupsFor(int round, int step) {
  if (round % 10 == 0) {
    final bossCount = 1 + round ~/ 30;
    final boss = SpawnGroup(
      enemyType: EnemyType.boss,
      count: bossCount,
      interval: 1.6,
    );
    final tank = SpawnGroup(
      enemyType: EnemyType.tank,
      count: 4 + step ~/ 4,
      interval: 1.08,
      startDelay: 1.8,
    );
    return [
      boss,
      tank,
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 9 + step ~/ 2,
        interval: 0.46,
        startDelay: _nextGroupDelay(tank, reserve: 1, gap: 0.55),
      ),
    ];
  }

  if (round % 5 == 0) {
    final tank = SpawnGroup(
      enemyType: EnemyType.tank,
      count: 3 + step ~/ 4,
      interval: 1.15,
    );
    return [
      tank,
      SpawnGroup(
        enemyType: EnemyType.normal,
        count: 8 + step ~/ 2,
        interval: 0.62,
        startDelay: _nextGroupDelay(tank, reserve: 1, gap: 0.55),
      ),
    ];
  }

  if (round >= 26) {
    final normal = SpawnGroup(
      enemyType: EnemyType.normal,
      count: 12 + step ~/ 2,
      interval: 0.52,
    );
    final fast = SpawnGroup(
      enemyType: EnemyType.fast,
      count: 8 + step ~/ 2,
      interval: 0.42,
      startDelay: _nextGroupDelay(normal, reserve: 1, gap: 0.4),
    );
    return [
      normal,
      fast,
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 3 + step ~/ 6,
        interval: 1.08,
        startDelay: _nextGroupDelay(fast, reserve: 1, gap: 0.55),
      ),
    ];
  }

  if (round >= 11) {
    final normal = SpawnGroup(
      enemyType: EnemyType.normal,
      count: 9 + step ~/ 2,
      interval: 0.56,
    );
    final fast = SpawnGroup(
      enemyType: EnemyType.fast,
      count: 5 + step ~/ 3,
      interval: 0.46,
      startDelay: _nextGroupDelay(normal, reserve: 1, gap: 0.4),
    );
    return [
      normal,
      fast,
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + step ~/ 8,
        interval: 1.18,
        startDelay: _nextGroupDelay(fast, reserve: 1, gap: 0.55),
      ),
    ];
  }

  if (round >= 4) {
    final normal = SpawnGroup(
      enemyType: EnemyType.normal,
      count: 6 + round,
      interval: 0.7,
    );
    return [
      normal,
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 3 + round,
        interval: 0.52,
        startDelay: _nextGroupDelay(normal, reserve: 1, gap: 0.45),
      ),
    ];
  }

  return [
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + round * 2,
      interval: 0.82,
    ),
  ];
}

double _nextGroupDelay(
  SpawnGroup previous, {
  required int reserve,
  required double gap,
}) {
  final almostFinishedCount = previous.count > reserve
      ? previous.count - reserve
      : 0;
  return previous.startDelay + previous.interval * almostFinishedCount + gap;
}
