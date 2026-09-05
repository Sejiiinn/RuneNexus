import 'package:flutter/services.dart';

import 'session_storage_types.dart';
export 'session_storage_types.dart';

class PlatformSessionStorage implements SessionStorage {
  const PlatformSessionStorage();

  static const _channel = MethodChannel('rune_nexus/session_storage');

  @override
  Future<String?> read() => _channel.invokeMethod<String>('read');

  @override
  Future<void> write(String value) =>
      _channel.invokeMethod<void>('write', {'value': value});

  @override
  Future<void> delete() => _channel.invokeMethod<void>('delete');
}
