import 'session_storage_types.dart';
export 'session_storage_types.dart';

class PlatformSessionStorage implements SessionStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async =>
      throw UnsupportedError('인증 정보를 보관할 수 없는 플랫폼입니다.');
  @override
  Future<void> delete() async {}
}
