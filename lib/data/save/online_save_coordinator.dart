import 'dart:async';
import 'dart:math' as math;

import '../auth/google_authentication_api.dart';
import '../auth/online_account_session_controller.dart';
import 'game_save_data.dart';
import 'online_save_api.dart';

typedef OnlineSaveTimerFactory =
    Timer Function(Duration duration, void Function() callback);
typedef OnlineSaveIdempotencyKeyFactory = String Function();

enum OnlineSaveCoordinatorPhase {
  idle,
  sending,
  retryWaiting,
  conflict,
  blocked,
  disposed,
}

class OnlineSaveCoordinatorSnapshot {
  const OnlineSaveCoordinatorSnapshot({
    required this.phase,
    required this.remoteRevision,
    required this.pendingSaveCount,
    required this.retryCount,
    required this.lastSyncedAt,
    required this.issueCode,
    required this.conflictRevision,
  });

  final OnlineSaveCoordinatorPhase phase;
  final int remoteRevision;
  final int pendingSaveCount;
  final int retryCount;
  final DateTime? lastSyncedAt;
  final String? issueCode;
  final int? conflictRevision;
}

class OnlineSaveCoordinator {
  OnlineSaveCoordinator({
    required this.accountId,
    required OnlineSaveClient client,
    required OnlineAccountSessionController session,
    required int initialRevision,
    OnlineSaveIdempotencyKeyFactory? idempotencyKeyFactory,
    OnlineSaveTimerFactory? timerFactory,
    math.Random? retryRandom,
    this.onSnapshotChanged,
  }) : _client = client,
       _session = session,
       _remoteRevision = initialRevision,
       _idempotencyKeyFactory =
           idempotencyKeyFactory ?? createOnlineSaveIdempotencyKey,
       _timerFactory = timerFactory ?? Timer.new,
       _retryRandom = retryRandom ?? math.Random() {
    if (accountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', '비어 있을 수 없습니다.');
    }
    if (initialRevision < 0) {
      throw ArgumentError.value(
        initialRevision,
        'initialRevision',
        '0 이상이어야 합니다.',
      );
    }
    if (session.credentials?.accountId != accountId) {
      throw ArgumentError('인증 세션과 온라인 저장 계정이 일치하지 않습니다.', 'session');
    }
  }

  final String accountId;
  final OnlineSaveClient _client;
  final OnlineAccountSessionController _session;
  final OnlineSaveIdempotencyKeyFactory _idempotencyKeyFactory;
  final OnlineSaveTimerFactory _timerFactory;
  final math.Random _retryRandom;
  final void Function(OnlineSaveCoordinatorSnapshot snapshot)?
  onSnapshotChanged;

  int _remoteRevision;
  GameSaveData? _pendingLatest;
  OnlineSaveUpdateRequest? _inFlight;
  Future<void>? _drainOperation;
  Timer? _retryTimer;
  OnlineSaveCoordinatorPhase _phase = OnlineSaveCoordinatorPhase.idle;
  DateTime? _lastSyncedAt;
  String? _issueCode;
  int? _conflictRevision;
  int _retryCount = 0;
  bool _disposed = false;

  OnlineSaveCoordinatorSnapshot get snapshot => OnlineSaveCoordinatorSnapshot(
    phase: _phase,
    remoteRevision: _remoteRevision,
    pendingSaveCount:
        (_inFlight == null ? 0 : 1) + (_pendingLatest == null ? 0 : 1),
    retryCount: _retryCount,
    lastSyncedAt: _lastSyncedAt,
    issueCode: _issueCode,
    conflictRevision: _conflictRevision,
  );

  Future<void> get currentAttempt => _drainOperation ?? Future<void>.value();

  void enqueuePersistedCheckpoint(GameSaveData data) {
    if (_disposed) {
      throw StateError('종료된 온라인 저장 coordinator입니다.');
    }
    _pendingLatest = data;
    _publishSnapshot();
    _startDrain();
  }

  void retryNow() {
    if (_disposed || _phase != OnlineSaveCoordinatorPhase.retryWaiting) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _phase = OnlineSaveCoordinatorPhase.idle;
    _publishSnapshot();
    _startDrain();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pendingLatest = null;
    _inFlight = null;
    _phase = OnlineSaveCoordinatorPhase.disposed;
    _publishSnapshot();
  }

  void _startDrain() {
    if (_disposed ||
        _drainOperation != null ||
        _retryTimer != null ||
        _phase == OnlineSaveCoordinatorPhase.conflict ||
        _phase == OnlineSaveCoordinatorPhase.blocked ||
        (_inFlight == null && _pendingLatest == null)) {
      return;
    }

    final operation = _drainQueue();
    _drainOperation = operation;
    unawaited(_observeDrain(operation));
  }

