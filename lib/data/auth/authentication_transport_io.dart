import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'authentication_transport_types.dart';
export 'authentication_transport_types.dart';

class AuthenticationTransport implements AuthenticationClient {
  @override
  Future<AuthenticationHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.postUrl(uri);
        // 인증 정보를 다른 호스트로 전달하지 않는 리다이렉트 금지.
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        headers.forEach(request.headers.set);
        request.write(body);
        final response = await request.close();
        return AuthenticationHTTPResponse(
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
      throw const AuthenticationTransportException('인증 API 요청 시간이 초과되었습니다.');
    } on Exception {
      throw const AuthenticationTransportException('인증 API에 연결할 수 없습니다.');
    } finally {
      client.close(force: true);
    }
  }
}
