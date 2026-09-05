// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'online_save_transport_types.dart';
export 'online_save_transport_types.dart';

class OnlineSaveTransport implements OnlineSaveHTTPClient {
  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) {
    return _sendJSON('POST', uri, body: body, headers: headers);
  }

  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    return _sendJSON('GET', uri, headers: headers);
  }

  @override
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) {
    return _sendJSON('PUT', uri, body: body, headers: headers);
  }

  Future<OnlineSaveHTTPResponse> _sendJSON(
    String method,
    Uri uri, {
    String? body,
    required Map<String, String> headers,
  }) async {
    final request = html.HttpRequest();
    final completed = Completer<OnlineSaveHTTPResponse>();

    request
      ..open(method, uri.toString())
      ..withCredentials = true
      ..timeout = const Duration(seconds: 10).inMilliseconds;
    if (body != null) {
      request.setRequestHeader('Content-Type', 'application/json');
    }
    for (final header in headers.entries) {
      request.setRequestHeader(header.key, header.value);
    }
    request.onLoad.listen((_) {
      if (completed.isCompleted) {
        return;
      }
      final retryAfter = request.getResponseHeader('Retry-After');
      completed.complete(
        OnlineSaveHTTPResponse(
          statusCode: request.status ?? 0,
          body: request.responseText ?? '',
          headers: retryAfter == null ? const {} : {'retry-after': retryAfter},
        ),
      );
    });
    request.onError.listen((_) {
      _completeWithConnectionError(completed);
    });
    request.onAbort.listen((_) {
      _completeWithConnectionError(completed);
    });
    request.onTimeout.listen((_) {
      if (!completed.isCompleted) {
        completed.completeError(
          const OnlineSaveTransportException('온라인 저장 요청 시간이 초과되었습니다.'),
        );
      }
    });

    try {
      request.send(body);
    } on Object catch (error) {
      throw OnlineSaveTransportException('온라인 저장 요청 실패: $error');
    }
    return completed.future;
  }

  void _completeWithConnectionError(
    Completer<OnlineSaveHTTPResponse> completed,
  ) {
    if (!completed.isCompleted) {
      completed.completeError(
        const OnlineSaveTransportException('온라인 저장 API에 연결할 수 없습니다.'),
      );
    }
  }
}
