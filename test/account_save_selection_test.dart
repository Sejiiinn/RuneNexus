import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/account_save_selection.dart';
import 'package:rune_nexus/data/save/backup_save_repository.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/local_save_slot.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';

const _accountId = '0198b955-3656-7c40-b3cb-87f427b90be2';

void main() {
  test('현재 기록과 단일 Google 계정 기록으로 조회한다', () async {
    final storage = _MemorySlotStorage()
      ..slot(LocalSaveSlot.guest).data = _saveData(10)
      ..slot(LocalSaveSlot.account(_accountId)).data = _saveData(20);
    final service = AccountSaveSelectionService(
      repositoryFactory: storage.repository,
    );

    final state = await service.inspect(
      accountId: _accountId,
      loadRemote: () async => _remoteSnapshot(30, revision: 7),
    );

    expect(state.currentProgress?.savedAtMillis, 10);
    expect(state.accountProgress?.savedAtMillis, 30);
    expect(state.remoteRevision, 7);
    expect(state.availableChoices, [
      AccountSaveSelectionChoice.linkCurrentProgress,
      AccountSaveSelectionChoice.useAccountProgress,
      AccountSaveSelectionChoice.keepCurrentProgress,
    ]);
  });

  test('원격 저장이 없으면 account 로컬 캐시를 계정 기록으로 사용한다', () async {
    final storage = _MemorySlotStorage()
      ..slot(LocalSaveSlot.account(_accountId)).data = _saveData(20);
    final service = AccountSaveSelectionService(
      repositoryFactory: storage.repository,
    );

    final state = await service.inspect(
      accountId: _accountId,
      loadRemote: () async => null,
    );

    expect(state.accountProgress?.savedAtMillis, 20);
    expect(state.remoteRevision, 0);
    expect(state.availableChoices, [
      AccountSaveSelectionChoice.useAccountProgress,
      AccountSaveSelectionChoice.keepCurrentProgress,
    ]);
  });

  test('게스트 진행 복사 전에 guest와 기존 account 원본을 백업한다', () async {
    final guest = _saveData(10);
    final account = _saveData(20);
    final storage = _MemorySlotStorage()
      ..slot(LocalSaveSlot.guest).data = guest
      ..slot(LocalSaveSlot.account(_accountId)).data = account;
    final service = AccountSaveSelectionService(
      repositoryFactory: storage.repository,
    );
    final state = await service.inspect(
      accountId: _accountId,
      loadRemote: () async => _remoteSnapshot(30, revision: 7),
    );

    final result = await service.apply(
      state,
      AccountSaveSelectionChoice.linkCurrentProgress,
    );

    expect(result.activeSlot, LocalSaveSlot.account(_accountId));
    expect(result.activeData?.savedAtMillis, 10);
    expect(result.remoteRevision, 7);
    expect(storage.slot(LocalSaveSlot.guest).backup, same(guest));
    expect(
      storage.slot(LocalSaveSlot.account(_accountId)).backup,
      same(account),
    );
    expect(storage.slot(LocalSaveSlot.account(_accountId)).data, same(guest));
  });

  test('Google 계정 기록 적용 전에 기존 account 로컬 캐시를 백업한다', () async {
    final account = _saveData(20);
    final remote = _remoteSnapshot(30, revision: 9);
    final storage = _MemorySlotStorage()
      ..slot(LocalSaveSlot.account(_accountId)).data = account;
    final service = AccountSaveSelectionService(
      repositoryFactory: storage.repository,
    );
    final state = await service.inspect(
      accountId: _accountId,
      loadRemote: () async => remote,
    );

    final result = await service.apply(
      state,
      AccountSaveSelectionChoice.useAccountProgress,
    );

    expect(result.remoteRevision, 9);
    expect(
      storage.slot(LocalSaveSlot.account(_accountId)).backup,
      same(account),
    );
    expect(
      storage.slot(LocalSaveSlot.account(_accountId)).data,
      same(remote.data),
    );
  });

  test('나중에 연동 선택은 account 저장을 바꾸지 않는다', () async {
    final guest = _saveData(10);
    final account = _saveData(20);
    final storage = _MemorySlotStorage()
      ..slot(LocalSaveSlot.guest).data = guest
      ..slot(LocalSaveSlot.account(_accountId)).data = account;
    final service = AccountSaveSelectionService(
      repositoryFactory: storage.repository,
    );
    final state = await service.inspect(
      accountId: _accountId,
      loadRemote: () async => _remoteSnapshot(30, revision: 7),
    );

    final result = await service.apply(
      state,
      AccountSaveSelectionChoice.keepCurrentProgress,
    );

    expect(result.activeSlot, LocalSaveSlot.guest);
    expect(storage.slot(LocalSaveSlot.guest).backup, same(guest));
    expect(storage.slot(LocalSaveSlot.account(_accountId)).data, same(account));
  });

  test('검사 뒤 account 저장이 생기면 새 진행 시작을 중단한다', () async {
    final storage = _MemorySlotStorage();
    final service = AccountSaveSelectionService(
      repositoryFactory: storage.repository,
    );
    final state = await service.inspect(
      accountId: _accountId,
      loadRemote: () async => null,
    );
    storage.slot(LocalSaveSlot.account(_accountId)).data = _saveData(40);

    await expectLater(
      service.apply(state, AccountSaveSelectionChoice.startNewAccount),
      throwsA(
        isA<AccountSaveSelectionException>().having(
          (error) => error.code,
          'code',
          'SAVE_SELECTION_STALE',
        ),
      ),
    );
  });
}

class _MemorySlotStorage {
  final Map<String, _MemorySlot> _slots = {};

  _MemorySlot slot(LocalSaveSlot slot) {
    return _slots.putIfAbsent(slot.namespace, _MemorySlot.new);
  }

  BackupSaveRepository repository(LocalSaveSlot slot) {
    return _MemoryBackupSaveRepository(this.slot(slot));
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
