class MailboxItem {
  const MailboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.freeDiamonds,
    required this.moduleTickets,
    required this.startsAt,
    required this.expiresAt,
    this.readAt,
    this.claimedAt,
  });

  final String id;
  final String title;
  final String body;
  final int freeDiamonds;
  final int moduleTickets;
  final DateTime startsAt;
  final DateTime expiresAt;
  final DateTime? readAt;
  final DateTime? claimedAt;
  bool get isRead => readAt != null;
  bool get isClaimed => claimedAt != null;
}

class MailboxPage {
  const MailboxPage({
    required this.items,
    required this.serverTime,
    this.nextCursor,
  });
  final List<MailboxItem> items;
  final DateTime serverTime;
  final String? nextCursor;
}

class MailboxClaimResult {
  const MailboxClaimResult({
    required this.mailId,
    required this.claimed,
    this.code,
    this.message,
  });
  final String mailId;
  final bool claimed;
  final String? code;
  final String? message;
}

class MailboxBatchResult {
  const MailboxBatchResult({required this.results});
  final List<MailboxClaimResult> results;
}

class MailboxException implements Exception {
  const MailboxException({
    required this.message,
    required this.code,
    this.statusCode,
    this.transportFailure = false,
  });
  final String message;
  final String code;
  final int? statusCode;
  final bool transportFailure;
  bool get isUnauthorized => statusCode == 401;
  @override
  String toString() => message;
}
