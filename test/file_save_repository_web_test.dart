@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/file_save_repository_web.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';

const _legacyKey = 'rune_nexus_save_v1';
const _primaryKey = 'rune_nexus:save:v2:guest:primary';
const _backupKey = 'rune_nexus:save:v2:guest:backup';

void main() {
  setUp(_clearTestKeys);
  tearDown(_clearTestKeys);

  test('Web legacy key를 guest v2 key로 이전하고 원본은 보존한다', () async {
    html.window.localStorage[_legacyKey] = jsonEncode(_legacyJson(17));
    final repository = FileSaveRepository();

    final loaded = await repository.load();

    expect(loaded?.progression.runes, 17);
    expect(html.window.localStorage[_legacyKey], isNotNull);
    final migrated = jsonDecode(html.window.localStorage[_primaryKey]!);
    expect(GameSaveData.isCanonicalVersion2Envelope(migrated), isTrue);
  });

  test('Web legacy key에 기록된 canonical v2도 신규 key로 옮긴다', () async {
    html.window.localStorage[_legacyKey] = jsonEncode(_saveData(18).toJson());
    final repository = FileSaveRepository();

    final loaded = await repository.load();

    expect(loaded?.savedAtMillis, 18);
    expect(html.window.localStorage[_legacyKey], isNotNull);
    expect(html.window.localStorage[_primaryKey], isNotNull);
  });

  test('Web primary 손상 시 직전 정상 backup을 복구한다', () async {
    final repository = FileSaveRepository();
    await repository.save(_saveData(10));
    await repository.save(_saveData(20));
    html.window.localStorage[_primaryKey] = '{broken';

    final loaded = await repository.load();

    expect(loaded?.savedAtMillis, 10);
    expect(
      GameSaveData.fromJson(
        jsonDecode(html.window.localStorage[_primaryKey]!),
      )?.savedAtMillis,
      10,
    );
  });

  test('Web current primary를 명시적으로 backup에 보존한다', () async {
    final repository = FileSaveRepository();
    await repository.save(_saveData(25));

    await repository.preserveCurrentAsBackup();

    expect(
      GameSaveData.fromJson(
        jsonDecode(html.window.localStorage[_backupKey]!),
      )?.savedAtMillis,
      25,
    );
  });
}

void _clearTestKeys() {
  html.window.localStorage.remove(_legacyKey);
  html.window.localStorage.remove(_primaryKey);
  html.window.localStorage.remove(_backupKey);
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
