import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/auth/google_authentication_api.dart';
import 'package:rune_nexus/data/auth/online_account_session_controller.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';
import 'package:rune_nexus/data/save/online_save_coordinator.dart';
import 'package:rune_nexus/domain/account/online_account_credentials.dart';

void main() {
  test('전송 중 여러 체크포인트를 최신 하나로 병합하고 순서대로 저장한다', () async {
    final completions = <Completer<OnlineSaveUpdateResult>>[];
    final requests = <OnlineSaveUpdateRequest>[];
    final client = _FakeOnlineSaveClient(
      update: (_, request) {
        requests.add(request);
        final completion = Completer<OnlineSaveUpdateResult>();
        completions.add(completion);
        return completion.future;
      },
    );
    final session = _session();
    var keySequence = 0;
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: client,
      session: session,
      initialRevision: 0,
      idempotencyKeyFactory: () => _idempotencyKey(++keySequence),
    );

    coordinator.enqueuePersistedCheckpoint(_saveData(1));
    await _pumpUntil(() => requests.length == 1);
    coordinator.enqueuePersistedCheckpoint(_saveData(2));
    coordinator.enqueuePersistedCheckpoint(_saveData(3));

    expect(requests, hasLength(1));
    expect(coordinator.snapshot.pendingSaveCount, 2);
    completions[0].complete(_updateResult(1));
    await _pumpUntil(() => requests.length == 2);

    expect(requests[0].expectedRevision, 0);
    expect(requests[1].expectedRevision, 1);
    expect(_savedAtMillis(requests[1]), 3);
    completions[1].complete(_updateResult(2));
    await coordinator.currentAttempt;

    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    expect(coordinator.snapshot.remoteRevision, 2);
    expect(coordinator.snapshot.pendingSaveCount, 0);
    coordinator.dispose();
    session.dispose();
  });

  test('전송 실패는 같은 본문과 멱등성 key를 Retry-After 뒤 재시도한다', () async {
    final requests = <OnlineSaveUpdateRequest>[];
    final timerFactory = _ManualTimerFactory();
    final client = _FakeOnlineSaveClient(
      update: (_, request) async {
        requests.add(request);
        if (requests.length == 1) {
          throw const OnlineSaveException(
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'limited',
            statusCode: 429,
            retryAfter: Duration(seconds: 7),
          );
        }
        return _updateResult(1);
      },
    );
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: client,
      session: session,
      initialRevision: 0,
      idempotencyKeyFactory: () => _idempotencyKey(1),
      timerFactory: timerFactory.create,
    );

    coordinator.enqueuePersistedCheckpoint(_saveData(10));
    await coordinator.currentAttempt;

    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.retryWaiting);
    expect(timerFactory.lastDuration, const Duration(seconds: 7));
    timerFactory.lastTimer!.fire();
    await _pumpUntil(() => requests.length == 2);
    await coordinator.currentAttempt;

    expect(identical(requests[0], requests[1]), isTrue);
    expect(requests[0].encodedBody, requests[1].encodedBody);
    expect(requests[0].idempotencyKey, requests[1].idempotencyKey);
    expect(coordinator.snapshot.remoteRevision, 1);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    coordinator.dispose();
    session.dispose();
  });

  test('401은 세션을 한 번 갱신하고 같은 저장 요청을 재전송한다', () async {
    final accessTokens = <String>[];
    final requests = <OnlineSaveUpdateRequest>[];
    var refreshCount = 0;
    final session = _session(
      refreshCredentials: (_) async {
        refreshCount++;
        return _credentials(accessToken: 'new-access');
      },
    );
    final client = _FakeOnlineSaveClient(
      update: (accessToken, request) async {
        accessTokens.add(accessToken);
        requests.add(request);
        if (accessTokens.length == 1) {
          throw const OnlineSaveException(
            code: 'ACCESS_TOKEN_INVALID',
            message: 'expired',
            statusCode: 401,
          );
        }
        return _updateResult(1);
      },
    );
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: client,
      session: session,
      initialRevision: 0,
      idempotencyKeyFactory: () => _idempotencyKey(1),
    );

    coordinator.enqueuePersistedCheckpoint(_saveData(20));
    await coordinator.currentAttempt;

    expect(refreshCount, 1);
    expect(accessTokens, ['old-access', 'new-access']);
    expect(identical(requests[0], requests[1]), isTrue);
    expect(coordinator.snapshot.remoteRevision, 1);
    coordinator.dispose();
    session.dispose();
  });

  test('인증 갱신 429도 세션을 유지하고 Retry-After 뒤 저장을 재개한다', () async {
    final now = DateTime.utc(2026, 8, 20, 3);
    final authenticationTimers = _ManualTimerFactory();
    final saveTimers = _ManualTimerFactory();
    var refreshCount = 0;
    var updateCount = 0;
    final session = OnlineAccountSessionController(
      credentials: OnlineAccountCredentials(
        accountId: _accountId,
        accessToken: 'expiring-access',
        accessExpiresAt: now.add(const Duration(seconds: 30)),
        refreshToken: 'refresh-token',
        refreshExpiresAt: now.add(const Duration(days: 30)),
      ),
      refreshCredentials: (_) async {
        refreshCount++;
        if (refreshCount == 1) {
          throw const GoogleAuthenticationException(
            code: 'RATE_LIMIT_EXCEEDED',
            message: 'limited',
            statusCode: 429,
            retryAfter: Duration(seconds: 7),
          );
        }
        return OnlineAccountCredentials(
          accountId: _accountId,
          accessToken: 'new-access',
          accessExpiresAt: now.add(const Duration(minutes: 15)),
          refreshToken: 'new-refresh-token',
          refreshExpiresAt: now.add(const Duration(days: 30)),
        );
      },
      revokeSession: (_, _) async {},
      onCredentialsChanged: (_) {},
      onSessionInvalidated: () {},
      now: () => now,
      timerFactory: authenticationTimers.create,
    );
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (accessToken, _) async {
          updateCount++;
          expect(accessToken, 'new-access');
          return _updateResult(1);
        },
      ),
      session: session,
      initialRevision: 0,
      idempotencyKeyFactory: () => _idempotencyKey(1),
      timerFactory: saveTimers.create,
    );

    coordinator.enqueuePersistedCheckpoint(_saveData(25));
    await coordinator.currentAttempt;

    expect(refreshCount, 1);
    expect(updateCount, 0);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.retryWaiting);
    expect(saveTimers.lastDuration, const Duration(seconds: 7));
    saveTimers.lastTimer!.fire();
    await _pumpUntil(() => updateCount == 1);
    await coordinator.currentAttempt;

    expect(refreshCount, 2);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    expect(coordinator.snapshot.remoteRevision, 1);
    coordinator.dispose();
    session.dispose();
  });

  test('revision 충돌은 자동 업로드를 중단하고 최신 pending을 보존한다', () async {
    var updateCount = 0;
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, _) async {
          updateCount++;
          throw const OnlineSaveException(
            code: 'SAVE_REVISION_CONFLICT',
            message: 'conflict',
            statusCode: 409,
            currentRevision: 5,
          );
        },
      ),
      session: session,
      initialRevision: 2,
      idempotencyKeyFactory: () => _idempotencyKey(1),
    );

    coordinator.enqueuePersistedCheckpoint(_saveData(30));
    await coordinator.currentAttempt;
    coordinator.enqueuePersistedCheckpoint(_saveData(31));
    await Future<void>.delayed(Duration.zero);

    expect(updateCount, 1);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.conflict);
    expect(coordinator.snapshot.remoteRevision, 2);
    expect(coordinator.snapshot.conflictRevision, 5);
    expect(coordinator.snapshot.pendingSaveCount, 2);
    coordinator.dispose();
    session.dispose();
  });

  test('검증 오류는 무한 재시도하지 않고 blocked로 전환한다', () async {
    final timerFactory = _ManualTimerFactory();
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, _) async => throw const OnlineSaveException(
          code: 'INVALID_SAVE_DATA',
          message: 'invalid',
          statusCode: 422,
        ),
      ),
      session: session,
      initialRevision: 0,
      idempotencyKeyFactory: () => _idempotencyKey(1),
      timerFactory: timerFactory.create,
    );

    coordinator.enqueuePersistedCheckpoint(_saveData(40));
    await coordinator.currentAttempt;

    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.blocked);
    expect(coordinator.snapshot.issueCode, 'INVALID_SAVE_DATA');
    expect(timerFactory.createCount, 0);
    coordinator.dispose();
    session.dispose();
  });

  test('생성한 멱등성 key는 UUID v4 형식을 따른다', () {
    final key = createOnlineSaveIdempotencyKey();

    expect(
      key,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}

const _accountId = '0198b955-3656-7c40-b3cb-87f427b90be2';

OnlineAccountSessionController _session({
  Future<OnlineAccountCredentials> Function(String refreshToken)?
  refreshCredentials,
}) {
  return OnlineAccountSessionController(
    credentials: _credentials(accessToken: 'old-access'),
    refreshCredentials:
        refreshCredentials ??
        (_) async => _credentials(accessToken: 'new-access'),
    revokeSession: (_, _) async {},
    onCredentialsChanged: (_) {},
    onSessionInvalidated: () {},
  );
}

OnlineAccountCredentials _credentials({required String accessToken}) {
  final now = DateTime.now().toUtc();
  return OnlineAccountCredentials(
    accountId: _accountId,
    accessToken: accessToken,
    accessExpiresAt: now.add(const Duration(minutes: 15)),
    refreshToken: 'refresh-token',
    refreshExpiresAt: now.add(const Duration(days: 30)),
  );
}

OnlineSaveUpdateResult _updateResult(int revision) {
  return OnlineSaveUpdateResult(
    revision: revision,
    serverSavedAt: DateTime.utc(2026, 8, 20, 3, 0, revision),
  );
}

String _idempotencyKey(int sequence) {
  return '0198b955-3656-7c40-b3cb-${sequence.toString().padLeft(12, '0')}';
}

GameSaveData _saveData(int savedAtMillis) {
  return GameSaveData.fromJson(<String, Object?>{
    'version': 2,
    'savedAtMillis': savedAtMillis,
    'preferences': const <String, Object?>{},
    'progression': const <String, Object?>{},
    'turretModules': const <String, Object?>{},
    'activeRun': null,
  })!;
}

int _savedAtMillis(OnlineSaveUpdateRequest request) {
  final decoded = jsonDecode(request.encodedBody) as Map<String, dynamic>;
  final data = decoded['data'] as Map<String, dynamic>;
  return data['savedAtMillis'] as int;
}

Future<void> _pumpUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('비동기 작업이 예상 상태에 도달하지 못했습니다.');
}

class _FakeOnlineSaveClient implements OnlineSaveClient {
  _FakeOnlineSaveClient({
    required Future<OnlineSaveUpdateResult> Function(
      String accessToken,
      OnlineSaveUpdateRequest request,
    )
    update,
  }) : _update = update;

  final Future<OnlineSaveUpdateResult> Function(
    String accessToken,
    OnlineSaveUpdateRequest request,
  )
  _update;

  @override
  Future<OnlineSaveSnapshot?> load(String accessToken) async => null;

  @override
  Future<OnlineSaveUpdateResult> update(
    String accessToken,
    OnlineSaveUpdateRequest request,
  ) {
    return _update(accessToken, request);
  }
}

class _ManualTimerFactory {
  Duration? lastDuration;
  _ManualTimer? lastTimer;
  int createCount = 0;

  Timer create(Duration duration, void Function() callback) {
    createCount++;
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
