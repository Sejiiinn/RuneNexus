import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/combat/auto_start_mode.dart';
import 'package:rune_nexus/domain/combat/game_phase.dart';
import 'package:rune_nexus/domain/gem/gem_type.dart';
import 'package:rune_nexus/domain/run_upgrade/run_upgrade_type.dart';

void main() {
  test('v1 평면 저장을 v2 저장 경계로 변환한다', () {
    final saved = GameSaveData.fromJson(<String, Object?>{
      'version': 1,
      'savedAtMillis': 1234,
      'gold': 275,
      'gemShards': 9,
      'nexusHp': 14.5,
      'stageNumber': 3,
      'mapSignature': 'legacy-map',
      'roundIndex': 2,
      'completedRounds': 2,
      'phase': 'wave',
      'autoStartMode': 'fullAuto',
      'progression': const <String, Object?>{
        'runes': 42,
        'unlockedStageCount': 3,
        'turretModuleTickets': 5,
        'turretModuleDrawCount': 7,
        'turretModuleTicketPurchaseCount': 2,
        'turretModuleItemSequence': 7,
      },
      'runUpgradeLevels': const <String, Object?>{'towerDamage': 2},
      'killGoldFractionWallet': 0.25,
      'gemInventory': const <String, Object?>{'range': 1},
      'rewardOptions': const <Object?>[],
      'isPurchasedGemReward': false,
      'turrets': const <Object?>[],
      'enemies': const <Object?>[],
      'spawnQueue': const <Object?>[],
    });

    expect(saved, isNotNull);
    expect(saved!.version, GameSaveData.currentVersion);
    expect(saved.savedAtMillis, 1234);
    expect(saved.preferences.selectedStageNumber, 3);
    expect(saved.preferences.autoStartMode, AutoStartMode.fullAuto);
    expect(saved.progression.runes, 42);
    expect(saved.progression.totalPlayTimeMillis, 0);
    expect(saved.turretModules.tickets, 5);
    expect(saved.turretModules.drawCount, 7);
    expect(saved.turretModules.ticketPurchaseCount, 2);
    expect(saved.activeRun, isNotNull);
    expect(saved.activeRun!.phase, GamePhase.wave);
    expect(saved.activeRun!.gold, 275);
    expect(saved.activeRun!.nexusHp, 14.5);
    expect(saved.activeRun!.runUpgradeLevels, {RunUpgradeType.towerDamage: 2});
    expect(saved.activeRun!.gemInventory, {GemType.range: 1});

    final migratedJson = saved.toJson();
    expect(migratedJson['version'], 2);
    expect(migratedJson, isNot(contains('gold')));
    expect(migratedJson['preferences'], isA<Map<String, Object?>>());
    expect(migratedJson['turretModules'], isA<Map<String, Object?>>());
    expect(migratedJson['activeRun'], isA<Map<String, Object?>>());
    expect(
      migratedJson['progression'] as Map<String, Object?>,
      isNot(contains('turretModuleTickets')),
    );
  });

  test('진행 중인 런이 없는 v1 저장은 선택 스테이지만 보존한다', () {
    final saved = GameSaveData.fromJson(<String, Object?>{
      'version': 1,
      'savedAtMillis': 10,
      'stageNumber': 4,
      'phase': 'preparation',
      'autoStartMode': 'pauseEachRound',
      'progression': const <String, Object?>{'unlockedStageCount': 4},
      'runUpgradeLevels': const <String, Object?>{},
      'rewardOptions': const <Object?>[],
      'turrets': const <Object?>[],
      'enemies': const <Object?>[],
      'spawnQueue': const <Object?>[],
    });

    expect(saved, isNotNull);
    expect(saved!.preferences.selectedStageNumber, 4);
    expect(saved.activeRun, isNull);
    expect(saved.toJson()['activeRun'], isNull);
  });

  test('지원하지 않는 저장 버전은 거부한다', () {
    expect(GameSaveData.fromJson(const {'version': 99}), isNull);
  });

  test('필수 영역이 빠진 손상된 v2 저장은 거부한다', () {
    expect(GameSaveData.fromJson(const {'version': 2}), isNull);
    expect(
      GameSaveData.fromJson(const <String, Object?>{
        'version': 2,
        'preferences': <String, Object?>{},
        'progression': <String, Object?>{},
        'turretModules': <String, Object?>{},
      }),
      isNull,
    );
    expect(
      GameSaveData.fromJson(const <String, Object?>{
        'version': 2,
        'preferences': <String, Object?>{},
        'progression': <String, Object?>{},
        'activeRun': null,
      }),
      isNull,
    );
    expect(
      GameSaveData.fromJson(const <String, Object?>{
        'version': 2,
        'preferences': <String, Object?>{},
        'progression': <String, Object?>{
          'turretModuleTickets': 3,
          'ownedTurretModules': <Object?>[],
        },
        'activeRun': null,
      }),
      isNull,
    );
  });

  test('모든 필수 영역이 있는 canonical v2 저장은 허용한다', () {
    final json = const <String, Object?>{
      'version': 2,
      'savedAtMillis': 30,
      'preferences': <String, Object?>{},
      'progression': <String, Object?>{},
      'turretModules': <String, Object?>{},
      'activeRun': null,
    };

    expect(GameSaveData.isCanonicalVersion2Envelope(json), isTrue);
    expect(GameSaveData.fromJson(json), isNotNull);
  });

  test('누적 플레이타임을 progression에 저장하고 음수는 보정한다', () {
    final saved = GameSaveData.fromJson(const <String, Object?>{
      'version': 2,
      'savedAtMillis': 40,
      'preferences': <String, Object?>{},
      'progression': <String, Object?>{'totalPlayTimeMillis': 3723000},
      'turretModules': <String, Object?>{},
      'activeRun': null,
    });

    expect(saved!.progression.totalPlayTimeMillis, 3723000);
    expect(
      saved.toJson()['progression'],
      isA<Map<String, Object?>>().having(
        (json) => json['totalPlayTimeMillis'],
        'totalPlayTimeMillis',
        3723000,
      ),
    );

    final sanitized = SavedProgression.fromJson(const <String, Object?>{
      'totalPlayTimeMillis': -1,
    });
    expect(sanitized.totalPlayTimeMillis, 0);
  });

  test('활성 런의 서버 정산 ID와 미확정 다이아를 보존한다', () {
    final saved = GameSaveData.fromJson(const <String, Object?>{
      'version': 2,
      'savedAtMillis': 50,
      'preferences': <String, Object?>{},
      'progression': <String, Object?>{},
      'turretModules': <String, Object?>{},
      'activeRun': <String, Object?>{
        'phase': 'wave',
        'stageNumber': 3,
        'economyRunId': '0198b955-3656-7c40-b3cb-87f427b90be3',
        'pendingEconomyDiamonds': 27,
      },
    });

    expect(saved!.activeRun!.economyRunId, isNotEmpty);
    expect(saved.activeRun!.pendingEconomyDiamonds, 27);
    expect(
      (saved.toJson()['activeRun']
          as Map<String, Object?>)['pendingEconomyDiamonds'],
      27,
    );
  });
}
