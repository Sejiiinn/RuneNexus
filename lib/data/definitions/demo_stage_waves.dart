import '../../domain/enemy/enemy_type.dart';
import '../../domain/wave/wave_definition.dart';

final demoWaves = List<WaveDefinition>.unmodifiable(_buildDemoWaves());
final demoStage2Waves = List<WaveDefinition>.unmodifiable(
  _buildStage2ArmoredWaves(),
);
final demoChapter2Waves = List<WaveDefinition>.unmodifiable(
  _buildStage2Waves(),
);
final demoChapter2Stage7Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage7Waves(),
);
final demoChapter2Stage8Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage8Waves(),
);
final demoChapter2Stage9Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage9Waves(),
);
final demoChapter2Stage10Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage10Waves(),
);

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

List<WaveDefinition> _buildChapter2Stage7Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage7PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage7GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildChapter2Stage8Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage8PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage8GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildChapter2Stage9Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage9PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage9GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildChapter2Stage10Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage10PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage10GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildStage2ArmoredWaves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _stage2ArmoredPreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _stage2ArmoredGroupsFor(round),
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
    return '보호막병 첫 등장';
  }
  if (round == 3) {
    return '보호막 대열';
  }
  if (round == 4) {
    return '빠른 적 재압박';
  }
  if (round == 5) {
    return '보호막병과 탱커';
  }
  if (round % 10 == 0) {
    return '보호막 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '보호막 혼합';
  }
  if (cycleStep == 2) {
    return '빠른 적 러시';
  }
  if (cycleStep == 3) {
    return '균열 보호막';
  }
  if (cycleStep == 4) {
    return '분산 압박';
  }
  if (cycleStep == 5) {
    return '보호막 압축';
  }
  return '일반 적 중심';
}

String _chapter2Stage7PreviewTextFor(int round) {
  if (round == 2) {
    return '보호막 추격';
  }
  if (round == 3) {
    return '고속 균열';
  }
  if (round == 4) {
    return '빠른 적 돌입';
  }
  if (round == 5) {
    return '보호막 추격대';
  }
  if (round % 10 == 0) {
    return '고속 보호막 호위';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '기동 보호막';
  }
  if (cycleStep == 2) {
    return '고속 러시';
  }
  if (cycleStep == 3) {
    return '보호막 추격선';
  }
  if (cycleStep == 4) {
    return '분산 기동';
  }
  if (cycleStep == 5) {
    return '압축 돌파';
  }
  return '빠른 적 중심';
}

String _chapter2Stage8PreviewTextFor(int round) {
  if (round == 2) {
    return '보호막 장갑병';
  }
  if (round == 3) {
    return '내구 대열';
  }
  if (round == 4) {
    return '장갑 재압박';
  }
  if (round == 5) {
    return '보호막 탱커';
  }
  if (round % 10 == 0) {
    return '내구 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '내구 혼합';
  }
  if (cycleStep == 2) {
    return '장갑 돌파';
  }
  if (cycleStep == 3) {
    return '보호막 장벽';
  }
  if (cycleStep == 4) {
    return '탱커 압박';
  }
  if (cycleStep == 5) {
    return '내구 압축';
  }
  return '내구 적 중심';
}

String _chapter2Stage9PreviewTextFor(int round) {
  if (round == 2) {
    return '보호막 대열';
  }
  if (round == 3) {
    return '균열 장벽';
  }
  if (round == 4) {
    return '보호막 겹침';
  }
  if (round == 5) {
    return '보호막 압축';
  }
  if (round % 10 == 0) {
    return '장벽 호위 보스';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '보호막 밀집';
  }
  if (cycleStep == 2) {
    return '보호막 후속 러시';
  }
  if (cycleStep == 3) {
    return '균열 보호막선';
  }
  if (cycleStep == 4) {
    return '겹침 장벽';
  }
  if (cycleStep == 5) {
    return '고밀도 보호막';
  }
  return '보호막 중심';
}

