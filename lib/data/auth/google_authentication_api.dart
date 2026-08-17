import 'dart:convert';

import '../../domain/account/online_account_credentials.dart';
import 'authentication_transport_stub.dart'
    if (dart.library.html) 'authentication_transport_web.dart';

class GoogleAuthenticationException implements Exception {
  const GoogleAuthenticationException({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
  });

  final String code;
  final String message;
  final String? requestId;
  final int? statusCode;

  @override
  String toString() => 'GoogleAuthenticationException($code): $message';
}

class GoogleAuthenticationApi {
  GoogleAuthenticationApi({
    required String baseUrl,
    AuthenticationTransport? transport,
  }) : _endpoint = _authenticationEndpoint(baseUrl),
       _transport = transport ?? AuthenticationTransport();

  static final RegExp _accountIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final Uri _endpoint;
  final AuthenticationTransport _transport;

  static bool supportsBaseUrl(String baseUrl) {
    try {
      _authenticationEndpoint(baseUrl);
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<OnlineAccountCredentials> authenticate(String idToken) async {
    final response = await _transport.postJSON(
      _endpoint,
      body: jsonEncode({'idToken': idToken}),
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw GoogleAuthenticationException(
        code: _stringValue(decoded, 'code') ?? 'AUTH_REQUEST_FAILED',
        message: _stringValue(decoded, 'message') ?? 'Google 로그인 요청에 실패했습니다.',
        requestId: _stringValue(decoded, 'requestId'),
        statusCode: response.statusCode,
      );
    }

    final account = decoded?['account'];
    final accountId = account is Map<String, dynamic>
        ? _stringValue(account, 'id')
        : null;
    final accessToken = _stringValue(decoded, 'accessToken');
    final refreshToken = _stringValue(decoded, 'refreshToken');
    final accessExpiresAt = DateTime.tryParse(
      _stringValue(decoded, 'accessExpiresAt') ?? '',
    );
    final refreshExpiresAt = DateTime.tryParse(
      _stringValue(decoded, 'refreshExpiresAt') ?? '',
    );
    if (accountId == null ||
        !_accountIdPattern.hasMatch(accountId) ||
        accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        accessExpiresAt == null ||
        refreshExpiresAt == null ||
        !refreshExpiresAt.isAfter(accessExpiresAt)) {
      throw const GoogleAuthenticationException(
        code: 'INVALID_AUTH_RESPONSE',
        message: '인증 서버 응답 형식이 올바르지 않습니다.',
      );
    }

    return OnlineAccountCredentials(
      accountId: accountId,
      accessToken: accessToken,
      accessExpiresAt: accessExpiresAt.toUtc(),
      refreshToken: refreshToken,
      refreshExpiresAt: refreshExpiresAt.toUtc(),
    );
  }

  static Uri _authenticationEndpoint(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !_supportedScheme(uri)) {
      throw const FormatException('유효한 인증 API 주소가 아닙니다.');
    }
    return Uri.parse('$normalized/v1/auth/google');
  }

  static bool _supportedScheme(Uri uri) {
    if (uri.scheme == 'https') {
      return true;
    }
    if (uri.scheme != 'http') {
      return false;
    }
    return uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';
  }

  static Map<String, dynamic>? _decodeObject(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String? _stringValue(Map<String, dynamic>? object, String key) {
    final value = object?[key];
    return value is String ? value : null;
  }
}
