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

abstract interface class AuthenticationClient {
  Future<AuthenticationHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  });
}
