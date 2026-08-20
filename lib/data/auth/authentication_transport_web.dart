// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class AuthenticationHTTPResponse {
  const AuthenticationHTTPResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

class AuthenticationTransportException implements Exception {
  const AuthenticationTransportException(this.message);

  final String message;

  @override
  String toString() => 'AuthenticationTransportException: $message';
}

class AuthenticationTransport {
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
