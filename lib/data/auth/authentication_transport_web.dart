// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'authentication_transport_types.dart';
export 'authentication_transport_types.dart';

class AuthenticationTransport implements AuthenticationClient {
  @override
  Future<AuthenticationHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    final request = html.HttpRequest();
    final completed = Completer<AuthenticationHTTPResponse>();

    request
      ..open('POST', uri.toString())
      ..withCredentials = true
      ..timeout = const Duration(seconds: 10).inMilliseconds
      ..setRequestHeader('Content-Type', 'application/json');
    for (final header in headers.entries) {
      request.setRequestHeader(header.key, header.value);
    }
    request.onLoad.listen((_) {
      if (!completed.isCompleted) {
        final retryAfter = request.getResponseHeader('Retry-After');
        completed.complete(
          AuthenticationHTTPResponse(
            statusCode: request.status ?? 0,
            body: request.responseText ?? '',
            headers: retryAfter == null
                ? const {}
                : {'retry-after': retryAfter},
          ),
        );
      }
    });
    request.onError.listen((_) {
      if (!completed.isCompleted) {
        completed.completeError(
          const AuthenticationTransportException('인증 API에 연결할 수 없습니다.'),
        );
      }
    });
    request.onTimeout.listen((_) {
      if (!completed.isCompleted) {
        completed.completeError(
          const AuthenticationTransportException('인증 API 요청 시간이 초과되었습니다.'),
        );
      }
    });

    try {
      request.send(body);
    } on Object catch (error) {
      throw AuthenticationTransportException('인증 API 요청 실패: $error');
    }
    return completed.future;
  }
}