String _chapter2Stage10PreviewTextFor(int round) {
  if (round == 2) {
    return '보스 호위 예열';
  }
  if (round == 3) {
    return '균열 정예';
  }
  if (round == 4) {
    return '정예 분산';
  }
  if (round == 5) {
    return '정예 압축';
  }
  if (round % 10 == 0) {
    return '균열 보스 호위';
  }
  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return '정예 혼합';
  }
  if (cycleStep == 2) {
    return '고속 정예';
  }
  if (cycleStep == 3) {
    return '정예 보호막선';
  }
  if (cycleStep == 4) {
    return '정예 분산 압박';
  }
  if (cycleStep == 5) {
    return '보스 호위 압축';
  }
  return '정예 적 중심';
}

String _stage2ArmoredPreviewTextFor(int round) {
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
    return _stage2ShieldLineGroups(tier);
  }
  if (cycleStep == 4) {
    return _stage2SplitPressureGroups(tier);
  }
  return _stage2CompressedGroups(tier);
}

List<SpawnGroup> _chapter2Stage7GroupsFor(int round) {
  if (round <= 5) {
    return _chapter2Stage7LearningGroupsFor(round);
  }

  final tier = _tierForRound(round);
  if (round % 10 == 0) {
    return _chapter2Stage7BossEscortGroups(tier);
  }

  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return _chapter2Stage7MobileMixedGroups(tier);
  }
  if (cycleStep == 2) {
    return _chapter2Stage7RushGroups(tier);
  }
  if (cycleStep == 3) {
    return _chapter2Stage7PursuitLineGroups(tier);
  }
  if (cycleStep == 4) {
    return _chapter2Stage7SplitPressureGroups(tier);
  }
  return _chapter2Stage7CompressedGroups(tier);
}

List<SpawnGroup> _chapter2Stage8GroupsFor(int round) {
  if (round <= 5) {
    return _chapter2Stage8LearningGroupsFor(round);
  }

  final tier = _tierForRound(round);
  if (round % 10 == 0) {
    return _chapter2Stage8BossEscortGroups(tier);
  }

  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return _chapter2Stage8DurableMixedGroups(tier);
  }
  if (cycleStep == 2) {
    return _chapter2Stage8ArmoredPushGroups(tier);
  }
  if (cycleStep == 3) {
    return _chapter2Stage8BarrierGroups(tier);
  }
  if (cycleStep == 4) {
    return _chapter2Stage8TankPressureGroups(tier);
  }
  return _chapter2Stage8CompressedGroups(tier);
}

List<SpawnGroup> _chapter2Stage9GroupsFor(int round) {
  if (round <= 5) {
    return _chapter2Stage9LearningGroupsFor(round);
  }

  final tier = _tierForRound(round);
  if (round % 10 == 0) {
    return _chapter2Stage9BossEscortGroups(tier);
  }

  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return _chapter2Stage9DenseMixedGroups(tier);
  }
  if (cycleStep == 2) {
    return _chapter2Stage9FollowupRushGroups(tier);
  }
  if (cycleStep == 3) {
    return _chapter2Stage9ShieldWallGroups(tier);
  }
  if (cycleStep == 4) {
    return _chapter2Stage9OverlapGroups(tier);
  }
  return _chapter2Stage9CompressedGroups(tier);
}

List<SpawnGroup> _chapter2Stage10GroupsFor(int round) {
  if (round <= 5) {
    return _chapter2Stage10LearningGroupsFor(round);
  }

  final tier = _tierForRound(round);
  if (round % 10 == 0) {
    return _chapter2Stage10BossEscortGroups(tier);
  }

  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return _chapter2Stage10EliteMixedGroups(tier);
  }
  if (cycleStep == 2) {
    return _chapter2Stage10EliteRushGroups(tier);
  }
  if (cycleStep == 3) {
    return _chapter2Stage10EliteShieldLineGroups(tier);
  }
  if (cycleStep == 4) {
    return _chapter2Stage10EliteSplitGroups(tier);
  }
  return _chapter2Stage10CompressedGroups(tier);
}

