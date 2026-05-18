import '../../domain/enemy/enemy_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/map/map_definition.dart';
import '../../domain/map/tile_type.dart';
import '../../domain/stage/stage_definition.dart';
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
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.build,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.build,
    ],
    [
      TileType.blocked,
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
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.build,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.core,
      TileType.blocked,
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

const demoStage2Map = MapDefinition(
  columns: 11,
  rows: 7,
  tiles: [
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.spawn,
      TileType.blocked,
      TileType.core,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
  ],
  path: [
    GridPoint(4, 1),
    GridPoint(3, 1),
    GridPoint(2, 1),
    GridPoint(1, 1),
    GridPoint(1, 2),
    GridPoint(1, 3),
    GridPoint(1, 4),
    GridPoint(1, 5),
    GridPoint(2, 5),
    GridPoint(3, 5),
    GridPoint(4, 5),
    GridPoint(5, 5),
    GridPoint(6, 5),
    GridPoint(7, 5),
    GridPoint(8, 5),
    GridPoint(9, 5),
    GridPoint(9, 4),
    GridPoint(9, 3),
    GridPoint(9, 2),
    GridPoint(9, 1),
    GridPoint(8, 1),
    GridPoint(7, 1),
    GridPoint(6, 1),
  ],
);

const stage3Map = MapDefinition(
  columns: 8,
  rows: 8,
  tiles: [
    [
      TileType.spawn,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
    ],
    [
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.path,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.blocked,
      TileType.path,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.core,
    ],
  ],
  path: [
    GridPoint(0, 0),
    GridPoint(1, 0),
    GridPoint(2, 0),
    GridPoint(3, 0),
    GridPoint(3, 1),
    GridPoint(3, 2),
    GridPoint(2, 2),
    GridPoint(1, 2),
    GridPoint(1, 3),
    GridPoint(1, 4),
    GridPoint(1, 5),
    GridPoint(1, 6),
    GridPoint(2, 6),
    GridPoint(3, 6),
    GridPoint(4, 6),
    GridPoint(5, 6),
    GridPoint(5, 5),
    GridPoint(5, 4),
    GridPoint(6, 4),
    GridPoint(7, 4),
    GridPoint(7, 5),
    GridPoint(7, 6),
    GridPoint(7, 7),
  ],
);

const stage4Map = MapDefinition(
  columns: 9,
  rows: 10,
  tiles: [
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.spawn,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.build,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.build,
      TileType.path,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.core,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.build,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.blocked,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
    ],
  ],
  path: [
    GridPoint(1, 1),
    GridPoint(1, 2),
    GridPoint(1, 3),
    GridPoint(2, 3),
    GridPoint(3, 3),
    GridPoint(4, 3),
    GridPoint(4, 2),
    GridPoint(5, 2),
    GridPoint(6, 2),
    GridPoint(6, 3),
    GridPoint(7, 3),
    GridPoint(7, 4),
    GridPoint(7, 5),
    GridPoint(7, 6),
    GridPoint(7, 7),
    GridPoint(7, 8),
    GridPoint(6, 8),
    GridPoint(5, 8),
    GridPoint(4, 8),
    GridPoint(3, 8),
    GridPoint(2, 8),
    GridPoint(1, 8),
    GridPoint(1, 7),
    GridPoint(1, 6),
  ],
);

