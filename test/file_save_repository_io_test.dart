import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/backup_save_repository.dart';
import 'package:rune_nexus/data/save/file_save_repository_io.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/local_save_slot.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'rune_nexus_save_test_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('legacy v1을 guest v2 primary로 이전하고 원본은 보존한다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    final backup = File('${temporaryDirectory.path}/save_v2.backup.json');
    final legacy = File('${temporaryDirectory.path}/rune_nexus_save_v1.json');
    await legacy.writeAsString(jsonEncode(_legacyJson(41)), flush: true);
    final repository = FileSaveRepository(
      file: primary,
      backupFile: backup,
      legacyFile: legacy,
    );

    final loaded = await repository.load();

    expect(loaded, isNotNull);
    expect(loaded!.progression.runes, 41);
    expect(await legacy.exists(), isTrue);
    expect(await primary.exists(), isTrue);
    final migratedJson = jsonDecode(await primary.readAsString());
    expect(GameSaveData.isCanonicalVersion2Envelope(migratedJson), isTrue);
  });

  test('미배포 canonical v2를 legacy v1 위치에서 마이그레이션하지 않는다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    final legacy = File('${temporaryDirectory.path}/rune_nexus_save_v1.json');
    await legacy.writeAsString(jsonEncode(_saveData(42).toJson()), flush: true);
    final repository = FileSaveRepository(file: primary, legacyFile: legacy);

    final loaded = await repository.load();

    expect(loaded, isNull);
    expect(await primary.exists(), isFalse);
    expect(await legacy.exists(), isTrue);
  });

  test('v2 primary 위치의 v1 데이터는 거부한다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    await primary.writeAsString(jsonEncode(_legacyJson(43)), flush: true);
    final repository = FileSaveRepository(file: primary);

    expect(await repository.load(), isNull);
  });

  test('손상된 primary 대신 직전 정상 backup을 복구한다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    final backup = File('${temporaryDirectory.path}/save_v2.backup.json');
    final repository = FileSaveRepository(file: primary, backupFile: backup);
    await repository.save(_saveData(10));
    await repository.save(_saveData(20));
    await primary.writeAsString('{broken', flush: true);

    final loaded = await repository.load();

    expect(loaded?.savedAtMillis, 10);
    expect(
      GameSaveData.fromJson(
        jsonDecode(await primary.readAsString()),
      )?.savedAtMillis,
      10,
    );
  });

  test('현재 primary를 명시적으로 backup에 보존한다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    final backup = File('${temporaryDirectory.path}/save_v2.backup.json');
    final repository = FileSaveRepository(file: primary, backupFile: backup);
    await repository.save(_saveData(25));

    await repository.preserveCurrentAsBackup();

    expect(
      GameSaveData.fromJson(
        jsonDecode(await backup.readAsString()),
      )?.savedAtMillis,
      25,
    );
  });

  test('충돌 백업은 일반 backup과 분리하고 같은 rebase를 중복 기록하지 않는다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    final backup = File('${temporaryDirectory.path}/save_v2.backup.json');
    final conflict = File('${temporaryDirectory.path}/save_v2.conflict.json');
    final repository = FileSaveRepository(
      file: primary,
      backupFile: backup,
      conflictBackupFile: conflict,
    );
    final local = _saveData(25);
    await repository.save(local);
    final conflictBackup = ConflictSaveBackup(
      rebaseId: 'rebase-1',
      accountId: '0198b955-3656-7c40-b3cb-87f427b90be2',
      baseRevision: 1,
      targetRevision: 2,
      localPayloadHash: 'hash-25',
      createdAt: DateTime.utc(2026, 8, 26),
      data: local,
    );

    await repository.preserveConflictBackup(conflictBackup);
    await repository.preserveConflictBackup(
      ConflictSaveBackup(
        rebaseId: 'rebase-1',
        accountId: conflictBackup.accountId,
        baseRevision: 1,
        targetRevision: 2,
        localPayloadHash: 'different',
        createdAt: DateTime.utc(2026, 8, 27),
        data: _saveData(99),
      ),
    );
    await repository.save(_saveData(30));

    final conflictJson =
        jsonDecode(await conflict.readAsString()) as Map<String, dynamic>;
    expect(conflictJson['rebaseId'], 'rebase-1');
    expect(GameSaveData.fromJson(conflictJson['data'])?.savedAtMillis, 25);
    expect(
      GameSaveData.fromJson(
        jsonDecode(await backup.readAsString()),
      )?.savedAtMillis,
      25,
    );
  });

  test('account UUID별 application support 경로를 분리한다', () async {
    const accountId = 'A0B1C2D3-E4F5-4678-9ABC-DEF012345678';
    final repository = FileSaveRepository(
      slot: LocalSaveSlot.account(accountId),
      applicationSupportDirectory: () async => temporaryDirectory,
    );

    await repository.save(_saveData(30));

    final primary = File(
      '${temporaryDirectory.path}/saves/accounts/'
      '${accountId.toLowerCase()}/save_v2.json',
    );
    expect(await primary.exists(), isTrue);
  });

  test('경로 조작에 사용할 수 있는 account ID를 거부한다', () {
    expect(() => LocalSaveSlot.account('../../guest'), throwsArgumentError);
  });

  test('clear 후 legacy 저장이 다시 살아나지 않는다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    final backup = File('${temporaryDirectory.path}/save_v2.backup.json');
    final legacy = File('${temporaryDirectory.path}/rune_nexus_save_v1.json');
    await legacy.writeAsString(jsonEncode(_legacyJson(7)), flush: true);
    final repository = FileSaveRepository(
      file: primary,
      backupFile: backup,
      legacyFile: legacy,
    );
    await repository.load();

    await repository.clear();

    expect(await repository.load(), isNull);
    expect(await primary.exists(), isFalse);
    expect(await backup.exists(), isFalse);
    expect(await legacy.exists(), isFalse);
  });

  test('교체 도중 남은 이전 primary를 다음 로드에서 복구한다', () async {
    final primary = File('${temporaryDirectory.path}/save_v2.json');
    final displaced = File('${primary.path}.replace');
    await displaced.writeAsString(
      jsonEncode(_saveData(50).toJson()),
      flush: true,
    );
    final repository = FileSaveRepository(file: primary);

    final loaded = await repository.load();

    expect(loaded?.savedAtMillis, 50);
    expect(await primary.exists(), isTrue);
    expect(await displaced.exists(), isFalse);
  });
}

GameSaveData _saveData(int savedAtMillis) {
  return GameSaveData.fromJson(<String, Object?>{
    'version': 2,
    'savedAtMillis': savedAtMillis,
    'preferences': const <String, Object?>{},
    'progression': const <String, Object?>{},
    'turretModules': const <String, Object?>{},
    'activeRun': null,
  })!;
}

Map<String, Object?> _legacyJson(int runes) {
  return <String, Object?>{
    'version': 1,
    'savedAtMillis': 1,
    'stageNumber': 1,
    'phase': 'preparation',
    'progression': <String, Object?>{'runes': runes},
    'runUpgradeLevels': const <String, Object?>{},
    'rewardOptions': const <Object?>[],
    'turrets': const <Object?>[],
    'enemies': const <Object?>[],
    'spawnQueue': const <Object?>[],
  };
}
