import 'dart:async';

import '../../domain/account/online_account_credentials.dart';
import 'google_authentication_api.dart';

typedef AuthenticationTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class OnlineAccountSessionController {
  OnlineAccountSessionController({
    required OnlineAccountCredentials credentials,
    required Future<OnlineAccountCredentials> Function(String refreshToken)
    refreshCredentials,
    required Future<void> Function(String refreshToken, String accessToken)
    revokeSession,
    required void Function(OnlineAccountCredentials credentials)
    onCredentialsChanged,
    required void Function() onSessionInvalidated,
    DateTime Function()? now,
    AuthenticationTimerFactory? timerFactory,
    this.refreshLeadTime = const Duration(minutes: 1),
    this.retryDelay = const Duration(seconds: 15),
  }) : _credentials = credentials,
       _refreshCredentials = refreshCredentials,
       _revokeSession = revokeSession,
       _onCredentialsChanged = onCredentialsChanged,
       _onSessionInvalidated = onSessionInvalidated,
       _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? Timer.new {
    _scheduleRefresh();
  }

  final Future<OnlineAccountCredentials> Function(String refreshToken)
  _refreshCredentials;
  final Future<void> Function(String refreshToken, String accessToken)
  _revokeSession;
  final void Function(OnlineAccountCredentials credentials)
  _onCredentialsChanged;
  final void Function() _onSessionInvalidated;
  final DateTime Function() _now;
  final AuthenticationTimerFactory _timerFactory;
  final Duration refreshLeadTime;
  final Duration retryDelay;

  OnlineAccountCredentials? _credentials;
  Future<OnlineAccountCredentials>? _refreshInFlight;
  Timer? _refreshTimer;
  bool _loggingOut = false;
  bool _disposed = false;

  OnlineAccountCredentials? get credentials => _credentials;

  Future<OnlineAccountCredentials> refresh() {
    final current = _refreshInFlight;
    if (current != null) {
      return current;
    }
    if (_disposed || _loggingOut || _credentials == null) {
      return Future.error(StateError('인증 세션을 갱신할 수 없습니다.'));
    }

    final operation = _performRefresh();
    _refreshInFlight = operation;
    return operation;
  }

  Future<T> runAuthenticated<T>({
    required Future<T> Function(String accessToken) request,
    required bool Function(Object error) isUnauthorized,
  }) async {
    var current = await _credentialsForRequest();
    try {
      return await request(current.accessToken);
    } on Object catch (error) {
      if (!isUnauthorized(error)) {
        rethrow;
      }
      current = await refresh();
      return request(current.accessToken);
    }
  }

  Future<void> logout() async {
    if (_disposed || _credentials == null || _loggingOut) {
      return;
    }
    _loggingOut = true;
    _refreshTimer?.cancel();

    final refreshInFlight = _refreshInFlight;
    if (refreshInFlight != null) {
      try {
        await refreshInFlight;
      } on Object {
        // 회전 결과가 불명확해도 최신 보유 토큰으로 폐기를 계속 시도한다.
      }
    }
    final current = _credentials;
    if (current == null) {
      _loggingOut = false;
      return;
    }

    try {
      await _revokeSession(current.refreshToken, current.accessToken);
    } on Object {
      _loggingOut = false;
      _scheduleRefresh();
      rethrow;
    }
    _invalidate();
  }

  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _credentials = null;
  }

  Future<OnlineAccountCredentials> _performRefresh() async {
    final current = _credentials;
    if (current == null) {
      throw StateError('인증 세션이 없습니다.');
    }
    try {
      final refreshed = await _refreshCredentials(current.refreshToken);
      if (refreshed.accountId != current.accountId) {
        throw const GoogleAuthenticationException(
          code: 'INVALID_AUTH_RESPONSE',
          message: '갱신된 인증 계정이 기존 세션과 일치하지 않습니다.',
        );
      }
      if (_disposed || _loggingOut) {
        return refreshed;
      }
      _credentials = refreshed;
      _onCredentialsChanged(refreshed);
      _scheduleRefresh();
      return refreshed;
    } on Object catch (error) {
      if (_isTerminalAuthenticationError(error)) {
        _invalidate();
      } else if (!_disposed && !_loggingOut && _credentials != null) {
        _scheduleRetry();
      }
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<OnlineAccountCredentials> _credentialsForRequest() async {
    final current = _credentials;
    if (current == null || _disposed || _loggingOut) {
      throw StateError('인증 세션이 없습니다.');
    }
    final now = _now().toUtc();
    if (current.accessExpiresAt.isAfter(now.add(refreshLeadTime))) {
      return current;
    }
    try {
      return await refresh();
    } on Object catch (error) {
      if (!_isTerminalAuthenticationError(error) &&
          _credentials != null &&
          current.accessExpiresAt.isAfter(now)) {
        return current;
      }
      rethrow;
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (_disposed || _loggingOut) {
      return;
    }
    final current = _credentials;
    if (current == null) {
      return;
    }
    final now = _now().toUtc();
    if (!current.refreshExpiresAt.isAfter(now)) {
      _refreshTimer = _timerFactory(Duration.zero, _invalidate);
      return;
    }
    final target = current.accessExpiresAt.subtract(refreshLeadTime);
    final delay = target.isAfter(now) ? target.difference(now) : Duration.zero;
    _refreshTimer = _timerFactory(delay, _refreshFromTimer);
  }

  void _scheduleRetry() {
    _refreshTimer?.cancel();
    final current = _credentials;
    if (_disposed || _loggingOut || current == null) {
      return;
    }
    final remaining = current.refreshExpiresAt.difference(_now().toUtc());
    if (remaining <= Duration.zero) {
      _invalidate();
      return;
    }
    final delay = remaining < retryDelay ? remaining : retryDelay;
    _refreshTimer = _timerFactory(delay, _refreshFromTimer);
  }

  void _refreshFromTimer() {
    unawaited(_refreshAfterTimer());
  }

  Future<void> _refreshAfterTimer() async {
    try {
      await refresh();
    } on Object {
      // 실패 유형에 따른 폐기 또는 재시도 예약은 refresh 내부에서 처리한다.
    }
  }

  bool _isTerminalAuthenticationError(Object error) {
    if (error is! GoogleAuthenticationException) {
      return false;
    }
    return error.code == 'REFRESH_TOKEN_INVALID' ||
        error.code == 'REFRESH_TOKEN_REUSED' ||
        error.code == 'ACCOUNT_NOT_ACTIVE' ||
        error.code == 'INVALID_AUTH_RESPONSE';
  }

  void _invalidate() {
    if (_credentials == null) {
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _credentials = null;
    _loggingOut = false;
    if (!_disposed) {
      _onSessionInvalidated();
    }
  }
}