const stage5Map = MapDefinition(
  columns: 9,
  rows: 9,
  tiles: [
    [
      TileType.spawn,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
    ],
    [
      TileType.path,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
    ],
    [
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.path,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.path,
    ],
    [
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.path,
    ],
    [
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.path,
    ],
    [
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.path,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.path,
    ],
    [
      TileType.path,
      TileType.build,
      TileType.blocked,
      TileType.build,
      TileType.path,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.path,
    ],
    [
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.path,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.path,
    ],
    [
      TileType.blocked,
      TileType.blocked,
      TileType.build,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.blocked,
      TileType.core,
    ],
  ],
  path: [
    GridPoint(0, 0),
    GridPoint(0, 1),
    GridPoint(0, 2),
    GridPoint(0, 3),
    GridPoint(0, 4),
    GridPoint(0, 5),
    GridPoint(0, 6),
    GridPoint(0, 7),
    GridPoint(1, 7),
    GridPoint(2, 7),
    GridPoint(3, 7),
    GridPoint(4, 7),
    GridPoint(4, 6),
    GridPoint(4, 5),
    GridPoint(4, 4),
    GridPoint(4, 3),
    GridPoint(4, 2),
    GridPoint(4, 1),
    GridPoint(5, 1),
    GridPoint(6, 1),
    GridPoint(7, 1),
    GridPoint(8, 1),
    GridPoint(8, 2),
    GridPoint(8, 3),
    GridPoint(8, 4),
    GridPoint(8, 5),
    GridPoint(8, 6),
    GridPoint(8, 7),
    GridPoint(8, 8),
  ],
);

final demoWaves = List<WaveDefinition>.unmodifiable(_buildDemoWaves());
final demoStage2Waves = List<WaveDefinition>.unmodifiable(_buildStage2Waves());

final demoStages = List<StageDefinition>.unmodifiable([
  StageDefinition(id: 1, name: 'Stage 1', map: demoMap, waves: demoWaves),
  StageDefinition(
    id: 2,
    name: 'Stage 2',
    map: demoStage2Map,
    waves: demoStage2Waves,
  ),
  StageDefinition(
    id: 3,
    name: 'Stage 3',
    map: stage3Map,
    waves: demoStage2Waves,
  ),
  StageDefinition(
    id: 4,
    name: 'Stage 4',
    map: stage4Map,
    waves: demoStage2Waves,
  ),
  StageDefinition(
    id: 5,
    name: 'Stage 5',
    map: stage5Map,
    waves: demoStage2Waves,
  ),
]);

const double _standardGroupGap = 0.75;
const double _tightGroupGap = 0.35;

List<WaveDefinition> _buildDemoWaves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _previewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _groupsFor(round),
    );
  });
}

List<WaveDefinition> _buildStage2Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _stage2PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _stage2GroupsFor(round),
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
  if (round == 4) {
    return '빠른 적 첫 등장';
  }
  if (round == 5) {
    return '탱커 첫 등장';
  }
  if (round % 10 == 0) {
    return '보스 호위';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '기준 혼합';
  }
  if (cycleStep == 2) {
    return '빠른 적 러시';
  }
  if (cycleStep == 3) {
    return '겹침 압박';
  }
  if (cycleStep == 4) {
    return '탱커 돌파';
  }
  if (cycleStep == 5) {
    return '고밀도 압축';
  }
  return '일반 적 중심';
}

String _stage2PreviewTextFor(int round) {
  if (round == 2) {
    return '장갑병 첫 등장';
  }
  if (round == 3) {
    return '장갑 대열';
  }
  if (round == 4) {
    return '빠른 적 재압박';
  }
  if (round == 5) {
    return '장갑병과 탱커';
  }
  if (round % 10 == 0) {
    return '장갑 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '장갑 혼합';
  }
  if (cycleStep == 2) {
    return '빠른 적 러시';
  }
  if (cycleStep == 3) {
    return '장갑 대열';
  }
  if (cycleStep == 4) {
    return '분산 압박';
  }
  if (cycleStep == 5) {
    return '장갑 압축';
  }
  return '일반 적 중심';
}

List<SpawnGroup> _groupsFor(int round) {
  if (round <= 5) {
    return _learningGroupsFor(round);
  }

  final tier = _tierForRound(round);
  if (round % 10 == 0) {
    return _bossEscortGroups(tier);
  }

  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return _standardMixedGroups(tier);
  }
  if (cycleStep == 2) {
    return _rushGroups(tier);
  }
  if (cycleStep == 3) {
    return _overlapGroups(tier);
  }
  if (cycleStep == 4) {
    return _tankPressureGroups(tier);
  }
  return _compressedGroups(tier);
}

