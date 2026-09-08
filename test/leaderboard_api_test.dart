import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/leaderboard/leaderboard_api.dart';
import 'package:rune_nexus/data/save/online_save_transport_types.dart';

Map<String, Object?> entry({bool mine = false, int rank = 128}) => {
  'rank': rank,
  'displayName': '룬지기#0042',
  'stageNumber': 4,
  'completedRounds': 12,
  'achievedAt': '2026-09-08T01:02:03.123456Z',
  'isMe': mine,
};

Map<String, Object?> snapshot() => {
  'rulesVersion': 1,
  'asOf': '2026-09-08T02:00:00Z',
  'entries': [entry(rank: 1)],
  'myEntry': entry(mine: true),
};

void main() {
  test('인증 조회는 경로·태그·서버 시각과 100위 밖 내 순위를 보존한다', () async {
    final transport = _Transport();
    final api = LeaderboardApi(
      baseUrl: 'https://example.com/api/',
      transport: transport,
    );
    final result = await api.load('access');
    expect(
      transport.uri.toString(),
      'https://example.com/api/v1/leaderboards/progression',
    );
    expect(transport.headers, {'Authorization': 'Bearer access'});
    expect(result.entries.single.displayName, '룬지기#0042');
    expect(result.myEntry!.rank, 128);
    expect(
      result.myEntry!.achievedAt,
      DateTime.utc(2026, 9, 8, 1, 2, 3, 123, 456),
    );
    expect(() => result.entries.clear(), throwsUnsupportedError);
  });

  test('아직 기록 없는 계정의 빈 결과를 정상 처리한다', () async {
    final transport = _Transport()
      ..body = jsonEncode({...snapshot(), 'entries': [], 'myEntry': null});
    final result = await LeaderboardApi(
      baseUrl: 'https://example.com',
      transport: transport,
    ).load('a');
    expect(result.entries, isEmpty);
    expect(result.myEntry, isNull);
  });

  test('비 JSON 401도 인증 갱신 대상으로 보존한다', () async {
    final transport = _Transport()
      ..status = 401
      ..body = '<html>expired</html>';
    await expectLater(
      LeaderboardApi(
        baseUrl: 'https://example.com',
        transport: transport,
      ).load('a'),
      throwsA(
        isA<LeaderboardException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          true,
        ),
      ),
    );
  });

  test('잘못된 기록·시각·버전은 빈 정상 결과로 바꾸지 않는다', () async {
    final payloads = [
      {...snapshot(), 'rulesVersion': 2},
      {...snapshot(), 'asOf': '2026-09-08T10:00:00'},
      {
        ...snapshot(),
        'entries': [
          {...entry(), 'rank': 0},
        ],
      },
      {
        ...snapshot(),
        'entries': [
          {...entry(), 'completedRounds': 41},
        ],
      },
      {
        ...snapshot(),
        'entries': [
          {...entry(), 'achievedAt': 'invalid'},
        ],
      },
      {...snapshot(), 'myEntry': entry(mine: false)},
      {...snapshot(), 'entries': List.generate(101, (_) => entry())},
    ];
    for (final payload in payloads) {
      final transport = _Transport()..body = jsonEncode(payload);
      await expectLater(
        LeaderboardApi(
          baseUrl: 'https://example.com',
          transport: transport,
        ).load('a'),
        throwsA(
          isA<LeaderboardException>().having(
            (e) => e.code,
            'code',
            'INVALID_LEADERBOARD_RESPONSE',
          ),
        ),
      );
    }
  });

  test('전송 오류와 안전하지 않은 API 주소를 구분한다', () async {
    final transport = _Transport()..offline = true;
    await expectLater(
      LeaderboardApi(
        baseUrl: 'http://127.0.0.1:8080',
        transport: transport,
      ).load('a'),
      throwsA(
        isA<LeaderboardException>().having(
          (e) => e.code,
          'code',
          'LEADERBOARD_NETWORK_ERROR',
        ),
      ),
    );
    expect(
      () => LeaderboardApi(baseUrl: 'http://example.com'),
      throwsFormatException,
    );
    expect(
      () => LeaderboardApi(baseUrl: 'https://user@example.com'),
      throwsFormatException,
    );
  });
}

class _Transport implements OnlineSaveHTTPClient {
  int status = 200;
  String body = jsonEncode(snapshot());
  bool offline = false;
  Uri? uri;
  Map<String, String>? headers;

  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    this.uri = uri;
    this.headers = headers;
    if (offline) throw const OnlineSaveTransportException('offline');
    return OnlineSaveHTTPResponse(statusCode: status, body: body);
  }

  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();

  @override
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
}
