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

abstract interface class OnlineSaveHTTPClient {
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  });
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  });
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  });
}
