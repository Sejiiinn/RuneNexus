import 'dart:async';
import 'dart:convert';

import '../../domain/economy/authoritative_economy_commands.dart';
import '../../domain/economy/economy_snapshot.dart';
import '../../domain/daily_quest/daily_quest_type.dart';
import '../../domain/research/research_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';
import '../../game/rune_nexus_game.dart';
import '../auth/online_account_session_controller.dart';
import '../save/online_save_api.dart';
import '../save/online_save_coordinator.dart';
import 'economy_api.dart';
import 'economy_command_outbox.dart';
import 'economy_command_outbox_repository.dart';

class EconomyCoordinator implements AuthoritativeEconomyCommands {
  EconomyCoordinator({
    required this.accountId,
    required EconomyApi api,
    required OnlineAccountSessionController session,
    required OnlineSaveCoordinator saveCoordinator,
    required EconomyCommandOutboxRepository outboxRepository,
    required RuneNexusGame game,
  }) : _api = api,
       _session = session,
       _saveCoordinator = saveCoordinator,
       _repository = outboxRepository,
       _game = game;

  final String accountId;
  final EconomyApi _api;
  final OnlineAccountSessionController _session;
  final OnlineSaveCoordinator _saveCoordinator;
  final EconomyCommandOutboxRepository _repository;
  RuneNexusGame _game;

  EconomyCommandOutboxState? _state;
  EconomySnapshot? _snapshot;
  Future<void> _serial = Future<void>.value();
  bool _userCommandPending = false;
  bool _disposed = false;

  EconomySnapshot? get snapshot => _snapshot;

  Future<void> initialize() => _serialized(() async {
    final restored = await _repository.load();
    if (restored != null &&
        restored.accountIdBinding != accountId.toLowerCase()) {
      throw StateError('경제 Outbox와 인증 계정이 일치하지 않습니다.');
    }
    _state = restored ?? EconomyCommandOutboxState.initial(accountId);

    final inFlight = _state!.inFlight;
    if (inFlight != null) {
      await _retryInFlight(inFlight);
    }
    await _loadOrBootstrap();
    await _applyPendingEffects();
    await _drainPendingRunRewards();
  });

  Future<void> refresh() => _serialized(() async {
    _ensureReady();
    await _loadAndApply();
    await _applyPendingEffects();
    await _drainPendingRunRewards();
  });

  Future<void> rebindGame(RuneNexusGame replacement) => _serialized(() async {
    _ensureReady();
    final previous = _game;
    replacement.attachAuthoritativeEconomyCommands(this);
    _game = replacement;
    try {
      final inFlight = _state!.inFlight;
      if (inFlight != null) {
        await _retryInFlight(inFlight);
      }
      await _loadAndApply();
      await _applyPendingEffects();
      await _drainPendingRunRewards();
    } on Object {
      _game = previous;
      replacement.detachAuthoritativeEconomyCommands();
      rethrow;
    }
    previous.detachAuthoritativeEconomyCommands();
  }, recoverPendingWork: false);

  void handleSaveSnapshotChanged(OnlineSaveCoordinatorSnapshot snapshot) {
    final ready =
        snapshot.phase == OnlineSaveCoordinatorPhase.idle &&
        snapshot.pendingSaveCount == 0 &&
        !snapshot.hasPendingRemoteRebase &&
        !snapshot.requiresGameReload;
    if (!ready || _disposed || _state == null) {
      return;
    }
    unawaited(
      _serialized(() async {
        await _applyPendingEffects();
        await _drainPendingRunRewards();
      }).catchError((_) {}),
    );
  }