List<SpawnGroup> _stage2ArmoredGroupsFor(int round) {
  if (round <= 5) {
    return _stage2ArmoredLearningGroupsFor(round);
  }

  final tier = _tierForRound(round);
  if (round % 10 == 0) {
    return _stage2ArmoredBossEscortGroups(tier);
  }

  final cycleStep = _cycleStepFor(round);
  if (cycleStep == 1) {
    return _stage2ArmoredStandardMixedGroups(tier);
  }
  if (cycleStep == 2) {
    return _stage2ArmoredRushGroups(tier);
  }
  if (cycleStep == 3) {
    return _stage2ArmoredLineGroups(tier);
  }
  if (cycleStep == 4) {
    return _stage2ArmoredSplitPressureGroups(tier);
  }
  return _stage2ArmoredCompressedGroups(tier);
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
        enemyType: EnemyType.shielded,
        count: 2,
        interval: 1.55,
        startAfterPrevious: true,
        followDelay: 0.8,
      ),
    ];
  }
  if (round == 3) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 4, interval: 1.5),
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
    SpawnGroup(enemyType: EnemyType.shielded, count: 2, interval: 1.45),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 2,
      interval: 1.45,
      startAfterPrevious: true,
      followDelay: 0.6,
    ),
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

List<SpawnGroup> _chapter2Stage7LearningGroupsFor(int round) {
  if (round == 1) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 6, interval: 1.65),
    ];
  }
  if (round == 2) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 4, interval: 1.45),
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 3,
        interval: 0.85,
        startDelay: 3.4,
      ),
      SpawnGroup(
        enemyType: EnemyType.shielded,
        count: 2,
        interval: 1.45,
        startAfterPrevious: true,
        followDelay: 0.7,
      ),
    ];
  }
  if (round == 3) {
    return const [
      SpawnGroup(enemyType: EnemyType.fast, count: 5, interval: 0.85),
      SpawnGroup(
        enemyType: EnemyType.shielded,
        count: 3,
        interval: 1.42,
        startDelay: 2.2,
      ),
    ];
  }
  if (round == 4) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 5, interval: 1.25),
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 6,
        interval: 0.8,
        startDelay: 5.4,
      ),
    ];
  }
  return const [
    SpawnGroup(enemyType: EnemyType.shielded, count: 3, interval: 1.4),
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 6,
      interval: 0.82,
      startAfterPrevious: true,
      followDelay: 0.5,
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5,
      interval: 1.12,
      startAfterPrevious: true,
      followDelay: 0.5,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage8LearningGroupsFor(int round) {
  if (round == 1) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 6, interval: 1.7),
    ];
  }
  if (round == 2) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 2, interval: 1.5),
      SpawnGroup(
        enemyType: EnemyType.armored,
        count: 3,
        interval: 1.45,
        startAfterPrevious: true,
        followDelay: 0.6,
      ),
    ];
  }
  if (round == 3) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 4, interval: 1.45),
      SpawnGroup(
        enemyType: EnemyType.armored,
        count: 4,
        interval: 1.4,
        startDelay: 2.8,
      ),
    ];
  }
  if (round == 4) {
    return const [
      SpawnGroup(enemyType: EnemyType.armored, count: 5, interval: 1.35),
      SpawnGroup(
        enemyType: EnemyType.normal,
        count: 5,
        interval: 1.16,
        startAfterPrevious: true,
        followDelay: 0.6,
      ),
    ];
  }
  return const [
    SpawnGroup(enemyType: EnemyType.shielded, count: 3, interval: 1.42),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 5,
      interval: 1.36,
      startAfterPrevious: true,
      followDelay: 0.5,
    ),
    SpawnGroup(
      enemyType: EnemyType.tank,
      count: 1,
      interval: 1.65,
      startAfterPrevious: true,
      followDelay: 0.8,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage9LearningGroupsFor(int round) {
  if (round == 1) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 5, interval: 1.6),
      SpawnGroup(
        enemyType: EnemyType.shielded,
        count: 2,
        interval: 1.45,
        startAfterPrevious: true,
        followDelay: 0.5,
      ),
    ];
  }
  if (round == 2) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 5, interval: 1.42),
      SpawnGroup(
        enemyType: EnemyType.normal,
        count: 4,
        interval: 1.18,
        startDelay: 2.0,
      ),
    ];
  }
  if (round == 3) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 6, interval: 1.38),
      SpawnGroup(
        enemyType: EnemyType.armored,
        count: 2,
        interval: 1.36,
        startDelay: 3.0,
      ),
    ];
  }
  if (round == 4) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 4, interval: 1.36),
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 5,
        interval: 0.8,
        startDelay: 1.8,
      ),
    ];
  }
  return const [
    SpawnGroup(enemyType: EnemyType.shielded, count: 6, interval: 1.34),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 6,
      interval: 1.08,
      startAfterPrevious: true,
      followDelay: 0.35,
    ),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 3,
      interval: 1.32,
      startAfterPrevious: true,
      followDelay: 0.45,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage10LearningGroupsFor(int round) {
  if (round == 1) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 3, interval: 1.45),
      SpawnGroup(
        enemyType: EnemyType.normal,
        count: 5,
        interval: 1.1,
        startAfterPrevious: true,
        followDelay: 0.45,
      ),
    ];
  }
  if (round == 2) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 4, interval: 1.4),
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 5,
        interval: 0.78,
        startDelay: 2.0,
      ),
    ];
  }
  if (round == 3) {
    return const [
      SpawnGroup(enemyType: EnemyType.shielded, count: 5, interval: 1.34),
      SpawnGroup(
        enemyType: EnemyType.armored,
        count: 4,
        interval: 1.28,
        startDelay: 2.5,
      ),
    ];
  }
  if (round == 4) {
    return const [
      SpawnGroup(enemyType: EnemyType.normal, count: 6, interval: 1.05),
      SpawnGroup(
        enemyType: EnemyType.fast,
        count: 7,
        interval: 0.76,
        startDelay: 1.7,
      ),
      SpawnGroup(
        enemyType: EnemyType.shielded,
        count: 3,
        interval: 1.3,
        startDelay: 4.0,
      ),
    ];
  }
  return const [
    SpawnGroup(enemyType: EnemyType.shielded, count: 5, interval: 1.32),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 5,
      interval: 1.28,
      startAfterPrevious: true,
      followDelay: 0.35,
    ),
    SpawnGroup(
      enemyType: EnemyType.tank,
      count: 1,
      interval: 1.55,
      startAfterPrevious: true,
      followDelay: 0.6,
    ),
  ];
}

