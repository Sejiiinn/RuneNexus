import 'package:flutter/foundation.dart';

@immutable
class OnlineAccountCredentials {
  const OnlineAccountCredentials({
    required this.accountId,
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  final String accountId;
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
}
