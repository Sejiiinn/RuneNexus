import 'dart:async';
import 'dart:math' as math;

import '../auth/google_authentication_api.dart';
import '../auth/online_account_session_controller.dart';
import 'backup_save_repository.dart';
import 'game_save_data.dart';
import 'online_save_api.dart';
import 'online_save_outbox.dart';
import 'online_save_outbox_repository.dart';
import 'online_save_repository.dart';

typedef OnlineSaveTimerFactory =
    Timer Function(Duration duration, void Function() callback);
typedef OnlineSaveIdempotencyKeyFactory = String Function();
typedef PersistedOnlineSaveLoader = Future<GameSaveData?> Function();
typedef OnlineSaveBeforeRemoteRebase = Future<void> Function();
typedef OnlineSaveLocalSavesResume = void Function();

enum OnlineSaveCoordinatorPhase {
  idle,
  sending,
  retryWaiting,
  rebasing,
  suspended,
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
    required this.requiresGameReload,
    required this.hasPendingRemoteRebase,
  });

  final OnlineSaveCoordinatorPhase phase;
  final int remoteRevision;
  final int pendingSaveCount;
  final int retryCount;
  final DateTime? lastSyncedAt;
  final String? issueCode;
  final int? conflictRevision;
  final bool requiresGameReload;
  final bool hasPendingRemoteRebase;
}

