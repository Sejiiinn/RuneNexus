class LocalSaveSlot {
  const LocalSaveSlot._(this.accountId);

  static const guest = LocalSaveSlot._(null);

  factory LocalSaveSlot.account(String accountId) {
    final normalized = accountId.toLowerCase();
    if (!_uuidPattern.hasMatch(normalized)) {
      throw ArgumentError.value(accountId, 'accountId', '유효한 UUID가 아닙니다.');
    }
    return LocalSaveSlot._(normalized);
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final String? accountId;

  bool get isGuest => accountId == null;
  String get namespace => isGuest ? 'guest' : 'account:$accountId';

  @override
  bool operator ==(Object other) {
    return other is LocalSaveSlot && other.accountId == accountId;
  }

  @override
  int get hashCode => accountId.hashCode;
}
