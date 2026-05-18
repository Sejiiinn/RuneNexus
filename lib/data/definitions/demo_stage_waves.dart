import '../../domain/enemy/enemy_type.dart';
import '../../domain/wave/wave_definition.dart';

final demoWaves = List<WaveDefinition>.unmodifiable(_buildDemoWaves());
final demoStage2Waves = List<WaveDefinition>.unmodifiable(_buildStage2Waves());

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
