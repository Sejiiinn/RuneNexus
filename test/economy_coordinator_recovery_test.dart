import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/auth/online_account_session_controller.dart';
import 'package:rune_nexus/data/economy/economy_api.dart';
import 'package:rune_nexus/data/economy/economy_command_outbox.dart';
import 'package:rune_nexus/data/economy/economy_command_outbox_repository.dart';
import 'package:rune_nexus/data/economy/economy_coordinator.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';
import 'package:rune_nexus/data/save/online_save_coordinator.dart';
import 'package:rune_nexus/data/save/online_save_outbox_repository.dart';
import 'package:rune_nexus/data/save/online_save_transport_stub.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/domain/account/online_account_credentials.dart';
import 'package:rune_nexus/domain/daily_quest/daily_quest_type.dart';
import 'package:rune_nexus/domain/economy/authoritative_economy_commands.dart';
import 'package:rune_nexus/domain/research/research_type.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';

void main() {
  test('원격 rebase 게임 교체 뒤에도 새 게임만 서버 경제에 연결된다', () async {
    final fixture = _Fixture();
    final first = RuneNexusGame(saveRepository: MemorySaveRepository());
    final coordinator = fixture.economyCoordinator(first);
    first.attachAuthoritativeEconomyCommands(coordinator);
    await coordinator.initialize();

    final replacement = RuneNexusGame(saveRepository: MemorySaveRepository());
    await coordinator.rebindGame(replacement);

    expect(replacement.snapshotNotifier.value.diamonds, 10);
    replacement.debugAddDiamonds(5);
    expect(replacement.snapshotNotifier.value.diamonds, 10);

    first.debugAddDiamonds(5);
    expect(first.snapshotNotifier.value.diamonds, 15);

    coordinator.dispose();
    fixture.dispose();
  });

  test('연구 명령 응답 유실 복구는 효과 저장과 ack를 먼저 완료한다', () async {
    final effect = <String, Object?>{
      'id': '44444444-4444-4444-8444-444444444444',
      'effectType': 'complete_research',
      'payload': {'researchType': 'researchEfficiency', 'targetLevel': 1},
    };
    final transport = _EconomyTransport(
      getResponse: _economySnapshot(revision: 3),
      postResponses: [
        {
          'economy': _economySnapshot(revision: 2, effects: [effect]),
          'progressionEffect': effect,
        },
        {'economy': _economySnapshot(revision: 3)},
      ],
    );
    final fixture = _Fixture(transport: transport);
    await fixture.saveCoordinator.initialize();
    final repository = MemoryEconomyCommandOutboxRepository()
      ..state = EconomyCommandOutboxState.initial(_accountId).copyWith(
        inFlight: const EconomyPendingCommand(
          kind: 'complete_research',
          path: 'v1/economy/researches/researchEfficiency/complete',
          idempotencyKey: '33333333-3333-4333-8333-333333333333',
          encodedBody: '{"expectedEconomyRevision":1}',
          createdAtMillis: 1,
        ),
      );
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      onlineSaveRepository: fixture.saveCoordinator,
    );
    final coordinator = fixture.economyCoordinator(
      game,
      repository: repository,
    );
    game.attachAuthoritativeEconomyCommands(coordinator);

    await coordinator.initialize();

    expect(repository.state!.inFlight, isNull);
    expect(
      game.snapshotNotifier.value.researchLevels[ResearchType
          .researchEfficiency],
      1,
    );
    expect(transport.postPaths, [
      '/v1/economy/researches/researchEfficiency/complete',
      '/v1/economy/progression-effects/${effect['id']}/ack',
    ]);

    coordinator.dispose();
    fixture.dispose();
  });

  test('넥서스 파괴 패배도 런 정산을 정확히 한 번 등록한다', () async {
    final commands = _RecordingEconomyCommands();
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    game.onGameResize(Vector2(400, 800));
    await game.onLoad();
    game.attachAuthoritativeEconomyCommands(commands);

    game.debugForceDefeat();
    await Future<void>.delayed(Duration.zero);

    expect(commands.runSettlements, hasLength(1));
    expect(commands.runSettlements.single.success, isFalse);
    expect(commands.runSettlements.single.firstClearModuleTickets, 0);
    game.disposeAppResources();
  });

  test('오프라인 런 정산은 저장 재연결 직후 자동 처리된다', () async {
    final client = _OnlineSaveClient();
    final transport = _EconomyTransport(
      getResponse: _economySnapshot(revision: 1),
      postResponses: [
        {'economy': _economySnapshot(revision: 2)},
      ],
    );
    final fixture = _Fixture(transport: transport, saveClient: client);
    await fixture.saveCoordinator.initialize();
    final repository = MemoryEconomyCommandOutboxRepository();
    final game = RuneNexusGame(
      saveRepository: MemorySaveRepository(),
      onlineSaveRepository: fixture.saveCoordinator,
    );
    final coordinator = fixture.economyCoordinator(
      game,
      repository: repository,
    );
    game.attachAuthoritativeEconomyCommands(coordinator);
    await coordinator.initialize();

    client.failUpdates = true;
    await coordinator.queueRunSettlement(
      runId: '55555555-5555-4555-8555-555555555555',
      stageNumber: 1,
      completedRounds: 3,
      success: false,
      pendingDiamonds: 1,
      firstClearModuleTickets: 0,
    );
    expect(repository.state!.pendingRewards, hasLength(1));

    client.failUpdates = false;
    await fixture.saveCoordinator.retryNow();
    await fixture.saveCoordinator.currentAttempt;
    coordinator.handleSaveSnapshotChanged(fixture.saveCoordinator.snapshot);
    await _pumpUntil(() => repository.state!.pendingRewards.isEmpty);

    expect(transport.postPaths, ['/v1/economy/runs/settle']);
    coordinator.dispose();
    fixture.dispose();
  });
}