List<SpawnGroup> _stage2ArmoredLearningGroupsFor(int round) {
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
      enemyType: EnemyType.shielded,
      count: 2 + (tier + 1) ~/ 2,
      interval: _durableIntervalFor(tier),
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

List<SpawnGroup> _chapter2Stage7MobileMixedGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 6 + tier,
    interval: _normalIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 5 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
  );
  return [
    normal,
    fast,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 2 + (tier + 1) ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage8DurableMixedGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 3 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
  );
  return [
    shielded,
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 4 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 7 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage9DenseMixedGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 5 + tier,
    interval: _durableIntervalFor(tier),
  );
  return [
    shielded,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 6 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 3 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 1.8,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage10EliteMixedGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 4 + tier,
    interval: _durableIntervalFor(tier),
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 3 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
  );
  return [
    shielded,
    armored,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 4 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 2.2,
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 6 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: _nextGroupDelay(armored, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _stage2ArmoredStandardMixedGroups(int tier) {
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
      interval: _durableIntervalFor(tier),
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
      enemyType: EnemyType.shielded,
      count: 1 + tier ~/ 3,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage7RushGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 4 + tier,
    interval: 1.16,
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 9 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
  );
  return [
    normal,
    fast,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 2 + tier ~/ 3,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage8ArmoredPushGroups(int tier) {
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 5 + tier,
    interval: _durableIntervalFor(tier),
  );
  return [
    armored,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 2 + (tier + 1) ~/ 2,
      interval: _durableIntervalFor(tier),
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

List<SpawnGroup> _chapter2Stage9FollowupRushGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 4 + tier,
    interval: _durableIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 6 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
  );
  return [
    shielded,
    fast,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 2 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage10EliteRushGroups(int tier) {
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 8 + tier,
    interval: _fastIntervalFor(tier),
  );
  return [
    fast,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 4 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 3 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _stage2ArmoredRushGroups(int tier) {
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
      interval: _durableIntervalFor(tier),
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

List<SpawnGroup> _stage2ShieldLineGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 4 + tier,
    interval: _durableIntervalFor(tier),
  );
  return [
    shielded,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 6 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 1 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _standardGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 3 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 2.4,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage7PursuitLineGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 3 + tier,
    interval: _durableIntervalFor(tier),
  );
  return [
    shielded,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 6 + tier,
      interval: _fastIntervalFor(tier),
      startDelay: 1.4,
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage8BarrierGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 4 + tier,
    interval: _durableIntervalFor(tier),
  );
  return [
    shielded,
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 3 + tier,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.tank,
      count: 1 + tier ~/ 3,
      interval: 1.55,
      startDelay: _nextGroupDelay(shielded, gap: _standardGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: 2.0,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage9ShieldWallGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 7 + tier,
    interval: _durableIntervalFor(tier),
  );
  return [
    shielded,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 3 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: 2.6,
    ),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 2 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 3 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 1.7,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage10EliteShieldLineGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 6 + tier,
    interval: _durableIntervalFor(tier),
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 4 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
  );
  return [
    shielded,
    armored,
    SpawnGroup(
      enemyType: EnemyType.tank,
      count: 1 + tier ~/ 4,
      interval: 1.55,
      startDelay: _nextGroupDelay(armored, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 4 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 2.0,
    ),
  ];
}

List<SpawnGroup> _stage2ArmoredLineGroups(int tier) {
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 4 + tier,
    interval: _durableIntervalFor(tier),
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
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 3 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: 1.8,
  );
  return [
    normal,
    shielded,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 4 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage7SplitPressureGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 6 + tier,
    interval: 1.08,
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 6 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: 1.2,
  );
  return [
    normal,
    fast,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 3 + (tier + 1) ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage8TankPressureGroups(int tier) {
  final tank = SpawnGroup(
    enemyType: EnemyType.tank,
    count: 1 + tier ~/ 2,
    interval: 1.55,
  );
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 3 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(tank, gap: _tightGroupGap),
  );
  return [
    tank,
    shielded,
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 4 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + tier,
      interval: 1.08,
      startDelay: _nextGroupDelay(tank, gap: _standardGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage9OverlapGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 5 + tier,
    interval: _durableIntervalFor(tier),
  );
  return [
    shielded,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 5 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 1.4,
    ),
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 3 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: 3.2,
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + tier,
      interval: _normalIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
  ];
}

List<SpawnGroup> _chapter2Stage10EliteSplitGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 6 + tier,
    interval: 1.06,
  );
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 5 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: 1.4,
  );
  return [
    normal,
    shielded,
    SpawnGroup(
      enemyType: EnemyType.fast,
      count: 5 + tier ~/ 2,
      interval: _fastIntervalFor(tier),
      startDelay: 2.2,
    ),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 3 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
  ];
}

List<SpawnGroup> _stage2ArmoredSplitPressureGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 8 + tier,
    interval: 1.12,
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 3 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
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
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 3 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
  );
  final groups = [normal, fast, shielded];
  if (tier >= 3) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 5,
        interval: 1.55,
        startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _chapter2Stage7CompressedGroups(int tier) {
  final normal = SpawnGroup(
    enemyType: EnemyType.normal,
    count: 5 + tier,
    interval: 1.04,
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 7 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(normal, gap: _tightGroupGap),
  );
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 3 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
  );
  final groups = [normal, fast, shielded];
  if (tier >= 4) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 6,
        interval: 1.55,
        startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _chapter2Stage8CompressedGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 4 + (tier + 1) ~/ 2,
    interval: _durableIntervalFor(tier),
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 5 + tier,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
  );
  final groups = [
    shielded,
    armored,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + tier,
      interval: 1.08,
      startDelay: 1.8,
    ),
  ];
  if (tier >= 2) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 4,
        interval: 1.55,
        startDelay: _nextGroupDelay(armored, gap: _tightGroupGap),
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _chapter2Stage9CompressedGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 7 + tier,
    interval: _durableIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 5 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: 1.6,
  );
  final groups = [
    shielded,
    fast,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 4 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
    ),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 2 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
  ];
  if (tier >= 4) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 6,
        interval: 1.55,
        startDelay: _nextGroupDelay(shielded, gap: _standardGroupGap),
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _chapter2Stage10CompressedGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 6 + tier,
    interval: _durableIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 6 + tier,
    interval: _fastIntervalFor(tier),
    startDelay: 1.4,
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 4 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(fast, gap: _tightGroupGap),
  );
  final groups = [
    shielded,
    fast,
    armored,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + tier,
      interval: 1.04,
      startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
    ),
  ];
  if (tier >= 3) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 5,
        interval: 1.5,
        startDelay: _nextGroupDelay(armored, gap: _tightGroupGap),
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _stage2ArmoredCompressedGroups(int tier) {
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
    interval: _durableIntervalFor(tier),
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
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 2 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 4 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
  );
  final boss = SpawnGroup(
    enemyType: EnemyType.boss,
    count: 1,
    interval: 2.0,
    startDelay: _nextGroupDelay(fast, gap: 1.2),
  );
  final groups = [
    shielded,
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

List<SpawnGroup> _chapter2Stage7BossEscortGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 2 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 6 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
  );
  final boss = SpawnGroup(
    enemyType: EnemyType.boss,
    count: 1,
    interval: 2.0,
    startDelay: _nextGroupDelay(fast, gap: 1.0),
  );
  return [
    shielded,
    fast,
    boss,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 4 + tier ~/ 2,
      interval: 1.0,
      startDelay: boss.startDelay + 0.8,
    ),
  ];
}

