// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'session_storage_types.dart';
export 'session_storage_types.dart';

class PlatformSessionStorage implements SessionStorage {
  static const _key = 'rune_nexus:auth:metadata:v1';
  // 토큰은 HttpOnly 쿠키에만 보관. 여기에는 계정/재시도 메타데이터만 저장.
  @override
  Future<String?> read() async => html.window.localStorage[_key];
  @override
  Future<void> write(String value) async =>
      html.window.localStorage[_key] = value;
  @override
  Future<void> delete() async => html.window.localStorage.remove(_key);
}
