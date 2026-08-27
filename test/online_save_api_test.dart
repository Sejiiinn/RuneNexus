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

  test('기준 revision 조회는 If-None-Match를 보내고 304를 본문 없이 해석한다', () async {
    final transport = _FakeOnlineSaveTransport(
      getResponse: const OnlineSaveHTTPResponse(
        statusCode: 304,
        body: '',
        headers: {'etag': '"rn-save-12"'},
      ),
    );
    final api = OnlineSaveApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: transport,
    );

    final result = await api.loadIfChanged('access-token', knownRevision: 12);

    expect(result.notModified, isTrue);
    expect(result.snapshot, isNull);
    expect(transport.requestHeaders, {
      'Authorization': 'Bearer access-token',
      'If-None-Match': '"rn-save-12"',
    });
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
      writerGeneration: 7,
      data: _saveData(5678),
    );

    final result = await api.update('access-token', request);

    expect(transport.requestMethod, 'PUT');
    expect(transport.requestBody, same(request.encodedBody));
    expect(transport.requestHeaders, {
      'Authorization': 'Bearer access-token',
      'Idempotency-Key': '0198b955-3656-7c40-b3cb-87f427b90be3',
      'Rune-Nexus-Save-Writer': '7',
    });
    expect(jsonDecode(transport.requestBody!), {
      'expectedRevision': 12,
      'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
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
          writerGeneration: 7,
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

  test('writer 획득 요청과 generation 응답을 그대로 처리한다', () async {
    final transport = _FakeOnlineSaveTransport(
      postResponse: const OnlineSaveHTTPResponse(
        statusCode: 200,
        body: '{"writerGeneration":8,"claimedAt":"2026-08-26T03:00:00Z"}',
      ),
    );
    final api = OnlineSaveApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: transport,
    );
    final request = OnlineSaveWriterClaimRequest(
      idempotencyKey: '0198b955-3656-7c40-b3cb-87f427b90be3',
      clientInstanceId: '0198b955-3656-7c40-b3cb-87f427b90be4',
      clientBuild: 'test-build',
    );

    final result = await api.claimWriter('access-token', request);

    expect(transport.requestMethod, 'POST');
    expect(transport.requestBody, request.encodedBody);
    expect(transport.requestHeaders, {
      'Authorization': 'Bearer access-token',
      'Idempotency-Key': '0198b955-3656-7c40-b3cb-87f427b90be3',
    });
    expect(jsonDecode(transport.requestBody!), {
      'clientInstanceId': '0198b955-3656-7c40-b3cb-87f427b90be4',
      'saveSchemaVersion': GameSaveData.currentVersion,
      'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
      'clientBuild': 'test-build',
    });
    expect(result.writerGeneration, 8);
    expect(result.claimedAt, DateTime.utc(2026, 8, 26, 3));
  });

  test('업데이트 뒤에도 이전 호환 버전의 영속 요청 본문을 정확히 복구한다', () {
    final writerClaim = OnlineSaveWriterClaimRequest(
      idempotencyKey: '0198b955-3656-7c40-b3cb-87f427b90be3',
      clientInstanceId: '0198b955-3656-7c40-b3cb-87f427b90be4',
      clientBuild: 'previous-build',
      clientCompatibilityVersion: 1,
    );
    final update = OnlineSaveUpdateRequest(
      expectedRevision: 12,
      idempotencyKey: '0198b955-3656-7c40-b3cb-87f427b90be5',
      writerGeneration: 7,
      data: _saveData(5678),
      clientCompatibilityVersion: 1,
    );

    final restoredWriterClaim = OnlineSaveWriterClaimRequest.fromPersisted(
      idempotencyKey: writerClaim.idempotencyKey,
      encodedBody: writerClaim.encodedBody,
      currentClientCompatibilityVersion: 2,
    );
    final restoredUpdate = OnlineSaveUpdateRequest.fromPersisted(
      expectedRevision: update.expectedRevision,
      idempotencyKey: update.idempotencyKey,
      writerGeneration: update.writerGeneration,
      encodedBody: update.encodedBody,
      currentClientCompatibilityVersion: 2,
    );

    expect(restoredWriterClaim.clientCompatibilityVersion, 1);
    expect(restoredWriterClaim.encodedBody, writerClaim.encodedBody);
    expect(restoredUpdate.clientCompatibilityVersion, 1);
    expect(restoredUpdate.encodedBody, update.encodedBody);
    expect(restoredUpdate.data.savedAtMillis, 5678);
  });

  test('현재 클라이언트보다 미래인 영속 요청은 복구하지 않는다', () {
    final update = OnlineSaveUpdateRequest(
      expectedRevision: 12,
      idempotencyKey: '0198b955-3656-7c40-b3cb-87f427b90be5',
      writerGeneration: 7,
      data: _saveData(5678),
      clientCompatibilityVersion: 3,
    );

    expect(
      () => OnlineSaveUpdateRequest.fromPersisted(
        expectedRevision: update.expectedRevision,
        idempotencyKey: update.idempotencyKey,
        writerGeneration: update.writerGeneration,
        encodedBody: update.encodedBody,
        currentClientCompatibilityVersion: 2,
      ),
      throwsFormatException,
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
  _FakeOnlineSaveTransport({
    this.getResponse,
    this.postResponse,
    this.putResponse,
    this.getError,
  });

  final OnlineSaveHTTPResponse? getResponse;
  final OnlineSaveHTTPResponse? postResponse;
  final OnlineSaveHTTPResponse? putResponse;
  final Object? getError;
  Uri? requestedUri;
  String? requestMethod;
  String? requestBody;
  Map<String, String>? requestHeaders;

  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    requestedUri = uri;
    requestMethod = 'POST';
    requestBody = body;
    requestHeaders = headers;
    return postResponse!;
  }

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
