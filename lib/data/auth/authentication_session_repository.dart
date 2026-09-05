import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../domain/account/online_account_credentials.dart';
import '../../platform/session/session_storage_stub.dart'
    if (dart.library.html) '../../platform/session/session_storage_web.dart'
    if (dart.library.io) '../../platform/session/session_storage_android.dart';
import 'google_authentication_api.dart';

class AuthenticationSessionRepository {
  AuthenticationSessionRepository({
    required GoogleAuthenticationApi api,
    required this.apiBaseUrl,
    SessionStorage? storage,
  }) : _api = api,
       _storage = storage ?? PlatformSessionStorage();

  final GoogleAuthenticationApi _api;
  final SessionStorage _storage;
  final String apiBaseUrl;
  Future<void> _tail = Future<void>.value();
  bool get _usesCookie => _api.mode == AuthenticationMode.web;

  Future<OnlineAccountCredentials?> restore() => _serialized(() => _restore());

  Future<OnlineAccountCredentials> refresh() => _serialized(() async {
    final credentials = await _restore();
    if (credentials == null) {
      throw const GoogleAuthenticationException(
        code: 'REFRESH_TOKEN_INVALID',
        message: '다시 로그인해 주세요.',
      );
    }
    return credentials;
  });

  Future<OnlineAccountCredentials> authenticate(String idToken) =>
      _serialized(() async {
        final previous = await _read();
        if (previous.logoutPending) {
          await _api.logout(previous.refreshToken);
          await _storage.delete();
        }
        final result = await _api.authenticate(idToken);
        await _save(
          _SessionRecord(
            accountId: result.credentials.accountId,
            refreshToken: _usesCookie ? null : result.refreshToken,
          ),
        );
        if (_usesCookie) {
          // HttpOnly 쿠키의 저장/전송 가능 여부는 서버 왕복으로 확인.
          try {
            final restored = await _restore();
            if (restored != null) return restored;
          } on GoogleAuthenticationException catch (error) {
            if (error.code != 'REFRESH_TOKEN_INVALID') rethrow;
          }
          throw const GoogleAuthenticationException(
            code: 'SESSION_COOKIE_UNAVAILABLE',
            message: '브라우저의 로그인 유지 쿠키를 확인할 수 없습니다.',
          );
        }
        return result.credentials;
      });

  Future<void> logout(String accessToken) => _serialized(() async {
    final record = await _read();
    // 서버 응답 유실/앱 종료 후에도 로그아웃 의도를 우선 복구.
    await _save(
      _SessionRecord(
        accountId: record.accountId,
        refreshToken: record.refreshToken,
        pendingKey: record.pendingKey,
        logoutPending: true,
      ),
    );
    await _api.logout(
      record.refreshToken,
      accessToken: record.pendingKey == null ? accessToken : null,
    );
    await _storage.delete();
  });

  Future<OnlineAccountCredentials?> _restore() async {
    final record = await _read();
    if (record.logoutPending) {
      await _api.logout(record.refreshToken);
      await _storage.delete();
      return null;
    }
    if (!_usesCookie && record.refreshToken == null) return null;
    final request = _SessionRecord(
      accountId: record.accountId,
      refreshToken: record.refreshToken,
      pendingKey: record.pendingKey ?? _newRequestKey(),
    );
    // 요청 전 먼저 저장하여 응답 유실 및 프로세스 종료 뒤 동일 요청으로 재시도.
    await _save(request);
    String? latestRefreshToken = request.refreshToken;
    try {
      var result = await _api.refresh(
        request.refreshToken,
        idempotencyKey: request.pendingKey,
      );
      latestRefreshToken = result.refreshToken;
      if (record.accountId != null &&
          record.accountId != result.credentials.accountId) {
        throw const GoogleAuthenticationException(
          code: 'INVALID_AUTH_ACCOUNT',
          message: '저장된 계정과 복원된 계정이 다릅니다. 다시 로그인해 주세요.',
        );
      }
      await _save(
        _SessionRecord(
          accountId: result.credentials.accountId,
          refreshToken: _usesCookie ? null : result.refreshToken,
        ),
      );
      // 오래된 멱등 응답의 access가 만료됐다면 회전된 refresh로 새 요청 수행.
      if (!result.credentials.accessExpiresAt.isAfter(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      )) {
        final next = _SessionRecord(
          accountId: result.credentials.accountId,
          refreshToken: _usesCookie ? null : result.refreshToken,
          pendingKey: _newRequestKey(),
        );
        await _save(next);
        result = await _api.refresh(
          next.refreshToken,
          idempotencyKey: next.pendingKey,
        );
        latestRefreshToken = result.refreshToken;
        if (result.credentials.accountId != next.accountId) {
          throw const GoogleAuthenticationException(
            code: 'INVALID_AUTH_ACCOUNT',
            message: '인증 계정이 변경되었습니다.',
          );
        }
        await _save(
          _SessionRecord(
            accountId: result.credentials.accountId,
            refreshToken: _usesCookie ? null : result.refreshToken,
          ),
        );
      }
      return result.credentials;
    } on GoogleAuthenticationException catch (error) {
      if (!error.endsSession) rethrow;
      // 확정 종료 뒤 남은 쿠키나 회전된 native 세션이 다시 복원되지 않도록 폐기 의도 보존.
      await _save(
        _SessionRecord(
          accountId: record.accountId,
          refreshToken: _usesCookie ? null : latestRefreshToken,
          logoutPending: true,
        ),
      );
      try {
        await _api.logout(_usesCookie ? null : latestRefreshToken);
        await _storage.delete();
      } on Object {
        // 통신/저장 실패 시 다음 시작에서 logoutPending을 먼저 재처리.
      }
      if (error.code == 'REFRESH_TOKEN_INVALID' && record.accountId == null) {
        return null;
      }
      rethrow;
    }
  }

  Future<_SessionRecord> _read() async {
    String? raw;
    try {
      raw = await _storage.read();
    } on PlatformException catch (error) {
      if (error.code != 'session_unreadable') rethrow;
      await _storage.delete();
      return const _SessionRecord();
    }
    if (raw == null) return const _SessionRecord();
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['version'] != 1 ||
          data['apiBaseUrl'] != apiBaseUrl ||
          (data['accountId'] != null && data['accountId'] is! String) ||
          (data['refreshToken'] != null && data['refreshToken'] is! String) ||
          (data['pendingKey'] != null && data['pendingKey'] is! String) ||
          data['logoutPending'] is! bool ||
          (_usesCookie && data['refreshToken'] != null)) {
        throw const FormatException('invalid session metadata');
      }
      return _SessionRecord(
        accountId: data['accountId'] as String?,
        refreshToken: data['refreshToken'] as String?,
        pendingKey: data['pendingKey'] as String?,
        logoutPending: data['logoutPending'] as bool,
      );
    } on FormatException {
      await _storage.delete();
      return const _SessionRecord();
    }
  }

  Future<void> _save(_SessionRecord record) => _storage.write(
    jsonEncode({
      'version': 1,
      'apiBaseUrl': apiBaseUrl,
      'accountId': record.accountId,
      if (!_usesCookie) 'refreshToken': record.refreshToken,
      'pendingKey': record.pendingKey,
      'logoutPending': record.logoutPending,
    }),
  );

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static String _newRequestKey() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }
}

class _SessionRecord {
  const _SessionRecord({
    this.accountId,
    this.refreshToken,
    this.pendingKey,
    this.logoutPending = false,
  });
  final String? accountId;
  final String? refreshToken;
  final String? pendingKey;
  final bool logoutPending;
}
