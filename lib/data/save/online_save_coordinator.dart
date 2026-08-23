import 'dart:async';
import 'dart:math' as math;

import '../auth/google_authentication_api.dart';
import '../auth/online_account_session_controller.dart';
import 'game_save_data.dart';
import 'online_save_api.dart';
import 'online_save_outbox.dart';
import 'online_save_outbox_repository.dart';
import 'online_save_repository.dart';

typedef OnlineSaveTimerFactory =
    Timer Function(Duration duration, void Function() callback);
typedef OnlineSaveIdempotencyKeyFactory = String Function();
typedef PersistedOnlineSaveLoader = Future<GameSaveData?> Function();

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

class OnlineSaveCoordinator implements OnlineSaveRepository {
  OnlineSaveCoordinator({
    required this.accountId,
    required OnlineSaveClient client,
    required OnlineAccountSessionController session,
    required int initialRevision,
    required OnlineSaveOutboxRepository outboxRepository,
    required PersistedOnlineSaveLoader loadPersistedCheckpoint,
    OnlineSaveIdempotencyKeyFactory? idempotencyKeyFactory,
    OnlineSaveTimerFactory? timerFactory,
    math.Random? retryRandom,
    DateTime Function()? now,
    this.onSnapshotChanged,
  }) : _client = client,
       _session = session,
       _initialRevision = initialRevision,
       _outbox = OnlineSaveOutboxController(
         accountId: accountId,
         repository: outboxRepository,
       ),
       _loadPersistedCheckpoint = loadPersistedCheckpoint,
       _idempotencyKeyFactory =
           idempotencyKeyFactory ?? createOnlineSaveIdempotencyKey,
       _timerFactory = timerFactory ?? Timer.new,
       _retryRandom = retryRandom ?? math.Random(),
       _now = now ?? DateTime.now {
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
  final int _initialRevision;
  final OnlineSaveOutboxController _outbox;
  final PersistedOnlineSaveLoader _loadPersistedCheckpoint;
  final OnlineSaveIdempotencyKeyFactory _idempotencyKeyFactory;
  final OnlineSaveTimerFactory _timerFactory;
  final math.Random _retryRandom;
  final DateTime Function() _now;
  final void Function(OnlineSaveCoordinatorSnapshot snapshot)?
  onSnapshotChanged;

  Future<void>? _initializeOperation;
  Future<void>? _drainOperation;
  Timer? _retryTimer;
  GameSaveData? _pendingLatest;
  bool _initialized = false;
  bool _disposed = false;

  OnlineSaveCoordinatorSnapshot get snapshot {
    if (!_initialized) {
      return OnlineSaveCoordinatorSnapshot(
        phase: _disposed
            ? OnlineSaveCoordinatorPhase.disposed
            : OnlineSaveCoordinatorPhase.idle,
        remoteRevision: _initialRevision,
        pendingSaveCount: 0,
        retryCount: 0,
        lastSyncedAt: null,
        issueCode: null,
        conflictRevision: null,
      );
    }
    final state = _outbox.state;
    return OnlineSaveCoordinatorSnapshot(
      phase: _disposed
          ? OnlineSaveCoordinatorPhase.disposed
          : _coordinatorPhase(state.phase),
      remoteRevision: state.remoteRevision,
      pendingSaveCount:
          (state.inFlight == null ? 0 : 1) + (state.dirty ? 1 : 0),
      retryCount: state.retryCount,
      lastSyncedAt: state.lastSyncedAt,
      issueCode: state.issueCode,
      conflictRevision: state.conflictRevision,
    );
  }

  Future<void> get currentAttempt =>
      _drainOperation ?? _initializeOperation ?? Future<void>.value();

  Future<void> initialize() {
    final current = _initializeOperation;
    if (current != null) {
      return current;
    }
    if (_initialized) {
      return Future<void>.value();
    }
    if (_disposed) {
      return Future<void>.error(StateError('종료된 온라인 저장 coordinator입니다.'));
    }
    final operation = _performInitialize();
    _initializeOperation = operation;
    return operation.whenComplete(() {
      if (identical(_initializeOperation, operation)) {
        _initializeOperation = null;
      }
    });
  }

  Future<void> enqueuePersistedCheckpoint(GameSaveData data) async {
    _ensureReady();
    final fingerprint = onlineSavePayloadFingerprint(data);
    final next = await _outbox.mutate((current) {
      final alreadyRepresented = current.inFlight == null
          ? current.lastSyncedPayloadFingerprint == fingerprint
          : current.inFlight!.payloadFingerprint == fingerprint;
      return current.copyWith(
        payloadGeneration: current.payloadGeneration + 1,
        dirty: !alreadyRepresented,
      );
    });
    _pendingLatest = next.dirty ? data : null;
    _publishSnapshot();
    _startDrain();
  }

  @override
  Future<void> saveRoundCheckpoint(GameSaveData data) {
    return enqueuePersistedCheckpoint(data);
  }

  Future<void> retryNow() async {
    if (_disposed ||
        !_initialized ||
        _outbox.state.phase != OnlineSaveOutboxPhase.retryWaiting) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    await _outbox.mutate(
      (current) => current.copyWith(
        phase: OnlineSaveOutboxPhase.idle,
        nextRetryAt: null,
      ),
    );
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
    _publishSnapshot();
  }

  Future<void> _performInitialize() async {
    var state = await _outbox.initialize(remoteRevision: _initialRevision);
    final persistedData = await _loadPersistedCheckpoint();
    final persistedFingerprint = persistedData == null
        ? null
        : onlineSavePayloadFingerprint(persistedData);
    state = await _outbox.mutate((current) {
      var generation = current.payloadGeneration;
      var dirty = current.dirty;
      var phase = current.phase;
      String? issueCode = current.issueCode;
      DateTime? nextRetryAt = current.nextRetryAt;

      if (persistedData == null) {
        if (current.dirty && current.inFlight == null) {
          phase = OnlineSaveOutboxPhase.blocked;
          issueCode = 'LOCAL_SAVE_NOT_FOUND';
        }
      } else {
        final representedFingerprint = current.inFlight == null
            ? current.lastSyncedPayloadFingerprint
            : current.inFlight!.payloadFingerprint;
        final recoveredDirty = persistedFingerprint != representedFingerprint;
        if (recoveredDirty && !current.dirty) {
          generation = math.max(
            current.payloadGeneration + 1,
            (current.inFlight?.payloadGeneration ?? -1) + 1,
          );
        }
        dirty = recoveredDirty;
      }

      if (phase == OnlineSaveOutboxPhase.sending) {
        phase = OnlineSaveOutboxPhase.idle;
      } else if (phase == OnlineSaveOutboxPhase.retryWaiting &&
          (nextRetryAt == null || !nextRetryAt.isAfter(_now().toUtc()))) {
        phase = OnlineSaveOutboxPhase.idle;
        nextRetryAt = null;
      }
      return current.copyWith(
        payloadGeneration: generation,
        dirty: dirty,
        phase: phase,
        issueCode: issueCode,
        nextRetryAt: nextRetryAt,
      );
    });
    if (_disposed) {
      return;
    }
    _initialized = true;
    _pendingLatest = state.dirty ? persistedData : null;
    _publishSnapshot();
    if (state.phase == OnlineSaveOutboxPhase.retryWaiting) {
      _scheduleRestoredRetry(state);
    } else {
      _startDrain();
    }
  }

  void _startDrain() {
    if (_disposed ||
        !_initialized ||
        _drainOperation != null ||
        _retryTimer != null ||
        _outbox.state.phase == OnlineSaveOutboxPhase.conflict ||
        _outbox.state.phase == OnlineSaveOutboxPhase.blocked ||
        (_outbox.state.inFlight == null && !_outbox.state.dirty)) {
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
        try {
          await _markBlocked('SAVE_SYNC_INTERNAL_ERROR');
        } on Object {
          // Outbox 자체 저장 실패는 호출자가 다음 체크포인트에서 다시 확인한다.
        }
      }
    } finally {
      if (identical(_drainOperation, operation)) {
        _drainOperation = null;
      }
      if (!_disposed &&
          _retryTimer == null &&
          _initialized &&
          _outbox.state.phase != OnlineSaveOutboxPhase.conflict &&
          _outbox.state.phase != OnlineSaveOutboxPhase.blocked &&
          (_outbox.state.inFlight != null || _outbox.state.dirty)) {
        _startDrain();
      }
    }
  }

