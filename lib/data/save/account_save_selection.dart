import 'backup_save_repository.dart';
import 'game_save_data.dart';
import 'local_save_slot.dart';
import 'online_save_api.dart';

typedef LocalSaveRepositoryFactory =
    BackupSaveRepository Function(LocalSaveSlot slot);

enum AccountSaveSelectionChoice {
  keepCurrentProgress,
  linkCurrentProgress,
  useAccountProgress,
  startNewAccount,
}

class AccountSaveSelectionState {
  AccountSaveSelectionState({
    required this.accountId,
    required this.currentProgress,
    required this.accountProgress,
    required this.remoteRevision,
  }) {
    LocalSaveSlot.account(accountId);
    if (remoteRevision < 0) {
      throw ArgumentError.value(
        remoteRevision,
        'remoteRevision',
        '0 이상이어야 합니다.',
      );
    }
  }

  final String accountId;
  final GameSaveData? currentProgress;
  final GameSaveData? accountProgress;
  final int remoteRevision;

  List<AccountSaveSelectionChoice> get availableChoices {
    return [
      if (currentProgress != null)
        AccountSaveSelectionChoice.linkCurrentProgress,
      if (accountProgress != null)
        AccountSaveSelectionChoice.useAccountProgress,
      if (accountProgress == null) AccountSaveSelectionChoice.startNewAccount,
      AccountSaveSelectionChoice.keepCurrentProgress,
    ];
  }
}

class AccountSaveSelectionResult {
  const AccountSaveSelectionResult({
    required this.choice,
    required this.activeSlot,
    required this.activeData,
    required this.remoteRevision,
  });

  final AccountSaveSelectionChoice choice;
  final LocalSaveSlot activeSlot;
  final GameSaveData? activeData;
  final int remoteRevision;

  bool get usesAccountSlot => !activeSlot.isGuest;
}

class AccountSaveSelectionException implements Exception {
  const AccountSaveSelectionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AccountSaveSelectionException($code): $message';
}

class AccountSaveSelectionService {
  const AccountSaveSelectionService({required this.repositoryFactory});

  final LocalSaveRepositoryFactory repositoryFactory;

  Future<AccountSaveSelectionState> inspect({
    required String accountId,
    required Future<OnlineSaveSnapshot?> Function() loadRemote,
  }) async {
    final accountSlot = LocalSaveSlot.account(accountId);
    final guestFuture = repositoryFactory(LocalSaveSlot.guest).load();
    final accountFuture = repositoryFactory(accountSlot).load();
    final remoteFuture = loadRemote();
    final guest = await guestFuture;
    final accountLocal = await accountFuture;
    final remote = await remoteFuture;
    return AccountSaveSelectionState(
      accountId: accountSlot.accountId!,
      currentProgress: guest,
      // 원격 데이터가 있으면 계정 진행의 기준이며, 로컬 account 저장은 캐시로 취급한다.
      accountProgress: remote?.data ?? accountLocal,
      remoteRevision: remote?.revision ?? 0,
    );
  }

  Future<AccountSaveSelectionResult> apply(
    AccountSaveSelectionState inspected,
    AccountSaveSelectionChoice choice,
  ) async {
    if (!inspected.availableChoices.contains(choice)) {
      throw const AccountSaveSelectionException(
        'SAVE_SELECTION_UNAVAILABLE',
        '현재 저장 상태에서 선택할 수 없는 진행 데이터입니다.',
      );
    }

    final accountSlot = LocalSaveSlot.account(inspected.accountId);
    final guestRepository = repositoryFactory(LocalSaveSlot.guest);
    final accountRepository = repositoryFactory(accountSlot);
    final guest = await guestRepository.load();
    final accountLocal = await accountRepository.load();

    if (guest != null) {
      await guestRepository.preserveCurrentAsBackup();
    }
    if (accountLocal != null) {
      await accountRepository.preserveCurrentAsBackup();
    }

    switch (choice) {
      case AccountSaveSelectionChoice.keepCurrentProgress:
        return AccountSaveSelectionResult(
          choice: choice,
          activeSlot: LocalSaveSlot.guest,
          activeData: guest,
          remoteRevision: inspected.remoteRevision,
        );
      case AccountSaveSelectionChoice.linkCurrentProgress:
        if (guest == null) {
          throw const AccountSaveSelectionException(
            'GUEST_SAVE_NOT_FOUND',
            '복사할 게스트 진행 데이터를 찾을 수 없습니다.',
          );
        }
        await accountRepository.save(guest);
        return AccountSaveSelectionResult(
          choice: choice,
          activeSlot: accountSlot,
          activeData: guest,
          remoteRevision: inspected.remoteRevision,
        );
      case AccountSaveSelectionChoice.useAccountProgress:
        final accountProgress = inspected.accountProgress;
        if (accountProgress == null) {
          throw const AccountSaveSelectionException(
            'ACCOUNT_SAVE_NOT_FOUND',
            '사용할 Google 계정 진행 데이터를 찾을 수 없습니다.',
          );
        }
        await accountRepository.save(accountProgress);
        return AccountSaveSelectionResult(
          choice: choice,
          activeSlot: accountSlot,
          activeData: accountProgress,
          remoteRevision: inspected.remoteRevision,
        );
      case AccountSaveSelectionChoice.startNewAccount:
        if (accountLocal != null || inspected.accountProgress != null) {
          throw const AccountSaveSelectionException(
            'SAVE_SELECTION_STALE',
            '저장 상태가 바뀌었습니다. 진행 데이터를 다시 확인해 주세요.',
          );
        }
        return AccountSaveSelectionResult(
          choice: choice,
          activeSlot: accountSlot,
          activeData: null,
          remoteRevision: 0,
        );
    }
  }
}
