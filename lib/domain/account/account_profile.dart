class AccountProfile {
  const AccountProfile({required this.accountId, this.nickname, this.tag});

  final String accountId;
  final String? nickname;
  final String? tag;

  bool get hasNickname => nickname != null && tag != null;
  String? get displayName => hasNickname ? '$nickname#$tag' : null;

  // 신규 설정 정책과 기존 프로필의 형식 검증 분리.
  static bool isValidNickname(String value) =>
      isValidNicknameFormat(value) &&
      !value.toLowerCase().contains('admin') &&
      !value.contains('운영자');

  static bool isValidNicknameFormat(String value) {
    final nickname = value.trim();
    if (!RegExp(r'^[가-힣A-Za-z0-9_]+$').hasMatch(nickname) ||
        nickname.length < 2) {
      return false;
    }
    return nicknameWeight(nickname) <= 16;
  }

  // 한글 완성형 2칸, ASCII 허용 문자 1칸.
  static int nicknameWeight(String value) => value.trim().runes.fold(
    0,
    (total, rune) => total + (rune >= 0xAC00 && rune <= 0xD7A3 ? 2 : 1),
  );
}