const _accountId = '11111111-1111-4111-8111-111111111111';

class _Fixture {
  factory _Fixture({
    _EconomyTransport? transport,
    _OnlineSaveClient? saveClient,
  }) {
    final resolvedSession = _session();
    final saveCoordinator = OnlineSaveCoordinator(
      accountId: _accountId,
      client: saveClient ?? _OnlineSaveClient(),
      session: resolvedSession,
      initialRevision: 0,
      outboxRepository: MemoryOnlineSaveOutboxRepository(),
      loadPersistedCheckpoint: () async => null,
    );
    return _Fixture._(
      transport ??
          _EconomyTransport(getResponse: _economySnapshot(revision: 1)),
      resolvedSession,
      saveCoordinator,
    );
  }

  _Fixture._(this.transport, this.session, this.saveCoordinator);

  final _EconomyTransport transport;
  final OnlineAccountSessionController session;
  final OnlineSaveCoordinator saveCoordinator;

  EconomyCoordinator economyCoordinator(
    RuneNexusGame game, {
    EconomyCommandOutboxRepository? repository,
  }) => EconomyCoordinator(
    accountId: _accountId,
    api: EconomyApi(baseUrl: 'https://api.example', transport: transport),
    session: session,
    saveCoordinator: saveCoordinator,
    outboxRepository: repository ?? MemoryEconomyCommandOutboxRepository(),
    game: game,
  );

  void dispose() {
    saveCoordinator.dispose();
    session.dispose();
  }
}

OnlineAccountSessionController _session() {
  final now = DateTime.now().toUtc();
  return OnlineAccountSessionController(
    credentials: OnlineAccountCredentials(
      accountId: _accountId,
      accessToken: 'access-token',
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshToken: 'refresh-token',
      refreshExpiresAt: now.add(const Duration(days: 30)),
    ),
    refreshCredentials: (_) async => throw StateError('unexpected refresh'),
    revokeSession: (_, _) async {},
    onCredentialsChanged: (_) {},
    onSessionInvalidated: () {},
  );
}

