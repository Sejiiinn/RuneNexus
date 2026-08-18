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

  OnlineAccountCredentials? _credentials;
  Future<OnlineAccountCredentials>? _refreshInFlight;
  Future<void>? _logoutInFlight;
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
    var attempted = await _credentialsForRequest();
    try {
      return await request(attempted.accessToken);
    } on Object catch (error) {
      if (!isUnauthorized(error)) {
        rethrow;
      }

      final latest = _activeCredentials();
      if (latest.accessToken != attempted.accessToken) {
        attempted = latest;
      } else {
        await refresh();
        attempted = _activeCredentials();
      }
      return request(attempted.accessToken);
    }
  }

  Future<void> logout() {
    final current = _logoutInFlight;
    if (current != null) {
      return current;
    }
    if (_disposed || _credentials == null) {
      return Future<void>.value();
    }

    final operation = _performLogout();
    _logoutInFlight = operation;
    return operation;
  }

  Future<void> _performLogout() async {
    _loggingOut = true;
    _refreshTimer?.cancel();

    try {
      final refreshInFlight = _refreshInFlight;
      if (refreshInFlight != null) {
        try {
          await refreshInFlight;
        } on Object {
          // 결과가 불명확해도 기존 token family를 찾아 폐기를 계속 시도한다.
        }
      }
      final current = _credentials;
      if (current == null || _disposed) {
        _loggingOut = false;
        return;
      }

      await _revokeSession(current.refreshToken, current.accessToken);
      _invalidate();
    } on Object {
      _loggingOut = false;
      _scheduleRefresh();
      rethrow;
    } finally {
      _logoutInFlight = null;
    }
  }

  void dispose() {
    _disposed = true;
    _loggingOut = false;
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
        throw StateError('인증 세션이 종료 중입니다.');
      }
      _credentials = refreshed;
      _onCredentialsChanged(refreshed);
      _scheduleRefresh();
      return refreshed;
    } on Object {
      if (!_disposed && !_loggingOut && _credentials != null) {
        _invalidate();
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
    await refresh();
    return _activeCredentials();
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

  void _refreshFromTimer() {
    unawaited(_refreshAfterTimer());
  }

  Future<void> _refreshAfterTimer() async {
    try {
      await refresh();
    } on Object {
      // refresh 결과가 불명확하면 같은 token을 재사용하지 않고 세션을 폐기한다.
    }
  }

  OnlineAccountCredentials _activeCredentials() {
    final current = _credentials;
    if (_disposed || _loggingOut || current == null) {
      throw StateError('인증 세션이 없습니다.');
    }
    return current;
  }

  void _invalidate() {
    final notify = _credentials != null && !_disposed;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _credentials = null;
    _loggingOut = false;
    if (notify) {
      _onSessionInvalidated();
    }
  }
}
