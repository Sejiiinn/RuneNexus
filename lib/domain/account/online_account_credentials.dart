import 'package:flutter/foundation.dart';

@immutable
class OnlineAccountCredentials {
  const OnlineAccountCredentials({
    required this.accountId,
    required this.accessToken,
    required this.accessExpiresAt,
  });

  final String accountId;
  final String accessToken;
  final DateTime accessExpiresAt;
}