  @override
  Future<List<TurretModuleInventoryItem>> drawTurretModules(
    int count, {
    required TurretType turretType,
    required bool buyMissingTicketsWithDiamonds,
  }) => _userCommand(() async {
    await _requireSyncedSave();
    final current = _requireSnapshot();
    final result = await _execute(
      kind: 'draw_modules',
      path: 'v1/economy/turret-modules/draw',
      body: {
        'expectedEconomyRevision': current.revision,
        'expectedCatalogVersion': current.catalogVersion,
        'sourceSaveRevision': _saveCoordinator.snapshot.remoteRevision,
        'writerGeneration': _requireWriterGeneration(),
        'count': count,
        'turretType': turretType.name,
        'buyMissingTicketsWithDiamonds': buyMissingTicketsWithDiamonds,
        'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
      },
    );
    return result.drawnModules
        .map(
          (module) => TurretModuleInventoryItem(
            id: module.id,
            key: module.key,
            options: module.options,
            acquiredOrder: module.acquiredOrder,
            equipped: false,
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<bool> disassembleTurretModules(Iterable<String> ids) =>
      _userCommand(() async {
        final moduleIds = ids.toSet().toList(growable: false)..sort();
        if (moduleIds.isEmpty) {
          return false;
        }
        final current = _requireSnapshot();
        await _execute(
          kind: 'disassemble_modules',
          path: 'v1/economy/turret-modules/disassemble',
          body: {
            'expectedEconomyRevision': current.revision,
            'expectedCatalogVersion': current.catalogVersion,
            'moduleIds': moduleIds,
            'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
          },
        );
        return true;
      });

  @override
  Future<bool> completeResearchWithDiamonds(ResearchType type) =>
      _userCommand(() async {
        await _requireSyncedSave();
        final current = _requireSnapshot();
        final result = await _execute(
          kind: 'complete_research',
          path: 'v1/economy/researches/${type.name}/complete',
          body: _progressionCommandBody(current),
        );
        await _applyEffect(result.progressionEffect);
        await _applyPendingEffects();
        return true;
      });

  @override
  Future<bool> unlockResearchSlotTwo() => _userCommand(() async {
    await _requireSyncedSave();
    final current = _requireSnapshot();
    await _execute(
      kind: 'unlock_research_slot_two',
      path: 'v1/economy/research-slots/2/unlock',
      body: _progressionCommandBody(current),
    );
    return true;
  });

  @override
  Future<bool> claimDailyQuestReward(DailyQuestType type) =>
      _claimDailyReward('quest', questType: type);

  @override
  Future<bool> claimDailyQuestAllCompleteReward() =>
      _claimDailyReward('all_complete');

  @override
  Future<bool> claimDailyAttendanceReward() => _claimDailyReward('attendance');

  @override
  Future<void> queueRunSettlement({
    required String runId,
    required int stageNumber,
    required int completedRounds,
    required bool success,
    required int pendingDiamonds,
    required int firstClearModuleTickets,
  }) => _serialized(() async {
    _ensureReady();
    if (_state!.pendingRewards.any((reward) => reward.runId == runId)) {
      await _drainPendingRunRewards();
      return;
    }
    final reward = EconomyPendingRunReward(
      runId: runId,
      stageNumber: stageNumber,
      completedRounds: completedRounds,
      success: success,
      pendingDiamonds: pendingDiamonds,
      firstClearModuleTickets: firstClearModuleTickets,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    _state = _state!.copyWith(
      pendingRewards: [..._state!.pendingRewards, reward],
    );
    await _repository.save(_state!);
    await _drainPendingRunRewards();
  });

  void dispose() {
    _disposed = true;
    _game.detachAuthoritativeEconomyCommands();
  }

  Map<String, Object> _progressionCommandBody(EconomySnapshot current) => {
    'expectedEconomyRevision': current.revision,
    'expectedCatalogVersion': current.catalogVersion,
    'sourceSaveRevision': _saveCoordinator.snapshot.remoteRevision,
    'writerGeneration': _requireWriterGeneration(),
    'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
  };

  Future<void> _loadOrBootstrap() async {
    try {
      await _loadAndApply();
    } on EconomyException catch (error) {
      if (error.code != 'ECONOMY_NOT_BOOTSTRAPPED') {
        rethrow;
      }
      await _requireSyncedSave();
      final command = EconomyPendingCommand(
        kind: 'bootstrap',
        path: 'v1/economy/bootstrap',
        idempotencyKey: createOnlineSaveIdempotencyKey(),
        encodedBody: jsonEncode({
          'expectedSaveRevision': _saveCoordinator.snapshot.remoteRevision,
          'writerGeneration': _requireWriterGeneration(),
          'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
        }),
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _setInFlight(command);
      try {
        final result = await _session.runAuthenticated(
          request: (token) => _api.bootstrap(
            token,
            idempotencyKey: command.idempotencyKey,
            encodedBody: command.encodedBody,
          ),
          isUnauthorized: _isUnauthorized,
        );
        await _applySnapshot(result.snapshot);
        await _clearInFlight(command);
      } on Object catch (error) {
        if (_isDefinitive(error)) {
          await _clearInFlight(command);
        }
        rethrow;
      }
    }
  }

  Future<void> _loadAndApply() async {
    final loaded = await _session.runAuthenticated(
      request: _api.load,
      isUnauthorized: _isUnauthorized,
    );
    await _applySnapshot(loaded);
  }

  Future<EconomyCommandResult> _execute({
    required String kind,
    required String path,
    required Map<String, Object?> body,
  }) async {
    final command = EconomyPendingCommand(
      kind: kind,
      path: path,
      idempotencyKey: createOnlineSaveIdempotencyKey(),
      encodedBody: jsonEncode(body),
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _setInFlight(command);
    try {
      final result = await _send(command);
      await _applySnapshot(result.snapshot);
      await _clearInFlight(command);
      return result;
    } on Object catch (error) {
      if (_isDefinitive(error)) {
        await _clearInFlight(command);
        if (error is EconomyException &&
            (error.code == 'ECONOMY_REVISION_CONFLICT' ||
                error.code == 'ECONOMY_CATALOG_CHANGED')) {
          await _loadAndApply();
        }
      }
      rethrow;
    }
  }

  Future<EconomyCommandResult> _send(EconomyPendingCommand command) =>
      _session.runAuthenticated(
        request: (token) => _api.execute(
          token,
          path: command.path,
          idempotencyKey: command.idempotencyKey,
          encodedBody: command.encodedBody,
        ),
        isUnauthorized: _isUnauthorized,
      );

  Future<void> _retryInFlight(EconomyPendingCommand command) async {
    EconomyProgressionEffect? recoveredEffect;
    var completed = false;
    try {
      if (command.kind == 'bootstrap') {
        final result = await _session.runAuthenticated(
          request: (token) => _api.bootstrap(
            token,
            idempotencyKey: command.idempotencyKey,
            encodedBody: command.encodedBody,
          ),
          isUnauthorized: _isUnauthorized,
        );
        await _applySnapshot(result.snapshot);
      } else if (command.kind == 'daily_reward') {
        await _sendDailyReward(command);
      } else {
        final result = await _send(command);
        await _applySnapshot(result.snapshot);
        recoveredEffect = result.progressionEffect;
      }
      completed = true;
    } on Object catch (error) {
      if (command.kind == 'run_settlement' && _isRebindableRunError(error)) {
        await _clearInFlight(command);
        return;
      }
      if (_isDefinitive(error)) {
        await _clearInFlight(command);
        if (command.kind == 'run_settlement') {
          final decoded = jsonDecode(command.encodedBody);
          final runId = decoded is Map<String, dynamic>
              ? decoded['runId'] as String?
              : null;
          if (runId != null) {
            await _removePendingRunReward(runId);
          }
          return;
        }
      }
      rethrow;
    }
    await _clearInFlight(command);
    if (completed && recoveredEffect != null) {
      await _applyEffect(recoveredEffect);
    }
    if (command.kind == 'run_settlement') {
      final decoded = jsonDecode(command.encodedBody);
      final runId = decoded is Map<String, dynamic>
          ? decoded['runId'] as String?
          : null;
      if (runId != null) {
        await _removePendingRunReward(runId);
      }
    }
  }

  Future<bool> _claimDailyReward(
    String rewardType, {
    DailyQuestType? questType,
  }) => _userCommand(() async {
    await _requireSyncedSave();
    final command = EconomyPendingCommand(
      kind: 'daily_reward',
      path: 'v1/economy/rewards/claim',
      idempotencyKey: createOnlineSaveIdempotencyKey(),
      encodedBody: jsonEncode({
        'period': 'daily',
        'rewardType': rewardType,
        if (questType != null) 'questType': questType.name,
        'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
      }),
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _setInFlight(command);
    try {
      await _sendDailyReward(command);
      await _clearInFlight(command);
      return true;
    } on Object catch (error) {
      if (_isDefinitive(error)) {
        await _clearInFlight(command);
      }
      rethrow;
    }
  });

  Future<void> _sendDailyReward(EconomyPendingCommand command) async {
    final body = jsonDecode(command.encodedBody);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('일일 보상 Outbox 본문이 올바르지 않습니다.');
    }
    final rewardType = body['rewardType'];
    final questName = body['questType'];
    DailyQuestType? questType;
    for (final candidate in DailyQuestType.values) {
      if (candidate.name == questName) {
        questType = candidate;
        break;
      }
    }
    if (rewardType is! String || (rewardType == 'quest' && questType == null)) {
      throw const FormatException('일일 보상 Outbox 대상이 올바르지 않습니다.');
    }
    final dayKey = await _session.runAuthenticated(
      request: (token) => _api.claimReward(
        token,
        idempotencyKey: command.idempotencyKey,
        encodedBody: command.encodedBody,
      ),
      isUnauthorized: _isUnauthorized,
    );
    await _game.applyAuthoritativeDailyRewardReceipt(
      rewardType: rewardType,
      questType: questType,
      dayKey: dayKey,
    );
    await _loadAndApply();
  }

  Future<void> _drainPendingRunRewards() async {
    while (_state!.pendingRewards.isNotEmpty) {
      final reward = _state!.pendingRewards.first;
      try {
        await _requireSyncedSave();
      } on StateError {
        return;
      }
      final command = EconomyPendingCommand(
        kind: 'run_settlement',
        path: 'v1/economy/runs/settle',
        idempotencyKey: createOnlineSaveIdempotencyKey(),
        encodedBody: jsonEncode({
          'runId': reward.runId,
          'writerGeneration': _requireWriterGeneration(),
          'sourceSaveRevision': _saveCoordinator.snapshot.remoteRevision,
          'stageNumber': reward.stageNumber,
          'completedRounds': reward.completedRounds,
          'success': reward.success,
          'pendingDiamonds': reward.pendingDiamonds,
          'firstClearModuleTickets': reward.firstClearModuleTickets,
          'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
        }),
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _setInFlight(command);
      try {
        final result = await _send(command);
        await _applySnapshot(result.snapshot);
        await _clearInFlight(command);
        await _removePendingRunReward(reward.runId);
      } on Object catch (error) {
        if (_isRebindableRunError(error)) {
          await _clearInFlight(command);
          return;
        }
        if (_isDefinitive(error)) {
          await _clearInFlight(command);
          await _removePendingRunReward(reward.runId);
          return;
        }
        if (error is EconomyException) {
          return;
        }
        rethrow;
      }
    }
  }

  Future<void> _removePendingRunReward(String runId) async {
    final remaining = _state!.pendingRewards
        .where((reward) => reward.runId != runId)
        .toList(growable: false);
    if (remaining.length == _state!.pendingRewards.length) {
      return;
    }
    _state = _state!.copyWith(pendingRewards: remaining);
    await _repository.save(_state!);
  }

  Future<void> _applySnapshot(EconomySnapshot next) async {
    final current = _snapshot;
    if (current != null &&
        current.authorityEpoch == next.authorityEpoch &&
        next.revision < current.revision) {
      return;
    }
    _snapshot = next;
    await _game.applyAuthoritativeEconomy(next);
  }

  Future<void> _applyPendingEffects() async {
    final effects = List.of(_snapshot?.pendingProgressionEffects ?? const []);
    for (final effect in effects) {
      await _applyEffect(effect);
    }
  }

  Future<void> _applyEffect(EconomyProgressionEffect? effect) async {
    if (effect == null) {
      return;
    }
    if (!await _game.applyEconomyProgressionEffect(effect)) {
      throw StateError('지원하지 않는 경제 진행 효과입니다: ${effect.effectType}');
    }
    await _requireSyncedSave();
    final result = await _execute(
      kind: 'ack_progression_effect',
      path: 'v1/economy/progression-effects/${effect.id}/ack',
      body: {
        'appliedSaveRevision': _saveCoordinator.snapshot.remoteRevision,
        'writerGeneration': _requireWriterGeneration(),
        'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
      },
    );
    _snapshot = result.snapshot;
  }

  Future<void> _requireSyncedSave() async {
    if (!await _game.saveAccountCheckpoint()) {
      throw StateError('계정 진행을 저장하지 못했습니다.');
    }
    await _saveCoordinator.currentAttempt;
    final state = _saveCoordinator.snapshot;
    if (state.phase != OnlineSaveCoordinatorPhase.idle ||
        state.pendingSaveCount != 0 ||
        state.hasPendingRemoteRebase ||
        state.requiresGameReload) {
      throw StateError('계정 진행 동기화를 먼저 완료해야 합니다.');
    }
  }

  int _requireWriterGeneration() {
    final generation = _saveCoordinator.writerGeneration;
    if (generation == null || generation <= 0) {
      throw StateError('온라인 저장 writer가 준비되지 않았습니다.');
    }
    return generation;
  }

  EconomySnapshot _requireSnapshot() {
    _ensureReady();
    return _snapshot ?? (throw StateError('서버 경제 정보가 준비되지 않았습니다.'));
  }

  void _ensureReady() {
    if (_disposed || _state == null) {
      throw StateError('경제 coordinator가 준비되지 않았습니다.');
    }
  }

  Future<void> _setInFlight(EconomyPendingCommand command) async {
    _ensureReady();
    if (_state!.inFlight != null) {
      throw StateError('처리 중인 경제 명령이 있습니다.');
    }
    _state = _state!.copyWith(inFlight: command);
    await _repository.save(_state!);
  }

  Future<void> _clearInFlight(EconomyPendingCommand command) async {
    if (_state?.inFlight?.idempotencyKey != command.idempotencyKey) {
      return;
    }
    _state = _state!.copyWith(inFlight: null);
    await _repository.save(_state!);
  }

  Future<T> _serialized<T>(
    Future<T> Function() operation, {
    bool recoverPendingWork = true,
  }) {
    final completer = Completer<T>();
    _serial = _serial.then((_) async {
      try {
        if (_disposed) {
          throw StateError('종료된 경제 coordinator입니다.');
        }
        if (recoverPendingWork) {
          final inFlight = _state?.inFlight;
          if (inFlight != null) {
            await _retryInFlight(inFlight);
          }
          if (_state != null && _snapshot != null) {
            await _applyPendingEffects();
            await _drainPendingRunRewards();
          }
        }
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<T> _userCommand<T>(Future<T> Function() operation) {
    if (_userCommandPending) {
      return Future<T>.error(StateError('다른 경제 요청을 처리하고 있습니다.'));
    }
    _userCommandPending = true;
    return _serialized(operation).whenComplete(() {
      _userCommandPending = false;
    });
  }

  static bool _isUnauthorized(Object error) =>
      error is EconomyException && error.isUnauthorized;

  static bool _isDefinitive(Object error) =>
      error is EconomyException &&
      !error.transportFailure &&
      error.statusCode != null &&
      error.statusCode! >= 400 &&
      error.statusCode! < 500 &&
      error.statusCode != 429;

  static bool _isRebindableRunError(Object error) =>
      error is EconomyException &&
      (error.code == 'SAVE_WRITER_REPLACED' ||
          error.code == 'SAVE_SYNC_REQUIRED');
}
