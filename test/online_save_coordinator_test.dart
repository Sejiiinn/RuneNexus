import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/auth/google_authentication_api.dart';
import 'package:rune_nexus/data/auth/online_account_session_controller.dart';
import 'package:rune_nexus/data/save/backup_save_repository.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';
import 'package:rune_nexus/data/save/online_save_coordinator.dart';
import 'package:rune_nexus/data/save/online_save_outbox.dart';
import 'package:rune_nexus/data/save/online_save_outbox_repository.dart';
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
      outboxRepository: MemoryOnlineSaveOutboxRepository(),
      loadPersistedCheckpoint: () async => null,
      idempotencyKeyFactory: () => _idempotencyKey(++keySequence),
    );
    await coordinator.initialize();

    await coordinator.enqueuePersistedCheckpoint(_saveData(1));
    await _pumpUntil(() => requests.length == 1);
    await coordinator.enqueuePersistedCheckpoint(_saveData(2));
    await coordinator.enqueuePersistedCheckpoint(_saveData(3));

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

  test('원격 기록을 동기화 기준으로 초기화하면 다시 업로드하지 않는다', () async {
    final remoteData = _saveData(5);
    final remoteSavedAt = DateTime.utc(2026, 8, 24, 4);
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 7,
          ).copyWith(
            lastSyncedPayloadFingerprint: onlineSavePayloadFingerprint(
              remoteData,
            ),
            lastSyncedAt: remoteSavedAt,
          );
    var updateCount = 0;
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, _) async {
          updateCount++;
          return _updateResult(8);
        },
      ),
      session: session,
      initialRevision: 7,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => remoteData,
    );

    await coordinator.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(updateCount, 0);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    expect(coordinator.snapshot.remoteRevision, 7);
    expect(coordinator.snapshot.lastSyncedAt, remoteSavedAt);
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
      outboxRepository: MemoryOnlineSaveOutboxRepository(),
      loadPersistedCheckpoint: () async => null,
      idempotencyKeyFactory: () => _idempotencyKey(1),
      timerFactory: timerFactory.create,
    );
    await coordinator.initialize();

    await coordinator.enqueuePersistedCheckpoint(_saveData(10));
    await coordinator.currentAttempt;

    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.retryWaiting);
    expect(timerFactory.lastDuration, const Duration(seconds: 7));
    timerFactory.lastTimer!.fire();
    await _pumpUntil(() => requests.length == 2);
    await coordinator.currentAttempt;

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
      outboxRepository: MemoryOnlineSaveOutboxRepository(),
      loadPersistedCheckpoint: () async => null,
      idempotencyKeyFactory: () => _idempotencyKey(1),
    );
    await coordinator.initialize();

    await coordinator.enqueuePersistedCheckpoint(_saveData(20));
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
      outboxRepository: MemoryOnlineSaveOutboxRepository(),
      loadPersistedCheckpoint: () async => null,
      idempotencyKeyFactory: () => _idempotencyKey(1),
      timerFactory: saveTimers.create,
    );
    await coordinator.initialize();

    await coordinator.enqueuePersistedCheckpoint(_saveData(25));
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
      outboxRepository: MemoryOnlineSaveOutboxRepository(),
      loadPersistedCheckpoint: () async => null,
      idempotencyKeyFactory: () => _idempotencyKey(1),
    );
    await coordinator.initialize();

    await coordinator.enqueuePersistedCheckpoint(_saveData(30));
    await coordinator.currentAttempt;
    await coordinator.enqueuePersistedCheckpoint(_saveData(31));
    await Future<void>.delayed(Duration.zero);

    expect(updateCount, 1);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.conflict);
    expect(coordinator.snapshot.remoteRevision, 2);
    expect(coordinator.snapshot.conflictRevision, 5);
    expect(coordinator.snapshot.pendingSaveCount, 2);
    coordinator.dispose();
    session.dispose();
  });

  test('원격 revision이 앞서면 로컬을 충돌 백업하고 원격 진행으로 자동 재기준화한다', () async {
    final local = _saveData(100);
    final remote = _saveData(200);
    final repository = _MemoryBackupSaveRepository(local);
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state = OnlineSaveOutboxState.initial(
        accountId: _accountId,
        remoteRevision: 1,
      ).copyWith(lastSyncedPayloadFingerprint: onlineSavePayloadHash(local));
    var updateCount = 0;
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        load: (_) async => OnlineSaveSnapshot(
          revision: 2,
          serverSavedAt: DateTime.utc(2026, 8, 24, 2),
          data: remote,
        ),
        update: (_, _) async {
          updateCount++;
          return _updateResult(2);
        },
      ),
      session: session,
      initialRevision: 1,
      outboxRepository: outbox,
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
    );

    await coordinator.initialize();

    expect(updateCount, 0);
    expect(repository.data?.savedAtMillis, 200);
    expect(repository.conflictBackups, hasLength(1));
    expect(repository.conflictBackups.single.data.savedAtMillis, 100);
    expect(outbox.state?.baseRevision, 2);
    expect(outbox.state?.basePayloadHash, onlineSavePayloadHash(remote));
    expect(outbox.state?.dirty, isFalse);
    expect(outbox.state?.rebase, isNull);
    expect(coordinator.snapshot.requiresGameReload, isTrue);
    coordinator.dispose();
    session.dispose();
  });

  test('원격 적용 실패 시 기존 로컬을 유지하고 일시 정지한 저장 writer를 재개한다', () async {
    final local = _saveData(210);
    final remote = _saveData(220);
    final repository = _MemoryBackupSaveRepository(local)..failNextSave = true;
    var quiesceCount = 0;
    var resumeCount = 0;
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        load: (_) async => OnlineSaveSnapshot(
          revision: 2,
          serverSavedAt: DateTime.utc(2026, 8, 24, 2),
          data: remote,
        ),
        update: (_, _) async => _updateResult(2),
      ),
      session: session,
      initialRevision: 1,
      outboxRepository: MemoryOnlineSaveOutboxRepository()
        ..state = OnlineSaveOutboxState.initial(
          accountId: _accountId,
          remoteRevision: 1,
        ).copyWith(lastSyncedPayloadFingerprint: onlineSavePayloadHash(local)),
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
      beforeRemoteRebase: () async {
        quiesceCount++;
      },
      resumeLocalSaves: () {
        resumeCount++;
      },
    );

    await coordinator.initialize();

    expect(quiesceCount, 1);
    expect(resumeCount, 1);
    expect(repository.data?.savedAtMillis, 210);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.blocked);
    expect(coordinator.snapshot.issueCode, 'LOCAL_REBASE_APPLY_FAILED');
    expect(coordinator.snapshot.requiresGameReload, isFalse);
    coordinator.dispose();
    session.dispose();
  });

  test('revision 충돌은 pending 로컬을 백업한 뒤 최신 원격 진행으로 자동 복구한다', () async {
    final base = _saveData(300);
    final pending = _saveData(301);
    final remoteLatest = _saveData(400);
    final repository = _MemoryBackupSaveRepository(base);
    var remote = OnlineSaveSnapshot(
      revision: 1,
      serverSavedAt: DateTime.utc(2026, 8, 24, 1),
      data: base,
    );
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        load: (_) async => remote,
        update: (_, _) async {
          remote = OnlineSaveSnapshot(
            revision: 2,
            serverSavedAt: DateTime.utc(2026, 8, 24, 2),
            data: remoteLatest,
          );
          throw const OnlineSaveException(
            code: 'SAVE_REVISION_CONFLICT',
            message: 'conflict',
            statusCode: 409,
            currentRevision: 2,
          );
        },
      ),
      session: session,
      initialRevision: 1,
      outboxRepository: MemoryOnlineSaveOutboxRepository()
        ..state = OnlineSaveOutboxState.initial(
          accountId: _accountId,
          remoteRevision: 1,
        ).copyWith(lastSyncedPayloadFingerprint: onlineSavePayloadHash(base)),
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
      idempotencyKeyFactory: () => _idempotencyKey(1),
    );
    await coordinator.initialize();
    await repository.save(pending);

    await coordinator.enqueuePersistedCheckpoint(pending);
    await coordinator.currentAttempt;

    expect(repository.data?.savedAtMillis, 400);
    expect(repository.conflictBackups, hasLength(1));
    expect(repository.conflictBackups.single.data.savedAtMillis, 301);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    expect(coordinator.snapshot.remoteRevision, 2);
    expect(coordinator.snapshot.pendingSaveCount, 0);
    expect(coordinator.snapshot.requiresGameReload, isTrue);
    coordinator.dispose();
    session.dispose();
  });

  test('재시작 시 exact in-flight를 원격 조회보다 먼저 재전송한다', () async {
    final data = _saveData(500);
    final request = OnlineSaveUpdateRequest(
      expectedRevision: 1,
      idempotencyKey: _idempotencyKey(1),
      writerGeneration: 1,
      data: data,
    );
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 1,
          ).copyWith(
            payloadGeneration: 1,
            inFlight: OnlineSaveOutboxEntry(
              idempotencyKey: request.idempotencyKey,
              writerGeneration: request.writerGeneration,
              expectedRevision: 1,
              encodedRequestBody: request.encodedBody,
              payloadFingerprint: onlineSavePayloadHash(data),
              payloadGeneration: 1,
            ),
            phase: OnlineSaveOutboxPhase.sending,
          );
    final repository = _MemoryBackupSaveRepository(data);
    final operations = <String>[];
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        load: (_) async {
          operations.add('load');
          return OnlineSaveSnapshot(
            revision: 2,
            serverSavedAt: DateTime.utc(2026, 8, 24, 2),
            data: data,
          );
        },
        update: (_, restored) async {
          operations.add('update');
          expect(restored.encodedBody, request.encodedBody);
          expect(restored.idempotencyKey, request.idempotencyKey);
          return OnlineSaveUpdateResult(
            revision: 2,
            serverSavedAt: DateTime.utc(2026, 8, 24, 2),
          );
        },
      ),
      session: session,
      initialRevision: 1,
      outboxRepository: outbox,
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
    );

    await coordinator.initialize();
    await coordinator.currentAttempt;

    expect(operations, isNotEmpty);
    expect(operations.first, 'update');
    expect(outbox.state?.inFlight, isNull);
    expect(outbox.state?.baseRevision, 2);
    coordinator.dispose();
    session.dispose();
  });

  test('backupPreserved rebase journal은 재시작 뒤 원격 적용부터 이어간다', () async {
    final local = _saveData(600);
    final remote = _saveData(700);
    final remoteSavedAt = DateTime.utc(2026, 8, 24, 7);
    final repository = _MemoryBackupSaveRepository(local)
      ..conflictBackups.add(
        ConflictSaveBackup(
          rebaseId: 'preserved',
          accountId: _accountId,
          baseRevision: 1,
          targetRevision: 2,
          localPayloadHash: onlineSavePayloadHash(local),
          createdAt: DateTime.utc(2026, 8, 24, 6),
          data: local,
        ),
      );
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 1,
          ).copyWith(
            lastSyncedPayloadFingerprint: onlineSavePayloadHash(local),
            rebase: OnlineSaveRebaseJournal(
              targetRevision: 2,
              targetPayloadHash: onlineSavePayloadHash(remote),
              targetServerSavedAt: remoteSavedAt,
              sourcePayloadHash: onlineSavePayloadHash(local),
              stage: OnlineSaveRebaseStage.backupPreserved,
            ),
            phase: OnlineSaveOutboxPhase.rebasing,
          );
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        load: (_) async => OnlineSaveSnapshot(
          revision: 2,
          serverSavedAt: remoteSavedAt,
          data: remote,
        ),
        update: (_, _) async => _updateResult(3),
      ),
      session: session,
      initialRevision: 1,
      outboxRepository: outbox,
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
    );

    await coordinator.initialize();

    expect(repository.data?.savedAtMillis, 700);
    expect(repository.conflictBackups, hasLength(1));
    expect(outbox.state?.rebase, isNull);
    expect(outbox.state?.baseRevision, 2);
    coordinator.dispose();
    session.dispose();
  });

  test('payloadApplied journal은 로컬 hash 확인만으로 Outbox 기준을 복구한다', () async {
    final base = _saveData(800);
    final applied = _saveData(900);
    final appliedAt = DateTime.utc(2026, 8, 24, 9);
    final repository = _MemoryBackupSaveRepository(applied);
    var loadCount = 0;
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 1,
          ).copyWith(
            lastSyncedPayloadFingerprint: onlineSavePayloadHash(base),
            rebase: OnlineSaveRebaseJournal(
              targetRevision: 2,
              targetPayloadHash: onlineSavePayloadHash(applied),
              targetServerSavedAt: appliedAt,
              sourcePayloadHash: onlineSavePayloadHash(base),
              stage: OnlineSaveRebaseStage.payloadApplied,
            ),
            phase: OnlineSaveOutboxPhase.rebasing,
          );
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        load: (_) async {
          loadCount++;
          return null;
        },
        update: (_, _) async => _updateResult(3),
      ),
      session: session,
      initialRevision: 1,
      outboxRepository: outbox,
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
    );

    await coordinator.initialize();

    expect(loadCount, 0);
    expect(outbox.state?.rebase, isNull);
    expect(outbox.state?.baseRevision, 2);
    expect(outbox.state?.dirty, isFalse);
    expect(coordinator.snapshot.requiresGameReload, isTrue);
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
      outboxRepository: MemoryOnlineSaveOutboxRepository(),
      loadPersistedCheckpoint: () async => null,
      idempotencyKeyFactory: () => _idempotencyKey(1),
      timerFactory: timerFactory.create,
    );
    await coordinator.initialize();

    await coordinator.enqueuePersistedCheckpoint(_saveData(40));
    await coordinator.currentAttempt;

    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.blocked);
    expect(coordinator.snapshot.issueCode, 'INVALID_SAVE_DATA');
    expect(timerFactory.createCount, 0);
    coordinator.dispose();
    session.dispose();
  });

  test('구버전 writer 획득은 로컬 저장을 멈추고 요청을 보존한다', () async {
    final outbox = MemoryOnlineSaveOutboxRepository();
    var quiesceCount = 0;
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        claimWriter: (_, _) async => throw const OnlineSaveException(
          code: 'CLIENT_UPDATE_REQUIRED',
          message: 'update required',
          statusCode: 426,
        ),
        update: (_, _) async => _updateResult(1),
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => null,
      beforeRemoteRebase: () async {
        quiesceCount++;
      },
      writerClaimIdempotencyKeyFactory: () => _idempotencyKey(70),
      clientInstanceIdFactory: () => _idempotencyKey(71),
    );

    await coordinator.initialize();

    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.blocked);
    expect(coordinator.snapshot.issueCode, 'CLIENT_UPDATE_REQUIRED');
    expect(outbox.state?.writerClaim, isNotNull);
    expect(outbox.state?.writerGeneration, isNull);
    expect(quiesceCount, 1);
    coordinator.dispose();
    session.dispose();
  });

  test('구버전 저장 요청은 in-flight를 보존한 채 로컬 저장을 멈춘다', () async {
    final persistedData = _saveData(45);
    final outbox = MemoryOnlineSaveOutboxRepository();
    var quiesceCount = 0;
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, _) async => throw const OnlineSaveException(
          code: 'CLIENT_UPDATE_REQUIRED',
          message: 'update required',
          statusCode: 426,
        ),
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => persistedData,
      beforeRemoteRebase: () async {
        quiesceCount++;
      },
      idempotencyKeyFactory: () => _idempotencyKey(72),
    );

    await coordinator.initialize();
    await coordinator.currentAttempt;

    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.blocked);
    expect(coordinator.snapshot.issueCode, 'CLIENT_UPDATE_REQUIRED');
    expect(outbox.state?.inFlight, isNotNull);
    expect(outbox.state?.dirty, isFalse);
    expect(quiesceCount, 1);
    coordinator.dispose();
    session.dispose();
  });

  test('업데이트 뒤 이전 writer claim은 폐기하고 현재 버전으로 다시 획득한다', () async {
    final legacyClaim = OnlineSaveWriterClaimRequest(
      idempotencyKey: _idempotencyKey(73),
      clientInstanceId: _idempotencyKey(74),
      clientBuild: 'previous-build',
      clientCompatibilityVersion: 1,
    );
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 0,
          ).copyWith(
            clientInstanceId: legacyClaim.clientInstanceId,
            writerClaim: OnlineSaveWriterClaimEntry(
              idempotencyKey: legacyClaim.idempotencyKey,
              encodedRequestBody: legacyClaim.encodedBody,
            ),
            phase: OnlineSaveOutboxPhase.blocked,
            issueCode: 'CLIENT_UPDATE_REQUIRED',
          );
    final claims = <OnlineSaveWriterClaimRequest>[];
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        claimWriter: (_, request) async {
          claims.add(request);
          return OnlineSaveWriterClaimResult(
            writerGeneration: 8,
            claimedAt: DateTime.utc(2026, 8, 28),
          );
        },
        update: (_, _) async => _updateResult(1),
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => null,
      writerClaimIdempotencyKeyFactory: () => _idempotencyKey(75),
      clientCompatibilityVersion: 2,
    );

    await coordinator.initialize();

    expect(claims, hasLength(1));
    expect(claims.single.clientCompatibilityVersion, 2);
    expect(claims.single.idempotencyKey, _idempotencyKey(75));
    expect(claims.single.idempotencyKey, isNot(legacyClaim.idempotencyKey));
    expect(outbox.state?.writerClaim, isNull);
    expect(outbox.state?.writerGeneration, 8);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    coordinator.dispose();
    session.dispose();
  });

  test('업데이트 전 in-flight가 이미 저장됐으면 exact 영수증으로 완료한다', () async {
    final data = _saveData(46);
    final legacyUpdate = OnlineSaveUpdateRequest(
      expectedRevision: 0,
      idempotencyKey: _idempotencyKey(76),
      writerGeneration: 7,
      data: data,
      clientCompatibilityVersion: 1,
    );
    final repository = _MemoryBackupSaveRepository(data);
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 0,
          ).copyWith(
            clientInstanceId: _idempotencyKey(77),
            writerGeneration: legacyUpdate.writerGeneration,
            payloadGeneration: 1,
            inFlight: OnlineSaveOutboxEntry(
              idempotencyKey: legacyUpdate.idempotencyKey,
              writerGeneration: legacyUpdate.writerGeneration,
              expectedRevision: legacyUpdate.expectedRevision,
              encodedRequestBody: legacyUpdate.encodedBody,
              payloadFingerprint: onlineSavePayloadHash(data),
              payloadGeneration: 1,
            ),
            phase: OnlineSaveOutboxPhase.blocked,
            issueCode: 'CLIENT_UPDATE_REQUIRED',
          );
    final updates = <OnlineSaveUpdateRequest>[];
    final claims = <OnlineSaveWriterClaimRequest>[];
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        claimWriter: (_, request) async {
          claims.add(request);
          return OnlineSaveWriterClaimResult(
            writerGeneration: 8,
            claimedAt: DateTime.utc(2026, 8, 28),
          );
        },
        load: (_) async => OnlineSaveSnapshot(
          revision: 1,
          serverSavedAt: DateTime.utc(2026, 8, 28),
          data: data,
        ),
        update: (_, request) async {
          updates.add(request);
          return _updateResult(1);
        },
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
      writerClaimIdempotencyKeyFactory: () => _idempotencyKey(78),
      clientCompatibilityVersion: 2,
    );

    await coordinator.initialize();
    await coordinator.currentAttempt;

    expect(updates, hasLength(1));
    expect(updates.single.clientCompatibilityVersion, 1);
    expect(updates.single.idempotencyKey, legacyUpdate.idempotencyKey);
    expect(updates.single.encodedBody, legacyUpdate.encodedBody);
    expect(claims.single.clientCompatibilityVersion, 2);
    expect(outbox.state?.inFlight, isNull);
    expect(outbox.state?.remoteRevision, 1);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    coordinator.dispose();
    session.dispose();
  });

  test('업데이트 전 in-flight 영수증이 없으면 현재 버전 요청으로 다시 저장한다', () async {
    final data = _saveData(47);
    final legacyUpdate = OnlineSaveUpdateRequest(
      expectedRevision: 0,
      idempotencyKey: _idempotencyKey(79),
      writerGeneration: 7,
      data: data,
      clientCompatibilityVersion: 1,
    );
    final repository = _MemoryBackupSaveRepository(data);
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 0,
          ).copyWith(
            clientInstanceId: _idempotencyKey(80),
            writerGeneration: legacyUpdate.writerGeneration,
            payloadGeneration: 1,
            inFlight: OnlineSaveOutboxEntry(
              idempotencyKey: legacyUpdate.idempotencyKey,
              writerGeneration: legacyUpdate.writerGeneration,
              expectedRevision: legacyUpdate.expectedRevision,
              encodedRequestBody: legacyUpdate.encodedBody,
              payloadFingerprint: onlineSavePayloadHash(data),
              payloadGeneration: 1,
            ),
            phase: OnlineSaveOutboxPhase.blocked,
            issueCode: 'CLIENT_UPDATE_REQUIRED',
          );
    final updates = <OnlineSaveUpdateRequest>[];
    final claims = <OnlineSaveWriterClaimRequest>[];
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        claimWriter: (_, request) async {
          claims.add(request);
          return OnlineSaveWriterClaimResult(
            writerGeneration: 8,
            claimedAt: DateTime.utc(2026, 8, 28),
          );
        },
        load: (_) async => null,
        update: (_, request) async {
          updates.add(request);
          if (request.clientCompatibilityVersion == 1) {
            throw const OnlineSaveException(
              code: 'CLIENT_UPDATE_REQUIRED',
              message: 'receipt missing',
              statusCode: 426,
            );
          }
          return _updateResult(1);
        },
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
      idempotencyKeyFactory: () => _idempotencyKey(82),
      writerClaimIdempotencyKeyFactory: () => _idempotencyKey(81),
      clientCompatibilityVersion: 2,
    );

    await coordinator.initialize();
    await _pumpUntil(() => updates.length == 2);
    await coordinator.currentAttempt;

    expect(updates.first.clientCompatibilityVersion, 1);
    expect(updates.first.idempotencyKey, legacyUpdate.idempotencyKey);
    expect(updates.first.encodedBody, legacyUpdate.encodedBody);
    expect(updates.last.clientCompatibilityVersion, 2);
    expect(updates.last.idempotencyKey, _idempotencyKey(82));
    expect(updates.last.idempotencyKey, isNot(legacyUpdate.idempotencyKey));
    expect(updates.last.data.savedAtMillis, data.savedAtMillis);
    expect(claims.single.clientCompatibilityVersion, 2);
    expect(outbox.state?.inFlight, isNull);
    expect(outbox.state?.remoteRevision, 1);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    coordinator.dispose();
    session.dispose();
  });

  test('앱 재시작 뒤에도 같은 본문과 멱등성 key로 in-flight를 재시도한다', () async {
    final now = DateTime.utc(2026, 8, 24, 3);
    final persistedData = _saveData(50);
    final outbox = MemoryOnlineSaveOutboxRepository();
    final firstTimers = _ManualTimerFactory();
    final firstRequests = <OnlineSaveUpdateRequest>[];
    final firstSession = _session();
    final firstCoordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, request) async {
          firstRequests.add(request);
          throw const OnlineSaveException(
            code: 'SAVE_NETWORK_ERROR',
            message: 'offline',
            transportFailure: true,
            retryAfter: Duration(seconds: 1),
          );
        },
      ),
      session: firstSession,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => persistedData,
      idempotencyKeyFactory: () => _idempotencyKey(1),
      timerFactory: firstTimers.create,
      now: () => now,
    );

    await firstCoordinator.initialize();
    await firstCoordinator.currentAttempt;

    expect(firstRequests, hasLength(1));
    expect(outbox.state?.inFlight, isNotNull);
    expect(outbox.state?.phase, OnlineSaveOutboxPhase.retryWaiting);
    final persistedBody = outbox.state!.inFlight!.encodedRequestBody;
    final persistedKey = outbox.state!.inFlight!.idempotencyKey;
    firstCoordinator.dispose();
    firstSession.dispose();

    final restoredTimers = _ManualTimerFactory();
    final restoredRequests = <OnlineSaveUpdateRequest>[];
    final restoredSession = _session();
    final restoredCoordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, request) async {
          restoredRequests.add(request);
          return _updateResult(1);
        },
      ),
      session: restoredSession,
      initialRevision: 99,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => persistedData,
      idempotencyKeyFactory: () => throw StateError('새 key를 만들면 안 됩니다.'),
      timerFactory: restoredTimers.create,
      now: () => now,
    );

    await restoredCoordinator.initialize();

    expect(restoredRequests, isEmpty);
    expect(restoredTimers.lastDuration, const Duration(seconds: 1));
    restoredTimers.lastTimer!.fire();
    await _pumpUntil(() => restoredRequests.length == 1);
    await restoredCoordinator.currentAttempt;

    expect(restoredRequests.single.encodedBody, persistedBody);
    expect(restoredRequests.single.idempotencyKey, persistedKey);
    expect(restoredCoordinator.snapshot.remoteRevision, 1);
    expect(restoredCoordinator.snapshot.pendingSaveCount, 0);
    restoredCoordinator.dispose();
    restoredSession.dispose();
  });

  test('로컬 저장과 metadata 기록 사이 종료도 시작 시 dirty로 복구한다', () async {
    final syncedData = _saveData(60);
    final latestData = _saveData(61);
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state =
          OnlineSaveOutboxState.initial(
            accountId: _accountId,
            remoteRevision: 3,
          ).copyWith(
            lastSyncedPayloadFingerprint: onlineSavePayloadFingerprint(
              syncedData,
            ),
            payloadGeneration: 1,
          );
    final requests = <OnlineSaveUpdateRequest>[];
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, request) async {
          requests.add(request);
          return _updateResult(4);
        },
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => latestData,
      idempotencyKeyFactory: () => _idempotencyKey(4),
    );

    await coordinator.initialize();
    await _pumpUntil(() => requests.length == 1);
    await coordinator.currentAttempt;

    expect(_savedAtMillis(requests.single), 61);
    expect(coordinator.snapshot.remoteRevision, 4);
    expect(outbox.state?.dirty, isFalse);
    expect(
      outbox.state?.lastSyncedPayloadFingerprint,
      onlineSavePayloadFingerprint(latestData),
    );
    coordinator.dispose();
    session.dispose();
  });

  test('Outbox 영속화가 끝나기 전에는 HTTP 요청을 시작하지 않는다', () async {
    final outbox = _BlockingOutboxRepository(
      OnlineSaveOutboxState.initial(accountId: _accountId, remoteRevision: 0),
    );
    var updateCount = 0;
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        update: (_, _) async {
          updateCount++;
          return _updateResult(1);
        },
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => null,
      idempotencyKeyFactory: () => _idempotencyKey(1),
    );
    await coordinator.initialize();
    outbox.blockNextSave();

    final enqueue = coordinator.saveRoundCheckpoint(_saveData(70));
    await outbox.saveStarted.future;

    expect(updateCount, 0);
    outbox.releaseSave();
    await enqueue;
    await _pumpUntil(() => updateCount == 1);
    await coordinator.currentAttempt;

    expect(coordinator.snapshot.remoteRevision, 1);
    coordinator.dispose();
    session.dispose();
  });

  test('writer 획득 응답 유실 뒤에도 같은 본문과 key로 재확인한다', () async {
    final now = DateTime.utc(2026, 8, 26, 3);
    final outbox = MemoryOnlineSaveOutboxRepository();
    final firstTimer = _ManualTimerFactory();
    late OnlineSaveWriterClaimRequest firstRequest;
    final firstSession = _session();
    final firstCoordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        claimWriter: (_, request) async {
          firstRequest = request;
          throw const OnlineSaveException(
            code: 'SAVE_NETWORK_ERROR',
            message: 'offline',
            transportFailure: true,
          );
        },
        update: (_, _) async => _updateResult(1),
      ),
      session: firstSession,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => null,
      writerClaimIdempotencyKeyFactory: () => _idempotencyKey(90),
      clientInstanceIdFactory: () => _idempotencyKey(91),
      timerFactory: firstTimer.create,
      now: () => now,
    );

    await firstCoordinator.initialize();

    expect(outbox.state?.writerClaim, isNotNull);
    expect(outbox.state?.phase, OnlineSaveOutboxPhase.retryWaiting);
    final persistedBody = outbox.state!.writerClaim!.encodedRequestBody;
    final persistedKey = outbox.state!.writerClaim!.idempotencyKey;
    firstCoordinator.dispose();
    firstSession.dispose();

    final restoredTimer = _ManualTimerFactory();
    late OnlineSaveWriterClaimRequest restoredRequest;
    final restoredSession = _session();
    final restoredCoordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        claimWriter: (_, request) async {
          restoredRequest = request;
          return OnlineSaveWriterClaimResult(
            writerGeneration: 4,
            claimedAt: now,
          );
        },
        update: (_, _) async => _updateResult(1),
      ),
      session: restoredSession,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: () async => null,
      writerClaimIdempotencyKeyFactory: () =>
          throw StateError('새 writer key를 만들면 안 됩니다.'),
      timerFactory: restoredTimer.create,
      now: () => now,
    );

    await restoredCoordinator.initialize();
    restoredTimer.lastTimer!.fire();
    await _pumpUntil(() => outbox.state?.writerGeneration == 4);

    expect(firstRequest.encodedBody, persistedBody);
    expect(restoredRequest.encodedBody, persistedBody);
    expect(restoredRequest.idempotencyKey, persistedKey);
    expect(outbox.state?.writerClaim, isNull);
    restoredCoordinator.dispose();
    restoredSession.dispose();
  });

  test('교체된 writer는 자동 탈환하지 않고 foreground 복귀 때 새 generation으로 저장한다', () async {
    final base = _saveData(1000);
    final pending = _saveData(1001);
    final repository = _MemoryBackupSaveRepository(base);
    final outbox = MemoryOnlineSaveOutboxRepository()
      ..state = OnlineSaveOutboxState.initial(
        accountId: _accountId,
        remoteRevision: 0,
      ).copyWith(lastSyncedPayloadFingerprint: onlineSavePayloadHash(base));
    var claimCount = 0;
    var quiesceCount = 0;
    var resumeCount = 0;
    final requests = <OnlineSaveUpdateRequest>[];
    final session = _session();
    final coordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: _FakeOnlineSaveClient(
        claimWriter: (_, _) async {
          claimCount++;
          return OnlineSaveWriterClaimResult(
            writerGeneration: claimCount,
            claimedAt: DateTime.utc(2026, 8, 26, claimCount),
          );
        },
        load: (_) async => null,
        update: (_, request) async {
          requests.add(request);
          if (requests.length == 1) {
            throw const OnlineSaveException(
              code: 'SAVE_WRITER_REPLACED',
              message: 'replaced',
              statusCode: 409,
              currentWriterGeneration: 2,
            );
          }
          return _updateResult(1);
        },
      ),
      session: session,
      initialRevision: 0,
      outboxRepository: outbox,
      loadPersistedCheckpoint: repository.load,
      persistedSaveRepository: repository,
      idempotencyKeyFactory: () => _idempotencyKey(requests.length + 1),
      writerClaimIdempotencyKeyFactory: () => _idempotencyKey(100 + claimCount),
      clientInstanceIdFactory: () => _idempotencyKey(110),
      beforeRemoteRebase: () async {
        quiesceCount++;
      },
      resumeLocalSaves: () {
        resumeCount++;
      },
    );
    await coordinator.initialize();
    await repository.save(pending);

    await coordinator.enqueuePersistedCheckpoint(pending);
    await coordinator.currentAttempt;

    expect(claimCount, 1);
    expect(requests.single.writerGeneration, 1);
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.suspended);
    expect(quiesceCount, 1);
    expect(resumeCount, 0);

    await coordinator.resumeForeground();
    await coordinator.currentAttempt;

    expect(claimCount, 2);
    expect(requests, hasLength(2));
    expect(requests.last.writerGeneration, 2);
    expect(requests.last.idempotencyKey, isNot(requests.first.idempotencyKey));
    expect(coordinator.snapshot.phase, OnlineSaveCoordinatorPhase.idle);
    expect(coordinator.snapshot.remoteRevision, 1);
    expect(quiesceCount, 1);
    expect(resumeCount, 1);
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
    Future<OnlineSaveWriterClaimResult> Function(
      String accessToken,
      OnlineSaveWriterClaimRequest request,
    )?
    claimWriter,
    Future<OnlineSaveSnapshot?> Function(String accessToken)? load,
    required Future<OnlineSaveUpdateResult> Function(
      String accessToken,
      OnlineSaveUpdateRequest request,
    )
    update,
  }) : _claimWriter = claimWriter,
       _load = load,
       _update = update;

  final Future<OnlineSaveWriterClaimResult> Function(
    String accessToken,
    OnlineSaveWriterClaimRequest request,
  )?
  _claimWriter;

  final Future<OnlineSaveSnapshot?> Function(String accessToken)? _load;

  final Future<OnlineSaveUpdateResult> Function(
    String accessToken,
    OnlineSaveUpdateRequest request,
  )
  _update;

  @override
  Future<OnlineSaveWriterClaimResult> claimWriter(
    String accessToken,
    OnlineSaveWriterClaimRequest request,
  ) async {
    return _claimWriter?.call(accessToken, request) ??
        OnlineSaveWriterClaimResult(
          writerGeneration: 1,
          claimedAt: DateTime.utc(2026, 8, 24),
        );
  }

  @override
  Future<OnlineSaveSnapshot?> load(String accessToken) async {
    return _load?.call(accessToken);
  }

  @override
  Future<OnlineSaveUpdateResult> update(
    String accessToken,
    OnlineSaveUpdateRequest request,
  ) {
    return _update(accessToken, request);
  }
}

