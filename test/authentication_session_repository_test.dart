import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/auth/authentication_session_repository.dart';
import 'package:rune_nexus/data/auth/authentication_transport_types.dart';
import 'package:rune_nexus/data/auth/google_authentication_api.dart';
import 'package:rune_nexus/platform/session/session_storage_types.dart';

const _baseUrl = 'https://api.rune-nexus.example';
const _accountId = '0198b955-3656-7c40-b3cb-87f427b90be2';

void main() {
  test('Android 저장된 세션이 없으면 통신 없이 미로그인 상태로 복원한다', () async {
    final harness = _Harness();
    expect(await harness.repository().restore(), isNull);
    expect(harness.client.requests, isEmpty);
  });

  test('응답 유실 뒤 앱이 재시작되어도 저장된 같은 갱신 요청을 재전송한다', () async {
    final harness = _Harness()..storage.value = _record();
    harness.client.results.add(const AuthenticationTransportException('lost'));

    await expectLater(
      harness.repository().restore(),
      throwsA(isA<AuthenticationTransportException>()),
    );
    final firstRequest = harness.client.requests.single;
    final pendingKey = harness.storage.decoded['pendingKey'];
    expect(pendingKey, isNotEmpty);
    expect(firstRequest.headers['Idempotency-Key'], pendingKey);
    expect(harness.storage.decoded['refreshToken'], 'old-refresh');

    harness.client.results.add(_sessionResponse());
    final credentials = await harness.repository().restore();

    expect(harness.client.requests.last.body, firstRequest.body);
    expect(harness.client.requests.last.headers, firstRequest.headers);
    expect(credentials?.accessToken, 'new-access');
    expect(harness.storage.decoded['pendingKey'], isNull);
    expect(harness.storage.decoded['refreshToken'], 'new-refresh');
  });

  test('회전 응답 저장 실패 뒤에도 이전 refresh와 같은 요청 키로 복구한다', () async {
    final harness = _Harness()..storage.value = _record();
    harness.storage.failWriteNumber = 2;
    harness.client.results.add(_sessionResponse());

    await expectLater(harness.repository().restore(), throwsStateError);
    final pendingKey = harness.storage.decoded['pendingKey'];
    expect(harness.storage.decoded['refreshToken'], 'old-refresh');
    expect(pendingKey, isNotEmpty);

    harness.client.results.add(_sessionResponse());
    expect((await harness.repository().restore())?.accessToken, 'new-access');
    expect(harness.client.requests.last.headers['Idempotency-Key'], pendingKey);
    expect(harness.storage.decoded['refreshToken'], 'new-refresh');
    expect(harness.storage.decoded['pendingKey'], isNull);
  });

  test('요청 키 영속화가 실패하면 서버 토큰 회전을 시작하지 않는다', () async {
    final harness = _Harness()..storage.value = _record();
    harness.storage.failWriteNumber = 1;

    await expectLater(harness.repository().restore(), throwsStateError);

    expect(harness.client.requests, isEmpty);
    expect(harness.storage.decoded['refreshToken'], 'old-refresh');
  });

  test('로그아웃 응답 유실 뒤 재시작하면 로그아웃을 완료하고 로그인 복원을 막는다', () async {
    final harness = _Harness()..storage.value = _record();
    harness.client.results.add(const AuthenticationTransportException('lost'));

    await expectLater(
      harness.repository().logout('old-access'),
      throwsA(isA<AuthenticationTransportException>()),
    );
    expect(harness.storage.decoded['logoutPending'], isTrue);
    harness.client.results.add(
      const AuthenticationHTTPResponse(statusCode: 204, body: ''),
    );

    expect(await harness.repository().restore(), isNull);
    expect(harness.storage.value, isNull);
    expect(harness.client.requests.map((request) => request.uri.path), [
      '/v1/auth/native/logout',
      '/v1/auth/native/logout',
    ]);
  });

  test('미완료 갱신의 로그아웃은 오래된 access를 함께 보내지 않는다', () async {
    final harness = _Harness()
      ..storage.value = _record(pendingKey: 'pending-request');
    harness.client.results.add(
      const AuthenticationHTTPResponse(statusCode: 204, body: ''),
    );

    await harness.repository().logout('old-access');

    expect(harness.client.requests.single.headers, isEmpty);
    expect(jsonDecode(harness.client.requests.single.body), {
      'refreshToken': 'old-refresh',
    });
    expect(harness.storage.value, isNull);
  });

  test('Web은 access 및 refresh 원문을 metadata에 저장하지 않는다', () async {
    final harness = _Harness(mode: AuthenticationMode.web);
    harness.client.results.add(_sessionResponse(web: true));
    harness.client.results.add(_sessionResponse(web: true));

    final credentials = await harness.repository().authenticate('google-id');

    expect(credentials.accessToken, 'new-access');
    expect(harness.storage.decoded['accountId'], _accountId);
    expect(harness.storage.decoded.containsKey('accessToken'), isFalse);
    expect(harness.storage.decoded.containsKey('refreshToken'), isFalse);
    expect(harness.storage.value, isNot(contains('new-access')));
    harness.client.results.add(_sessionResponse(web: true));
    await harness.repository().restore();
    expect(harness.client.requests.last.uri.path, '/v1/auth/web/refresh');
    expect(jsonDecode(harness.client.requests.last.body), isEmpty);
  });

  test('Web 로그인 응답이 성공해도 쿠키가 전송되지 않으면 로그인 완료로 처리하지 않는다', () async {
    final harness = _Harness(mode: AuthenticationMode.web);
    harness.client.results.add(_sessionResponse(web: true));
    harness.client.results.add(
      const AuthenticationHTTPResponse(
        statusCode: 401,
        body: '{"code":"REFRESH_TOKEN_INVALID","message":"no cookie"}',
      ),
    );
    harness.client.results.add(
      const AuthenticationHTTPResponse(statusCode: 204, body: ''),
    );

    await expectLater(
      harness.repository().authenticate('google-id'),
      throwsA(
        isA<GoogleAuthenticationException>().having(
          (error) => error.code,
          'code',
          'SESSION_COOKIE_UNAVAILABLE',
        ),
      ),
    );
    expect(harness.storage.value, isNull);
  });

  test('Android 무만료 세션은 refresh만 보관하고 새 인스턴스에서 복원한다', () async {
    final harness = _Harness();
    harness.client.results.add(_sessionResponse());
    await harness.repository().authenticate('google-id');

    expect(harness.storage.decoded['refreshToken'], 'new-refresh');
    expect(harness.storage.decoded.containsKey('accessToken'), isFalse);
    expect(harness.storage.decoded.containsKey('refreshExpiresAt'), isFalse);
    harness.client.results.add(_sessionResponse());
    expect((await harness.repository().restore())?.accountId, _accountId);
  });

  for (final invalidRecord in [
    'broken-json',
    _record(baseUrl: 'https://another-api.example'),
    jsonEncode({'version': 1, 'apiBaseUrl': _baseUrl, 'logoutPending': 'yes'}),
  ]) {
    test('손상되거나 다른 API에 귀속된 저장 정보는 전송하지 않는다: $invalidRecord', () async {
      final harness = _Harness()..storage.value = invalidRecord;

      expect(await harness.repository().restore(), isNull);

      expect(harness.storage.value, isNull);
      expect(harness.client.requests, isEmpty);
    });
  }

  test('Keystore 복호화 불가 정보는 제거하고 다시 로그인할 수 있게 한다', () async {
    final harness = _Harness()..storage.value = _record();
    harness.storage.readFailure = PlatformException(code: 'session_unreadable');

    expect(await harness.repository().restore(), isNull);
    expect(harness.storage.value, isNull);
    expect(harness.client.requests, isEmpty);
  });

  for (final code in [
    'REFRESH_TOKEN_INVALID',
    'REFRESH_TOKEN_REUSED',
    'REFRESH_RECOVERY_EXPIRED',
    'ACCOUNT_NOT_ACTIVE',
  ]) {
    test('확실한 인증 오류 $code는 저장된 자격 증명을 제거한다', () async {
      final harness = _Harness()..storage.value = _record();
      harness.client.results.add(_errorResponse(code, 401));
      harness.client.results.add(
        const AuthenticationHTTPResponse(statusCode: 204, body: ''),
      );

      await expectLater(
        harness.repository().restore(),
        throwsA(
          isA<GoogleAuthenticationException>().having(
            (error) => error.code,
            'code',
            code,
          ),
        ),
      );
      expect(harness.storage.value, isNull);
    });
  }

  for (final failure in [
    _errorResponse('INTERNAL_ERROR', 503),
    _errorResponse('RATE_LIMIT_EXCEEDED', 429),
    const AuthenticationHTTPResponse(statusCode: 200, body: 'not-json'),
  ]) {
    test(
      '일시적 오류 ${failure.statusCode}/${failure.body}는 pending 요청을 보존한다',
      () async {
        final harness = _Harness()..storage.value = _record();
        harness.client.results.add(failure);

        await expectLater(
          harness.repository().restore(),
          throwsA(isA<GoogleAuthenticationException>()),
        );
        expect(harness.storage.decoded['refreshToken'], 'old-refresh');
        expect(harness.storage.decoded['pendingKey'], isNotEmpty);
      },
    );
  }

  test('Web 신규 브라우저의 쿠키 없음은 오류 대신 미로그인으로 처리한다', () async {
    final harness = _Harness(mode: AuthenticationMode.web);
    harness.client.results.add(_errorResponse('REFRESH_TOKEN_INVALID', 401));
    harness.client.results.add(
      const AuthenticationHTTPResponse(statusCode: 204, body: ''),
    );

    expect(await harness.repository().restore(), isNull);
    expect(harness.storage.value, isNull);
  });

  for (final mode in [AuthenticationMode.native, AuthenticationMode.web]) {
    test('$mode 계정 불일치는 반환된 세션을 폐기하고 원래 오류를 보존한다', () async {
      final harness = _Harness(mode: mode);
      harness.storage.value = mode == AuthenticationMode.web
          ? jsonEncode(
              {...jsonDecode(_record()) as Map<String, dynamic>}
                ..remove('refreshToken'),
            )
          : _record();
      harness.client.results.add(
        _sessionResponse(
          web: mode == AuthenticationMode.web,
          accountId: '0198b955-3656-7c40-b3cb-87f427b90be3',
        ),
      );
      harness.client.results.add(
        const AuthenticationTransportException('lost logout'),
      );

      await expectLater(
        harness.repository().restore(),
        throwsA(
          isA<GoogleAuthenticationException>().having(
            (error) => error.code,
            'code',
            'INVALID_AUTH_ACCOUNT',
          ),
        ),
      );

      expect(harness.storage.decoded['logoutPending'], isTrue);
      expect(harness.client.requests.last.uri.path, endsWith('/logout'));
      expect(
        jsonDecode(harness.client.requests.last.body),
        mode == AuthenticationMode.web
            ? isEmpty
            : {'refreshToken': 'new-refresh'},
      );
      harness.client.results.add(
        const AuthenticationHTTPResponse(statusCode: 204, body: ''),
      );
      expect(await harness.repository().restore(), isNull);
      expect(harness.storage.value, isNull);
      expect(harness.client.requests.last.uri.path, endsWith('/logout'));
    });
  }

  test('만료된 멱등 응답은 새 refresh와 새 key로 access를 다시 발급받는다', () async {
    final harness = _Harness()
      ..storage.value = _record(pendingKey: 'old-request');
    harness.client.results.add(
      _sessionResponse(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );
    harness.client.results.add(_sessionResponse());

    expect((await harness.repository().restore())?.accessToken, 'new-access');

    expect(harness.client.requests, hasLength(2));
    expect(
      harness.client.requests.first.headers['Idempotency-Key'],
      'old-request',
    );
    expect(
      harness.client.requests.last.headers['Idempotency-Key'],
      isNot('old-request'),
    );
    expect(jsonDecode(harness.client.requests.last.body), {
      'refreshToken': 'new-refresh',
    });
    expect(harness.storage.decoded['pendingKey'], isNull);
  });
}

class _Harness {
  _Harness({this.mode = AuthenticationMode.native});

  final AuthenticationMode mode;
  final _MemorySessionStorage storage = _MemorySessionStorage();
  final _ScriptedClient client = _ScriptedClient();

  AuthenticationSessionRepository repository() =>
      AuthenticationSessionRepository(
        api: GoogleAuthenticationApi(
          baseUrl: _baseUrl,
          mode: mode,
          transport: client,
        ),
        apiBaseUrl: _baseUrl,
        storage: storage,
      );
}

class _MemorySessionStorage implements SessionStorage {
  String? value;
  int writes = 0;
  int? failWriteNumber;
  Object? readFailure;

  Map<String, dynamic> get decoded =>
      jsonDecode(value!) as Map<String, dynamic>;

  @override
  Future<String?> read() async {
    if (readFailure case final Object error) throw error;
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    if (writes == failWriteNumber) throw StateError('disk write failed');
    this.value = value;
  }

  @override
  Future<void> delete() async => value = null;
}

class _Request {
  const _Request(this.uri, this.body, this.headers);
  final Uri uri;
  final String body;
  final Map<String, String> headers;
}

class _ScriptedClient implements AuthenticationClient {
  final List<Object> results = [];
  final List<_Request> requests = [];

  @override
  Future<AuthenticationHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    requests.add(_Request(uri, body, headers));
    final result = results.removeAt(0);
    if (result is AuthenticationHTTPResponse) return result;
    throw result;
  }
}

String _record({String baseUrl = _baseUrl, String? pendingKey}) => jsonEncode({
  'version': 1,
  'apiBaseUrl': baseUrl,
  'accountId': _accountId,
  'refreshToken': 'old-refresh',
  'pendingKey': pendingKey,
  'logoutPending': false,
});

AuthenticationHTTPResponse _sessionResponse({
  bool web = false,
  String accountId = _accountId,
  DateTime? expiresAt,
}) => AuthenticationHTTPResponse(
  statusCode: 200,
  body: jsonEncode({
    'account': {'id': accountId},
    'accessToken': 'new-access',
    'accessExpiresAt':
        (expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 15)))
            .toIso8601String(),
    if (!web) 'refreshToken': 'new-refresh',
    'refreshExpiresAt': null,
  }),
);

AuthenticationHTTPResponse _errorResponse(String code, int status) =>
    AuthenticationHTTPResponse(
      statusCode: status,
      body: jsonEncode({'code': code, 'message': 'rejected'}),
    );
