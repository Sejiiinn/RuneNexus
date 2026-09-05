import 'dart:convert';

import '../../domain/account/online_account_credentials.dart';
import 'authentication_transport_stub.dart'
    if (dart.library.html) 'authentication_transport_web.dart'
    if (dart.library.io) 'authentication_transport_io.dart';

enum AuthenticationMode { legacy, web, native }

class AuthenticationResult {
  const AuthenticationResult({
    required this.credentials,
    this.refreshToken,
    this.refreshExpiresAt,
  });
  final OnlineAccountCredentials credentials;
  final String? refreshToken;
  final DateTime? refreshExpiresAt;
}

class GoogleAuthenticationException implements Exception {
  const GoogleAuthenticationException({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
    this.retryAfter,
  });

  final String code;
  final String message;
  final String? requestId;
  final int? statusCode;
  final Duration? retryAfter;

  bool get endsSession => const {
    'REFRESH_TOKEN_INVALID',
    'REFRESH_TOKEN_REUSED',
    'REFRESH_RECOVERY_EXPIRED',
    'ACCOUNT_NOT_ACTIVE',
    'INVALID_AUTH_ACCOUNT',
  }.contains(code);

  @override
  String toString() => 'GoogleAuthenticationException($code): $message';
}

class GoogleAuthenticationApi {
  GoogleAuthenticationApi({
    required String baseUrl,
    AuthenticationClient? transport,
    this.mode = AuthenticationMode.legacy,
  }) : _baseUri = _apiBaseUri(baseUrl),
       _transport = transport ?? AuthenticationTransport();

  static final RegExp _accountIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final Uri _baseUri;
  final AuthenticationClient _transport;
  final AuthenticationMode mode;

  String get _endpoint => switch (mode) {
    AuthenticationMode.legacy => 'v1/auth',
    AuthenticationMode.web => 'v1/auth/web',
    AuthenticationMode.native => 'v1/auth/native',
  };

  static bool supportsBaseUrl(String baseUrl) {
    try {
      _apiBaseUri(baseUrl);
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<AuthenticationResult> authenticate(String idToken) async {
    return _requestCredentials(
      endpoint: _baseUri.resolve('$_endpoint/google'),
      body: jsonEncode({'idToken': idToken}),
      failureMessage: 'Google 로그인 요청에 실패했습니다.',
    );
  }

  Future<AuthenticationResult> refresh(
    String? refreshToken, {
    String? idempotencyKey,
  }) {
    return _requestCredentials(
      endpoint: _baseUri.resolve('$_endpoint/refresh'),
      body: jsonEncode(
        mode == AuthenticationMode.web ? {} : {'refreshToken': refreshToken},
      ),
      headers: {'Idempotency-Key': ?idempotencyKey},
      failureMessage: '인증 세션 갱신에 실패했습니다.',
    );
  }

  Future<void> logout(String? refreshToken, {String? accessToken}) async {
    final response = await _transport.postJSON(
      _baseUri.resolve('$_endpoint/logout'),
      body: jsonEncode(
        mode == AuthenticationMode.web ? {} : {'refreshToken': refreshToken},
      ),
      headers: accessToken == null
          ? const {}
          : {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 204) {
      return;
    }
    final decoded = _decodeObject(response.body);
    throw GoogleAuthenticationException(
      code: _stringValue(decoded, 'code') ?? 'AUTH_REQUEST_FAILED',
      message: _stringValue(decoded, 'message') ?? '로그아웃 요청에 실패했습니다.',
      requestId: _stringValue(decoded, 'requestId'),
      statusCode: response.statusCode,
    );
  }

  Future<AuthenticationResult> _requestCredentials({
    required Uri endpoint,
    required String body,
    required String failureMessage,
    Map<String, String> headers = const {},
  }) async {
    final response = await _transport.postJSON(
      endpoint,
      body: body,
      headers: headers,
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw GoogleAuthenticationException(
        code: _stringValue(decoded, 'code') ?? 'AUTH_REQUEST_FAILED',
        message: _stringValue(decoded, 'message') ?? failureMessage,
        requestId: _stringValue(decoded, 'requestId'),
        statusCode: response.statusCode,
        retryAfter: _retryAfter(response.headers['retry-after']),
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
        (mode != AuthenticationMode.web &&
            (refreshToken == null || refreshToken.isEmpty)) ||
        (mode == AuthenticationMode.web && refreshToken != null) ||
        accessExpiresAt == null ||
        (mode == AuthenticationMode.legacy && refreshExpiresAt == null) ||
        (decoded?['refreshExpiresAt'] != null && refreshExpiresAt == null) ||
        (refreshExpiresAt != null &&
            !refreshExpiresAt.isAfter(accessExpiresAt))) {
      throw const GoogleAuthenticationException(
        code: 'INVALID_AUTH_RESPONSE',
        message: '인증 서버 응답 형식이 올바르지 않습니다.',
      );
    }

    return AuthenticationResult(
      credentials: OnlineAccountCredentials(
        accountId: accountId,
        accessToken: accessToken,
        accessExpiresAt: accessExpiresAt.toUtc(),
      ),
      refreshToken: refreshToken,
      refreshExpiresAt: refreshExpiresAt?.toUtc(),
    );
  }

  static Uri _apiBaseUri(String baseUrl) {
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
    return Uri.parse('$normalized/');
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

  static Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }
}