class _MemoryBackupSaveRepository implements BackupSaveRepository {
  _MemoryBackupSaveRepository(this.data);

  GameSaveData? data;
  GameSaveData? backup;
  bool failNextSave = false;
  final List<ConflictSaveBackup> conflictBackups = [];

  @override
  Future<GameSaveData?> load() async => data;

  @override
  Future<void> save(GameSaveData data) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    backup = this.data;
    this.data = data;
  }

  @override
  Future<void> preserveCurrentAsBackup() async {
    backup = data;
  }

  @override
  Future<void> preserveConflictBackup(ConflictSaveBackup backup) async {
    if (conflictBackups.any((current) => current.rebaseId == backup.rebaseId)) {
      return;
    }
    conflictBackups.add(backup);
  }

  @override
  Future<void> clear() async {
    data = null;
    backup = null;
    conflictBackups.clear();
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

class _BlockingOutboxRepository implements OnlineSaveOutboxRepository {
  _BlockingOutboxRepository(this.state);

  OnlineSaveOutboxState? state;
  Completer<void> saveStarted = Completer<void>();
  Completer<void>? _saveGate;

  void blockNextSave() {
    saveStarted = Completer<void>();
    _saveGate = Completer<void>();
  }

  void releaseSave() {
    _saveGate?.complete();
  }

  @override
  Future<OnlineSaveOutboxState?> load() async => state;

  @override
  Future<void> save(OnlineSaveOutboxState state) async {
    final gate = _saveGate;
    if (gate != null) {
      if (!saveStarted.isCompleted) {
        saveStarted.complete();
      }
      await gate.future;
      _saveGate = null;
    }
    this.state = state;
  }

  @override
  Future<void> clear() async {
    state = null;
  }
}