List<SpawnGroup> _chapter2Stage8BossEscortGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 3 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
  );
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 3 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
    startDelay: _nextGroupDelay(shielded, gap: _tightGroupGap),
  );
  final boss = SpawnGroup(
    enemyType: EnemyType.boss,
    count: 1,
    interval: 2.0,
    startDelay: _nextGroupDelay(armored, gap: 1.0),
  );
  final groups = [
    shielded,
    armored,
    boss,
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 4 + tier ~/ 2,
      interval: 1.0,
      startDelay: boss.startDelay + 0.8,
    ),
  ];
  if (tier >= 4) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1,
        interval: 1.55,
        startDelay: boss.startDelay + 2.0,
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _chapter2Stage9BossEscortGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 5 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 4 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: 1.8,
  );
  final boss = SpawnGroup(
    enemyType: EnemyType.boss,
    count: 1,
    interval: 2.0,
    startDelay: _nextGroupDelay(shielded, gap: 1.0),
  );
  final groups = [
    shielded,
    fast,
    boss,
    SpawnGroup(
      enemyType: EnemyType.shielded,
      count: 2 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: boss.startDelay + 0.8,
    ),
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 2 + tier ~/ 3,
      interval: _durableIntervalFor(tier),
      startDelay: boss.startDelay + 1.6,
    ),
  ];
  if (tier >= 6) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1,
        interval: 1.55,
        startDelay: boss.startDelay + 2.6,
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _chapter2Stage10BossEscortGroups(int tier) {
  final shielded = SpawnGroup(
    enemyType: EnemyType.shielded,
    count: 5 + tier,
    interval: _durableIntervalFor(tier),
  );
  final fast = SpawnGroup(
    enemyType: EnemyType.fast,
    count: 5 + tier ~/ 2,
    interval: _fastIntervalFor(tier),
    startDelay: 1.6,
  );
  final boss = SpawnGroup(
    enemyType: EnemyType.boss,
    count: tier >= 6 ? 2 : 1,
    interval: 2.6,
    startDelay: _nextGroupDelay(shielded, gap: 1.0),
  );
  final groups = [
    shielded,
    fast,
    boss,
    SpawnGroup(
      enemyType: EnemyType.armored,
      count: 3 + tier ~/ 2,
      interval: _durableIntervalFor(tier),
      startDelay: boss.startDelay + 0.9,
    ),
    SpawnGroup(
      enemyType: EnemyType.normal,
      count: 5 + tier ~/ 2,
      interval: 1.0,
      startDelay: boss.startDelay + 1.5,
    ),
  ];
  if (tier >= 4) {
    groups.add(
      SpawnGroup(
        enemyType: EnemyType.tank,
        count: 1 + tier ~/ 5,
        interval: 1.55,
        startDelay: boss.startDelay + 2.4,
      ),
    );
  }
  return groups;
}

List<SpawnGroup> _stage2ArmoredBossEscortGroups(int tier) {
  final armored = SpawnGroup(
    enemyType: EnemyType.armored,
    count: 2 + tier ~/ 2,
    interval: _durableIntervalFor(tier),
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

double _durableIntervalFor(int tier) {
  return 1.38 - tier * 0.02;
}

double _nextGroupDelay(SpawnGroup previous, {required double gap}) {
  final lastSpawnIndex = previous.count > 0 ? previous.count - 1 : 0;
  return previous.startDelay + previous.interval * lastSpawnIndex + gap;
}
