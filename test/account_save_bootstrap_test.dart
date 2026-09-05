import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/account_save_bootstrap.dart';
import 'package:rune_nexus/data/save/backup_save_repository.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/local_save_slot.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';
import 'package:rune_nexus/data/save/online_save_outbox.dart';
import 'package:rune_nexus/data/save/online_save_outbox_repository.dart';

const _accountId = '0198b955-3656-7c40-b3cb-87f427b90be2';

void main() {
  for (final hasRemote in [false, true]) {
    test('세션 복원은 게스트를 열지 않고 계정만 복구한다 (remote=$hasRemote)', () async {
      final accountSlot = LocalSaveSlot.account(_accountId);
      final account = _saveData(20);
      final storage = _MemoryBootstrapStorage()
        ..slot(accountSlot).data = account;
      final remote = hasRemote ? _remoteSnapshot(30, revision: 7) : null;
      final service = AccountSaveBootstrapService(
        repositoryFactory: (slot) {
          expect(slot, accountSlot, reason: '자동 복원 중 게스트 저장소 접근 금지');
          return _MemoryBackupSaveRepository(storage.slot(slot));
        },
        outboxRepositoryFactory: storage.outbox,
      );

      final result = await service.bootstrap(
        accountId: _accountId,
        mode: AccountSaveBootstrapMode.sessionRestore,
        loadRemote: () async => remote,
      );

      expect(
        result.source,
        hasRemote
            ? AccountSaveBootstrapSource.remoteAccount
            : AccountSaveBootstrapSource.localAccountRecovery,
      );
      expect(storage.slot(accountSlot).data, same(remote?.data ?? account));
      expect(storage.slot(accountSlot).backup, same(account));
    });
  }

  test('계정 저장이 없는 세션 복원은 기존 게스트 진행을 이전하지 않는다', () async {
    final guest = _saveData(10);
    final storage = _MemoryBootstrapStorage()
      ..slot(LocalSaveSlot.guest).data = guest;
    final result = await storage.service().bootstrap(
      accountId: _accountId,
      mode: AccountSaveBootstrapMode.sessionRestore,
      loadRemote: () async => null,
    );

    expect(result.source, AccountSaveBootstrapSource.newAccount);
    expect(storage.slot(LocalSaveSlot.account(_accountId)).data, isNull);
    expect(storage.slot(LocalSaveSlot.guest).data, same(guest));
    expect(storage.slot(LocalSaveSlot.guest).backup, isNull);
  });

  test('원격 계정 진행이 있으면 자동 적용하고 로컬 원본을 백업한다', () async {
    final guest = _saveData(10);
    final account = _saveData(20);
    final remote = _remoteSnapshot(30, revision: 7);
    final storage = _MemoryBootstrapStorage()
      ..slot(LocalSaveSlot.guest).data = guest
      ..slot(LocalSaveSlot.account(_accountId)).data = account;
    final service = storage.service();

    final result = await service.bootstrap(
      accountId: _accountId,
      loadRemote: () async => remote,
    );

    expect(result.source, AccountSaveBootstrapSource.remoteAccount);
    expect(result.remoteRevision, 7);
    expect(storage.slot(LocalSaveSlot.guest).data, same(guest));
    expect(storage.slot(LocalSaveSlot.guest).backup, same(guest));
    expect(
      storage.slot(LocalSaveSlot.account(_accountId)).backup,
      same(account),
    );
    expect(
      storage.slot(LocalSaveSlot.account(_accountId)).data,
      same(remote.data),
    );
    final outbox = storage.outbox(LocalSaveSlot.account(_accountId)).state;
    expect(outbox?.remoteRevision, 7);
    expect(
      outbox?.lastSyncedPayloadFingerprint,
      onlineSavePayloadHash(remote.data),
    );
    expect(outbox?.lastSyncedAt, remote.serverSavedAt);
  });

  test('원격 진행이 없으면 게스트 진행을 최초 계정 진행으로 자동 이전한다', () async {
    final guest = _saveData(10);
    final account = _saveData(20);
    final storage = _MemoryBootstrapStorage()
      ..slot(LocalSaveSlot.guest).data = guest
      ..slot(LocalSaveSlot.account(_accountId)).data = account;

    final result = await storage.service().bootstrap(
      accountId: _accountId,
      loadRemote: () async => null,
    );

    expect(result.source, AccountSaveBootstrapSource.guestProgress);
    expect(storage.slot(LocalSaveSlot.guest).data, same(guest));
    expect(storage.slot(LocalSaveSlot.guest).backup, same(guest));
    expect(
      storage.slot(LocalSaveSlot.account(_accountId)).backup,
      same(account),
    );
    expect(storage.slot(LocalSaveSlot.account(_accountId)).data, same(guest));
    final outbox = storage.outbox(LocalSaveSlot.account(_accountId)).state;
    expect(outbox?.remoteRevision, 0);
    expect(outbox?.lastSyncedPayloadFingerprint, isNull);
  });

  test('기존 Outbox가 있으면 원격 조회와 로컬 교체 전에 그대로 복구한다', () async {
    final accountSlot = LocalSaveSlot.account(_accountId);
    final account = _saveData(20);
    final existingOutbox = OnlineSaveOutboxState.initial(
      accountId: _accountId,
      remoteRevision: 5,
    ).copyWith(dirty: true, payloadGeneration: 2);
    final storage = _MemoryBootstrapStorage()
      ..slot(accountSlot).data = account
      ..outbox(accountSlot).state = existingOutbox;
    var remoteLoadCount = 0;

    final result = await storage.service().bootstrap(
      accountId: _accountId,
      loadRemote: () async {
        remoteLoadCount += 1;
        return _remoteSnapshot(30, revision: 6);
      },
    );

    expect(result.source, AccountSaveBootstrapSource.existingOutbox);
    expect(result.remoteRevision, 5);
    expect(remoteLoadCount, 0);
    expect(storage.slot(accountSlot).data, same(account));
    expect(storage.slot(accountSlot).backup, isNull);
    expect(storage.outbox(accountSlot).state, same(existingOutbox));
  });

  test('원격 조회 실패 시 guest와 account 저장을 변경하지 않는다', () async {
    final guest = _saveData(10);
    final account = _saveData(20);
    final accountSlot = LocalSaveSlot.account(_accountId);
    final storage = _MemoryBootstrapStorage()
      ..slot(LocalSaveSlot.guest).data = guest
      ..slot(accountSlot).data = account;

    await expectLater(
      storage.service().bootstrap(
        accountId: _accountId,
        loadRemote: () => Future.error(StateError('offline')),
      ),
      throwsStateError,
    );

    expect(storage.slot(LocalSaveSlot.guest).data, same(guest));
    expect(storage.slot(LocalSaveSlot.guest).backup, isNull);
    expect(storage.slot(accountSlot).data, same(account));
    expect(storage.slot(accountSlot).backup, isNull);
    expect(storage.outbox(accountSlot).state, isNull);
  });

  test('저장이 전혀 없으면 새 계정 진행을 준비한다', () async {
    final storage = _MemoryBootstrapStorage();

    final result = await storage.service().bootstrap(
      accountId: _accountId,
      loadRemote: () async => null,
    );

    expect(result.source, AccountSaveBootstrapSource.newAccount);
    expect(result.activeSlot, LocalSaveSlot.account(_accountId));
    expect(
      storage.outbox(LocalSaveSlot.account(_accountId)).state?.remoteRevision,
      0,
    );
  });

  test('초기 Outbox 생성 뒤 중단된 새 계정 연결을 새 진행으로 재개한다', () async {
    final accountSlot = LocalSaveSlot.account(_accountId);
    final storage = _MemoryBootstrapStorage()
      ..outbox(accountSlot).state = OnlineSaveOutboxState.initial(
        accountId: _accountId,
        remoteRevision: 0,
      );
    var remoteLoadCount = 0;

    final result = await storage.service().bootstrap(
      accountId: _accountId,
      loadRemote: () async {
        remoteLoadCount += 1;
        return null;
      },
    );

    expect(result.source, AccountSaveBootstrapSource.newAccount);
    expect(remoteLoadCount, 0);
  });

  test('원격과 게스트가 없으면 남아 있는 account 캐시를 복구한다', () async {
    final accountSlot = LocalSaveSlot.account(_accountId);
    final account = _saveData(20);
    final storage = _MemoryBootstrapStorage()..slot(accountSlot).data = account;

    final result = await storage.service().bootstrap(
      accountId: _accountId,
      loadRemote: () async => null,
    );

    expect(result.source, AccountSaveBootstrapSource.localAccountRecovery);
    expect(storage.slot(accountSlot).data, same(account));
    expect(storage.slot(accountSlot).backup, same(account));
  });
}

