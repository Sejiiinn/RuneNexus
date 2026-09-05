abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}
