class PlatformLocalSaveWriterLock {
  Future<bool> acquire() async => true;

  void release() {}
}