  Future<void> _drainQueue() async {
    while (!_disposed) {
      var state = _outbox.state;
      if (state.phase == OnlineSaveOutboxPhase.conflict ||
          state.phase == OnlineSaveOutboxPhase.blocked ||
          state.phase == OnlineSaveOutboxPhase.retryWaiting) {
        return;
      }
      var entry = state.inFlight;
      if (entry == null) {
        if (!state.dirty) {
          await _setIdle();
          return;
        }
        final data = _pendingLatest ?? await _loadPersistedCheckpoint();
        if (data == null) {
          await _markBlocked('LOCAL_SAVE_NOT_FOUND');
          return;
        }
        final fingerprint = onlineSavePayloadFingerprint(data);
        final request = OnlineSaveUpdateRequest(
          expectedRevision: state.remoteRevision,
          idempotencyKey: _idempotencyKeyFactory(),
          data: data,
        );
        entry = OnlineSaveOutboxEntry(
          idempotencyKey: request.idempotencyKey,
          expectedRevision: request.expectedRevision,
          encodedRequestBody: request.encodedBody,
          payloadFingerprint: fingerprint,
          payloadGeneration: state.payloadGeneration,
        );
        final preparedEntry = entry;
        state = await _outbox.mutate((current) {
          if (current.inFlight != null) {
            return current;
          }
          return current.copyWith(
            inFlight: preparedEntry,
            dirty: current.payloadGeneration > preparedEntry.payloadGeneration,
            phase: OnlineSaveOutboxPhase.sending,
            issueCode: null,
            conflictRevision: null,
            nextRetryAt: null,
          );
        });
        entry = state.inFlight;
        if (entry == null) {
          continue;
        }
        if (!state.dirty) {
          _pendingLatest = null;
        }
        _publishSnapshot();
      } else if (state.phase != OnlineSaveOutboxPhase.sending) {
        state = await _outbox.mutate(
          (current) => current.copyWith(
            phase: OnlineSaveOutboxPhase.sending,
            issueCode: null,
            nextRetryAt: null,
          ),
        );
        _publishSnapshot();
      }

      final request = entry.toRequest();
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
        final acknowledgedKey = entry.idempotencyKey;
        state = await _outbox.mutate((current) {
          if (current.inFlight?.idempotencyKey != acknowledgedKey) {
            return current;
          }
          return current.copyWith(
            remoteRevision: result.revision,
            lastSyncedPayloadFingerprint: entry!.payloadFingerprint,
            inFlight: null,
            phase: current.dirty
                ? OnlineSaveOutboxPhase.sending
                : OnlineSaveOutboxPhase.idle,
            retryCount: 0,
            nextRetryAt: null,
            lastSyncedAt: result.serverSavedAt,
            issueCode: null,
            conflictRevision: null,
          );
        });
        if (!state.dirty) {
          _pendingLatest = null;
        }
        _publishSnapshot();
      } on Object catch (error) {
        if (_disposed) {
          return;
        }
        if (error is OnlineSaveException && error.isRetryable) {
          await _scheduleRetry(
            issueCode: error.code,
            retryAfter: error.retryAfter,
          );
          return;
        }
        if (error is GoogleAuthenticationException && error.statusCode == 429) {
          await _scheduleRetry(
            issueCode: error.code,
            retryAfter: error.retryAfter,
          );
          return;
        }
        if (error is OnlineSaveException &&
            error.statusCode == 409 &&
            error.code == 'SAVE_REVISION_CONFLICT') {
          await _outbox.mutate(
            (current) => current.copyWith(
              phase: OnlineSaveOutboxPhase.conflict,
              issueCode: error.code,
              conflictRevision: error.currentRevision,
              nextRetryAt: null,
            ),
          );
          _publishSnapshot();
          return;
        }
        await _markBlocked(
          error is OnlineSaveException
              ? error.code
              : 'AUTH_SESSION_UNAVAILABLE',
        );
        return;
      }
    }
  }

  Future<void> _scheduleRetry({
    required String issueCode,
    Duration? retryAfter,
  }) async {
    final retryCount = _outbox.state.retryCount + 1;
    final delay = retryAfter ?? _backoffDelay(retryCount);
    final nextRetryAt = _now().toUtc().add(delay);
    await _outbox.mutate(
      (current) => current.copyWith(
        phase: OnlineSaveOutboxPhase.retryWaiting,
        retryCount: retryCount,
        nextRetryAt: nextRetryAt,
        issueCode: issueCode,
      ),
    );
    _retryTimer?.cancel();
    _retryTimer = _timerFactory(delay, () {
      _retryTimer = null;
      unawaited(_resumeRetry());
    });
    _publishSnapshot();
  }

  void _scheduleRestoredRetry(OnlineSaveOutboxState state) {
    final retryAt = state.nextRetryAt;
    final now = _now().toUtc();
    final delay = retryAt != null && retryAt.isAfter(now)
        ? retryAt.difference(now)
        : Duration.zero;
    _retryTimer = _timerFactory(delay, () {
      _retryTimer = null;
      unawaited(_resumeRetry());
    });
  }

  Future<void> _resumeRetry() async {
    if (_disposed) {
      return;
    }
    await _outbox.mutate(
      (current) => current.copyWith(
        phase: OnlineSaveOutboxPhase.idle,
        nextRetryAt: null,
      ),
    );
    _publishSnapshot();
    _startDrain();
  }

  Future<void> _setIdle() async {
    if (_outbox.state.phase == OnlineSaveOutboxPhase.idle) {
      return;
    }
    await _outbox.mutate(
      (current) => current.copyWith(
        phase: OnlineSaveOutboxPhase.idle,
        issueCode: null,
        nextRetryAt: null,
      ),
    );
    _publishSnapshot();
  }

  Future<void> _markBlocked(String issueCode) async {
    await _outbox.mutate(
      (current) => current.copyWith(
        phase: OnlineSaveOutboxPhase.blocked,
        issueCode: issueCode,
        nextRetryAt: null,
      ),
    );
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

  void _ensureReady() {
    if (_disposed) {
      throw StateError('종료된 온라인 저장 coordinator입니다.');
    }
    if (!_initialized) {
      throw StateError('온라인 저장 coordinator가 초기화되지 않았습니다.');
    }
  }

  void _publishSnapshot() {
    onSnapshotChanged?.call(snapshot);
  }

  static OnlineSaveCoordinatorPhase _coordinatorPhase(
    OnlineSaveOutboxPhase phase,
  ) {
    return switch (phase) {
      OnlineSaveOutboxPhase.idle => OnlineSaveCoordinatorPhase.idle,
      OnlineSaveOutboxPhase.sending => OnlineSaveCoordinatorPhase.sending,
      OnlineSaveOutboxPhase.retryWaiting =>
        OnlineSaveCoordinatorPhase.retryWaiting,
      OnlineSaveOutboxPhase.conflict => OnlineSaveCoordinatorPhase.conflict,
      OnlineSaveOutboxPhase.blocked => OnlineSaveCoordinatorPhase.blocked,
    };
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
