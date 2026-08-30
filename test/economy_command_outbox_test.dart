import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/economy/economy_command_outbox.dart';

void main() {
  const accountId = '11111111-1111-4111-8111-111111111111';

  test('경제 명령의 exact 본문과 런 정산 대기를 복원한다', () {
    const command = EconomyPendingCommand(
      kind: 'draw_modules',
      path: 'v1/economy/turret-modules/draw',
      idempotencyKey: '22222222-2222-4222-8222-222222222222',
      encodedBody: '{"expectedEconomyRevision":3}',
      createdAtMillis: 100,
    );
    const reward = EconomyPendingRunReward(
      runId: '33333333-3333-4333-8333-333333333333',
      stageNumber: 11,
      completedRounds: 30,
      success: true,
      pendingDiamonds: 25,
      firstClearModuleTickets: 5,
      createdAtMillis: 200,
    );
    final state = EconomyCommandOutboxState.initial(
      accountId,
    ).copyWith(inFlight: command, pendingRewards: const [reward]);

    final restored = EconomyCommandOutboxState.fromJson(state.toJson());

    expect(restored, isNotNull);
    expect(restored!.accountIdBinding, accountId);
    expect(restored.inFlight!.idempotencyKey, command.idempotencyKey);
    expect(restored.inFlight!.encodedBody, command.encodedBody);
    expect(restored.pendingRewards.single.runId, reward.runId);
    expect(restored.pendingRewards.single.pendingDiamonds, 25);
    expect(restored.pendingRewards.single.firstClearModuleTickets, 5);
  });

  test('손상된 런 정산 대기는 전체 Outbox 복원을 거부한다', () {
    final json = EconomyCommandOutboxState.initial(accountId).toJson();
    json['pendingRewards'] = [
      {
        'runId': '',
        'stageNumber': 0,
        'completedRounds': -1,
        'success': true,
        'pendingDiamonds': -1,
        'createdAtMillis': 0,
      },
    ];

    expect(EconomyCommandOutboxState.fromJson(json), isNull);
  });
}
