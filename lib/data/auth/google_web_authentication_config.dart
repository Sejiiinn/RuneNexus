import 'package:flutter/foundation.dart';

import 'google_authentication_api.dart';

class GoogleWebAuthenticationConfig {
  const GoogleWebAuthenticationConfig({
    required this.clientId,
    required this.apiBaseUrl,
  });

  factory GoogleWebAuthenticationConfig.fromEnvironment() {
    return const GoogleWebAuthenticationConfig(
      clientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      apiBaseUrl: String.fromEnvironment('RUNE_NEXUS_API_BASE_URL'),
    );
  }

  final String clientId;
  final String apiBaseUrl;

  bool get isConfigured =>
      kIsWeb &&
      clientId.trim().isNotEmpty &&
      GoogleAuthenticationApi.supportsBaseUrl(apiBaseUrl);
}
