import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/mailbox/mailbox_api.dart';
import 'package:rune_nexus/domain/mailbox/mailbox.dart';
import 'package:rune_nexus/data/save/online_save_transport_types.dart';

Map<String, Object?> mail() => {
  'id': '11111111-1111-4111-8111-111111111111',
  'title': '운영 선물',
  'body': '업데이트를 함께해 주셔서 감사합니다.',
  'freeDiamonds': 100,
  'moduleTickets': 2,
  'startsAt': '2026-09-10T00:00:00Z',
  'expiresAt': '2026-09-17T00:00:00Z',
  'readAt': '2026-09-10T01:00:00Z',
  'claimedAt': null,
};
Map<String, Object?> page() => {
  'mails': [mail()],
  'nextCursor': 'opaque+/=',
  'serverTime': '2026-09-10T02:00:00Z',
};
void main() {
  test('커서·인증·보상·읽음과 수령을 구분해 보존한다', () async {
    final transport = _Transport();
    final api = MailboxApi(
      baseUrl: 'https://example.com/api',
      transport: transport,
    );
    final result = await api.load('token', cursor: 'opaque+/=');
    expect(transport.uri!.path, '/api/v1/mailbox');
    expect(transport.uri!.queryParameters['cursor'], 'opaque+/=');
    expect(transport.headers['Authorization'], 'Bearer token');
    expect(result.items.single.isRead, isTrue);
    expect(result.items.single.isClaimed, isFalse);
    expect(result.items.single.freeDiamonds, 100);
    expect(result.items.single.moduleTickets, 2);
    expect(result.nextCursor, 'opaque+/=');
    expect(() => result.items.clear(), throwsUnsupportedError);
  });
  test('요약과 멱등 읽음 요청은 재화 값을 보내지 않는다', () async {
    final transport = _Transport()..body = '{"unclaimedCount":3000}';
    final api = MailboxApi(
      baseUrl: 'https://example.com',
      transport: transport,
    );
    expect(await api.summary('a'), 3000);
    transport.status = 204;
    transport.body = '';
    await api.markRead('a', mail()['id']! as String);
    expect(transport.requestBody, '{}');
    expect(transport.uri!.path, '/v1/mailbox/${mail()['id']}/read');
  });
  test('비 JSON 401은 인증 갱신 대상으로 유지한다', () async {
    final transport = _Transport()
      ..status = 401
      ..body = 'expired';
    await expectLater(
      MailboxApi(
        baseUrl: 'https://example.com',
        transport: transport,
      ).load('a'),
      throwsA(
        isA<MailboxException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          true,
        ),
      ),
    );
  });
  test('음수 보상·중복 우편·잘못된 시각·페이지 초과는 거부한다', () async {
    final payloads = [
      {
        ...page(),
        'mails': [
          {...mail(), 'freeDiamonds': -1},
        ],
      },
      {
        ...page(),
        'mails': [mail(), mail()],
      },
      {
        ...page(),
        'mails': [
          {...mail(), 'claimedAt': 'broken'},
        ],
      },
      {...page(), 'serverTime': '2026-09-10T00:00:00'},
      {...page(), 'mails': List.generate(21, (_) => mail())},
    ];
    for (final payload in payloads) {
      final transport = _Transport()..body = jsonEncode(payload);
      await expectLater(
        MailboxApi(
          baseUrl: 'https://example.com',
          transport: transport,
        ).load('a'),
        throwsA(
          isA<MailboxException>().having(
            (e) => e.code,
            'code',
            'INVALID_MAILBOX_RESPONSE',
          ),
        ),
      );
    }
  });
}

class _Transport implements OnlineSaveHTTPClient {
  int status = 200;
  String body = jsonEncode(page());
  Uri? uri;
  String? requestBody;
  Map<String, String> headers = {};
  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    this.uri = uri;
    this.headers = headers;
    return OnlineSaveHTTPResponse(statusCode: status, body: body);
  }

  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    requestBody = body;
    return getJSON(uri, headers: headers);
  }

  @override
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
}