  Future<void> _observeDrain(Future<void> operation) async {
    try {
      await operation;
    } on Object {
      if (!_disposed) {
        _phase = OnlineSaveCoordinatorPhase.blocked;
        _issueCode = 'SAVE_SYNC_INTERNAL_ERROR';
        _publishSnapshot();
      }
    } finally {
      if (identical(_drainOperation, operation)) {
        _drainOperation = null;
      }
      if (!_disposed &&
          _retryTimer == null &&
          _phase != OnlineSaveCoordinatorPhase.conflict &&
          _phase != OnlineSaveCoordinatorPhase.blocked &&
          (_inFlight != null || _pendingLatest != null)) {
        _startDrain();
      }
    }
  }

  Future<void> _drainQueue() async {
    while (!_disposed) {
      if (_inFlight == null) {
        final data = _pendingLatest;
        if (data == null) {
          _phase = OnlineSaveCoordinatorPhase.idle;
          _publishSnapshot();
          return;
        }
        _pendingLatest = null;
        _inFlight = OnlineSaveUpdateRequest(
          expectedRevision: _remoteRevision,
          idempotencyKey: _idempotencyKeyFactory(),
          data: data,
        );
      }

      final request = _inFlight!;
      _phase = OnlineSaveCoordinatorPhase.sending;
      _issueCode = null;
      _publishSnapshot();
      try {
        final result = await _session.runAuthenticated(
          request: (accessToken) => _client.update(accessToken, request),
          isUnauthorized: (error) =>
              error is OnlineSaveException && error.isUnauthorized,
        );
        if (_disposed) {
          return;
        }
        if (result.revision != request.expectedRevision + 1) {
          throw const OnlineSaveException(
            code: 'INVALID_SAVE_RESPONSE',
            message: '원격 저장 revision이 예상과 일치하지 않습니다.',
          );
        }
        _remoteRevision = result.revision;
        _lastSyncedAt = result.serverSavedAt;
        _inFlight = null;
        _retryCount = 0;
        _issueCode = null;
        _conflictRevision = null;
        _phase = _pendingLatest == null
            ? OnlineSaveCoordinatorPhase.idle
            : OnlineSaveCoordinatorPhase.sending;
        _publishSnapshot();
      } on Object catch (error) {
        if (_disposed) {
          return;
        }
        if (error is OnlineSaveException && error.isRetryable) {
          // 결과가 불명확한 요청의 본문과 멱등성 key 유지.
          _scheduleRetry(issueCode: error.code, retryAfter: error.retryAfter);
          return;
        }
        if (error is GoogleAuthenticationException && error.statusCode == 429) {
          _scheduleRetry(issueCode: error.code, retryAfter: error.retryAfter);
          return;
        }
        if (error is OnlineSaveException &&
            error.statusCode == 409 &&
            error.code == 'SAVE_REVISION_CONFLICT') {
          _phase = OnlineSaveCoordinatorPhase.conflict;
          _issueCode = error.code;
          _conflictRevision = error.currentRevision;
          _publishSnapshot();
          return;
        }
        _phase = OnlineSaveCoordinatorPhase.blocked;
        _issueCode = error is OnlineSaveException
            ? error.code
            : 'AUTH_SESSION_UNAVAILABLE';
        _publishSnapshot();
        return;
      }
    }
  }

  void _scheduleRetry({required String issueCode, Duration? retryAfter}) {
    _retryCount++;
    _phase = OnlineSaveCoordinatorPhase.retryWaiting;
    _issueCode = issueCode;
    final delay = retryAfter ?? _backoffDelay(_retryCount);
    _retryTimer = _timerFactory(delay, () {
      _retryTimer = null;
      if (_disposed) {
        return;
      }
      _phase = OnlineSaveCoordinatorPhase.idle;
      _publishSnapshot();
      _startDrain();
    });
    _publishSnapshot();
  }

  Duration _backoffDelay(int retryCount) {
    final exponent = math.min(retryCount - 1, 6);
    final baseMilliseconds = math.min(60_000, 1000 * (1 << exponent));
    final jitterRange = math.max(1, baseMilliseconds ~/ 4);
    return Duration(
      milliseconds: baseMilliseconds + _retryRandom.nextInt(jitterRange),
    );
  }

  void _publishSnapshot() {
    onSnapshotChanged?.call(snapshot);
  }
}

String createOnlineSaveIdempotencyKey() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
  final joined = hex.join();
  return '${joined.substring(0, 8)}-'
      '${joined.substring(8, 12)}-'
      '${joined.substring(12, 16)}-'
      '${joined.substring(16, 20)}-'
      '${joined.substring(20)}';
}