List<SpawnGroup> _stage2GroupsFor(int round) {
  if (round <= 5) {
    return _stage2LearningGroupsFor(round);
  }

  final tier = _tierForRound(round);
  if (round % 10 == 0) {
    return _stage2BossEscortGroups(tier);
  }

  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return _stage2StandardMixedGroups(tier);
  }
  if (cycleStep == 2) {
    return _stage2RushGroups(tier);
  }
  if (cycleStep == 3) {
    return _stage2ArmorLineGroups(tier);
  }
  if (cycleStep == 4) {
    return _stage2SplitPressureGroups(tier);
  }
  return _stage2CompressedGroups(tier);
}

List<SpawnGroup> _learningGroupsFor(int round) {
  if (round == 1) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 6, interval: 1.7),
    ];
  }
  if (round == 2) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 8, interval: 1.55),
    ];
  }
  if (round == 3) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 5, interval: 1.4),
      SpawnGroup(
        enemyType: EnemyType.normal,
        count: 4,
        interval: 1.35,
        startDelay: 3.2,
      ),
    ];
  }
  if (round == 4) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 7, interval: 1.4),
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 3,
        interval: 0.85,
        startDelay: 8.8,
      ),
    ];
  }
  return const [
    SpawnGroup(enemyType: EnemyType.tank, count: 1, interval: 1.7),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 8,
      interval: 1.25,
      startDelay: 1.6,
    ),
  ];
}

List<SpawnGroup> _stage2LearningGroupsFor(int round) {
  if (round == 1) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 6, interval: 1.7),
    ];
  }
  if (round == 2) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 5, interval: 1.55),
      SpawnGroup(
        enemyType: EnemyType.armored,
        count: 2,
        interval: 1.55,
        startAfterPrevious: true,
        followDelay: 0.8,
      ),
    ];
  }
  if (round == 3) {
    return const [
      SpawnGroup(enemyType: EnemyType.armored, count: 4, interval: 1.5),
      SpawnGroup(
        enemyType: EnemyType.normal,
        count: 4,
        interval: 1.35,
        startDelay: 5.6,
      ),
    ];
  }
  if (round == 4) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 6, interval: 1.4),
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 4,
        interval: 0.85,
        startDelay: 7.6,
      ),
    ];
  }
  return const [
    SpawnGroup(enemyType: EnemyType.armored, count: 3, interval: 1.45),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 6,
      interval: 1.25,
      startAfterPrevious: true,
      followDelay: 0.7,
    ),
    SpawnGroup(
      enemyType: EnemyType.tank,
      count: 1,
      interval: 1.7,
      startAfterPrevious: true,
      followDelay: 0.8,
    ),
  ];
}

List<SpawnGroup> _standardMixedGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 12 + tier,
    interval: _normalIntervalFor(tier),
  );
  return [
    normal,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 4 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: _nextGroupDelay(normal, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _stage2StandardMixedGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 8 + tier,
    interval: _normalIntervalFor(tier),
  );
  return [
    normal,
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 2 + (tier + 1) ~/ 2,
      interval: _armoredIntervalFor(tier),
      startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 3 + tier ~/ 3,
      interval: _fastIntervalFor(tier),
      startDelay: _nextGroupDelay(normal, gap: _standardGroupGap + 2.0),
    ),
  ];
}

List<SpawnGroup> _rushGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 6 + tier,
    interval: 1.25,
  );
  final firstRush = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 5 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
  );
  return [
    normal,
    firstRush,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 5 + (tier + 1) ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: _nextGroupDelay(firstRush, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _stage2RushGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 5 + tier,
    interval: 1.25,
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 7 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
  );
  return [
    normal,
    fast,
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 1 + tier ~/ 3,
      interval: _armoredIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _overlapGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 9 + tier,
    interval: _normalIntervalFor(tier),
  );
  final groups = [
    normal,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 4 + tier,
      interval: _fastIntervalFor(tier),
      startDelay: 2.2,
    ),
  ];
  if (tier >= 2) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 4,
        interval: 1.55,
        startDelay: 5.4,
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _stage2ArmorLineGroups(int tier) {
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 4 + tier,
    interval: _armoredIntervalFor(tier),
  );
  return [
    armored,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 6 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: _nextGroupDelay(armored, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 3 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 2.4,
    ),
  ];
}

