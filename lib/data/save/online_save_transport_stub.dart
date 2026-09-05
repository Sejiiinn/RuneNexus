import 'online_save_transport_types.dart';
export 'online_save_transport_types.dart';

class OnlineSaveTransport implements OnlineSaveHTTPClient {
  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) {
    throw const OnlineSaveTransportException('현재 플랫폼에서는 온라인 저장 요청을 지원하지 않습니다.');
  }

  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    throw const OnlineSaveTransportException('현재 플랫폼에서는 온라인 저장 요청을 지원하지 않습니다.');
  }

  @override
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) {
    throw const OnlineSaveTransportException('현재 플랫폼에서는 온라인 저장 요청을 지원하지 않습니다.');
  }
}
