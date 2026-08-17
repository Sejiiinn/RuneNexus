import 'package:flutter/foundation.dart';

enum AccountIdentityProvider { playGames, google, apple }

enum OnlineSaveSyncStatus {
  unavailable,
  synchronized,
  syncing,
  offline,
  actionRequired,
}

@immutable
class AccountIdentity {
  const AccountIdentity({
    required this.provider,
    required this.displayName,
    this.detail,
  });

  final AccountIdentityProvider provider;
  final String displayName;
  final String? detail;
}

@immutable
class AccountSession {
  const AccountSession.guest()
    : accountId = null,
      identities = const [],
      syncStatus = OnlineSaveSyncStatus.unavailable,
      lastSyncedAt = null,
      pendingSaveCount = 0,
      issueMessage = null;

  AccountSession.authenticated({
    required String this.accountId,
    required List<AccountIdentity> identities,
    this.syncStatus = OnlineSaveSyncStatus.synchronized,
    this.lastSyncedAt,
    this.pendingSaveCount = 0,
    this.issueMessage,
  }) : assert(accountId.isNotEmpty),
       assert(identities.isNotEmpty),
       assert(syncStatus != OnlineSaveSyncStatus.unavailable),
       assert(pendingSaveCount >= 0),
       identities = List.unmodifiable(identities);

  final String? accountId;
  final List<AccountIdentity> identities;
  final OnlineSaveSyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final int pendingSaveCount;
  final String? issueMessage;

  bool get isGuest => accountId == null;

  AccountIdentity? identityFor(AccountIdentityProvider provider) {
    for (final identity in identities) {
      if (identity.provider == provider) {
        return identity;
      }
    }
    return null;
  }
}
