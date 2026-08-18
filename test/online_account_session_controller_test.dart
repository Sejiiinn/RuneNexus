import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/auth/google_authentication_api.dart';
import 'package:rune_nexus/data/auth/online_account_session_controller.dart';
import 'package:rune_nexus/domain/account/online_account_credentials.dart';

void main() {
  test('동시에 요청된 refresh는 하나의 Future를 공유한다', () async {
    final refreshCompleter = Completer<OnlineAccountCredentials>();
    var refreshCount = 0;
    final controller = _controller(
      refreshCredentials: (_) {
        refreshCount += 1;
        return refreshCompleter.future;
      },
    );

    final first = controller.refresh();
    final second = controller.refresh();

    expect(identical(first, second), isTrue);
    expect(refreshCount, 1);
    refreshCompleter.complete(_rotatedCredentials);
    expect((await first).accessToken, 'new-access');
    expect((await second).refreshToken, 'new-refresh');
    controller.dispose();
  });

  test('401 이후 한 번 refresh하고 요청을 한 번만 재시도한다', () async {
    var refreshCount = 0;
    var requestCount = 0;
    final controller = _controller(
      refreshCredentials: (_) async {
        refreshCount += 1;
        return _rotatedCredentials;
      },
    );

    final result = await controller.runAuthenticated<String>(
      request: (accessToken) async {
        requestCount += 1;
        if (requestCount == 1) {
          throw const _Unauthorized();
        }
        expect(accessToken, 'new-access');
        return 'ok';
      },
      isUnauthorized: (error) => error is _Unauthorized,
    );

    expect(result, 'ok');
    expect(refreshCount, 1);
    expect(requestCount, 2);
    controller.dispose();
  });

  test('access 만료 전에 예약된 자동 refresh를 수행한다', () async {
    final now = DateTime.utc(2026, 8, 19, 1);
    final scheduler = _ManualTimerFactory();
    var changedCredentials = _initialCredentials;
    final controller = OnlineAccountSessionController(
      credentials: _credentialsAt(now),
      refreshCredentials: (_) async => _rotatedCredentialsAt(now),
      revokeSession: (_, _) async {},
      onCredentialsChanged: (credentials) {
        changedCredentials = credentials;
      },
      onSessionInvalidated: () {},
      now: () => now,
      timerFactory: scheduler.create,
    );

    expect(scheduler.lastDuration, const Duration(minutes: 4));
    scheduler.lastTimer!.fire();
    await Future<void>.delayed(Duration.zero);

    expect(changedCredentials.accessToken, 'new-access');
    controller.dispose();
  });

  test('재사용 감지 오류는 메모리 세션을 폐기한다', () async {
    var invalidated = false;
    final controller = _controller(
      refreshCredentials: (_) async =>
          throw const GoogleAuthenticationException(
            code: 'REFRESH_TOKEN_REUSED',
            message: 'reused',
          ),
      onSessionInvalidated: () {
        invalidated = true;
      },
    );

    await expectLater(
      controller.refresh(),
      throwsA(
        isA<GoogleAuthenticationException>().having(
          (error) => error.code,
          'code',
          'REFRESH_TOKEN_REUSED',
        ),
      ),
    );

    expect(invalidated, isTrue);
    expect(controller.credentials, isNull);
    controller.dispose();
  });

  test('logout은 같은 세션의 access/refresh token을 보내고 성공 후 폐기한다', () async {
    String? revokedRefreshToken;
    String? revokedAccessToken;
    var invalidated = false;
    final controller = OnlineAccountSessionController(
      credentials: _initialCredentials,
      refreshCredentials: (_) async => _rotatedCredentials,
      revokeSession: (refreshToken, accessToken) async {
        revokedRefreshToken = refreshToken;
        revokedAccessToken = accessToken;
      },
      onCredentialsChanged: (_) {},
      onSessionInvalidated: () {
        invalidated = true;
      },
    );

    await controller.logout();

    expect(revokedRefreshToken, 'old-refresh');
    expect(revokedAccessToken, 'old-access');
    expect(invalidated, isTrue);
    expect(controller.credentials, isNull);
    controller.dispose();
  });

  test('선제 refresh에서 세션 폐기 오류가 나면 기존 access 요청을 보내지 않는다', () async {
    final now = DateTime.utc(2026, 8, 19, 1);
    var requestCount = 0;
    final controller = OnlineAccountSessionController(
      credentials: OnlineAccountCredentials(
        accountId: _initialCredentials.accountId,
        accessToken: 'soon-expiring-access',
        accessExpiresAt: now.add(const Duration(seconds: 30)),
        refreshToken: 'invalid-refresh',
        refreshExpiresAt: now.add(const Duration(days: 30)),
      ),
      refreshCredentials: (_) async =>
          throw const GoogleAuthenticationException(
            code: 'REFRESH_TOKEN_INVALID',
            message: 'invalid',
          ),
      revokeSession: (_, _) async {},
      onCredentialsChanged: (_) {},
      onSessionInvalidated: () {},
      now: () => now,
    );

    await expectLater(
      controller.runAuthenticated<void>(
        request: (_) async {
          requestCount += 1;
        },
        isUnauthorized: (_) => false,
      ),
      throwsA(isA<GoogleAuthenticationException>()),
    );

    expect(requestCount, 0);
    controller.dispose();
  });
}

OnlineAccountSessionController _controller({
  required Future<OnlineAccountCredentials> Function(String refreshToken)
  refreshCredentials,
  void Function()? onSessionInvalidated,
}) {
  return OnlineAccountSessionController(
    credentials: _initialCredentials,
    refreshCredentials: refreshCredentials,
    revokeSession: (_, _) async {},
    onCredentialsChanged: (_) {},
    onSessionInvalidated: onSessionInvalidated ?? () {},
  );
}

final _initialCredentials = OnlineAccountCredentials(
  accountId: '0198b955-3656-7c40-b3cb-87f427b90be2',
  accessToken: 'old-access',
  accessExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
  refreshToken: 'old-refresh',
  refreshExpiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
);

final _rotatedCredentials = OnlineAccountCredentials(
  accountId: _initialCredentials.accountId,
  accessToken: 'new-access',
  accessExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
  refreshToken: 'new-refresh',
  refreshExpiresAt: _initialCredentials.refreshExpiresAt,
);

OnlineAccountCredentials _credentialsAt(DateTime now) {
  return OnlineAccountCredentials(
    accountId: _initialCredentials.accountId,
    accessToken: 'old-access',
    accessExpiresAt: now.add(const Duration(minutes: 5)),
    refreshToken: 'old-refresh',
    refreshExpiresAt: now.add(const Duration(days: 30)),
  );
}

OnlineAccountCredentials _rotatedCredentialsAt(DateTime now) {
  return OnlineAccountCredentials(
    accountId: _initialCredentials.accountId,
    accessToken: 'new-access',
    accessExpiresAt: now.add(const Duration(minutes: 20)),
    refreshToken: 'new-refresh',
    refreshExpiresAt: now.add(const Duration(days: 30)),
  );
}

class _Unauthorized implements Exception {
  const _Unauthorized();
}

class _ManualTimerFactory {
  Duration? lastDuration;
  _ManualTimer? lastTimer;

  Timer create(Duration duration, void Function() callback) {
    lastDuration = duration;
    return lastTimer = _ManualTimer(callback);
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) {
      return;
    }
    _active = false;
    _callback();
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;

  @override
  void cancel() {
    _active = false;
  }
}
