import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';
import 'package:rune_nexus/data/save/online_save_transport_stub.dart';

void main() {
  test('원격 저장을 Bearer 인증으로 조회하고 canonical 데이터를 해석한다', () async {
    final transport = _FakeOnlineSaveTransport(
      getResponse: OnlineSaveHTTPResponse(
        statusCode: 200,
        body: jsonEncode({
          'revision': 12,
          'serverSavedAt': '2026-08-20T03:00:00Z',
          'data': _saveData(1234).toJson(),
        }),
      ),
    );
    final api = OnlineSaveApi(
      baseUrl: 'https://api.rune-nexus.example/',
      transport: transport,
    );

    final snapshot = await api.load('access-token');

    expect(
      transport.requestedUri,
      Uri.parse('https://api.rune-nexus.example/v1/save'),
    );
    expect(transport.requestHeaders, {'Authorization': 'Bearer access-token'});
    expect(snapshot?.revision, 12);
    expect(snapshot?.data.savedAtMillis, 1234);
    expect(snapshot?.serverSavedAt.isUtc, isTrue);
  });

  test('SAVE_NOT_FOUND는 최초 업로드 가능한 null로 해석한다', () async {
    final api = OnlineSaveApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeOnlineSaveTransport(
        getResponse: const OnlineSaveHTTPResponse(
          statusCode: 404,
          body: '{"code":"SAVE_NOT_FOUND","message":"missing"}',
        ),
      ),
    );

    expect(await api.load('access-token'), isNull);
  });

  test('저장 요청의 revision, 본문과 멱등성 key를 그대로 전송한다', () async {
    final transport = _FakeOnlineSaveTransport(
      putResponse: const OnlineSaveHTTPResponse(
        statusCode: 200,
        body: '''
          {
            "revision": 13,
            "serverSavedAt": "2026-08-20T03:00:01Z"
          }
        ''',
      ),
    );
    final api = OnlineSaveApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: transport,
    );
    final request = OnlineSaveUpdateRequest(
      expectedRevision: 12,
      idempotencyKey: '0198b955-3656-7c40-b3cb-87f427b90be3',
      data: _saveData(5678),
    );

    final result = await api.update('access-token', request);

    expect(transport.requestMethod, 'PUT');
    expect(transport.requestBody, same(request.encodedBody));
    expect(transport.requestHeaders, {
      'Authorization': 'Bearer access-token',
      'Idempotency-Key': '0198b955-3656-7c40-b3cb-87f427b90be3',
    });
    expect(jsonDecode(transport.requestBody!), {
      'expectedRevision': 12,
      'data': _saveData(5678).toJson(),
    });
    expect(result.revision, 13);
  });

  test('revision 충돌과 Retry-After 정보를 오류에 보존한다', () async {
    final api = OnlineSaveApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeOnlineSaveTransport(
        putResponse: const OnlineSaveHTTPResponse(
          statusCode: 409,
          body: '''
            {
              "code": "SAVE_REVISION_CONFLICT",
              "message": "conflict",
              "requestId": "request-123",
              "currentRevision": 15
            }
          ''',
          headers: {'retry-after': '9'},
        ),
      ),
    );

    await expectLater(
      api.update(
        'access-token',
        OnlineSaveUpdateRequest(
          expectedRevision: 12,
          idempotencyKey: '0198b955-3656-7c40-b3cb-87f427b90be3',
          data: _saveData(1),
        ),
      ),
      throwsA(
        isA<OnlineSaveException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having((error) => error.currentRevision, 'currentRevision', 15)
            .having((error) => error.requestId, 'requestId', 'request-123')
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 9),
            ),
      ),
    );
  });

  test('전송 계층 오류는 재시도 가능한 저장 오류로 변환한다', () async {
    final api = OnlineSaveApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeOnlineSaveTransport(
        getError: const OnlineSaveTransportException('network down'),
      ),
    );

    await expectLater(
      api.load('access-token'),
      throwsA(
        isA<OnlineSaveException>()
            .having((error) => error.code, 'code', 'SAVE_NETWORK_ERROR')
            .having((error) => error.isRetryable, 'isRetryable', isTrue),
      ),
    );
  });

  test('운영 API는 HTTPS, 로컬 개발 API만 HTTP를 허용한다', () {
    expect(
      () => OnlineSaveApi(baseUrl: 'http://api.rune-nexus.example'),
      throwsFormatException,
    );
    expect(
      () => OnlineSaveApi(baseUrl: 'http://127.0.0.1:8080'),
      returnsNormally,
    );
  });
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

class _FakeOnlineSaveTransport extends OnlineSaveTransport {
  _FakeOnlineSaveTransport({this.getResponse, this.putResponse, this.getError});

  final OnlineSaveHTTPResponse? getResponse;
  final OnlineSaveHTTPResponse? putResponse;
  final Object? getError;
  Uri? requestedUri;
  String? requestMethod;
  String? requestBody;
  Map<String, String>? requestHeaders;

  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requestedUri = uri;
    requestMethod = 'GET';
    requestHeaders = headers;
    final error = getError;
    if (error != null) {
      throw error;
    }
    return getResponse!;
  }

  @override
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    requestedUri = uri;
    requestMethod = 'PUT';
    requestBody = body;
    requestHeaders = headers;
    return putResponse!;
  }
}
