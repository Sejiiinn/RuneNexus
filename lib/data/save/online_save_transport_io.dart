import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'online_save_transport_types.dart';
export 'online_save_transport_types.dart';

class OnlineSaveTransport implements OnlineSaveHTTPClient {
  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) => _sendJSON('POST', uri, body: body, headers: headers);

  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) => _sendJSON('GET', uri, headers: headers);

  @override
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) => _sendJSON('PUT', uri, body: body, headers: headers);

  Future<OnlineSaveHTTPResponse> _sendJSON(
    String method,
    Uri uri, {
    String? body,
    required Map<String, String> headers,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.openUrl(method, uri);
        // Bearer 토큰의 리다이렉트 대상 노출 방지.
        request.followRedirects = false;
        if (body != null) {
          request.headers.contentType = ContentType.json;
        }
        headers.forEach(request.headers.set);
        if (body != null) {
          request.write(body);
        }
        final response = await request.close();
        return OnlineSaveHTTPResponse(
          statusCode: response.statusCode,
          body: await utf8.decoder.bind(response).join(),
          headers: {
            'retry-after': ?response.headers.value(
              HttpHeaders.retryAfterHeader,
            ),
          },
        );
      })().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const OnlineSaveTransportException('온라인 저장 요청 시간이 초과되었습니다.');
    } on Exception {
      throw const OnlineSaveTransportException('온라인 저장 API에 연결할 수 없습니다.');
    } finally {
      client.close(force: true);
    }
  }
}
