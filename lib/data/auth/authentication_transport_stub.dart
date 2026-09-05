import 'authentication_transport_types.dart';
export 'authentication_transport_types.dart';

class AuthenticationTransport implements AuthenticationClient {
  @override
  Future<AuthenticationHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) {
    throw const AuthenticationTransportException(
      '현재 플랫폼에서는 웹 인증 요청을 지원하지 않습니다.',
    );
  }
}
