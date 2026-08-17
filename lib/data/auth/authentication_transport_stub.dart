class AuthenticationHTTPResponse {
  const AuthenticationHTTPResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class AuthenticationTransportException implements Exception {
  const AuthenticationTransportException(this.message);

  final String message;

  @override
  String toString() => 'AuthenticationTransportException: $message';
}

class AuthenticationTransport {
  Future<AuthenticationHTTPResponse> postJSON(Uri uri, {required String body}) {
    throw const AuthenticationTransportException(
      '현재 플랫폼에서는 웹 인증 요청을 지원하지 않습니다.',
    );
  }
}