class OnlineSaveCoordinator implements OnlineSaveRepository {
  OnlineSaveCoordinator({
    required this.accountId,
    required OnlineSaveClient client,
    required OnlineAccountSessionController session,
    required int initialRevision,
    required OnlineSaveOutboxRepository outboxRepository,
    required PersistedOnlineSaveLoader loadPersistedCheckpoint,
    BackupSaveRepository? persistedSaveRepository,
    OnlineSaveBeforeRemoteRebase? beforeRemoteRebase,
    OnlineSaveLocalSavesResume? resumeLocalSaves,
    OnlineSaveIdempotencyKeyFactory? idempotencyKeyFactory,
    OnlineSaveIdempotencyKeyFactory? writerClaimIdempotencyKeyFactory,
    OnlineSaveIdempotencyKeyFactory? clientInstanceIdFactory,
    String clientBuild = const String.fromEnvironment(
      'RUNE_NEXUS_CLIENT_BUILD',
      defaultValue: 'development',
    ),
    int clientCompatibilityVersion = onlineSaveClientCompatibilityVersion,
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
       _persistedSaveRepository = persistedSaveRepository,
       _beforeRemoteRebase = beforeRemoteRebase,
       _resumeLocalSaves = resumeLocalSaves,
       _idempotencyKeyFactory =
           idempotencyKeyFactory ?? createOnlineSaveIdempotencyKey,
       _writerClaimIdempotencyKeyFactory =
           writerClaimIdempotencyKeyFactory ?? createOnlineSaveIdempotencyKey,
       _clientInstanceIdFactory =
           clientInstanceIdFactory ?? createOnlineSaveIdempotencyKey,
       _clientBuild = clientBuild,
       _clientCompatibilityVersion = clientCompatibilityVersion,
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
    if (clientBuild.trim().isEmpty) {
      throw ArgumentError.value(clientBuild, 'clientBuild', '비어 있을 수 없습니다.');
    }
    if (clientCompatibilityVersion <= 0) {
      throw ArgumentError.value(
        clientCompatibilityVersion,
        'clientCompatibilityVersion',
        '1 이상이어야 합니다.',
      );
    }
  }

  final String accountId;
  final OnlineSaveClient _client;
  final OnlineAccountSessionController _session;
  final int _initialRevision;
  final OnlineSaveOutboxController _outbox;
  final PersistedOnlineSaveLoader _loadPersistedCheckpoint;
  final BackupSaveRepository? _persistedSaveRepository;
  final OnlineSaveBeforeRemoteRebase? _beforeRemoteRebase;
  final OnlineSaveLocalSavesResume? _resumeLocalSaves;
  final OnlineSaveIdempotencyKeyFactory _idempotencyKeyFactory;
  final OnlineSaveIdempotencyKeyFactory _writerClaimIdempotencyKeyFactory;
  final OnlineSaveIdempotencyKeyFactory _clientInstanceIdFactory;
  final String _clientBuild;
  final int _clientCompatibilityVersion;
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
  bool _requiresGameReload = false;
  bool _needsRemoteReconciliation = false;
  bool _reconcileAfterInFlightAck = false;
  bool _localSavesQuiesced = false;

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
        requiresGameReload: false,
        hasPendingRemoteRebase: false,
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
      requiresGameReload: _requiresGameReload,
      hasPendingRemoteRebase: state.rebase != null,
    );
  }

  Future<void> get currentAttempt =>
      _drainOperation ?? _initializeOperation ?? Future<void>.value();

  int? get writerGeneration =>
      _initialized ? _outbox.state.writerGeneration : null;

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

  Future<void> resumeForeground() async {
    _ensureReady();
    var state = _outbox.state;
    if (state.phase == OnlineSaveOutboxPhase.retryWaiting ||
        state.phase == OnlineSaveOutboxPhase.rebasing ||
        state.phase == OnlineSaveOutboxPhase.blocked) {
      return;
    }
    final wasSuspended = state.phase == OnlineSaveOutboxPhase.suspended;
    if (!wasSuspended &&
        (_drainOperation != null || state.inFlight != null || state.dirty)) {
      _startDrain();
      await currentAttempt;
      if (_disposed) {
        return;
      }
      state = _outbox.state;
      if (state.phase == OnlineSaveOutboxPhase.retryWaiting ||
          state.phase == OnlineSaveOutboxPhase.rebasing ||
          state.phase == OnlineSaveOutboxPhase.blocked) {
        return;
      }
    }
    final claimed = await _claimWriter(allowSuspended: wasSuspended);
    if (!claimed || _disposed) {
      return;
    }
    final local = await _loadPersistedCheckpoint();
    final localHash = local == null ? null : onlineSavePayloadHash(local);
    final updated = await _outbox.mutate(
      (current) => current.copyWith(
        inFlight: wasSuspended ? null : current.inFlight,
        dirty: localHash != current.lastSyncedPayloadFingerprint,
        phase: OnlineSaveOutboxPhase.idle,
        issueCode: null,
        conflictRevision: null,
      ),
    );
    _pendingLatest = updated.dirty ? local : null;
    _needsRemoteReconciliation = _automaticRebaseEnabled;
    _publishSnapshot();
    if (_needsRemoteReconciliation) {
      await _reconcileRemote();
    }
    _resumeLocalSavesIfSafe();
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
    await _resumeAfterRetry();
  }

  void acknowledgeGameReload() {
    if (!_requiresGameReload) {
      return;
    }
    _requiresGameReload = false;
    _publishSnapshot();
  }

  Future<void> reportGameReloadFailure() async {
    if (_disposed || !_initialized || !_requiresGameReload) {
      return;
    }
    await _markBlocked('GAME_RELOAD_FAILED');
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
    state = await _prepareLegacyRequestsForRecovery(state);
    if (state.clientInstanceId == null) {
      state = await _outbox.mutate(
        (current) =>
            current.copyWith(clientInstanceId: _clientInstanceIdFactory()),
      );
    }
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
      } else if (_automaticRebaseEnabled &&
          phase == OnlineSaveOutboxPhase.conflict &&
          current.inFlight != null) {
        // 성공 응답 유실 가능성이 있는 요청을 먼저 같은 본문으로 재시도한다.
        phase = OnlineSaveOutboxPhase.idle;
      } else if (phase == OnlineSaveOutboxPhase.retryWaiting &&
          (nextRetryAt == null || !nextRetryAt.isAfter(_now().toUtc()))) {
        phase = OnlineSaveOutboxPhase.idle;
        nextRetryAt = null;
      }
      if (phase == OnlineSaveOutboxPhase.rebasing && current.rebase == null) {
        phase = OnlineSaveOutboxPhase.blocked;
        issueCode = 'SAVE_REBASE_JOURNAL_MISSING';
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
    _reconcileAfterInFlightAck =
        _automaticRebaseEnabled && state.inFlight != null;
    _needsRemoteReconciliation =
        _automaticRebaseEnabled &&
        state.inFlight == null &&
        state.rebase == null &&
        state.phase != OnlineSaveOutboxPhase.blocked;
    _publishSnapshot();

    if (_automaticRebaseEnabled && state.rebase != null) {
      await _resumeRebase();
      state = _outbox.state;
      if (state.phase == OnlineSaveOutboxPhase.retryWaiting ||
          state.phase == OnlineSaveOutboxPhase.blocked ||
          state.phase == OnlineSaveOutboxPhase.suspended) {
        return;
      }
    }
    if (state.phase == OnlineSaveOutboxPhase.retryWaiting) {
      _scheduleRestoredRetry(state);
      return;
    }
    if (state.inFlight != null &&
        state.phase != OnlineSaveOutboxPhase.suspended) {
      _startDrain();
      return;
    }
    final claimed = await _claimWriter(
      allowSuspended: state.phase == OnlineSaveOutboxPhase.suspended,
    );
    if (!claimed) {
      return;
    }
    state = _outbox.state;
    if (_needsRemoteReconciliation) {
      await _reconcileRemote();
      state = _outbox.state;
      if (state.phase == OnlineSaveOutboxPhase.retryWaiting ||
          state.phase == OnlineSaveOutboxPhase.blocked ||
          state.phase == OnlineSaveOutboxPhase.suspended) {
        return;
      }
    }
    _startDrain();
  }

  Future<OnlineSaveOutboxState> _prepareLegacyRequestsForRecovery(
    OnlineSaveOutboxState state,
  ) async {
    if (state.rebase != null) {
      return state;
    }
    final writerClaim = state.writerClaim;
    final inFlight = state.inFlight;
    final legacyWriterClaim =
        writerClaim != null &&
        writerClaim
                .toRequest(
                  currentClientCompatibilityVersion:
                      _clientCompatibilityVersion,
                )
                .clientCompatibilityVersion <
            _clientCompatibilityVersion;
    final legacyInFlight =
        inFlight != null &&
        inFlight
                .toRequest(
                  currentClientCompatibilityVersion:
                      _clientCompatibilityVersion,
                )
                .clientCompatibilityVersion <
            _clientCompatibilityVersion;
    if (!legacyWriterClaim && !legacyInFlight) {
      return state;
    }

    // 과거 claim은 폐기하고, 과거 PUT은 성공 영수증 확인을 위해 exact body를 유지한다.
    return _outbox.mutate(
      (current) => current.copyWith(
        writerGeneration: legacyWriterClaim && current.inFlight == null
            ? null
            : current.writerGeneration,
        writerClaim: legacyWriterClaim ? null : current.writerClaim,
        phase: OnlineSaveOutboxPhase.idle,
        retryCount: 0,
        nextRetryAt: null,
        issueCode: null,
        conflictRevision: null,
      ),
    );
  }

  Future<bool> _claimWriter({bool allowSuspended = false}) async {
    var state = _outbox.state;
    final replaceStaleInFlight =
        state.writerGeneration == null && state.inFlight != null;
    if (_disposed ||
        state.phase == OnlineSaveOutboxPhase.blocked ||
        (state.phase == OnlineSaveOutboxPhase.suspended && !allowSuspended)) {
      return false;
    }
    var claimEntry = state.writerClaim;
    if (claimEntry == null) {
      final clientInstanceId = state.clientInstanceId;
      if (clientInstanceId == null) {
        await _markBlocked('CLIENT_INSTANCE_ID_MISSING');
        return false;
      }
      final request = OnlineSaveWriterClaimRequest(
        idempotencyKey: _writerClaimIdempotencyKeyFactory(),
        clientInstanceId: clientInstanceId,
        clientBuild: _clientBuild,
        clientCompatibilityVersion: _clientCompatibilityVersion,
      );
      claimEntry = OnlineSaveWriterClaimEntry(
        idempotencyKey: request.idempotencyKey,
        encodedRequestBody: request.encodedBody,
      );
      final prepared = claimEntry;
      state = await _outbox.mutate(
        (current) => current.copyWith(
          writerClaim: prepared,
          phase: OnlineSaveOutboxPhase.sending,
          issueCode: null,
          nextRetryAt: null,
        ),
      );
      claimEntry = state.writerClaim;
    }
    if (claimEntry == null) {
      return false;
    }
    _publishSnapshot();
    try {
      final result = await _session.runAuthenticated(
        request: (accessToken) => _client.claimWriter(
          accessToken,
          claimEntry!.toRequest(
            currentClientCompatibilityVersion: _clientCompatibilityVersion,
          ),
        ),
        isUnauthorized: (error) =>
            error is OnlineSaveException && error.isUnauthorized,
      );
      if (_disposed) {
        return false;
      }
      final acknowledgedKey = claimEntry.idempotencyKey;
      await _outbox.mutate((current) {
        if (current.writerClaim?.idempotencyKey != acknowledgedKey) {
          return current;
        }
        return current.copyWith(
          writerGeneration: result.writerGeneration,
          writerClaim: null,
          inFlight: replaceStaleInFlight ? null : current.inFlight,
          dirty: replaceStaleInFlight ? true : current.dirty,
          phase: OnlineSaveOutboxPhase.idle,
          retryCount: 0,
          nextRetryAt: null,
          issueCode: null,
        );
      });
      _publishSnapshot();
      return true;
    } on Object catch (error) {
      if (error is OnlineSaveException && error.isRetryable) {
        await _scheduleRetry(
          issueCode: error.code,
          retryAfter: error.retryAfter,
        );
        return false;
      }
      if (error is OnlineSaveException &&
          error.statusCode == 426 &&
          error.code == 'CLIENT_UPDATE_REQUIRED') {
        await _blockForClientUpdate();
        return false;
      }
      if (error is GoogleAuthenticationException && error.statusCode == 429) {
        await _scheduleRetry(
          issueCode: error.code,
          retryAfter: error.retryAfter,
        );
        return false;
      }
      await _markBlocked(
        error is OnlineSaveException ? error.code : 'AUTH_SESSION_UNAVAILABLE',
      );
      return false;
    }
  }

  void _startDrain() {
    if (_disposed ||
        !_initialized ||
        _drainOperation != null ||
        _retryTimer != null ||
        _stopsDrain(_outbox.state.phase) ||
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
          !_stopsDrain(_outbox.state.phase) &&
          (_outbox.state.inFlight != null || _outbox.state.dirty)) {
        _startDrain();
      }
    }
  }

  Future<void> _drainQueue() async {
    while (!_disposed) {
      var state = _outbox.state;
      if (_stopsDrain(state.phase) ||
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
        final writerGeneration = state.writerGeneration;
        if (writerGeneration == null) {
          await _suspendWriter('SAVE_WRITER_REQUIRED');
          return;
        }
        final request = OnlineSaveUpdateRequest(
          expectedRevision: state.remoteRevision,
          idempotencyKey: _idempotencyKeyFactory(),
          writerGeneration: writerGeneration,
          data: data,
          clientCompatibilityVersion: _clientCompatibilityVersion,
        );
        entry = OnlineSaveOutboxEntry(
          idempotencyKey: request.idempotencyKey,
          writerGeneration: request.writerGeneration,
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

      final request = entry.toRequest(
        currentClientCompatibilityVersion: _clientCompatibilityVersion,
      );
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
        if (_reconcileAfterInFlightAck) {
          _reconcileAfterInFlightAck = false;
          final claimed = await _claimWriter();
          if (!claimed) {
            return;
          }
          _needsRemoteReconciliation = true;
          await _reconcileRemote();
          if (_stopsDrain(_outbox.state.phase) ||
              _outbox.state.phase == OnlineSaveOutboxPhase.retryWaiting) {
            return;
          }
        }
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
            error.statusCode == 426 &&
            error.code == 'CLIENT_UPDATE_REQUIRED') {
          if (request.clientCompatibilityVersion <
              _clientCompatibilityVersion) {
            await _recoverRejectedLegacyUpdate(entry, request);
            return;
          }
          await _blockForClientUpdate();
          return;
        }
        if (error is OnlineSaveException &&
            error.statusCode == 409 &&
            error.code == 'SAVE_WRITER_REPLACED') {
          await _suspendWriter(error.code);
          _needsRemoteReconciliation = _automaticRebaseEnabled;
          if (_needsRemoteReconciliation) {
            await _reconcileRemote();
          }
          return;
        }
        if (error is OnlineSaveException &&
            error.statusCode == 428 &&
            error.code == 'SAVE_WRITER_REQUIRED') {
          await _suspendWriter(error.code);
          return;
        }
        if (error is OnlineSaveException &&
            error.statusCode == 409 &&
            error.code == 'SAVE_REVISION_CONFLICT') {
          if (_automaticRebaseEnabled) {
            _reconcileAfterInFlightAck = false;
            await _resolveRevisionConflict(error);
            return;
          }
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

  Future<void> _reconcileRemote() async {
    if (!_automaticRebaseEnabled || _disposed) {
      return;
    }
    try {
      final state = _outbox.state;
      final lookup = await _loadRemoteForReconciliation(state);
      if (_disposed) {
        return;
      }
      final local = await _loadPersistedCheckpoint();
      final localHash = local == null ? null : onlineSavePayloadHash(local);
      final writerSuspended =
          state.phase == OnlineSaveOutboxPhase.suspended ||
          state.issueCode == 'SAVE_WRITER_REPLACED' ||
          state.issueCode == 'SAVE_WRITER_REQUIRED';
      final reconciledPhase = writerSuspended
          ? OnlineSaveOutboxPhase.suspended
          : OnlineSaveOutboxPhase.idle;
      final reconciledIssueCode = writerSuspended ? state.issueCode : null;
      if (lookup.notModified) {
        final updated = await _outbox.mutate(
          (current) => current.copyWith(
            dirty: localHash != current.lastSyncedPayloadFingerprint,
            phase: reconciledPhase,
            retryCount: 0,
            nextRetryAt: null,
            issueCode: reconciledIssueCode,
            conflictRevision: null,
          ),
        );
        _pendingLatest = updated.dirty ? local : null;
        _needsRemoteReconciliation = false;
        _publishSnapshot();
        _resumeLocalSavesIfSafe();
        return;
      }
      final remote = lookup.snapshot;
      if (remote == null) {
        if (state.remoteRevision > 0) {
          await _markBlocked('REMOTE_SAVE_MISSING');
          return;
        }
        final updated = await _outbox.mutate(
          (current) => current.copyWith(
            lastSyncedPayloadFingerprint: null,
            dirty: local != null,
            phase: reconciledPhase,
            issueCode: reconciledIssueCode,
            conflictRevision: null,
            nextRetryAt: null,
          ),
        );
        _pendingLatest = updated.dirty ? local : null;
        _needsRemoteReconciliation = false;
        _publishSnapshot();
        _resumeLocalSavesIfSafe();
        return;
      }

      final remoteHash = onlineSavePayloadHash(remote.data);
      if (remote.revision < state.remoteRevision) {
        await _markBlocked('REMOTE_REVISION_REGRESSION');
        return;
      }
      if (remote.revision > state.remoteRevision) {
        _needsRemoteReconciliation = false;
        await _beginRemoteRebase(remote, localHash);
        return;
      }
      final knownBaseHash = state.lastSyncedPayloadFingerprint;
      if (knownBaseHash != null && knownBaseHash != remoteHash) {
        await _markBlocked('REMOTE_PAYLOAD_HASH_MISMATCH');
        return;
      }
      final updated = await _outbox.mutate(
        (current) => current.copyWith(
          lastSyncedPayloadFingerprint: remoteHash,
          dirty: localHash != remoteHash,
          phase: reconciledPhase,
          retryCount: 0,
          nextRetryAt: null,
          lastSyncedAt: remote.serverSavedAt,
          issueCode: reconciledIssueCode,
          conflictRevision: null,
        ),
      );
      _pendingLatest = updated.dirty ? local : null;
      _needsRemoteReconciliation = false;
      _publishSnapshot();
      _resumeLocalSavesIfSafe();
    } on Object catch (error) {
      await _handleRemoteOperationError(error);
    }
  }

  Future<void> _resolveRevisionConflict(OnlineSaveException error) async {
    try {
      final remote = await _loadRemote();
      if (_disposed) {
        return;
      }
      final state = _outbox.state;
      if (remote == null || remote.revision <= state.remoteRevision) {
        await _markBlocked('SAVE_CONFLICT_STATE_INVALID');
        return;
      }
      final reportedRevision = error.currentRevision;
      if (reportedRevision != null && remote.revision < reportedRevision) {
        await _markBlocked('SAVE_CONFLICT_STATE_INVALID');
        return;
      }
      final local = await _loadPersistedCheckpoint();
      await _beginRemoteRebase(
        remote,
        local == null ? null : onlineSavePayloadHash(local),
      );
    } on Object catch (loadError) {
      await _handleRemoteOperationError(loadError);
    }
  }

  Future<OnlineSaveSnapshot?> _loadRemote() {
    return _session.runAuthenticated(
      request: _client.load,
      isUnauthorized: (error) =>
          error is OnlineSaveException && error.isUnauthorized,
    );
  }

  Future<_RemoteReconciliationLookup> _loadRemoteForReconciliation(
    OnlineSaveOutboxState state,
  ) async {
    final client = _client;
    if (client is OnlineSaveConditionalClient &&
        state.lastSyncedPayloadFingerprint != null) {
      final result = await _session.runAuthenticated(
        request: (accessToken) => client.loadIfChanged(
          accessToken,
          knownRevision: state.remoteRevision,
        ),
        isUnauthorized: (error) =>
            error is OnlineSaveException && error.isUnauthorized,
      );
      return _RemoteReconciliationLookup(
        notModified: result.notModified,
        snapshot: result.snapshot,
      );
    }
    return _RemoteReconciliationLookup(
      notModified: false,
      snapshot: await _loadRemote(),
    );
  }

  Future<void> _beginRemoteRebase(
    OnlineSaveSnapshot remote,
    String? sourcePayloadHash,
  ) async {
    final journal = OnlineSaveRebaseJournal(
      targetRevision: remote.revision,
      targetPayloadHash: onlineSavePayloadHash(remote.data),
      targetServerSavedAt: remote.serverSavedAt,
      sourcePayloadHash: sourcePayloadHash,
      stage: OnlineSaveRebaseStage.prepared,
    );
    await _outbox.mutate(
      (current) => current.copyWith(
        rebase: journal,
        phase: OnlineSaveOutboxPhase.rebasing,
        issueCode: current.issueCode,
        conflictRevision: remote.revision,
        nextRetryAt: null,
      ),
    );
    _publishSnapshot();
    if (!await _quiesceLocalSaves()) {
      return;
    }
    await _resumeRebase();
  }

  Future<void> _resumeRebase() async {
    final repository = _persistedSaveRepository;
    if (repository == null || _disposed) {
      return;
    }
    while (!_disposed) {
      var state = _outbox.state;
      var journal = state.rebase;
      if (journal == null) {
        return;
      }
      if (journal.stage == OnlineSaveRebaseStage.payloadApplied) {
        final applied = await _loadPersistedCheckpoint();
        if (applied != null &&
            onlineSavePayloadHash(applied) == journal.targetPayloadHash) {
          await _finalizeRemoteRebase(journal);
          return;
        }
        state = await _outbox.mutate(
          (current) => current.copyWith(
            rebase: current.rebase?.copyWith(
              stage: OnlineSaveRebaseStage.backupPreserved,
            ),
            phase: OnlineSaveOutboxPhase.rebasing,
          ),
        );
        journal = state.rebase!;
      }

      OnlineSaveSnapshot? remote;
      try {
        remote = await _loadRemote();
      } on Object catch (error) {
        await _handleRemoteOperationError(error);
        return;
      }
      if (remote == null || remote.revision < journal.targetRevision) {
        await _markBlocked('REMOTE_REBASE_TARGET_UNAVAILABLE');
        return;
      }
      final remoteHash = onlineSavePayloadHash(remote.data);
      if (remote.revision == journal.targetRevision &&
          remoteHash != journal.targetPayloadHash) {
        await _markBlocked('REMOTE_PAYLOAD_HASH_MISMATCH');
        return;
      }
      if (remote.revision != journal.targetRevision ||
          remoteHash != journal.targetPayloadHash) {
        journal = journal.copyWith(
          targetRevision: remote.revision,
          targetPayloadHash: remoteHash,
          targetServerSavedAt: remote.serverSavedAt,
        );
        await _outbox.mutate(
          (current) => current.copyWith(
            rebase: journal,
            phase: OnlineSaveOutboxPhase.rebasing,
            conflictRevision: remote!.revision,
          ),
        );
      }

      if (journal.stage == OnlineSaveRebaseStage.prepared) {
        final local = await _loadPersistedCheckpoint();
        final sourceHash = local == null ? null : onlineSavePayloadHash(local);
        journal = journal.copyWith(sourcePayloadHash: sourceHash);
        await _outbox.mutate(
          (current) => current.copyWith(
            rebase: journal,
            phase: OnlineSaveOutboxPhase.rebasing,
          ),
        );
        if (local != null) {
          try {
            await repository.preserveConflictBackup(
              ConflictSaveBackup(
                rebaseId: '$accountId:${journal.rebaseId}',
                accountId: accountId,
                baseRevision: state.remoteRevision,
                targetRevision: journal.targetRevision,
                localPayloadHash: sourceHash!,
                createdAt: _now().toUtc(),
                data: local,
              ),
            );
          } on Object {
            await _markBlocked('LOCAL_CONFLICT_BACKUP_FAILED');
            return;
          }
        }
        await _outbox.mutate(
          (current) => current.copyWith(
            rebase: current.rebase?.copyWith(
              stage: OnlineSaveRebaseStage.backupPreserved,
            ),
            phase: OnlineSaveOutboxPhase.rebasing,
          ),
        );
        _publishSnapshot();
        continue;
      }

      if (!await _quiesceLocalSaves()) {
        return;
      }
      final currentLocal = await _loadPersistedCheckpoint();
      final currentLocalHash = currentLocal == null
          ? null
          : onlineSavePayloadHash(currentLocal);
      if (currentLocalHash != journal.sourcePayloadHash) {
        await _outbox.mutate(
          (current) => current.copyWith(
            rebase: current.rebase?.copyWith(
              sourcePayloadHash: currentLocalHash,
              stage: OnlineSaveRebaseStage.prepared,
            ),
            phase: OnlineSaveOutboxPhase.rebasing,
          ),
        );
        continue;
      }

      try {
        await repository.save(remote.data);
      } on Object {
        _localSavesQuiesced = false;
        _resumeLocalSaves?.call();
        await _markBlocked('LOCAL_REBASE_APPLY_FAILED');
        return;
      }
      _requiresGameReload = true;
      await _outbox.mutate(
        (current) => current.copyWith(
          rebase: current.rebase?.copyWith(
            targetRevision: remote!.revision,
            targetPayloadHash: remoteHash,
            targetServerSavedAt: remote.serverSavedAt,
            stage: OnlineSaveRebaseStage.payloadApplied,
          ),
          phase: OnlineSaveOutboxPhase.rebasing,
        ),
      );
    }
  }

  Future<void> _finalizeRemoteRebase(OnlineSaveRebaseJournal journal) async {
    _requiresGameReload = true;
    await _outbox.mutate(
      (current) => current.copyWith(
        remoteRevision: journal.targetRevision,
        lastSyncedPayloadFingerprint: journal.targetPayloadHash,
        dirty: false,
        inFlight: null,
        rebase: null,
        phase:
            current.issueCode == 'SAVE_WRITER_REPLACED' ||
                current.issueCode == 'SAVE_WRITER_REQUIRED'
            ? OnlineSaveOutboxPhase.suspended
            : OnlineSaveOutboxPhase.idle,
        retryCount: 0,
        nextRetryAt: null,
        lastSyncedAt: journal.targetServerSavedAt,
        issueCode:
            current.issueCode == 'SAVE_WRITER_REPLACED' ||
                current.issueCode == 'SAVE_WRITER_REQUIRED'
            ? current.issueCode
            : null,
        conflictRevision: null,
      ),
    );
    _pendingLatest = null;
    _needsRemoteReconciliation = false;
    _reconcileAfterInFlightAck = false;
    _localSavesQuiesced = false;
    _publishSnapshot();
  }

  Future<void> _handleRemoteOperationError(Object error) async {
    if (error is OnlineSaveException && error.isRetryable) {
      await _scheduleRetry(issueCode: error.code, retryAfter: error.retryAfter);
      return;
    }
    if (error is GoogleAuthenticationException && error.statusCode == 429) {
      await _scheduleRetry(issueCode: error.code, retryAfter: error.retryAfter);
      return;
    }
    await _markBlocked(
      error is OnlineSaveException ? error.code : 'AUTH_SESSION_UNAVAILABLE',
    );
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
    await _resumeAfterRetry();
  }

  Future<void> _resumeAfterRetry() async {
    if (_disposed) {
      return;
    }
    if (_automaticRebaseEnabled && _outbox.state.rebase != null) {
      await _resumeRebase();
      return;
    }
    if (_outbox.state.writerClaim != null) {
      final claimed = await _claimWriter(
        allowSuspended: _outbox.state.phase == OnlineSaveOutboxPhase.suspended,
      );
      if (!claimed) {
        return;
      }
      _needsRemoteReconciliation = _automaticRebaseEnabled;
    }
    if (_needsRemoteReconciliation) {
      await _reconcileRemote();
      if (_outbox.state.phase == OnlineSaveOutboxPhase.retryWaiting ||
          _stopsDrain(_outbox.state.phase)) {
        return;
      }
    }
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

  Future<void> _blockForClientUpdate() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!await _quiesceLocalSaves()) {
      return;
    }
    await _markBlocked('CLIENT_UPDATE_REQUIRED');
  }

  Future<void> _recoverRejectedLegacyUpdate(
    OnlineSaveOutboxEntry entry,
    OnlineSaveUpdateRequest request,
  ) async {
    var local = await _loadPersistedCheckpoint();
    if (local == null) {
      local = request.data;
      await _persistedSaveRepository?.save(local);
    }
    var retired = false;
    await _outbox.mutate((current) {
      if (current.inFlight?.idempotencyKey != entry.idempotencyKey) {
        return current;
      }
      retired = true;
      return current.copyWith(
        writerGeneration: null,
        writerClaim: null,
        inFlight: null,
        dirty: true,
        phase: OnlineSaveOutboxPhase.idle,
        retryCount: 0,
        nextRetryAt: null,
        issueCode: null,
        conflictRevision: null,
      );
    });
    if (!retired || _disposed) {
      return;
    }
    _pendingLatest = local;
    _reconcileAfterInFlightAck = false;
    _needsRemoteReconciliation = _automaticRebaseEnabled;
    _publishSnapshot();

    final claimed = await _claimWriter();
    if (!claimed || _disposed) {
      return;
    }
    if (_needsRemoteReconciliation) {
      await _reconcileRemote();
    }
    _resumeLocalSavesIfSafe();
  }

  Future<void> _suspendWriter(String issueCode) async {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!await _quiesceLocalSaves()) {
      return;
    }
    await _outbox.mutate(
      (current) => current.copyWith(
        writerGeneration: null,
        phase: OnlineSaveOutboxPhase.suspended,
        issueCode: issueCode,
        nextRetryAt: null,
      ),
    );
    _publishSnapshot();
  }

  Future<bool> _quiesceLocalSaves() async {
    if (_localSavesQuiesced) {
      return true;
    }
    try {
      await _beforeRemoteRebase?.call();
      _localSavesQuiesced = true;
      return true;
    } on Object {
      await _markBlocked('LOCAL_SAVE_QUIESCE_FAILED');
      return false;
    }
  }

  void _resumeLocalSavesIfSafe() {
    final state = _outbox.state;
    if (!_localSavesQuiesced ||
        _requiresGameReload ||
        state.writerGeneration == null ||
        state.phase != OnlineSaveOutboxPhase.idle) {
      return;
    }
    _localSavesQuiesced = false;
    _resumeLocalSaves?.call();
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
      OnlineSaveOutboxPhase.rebasing => OnlineSaveCoordinatorPhase.rebasing,
      OnlineSaveOutboxPhase.suspended => OnlineSaveCoordinatorPhase.suspended,
      OnlineSaveOutboxPhase.conflict => OnlineSaveCoordinatorPhase.conflict,
      OnlineSaveOutboxPhase.blocked => OnlineSaveCoordinatorPhase.blocked,
    };
  }

  bool get _automaticRebaseEnabled => _persistedSaveRepository != null;

  static bool _stopsDrain(OnlineSaveOutboxPhase phase) {
    return phase == OnlineSaveOutboxPhase.rebasing ||
        phase == OnlineSaveOutboxPhase.suspended ||
        phase == OnlineSaveOutboxPhase.conflict ||
        phase == OnlineSaveOutboxPhase.blocked;
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

class _RemoteReconciliationLookup {
  const _RemoteReconciliationLookup({
    required this.notModified,
    required this.snapshot,
  });

  final bool notModified;
  final OnlineSaveSnapshot? snapshot;
}
