import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/legacy_save_transfer_api.dart';
import 'package:rune_nexus/data/save/online_save_transport_stub.dart';

void main() {
  const token = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  test('기존 진행 이전 링크 생성은 인증 정보 없이 canonical 저장만 전송한다', () async {
    final transport = _FakeLegacyTransferTransport(
      responses: [
        OnlineSaveHTTPResponse(
          statusCode: 201,
          body: jsonEncode({
            'token': token,
            'expiresAt': '2026-08-29T03:15:00Z',
          }),
        ),
      ],
    );
    final api = LegacySaveTransferApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: transport,
    );

    final result = await api.create(_saveData());

    expect(
      transport.requests.single.uri,
      Uri.parse('https://api.rune-nexus.example/v1/legacy-save-transfers'),
    );
    expect(transport.requests.single.headers, isEmpty);
    final body = jsonDecode(transport.requests.single.body);
    expect(body['clientCompatibilityVersion'], 1);
    expect(body['data']['version'], GameSaveData.currentVersion);
    expect(result.token, token);
    expect(result.expiresAt, DateTime.parse('2026-08-29T03:15:00Z'));
  });

  test('이전 링크 소비는 Bearer와 토큰으로 계정 귀속 결과를 받는다', () async {
    final transport = _FakeLegacyTransferTransport(
      responses: [
        OnlineSaveHTTPResponse(
          statusCode: 200,
          body: jsonEncode({
            'revision': 1,
            'serverSavedAt': '2026-08-29T03:01:02Z',
          }),
        ),
      ],
    );
    final api = LegacySaveTransferApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: transport,
    );

    final result = await api.consume('access-token', token: token);

    final request = transport.requests.single;
    expect(
      request.uri,
      Uri.parse(
        'https://api.rune-nexus.example/v1/legacy-save-transfers/consume',
      ),
    );
    expect(request.headers, {'Authorization': 'Bearer access-token'});
    expect(jsonDecode(request.body), {'token': token});
    expect(result.revision, 1);
  });

  test('안전하게 교체할 수 없는 계정 응답을 보존한다', () async {
    final api = LegacySaveTransferApi(
      baseUrl: 'https://api.rune-nexus.example',
      transport: _FakeLegacyTransferTransport(
        responses: [
          OnlineSaveHTTPResponse(
            statusCode: 409,
            body: jsonEncode({
              'code': 'LEGACY_TRANSFER_TARGET_REQUIRES_MANUAL_REVIEW',
              'message': '자동으로 교체할 수 없는 진행 데이터입니다.',
            }),
          ),
        ],
      ),
    );

    await expectLater(
      api.consume('access-token', token: token),
      throwsA(
        isA<LegacySaveTransferException>().having(
          (error) => error.code,
          'code',
          'LEGACY_TRANSFER_TARGET_REQUIRES_MANUAL_REVIEW',
        ),
      ),
    );
  });
}

GameSaveData _saveData() {
  return GameSaveData.fromJson({
    'version': GameSaveData.currentVersion,
    'savedAtMillis': 123,
    'preferences': <String, Object?>{},
    'progression': <String, Object?>{
      'runes': 10,
      'freeDiamonds': 20,
      'paidDiamonds': 0,
    },
    'turretModules': <String, Object?>{'tickets': 1, 'items': <Object?>[]},
    'activeRun': null,
  })!;
}

class _LegacyTransferRequest {
  const _LegacyTransferRequest({
    required this.uri,
    required this.body,
    required this.headers,
  });

  final Uri uri;
  final String body;
  final Map<String, String> headers;
}

class _FakeLegacyTransferTransport extends OnlineSaveTransport {
  _FakeLegacyTransferTransport({
    required List<OnlineSaveHTTPResponse> responses,
  }) : _responses = List.of(responses);

  final List<OnlineSaveHTTPResponse> _responses;
  final List<_LegacyTransferRequest> requests = [];

  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    requests.add(
      _LegacyTransferRequest(uri: uri, body: body, headers: Map.of(headers)),
    );
    return _responses.removeAt(0);
  }
}