List<SpawnGroup> _tankPressureGroups(int tier) {
  final tank = SpawnGroup(
    enemyType: EnemyType.tank,
    count: 2 + tier ~/ 2,
    interval: 1.55,
  );
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 10 + tier,
    interval: 1.16,
    startDelay: _nextGroupDelay(tank, gap: _tightGroupGap),
  );
  return [
    tank,
    normal,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 3 + tier ~/ 3,
      interval: _fastIntervalFor(tier),
      startDelay: _nextGroupDelay(normal, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _stage2SplitPressureGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 8 + tier,
    interval: 1.12,
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 3 + (tier + 1) ~/ 2,
    interval: _armoredIntervalFor(tier),
    startDelay: 1.8,
  );
  return [
    normal,
    armored,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 4 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: _nextGroupDelay(armored, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _compressedGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 8 + tier,
    interval: 1.08,
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 6 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
  );
  return [
    normal,
    fast,
    SpawnGroup(
      enemyType: EnemyType.tank,
      count: 2 + (tier + 1) ~/ 3,
      interval: 1.5,
      startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
    ),
  ];
}

List<SpawnGroup> _stage2CompressedGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 6 + tier,
    interval: 1.08,
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 5 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 3 + (tier + 1) ~/ 2,
    interval: _armoredIntervalFor(tier),
    startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
  );
  final groups = [normal, fast, armored];
  if (tier >= 3) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 5,
        interval: 1.55,
        startDelay: _nextGroupDelay(armored, gap: _tightGroupGap),
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _bossEscortGroups(int tier) {
  final tank = SpawnGroup(
    enemyType: EnemyType.tank,
    count: 2 + tier ~/ 3,
    interval: 1.55,
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 5 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(tank, gap: _tightGroupGap),
  );
  final boss = SpawnGroup(
    enemyType: EnemyType.boss,
    count: 1,
    interval: 2.0,
    startDelay: _nextGroupDelay(fast, gap: 1.2),
  );
  return [
    tank,
    fast,
    boss,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 4 + tier ~/ 2,
      interval: 1.0,
      startDelay: boss.startDelay + 0.9,
    ),
  ];
}

List<SpawnGroup> _stage2BossEscortGroups(int tier) {
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 2 + tier ~/ 2,
    interval: _armoredIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 4 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(armored, gap: _tightGroupGap),
  );
  final boss = SpawnGroup(
    enemyType: EnemyType.boss,
    count: 1,
    interval: 2.0,
    startDelay: _nextGroupDelay(fast, gap: 1.2),
  );
  final groups = [
    armored,
    fast,
    boss,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 4 + tier ~/ 2,
      interval: 1.0,
      startDelay: boss.startDelay + 0.9,
    ),
  ];
  if (tier >= 6) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1,
        interval: 1.6,
        startDelay: boss.startDelay + 2.2,
      ),
    );
  }
  return groups;
}

int _tierForRound(int round) {
  if (round <= 5) {
    return 0;
  }
  return (round - 6) ~/ 5;
}

int _cycleStepFor(int round) {
  if (round <= 5) {
    return round;
  }
  return (round - 6) % 5 + 1;
}

double _normalIntervalFor(int tier) {
  return 1.24 - tier * 0.02;
}

double _fastIntervalFor(int tier) {
  return 0.82 - tier * 0.015;
}

double _armoredIntervalFor(int tier) {
  return 1.38 - tier * 0.02;
}

double _nextGroupDelay(SpawnGroup previous, {required double gap}) {
  final lastSpawnIndex = previous.count > 0 ? previous.count - 1 : 0;
  return previous.startDelay + previous.interval * lastSpawnIndex + gap;
}
