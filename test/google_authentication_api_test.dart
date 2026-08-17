import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/auth/authentication_transport_stub.dart';
import 'package:rune_nexus/data/auth/google_authentication_api.dart';

void main() {
  test('Google ID token을 인증 API에 보내고 세션을 해석한다', () async {
    final transport = _FakeAuthenticationTransport(
      response: const AuthenticationHTTPResponse(
        statusCode: 200,
        body: '''
          {
            "account": {"id": "0198b955-3656-7c40-b3cb-87f427b90be2"},
            "accessToken": "opaque-access-token",
            "accessExpiresAt": "2026-08-18T03:15:00Z",
            "refreshToken": "opaque-refresh-token",
            "refreshExpiresAt": "2026-09-17T03:00:00Z"
          }
        ''',
      ),
    );
    final api = GoogleAuthenticationApi(
      baseUrl: 'https://api.rune-nexus.example/',
      transport: transport,
    );

    final credentials = await api.authenticate('google-id-token');

    expect(
      transport.requestedUri,
      Uri.parse('https://api.rune-nexus.example/v1/auth/google'),
    );
    expect(jsonDecode(transport.requestBody!), {'idToken': 'google-id-token'});
    expect(credentials.accountId, '0198b955-3656-7c40-b3cb-87f427b90be2');
    expect(credentials.accessToken, 'opaque-access-token');
    expect(credentials.refreshToken, 'opaque-refresh-token');
    expect(credentials.accessExpiresAt.isUtc, isTrue);
  });

  test('서버 인증 오류 코드와 요청 ID를 보존한다', () async {
    final api = GoogleAuthenticationApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeAuthenticationTransport(
        response: const AuthenticationHTTPResponse(
          statusCode: 401,
          body: '''
            {
              "code": "GOOGLE_AUTH_REJECTED",
              "message": "로그인을 확인할 수 없습니다.",
              "requestId": "request-123"
            }
          ''',
        ),
      ),
    );

    await expectLater(
      api.authenticate('rejected-token'),
      throwsA(
        isA<GoogleAuthenticationException>()
            .having((error) => error.code, 'code', 'GOOGLE_AUTH_REJECTED')
            .having((error) => error.requestId, 'requestId', 'request-123')
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );
  });

  test('성공 응답의 계정 ID 또는 만료 정보가 잘못되면 거부한다', () async {
    final api = GoogleAuthenticationApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeAuthenticationTransport(
        response: const AuthenticationHTTPResponse(
          statusCode: 200,
          body: '''
            {
              "account": {"id": "untrusted-account-id"},
              "accessToken": "access",
              "accessExpiresAt": "2026-09-18T03:15:00Z",
              "refreshToken": "refresh",
              "refreshExpiresAt": "2026-08-18T03:15:00Z"
            }
          ''',
        ),
      ),
    );

    await expectLater(
      api.authenticate('google-id-token'),
      throwsA(
        isA<GoogleAuthenticationException>().having(
          (error) => error.code,
          'code',
          'INVALID_AUTH_RESPONSE',
        ),
      ),
    );
  });

  test('운영 API는 HTTPS, 로컬 개발 API만 HTTP를 허용한다', () {
    expect(
      GoogleAuthenticationApi.supportsBaseUrl('https://api.rune-nexus.example'),
      isTrue,
    );
    expect(
      GoogleAuthenticationApi.supportsBaseUrl('http://127.0.0.1:8080'),
      isTrue,
    );
    expect(
      GoogleAuthenticationApi.supportsBaseUrl('http://api.rune-nexus.example'),
      isFalse,
    );
    expect(
      GoogleAuthenticationApi.supportsBaseUrl(
        'https://user:password@api.rune-nexus.example',
      ),
      isFalse,
    );
  });
}

class _FakeAuthenticationTransport extends AuthenticationTransport {
  _FakeAuthenticationTransport({required this.response});

  final AuthenticationHTTPResponse response;
  Uri? requestedUri;
  String? requestBody;

  @override
  Future<AuthenticationHTTPResponse> postJSON(
    Uri uri, {
    required String body,
  }) async {
    requestedUri = uri;
    requestBody = body;
    return response;
  }
}
