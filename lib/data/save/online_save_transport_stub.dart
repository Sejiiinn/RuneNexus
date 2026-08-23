class OnlineSaveHTTPResponse {
  const OnlineSaveHTTPResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

class OnlineSaveTransportException implements Exception {
  const OnlineSaveTransportException(this.message);

  final String message;

  @override
  String toString() => 'OnlineSaveTransportException: $message';
}

class OnlineSaveTransport {
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    throw const OnlineSaveTransportException('현재 플랫폼에서는 온라인 저장 요청을 지원하지 않습니다.');
  }

  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) {
    throw const OnlineSaveTransportException('현재 플랫폼에서는 온라인 저장 요청을 지원하지 않습니다.');
  }
}