class _MemoryBootstrapStorage {
  final Map<String, _MemorySlot> _slots = {};
  final Map<String, MemoryOnlineSaveOutboxRepository> _outboxes = {};

  _MemorySlot slot(LocalSaveSlot slot) {
    return _slots.putIfAbsent(slot.namespace, _MemorySlot.new);
  }

  MemoryOnlineSaveOutboxRepository outbox(LocalSaveSlot slot) {
    return _outboxes.putIfAbsent(
      slot.namespace,
      MemoryOnlineSaveOutboxRepository.new,
    );
  }

  AccountSaveBootstrapService service() {
    return AccountSaveBootstrapService(
      repositoryFactory: (slot) => _MemoryBackupSaveRepository(this.slot(slot)),
      outboxRepositoryFactory: outbox,
    );
  }
}

class _MemorySlot {
  GameSaveData? data;
  GameSaveData? backup;
}

class _MemoryBackupSaveRepository implements BackupSaveRepository {
  const _MemoryBackupSaveRepository(this.slot);

  final _MemorySlot slot;

  @override
  Future<GameSaveData?> load() async => slot.data;

  @override
  Future<void> save(GameSaveData data) async {
    slot.backup = slot.data;
    slot.data = data;
  }

  @override
  Future<void> preserveCurrentAsBackup() async {
    slot.backup = slot.data;
  }

  @override
  Future<void> preserveConflictBackup(ConflictSaveBackup backup) async {
    slot.backup = backup.data;
  }

  @override
  Future<void> clear() async {
    slot.data = null;
    slot.backup = null;
  }
}

OnlineSaveSnapshot _remoteSnapshot(int savedAtMillis, {required int revision}) {
  return OnlineSaveSnapshot(
    revision: revision,
    serverSavedAt: DateTime.utc(2026, 8, 24),
    data: _saveData(savedAtMillis),
  );
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