class _OnlineSaveClient implements OnlineSaveClient {
  var revision = 0;
  var failUpdates = false;

  @override
  Future<OnlineSaveWriterClaimResult> claimWriter(
    String accessToken,
    OnlineSaveWriterClaimRequest request,
  ) async => OnlineSaveWriterClaimResult(
    writerGeneration: 1,
    claimedAt: DateTime.utc(2026, 8, 30),
  );

  @override
  Future<OnlineSaveSnapshot?> load(String accessToken) async => null;

  @override
  Future<OnlineSaveUpdateResult> update(
    String accessToken,
    OnlineSaveUpdateRequest request,
  ) async {
    if (failUpdates) {
      throw const OnlineSaveException(
        code: 'NETWORK_ERROR',
        message: 'offline',
        transportFailure: true,
      );
    }
    revision += 1;
    return OnlineSaveUpdateResult(
      revision: revision,
      serverSavedAt: DateTime.utc(2026, 8, 30, 0, 0, revision),
    );
  }
}

Future<void> _pumpUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('비동기 경제 작업이 예상 상태에 도달하지 못했습니다.');
}

class _EconomyTransport extends OnlineSaveTransport {
  _EconomyTransport({required this.getResponse, this.postResponses = const []});

  final Map<String, Object?> getResponse;
  final List<Map<String, Object?>> postResponses;
  final List<String> postPaths = [];
  var _postIndex = 0;

  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async =>
      OnlineSaveHTTPResponse(statusCode: 200, body: jsonEncode(getResponse));

  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    postPaths.add(uri.path);
    final response = postResponses[_postIndex++];
    return OnlineSaveHTTPResponse(statusCode: 200, body: jsonEncode(response));
  }
}

Map<String, Object?> _economySnapshot({
  required int revision,
  List<Map<String, Object?>> effects = const [],
}) => {
  'authorityEpoch': '22222222-2222-4222-8222-222222222222',
  'authorityState': 'server_authoritative',
  'authorityVersion': 1,
  'economyRevision': revision,
  'catalogVersion': 1,
  'serverTime': '2026-08-30T00:00:00Z',
  'wallet': {'freeDiamonds': 10, 'paidDiamonds': 0, 'moduleTickets': 0},
  'turretModules': {
    'drawCount': 0,
    'ticketPurchaseCount': 0,
    'items': <Object?>[],
  },
  'entitlements': {'researchSlotTwoUnlocked': false},
  'pendingProgressionEffects': effects,
  'claimedRewardKeys': <String>[],
};

class _RunSettlementCall {
  const _RunSettlementCall({
    required this.success,
    required this.firstClearModuleTickets,
  });

  final bool success;
  final int firstClearModuleTickets;
}

class _RecordingEconomyCommands implements AuthoritativeEconomyCommands {
  final List<_RunSettlementCall> runSettlements = [];

  @override
  Future<bool> claimDailyAttendanceReward() async => false;

  @override
  Future<bool> claimDailyQuestAllCompleteReward() async => false;

  @override
  Future<bool> claimDailyQuestReward(DailyQuestType type) async => false;

  @override
  Future<bool> completeResearchWithDiamonds(ResearchType type) async => false;

  @override
  Future<bool> disassembleTurretModules(Iterable<String> ids) async => false;

  @override
  Future<List<TurretModuleInventoryItem>> drawTurretModules(
    int count, {
    required TurretType turretType,
    required bool buyMissingTicketsWithDiamonds,
  }) async => const [];

  @override
  Future<void> queueRunSettlement({
    required String runId,
    required int stageNumber,
    required int completedRounds,
    required bool success,
    required int pendingDiamonds,
    required int firstClearModuleTickets,
  }) async {
    runSettlements.add(
      _RunSettlementCall(
        success: success,
        firstClearModuleTickets: firstClearModuleTickets,
      ),
    );
  }

  @override
  Future<bool> unlockResearchSlotTwo() async => false;
}
