import 'backup_save_repository.dart';
import 'game_save_data.dart';
import 'local_save_slot.dart';
import 'online_save_api.dart';
import 'online_save_outbox.dart';
import 'online_save_outbox_repository.dart';

typedef LocalSaveRepositoryFactory =
    BackupSaveRepository Function(LocalSaveSlot slot);
typedef OnlineSaveOutboxRepositoryFactory =
    OnlineSaveOutboxRepository Function(LocalSaveSlot slot);

enum AccountSaveBootstrapSource {
  existingOutbox,
  remoteAccount,
  guestProgress,
  localAccountRecovery,
  newAccount,
}

class AccountSaveBootstrapResult {
  const AccountSaveBootstrapResult({
    required this.accountId,
    required this.source,
    required this.remoteRevision,
  });

  final String accountId;
  final AccountSaveBootstrapSource source;
  final int remoteRevision;

  LocalSaveSlot get activeSlot => LocalSaveSlot.account(accountId);
}

class AccountSaveBootstrapException implements Exception {
  const AccountSaveBootstrapException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AccountSaveBootstrapException($code): $message';
}

class AccountSaveBootstrapService {
  const AccountSaveBootstrapService({
    required this.repositoryFactory,
    required this.outboxRepositoryFactory,
  });

  final LocalSaveRepositoryFactory repositoryFactory;
  final OnlineSaveOutboxRepositoryFactory outboxRepositoryFactory;

  Future<AccountSaveBootstrapResult> bootstrap({
    required String accountId,
    required Future<OnlineSaveSnapshot?> Function() loadRemote,
  }) async {
    final accountSlot = LocalSaveSlot.account(accountId);
    final normalizedAccountId = accountSlot.accountId!;
    final outboxRepository = outboxRepositoryFactory(accountSlot);
    final existingOutbox = await outboxRepository.load();

    // 영속 요청이 있으면 원격 조회나 로컬 교체보다 coordinator 복구를 우선한다.
    if (existingOutbox != null) {
      if (existingOutbox.accountIdBinding != normalizedAccountId) {
        throw const AccountSaveBootstrapException(
          'ACCOUNT_OUTBOX_MISMATCH',
          '온라인 저장 작업과 인증 계정이 일치하지 않습니다.',
        );
      }
      final accountLocal = await repositoryFactory(accountSlot).load();
      final resumesUnstartedAccount =
          accountLocal == null &&
          existingOutbox.remoteRevision == 0 &&
          existingOutbox.lastSyncedPayloadFingerprint == null &&
          !existingOutbox.requiresResolutionBeforeRebase;
      return AccountSaveBootstrapResult(
        accountId: normalizedAccountId,
        source: resumesUnstartedAccount
            ? AccountSaveBootstrapSource.newAccount
            : AccountSaveBootstrapSource.existingOutbox,
        remoteRevision: existingOutbox.remoteRevision,
      );
    }

    final remote = await loadRemote();
    final guestRepository = repositoryFactory(LocalSaveSlot.guest);
    final accountRepository = repositoryFactory(accountSlot);
    final guest = await guestRepository.load();
    final accountLocal = await accountRepository.load();

    if (remote != null) {
      await _preserveExisting(
        guestRepository: guestRepository,
        guest: guest,
        accountRepository: accountRepository,
        accountLocal: accountLocal,
      );
      await accountRepository.save(remote.data);
      await outboxRepository.save(
        OnlineSaveOutboxState.initial(
          accountId: normalizedAccountId,
          remoteRevision: remote.revision,
        ).copyWith(
          lastSyncedPayloadFingerprint: onlineSavePayloadHash(remote.data),
          lastSyncedAt: remote.serverSavedAt,
        ),
      );
      return AccountSaveBootstrapResult(
        accountId: normalizedAccountId,
        source: AccountSaveBootstrapSource.remoteAccount,
        remoteRevision: remote.revision,
      );
    }

    await _preserveExisting(
      guestRepository: guestRepository,
      guest: guest,
      accountRepository: accountRepository,
      accountLocal: accountLocal,
    );

    late final AccountSaveBootstrapSource source;
    if (guest != null) {
      await accountRepository.save(guest);
      source = AccountSaveBootstrapSource.guestProgress;
    } else if (accountLocal != null) {
      source = AccountSaveBootstrapSource.localAccountRecovery;
    } else {
      source = AccountSaveBootstrapSource.newAccount;
    }
    await outboxRepository.save(
      OnlineSaveOutboxState.initial(
        accountId: normalizedAccountId,
        remoteRevision: 0,
      ),
    );
    return AccountSaveBootstrapResult(
      accountId: normalizedAccountId,
      source: source,
      remoteRevision: 0,
    );
  }

  Future<void> _preserveExisting({
    required BackupSaveRepository guestRepository,
    required GameSaveData? guest,
    required BackupSaveRepository accountRepository,
    required GameSaveData? accountLocal,
  }) async {
    if (guest != null) {
      await guestRepository.preserveCurrentAsBackup();
    }
    if (accountLocal != null) {
      await accountRepository.preserveCurrentAsBackup();
    }
  }
}
