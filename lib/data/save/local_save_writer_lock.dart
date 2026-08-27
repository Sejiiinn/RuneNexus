import 'local_save_writer_lock_stub.dart'
    if (dart.library.html) 'local_save_writer_lock_web.dart';

abstract interface class LocalSaveWriterLock {
  Future<bool> acquire();

  void release();
}

LocalSaveWriterLock createLocalSaveWriterLock() {
  return _DefaultLocalSaveWriterLock(PlatformLocalSaveWriterLock());
}

class _DefaultLocalSaveWriterLock implements LocalSaveWriterLock {
  _DefaultLocalSaveWriterLock(this._platform);

  final PlatformLocalSaveWriterLock _platform;

  @override
  Future<bool> acquire() => _platform.acquire();

  @override
  void release() => _platform.release();
}
