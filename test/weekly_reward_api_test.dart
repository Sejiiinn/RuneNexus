import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/economy/weekly_reward_api.dart';
import 'package:rune_nexus/data/save/online_save_transport_stub.dart';
import 'package:rune_nexus/domain/daily_quest/daily_quest_type.dart';
import 'package:rune_nexus/domain/economy/weekly_reward_claim.dart';

void main() {
  const idempotencyKey = '0198b955-3656-7c40-b3cb-87f427b90be3';

  test('주간 임무 수령은 Bearer와 멱등성 key만 보내고 서버 보상량을 해석한다', () async {
    final transport = _FakeWeeklyRewardTransport(
      response: OnlineSaveHTTPResponse(
        statusCode: 200,
        body: jsonEncode({
          'rewardKey': 'weekly:2026-W35:quest:killEnemies',
          'periodKey': '2026-W35',
          'weekKey': 2956,
          'rewardType': 'quest',
          'questType': 'killEnemies',
          'diamonds': 20,
          'moduleTickets': 0,
          'sourceSaveRevision': 7,
          'claimedAt': '2026-08-29T01:02:03Z',
        }),
      ),
    );
    final api = WeeklyRewardApi(
      baseUrl: 'https://api.rune-nexus.example/',
      transport: transport,
    );

    final receipt = await api.claim(
      'access-token',
      idempotencyKey: idempotencyKey,
      target: const WeeklyRewardClaimTarget.quest(DailyQuestType.killEnemies),
    );

    expect(
      transport.uri,
      Uri.parse('https://api.rune-nexus.example/v1/economy/rewards/claim'),
    );
    expect(transport.headers, {
      'Authorization': 'Bearer access-token',
      'Idempotency-Key': idempotencyKey,
    });
    expect(jsonDecode(transport.body!), {
      'period': 'weekly',
      'rewardType': 'quest',
      'questType': 'killEnemies',
    });
    expect(receipt.diamonds, 20);
    expect(receipt.target.key, 'quest:killEnemies');
    expect(receipt.sourceSaveRevision, 7);
  });

  test('다른 멱등성 key의 이미 수령 응답도 원래 영수증으로 복구한다', () async {
    final reward = {
      'rewardKey': 'weekly:2026-W35:attendance',
      'periodKey': '2026-W35',
      'weekKey': 2956,
      'rewardType': 'attendance',
      'diamonds': 20,
      'moduleTickets': 0,
      'sourceSaveRevision': 8,
      'claimedAt': '2026-08-29T01:02:03Z',
    };
    final api = WeeklyRewardApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeWeeklyRewardTransport(
        response: OnlineSaveHTTPResponse(
          statusCode: 409,
          body: jsonEncode({
            'code': 'REWARD_ALREADY_CLAIMED',
            'message': 'already claimed',
            'reward': reward,
          }),
        ),
      ),
    );

    final receipt = await api.claim(
      'access-token',
      idempotencyKey: idempotencyKey,
      target: const WeeklyRewardClaimTarget.attendance(),
    );

    expect(receipt.rewardKey, reward['rewardKey']);
    expect(receipt.diamonds, 20);
  });

  test('요청 대상과 다른 보상 영수증은 적용하지 않는다', () async {
    final api = WeeklyRewardApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeWeeklyRewardTransport(
        response: const OnlineSaveHTTPResponse(
          statusCode: 200,
          body: '''
            {
              "rewardKey":"weekly:2026-W35:attendance",
              "periodKey":"2026-W35",
              "weekKey":2956,
              "rewardType":"attendance",
              "diamonds":20,
              "moduleTickets":0,
              "sourceSaveRevision":8,
              "claimedAt":"2026-08-29T01:02:03Z"
            }
          ''',
        ),
      ),
    );

    await expectLater(
      api.claim(
        'access-token',
        idempotencyKey: idempotencyKey,
        target: const WeeklyRewardClaimTarget.allComplete(),
      ),
      throwsA(
        isA<WeeklyRewardException>().having(
          (error) => error.code,
          'code',
          'INVALID_WEEKLY_REWARD_RESPONSE',
        ),
      ),
    );
  });
}

class _FakeWeeklyRewardTransport extends OnlineSaveTransport {
  _FakeWeeklyRewardTransport({required this.response});

  final OnlineSaveHTTPResponse response;
  Uri? uri;
  String? body;
  Map<String, String>? headers;

  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    this.uri = uri;
    this.body = body;
    this.headers = headers;
    return response;
  }
}
