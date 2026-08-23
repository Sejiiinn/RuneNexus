import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/local_save_slot.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';
import 'package:rune_nexus/data/save/online_save_outbox.dart';
import 'package:rune_nexus/data/save/online_save_outbox_file_repository_io.dart';

void main() {
  test('Outbox 직렬화는 정확한 요청 본문과 계정 binding을 보존한다', () {
    final request = OnlineSaveUpdateRequest(
      expectedRevision: 7,
      idempotencyKey: _idempotencyKey,
      data: _saveData(100),
    );
    final state =
        OnlineSaveOutboxState.initial(
          accountId: _accountId,
          remoteRevision: 7,
        ).copyWith(
          payloadGeneration: 3,
          inFlight: OnlineSaveOutboxEntry(
            idempotencyKey: request.idempotencyKey,
            expectedRevision: request.expectedRevision,
            encodedRequestBody: request.encodedBody,
            payloadFingerprint: onlineSavePayloadFingerprint(_saveData(100)),
            payloadGeneration: 3,
          ),
          phase: OnlineSaveOutboxPhase.retryWaiting,
          retryCount: 2,
          nextRetryAt: DateTime.utc(2026, 8, 24, 4),
          issueCode: 'SAVE_NETWORK_ERROR',
        );

    final restored = OnlineSaveOutboxState.fromJson(
      jsonDecode(jsonEncode(state.toJson())),
    );

    expect(restored, isNotNull);
    expect(restored!.accountIdBinding, _accountId);
    expect(restored.inFlight?.encodedRequestBody, request.encodedBody);
    expect(restored.inFlight?.toRequest().idempotencyKey, _idempotencyKey);
    expect(restored.retryCount, 2);
    expect(restored.nextRetryAt, DateTime.utc(2026, 8, 24, 4));
  });

  test('본문이 변경된 영속 요청은 복구하지 않는다', () {
    final request = OnlineSaveUpdateRequest(
      expectedRevision: 7,
      idempotencyKey: _idempotencyKey,
      data: _saveData(100),
    );
    final entryJson = OnlineSaveOutboxEntry(
      idempotencyKey: request.idempotencyKey,
      expectedRevision: request.expectedRevision,
      encodedRequestBody: request.encodedBody,
      payloadFingerprint: onlineSavePayloadFingerprint(_saveData(100)),
      payloadGeneration: 1,
    ).toJson();
    entryJson['expectedRevision'] = 8;

    expect(OnlineSaveOutboxEntry.fromJson(entryJson), isNull);
  });

  test('payload fingerprint는 같은 저장에 안정적이고 변경을 구분한다', () {
    expect(
      onlineSavePayloadFingerprint(_saveData(100)),
      onlineSavePayloadFingerprint(_saveData(100)),
    );
    expect(
      onlineSavePayloadFingerprint(_saveData(100)),
      isNot(onlineSavePayloadFingerprint(_saveData(101))),
    );
  });

  group('IO Outbox 저장소', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'rune_nexus_outbox_test_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('계정별 application support 경로에 영속 저장한다', () async {
      final repository = FileOnlineSaveOutboxRepository(
        slot: LocalSaveSlot.account(_accountId),
        applicationSupportDirectory: () async => temporaryDirectory,
      );
      final state = OnlineSaveOutboxState.initial(
        accountId: _accountId,
        remoteRevision: 4,
      );

      await repository.save(state);

      final file = File(
        '${temporaryDirectory.path}/saves/accounts/$_accountId/outbox_v1.json',
      );
      expect(await file.exists(), isTrue);
      expect((await repository.load())?.remoteRevision, 4);
    });

    test('손상된 primary 대신 직전 정상 backup을 복구한다', () async {
      final primary = File('${temporaryDirectory.path}/outbox_v1.json');
      final backup = File('${temporaryDirectory.path}/outbox_v1.backup.json');
      final repository = FileOnlineSaveOutboxRepository(
        slot: LocalSaveSlot.account(_accountId),
        file: primary,
        backupFile: backup,
      );
      final first = OnlineSaveOutboxState.initial(
        accountId: _accountId,
        remoteRevision: 1,
      );
      final second = first.copyWith(remoteRevision: 2);
      await repository.save(first);
      await repository.save(second);
      await primary.writeAsString('{broken', flush: true);

      final restored = await repository.load();

      expect(restored?.remoteRevision, 1);
      expect(
        OnlineSaveOutboxState.fromJson(
          jsonDecode(await primary.readAsString()),
        )?.remoteRevision,
        1,
      );
    });

    test('다른 계정 상태를 같은 슬롯에 저장하지 않는다', () async {
      final repository = FileOnlineSaveOutboxRepository(
        slot: LocalSaveSlot.account(_accountId),
        file: File('${temporaryDirectory.path}/outbox_v1.json'),
      );
      final other = OnlineSaveOutboxState.initial(
        accountId: '0198b955-3656-7c40-b3cb-87f427b90be9',
        remoteRevision: 0,
      );

      await expectLater(repository.save(other), throwsStateError);
    });
  });
}

const _accountId = '0198b955-3656-7c40-b3cb-87f427b90be2';
const _idempotencyKey = '0198b955-3656-7c40-b3cb-87f427b90be3';

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
